import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webfeed_revised/webfeed_revised.dart';

import '../models/card.dart';

/// tldr's content sourcing.
///
/// Two independent lanes merge into a single feed:
///
///  1. **NewsAPI lane** — English coverage. Server-side GitHub Actions
///     cron refreshes twice a day (every 12h) and commits the JSON to
///     `assets/content/cards.json`. The client fetches that file from
///     GitHub Raw on load and caches it locally. Fits NewsAPI's quota
///     comfortably and is the offline / cold-start baseline.
///
///  2. **Hebrew RSS lane** — client-side. On every app open we hit the
///     5 curated Hebrew feeds directly and merge them in. Works fully
///     on Android (no CORS). On PWA the browser will refuse the
///     cross-origin fetches; we silently fall back to the 36h cache
///     from a previous successful fetch, and if that's empty too, the
///     PWA user just sees the NewsAPI baseline (English + whatever HE
///     the server-side snapshot has). Nothing crashes, everything
///     degrades quietly.
///
/// Merge rule: dedupe by canonical URL, sort by publishedAt DESC so
/// fresh live-RSS items rise to the top and stale-cache items sink
/// to the bottom without any manual "put cached at end" bookkeeping.
class ContentRepository {
  ContentRepository(this._prefs);

  // ── NewsAPI (server-cached) ──────────────────────────────────────
  static const _remoteUrl =
      'https://raw.githubusercontent.com/unix14/tldr-mobile/main/assets/content/cards.json';
  static const _newsApiCacheKey = 'cards_cache_v1';
  static const _newsApiCacheTsKey = 'cards_cache_ts_v1';
  static const _networkTimeout = Duration(seconds: 6);

  // ── RSS (client-fetched) ─────────────────────────────────────────
  static const _rssCacheKey = 'rss_cache_v1';
  static const _rssCacheTsKey = 'rss_cache_ts_v1';
  static const _rssCacheMaxAge = Duration(hours: 36);
  static const _rssTimeout = Duration(seconds: 5);

  static const List<_RssFeed> _rssFeeds = [
    _RssFeed(
      url: 'https://www.ynet.co.il/Integration/StoryRss2.xml',
      publisher: 'Ynet',
      topics: ['israel', 'world'],
      max: 10,
    ),
    _RssFeed(
      url:
          'https://www.globes.co.il/webservice/rss/rssfeeder.asmx/FeederNode?iID=2',
      publisher: 'Globes',
      topics: ['markets', 'israel'],
      max: 10,
    ),
    _RssFeed(
      url: 'https://rss.walla.co.il/feed/1',
      publisher: 'Walla',
      topics: ['israel', 'world'],
      max: 8,
    ),
    _RssFeed(
      url: 'https://www.israelhayom.co.il/rss.xml',
      publisher: 'Israel Hayom',
      topics: ['israel'],
      max: 8,
    ),
    _RssFeed(
      url: 'https://www.haaretz.co.il/cmlink/1.1470869',
      publisher: 'Haaretz',
      topics: ['israel', 'world'],
      max: 10,
    ),
  ];

  final SharedPreferences _prefs;

  Future<List<ContentCard>> loadAll() async {
    // Kick RSS off in parallel with the NewsAPI baseline fetch so total
    // load time is bounded by the slower lane, not their sum.
    final newsApiFuture = _loadNewsApiLane();
    final rssFuture = _loadRssLane();

    final results = await Future.wait([newsApiFuture, rssFuture]);
    final newsApi = results[0];
    final rss = results[1];
    return _merge([...newsApi, ...rss]);
  }

  // ── NewsAPI lane ─────────────────────────────────────────────────

  Future<List<ContentCard>> _loadNewsApiLane() async {
    try {
      final res = await http
          .get(Uri.parse(_remoteUrl))
          .timeout(_networkTimeout);
      if (res.statusCode == 200 && res.body.isNotEmpty) {
        final list = _parseJson(res.body);
        if (list.isNotEmpty) {
          unawaited(_writeNewsApiCache(res.body));
          return list;
        }
      }
    } catch (e) {
      debugPrint('[content] newsapi network fetch failed: $e');
    }
    final cached = _prefs.getString(_newsApiCacheKey);
    if (cached != null && cached.isNotEmpty) {
      try {
        return _parseJson(cached);
      } catch (_) {}
    }
    // Bundled asset as last-resort.
    try {
      final raw = await rootBundle.loadString('assets/content/cards.json');
      return _parseJson(raw);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _writeNewsApiCache(String body) async {
    await _prefs.setString(_newsApiCacheKey, body);
    await _prefs.setInt(
        _newsApiCacheTsKey, DateTime.now().millisecondsSinceEpoch);
  }

  // ── RSS lane ─────────────────────────────────────────────────────

  Future<List<ContentCard>> _loadRssLane() async {
    // Fire all feeds in parallel with per-feed timeout + isolation so one
    // slow site doesn't drag the whole feed. Failures are silent — we
    // fall back to cache below.
    final results = await Future.wait(_rssFeeds.map(_fetchOneRssFeed));
    final live = <ContentCard>[];
    for (final r in results) {
      live.addAll(r);
    }
    if (live.isNotEmpty) {
      unawaited(_writeRssCache(live));
      return live;
    }
    // Live fetch got nothing → try the 36h cache.
    final cached = _readRssCacheIfFresh();
    if (cached.isNotEmpty) {
      debugPrint('[content] rss live fetch empty; using cache '
          '(${cached.length} items)');
    }
    return cached;
  }

  Future<List<ContentCard>> _fetchOneRssFeed(_RssFeed feed) async {
    try {
      final res = await http.get(
        Uri.parse(feed.url),
        headers: const {
          // Some Israeli sites 403 non-browser UAs.
          'User-Agent':
              'Mozilla/5.0 (compatible; tldr-app/1.0) AppleWebKit/605.1.15',
          'Accept': 'application/rss+xml, application/xml, text/xml, */*',
        },
      ).timeout(_rssTimeout);
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) return const [];
      // Israel Hayom (and some other feeds) serve `text/xml` without a
      // charset, so Dart's http package would default to Latin-1 on
      // `res.body` — every Hebrew glyph would come back as mojibake. All
      // five feeds we curate declare UTF-8 in their XML preamble, so
      // decode the raw bytes as UTF-8 (with a permissive replacement on
      // stray bytes so one bad character can't sink a whole feed).
      final xml = utf8.decode(res.bodyBytes, allowMalformed: true);
      final parsed = RssFeed.parse(xml);
      final items = (parsed.items ?? []).take(feed.max).toList();
      return items
          .map((it) => _rssItemToCard(it, feed))
          .whereType<ContentCard>()
          .toList();
    } catch (e) {
      debugPrint('[content] rss ${feed.publisher} failed: $e');
      return const [];
    }
  }

  ContentCard? _rssItemToCard(RssItem item, _RssFeed feed) {
    final headline = _stripHtml(item.title ?? '').trim();
    final url = item.link ?? item.guid ?? '';
    if (headline.isEmpty || url.isEmpty) return null;
    final desc = _stripHtml(item.description ?? item.content?.value ?? '');
    final bullets = <String>[];
    if (desc.isNotEmpty) {
      final sentences = desc
          .split(RegExp(r'(?<=[.!?׃])\s+'))
          .map((s) => s.trim())
          .where((s) => s.length >= 12)
          .toList();
      if (sentences.isEmpty) {
        bullets.add(desc.length > 240 ? desc.substring(0, 240) : desc);
      } else {
        bullets.addAll(sentences.take(3));
      }
    }
    final published = item.pubDate ?? DateTime.now();
    final tags = <String>{...feed.topics};
    // Same adjacent-topic tagging the server-side script does.
    if (feed.topics.contains('markets')) tags.add('world');
    if (feed.topics.contains('israel')) tags.add('world');

    return ContentCard(
      id: 'rss_${_hash(url)}',
      kind: CardKind.news,
      language: 'he',
      topicTags: tags.toList(),
      headline: headline,
      bullets: bullets,
      confidence: Confidence.confirmed,
      risk: Risk.standard,
      estimatedSeconds: _estimateSeconds(bullets.join(' ')),
      publishedAt: published,
      sources: [
        SourceRef(
          publisher: feed.publisher,
          url: url,
          publishedAt: published,
          tier: 1,
        ),
      ],
    );
  }

  Future<void> _writeRssCache(List<ContentCard> cards) async {
    final serial = jsonEncode(cards.map(_serializeCard).toList());
    await _prefs.setString(_rssCacheKey, serial);
    await _prefs.setInt(
        _rssCacheTsKey, DateTime.now().millisecondsSinceEpoch);
  }

  List<ContentCard> _readRssCacheIfFresh() {
    final ts = _prefs.getInt(_rssCacheTsKey);
    if (ts == null) return const [];
    final age =
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts));
    if (age > _rssCacheMaxAge) return const [];
    final raw = _prefs.getString(_rssCacheKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ContentCard.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  // ── merge + shared helpers ───────────────────────────────────────

  List<ContentCard> _merge(List<ContentCard> combined) {
    final seenUrl = <String>{};
    final out = <ContentCard>[];
    for (final c in combined) {
      final url = c.sources.isNotEmpty ? c.sources.first.url : c.id;
      if (seenUrl.contains(url)) continue;
      seenUrl.add(url);
      out.add(c);
    }
    // Newest first — natural order gives us the "cached RSS sinks to the
    // bottom because it's older" behaviour without extra bookkeeping.
    out.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return out;
  }

  List<ContentCard> _parseJson(String body) {
    final decoded = jsonDecode(body) as List<dynamic>;
    return decoded
        .map((e) => ContentCard.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Map<String, dynamic> _serializeCard(ContentCard c) => {
        'id': c.id,
        'kind': c.kind.name,
        'language': c.language,
        'topicTags': c.topicTags,
        'headline': c.headline,
        'bullets': c.bullets,
        'whyItMatters': c.whyItMatters,
        'confidence': c.confidence.name,
        'risk': c.risk.name,
        'estimatedSeconds': c.estimatedSeconds,
        'publishedAt': c.publishedAt.toIso8601String(),
        'sources': c.sources
            .map((s) => {
                  'publisher': s.publisher,
                  'url': s.url,
                  'publishedAt': s.publishedAt.toIso8601String(),
                  'tier': s.tier,
                })
            .toList(),
        'disagreement': c.disagreement,
        'youtubeId': c.youtubeId,
        'channel': c.channel,
        'imageUrl': c.imageUrl,
      };

  static String _stripHtml(String s) => s
      .replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&#x27;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static int _estimateSeconds(String text) {
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final s = (words / 3).round();
    return s < 20 ? 20 : (s > 120 ? 120 : s);
  }

  static String _hash(String s) {
    // Simple non-crypto hash — good enough for a card id de-collision.
    var h = 0;
    for (var i = 0; i < s.length; i++) {
      h = 0x1fffffff & (h + s.codeUnitAt(i));
      h = 0x1fffffff & (h + ((0x0007ffff & h) << 10));
      h ^= h >> 6;
    }
    h = 0x1fffffff & (h + ((0x03ffffff & h) << 3));
    h ^= h >> 11;
    h = 0x1fffffff & (h + ((0x00003fff & h) << 15));
    return h.toRadixString(16).padLeft(8, '0');
  }
}

class _RssFeed {
  final String url;
  final String publisher;
  final List<String> topics;
  final int max;
  const _RssFeed({
    required this.url,
    required this.publisher,
    required this.topics,
    required this.max,
  });
}

final contentRepositoryProvider =
    Provider<ContentRepository>((ref) => throw UnimplementedError(
          'contentRepositoryProvider must be overridden in main().',
        ));

final allCardsProvider = FutureProvider<List<ContentCard>>((ref) async {
  return ref.read(contentRepositoryProvider).loadAll();
});

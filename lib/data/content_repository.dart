import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/card.dart';

/// Network-first, cache-second, bundle-third.
///
///   1. Try to fetch the freshest `cards.json` from GitHub raw.
///      The refresh-content workflow updates it every 2h.
///   2. If (1) fails (offline, GitHub hiccup), fall back to the copy we
///      cached in SharedPreferences from a previous successful fetch.
///   3. If neither is available, use the version bundled with the APK.
///
/// The bundled copy is important: fresh installs, no-network first launches,
/// and CI-produced snapshots all render immediately without waiting on the
/// network. GitHub's Raw CDN is fast in practice but not zero-latency.
class ContentRepository {
  ContentRepository(this._prefs);

  static const _remoteUrl =
      'https://raw.githubusercontent.com/unix14/tldr-mobile/main/assets/content/cards.json';
  static const _cacheKey = 'cards_cache_v1';
  static const _cacheTsKey = 'cards_cache_ts_v1';
  static const _networkTimeout = Duration(seconds: 6);

  final SharedPreferences _prefs;

  Future<List<ContentCard>> loadAll() async {
    // 1. Network.
    try {
      final res = await http
          .get(Uri.parse(_remoteUrl))
          .timeout(_networkTimeout);
      if (res.statusCode == 200 && res.body.isNotEmpty) {
        final list = _parse(res.body);
        if (list.isNotEmpty) {
          // Cache raw text for next launch. Never blocks the return.
          unawaited(_writeCache(res.body));
          return list;
        }
      }
    } catch (e) {
      // Silent — we have fallbacks.
      debugPrint('[content] network fetch failed: $e');
    }

    // 2. Cache.
    final cached = _prefs.getString(_cacheKey);
    if (cached != null && cached.isNotEmpty) {
      try {
        final list = _parse(cached);
        if (list.isNotEmpty) return list;
      } catch (_) {
        // fall through
      }
    }

    // 3. Bundled asset.
    final raw = await rootBundle.loadString('assets/content/cards.json');
    return _parse(raw);
  }

  Future<void> _writeCache(String body) async {
    await _prefs.setString(_cacheKey, body);
    await _prefs.setInt(
        _cacheTsKey, DateTime.now().millisecondsSinceEpoch);
  }

  List<ContentCard> _parse(String body) {
    final decoded = jsonDecode(body) as List<dynamic>;
    return decoded
        .map((e) => ContentCard.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final contentRepositoryProvider =
    Provider<ContentRepository>((ref) => throw UnimplementedError(
          'contentRepositoryProvider must be overridden in main().',
        ));

final allCardsProvider = FutureProvider<List<ContentCard>>((ref) async {
  return ref.read(contentRepositoryProvider).loadAll();
});

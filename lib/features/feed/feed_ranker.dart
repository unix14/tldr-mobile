import 'dart:math';

import '../../models/card.dart';

class FeedRanker {
  const FeedRanker();

  /// Deterministic-ish ranker: interest weights + freshness + language +
  /// seen penalty + diversity constraint (no more than 2 same primary topic
  /// consecutively).
  List<ContentCard> rank({
    required List<ContentCard> pool,
    required String language,
    required Set<String> interests,
    required Map<String, double> weights,
    required Set<String> seenIds,
    required bool allowSensitive,
  }) {
    final now = DateTime.now();
    final scored = <(ContentCard, double)>[];
    for (final c in pool) {
      if (!allowSensitive && c.risk == Risk.distressing) continue;
      // Language: prefer matches but don't hide the other language entirely;
      // penalise mismatch mildly so the feed feels native but not walled off.
      final langBonus = c.language == language ? 0.4 : 0.0;

      double topicScore = 0;
      var overlaps = 0;
      for (final t in c.topicTags) {
        if (interests.contains(t)) {
          overlaps += 1;
          topicScore += weights[t] ?? 1.0;
        }
      }
      if (overlaps == 0) topicScore = 0.15; // small floor so surprises survive
      final freshness =
          _freshnessScore(now.difference(c.publishedAt).inHours.toDouble());
      final seenPenalty = seenIds.contains(c.id) ? -1.5 : 0.0;
      final score = topicScore + langBonus + freshness + seenPenalty;
      scored.add((c, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));

    // Diversity + kind spacing pass
    final ordered = <ContentCard>[];
    final buckets = List<ContentCard>.from(scored.map((e) => e.$1));
    final rand = Random(42);
    while (buckets.isNotEmpty) {
      // Pick the next card that doesn't repeat the last two primary topics
      // and doesn't produce 3 video cards in a row.
      int chosenIdx = 0;
      for (var i = 0; i < buckets.length; i++) {
        if (_ok(ordered, buckets[i])) {
          chosenIdx = i;
          break;
        }
      }
      // Light random jitter within the top-N to keep sessions from being
      // perfectly identical.
      if (ordered.length > 3 && buckets.length > 5) {
        final jitter = rand.nextInt(3);
        if (chosenIdx + jitter < buckets.length &&
            _ok(ordered, buckets[chosenIdx + jitter])) {
          chosenIdx += jitter;
        }
      }
      ordered.add(buckets.removeAt(chosenIdx));
    }
    return ordered;
  }

  bool _ok(List<ContentCard> tail, ContentCard candidate) {
    if (tail.length < 2) return true;
    final last = tail.last;
    final prev = tail[tail.length - 2];
    // No 3 same primary topics in a row
    if (last.topicTags.isNotEmpty &&
        prev.topicTags.isNotEmpty &&
        candidate.topicTags.isNotEmpty &&
        last.topicTags.first == candidate.topicTags.first &&
        prev.topicTags.first == candidate.topicTags.first) {
      return false;
    }
    // No 3 videos in a row
    if (last.kind == CardKind.video &&
        prev.kind == CardKind.video &&
        candidate.kind == CardKind.video) {
      return false;
    }
    return true;
  }

  double _freshnessScore(double hoursOld) {
    if (hoursOld < 0) return 0.3;
    if (hoursOld < 6) return 0.6;
    if (hoursOld < 24) return 0.4;
    if (hoursOld < 72) return 0.2;
    if (hoursOld < 168) return 0.05;
    return -0.1;
  }
}

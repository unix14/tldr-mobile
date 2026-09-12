import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Counters for the current app session only.
///
/// * Reset every launch (this file exists in memory).
/// * Never persisted, never sent anywhere.
/// * Feed & actions increment; the end-of-feed screen reads.
///
/// Deliberately not tied to any user id or device fingerprint — it is a
/// quiet mirror for the user, not a metric for us.
class SessionStats {
  final int itemsSeen;
  final int cardsSaved;
  final int sourcesOpened;

  const SessionStats({
    this.itemsSeen = 0,
    this.cardsSaved = 0,
    this.sourcesOpened = 0,
  });

  SessionStats bumpSeen() =>
      SessionStats(
        itemsSeen: itemsSeen + 1,
        cardsSaved: cardsSaved,
        sourcesOpened: sourcesOpened,
      );

  SessionStats bumpSaved() =>
      SessionStats(
        itemsSeen: itemsSeen,
        cardsSaved: cardsSaved + 1,
        sourcesOpened: sourcesOpened,
      );

  SessionStats bumpSources() =>
      SessionStats(
        itemsSeen: itemsSeen,
        cardsSaved: cardsSaved,
        sourcesOpened: sourcesOpened + 1,
      );
}

class SessionStatsNotifier extends Notifier<SessionStats> {
  @override
  SessionStats build() => const SessionStats();

  void markSeen() => state = state.bumpSeen();
  void markSaved() => state = state.bumpSaved();
  void markSourcesOpened() => state = state.bumpSources();
}

final sessionStatsProvider =
    NotifierProvider<SessionStatsNotifier, SessionStats>(
        SessionStatsNotifier.new);

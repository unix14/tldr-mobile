import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App-session lifetime tracker.
///
/// * `startedAt` — set once when the notifier is created (app launch).
/// * `checkInFired` — becomes true the first time the gentle check-in sheet
///   is shown; the sheet is one-per-session by design so we never nag.
/// * `snoozed` — when the user chose "keep reading" we push the *next*
///   trigger out by [snoozeMinutes] instead of never showing it again.
///
/// Everything here lives in memory only. A fresh launch resets the clock.
class SessionTimerState {
  final DateTime startedAt;
  final bool checkInFired;
  final DateTime? snoozedUntil;

  const SessionTimerState({
    required this.startedAt,
    this.checkInFired = false,
    this.snoozedUntil,
  });

  Duration elapsed() => DateTime.now().difference(startedAt);

  bool shouldShowCheckIn({
    required int sessionMinutes,
    DateTime? now,
  }) {
    if (sessionMinutes <= 0) return false;
    final n = now ?? DateTime.now();
    if (snoozedUntil != null && n.isBefore(snoozedUntil!)) return false;
    if (checkInFired && snoozedUntil == null) return false;
    final elapsedMin = n.difference(startedAt).inSeconds / 60;
    return elapsedMin >= sessionMinutes;
  }

  SessionTimerState copyWith({
    bool? checkInFired,
    DateTime? snoozedUntil,
    bool clearSnooze = false,
  }) =>
      SessionTimerState(
        startedAt: startedAt,
        checkInFired: checkInFired ?? this.checkInFired,
        snoozedUntil: clearSnooze ? null : (snoozedUntil ?? this.snoozedUntil),
      );
}

class SessionTimerNotifier extends Notifier<SessionTimerState> {
  @override
  SessionTimerState build() =>
      SessionTimerState(startedAt: DateTime.now());

  /// Called the first time the sheet is shown in a session.
  void markShown() {
    state = state.copyWith(checkInFired: true, clearSnooze: true);
  }

  /// User chose "keep reading" — push the next check-in out by [minutes].
  void snooze({int minutes = 10}) {
    state = state.copyWith(
      checkInFired: true,
      snoozedUntil: DateTime.now().add(Duration(minutes: minutes)),
    );
  }
}

final sessionTimerProvider =
    NotifierProvider<SessionTimerNotifier, SessionTimerState>(
        SessionTimerNotifier.new);

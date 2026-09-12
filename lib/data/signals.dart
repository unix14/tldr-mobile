import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card.dart';
import 'settings_repository.dart';

/// Implicit-signal ranker driver.
///
/// Replaces the removed More/Less UI. Interest weights are nudged based
/// on how the user actually engages with each card:
///
///   * dwell < 3s        → −0.05 per topic tag (skipped)
///   * dwell 3–15s       → no change (neutral)
///   * dwell 15–60s      → +0.05 per topic tag (engaged)
///   * dwell ≥ 60s       → +0.10 per topic tag (deep)
///   * save              → +0.15 per topic tag
///   * open Sources sheet→ +0.10 per topic tag
///   * open a source URL → +0.15 per topic tag  (highest trust signal)
///
/// Adjustments are applied through the existing
/// [SettingsController.adjustInterestWeight], which clamps to [0.1, 3.0].
class SignalTracker {
  // WidgetRef so we can call this from any Consumer widget without threading
  // notifier-side Refs through the tree.
  final WidgetRef _ref;
  SignalTracker(this._ref);

  Future<void> recordDwell(ContentCard card, Duration dwell) async {
    final delta = _dwellDelta(dwell);
    if (delta == 0) return;
    await _apply(card, delta);
  }

  Future<void> recordSave(ContentCard card) => _apply(card, 0.15);
  Future<void> recordSourcesOpened(ContentCard card) => _apply(card, 0.10);
  Future<void> recordSourceOpened(ContentCard card) => _apply(card, 0.15);

  double _dwellDelta(Duration dwell) {
    final s = dwell.inMilliseconds / 1000.0;
    if (s < 3) return -0.05;
    if (s < 15) return 0.0;
    if (s < 60) return 0.05;
    return 0.10;
  }

  Future<void> _apply(ContentCard card, double delta) async {
    final ctrl = _ref.read(settingsControllerProvider.notifier);
    for (final t in card.topicTags) {
      await ctrl.adjustInterestWeight(t, delta);
    }
  }
}

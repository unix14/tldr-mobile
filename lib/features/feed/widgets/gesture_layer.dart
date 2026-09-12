import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/session_stats.dart';
import '../../../data/settings_repository.dart';
import '../../../data/signals.dart';
import '../../../models/card.dart';
import '../../../theme/colors.dart';

/// Wraps a card with one gesture: **double-tap to save**.
///
/// * Double-tap always *saves* — never unsaves. If the card is already
///   saved, we still play the animation (small acknowledgement) but the
///   library state is unchanged. Unsave lives on the bookmark button in
///   the action row, so an accidental double-tap can never destroy a
///   deliberate save.
/// * All vertical drags fall through to the parent PageView.
/// * No horizontal-drag gesture at all — More/Less signals are inferred
///   from dwell + save + source-open, not from an explicit UI.
class GestureLayer extends ConsumerStatefulWidget {
  final ContentCard card;
  final Widget child;
  const GestureLayer({
    super.key,
    required this.card,
    required this.child,
  });

  @override
  ConsumerState<GestureLayer> createState() => _GestureLayerState();
}

class _GestureLayerState extends ConsumerState<GestureLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flashCtrl;

  @override
  void initState() {
    super.initState();
    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
  }

  @override
  void dispose() {
    _flashCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleDoubleTap() async {
    HapticFeedback.selectionClick();
    _flashCtrl.forward(from: 0);
    final wasSaved = ref
        .read(settingsControllerProvider)
        .librarySavedIds
        .contains(widget.card.id);
    if (wasSaved) return; // Never toggle-off on double-tap.
    await ref
        .read(settingsControllerProvider.notifier)
        .toggleSave(widget.card.id);
    ref.read(sessionStatsProvider.notifier).markSaved();
    await SignalTracker(ref).recordSave(widget.card);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onDoubleTap: _handleDoubleTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          _saveFlash(),
        ],
      ),
    );
  }

  Widget _saveFlash() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _flashCtrl,
        builder: (context, _) {
          final t = _flashCtrl.value;
          if (t == 0) return const SizedBox.shrink();
          final scale = 0.6 + (t < 0.5 ? t : (1 - t)) * 1.8;
          final opacity = t < 0.15
              ? t / 0.15
              : t > 0.7
                  ? 1.0 - ((t - 0.7) / 0.3)
                  : 1.0;
          return Center(
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bookmark,
                    color: AppColors.accent,
                    size: 56,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

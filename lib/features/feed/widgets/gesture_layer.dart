import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/session_stats.dart';
import '../../../data/settings_repository.dart';
import '../../../models/card.dart';
import '../../../theme/colors.dart';

/// Wraps a card with rich gestures:
///
/// * **Double-tap** → toggle save, with a big centered bookmark flash.
/// * **Horizontal drag** → show a colored side hint (green ✓ for "more like
///   this", red — for "less like this"); release past the threshold commits
///   the choice, otherwise the hint animates back.
/// * **Vertical drag** → falls through untouched to the parent PageView so
///   swiping between cards still works.
///
/// The layer never blocks child pointer events; it uses the *deferred*
/// gesture semantics — the widget under it (bullets, action row, callouts)
/// still receives taps normally.
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
    with TickerProviderStateMixin {
  static const double _commitThreshold = 90; // px

  late final AnimationController _flashCtrl;
  late final AnimationController _hintCtrl;
  double _dragDx = 0;
  bool _committing = false;

  bool get _isHe => widget.card.language == 'he';

  @override
  void initState() {
    super.initState();
    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _hintCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      value: 0,
    );
  }

  @override
  void dispose() {
    _flashCtrl.dispose();
    _hintCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleDoubleTap() async {
    HapticFeedback.selectionClick();
    _flashCtrl.forward(from: 0);
    final wasSaved = ref
        .read(settingsControllerProvider)
        .librarySavedIds
        .contains(widget.card.id);
    await ref
        .read(settingsControllerProvider.notifier)
        .toggleSave(widget.card.id);
    if (!wasSaved) {
      ref.read(sessionStatsProvider.notifier).markSaved();
    }
  }

  void _onHorizontalDragUpdate(DragUpdateDetails d) {
    setState(() => _dragDx = (_dragDx + d.delta.dx).clamp(-160.0, 160.0));
    final progress = _dragDx.abs() / _commitThreshold;
    _hintCtrl.value = progress.clamp(0.0, 1.0);
  }

  Future<void> _onHorizontalDragEnd(DragEndDetails d) async {
    if (_committing) return;
    if (_dragDx.abs() < _commitThreshold) {
      _reset();
      return;
    }
    // In RTL, a physical rightward drag reads as a "back" motion — invert
    // the sign so More/Less semantics stay consistent regardless of layout.
    final rightward =
        _isHe ? (_dragDx < 0) : (_dragDx > 0);
    _committing = true;
    HapticFeedback.mediumImpact();
    final messenger = ScaffoldMessenger.of(context);
    for (final t in widget.card.topicTags) {
      await ref
          .read(settingsControllerProvider.notifier)
          .adjustInterestWeight(t, rightward ? 0.3 : -0.4);
    }
    if (mounted) {
      _showToast(
        messenger,
        rightward
            ? (_isHe ? 'נראה יותר כאלה' : 'Showing more like this')
            : (_isHe ? 'נראה פחות כאלה' : 'Showing less like this'),
      );
    }
    _reset();
    _committing = false;
  }

  void _reset() {
    setState(() => _dragDx = 0);
    _hintCtrl.reverse();
  }

  void _showToast(ScaffoldMessengerState m, String msg) {
    m.showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(seconds: 1),
      backgroundColor: AppColors.surfaceElevated,
    ));
  }

  bool get _saved =>
      ref.watch(settingsControllerProvider).librarySavedIds
          .contains(widget.card.id);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onDoubleTap: _handleDoubleTap,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      onHorizontalDragCancel: _reset,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Card content, translated slightly with the drag so it feels
          // physically anchored to the finger.
          Transform.translate(
            offset: Offset(_dragDx * 0.4, 0),
            child: widget.child,
          ),
          _sideHint(),
          _saveFlash(),
        ],
      ),
    );
  }

  Widget _sideHint() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _hintCtrl,
        builder: (context, _) {
          final v = _hintCtrl.value;
          if (v == 0) return const SizedBox.shrink();
          // In LTR: positive drag = right = "more" = green
          // In RTL: positive drag = right visually = "less" = red (mirrored)
          final rightward = _isHe ? (_dragDx < 0) : (_dragDx > 0);
          final color = rightward ? AppColors.confirmed : AppColors.disputed;
          final align = _dragDx > 0 ? Alignment.centerLeft : Alignment.centerRight;
          return Opacity(
            opacity: (v * 0.9).clamp(0.0, 0.9),
            child: Align(
              alignment: align,
              child: Container(
                width: 84 + (v * 30),
                margin: const EdgeInsets.symmetric(vertical: 80),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  border: BorderDirectional(
                    start: _dragDx < 0
                        ? BorderSide(color: color, width: 3)
                        : BorderSide.none,
                    end: _dragDx > 0
                        ? BorderSide(color: color, width: 3)
                        : BorderSide.none,
                  ),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(rightward ? Icons.add : Icons.remove,
                        size: 40, color: color),
                    const SizedBox(height: 6),
                    Text(
                      rightward
                          ? (_isHe ? 'עוד כאלה' : 'More')
                          : (_isHe ? 'פחות' : 'Less'),
                      style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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
                  child: Icon(
                    _saved ? Icons.bookmark : Icons.bookmark_border,
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

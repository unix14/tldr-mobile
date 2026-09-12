import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/session_stats.dart';
import '../../../data/session_timer.dart';
import '../../../data/settings_repository.dart';
import '../../../theme/colors.dart';

/// A gentle mid-session pause.
///
/// * Fires once per session (or once per snooze window) when the user's
///   chosen session length has been exceeded.
/// * Never blocks. Two clear choices: keep reading (snoozes) or step away
///   (dismisses the sheet — no lecture, no confetti, no streak).
/// * Draggable + tap-outside-to-dismiss, matches every other bottom sheet
///   in the app so it never feels like an alert dialog.
///
/// Call [SessionCheckInSheet.show] from a place that has a BuildContext.
class SessionCheckInSheet extends ConsumerWidget {
  const SessionCheckInSheet._();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surfaceElevated,
      builder: (_) => const SessionCheckInSheet._(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final stats = ref.watch(sessionStatsProvider);
    final timer = ref.watch(sessionTimerProvider);
    final isHe = settings.language == 'he';
    final elapsed = timer.elapsed();
    final t = Theme.of(context).textTheme;

    return Directionality(
      textDirection: isHe ? TextDirection.rtl : TextDirection.ltr,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Small accent rule, same visual language as end-of-feed.
              Center(
                child: Container(
                  width: 28,
                  height: 2,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                isHe
                    ? 'עברו ${_formatElapsed(elapsed, isHe)}.'
                    : "You've been reading for ${_formatElapsed(elapsed, isHe)}.",
                textAlign: TextAlign.center,
                style: t.headlineSmall!.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isHe
                    ? 'לפעמים מספיק להיום. אין שום לחץ.'
                    : 'Enough for now is a good place to stop.',
                textAlign: TextAlign.center,
                style: t.bodyMedium!.copyWith(
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 28),
              _statsStrip(context, stats, isHe),
              const SizedBox(height: 28),
              _button(
                label: isHe ? 'הפסקה קטנה' : 'Step away',
                onTap: () {
                  ref.read(sessionTimerProvider.notifier).markShown();
                  Navigator.of(context).pop();
                },
                bg: AppColors.accent,
                fg: Colors.black,
              ),
              const SizedBox(height: 8),
              _button(
                label: isHe ? 'עוד קצת' : 'Keep reading',
                onTap: () {
                  ref
                      .read(sessionTimerProvider.notifier)
                      .snooze(minutes: 10);
                  Navigator.of(context).pop();
                },
                bg: Colors.transparent,
                fg: AppColors.textPrimary,
                border: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statsStrip(BuildContext context, SessionStats stats, bool isHe) {
    Widget one(String value, String label) {
      return Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge!.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall!.copyWith(
                  color: AppColors.textMuted,
                  letterSpacing: 1.1,
                ),
          ),
        ],
      );
    }

    Widget sep() => Container(
          width: 1,
          height: 30,
          margin: const EdgeInsets.symmetric(horizontal: 22),
          color: AppColors.divider,
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        one('${stats.itemsSeen}', isHe ? 'נקראו' : 'read'),
        sep(),
        one('${stats.cardsSaved}', isHe ? 'נשמרו' : 'saved'),
        sep(),
        one('${stats.sourcesOpened}', isHe ? 'מקורות' : 'sources'),
      ],
    );
  }

  Widget _button({
    required String label,
    required VoidCallback onTap,
    required Color bg,
    required Color fg,
    bool border = false,
  }) {
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        side: border
            ? const BorderSide(color: AppColors.divider)
            : BorderSide.none,
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _formatElapsed(Duration d, bool isHe) {
    final m = d.inMinutes;
    if (m < 1) return isHe ? 'פחות מדקה' : 'less than a minute';
    if (m == 1) return isHe ? 'דקה אחת' : '1 minute';
    if (m < 60) {
      return isHe ? '$m דקות' : '$m minutes';
    }
    final h = m ~/ 60;
    final rem = m % 60;
    if (rem == 0) {
      return isHe
          ? (h == 1 ? 'שעה' : '$h שעות')
          : (h == 1 ? '1 hour' : '$h hours');
    }
    return isHe ? '$h שעות ו־$rem דקות' : '$h h $rem min';
  }
}

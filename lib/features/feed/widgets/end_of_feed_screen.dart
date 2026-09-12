import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/session_stats.dart';
import '../../../theme/colors.dart';

/// A quiet moment. The whole product-promise reduces to this screen:
/// the user reached the end without being kept scrolling.
///
/// * Big serif "You're caught up."
/// * Session-only stats (never persisted, never sent).
/// * Two calm actions — Look again (rewind) or Open Library (revisit saves).
class EndOfFeedScreen extends ConsumerWidget {
  final String language;
  final int totalCards;
  final VoidCallback onBackToTop;

  const EndOfFeedScreen({
    super.key,
    required this.language,
    required this.totalCards,
    required this.onBackToTop,
  });

  bool get _isHe => language == 'he';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(sessionStatsProvider);
    final t = Theme.of(context).textTheme;

    return Directionality(
      textDirection: _isHe ? TextDirection.rtl : TextDirection.ltr,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Small quiet mark above the headline
              Center(
                child: Container(
                  width: 32,
                  height: 2,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                _isHe ? 'סיימת להתעדכן.' : "You're caught up.",
                textAlign: TextAlign.center,
                style: t.displayMedium!.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _isHe
                    ? 'זה זמן טוב לחזור לחיים.'
                    : 'A good moment to step away.',
                textAlign: TextAlign.center,
                style: t.bodyLarge!.copyWith(
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 40),
              _statsRow(context, stats),
              const SizedBox(height: 40),
              _primaryButton(
                label: _isHe ? 'חזרה להתחלה' : 'Look again',
                onTap: onBackToTop,
              ),
              const SizedBox(height: 10),
              _secondaryButton(
                label: _isHe ? 'פתח את הספרייה' : 'Open Library',
                onTap: () {
                  // The Library tab is the sibling; use the shell nav.
                  // Feed → Library switch is at the ShellScreen level, so
                  // just pop this focus and let the user tap Library.
                  // For MVP simplicity we surface it as a hint here rather
                  // than deep-linking.
                  _showLibraryHint(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statsRow(BuildContext context, SessionStats stats) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stat(context,
            value: '${stats.itemsSeen}',
            label: _isHe ? 'נקראו' : 'read'),
        _statDivider(),
        _stat(context,
            value: '${stats.cardsSaved}',
            label: _isHe ? 'נשמרו' : 'saved'),
        _statDivider(),
        _stat(context,
            value: '${stats.sourcesOpened}',
            label: _isHe ? 'מקורות' : 'sources'),
      ],
    );
  }

  Widget _statDivider() {
    return Container(
      width: 1,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      color: AppColors.divider,
    );
  }

  Widget _stat(BuildContext context,
      {required String value, required String label}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
        ),
        const SizedBox(height: 4),
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

  Widget _primaryButton({required String label, required VoidCallback onTap}) {
    return _button(
      label: label,
      onTap: onTap,
      bg: AppColors.accent,
      fg: Colors.black,
    );
  }

  Widget _secondaryButton(
      {required String label, required VoidCallback onTap}) {
    return _button(
      label: label,
      onTap: onTap,
      bg: Colors.transparent,
      fg: AppColors.textPrimary,
      border: true,
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
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
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

  void _showLibraryHint(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isHe
              ? 'הקש על "ספרייה" בסרגל התחתון.'
              : 'Tap Library in the bottom bar.',
        ),
        backgroundColor: AppColors.surfaceElevated,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

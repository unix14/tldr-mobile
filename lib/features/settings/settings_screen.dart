import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/settings_repository.dart';
import '../../models/interest.dart';
import '../../theme/colors.dart';
import '../onboarding/onboarding_screen.dart';

/// Editorial settings.
///
/// Structure mirrors the card + end-of-feed rhythm: section eyebrows in
/// small caps, quiet dividers, custom pill selectors instead of dropdowns
/// so nothing looks like an OS system chrome. The whole screen is meant
/// to feel like a well-set page, not a form.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final isHe = settings.language == 'he';
    final ctrl = ref.read(settingsControllerProvider.notifier);
    final t = Theme.of(context).textTheme;

    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          backgroundColor: AppColors.bg,
          surfaceTintColor: Colors.transparent,
          title: Text(isHe ? 'הגדרות' : 'Settings'),
          pinned: true,
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _section(context, isHe ? 'קריאה' : 'Reading'),
              _card(
                child: Column(
                  children: [
                    _rowLabel(
                      context,
                      title: isHe ? 'שפה' : 'Language',
                      trailing: _PillGroup<String>(
                        value: settings.language,
                        options: const [
                          _PillOption(value: 'en', label: 'EN'),
                          _PillOption(value: 'he', label: 'עב'),
                        ],
                        onChanged: ctrl.setLanguage,
                      ),
                    ),
                    const _SoftDivider(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isHe ? 'נושאים' : 'Interests',
                            style: t.titleMedium!.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isHe
                                ? 'בחר לפחות אחד. עדיף שניים.'
                                : 'Pick at least one — two is better.',
                            style: t.bodySmall!.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final i in kInterests)
                                _InterestPill(
                                  label: i.label(settings.language),
                                  selected: settings.interests.contains(i.id),
                                  onTap: () {
                                    final next = Set<String>.from(
                                        settings.interests);
                                    if (next.contains(i.id)) {
                                      next.remove(i.id);
                                    } else {
                                      next.add(i.id);
                                    }
                                    if (next.isNotEmpty) {
                                      ctrl.setInterests(next);
                                    }
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              _section(context, isHe ? 'סשן' : 'Session'),
              _card(
                child: Column(
                  children: [
                    _rowLabel(
                      context,
                      title: isHe
                          ? 'אורך סשן מועדף'
                          : 'Preferred session length',
                      subtitle: isHe
                          ? 'הצעת עצירה עדינה, פעם בסשן.'
                          : 'A gentle nudge to pause, once per session.',
                      trailing: _PillGroup<int>(
                        value: settings.sessionMinutes,
                        options: const [
                          _PillOption(value: 5, label: '5m'),
                          _PillOption(value: 10, label: '10m'),
                          _PillOption(value: 15, label: '15m'),
                          _PillOption(value: 30, label: '30m'),
                        ],
                        onChanged: ctrl.setSessionMinutes,
                      ),
                    ),
                    const _SoftDivider(),
                    _rowToggle(
                      context,
                      title: isHe ? 'מצב לילה אוטומטי' : 'Auto night mode',
                      subtitle: isHe
                          ? 'פלטה חמה יותר, בלי הפעלה אוטומטית לאחר 21:00.'
                          : 'Warmer palette, no autoplay after 9pm.',
                      value: settings.nightAuto,
                      onChanged: ctrl.setNightAuto,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              _section(context, isHe ? 'תוכן' : 'Content'),
              _card(
                child: _rowToggle(
                  context,
                  title: isHe
                      ? 'הצג תוכן רגיש'
                      : 'Allow distressing content',
                  subtitle: isHe
                      ? 'מסונן כברירת מחדל. הפעלה תוסיף חדשות עם תגית רגישה.'
                      : 'Filtered by default. Turning this on lets sensitive stories through.',
                  value: settings.allowSensitive,
                  onChanged: ctrl.setAllowSensitive,
                ),
              ),
              const SizedBox(height: 28),
              _section(context, isHe ? 'פרטיות' : 'Privacy'),
              _PrivacyCard(settings: settings, isHe: isHe),
              const SizedBox(height: 16),
              _card(
                child: _rowDanger(
                  context,
                  title: isHe ? 'מחק את כל הנתונים' : 'Clear all data',
                  subtitle: isHe
                      ? 'מוחק היסטוריה, מועדפים ונתוני נושאים באופן מיידי.'
                      : 'Removes history, saves, and interest weights instantly.',
                  onTap: () => _confirmClear(context, ref, isHe),
                ),
              ),
              const SizedBox(height: 40),
              _footer(context, isHe),
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ],
    );
  }

  // ── layout primitives ────────────────────────────────────────────

  Widget _section(BuildContext context, String label) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
        child: Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall!.copyWith(
                color: AppColors.textMuted,
                letterSpacing: 1.4,
              ),
        ),
      );

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: child,
      ),
    );
  }

  Widget _rowLabel(
    BuildContext context, {
    required String title,
    String? subtitle,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          color: AppColors.textMuted,
                        ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _rowToggle(
    BuildContext context, {
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium!.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                            color: AppColors.textMuted,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.accent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowDanger(
    BuildContext context, {
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.disputed.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline,
                  size: 18, color: AppColors.disputed),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium!.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.disputed,
                        ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                            color: AppColors.textMuted,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _footer(BuildContext context, bool isHe) {
    return Column(
      children: [
        Text(
          'tldr',
          style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          isHe ? 'קצר. נקי. שלך בלבד.' : 'Short. Clean. Yours alone.',
          style: Theme.of(context).textTheme.bodySmall!.copyWith(
                color: AppColors.textMuted,
                fontStyle: FontStyle.italic,
              ),
        ),
        const SizedBox(height: 10),
        Text(
          'v0.1',
          style: Theme.of(context).textTheme.labelSmall!.copyWith(
                color: AppColors.textMuted,
                letterSpacing: 1.2,
              ),
        ),
      ],
    );
  }

  Future<void> _confirmClear(
      BuildContext context, WidgetRef ref, bool isHe) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text(isHe ? 'למחוק הכל?' : 'Clear all data?'),
        content: Text(isHe
            ? 'הפעולה בלתי הפיכה. כל ההיסטוריה והמועדפים יימחקו מיד.'
            : 'This cannot be undone. All history, saves, and interests will be removed immediately.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isHe ? 'ביטול' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.disputed),
            child: Text(isHe ? 'מחק' : 'Clear'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(settingsControllerProvider.notifier).clearAll();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (route) => false,
    );
  }
}

// ── shared components ──────────────────────────────────────────────

class _SoftDivider extends StatelessWidget {
  const _SoftDivider();
  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 0.5,
      color: AppColors.divider,
      indent: 16,
      endIndent: 16,
    );
  }
}

class _PillOption<T> {
  final T value;
  final String label;
  const _PillOption({required this.value, required this.label});
}

class _PillGroup<T> extends StatelessWidget {
  final T value;
  final List<_PillOption<T>> options;
  final ValueChanged<T> onChanged;

  const _PillGroup({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final opt in options) _pill(opt),
        ],
      ),
    );
  }

  Widget _pill(_PillOption<T> opt) {
    final selected = opt.value == value;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected ? AppColors.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onChanged(opt.value),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 7),
            child: Text(
              opt.label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: selected ? Colors.black : AppColors.textSecondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InterestPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _InterestPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected
            ? AppColors.accent.withValues(alpha: 0.15)
            : AppColors.surfaceElevated,
        border: Border.all(
          color: selected ? AppColors.accent : AppColors.divider,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected ? AppColors.accent : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  final SettingsSnapshot settings;
  final bool isHe;
  const _PrivacyCard({required this.settings, required this.isHe});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_outline,
                  size: 16, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(
                isHe ? 'הכל נשאר במכשיר' : 'Everything stays on this device',
                style: t.titleMedium!.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isHe
                ? 'אין חשבון, אין ענן, אין פרופיל פרסומי. תחומי העניין, השמורים וההיסטוריה חיים רק כאן.'
                : 'No account. No cloud. No advertising profile. Your interests, saves, and history live only here.',
            style: t.bodyMedium!.copyWith(
              color: AppColors.textSecondary,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 14),
          _statLine(
            context,
            label: isHe ? 'פריטים שמורים' : 'Saved items',
            value: '${settings.librarySavedIds.length}',
          ),
          const SizedBox(height: 6),
          _statLine(
            context,
            label: isHe ? 'נצפו' : 'Seen',
            value: '${settings.seenIds.length}',
          ),
          const SizedBox(height: 6),
          _statLine(
            context,
            label: isHe ? 'תחומי עניין' : 'Interests',
            value: '${settings.interests.length}',
          ),
        ],
      ),
    );
  }

  Widget _statLine(BuildContext context,
      {required String label, required String value}) {
    return Row(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall!.copyWith(
                color: AppColors.textMuted,
              ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            height: 1,
            color: AppColors.divider.withValues(alpha: 0.7),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall!.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
        ),
      ],
    );
  }
}

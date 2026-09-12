import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/settings_repository.dart';
import '../../models/interest.dart';
import '../../theme/colors.dart';
import '../shell/shell_screen.dart';

/// First-launch experience.
///
/// Two steps, no accounts, no goals, no promises:
///   1. Language pick (English or עברית).
///   2. Interest pick (news topics only in v1).
///
/// Every screen renders in the currently-selected onboarding language so a
/// user who picks Hebrew immediately sees Hebrew chrome — the language pill
/// isn't just a preference, it's the moment the app becomes theirs.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  String _language = 'en';
  final Set<String> _picked = {'world', 'tech'};
  int _step = 0;

  bool get _isHe => _language == 'he';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: _isHe ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.03),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: _step == 0 ? _languageStep() : _interestsStep(),
          ),
        ),
      ),
    );
  }

  // ── Step 1: Language ──────────────────────────────────────────────

  Widget _languageStep() {
    return Padding(
      key: const ValueKey('lang'),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(flex: 3),
          Text(
            'tldr',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displayLarge!.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 68,
                  height: 1,
                ),
          ),
          const SizedBox(height: 18),
          Text(
            _isHe
                ? 'קצר. נקי. שלך בלבד.'
                : 'Short. Clean. Yours alone.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge!.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.1,
                ),
          ),
          const Spacer(flex: 4),
          Text(
            _isHe ? 'שפת ממשק' : 'Interface language',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall!.copyWith(
                  color: AppColors.textMuted,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _langPill(
                  label: 'English',
                  selected: _language == 'en',
                  onTap: () => setState(() => _language = 'en'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _langPill(
                  label: 'עברית',
                  selected: _language == 'he',
                  onTap: () => setState(() => _language = 'he'),
                ),
              ),
            ],
          ),
          const Spacer(flex: 3),
          _primaryButton(
            label: _isHe ? 'המשך' : 'Continue',
            onTap: () => setState(() => _step = 1),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _langPill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected
            ? AppColors.accent.withValues(alpha: 0.12)
            : AppColors.surface,
        border: Border.all(
          color: selected ? AppColors.accent : AppColors.divider,
          width: selected ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.accent : AppColors.textPrimary,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Step 2: Interests ─────────────────────────────────────────────

  Widget _interestsStep() {
    final count = _picked.length;
    final canContinue = count >= 2;
    return Padding(
      key: const ValueKey('interests'),
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () => setState(() => _step = 0),
            style: IconButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(36, 36),
              foregroundColor: AppColors.textSecondary,
            ),
            icon: Icon(
              _isHe ? Icons.arrow_forward : Icons.arrow_back,
              size: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isHe ? 'מה מעניין אותך?' : 'What matters to you?',
            style: Theme.of(context).textTheme.headlineLarge!.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                _isHe
                    ? 'בחר לפחות שניים.'
                    : 'Pick at least two.',
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const Spacer(),
              AnimatedOpacity(
                opacity: count > 0 ? 1 : 0,
                duration: const Duration(milliseconds: 220),
                child: Text(
                  _isHe ? '$count נבחרו' : '$count selected',
                  style: Theme.of(context).textTheme.labelSmall!.copyWith(
                        color: canContinue
                            ? AppColors.accent
                            : AppColors.textMuted,
                        letterSpacing: 1.2,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final i in kInterests)
                    _interestChip(
                      label: i.label(_language),
                      selected: _picked.contains(i.id),
                      onTap: () => setState(() {
                        if (_picked.contains(i.id)) {
                          _picked.remove(i.id);
                        } else {
                          _picked.add(i.id);
                        }
                      }),
                    ),
                ],
              ),
            ),
          ),
          _primaryButton(
            label: _isHe ? 'להתחיל' : 'Start reading',
            onTap: canContinue ? _finish : null,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _interestChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected
            ? AppColors.accent.withValues(alpha: 0.15)
            : AppColors.surface,
        border: Border.all(
          color: selected ? AppColors.accent : AppColors.divider,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 11),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                color: selected ? AppColors.accent : AppColors.textPrimary,
              ),
              child: Text(label),
            ),
          ),
        ),
      ),
    );
  }

  // ── Shared ────────────────────────────────────────────────────────

  Widget _primaryButton({
    required String label,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return SizedBox(
      width: double.infinity,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: enabled ? AppColors.accent : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    color: enabled ? Colors.black : AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _finish() async {
    await ref.read(settingsControllerProvider.notifier).completeOnboarding(
          language: _language,
          interests: _picked,
        );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ShellScreen()),
    );
  }
}

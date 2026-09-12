import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings_repository.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/shell/shell_screen.dart';
import '../theme/theme.dart';

/// Allow mouse-drag on web + desktop for scrollables — required for the
/// vertical PageView feed to be swipeable outside of touch devices.
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      };
}

class TldrApp extends ConsumerWidget {
  const TldrApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    return MaterialApp(
      title: 'tldr',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      scrollBehavior: const _AppScrollBehavior(),
      locale: Locale(settings.language),
      supportedLocales: const [Locale('en'), Locale('he')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: settings.onboarded ? const ShellScreen() : const OnboardingScreen(),
    );
  }
}

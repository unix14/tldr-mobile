import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/settings_repository.dart';
import '../../theme/colors.dart';
import '../feed/feed_screen.dart';
import '../library/library_screen.dart';
import '../settings/settings_screen.dart';
import 'widgets/tldr_nav_bar.dart';

class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  int _index = 0;

  static const _pages = [
    FeedScreen(),
    LibraryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);
    final isHe = settings.language == 'he';
    final items = [
      NavItem(
        icon: Icons.article_outlined,
        activeIcon: Icons.article,
        label: isHe ? 'פיד' : 'Feed',
      ),
      NavItem(
        icon: Icons.bookmark_border,
        activeIcon: Icons.bookmark,
        label: isHe ? 'ספרייה' : 'Library',
      ),
      NavItem(
        icon: Icons.tune,
        activeIcon: Icons.tune,
        label: isHe ? 'הגדרות' : 'Settings',
      ),
    ];
    return Directionality(
      textDirection: isHe ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: IndexedStack(index: _index, children: _pages),
        bottomNavigationBar: TldrNavBar(
          index: _index,
          items: items,
          onSelect: (i) => setState(() => _index = i),
        ),
      ),
    );
  }
}

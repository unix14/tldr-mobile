import 'package:flutter/material.dart';

import '../../../theme/colors.dart';

class NavItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  const NavItem({
    required this.icon,
    required this.label,
    this.activeIcon,
  });
}

/// Custom bottom navigation.
///
/// * Thin top hairline (no full elevation shadow).
/// * Small-caps labels in the same rhythm as card meta and settings
///   section eyebrows.
/// * Active state = accent icon + a small underline dot that slides
///   between destinations.
/// * Subtle backdrop translucency so a card scrolling under the bar
///   quietly darkens through it instead of being flatly cut off.
class TldrNavBar extends StatelessWidget {
  final int index;
  final List<NavItem> items;
  final ValueChanged<int> onSelect;

  const TldrNavBar({
    super.key,
    required this.index,
    required this.items,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(
          top: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavCell(
                    item: items[i],
                    selected: i == index,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavCell extends StatelessWidget {
  final NavItem item;
  final bool selected;
  final VoidCallback onTap;
  const _NavCell({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = selected ? AppColors.accent : AppColors.textSecondary;
    final labelColor = selected ? AppColors.textPrimary : AppColors.textMuted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.92, end: 1.0).animate(
                    CurvedAnimation(
                        parent: animation, curve: Curves.easeOut),
                  ),
                  child: child,
                ),
              ),
              child: Icon(
                selected ? (item.activeIcon ?? item.icon) : item.icon,
                key: ValueKey(selected),
                size: 22,
                color: iconColor,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: labelColor,
              ),
              child: Text(item.label.toUpperCase()),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              width: selected ? 14 : 0,
              height: 2,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

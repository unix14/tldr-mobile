import 'package:flutter/material.dart';

import 'colors.dart';
import 'typography.dart';

class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    final text = AppTypography.build();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      canvasColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.bg,
        surfaceContainerHighest: AppColors.surfaceElevated,
        primary: AppColors.accent,
        onPrimary: Colors.black,
        secondary: AppColors.accent,
        onSurface: AppColors.textPrimary,
        outline: AppColors.divider,
      ),
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        modalBackgroundColor: AppColors.surfaceElevated,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 0.5,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceElevated,
        selectedColor: AppColors.accent.withValues(alpha: 0.2),
        labelStyle: text.labelLarge!,
        secondaryLabelStyle: text.labelLarge!,
        side: const BorderSide(color: AppColors.divider),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 22),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
  }
}

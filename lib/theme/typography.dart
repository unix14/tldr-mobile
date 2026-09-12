import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';

/// Editorial type stack.
///
/// * Headlines / display → **Fraunces** (a modern variable serif with strong
///   editorial character but a friendly warmth; feels closer to a magazine
///   than a news app).
/// * Body / labels → **Inter** (neutral, extremely legible at small sizes,
///   great Hebrew coverage in modern releases).
///
/// A single [TextStyle] can only carry one font, so we compose the theme by
/// applying Inter as the base and overriding the display/headline slots with
/// Fraunces. Google Fonts falls back to system Hebrew where a glyph is
/// missing — a proper bundled Hebrew stack (Frank Ruhl Libre + Rubik) is a
/// separate refinement pass.
class AppTypography {
  AppTypography._();

  static TextTheme build() {
    // Base = Inter for the entire theme.
    final base = GoogleFonts.interTextTheme(
      const TextTheme(
        displayLarge: TextStyle(fontSize: 40, height: 1.05, letterSpacing: -0.8),
        displayMedium: TextStyle(fontSize: 32, height: 1.1, letterSpacing: -0.6),
        headlineLarge: TextStyle(fontSize: 28, height: 1.15, letterSpacing: -0.4),
        headlineMedium: TextStyle(fontSize: 24, height: 1.2, letterSpacing: -0.3),
        headlineSmall: TextStyle(fontSize: 20, height: 1.25, letterSpacing: -0.2),
        titleLarge: TextStyle(fontSize: 18, height: 1.3, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontSize: 15, height: 1.35, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 16, height: 1.5),
        bodyMedium: TextStyle(fontSize: 14, height: 1.5),
        bodySmall: TextStyle(fontSize: 12.5, height: 1.4),
        labelLarge: TextStyle(fontSize: 12.5, height: 1.15, letterSpacing: 0.3, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(fontSize: 11, height: 1.1, letterSpacing: 0.9, fontWeight: FontWeight.w600),
        labelSmall: TextStyle(fontSize: 10, height: 1.05, letterSpacing: 1.1, fontWeight: FontWeight.w600),
      ),
    ).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    // Override the four editorial slots with Fraunces — kept only for the
    // slots we actually use as "editorial" (display + headlines).
    TextStyle serif(TextStyle? base) =>
        GoogleFonts.fraunces(textStyle: base).copyWith();

    return base.copyWith(
      displayLarge: serif(base.displayLarge),
      displayMedium: serif(base.displayMedium),
      headlineLarge: serif(base.headlineLarge),
      headlineMedium: serif(base.headlineMedium),
      headlineSmall: serif(base.headlineSmall),
    );
  }
}

import 'package:flutter/material.dart';

/// tldr palette — true-black OLED dark, editorial restraint.
class AppColors {
  AppColors._();

  static const Color bg = Color(0xFF000000);
  static const Color surface = Color(0xFF0B0B0C);
  static const Color surfaceElevated = Color(0xFF141416);
  static const Color divider = Color(0xFF1E1E22);

  static const Color textPrimary = Color(0xFFE7E7EA);
  static const Color textSecondary = Color(0xFF9C9CA3);
  static const Color textMuted = Color(0xFF64646B);

  // Muted accent, not loud.
  static const Color accent = Color(0xFFCFA574);

  // Confidence chip palette (text-first; color is secondary signal).
  static const Color confirmed = Color(0xFF6AA37E);
  static const Color developing = Color(0xFFD4B25A);
  static const Color disputed = Color(0xFFCF8A6A);
  static const Color analysis = Color(0xFF7F94C4);
  static const Color opinion = Color(0xFF9C7FC4);

  // Night mode adjustments (warmer).
  static const Color nightAccent = Color(0xFFE0B48A);
}

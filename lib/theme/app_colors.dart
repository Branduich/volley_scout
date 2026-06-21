import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // --- Colori brand (sorgente) ---
  static const Color brandPrimary = Color(0xFF1E3A8A);   // blu profondo
  static const Color brandAccent  = Color(0xFFF59E0B);   // ambra

  // --- Colori semantici (a cosa servono, non che colore sono) ---
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger  = Color(0xFFDC2626);
  static const Color info    = Color(0xFF2563EB);
  static const Color neutral = Color(0xFF64748B);

  // --- Superfici / neutri ---
  static const Color surface    = Color(0xFFF8FAFC);
  static const Color surfaceDim = Color(0xFFE2E8F0);

  /// Scurisce un colore (es. la maglia di una squadra) riducendone la
  /// luminosità HSL — usato ovunque venga mostrato il colore squadra come
  /// avatar/badge, per maggiore leggibilità e coerenza visiva.
  static Color darken(Color color, [double amount = 0.25]) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }
}
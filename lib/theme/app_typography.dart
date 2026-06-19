import 'package:flutter/material.dart';

class AppTypography {
  AppTypography._();

  // Font Barlow bundlato come asset locale (assets/fonts/Barlow), nessuna
  // dipendenza da rete a runtime. Pesi disponibili: 400/500/600/700.
  static const String fontFamily = 'Barlow';

  static final TextTheme textTheme = _baseTextTheme.apply(fontFamily: fontFamily);

  static const TextTheme _baseTextTheme = TextTheme(
    // Titoli grandi (es. nome schermata, intestazioni)
    headlineMedium: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.5,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
    // Titoli di card / sezioni
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
    ),
    // Testo corrente
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
    ),
    // Testo secondario / sottotitoli
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
    ),
    // Testo dei bottoni
    labelLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.2,
    ),
  );
}
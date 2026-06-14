import 'package:flutter/material.dart';

class AppTypography {
  AppTypography._();

  // Famiglia base (se in futuro aggiungi un font custom, lo cambi qui)
  static const String? fontFamily = null; // null = font di sistema

  static const TextTheme textTheme = TextTheme(
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
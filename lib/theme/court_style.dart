import 'package:flutter/material.dart';
import 'app_colors.dart';
import '../models/enums.dart';

class CourtStyle {
  CourtStyle._();

  // Campo
  static const Color courtLine    = Color(0xFF94A3B8);
  static const Color netColor     = Color(0xFF475569);
  static const double lineWidth   = 1.5;
  static const double playerToken = 48; // diametro token giocatore

  // Traiettoria
  static const Color trajectoryArrow = AppColors.brandAccent;
  static const double trajectoryWidth = 2.5;

  // Colore associato a ciascun voto (#, +, !, -, =). Mezzo punto e negativo
  // condividono un colore neutro (non richiesto un trattamento dedicato).
  // positivo/errore usano Colors.blue/Colors.red letterali (non
  // AppColors.info/danger) per essere IDENTICI ai bottoni rapidi Punto/
  // Errore e al banner ultima azione (_buildQuickActionButton,
  // _descrizioneAzione in scout_screen.dart) — stesso significato
  // (punto/errore), deve essere lo stesso colore ovunque appaia.
  static Color votoColor(Voto v) {
    switch (v) {
      case Voto.perfetto:
        return AppColors.success;
      case Voto.positivo:
        return Colors.blue;
      case Voto.mezzoPunto:
      case Voto.negativo:
        return AppColors.neutral;
      case Voto.errore:
        return Colors.red;
    }
  }
}
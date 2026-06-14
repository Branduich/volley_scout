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

  // Colore associato a ciascun voto (#, +, !, -, =)
  static Color votoColor(Voto v) {
    switch (v) {
      case Voto.perfetto:
      case Voto.positivo:
        return AppColors.success;
      case Voto.mezzoPunto:
        return AppColors.warning;
      case Voto.negativo:
      case Voto.errore:
        return AppColors.danger;
    }
  }
}
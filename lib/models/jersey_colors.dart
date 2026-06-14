import 'package:flutter/material.dart';

class JerseyColor {
  final String nome;
  final Color color;

  const JerseyColor(this.nome, this.color);
}

const List<JerseyColor> jerseyPalette = [
  JerseyColor('Rosso', Color(0xFFD32F2F)),
  JerseyColor('Blu', Color(0xFF1976D2)),
  JerseyColor('Verde', Color(0xFF388E3C)),
  JerseyColor('Giallo', Color(0xFFFBC02D)),
  JerseyColor('Arancione', Color(0xFFF57C00)),
  JerseyColor('Viola', Color(0xFF7B1FA2)),
  JerseyColor('Nero', Color(0xFF212121)),
];

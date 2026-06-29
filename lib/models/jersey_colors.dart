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
  JerseyColor('Bianco', Color(0xFFFFFFFF)),
];

/// Colore del testo/numero da disegnare sopra un avatar/token con questo
/// sfondo — nero se lo sfondo è chiaro (es. bianco), altrimenti bianco.
/// Basato sulla luminanza (non solo un controllo esplicito sul bianco) per
/// restare corretto anche se in futuro si aggiungono altri colori chiari
/// alla palette, o per il colore invertito del libero (che può diventare
/// chiaro se il colore squadra originale è scuro).
Color contrastingTextColor(Color background) =>
    background.computeLuminance() > 0.6 ? Colors.black : Colors.white;

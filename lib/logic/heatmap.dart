/// Adapter verso `packages/volley_stats/lib/heatmap.dart` (passo 5.3 del piano
/// in docs/dati-stagionali.md).
///
/// Nel package le funzioni lavorano su [TiroScout], il tipo neutro ridotto ai
/// campi che la geometria legge: `ScoutAction` è una riga drift e sul web non
/// esiste. Qui restano le firme di prima, che accettano le righe drift e le
/// convertono — così i call-site dei report non cambiano.
library;

import 'dart:ui' show Offset;

import 'package:volley_stats/heatmap.dart' as stats;
import 'package:volley_stats/tiro_scout.dart';

import '../data/database.dart';
import '../models/enums.dart';

export 'package:volley_stats/tiro_scout.dart';

/// Riga drift → tipo neutro. Unico punto di conversione: se un domani la
/// geometria avesse bisogno di un campo in più, si aggiunge qui e in
/// [TiroScout], non in ogni chiamante.
TiroScout tiroDaRiga(ScoutAction a) => TiroScout(
      squadra: a.squadra,
      tipo: a.tipo,
      fondamentale: a.fondamentale,
      voto: a.voto,
      tipoEsecuzione: a.tipoEsecuzione,
      x1: a.traiettoriaX1,
      y1: a.traiettoriaY1,
      x2: a.traiettoriaX2,
      y2: a.traiettoriaY2,
      muroX: a.traiettoriaMuroX,
      muroY: a.traiettoriaMuroY,
    );

/// Vedi `stats.puntiArrivoAvversari`.
List<Offset> puntiArrivoAvversari(
        Iterable<ScoutAction> azioni, Fondamentale fondamentale) =>
    stats.puntiArrivoAvversari(azioni.map(tiroDaRiga), fondamentale);

/// Vedi `stats.puntiArrivoAvversariPerfetti`.
List<Offset> puntiArrivoAvversariPerfetti(
        Iterable<ScoutAction> azioni, Fondamentale fondamentale) =>
    stats.puntiArrivoAvversariPerfetti(azioni.map(tiroDaRiga), fondamentale);

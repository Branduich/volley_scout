import 'dart:ui' show Offset;

import '../data/database.dart';
import '../models/enums.dart';

/// Punti d'arrivo (nel NOSTRO campo) delle azioni AVVERSARIE del fondamentale
/// dato — battuta o attacco — per la heatmap. Coordinate normalizzate 0-1 nello
/// spazio del **campo doppio** (1200×600), con l'arrivo sempre nella metà
/// **destra** (= nostro campo) — direttamente disegnabili da
/// `CourtTrajectoriesView`/`MultiTrajectoryPainter` (`_toScreen`), come le
/// traiettorie.
///
/// Filtra: `squadra == avversari`, `tipo == scout`, quel `fondamentale`, con
/// traiettoria completa (X1/X2/Y2 non-null). Normalizzazione identica a
/// `buildTrajData`: si specchia se `x1 > 0.5` (partenza sempre a sinistra →
/// arrivo a destra), poi si prende il punto d'arrivo `(x2, y2)`.
///
/// I punti NON sono clampati: una battuta/attacco andata fuori produce un
/// arrivo oltre i bordi (coerente col resto dello scout). L'eventuale filtro
/// "solo palle in campo" si decide a monte o nel painter. Funzione pura —
/// vedi test/logic/heatmap_test.dart.
List<Offset> puntiArrivoAvversari(
    Iterable<ScoutAction> azioni, Fondamentale fondamentale) {
  final punti = <Offset>[];
  for (final a in azioni) {
    if (a.squadra != Squadra.avversari) continue;
    if (a.tipo != TipoAzione.scout) continue;
    if (a.fondamentale != fondamentale) continue;
    final x1 = a.traiettoriaX1;
    final x2 = a.traiettoriaX2;
    final y2 = a.traiettoriaY2;
    if (x1 == null || x2 == null || y2 == null) continue;
    // Specchia come buildTrajData se la partenza è a destra, così l'arrivo è
    // sempre nella nostra metà (destra, x >= 0.5).
    final ex = x1 > 0.5 ? 1.0 - x2 : x2;
    final ey = x1 > 0.5 ? 1.0 - y2 : y2;
    punti.add(Offset(ex, ey));
  }
  return punti;
}

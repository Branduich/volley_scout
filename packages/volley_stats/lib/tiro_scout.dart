import 'enums.dart';

/// Un'azione di scout **ridotta ai campi che la geometria legge**: dove parte
/// la palla, dove arriva, con che voto e in che fondamentale.
///
/// Esiste perché le funzioni di questo package non possono dipendere da
/// `ScoutAction`, che è una riga drift e sul web non esiste. Ma non si usa
/// nemmeno `AzioneBackup` al suo posto: quello è il DTO del **file**, porta
/// uid e riferimenti che qui non servono, e costruirne uno parziale solo per
/// disegnare una freccia sarebbe un dato finto che gira per il codice.
///
/// Gli adapter stanno ai due capi: l'app converte le righe drift
/// (`tiroDaRiga` in `logic/heatmap.dart`), la dashboard convertirà le
/// `AzioneBackup` lette dal backup. Entrambe chiamano lo stesso codice.
class TiroScout {
  const TiroScout({
    required this.squadra,
    required this.tipo,
    this.fondamentale,
    this.voto,
    this.tipoEsecuzione = 'nonSpecificato',
    this.x1,
    this.y1,
    this.x2,
    this.y2,
    this.muroX,
    this.muroY,
  });

  final Squadra squadra;
  final TipoAzione tipo;
  final Fondamentale? fondamentale;
  final Voto? voto;

  /// Colonna polimorfica: `.name` di TipoAttacco o TipoBattuta secondo il
  /// fondamentale (vedi Modello dati). Qui serve solo a riconoscere il
  /// pallonetto, che si disegna ad arco.
  final String tipoEsecuzione;

  /// Coordinate normalizzate 0-1 sul campo doppio; `null` se l'azione non ha
  /// traiettoria (la maggior parte).
  final double? x1, y1, x2, y2;

  /// Punto di tocco a muro, solo attacco (vedi TrajectoryScreen).
  final double? muroX, muroY;

  /// Ha una traiettoria completa, cioè è disegnabile.
  bool get haTraiettoria => x1 != null && y1 != null && x2 != null && y2 != null;
}

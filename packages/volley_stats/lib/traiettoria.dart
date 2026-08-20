import 'enums.dart';
import 'tiro_scout.dart';

/// Una traiettoria pronta da disegnare: coordinate normalizzate 0-1 con la
/// **partenza sempre a sinistra**, tocco a muro già specchiato insieme al
/// resto, e la forma (retta / arco del pallonetto / snodo del muro) risolta.
///
/// **Porta il `voto`, non un colore.** Il colore è presentazione, e i due
/// consumatori dell'app usano tipi diversi e incompatibili — `Color` a video,
/// `PdfColor` nel PDF — mentre la dashboard web vorrà la propria palette. È
/// esattamente la duplicazione che questa classe elimina: prima la stessa
/// normalizzazione era scritta due volte (`TrajData` e `_TrajPdf`) solo perché
/// in mezzo c'era un colore di tipo diverso.
class Traiettoria {
  const Traiettoria({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    this.muroX,
    this.muroY,
    this.isPallonetto = false,
    this.voto,
  });

  final double x1, y1, x2, y2;

  /// Punto di tocco a muro (solo attacco): la freccia si disegna in due
  /// segmenti con lo snodo qui.
  final double? muroX, muroY;

  /// Si disegna ad arco invece che dritta.
  final bool isPallonetto;

  /// Da cui il chiamante ricava il colore: `perfetto` = vincente,
  /// `errore` = sbagliata, il resto = palla in campo.
  final Voto? voto;
}

/// Normalizza un tiro in una traiettoria disegnabile, oppure `null` se le
/// coordinate non sono complete (la maggior parte delle azioni non ne ha).
///
/// La specchiatura serve a poter confrontare a colpo d'occhio traiettorie
/// battute da lati opposti del campo: chi parte da destra viene ribaltato
/// attorno al centro, muro compreso.
Traiettoria? normalizzaTiro(TiroScout t) {
  var x1 = t.x1;
  var y1 = t.y1;
  var x2 = t.x2;
  var y2 = t.y2;
  if (x1 == null || y1 == null || x2 == null || y2 == null) return null;

  var muroX = t.muroX;
  var muroY = t.muroY;
  if (x1 > 0.5) {
    x1 = 1.0 - x1;
    y1 = 1.0 - y1;
    x2 = 1.0 - x2;
    y2 = 1.0 - y2;
    if (muroX != null && muroY != null) {
      muroX = 1.0 - muroX;
      muroY = 1.0 - muroY;
    }
  }

  return Traiettoria(
    x1: x1,
    y1: y1,
    x2: x2,
    y2: y2,
    muroX: muroX,
    muroY: muroY,
    isPallonetto: t.tipoEsecuzione == TipoAttacco.pallonetto.name,
    voto: t.voto,
  );
}

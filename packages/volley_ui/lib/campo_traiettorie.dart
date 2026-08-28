import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:volley_stats/volley_stats.dart';

const _kCourtImage = 'packages/volley_ui/assets/double_court_bg.png';

/// Verde brillante per le frecce vincenti (ace, attacco punto): più saturo
/// del verde di stato dell'app, per risaltare sul campo scuro.
///
/// Definito QUI e non nel tema dell'app perché il campo lo disegna questo
/// package, e lo disegna identico per l'app e per il web. `CourtStyle` lo
/// ri-espone, così il valore resta uno solo.
const Color kColoreTraiettoriaVincente = Color(0xFF00FF08);
const double kSpessoreTraiettoria = 2.5;

/// Il blu scuro dietro al campo: lo stesso dello scout live.
///
/// Serve a far vedere le frecce BIANCHE anche fuori dal rettangolo — una
/// battuta parte da dietro la linea di fondo, e su pagina chiara la sua coda
/// non si vedeva. Chi mostra il campo su una pagina chiara dovrebbe
/// appoggiarlo su questo colore.
const Color kSfondoCampo = Color(0xFF143E59);

/// Frazione della larghezza disponibile occupata dal campo doppio e margine
/// superiore fisso — condivisi tra TrajectoryScreen, TrajectoryReportScreen e
/// (in futuro) la cattura per il PDF, così il campo è identico ovunque.
const double kCourtWidthFraction = 0.58;
const double kCourtTopMargin = 16.0;

// Alzata del punto di controllo per l'arco del pallonetto (px schermo).
const double _kPallonettoArcOffset = 40.0;

// Blob della heatmap opzionale sovrapposta alle traiettorie (vista ricezione
// combinata / modalità heatmap del report): tinta unica calda in blend additivo.
const Color _kHeatBlobColore = Color(0xFFFF3D00);
const int _kHeatBlobAlpha = 110;

/// Quanto inchiostro mette UN punto della heatmap, dato quanti sono.
///
/// I blob si sommano (`BlendMode.plus`): con un'opacità fissa bastano tre
/// punti sovrapposti a saturare, e da lì in poi il colore non cambia più.
/// Con quattrocento tiri in mezzo campo veniva tutto giallo pieno, e una
/// mappa satura non dice più DOVE cade la palla: dice solo che ne sono
/// cadute tante, che è il numero scritto sopra al campo.
///
/// L'opacità scende come `1/√n`. Il `1/n` puro sarebbe la legge esatta — la
/// sovrapposizione cresce proprio così — ma spegne troppo: con quattrocento
/// tiri servivano quattordici palloni nello stesso punto per vedere qualcosa.
/// La radice è la via di mezzo fra "tutto giallo" e "quasi niente".
///
/// Il minimo tiene visibile un punto isolato anche in mezzo a una stagione
/// intera: i colpi rari sono spesso quelli interessanti.
int alphaBlobHeatmap(int quanti) => quanti <= 0
    ? 0
    : (_kHeatBlobAlpha * math.sqrt(12 / quanti))
        .round()
        .clamp(16, _kHeatBlobAlpha);
const double _kHeatBlobRaggioFrazione = 0.065;

// Marker (cerchietto bordo rosso, senza fill) per ace/kill avversari.
const double _kMarkerRaggioFrazione = 0.022;
const double _kMarkerBordo = 2.5;

/// Una traiettoria pronta da disegnare: coordinate normalizzate 0.0-1.0 già
/// normalizzate in direzione sx→dx, colore e forma (retta / pallonetto /
/// tocco a muro) risolti. Costruita da [buildTrajData].
class TrajData {
  final double x1, y1, x2, y2;
  final double? muroX, muroY; // coordinate normalizzate del tocco a muro
  final Color color;
  final bool isPallonetto;
  const TrajData(
    this.x1,
    this.y1,
    this.x2,
    this.y2,
    this.color, {
    this.muroX,
    this.muroY,
    this.isPallonetto = false,
  });
}

/// Colore di una traiettoria dal suo voto: verde brillante per le vincenti
/// (#), rosso per gli errori (=), bianco per il resto (in campo).
///
/// Sta qui e non nel package perché è **presentazione**: il PDF usa `PdfColor`
/// e la dashboard web avrà la sua palette, mentre la geometria è la stessa per
/// tutti (vedi `normalizzaTiro`).
Color coloreTraiettoria(Voto? voto) => switch (voto) {
  Voto.perfetto => kColoreTraiettoriaVincente,
  Voto.errore => Colors.red,
  _ => Colors.white,
};

/// Converte un [TiroScout] con traiettoria in [TrajData]. Presuppone che le
/// quattro coordinate siano non-null (filtrare prima).
///
/// Prende il tipo NEUTRO e non una riga del database: è ciò che permette a
/// questo disegno di girare identico nell'app (dove i dati vengono da drift) e
/// sul web (dove vengono da un file). La normalizzazione — specchiatura sx→dx,
/// muro, pallonetto — vive in `volley_stats`: qui resta solo il colore.
TrajData trajDataDaTiro(TiroScout tiro) {
  final t = normalizzaTiro(tiro)!;
  return TrajData(
    t.x1,
    t.y1,
    t.x2,
    t.y2,
    coloreTraiettoria(t.voto),
    muroX: t.muroX,
    muroY: t.muroY,
    isPallonetto: t.isPallonetto,
  );
}

/// Campo doppio (`double_court_bg.png`) con sopra un insieme di traiettorie
/// già filtrate — widget puro, senza filtri/Scaffold/navigazione, così è
/// riusabile: a video dentro TrajectoryReportScreen (avvolto dai dropdown) e
/// in futuro catturato in PNG, uno per giocatore, per il PDF. Riempie lo
/// spazio del parent: il campo occupa [kCourtWidthFraction] della larghezza,
/// centrato, ancorato in alto con margine [kCourtTopMargin]; [footer]
/// (mini-tabella o messaggio) viene posto sotto al campo.
class CourtTrajectoriesView extends StatelessWidget {
  final List<TrajData> trajectories;
  final Widget? footer;
  // Layer heatmap opzionale (punti d'arrivo normalizzati, stesso spazio delle
  // traiettorie) disegnato SOTTO le frecce. Con [specchia] traiettorie E
  // heatmap sono ruotate di 180° (prospettiva della nostra squadra).
  final List<Offset> heatmapPunti;
  // Punti da evidenziare con un cerchietto bordo rosso (ace/kill avversari),
  // disegnati sopra i blob. Stessa trasformazione delle traiettorie/heatmap.
  final List<Offset> markerPunti;
  final bool specchia;

  const CourtTrajectoriesView({
    super.key,
    required this.trajectories,
    this.footer,
    this.heatmapPunti = const [],
    this.markerPunti = const [],
    this.specchia = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final courtWidth = constraints.maxWidth * kCourtWidthFraction;
        final courtHeight = courtWidth / 2;
        final courtLeft = (constraints.maxWidth - courtWidth) / 2;
        const courtTop = kCourtTopMargin;

        return Stack(
          children: [
            Positioned(
              top: courtTop,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: courtWidth,
                  child: AspectRatio(
                    aspectRatio: 1200 / 600,
                    child: Image.asset(_kCourtImage, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
            if (trajectories.isNotEmpty ||
                heatmapPunti.isNotEmpty ||
                markerPunti.isNotEmpty)
              CustomPaint(
                size: constraints.biggest,
                painter: MultiTrajectoryPainter(
                  trajectories: trajectories,
                  courtLeft: courtLeft,
                  courtTop: courtTop,
                  courtWidth: courtWidth,
                  courtHeight: courtHeight,
                  heatmapPunti: heatmapPunti,
                  markerPunti: markerPunti,
                  specchia: specchia,
                ),
              ),
            if (footer != null)
              Positioned(
                top: courtTop + courtHeight + 16,
                left: 0,
                right: 0,
                child: footer!,
              ),
          ],
        );
      },
    );
  }
}

class MultiTrajectoryPainter extends CustomPainter {
  final List<TrajData> trajectories;
  final double courtLeft, courtTop, courtWidth, courtHeight;
  final List<Offset> heatmapPunti;
  final List<Offset> markerPunti;
  final bool specchia;

  MultiTrajectoryPainter({
    required this.trajectories,
    required this.courtLeft,
    required this.courtTop,
    required this.courtWidth,
    required this.courtHeight,
    this.heatmapPunti = const [],
    this.markerPunti = const [],
    this.specchia = false,
  });

  // specchia = rotazione 180° (X e Y): mostra tutto dalla prospettiva della
  // nostra squadra (arrivi/zone corrette).
  Offset _toScreen(double nx, double ny) => Offset(
    courtLeft + (specchia ? 1.0 - nx : nx) * courtWidth,
    courtTop + (specchia ? 1.0 - ny : ny) * courtHeight,
  );

  @override
  void paint(Canvas canvas, Size size) {
    // Layer heatmap (sotto le frecce): blob additivi caldi.
    if (heatmapPunti.isNotEmpty) {
      final raggio = courtWidth * _kHeatBlobRaggioFrazione;
      canvas.saveLayer(Offset.zero & size, Paint());
      for (final p in heatmapPunti) {
        final c = _toScreen(p.dx, p.dy);
        final rect = Rect.fromCircle(center: c, radius: raggio);
        final shader = RadialGradient(
          colors: [
            _kHeatBlobColore.withAlpha(alphaBlobHeatmap(heatmapPunti.length)),
            _kHeatBlobColore.withAlpha(0),
          ],
        ).createShader(rect);
        canvas.drawCircle(
          c,
          raggio,
          Paint()
            ..shader = shader
            ..blendMode = BlendMode.plus,
        );
      }
      canvas.restore();
    }
    for (final t in trajectories) {
      final inizio = _toScreen(t.x1, t.y1);
      final fine = _toScreen(t.x2, t.y2);

      final paint = Paint()
        ..color = t.color.withAlpha(220)
        ..strokeWidth = kSpessoreTraiettoria
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final Offset arrowDir;
      final muroScreen = (t.muroX != null && t.muroY != null)
          ? _toScreen(t.muroX!, t.muroY!)
          : null;

      if (muroScreen != null) {
        // Tocco a muro: due segmenti dritti con pallino sullo snodo.
        canvas.drawLine(inizio, muroScreen, paint);
        canvas.drawLine(muroScreen, fine, paint);
        canvas.drawCircle(
          muroScreen,
          5,
          Paint()..color = t.color.withAlpha(220),
        );
        arrowDir = fine - muroScreen;
      } else if (t.isPallonetto) {
        // Pallonetto: arco con bezier quadratica. Punto di controllo = punto
        // medio della traiettoria alzato di un offset fisso verso l'alto.
        // La freccia finale segue la tangente della curva in t=1 (fine−ctrl).
        final ctrl = Offset(
          (inizio.dx + fine.dx) / 2,
          (inizio.dy + fine.dy) / 2 - _kPallonettoArcOffset,
        );
        final path = Path()
          ..moveTo(inizio.dx, inizio.dy)
          ..quadraticBezierTo(ctrl.dx, ctrl.dy, fine.dx, fine.dy);
        canvas.drawPath(path, paint);
        arrowDir = fine - ctrl;
      } else {
        canvas.drawLine(inizio, fine, paint);
        arrowDir = fine - inizio;
      }

      if (arrowDir.distance >= 4) {
        final angolo = arrowDir.direction;
        const lunghezza = 10.0;
        const apertura = 0.45;
        final p1 =
            fine -
            Offset(
              lunghezza * math.cos(angolo - apertura),
              lunghezza * math.sin(angolo - apertura),
            );
        final p2 =
            fine -
            Offset(
              lunghezza * math.cos(angolo + apertura),
              lunghezza * math.sin(angolo + apertura),
            );
        canvas.drawLine(fine, p1, paint);
        canvas.drawLine(fine, p2, paint);
      }

      canvas.drawCircle(inizio, 4, Paint()..color = t.color.withAlpha(220));
    }

    // Marker ace/kill: cerchietto bordo rosso senza fill, sopra tutto.
    if (markerPunti.isNotEmpty) {
      final raggio = courtWidth * _kMarkerRaggioFrazione;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.red
        ..strokeWidth = _kMarkerBordo;
      for (final p in markerPunti) {
        canvas.drawCircle(_toScreen(p.dx, p.dy), raggio, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant MultiTrajectoryPainter old) =>
      old.trajectories != trajectories ||
      old.heatmapPunti != heatmapPunti ||
      old.markerPunti != markerPunti ||
      old.specchia != specchia ||
      old.courtLeft != courtLeft ||
      old.courtTop != courtTop;
}

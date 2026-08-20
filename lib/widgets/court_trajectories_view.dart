import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:volley_stats/traiettoria.dart';

import '../data/database.dart';
import '../logic/heatmap.dart' show tiroDaRiga;
import '../models/enums.dart';
import '../theme/court_style.dart';

const _kCourtImage = 'assets/images/double_court_bg.png';

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
  const TrajData(this.x1, this.y1, this.x2, this.y2, this.color,
      {this.muroX, this.muroY, this.isPallonetto = false});
}

/// Colore di una traiettoria dal suo voto: verde brillante per le vincenti
/// (#), rosso per gli errori (=), bianco per il resto (in campo).
///
/// Sta qui e non nel package perché è **presentazione**: il PDF usa `PdfColor`
/// e la dashboard web avrà la sua palette, mentre la geometria è la stessa per
/// tutti (vedi `normalizzaTiro`).
Color coloreTraiettoria(Voto? voto) => switch (voto) {
      Voto.perfetto => CourtStyle.trajectoryAce,
      Voto.errore => Colors.red,
      _ => Colors.white,
    };

/// Converte una [ScoutAction] con traiettoria in [TrajData]. Presuppone che
/// le quattro coordinate `traiettoria*` siano non-null (filtrare prima con
/// il controllo su X1/Y1/X2/Y2).
///
/// La normalizzazione (specchiatura sx→dx, muro, pallonetto) vive in
/// `packages/volley_stats`: qui resta solo la scelta del colore.
TrajData buildTrajData(ScoutAction a) {
  final t = normalizzaTiro(tiroDaRiga(a))!;
  return TrajData(t.x1, t.y1, t.x2, t.y2, coloreTraiettoria(t.voto),
      muroX: t.muroX, muroY: t.muroY, isPallonetto: t.isPallonetto);
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
    return LayoutBuilder(builder: (context, constraints) {
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
    });
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
        final shader = RadialGradient(colors: [
          _kHeatBlobColore.withAlpha(_kHeatBlobAlpha),
          _kHeatBlobColore.withAlpha(0),
        ]).createShader(rect);
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
        ..strokeWidth = CourtStyle.trajectoryWidth
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
            muroScreen, 5, Paint()..color = t.color.withAlpha(220));
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
        final p1 = fine -
            Offset(
              lunghezza * math.cos(angolo - apertura),
              lunghezza * math.sin(angolo - apertura),
            );
        final p2 = fine -
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

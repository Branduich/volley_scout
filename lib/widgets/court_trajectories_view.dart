import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/database.dart';
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

/// Converte una [ScoutAction] con traiettoria in [TrajData]. Presuppone che
/// le quattro coordinate `traiettoria*` siano non-null (filtrare prima con
/// il controllo su X1/Y1/X2/Y2). Normalizza: partenza sempre da sinistra
/// (x1 < 0.5). Verde brillante per le azioni vincenti (#), rosso per gli
/// errori (=), bianco per il resto (in campo).
TrajData buildTrajData(ScoutAction a) {
  var x1 = a.traiettoriaX1!;
  var y1 = a.traiettoriaY1!;
  var x2 = a.traiettoriaX2!;
  var y2 = a.traiettoriaY2!;
  final shouldMirror = x1 > 0.5;
  if (shouldMirror) {
    x1 = 1.0 - x1;
    y1 = 1.0 - y1;
    x2 = 1.0 - x2;
    y2 = 1.0 - y2;
  }
  // Il tocco a muro va specchiato come il resto della traiettoria.
  double? muroX = a.traiettoriaMuroX;
  double? muroY = a.traiettoriaMuroY;
  if (shouldMirror && muroX != null && muroY != null) {
    muroX = 1.0 - muroX;
    muroY = 1.0 - muroY;
  }
  final Color color;
  if (a.voto == Voto.perfetto) {
    color = CourtStyle.trajectoryAce;
  } else if (a.voto == Voto.errore) {
    color = Colors.red;
  } else {
    color = Colors.white;
  }
  final isPallonetto = a.tipoEsecuzione == TipoAttacco.pallonetto.name;
  return TrajData(x1, y1, x2, y2, color,
      muroX: muroX, muroY: muroY, isPallonetto: isPallonetto);
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

  const CourtTrajectoriesView({
    super.key,
    required this.trajectories,
    this.footer,
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
          if (trajectories.isNotEmpty)
            CustomPaint(
              size: constraints.biggest,
              painter: MultiTrajectoryPainter(
                trajectories: trajectories,
                courtLeft: courtLeft,
                courtTop: courtTop,
                courtWidth: courtWidth,
                courtHeight: courtHeight,
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

  MultiTrajectoryPainter({
    required this.trajectories,
    required this.courtLeft,
    required this.courtTop,
    required this.courtWidth,
    required this.courtHeight,
  });

  Offset _toScreen(double nx, double ny) => Offset(
        courtLeft + nx * courtWidth,
        courtTop + ny * courtHeight,
      );

  @override
  void paint(Canvas canvas, Size size) {
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
  }

  @override
  bool shouldRepaint(covariant MultiTrajectoryPainter old) =>
      old.trajectories != trajectories ||
      old.courtLeft != courtLeft ||
      old.courtTop != courtTop;
}

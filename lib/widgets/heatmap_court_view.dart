import 'package:flutter/material.dart';

import 'court_trajectories_view.dart' show kCourtWidthFraction, kCourtTopMargin;

const _kCourtImage = 'assets/images/double_court_bg.png';

// Blob della heatmap (tunable). Colore caldo a tinta unica disegnato in blend
// ADDITIVO (BlendMode.plus) dentro un saveLayer: dove cadono più palle i blob
// si sommano e la zona "scalda"; dove ne cadono poche resta tenue. Raggio
// proporzionale alla larghezza del campo.
const Color _kBlobColore = Color(0xFFFF3D00);
const int _kBlobAlpha = 110;
const double _kBlobRaggioFrazione = 0.065;

/// Campo doppio (`double_court_bg.png`) con sopra una **heatmap a blob** dei
/// punti d'arrivo (già filtrati/normalizzati da `puntiArrivoAvversari`, nello
/// spazio 1200×600 → metà destra = nostro campo). Con [specchia] la heatmap è
/// ruotata di 180° (specchio X e Y) per mostrarla dalla NOSTRA prospettiva —
/// così le zone tornano corrette. Widget puro, stessa geometria di
/// `CourtTrajectoriesView`. [footer] sotto al campo.
class HeatmapCourtView extends StatelessWidget {
  final List<Offset> punti;
  final Widget? footer;
  final bool specchia;

  const HeatmapCourtView({
    super.key,
    required this.punti,
    this.footer,
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
          if (punti.isNotEmpty)
            CustomPaint(
              size: constraints.biggest,
              painter: HeatmapPainter(
                punti: punti,
                courtLeft: courtLeft,
                courtTop: courtTop,
                courtWidth: courtWidth,
                courtHeight: courtHeight,
                raggio: courtWidth * _kBlobRaggioFrazione,
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

class HeatmapPainter extends CustomPainter {
  final List<Offset> punti;
  final double courtLeft, courtTop, courtWidth, courtHeight, raggio;
  final bool specchia;

  HeatmapPainter({
    required this.punti,
    required this.courtLeft,
    required this.courtTop,
    required this.courtWidth,
    required this.courtHeight,
    required this.raggio,
    this.specchia = false,
  });

  // specchia = rotazione 180° (X e Y) per la prospettiva della nostra squadra.
  Offset _toScreen(double nx, double ny) => Offset(
        courtLeft + (specchia ? 1.0 - nx : nx) * courtWidth,
        courtTop + (specchia ? 1.0 - ny : ny) * courtHeight,
      );

  @override
  void paint(Canvas canvas, Size size) {
    if (punti.isEmpty) return;
    // Layer separato: il blend additivo dei blob avviene tra loro, poi il
    // risultato è composto sul campo senza "bruciarlo".
    canvas.saveLayer(Offset.zero & size, Paint());
    for (final p in punti) {
      final c = _toScreen(p.dx, p.dy);
      final rect = Rect.fromCircle(center: c, radius: raggio);
      final shader = RadialGradient(
        colors: [
          _kBlobColore.withAlpha(_kBlobAlpha), // centro caldo
          _kBlobColore.withAlpha(0), // bordo trasparente
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

  @override
  bool shouldRepaint(covariant HeatmapPainter old) =>
      old.punti != punti ||
      old.raggio != raggio ||
      old.specchia != specchia ||
      old.courtLeft != courtLeft ||
      old.courtTop != courtTop;
}

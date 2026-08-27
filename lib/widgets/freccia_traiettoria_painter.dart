import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/court_style.dart';

/// Freccia della traiettoria che si sta disegnando: linea (o arco, o due
/// segmenti col tocco a muro) + punta a V + pallino sul punto di partenza.
///
/// Estratta da `TrajectoryScreen`, dove era privata, perché ora la disegnano in
/// due: la schermata dedicata e — per la battuta, quando l'impostazione
/// sperimentale è accesa — lo scout live, direttamente sopra al campo (vedi
/// `Impostazioni.traiettoriaBattutaInLine`). Averne una copia sola è ciò che
/// impedisce alle due strade di divergere mentre le si confronta.
///
/// Lavora in coordinate **assolute** dello Stack che lo ospita, non
/// normalizzate: chi lo usa gli passa i punti già nello spazio in cui disegna.
class FrecciaTraiettoriaPainter extends CustomPainter {
  final Offset inizio;
  final Offset fine;

  /// Punto di tocco a muro (solo attacco) — se non null, la freccia si disegna
  /// a due segmenti (inizio→muro, muro→fine) con uno snodo lì, invece di una
  /// linea unica dritta.
  final Offset? puntoMuro;

  /// Se true la freccia è un arco (bezier quadratica) — solo quando non c'è un
  /// muro: i due segmenti del muro prevalgono.
  final bool isPallonetto;

  const FrecciaTraiettoriaPainter(
    this.inizio,
    this.fine,
    this.puntoMuro, {
    this.isPallonetto = false,
  });

  static const _kArcOffset = 40.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = CourtStyle.trajectoryArrow
      ..strokeWidth = CourtStyle.trajectoryWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final muro = puntoMuro;

    // Direzione per la punta della freccia: calcolata dopo aver scelto come
    // disegnare il corpo (linea, arco o due segmenti col muro).
    final Offset arrowDir;

    if (muro != null) {
      // Muro: due segmenti dritti, l'arco non si applica.
      canvas.drawLine(inizio, muro, paint);
      canvas.drawLine(muro, fine, paint);
      canvas.drawCircle(muro, 5, Paint()..color = CourtStyle.trajectoryArrow);
      arrowDir = fine - muro;
    } else if (isPallonetto) {
      // Pallonetto: arco con bezier quadratica, punto di controllo alzato al
      // centro della traiettoria.
      final ctrl = Offset(
        (inizio.dx + fine.dx) / 2,
        (inizio.dy + fine.dy) / 2 - _kArcOffset,
      );
      final path = Path()
        ..moveTo(inizio.dx, inizio.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, fine.dx, fine.dy);
      canvas.drawPath(path, paint);
      arrowDir = fine - ctrl; // tangente in t=1
    } else {
      canvas.drawLine(inizio, fine, paint);
      arrowDir = fine - inizio;
    }

    // Punta della freccia ancorata al punto di arrivo, nella direzione
    // dell'ultimo segmento (o della tangente della curva per il pallonetto).
    if (arrowDir.distance < 1) return;
    final angolo = arrowDir.direction;
    const lunghezzaPunta = 16.0;
    const apertura = 0.45;
    final p1 = fine -
        Offset(
          lunghezzaPunta * math.cos(angolo - apertura),
          lunghezzaPunta * math.sin(angolo - apertura),
        );
    final p2 = fine -
        Offset(
          lunghezzaPunta * math.cos(angolo + apertura),
          lunghezzaPunta * math.sin(angolo + apertura),
        );
    canvas.drawLine(fine, p1, paint);
    canvas.drawLine(fine, p2, paint);

    canvas.drawCircle(inizio, 5, Paint()..color = CourtStyle.trajectoryArrow);
  }

  @override
  bool shouldRepaint(covariant FrecciaTraiettoriaPainter oldDelegate) =>
      oldDelegate.inizio != inizio ||
      oldDelegate.fine != fine ||
      oldDelegate.puntoMuro != puntoMuro ||
      oldDelegate.isPallonetto != isPallonetto;
}

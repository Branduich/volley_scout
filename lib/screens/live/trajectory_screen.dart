import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../models/enums.dart';
import '../../theme/court_style.dart';

const _kCourtImage = 'assets/images/double_court_bg.png';

// Stesso sfondo/barra superiore di ScoutScreen, duplicati qui per coerenza
// visiva tra le due schermate (vedi scout_screen.dart).
const _kBg = Color(0xFF143E59);
const _kTopBarBg = Color(0xFF0D2738);

// Stessa dimensione/posizionamento del campo in ScoutScreen (58% della
// larghezza disponibile, ancorato in alto con margine fisso 16px — non
// centrato verticalmente) per coerenza visiva tra le due schermate, vedi
// scout_screen.dart.
const double _kCourtWidthFraction = 0.58;
const double _kCourtTopMargin = 16.0;

/// Coordinate normalizzate (0.0-1.0) di una traiettoria, rispetto al campo
/// intero (rete a x=0.5) — stesso spazio di riferimento usato altrove in
/// ScoutScreen per le posizioni dei token.
typedef Traiettoria = ({double x1, double y1, double x2, double y2});

/// Schermata dedicata per registrare la traiettoria di una battuta/attacco
/// (Fase 3, "PROSSIMO" in CLAUDE.md) — campo vuoto, drag dal punto di
/// partenza a quello di arrivo. Nessun bottone "Salta"/"Conferma": il back
/// (automatico, AppBar) chiude la schermata senza traiettoria
/// (`Navigator.pop` con `null` di default — "salta"), il rilascio del drag
/// la conferma subito (`Navigator.pop(context, risultato)`).
class TrajectoryScreen extends StatefulWidget {
  // Giocatore/fondamentale/voto dell'azione in corso (non ancora
  // registrata — vedi ScoutScreen._registraVoto), solo per mostrare lo
  // stesso banner di ScoutScreen mentre si imposta la traiettoria.
  final Player giocatore;
  final Fondamentale fondamentale;
  final Voto voto;

  const TrajectoryScreen({
    super.key,
    required this.giocatore,
    required this.fondamentale,
    required this.voto,
  });

  @override
  State<TrajectoryScreen> createState() => _TrajectoryScreenState();
}

class _TrajectoryScreenState extends State<TrajectoryScreen> {
  Offset? _inizio;
  Offset? _attuale;

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _inizio = details.localPosition;
      _attuale = details.localPosition;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() => _attuale = details.localPosition);
  }

  void _onPanEnd(DragEndDetails details, Size campoSize) {
    final inizio = _inizio;
    final fine = _attuale;
    if (inizio == null || fine == null) return;
    final risultato = (
      x1: inizio.dx / campoSize.width,
      y1: inizio.dy / campoSize.height,
      x2: fine.dx / campoSize.width,
      y2: fine.dy / campoSize.height,
    );
    Navigator.pop(context, risultato);
  }

  // Stesso testo/stile/colore di ScoutScreen._descrizioneAzione per il caso
  // TipoAzione.scout (qui l'azione non è ancora un ScoutAction salvato,
  // quindi si formatta direttamente da giocatore/fondamentale/voto).
  Widget _buildBanner() {
    final testo =
        '${widget.giocatore.numero} - ${widget.giocatore.cognome} - ${widget.fondamentale.label}';
    final voto = widget.voto.simbolo;
    final colore = CourtStyle.votoColor(widget.voto);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: colore,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            testo,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              height: 1.0,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            voto,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          // Stessa barra superiore (colore/altezza/stile titolo) di
          // ScoutScreen — qui solo back (niente menu/undo/punteggio, non
          // pertinenti su questa schermata), stesso ancoraggio in basso del
          // titolo.
          Container(
            height: 60,
            color: _kTopBarBg,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                const Positioned(
                  left: 56,
                  right: 56,
                  bottom: 4,
                  child: Text(
                    'Imposta traiettoria',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
          // Spazio equivalente alla riga dei bottoni rapidi di ScoutScreen
          // (Padding verticale 8 + bottoni 44 + 8 = 60px), assente qui —
          // senza questo spacer banner e campo risulterebbero più in alto
          // che in ScoutScreen, a parità di margine interno del campo.
          const SizedBox(height: 60),
          // Stesso banner di ScoutScreen (_buildBannerUltimaAzione), qui
          // sull'azione in corso (non ancora registrata) invece che
          // sull'ultima già salvata — stessa altezza fissa 36 per non far
          // saltare il campo sottostante.
          SizedBox(
            height: 36,
            child: Center(child: _buildBanner()),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, screenConstraints) {
                final courtWidth =
                    screenConstraints.maxWidth * _kCourtWidthFraction;
                return Stack(
                  children: [
                    Positioned(
                      top: _kCourtTopMargin,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: SizedBox(
                          width: courtWidth,
                          child: AspectRatio(
                            aspectRatio: 1200 / 600,
                            child: LayoutBuilder(
                              builder: (context, courtConstraints) {
                                final campoSize = courtConstraints.biggest;
                                return GestureDetector(
                                  onPanStart: _onPanStart,
                                  onPanUpdate: _onPanUpdate,
                                  onPanEnd: (details) =>
                                      _onPanEnd(details, campoSize),
                                  child: Stack(
                                    children: [
                                      Image.asset(_kCourtImage,
                                          fit: BoxFit.contain),
                                      if (_inizio != null && _attuale != null)
                                        CustomPaint(
                                          size: campoSize,
                                          painter: _FrecciaTraiettoriaPainter(
                                              _inizio!, _attuale!),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FrecciaTraiettoriaPainter extends CustomPainter {
  final Offset inizio;
  final Offset fine;

  _FrecciaTraiettoriaPainter(this.inizio, this.fine);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = CourtStyle.trajectoryArrow
      ..strokeWidth = CourtStyle.trajectoryWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(inizio, fine, paint);

    // Punta della freccia: due segmenti corti angolati rispetto alla
    // direzione della linea, ancorati al punto di arrivo.
    final direzione = fine - inizio;
    if (direzione.distance < 1) return;
    final angolo = direzione.direction;
    const lunghezzaPunta = 16.0;
    const apertura = 0.45; // radianti
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

    final puntoPaint = Paint()..color = CourtStyle.trajectoryArrow;
    canvas.drawCircle(inizio, 5, puntoPaint);
  }

  @override
  bool shouldRepaint(covariant _FrecciaTraiettoriaPainter oldDelegate) =>
      oldDelegate.inizio != inizio || oldDelegate.fine != fine;
}

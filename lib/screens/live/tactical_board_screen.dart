import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../models/jersey_colors.dart';

const _kCourtImage = 'assets/images/double_court_bg.png';

// Stesso sfondo/barra/campo di TrajectoryScreen (costanti duplicate per
// coerenza visiva tra le schermate live, stesso pattern già usato).
const _kBg = Color(0xFF143E59);
const _kTopBarBg = Color(0xFF0D2738);
// Campo ~10% più largo della lavagna traiettorie (0.58) e con più margine
// dall'alto: qui non c'è la riga chip sotto al campo, c'è spazio per i
// giocatori che partono fuori dal campo, in basso.
const double _kCourtWidthFraction = 0.64;
const double _kCourtTopMargin = 32.0;

// Colore invertito canale per canale rispetto al colore squadra — per la chip
// del libero (maglia di colore diverso). Stessa funzione duplicata in
// lineup/scout (pattern deliberato, vedi CLAUDE.md).
Color _invertedColor(Color color) => Color.from(
  alpha: color.a,
  red: 1.0 - color.r,
  green: 1.0 - color.g,
  blue: 1.0 - color.b,
);

// Le 7 chip (6 ruoli + libero) e le loro posizioni di default, normalizzate
// 0–1 sull'INTERA area disponibile (non sul campo): partono FUORI dal campo,
// in una fila ravvicinata in basso a sinistra, e da lì si trascinano
// liberamente ovunque (anche dentro/fuori il campo). Passo 0.05 (chip quasi
// a contatto), ordine sinistra→destra.
const Map<String, Offset> _kChipDefault = {
  'P': Offset(0.19, 0.78),
  'O': Offset(0.24, 0.78),
  'S1': Offset(0.29, 0.78),
  'S2': Offset(0.34, 0.78),
  'C1': Offset(0.39, 0.78),
  'C2': Offset(0.44, 0.78),
  'L': Offset(0.49, 0.78),
};

// Colori del tratto (penne in header) — bianco/rosso/verde. Verde brillante
// (non AppColors.success, troppo scuro sul campo azzurro chiaro) per restare
// ben visibile.
const List<Color> _kColoriTratto = [
  Colors.white,
  Colors.red,
  Color.fromARGB(255, 0, 255, 94),
];

// Un tratto disegnato: polilinea di punti normalizzati + il suo colore.
typedef _Tratto = ({List<Offset> punti, Color colore});

/// Lavagna tattica (raggiunta dal drawer di ScoutScreen, funzione premium):
/// campo su cui trascinare le chip dei ruoli nella propria metà e disegnare
/// linee a mano libera durante il timeout. Effimera: nessuna persistenza, si
/// chiude col back. Riusa l'impaginazione del campo di TrajectoryScreen ma con
/// interazione dedicata (chip trascinabili + disegno).
class TacticalBoardScreen extends StatefulWidget {
  final Team team;

  const TacticalBoardScreen({super.key, required this.team});

  @override
  State<TacticalBoardScreen> createState() => _TacticalBoardScreenState();
}

class _TacticalBoardScreenState extends State<TacticalBoardScreen> {
  // Posizioni correnti delle chip (normalizzate sul campo intero).
  late Map<String, Offset> _chip = Map.of(_kChipDefault);

  // Tratti disegnati (ognuno una polilinea di punti normalizzati + il proprio
  // colore) + quello in corso durante il drag (usa _coloreTratto corrente).
  final List<_Tratto> _tratti = [];
  List<Offset>? _lineaCorrente;

  // Colore del tratto selezionato in header (default bianco).
  Color _coloreTratto = _kColoriTratto.first;

  // Chip trascinata nel drag corrente (null = si sta disegnando una linea).
  String? _chipTrascinata;

  bool get _boardVuota => _tratti.isEmpty && _lineaCorrente == null;

  void _annullaUltimoTratto() {
    if (_tratti.isEmpty) return;
    setState(() => _tratti.removeLast());
  }

  void _pulisciBoard() {
    setState(() {
      _tratti.clear();
      _lineaCorrente = null;
      _chip = Map.of(_kChipDefault);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                // Stesso dimensionamento di TrajectoryScreen: 58% della
                // larghezza, mai più alto dello spazio disponibile.
                final courtWidth = _minDouble(
                  c.maxWidth * _kCourtWidthFraction,
                  (c.maxHeight - _kCourtTopMargin - 8) * 2,
                );
                final courtHeight = courtWidth / 2; // aspect 1200/600
                const courtTop = _kCourtTopMargin;

                // Chip e linee sono normalizzate sull'INTERA area (0–1 di
                // maxWidth/maxHeight), non sul campo: così i giocatori si
                // dispongono anche fuori dal campo e partono dalla fila in
                // basso. Il campo resta solo lo sfondo (centrato, courtTop).
                final r = courtHeight * 0.06;
                final rNormX = r / c.maxWidth;
                final rNormY = r / c.maxHeight;

                Offset toNorm(Offset local) =>
                    Offset(local.dx / c.maxWidth, local.dy / c.maxHeight);
                Offset toPixel(Offset norm) =>
                    Offset(norm.dx * c.maxWidth, norm.dy * c.maxHeight);

                void onPanStart(DragStartDetails d) {
                  final p = d.localPosition;
                  // Chip più vicina entro il raggio (in pixel) → la si
                  // trascina; altrimenti si inizia una linea.
                  String? colpita;
                  var minDist = r * 1.3;
                  for (final e in _chip.entries) {
                    final dist = (toPixel(e.value) - p).distance;
                    if (dist < minDist) {
                      minDist = dist;
                      colpita = e.key;
                    }
                  }
                  setState(() {
                    if (colpita != null) {
                      _chipTrascinata = colpita;
                    } else {
                      _chipTrascinata = null;
                      _lineaCorrente = [toNorm(p)];
                    }
                  });
                }

                void onPanUpdate(DragUpdateDetails d) {
                  final n = toNorm(d.localPosition);
                  setState(() {
                    final chip = _chipTrascinata;
                    if (chip != null) {
                      // Nessun vincolo al campo: si dispone ovunque, clampata
                      // solo all'area visibile per non perderla fuori schermo.
                      _chip[chip] = Offset(
                        n.dx.clamp(rNormX, 1 - rNormX),
                        n.dy.clamp(rNormY, 1 - rNormY),
                      );
                    } else {
                      _lineaCorrente?.add(n);
                    }
                  });
                }

                void onPanEnd(DragEndDetails d) {
                  setState(() {
                    final linea = _lineaCorrente;
                    if (linea != null && linea.length > 1) {
                      _tratti.add((punti: linea, colore: _coloreTratto));
                    }
                    _lineaCorrente = null;
                    _chipTrascinata = null;
                  });
                }

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: onPanStart,
                  onPanUpdate: onPanUpdate,
                  onPanEnd: onPanEnd,
                  child: Stack(
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
                              child: Image.asset(
                                _kCourtImage,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                      CustomPaint(
                        size: c.biggest,
                        painter: _LavagnaPainter(
                          tratti: _tratti,
                          lineaCorrente: _lineaCorrente,
                          coloreCorrente: _coloreTratto,
                          toPixel: toPixel,
                        ),
                      ),
                      for (final e in _chip.entries)
                        _buildChip(e.key, toPixel(e.value), r),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 80,
      color: _kTopBarBg,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          const Positioned(
            left: 220,
            right: 112,
            bottom: 4,
            child: Text(
              'Lavagna tattica',
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
          // Sinistra: back + le 3 penne colore (bianco/rosso/verde).
          Positioned(
            left: 0,
            bottom: 0,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                for (final colore in _kColoriTratto) _buildPenna(colore),
              ],
            ),
          ),
          // Destra: annulla ultimo tratto + pulisci board.
          Positioned(
            right: 0,
            bottom: 0,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.undo),
                  color: Colors.white,
                  disabledColor: Colors.white24,
                  tooltip: 'Annulla ultimo tratto',
                  onPressed: _tratti.isEmpty ? null : _annullaUltimoTratto,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.white,
                  disabledColor: Colors.white24,
                  tooltip: 'Pulisci la board',
                  onPressed: _boardVuota && _mapEquals(_chip, _kChipDefault)
                      ? null
                      : _pulisciBoard,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Penna colore in header: icona pennello tinta col colore, cerchio di
  // sfondo bianco tenue quando è quella selezionata.
  Widget _buildPenna(Color colore) {
    final selezionata = _coloreTratto == colore;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selezionata ? Colors.white24 : Colors.transparent,
      ),
      child: IconButton(
        icon: Icon(Icons.create, color: colore),
        tooltip: 'Colore tratto',
        onPressed: () => setState(() => _coloreTratto = colore),
      ),
    );
  }

  // Chip circolare col colore squadra (libero invertito) + etichetta ruolo.
  // Solo visuale: il drag è gestito dal GestureDetector esterno.
  Widget _buildChip(String ruolo, Offset center, double r) {
    final teamColor = Color(widget.team.coloreDivisa);
    final base = ruolo == 'L' ? _invertedColor(teamColor) : teamColor;
    return Positioned(
      left: center.dx - r,
      top: center.dy - r,
      width: r * 2,
      height: r * 2,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: base,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(120),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          ruolo,
          style: TextStyle(
            color: contrastingTextColor(base),
            fontWeight: FontWeight.bold,
            fontSize: r * 0.7,
          ),
        ),
      ),
    );
  }
}

double _minDouble(double a, double b) => a < b ? a : b;

bool _mapEquals(Map<String, Offset> a, Map<String, Offset> b) {
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    if (b[e.key] != e.value) return false;
  }
  return true;
}

class _LavagnaPainter extends CustomPainter {
  final List<_Tratto> tratti;
  final List<Offset>? lineaCorrente;
  final Color coloreCorrente;
  final Offset Function(Offset) toPixel;

  _LavagnaPainter({
    required this.tratti,
    required this.lineaCorrente,
    required this.coloreCorrente,
    required this.toPixel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    void disegna(List<Offset> punti, Color colore) {
      if (punti.length < 2) return;
      final paint = Paint()
        ..color = colore
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path()
        ..moveTo(toPixel(punti.first).dx, toPixel(punti.first).dy);
      for (final p in punti.skip(1)) {
        final px = toPixel(p);
        path.lineTo(px.dx, px.dy);
      }
      canvas.drawPath(path, paint);
    }

    for (final t in tratti) {
      disegna(t.punti, t.colore);
    }
    final corrente = lineaCorrente;
    if (corrente != null) disegna(corrente, coloreCorrente);
  }

  // Sempre true: le liste sono mutate in place (stessa reference), quindi un
  // confronto per reference non coglierebbe disegno/undo/clear. Ridisegnare
  // poche polilinee ad ogni setState è trascurabile.
  @override
  bool shouldRepaint(covariant _LavagnaPainter old) => true;
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../models/enums.dart';
import '../../theme/app_colors.dart';

const _kBg = Color(0xFF143E59);
const _kTopBarBg = Color(0xFF0D2738);
const _kCourtImage = 'assets/images/double_court_bg.png';
const _kSmallCourtImage = 'assets/images/small_court.png';

// Ancoraggio del badge di rotazione sul campo piccolo, per slot del
// palleggiatore. Il campo piccolo è ruotato di 90° in senso orario rispetto
// a LineupScreen: P1 basso-sx, P2 basso-dx, P3 centro-dx (lato rete),
// P4 alto-dx, P5 alto-sx, P6 centro-sx — in senso antiorario da P1.
const Map<String, Alignment> _kRotationBadgeAnchor = {
  'P1': Alignment.bottomLeft,
  'P2': Alignment.bottomRight,
  'P3': Alignment.centerRight,
  'P4': Alignment.topRight,
  'P5': Alignment.topLeft,
  'P6': Alignment.centerLeft,
};

// Posizioni di attacco dei 6 giocatori sul campo grande, in coordinate di
// riferimento rispetto all'immagine double_court_bg.png (1200×600 — ogni
// singolo campo è quindi un quadrato 600×600). Da estendere in futuro con le
// posizioni di ricezione.
const Map<String, Offset> _kAttackPositions = {
  'P1': Offset(200, 470),
  'P2': Offset(530, 470),
  'P3': Offset(530, 300),
  'P4': Offset(530, 130),
  'P5': Offset(200, 130),
  'P6': Offset(200, 300),
};

// Ordine antiorario degli slot sul campo grande (verificato sulle coordinate
// di _kAttackPositions), usato per calcolare la distanza dal palleggiatore.
const List<String> _kSlotOrder = ['P1', 'P2', 'P3', 'P4', 'P5', 'P6'];

// Modulo che gestisce correttamente anche valori negativi (a differenza di
// `%` in Dart, che mantiene il segno dell'operando).
int _mod(int a, int n) => ((a % n) + n) % n;

// Etichette di ruolo per ogni slot, basate sul ruolo REALE del giocatore
// assegnato (non su un pattern fisso): il palleggiatore è sempre "P",
// l'opposto è sempre "O". Tra i due schiacciatori, quello più vicino al
// palleggiatore (in senso antiorario) è "S1", l'altro (diametralmente
// opposto, a 3 posizioni di distanza) è "S2" — stessa logica per i centrali
// ("C1"/"C2"). Permette anche formazioni dove un centrale, non uno
// schiacciatore, si trova subito dopo il palleggiatore.
Map<String, String> _roleLabelsFor(
    String palleggiatoreSlot, Map<String, Player> assignments) {
  final startIndex = _kSlotOrder.indexOf(palleggiatoreSlot);
  int distanceFromP(String slot) =>
      (_kSlotOrder.indexOf(slot) - startIndex + _kSlotOrder.length) %
      _kSlotOrder.length;

  final schiacciatori = <String>[];
  final centrali = <String>[];
  String? opposto;

  for (final slot in _kSlotOrder) {
    if (slot == palleggiatoreSlot) continue;
    switch (assignments[slot]?.ruolo) {
      case Ruolo.opposto:
        opposto = slot;
      case Ruolo.schiacciatore:
        schiacciatori.add(slot);
      case Ruolo.centrale:
        centrali.add(slot);
      default:
        break;
    }
  }
  schiacciatori.sort((a, b) => distanceFromP(a).compareTo(distanceFromP(b)));
  centrali.sort((a, b) => distanceFromP(a).compareTo(distanceFromP(b)));

  final labels = <String, String>{palleggiatoreSlot: 'P'};
  if (opposto != null) labels[opposto] = 'O';
  if (schiacciatori.isNotEmpty) labels[schiacciatori[0]] = 'S1';
  if (schiacciatori.length > 1) labels[schiacciatori[1]] = 'S2';
  if (centrali.isNotEmpty) labels[centrali[0]] = 'C1';
  if (centrali.length > 1) labels[centrali[1]] = 'C2';
  return labels;
}

// Esagono con angoli arrotondati, inscritto nel quadrato `size` (stesso
// raggio centro-vertice dei token circolari, per coerenza di ingombro).
// Usato per distinguere il palleggiatore, ruolo chiave della formazione.
Path _roundedHexagonPath(Size size, double cornerRadius) {
  final center = Offset(size.width / 2, size.height / 2);
  final radius = size.shortestSide / 2 - 1;
  const sides = 6;
  final points = List.generate(sides, (i) {
    final angle = -math.pi / 2 + i * (2 * math.pi / sides);
    return center + Offset(math.cos(angle), math.sin(angle)) * radius;
  });

  final path = Path();
  for (var i = 0; i < sides; i++) {
    final prev = points[(i - 1 + sides) % sides];
    final curr = points[i];
    final next = points[(i + 1) % sides];

    final toPrev = prev - curr;
    final toNext = next - curr;
    final start = curr + toPrev / toPrev.distance * cornerRadius;
    final end = curr + toNext / toNext.distance * cornerRadius;

    if (i == 0) {
      path.moveTo(start.dx, start.dy);
    } else {
      path.lineTo(start.dx, start.dy);
    }
    path.quadraticBezierTo(curr.dx, curr.dy, end.dx, end.dy);
  }
  path.close();
  return path;
}

class _RoundedHexagonPainter extends CustomPainter {
  final Color color;
  const _RoundedHexagonPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = _roundedHexagonPath(size, size.shortestSide * 0.08);
    canvas.drawShadow(path, Colors.black, 3, false);
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _RoundedHexagonPainter oldDelegate) =>
      oldDelegate.color != color;
}

class ScoutScreen extends StatefulWidget {
  final VolleyMatch match;
  final Team team;
  final String palleggiatoreSlot;
  final Map<String, Player> assignments;

  const ScoutScreen({
    super.key,
    required this.match,
    required this.team,
    required this.palleggiatoreSlot,
    required this.assignments,
  });

  @override
  State<ScoutScreen> createState() => _ScoutScreenState();
}

class _ScoutScreenState extends State<ScoutScreen> {
  // Numero di rotazioni applicate da inizio set (positivo = avanti, P1→P2;
  // negativo = indietro, P1→P6). Tutti i giocatori ruotano insieme: chi era
  // nello slot di indice i si trova ora nello slot di indice i+_rotationSteps.
  int _rotationSteps = 0;

  String get _currentSlot {
    final originalIndex = _kSlotOrder.indexOf(widget.palleggiatoreSlot);
    return _kSlotOrder[_mod(originalIndex + _rotationSteps, _kSlotOrder.length)];
  }

  // Mappa slot -> giocatore aggiornata in base alla rotazione corrente.
  Map<String, Player> get _currentAssignments {
    final n = _kSlotOrder.length;
    final result = <String, Player>{};
    for (var j = 0; j < n; j++) {
      final originalSlot = _kSlotOrder[_mod(j - _rotationSteps, n)];
      final player = widget.assignments[originalSlot];
      if (player != null) result[_kSlotOrder[j]] = player;
    }
    return result;
  }

  void _rotateBackward() => setState(() => _rotationSteps--);

  void _rotateForward() => setState(() => _rotationSteps++);

  // Quando la squadra ataca dal campo di destra, le posizioni vanno
  // riflesse rispetto al centro dell'immagine doppia (rotazione di 180°,
  // non un semplice mirror orizzontale): chi era in basso a sinistra finisce
  // in alto a destra. Coordinate di riferimento 1200×600.
  bool _isRightSide = false;

  void _toggleSide() => setState(() => _isRightSide = !_isRightSide);

  Offset _displayPosition(Offset refPos) => _isRightSide
      ? Offset(1200 - refPos.dx, 600 - refPos.dy)
      : refPos;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          Container(
            height: 60,
            color: _kTopBarBg,
            child: Row(
              children: [
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Container(
            height: 48,
            color: _kBg,
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: _toggleSide,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF00008A),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(120),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.swap_horiz,
                    color: Colors.white, size: 22),
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Margine sinistro/destro del 15% dello schermo: il campo
                // occupa il restante 70% della larghezza, centrato.
                final courtWidth = constraints.maxWidth * 0.7;
                // Campo piccolo: 5% di margine da top e 3% da left
                // larghezza massima del 7% dello schermo (per mantenere proporzioni con il campo grande)
                final smallCourtSize = constraints.maxWidth * 0.07;
                return Stack(
                  children: [
                    Center(
                      child: SizedBox(
                        width: courtWidth,
                        child: AspectRatio(
                          aspectRatio: 1200 / 600,
                          child: LayoutBuilder(
                            builder: (context, courtConstraints) {
                              final cw = courtConstraints.maxWidth;
                              final ch = courtConstraints.maxHeight;
                              final roleLabels = _roleLabelsFor(
                                  _currentSlot, _currentAssignments);
                              return Stack(
                                children: [
                                  Image.asset(_kCourtImage,
                                      fit: BoxFit.contain),
                                  for (final entry
                                      in _kAttackPositions.entries)
                                    _buildPlayerToken(
                                        roleLabels[entry.key] ?? entry.key,
                                        _displayPosition(entry.value),
                                        cw,
                                        ch),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: constraints.maxHeight * 0.05,
                      left: constraints.maxWidth * 0.03,
                      width: smallCourtSize,
                      height: smallCourtSize,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Stack(
                            children: [
                              Image.asset(_kSmallCourtImage,
                                  fit: BoxFit.contain),
                              _buildRotationBadge(smallCourtSize),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: constraints.maxHeight * 0.05 + smallCourtSize + 8,
                      left: constraints.maxWidth * 0.03,
                      width: smallCourtSize,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildRotationButton(
                              Icons.rotate_right, _rotateBackward, smallCourtSize),
                          _buildRotationButton(
                              Icons.rotate_left, _rotateForward, smallCourtSize),
                        ],
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

  Widget _buildRotationBadge(double courtSize) {
    final anchor = _kRotationBadgeAnchor[_currentSlot] ?? Alignment.bottomLeft;
    final badgeWidth = courtSize * 0.5;
    final badgeHeight = courtSize / 3;
    return Align(
      alignment: anchor,
      child: SizedBox(
        width: badgeWidth,
        height: badgeHeight,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.darken(Color(widget.team.coloreDivisa)),
            borderRadius: BorderRadius.circular(badgeHeight * 0.1),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Text(
            _currentSlot,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: badgeHeight * 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRotationButton(
      IconData icon, VoidCallback onTap, double smallCourtSize) {
    final buttonSize = smallCourtSize * 0.45;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          color: const Color(0xFF00008A),
          borderRadius: BorderRadius.circular(buttonSize * 0.25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(120),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: buttonSize * 0.55),
      ),
    );
  }

  Widget _buildPlayerToken(
      String label, Offset refPos, double cw, double ch) {
    // Raggio = un ventesimo del campo (singolo campo = quadrato 600×600 nello
    // spazio di riferimento, quindi un ventesimo equivale a ch/20).
    final radius = ch / 20;
    final cx = (refPos.dx / 1200) * cw;
    final cy = (refPos.dy / 600) * ch;
    final fillColor = AppColors.darken(Color(widget.team.coloreDivisa));
    final isPalleggiatore = label == 'P';
    // L'esagono del palleggiatore è il 10% più grande dei token circolari.
    final tokenRadius = isPalleggiatore ? radius * 1.1 : radius;

    final text = Text(
      label,
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: radius * 0.7,
      ),
    );

    return Positioned(
      left: cx - tokenRadius,
      top: cy - tokenRadius,
      width: tokenRadius * 2,
      height: tokenRadius * 2,
      child: isPalleggiatore
          ? CustomPaint(
              painter: _RoundedHexagonPainter(fillColor),
              child: Center(child: text),
            )
          : Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fillColor,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(120),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: text,
            ),
    );
  }
}

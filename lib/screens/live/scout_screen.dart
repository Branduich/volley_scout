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

  // "Nome nostro - Nome avversario" di default: il nome della squadra di cui
  // si fa lo scout va sempre sul lato dove sono disegnati i suoi giocatori
  // (non dipende da casa/trasferta, solo dal cambio campo).
  String get _matchTitle {
    final nostro = widget.team.nome;
    final avversarioRaw = widget.match.avversario?.trim();
    final avversario =
        (avversarioRaw != null && avversarioRaw.isNotEmpty)
            ? avversarioRaw
            : 'AVVERSARI';
    final nostroASinistra = !_isRightSide;
    return nostroASinistra
        ? '$nostro - $avversario'
        : '$avversario - $nostro';
  }

  // Di default i token mostrano il numero di maglia; disattivando il toggle
  // mostrano il ruolo.
  bool _showJerseyNumbers = true;

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _kBg,
      drawer: _buildUtilityDrawer(),
      body: Column(
        children: [
          Container(
            height: 60,
            color: _kTopBarBg,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.only(left: 56, right: 56, bottom: 4),
                  child: Text(
                    _matchTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white),
                      onPressed: () =>
                          _scaffoldKey.currentState?.openDrawer(),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
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
                // Mini-map e bottoni di rotazione seguono il lato del campo:
                // a sinistra di default, speculari a destra quando si cambia
                // campo (stesso margine del 3%).
                final horizontalMargin = constraints.maxWidth * 0.03;
                final minimapLeft = _isRightSide
                    ? constraints.maxWidth - smallCourtSize - horizontalMargin
                    : horizontalMargin;
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
                              final currentAssignments = _currentAssignments;
                              final roleLabels = _roleLabelsFor(
                                  _currentSlot, currentAssignments);
                              return Stack(
                                children: [
                                  Image.asset(_kCourtImage,
                                      fit: BoxFit.contain),
                                  // Itera per giocatore (non per slot fisso)
                                  // così ogni token mantiene la sua identità
                                  // (key = player.id) mentre ruota, e
                                  // AnimatedPositioned ne anima lo spostamento.
                                  for (final entry
                                      in currentAssignments.entries)
                                    _buildPlayerToken(
                                        roleLabels[entry.key] ?? entry.key,
                                        entry.value,
                                        _displayPosition(
                                            _kAttackPositions[entry.key]!),
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
                      left: minimapLeft,
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
                              Transform.rotate(
                                angle: _isRightSide ? math.pi : 0,
                                child: Image.asset(_kSmallCourtImage,
                                    fit: BoxFit.contain),
                              ),
                              _buildRotationBadge(smallCourtSize),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: constraints.maxHeight * 0.05 + smallCourtSize + 8,
                      left: minimapLeft,
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
                    ..._buildLiberoTokens(constraints, courtWidth),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Pannello laterale per i bottoni "di utilità" usati raramente (es.
  // cambio campo), per non affollare l'area sopra il campo grande.
  Widget _buildUtilityDrawer() {
    return Drawer(
      backgroundColor: _kBg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Utilità',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            ListTile(
              leading: const Icon(Icons.swap_horiz, color: Colors.white),
              title: const Text('Cambia campo',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                _toggleSide();
                _scaffoldKey.currentState?.closeDrawer();
              },
            ),
            SwitchListTile(
              value: _showJerseyNumbers,
              onChanged: (v) => setState(() => _showJerseyNumbers = v),
              title: Text(
                  _showJerseyNumbers ? 'Mostra ruoli' : 'Mostra numeri',
                  style: const TextStyle(color: Colors.white)),
              activeThumbColor: Colors.white,
              activeTrackColor: const Color(0xFF00008A),
              inactiveThumbColor: Colors.white70,
              inactiveTrackColor: Colors.white24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRotationBadge(double courtSize) {
    final baseAnchor =
        _kRotationBadgeAnchor[_currentSlot] ?? Alignment.bottomLeft;
    // La mini-map è ruotata di 180° sul campo destro: l'ancoraggio del badge
    // segue la stessa rotazione (negare entrambe le componenti), mentre il
    // testo resta dritto e leggibile.
    final anchor = _isRightSide
        ? Alignment(-baseAnchor.x, -baseAnchor.y)
        : baseAnchor;
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
      String roleLabel, Player player, Offset refPos, double cw, double ch) {
    // Raggio = un ventesimo del campo (singolo campo = quadrato 600×600 nello
    // spazio di riferimento, quindi un ventesimo equivale a ch/20).
    final radius = ch / 20;
    final cx = (refPos.dx / 1200) * cw;
    final cy = (refPos.dy / 600) * ch;
    final fillColor = AppColors.darken(Color(widget.team.coloreDivisa));
    final isPalleggiatore = roleLabel == 'P';
    final label = _showJerseyNumbers ? '${player.numero}' : roleLabel;
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

    // Key = identità del giocatore (non lo slot): così, quando la rotazione
    // sposta tutti i giocatori, AnimatedPositioned anima ciascun token dalla
    // vecchia alla nuova posizione invece di "teletrasportarlo".
    return AnimatedPositioned(
      key: ValueKey(player.id),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
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

  // Token del/dei libero (L1, opzionale L2): non ruotano con P1-P6, restano
  // ancorati in basso a sinistra (a destra col cambio campo), affiancati.
  List<Widget> _buildLiberoTokens(BoxConstraints constraints, double courtWidth) {
    final entries = <MapEntry<String, Player>>[];
    for (final slot in const ['L1', 'L2']) {
      final player = widget.assignments[slot];
      if (player != null) entries.add(MapEntry(slot, player));
    }
    if (entries.isEmpty) return const [];

    final size = courtWidth / 20;
    const gap = 8.0;
    final margin = constraints.maxWidth * 0.03;
    // Solo `left` (mai `right`), come per la mini-map: un valore costante
    // toggling left/right non si anima fluidamente con AnimatedPositioned.
    final rowWidth = entries.length * size + (entries.length - 1) * gap;
    final liberoLeft = _isRightSide
        ? constraints.maxWidth - rowWidth - margin
        : margin;

    return [
      AnimatedPositioned(
        key: const ValueKey('libero-row'),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        bottom: margin,
        left: liberoLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < entries.length; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              _buildLiberoToken(entries[i].key, entries[i].value, size),
            ],
          ],
        ),
      ),
    ];
  }

  Widget _buildLiberoToken(String slotLabel, Player player, double size) {
    final label = _showJerseyNumbers ? '${player.numero}' : slotLabel;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(120),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../models/enums.dart';
import '../../providers/database_provider.dart';

const _kBg = Color(0xFF143E59);
const _kTopBarBg = Color(0xFF0D2738);
const _kCourtImage = 'assets/images/double_court_bg.png';
const _kSmallCourtImage = 'assets/images/small_court.png';

// Colore invertito (canale per canale) rispetto al colore squadra, usato per
// il cerchio del libero — in pallavolo il libero indossa sempre una maglia
// di colore diverso dai compagni. Stessa logica di lineup_screen.dart.
Color _invertedColor(Color color) => Color.from(
      alpha: color.a,
      red: 1.0 - color.r,
      green: 1.0 - color.g,
      blue: 1.0 - color.b,
    );

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
// posizioni di ricezione (quando l'avversario è al servizio).
const Map<String, Offset> _kAttackPositions = {
  'P1': Offset(200, 470),
  'P2': Offset(530, 470),
  'P3': Offset(530, 300),
  'P4': Offset(530, 130),
  'P5': Offset(200, 130),
  'P6': Offset(200, 300),
};

// Quando battiamo noi, chi è in P1 esce dal campo per servire: stessa Y
// dell'posizione di attacco, X spostata di -60 (verso la linea di fondo).
// Passa comunque per _displayPosition(), quindi si specchia correttamente
// anche ripartendo da destra.
const Offset _kBattutaP1Position = Offset(140, 470);

// Posizioni di ricezione (battuta avversaria), per rotazione (chiave = slot
// del palleggiatore, come _currentSlot) e per RUOLO (non per slot fisso —
// stessi codici di _roleLabelsFor: P, O, S1, S2, C1, C2). Il libero sostituisce
// il centrale di seconda linea, che quindi non compare in questa mappa per
// quella rotazione (solo il centrale a rete, che resta in campo, è presente).
// Tutte e 6 le rotazioni sono complete — vedi _activeDefenseMap per il
// controllo di completezza (resta utile se in futuro si aggiungono altre fasi).
const Map<String, Map<String, Offset>> _kDefensePositions = {
  'P1': {
    'S1': Offset(240, 482),
    'Libero': Offset(166, 300),
    'P': Offset(206, 560),
    'S2': Offset(240, 114),
    'C1': Offset(540, 324),
    'O': Offset(444, 50),
  },
  'P2': {
    'P': Offset(552, 356),
    'C1': Offset(498, 50),
    'Libero': Offset(240, 482),
    'S1': Offset(240, 114),
    'S2': Offset(166, 296),
    'O': Offset(60, 266),
  },
  'P3': {
    'P': Offset(552, 356),
    'C2': Offset(480, 384),
    'O': Offset(84, 416),
    'S1': Offset(240, 114),
    'S2': Offset(240, 482),
    'Libero': Offset(166, 296),
  },
  'P4': {
    'P': Offset(552, 50),
    'C2': Offset(482, 76),
    'O': Offset(188, 542),
    'S1': Offset(166, 296),
    'S2': Offset(240, 114),
    'Libero': Offset(240, 482),
  },
  'P5': {
    'P': Offset(518, 254),
    'C2': Offset(552, 50),
    'S1': Offset(166, 296),
    'S2': Offset(240, 114),
    'Libero': Offset(240, 482),
    'O': Offset(438, 542),
  },
  'P6': {
    'O': Offset(552, 274),
    'S2': Offset(240, 114),
    'S1': Offset(240, 482),
    'Libero': Offset(166, 296),
    'P': Offset(498, 314),
    'C1': Offset(438, 542),
  },
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

class ScoutScreen extends ConsumerStatefulWidget {
  final VolleyMatch match;
  final Team team;
  final String palleggiatoreSlot;
  final Map<String, Player> assignments;
  // Quale coppia di ruoli sostituisce il libero (deciso in
  // FormationConfigScreen: o i due centrali o i due schiacciatori, mai una
  // combinazione). Null se non c'è libero in formazione.
  final Ruolo? ruoloCambiLibero;

  const ScoutScreen({
    super.key,
    required this.match,
    required this.team,
    required this.palleggiatoreSlot,
    required this.assignments,
    this.ruoloCambiLibero,
  });

  @override
  ConsumerState<ScoutScreen> createState() => _ScoutScreenState();
}

class _ScoutScreenState extends ConsumerState<ScoutScreen> {
  // Set corrente: creato (con relativa rotazione iniziale) non appena si
  // risponde al dialog "Chi serve per primo?" — vedi _chiediServizioIniziale.
  MatchSet? _setCorrente;

  // Chi è al servizio ora. Finché non registriamo azioni vere (e quindi non
  // richiamiamo ricalcolaStato() su eventi reali), coincide sempre con chi
  // serviva per primo nel set: nessun punto è stato ancora segnato. In
  // modalità test, ignora tutto questo e usa _testServizio (vedi sotto).
  Squadra? get _squadraAlServizio =>
      _testModeEnabled ? _testServizio : _setCorrente?.squadraServizioIniziale;

  // --- Modalità test (solo per provare a video tutte le combinazioni
  // rotazione × chi serve, senza dover passare dal flusso reale di gioco) ---
  bool _testModeEnabled = false;
  Squadra _testServizio = Squadra.nostra;

  void _toggleTestMode(bool value) {
    setState(() {
      _testModeEnabled = value;
      if (value) {
        _rotationSteps = 0;
        _testServizio = Squadra.nostra;
      }
    });
  }

  // Avanza di un passo: stessa rotazione battuta->ricezione, poi ricezione->
  // battuta sulla rotazione successiva (P1->P6->P5->P4->P3->P2->P1...).
  void _testAvanza() {
    setState(() {
      if (_testServizio == Squadra.nostra) {
        _testServizio = Squadra.avversari;
      } else {
        _testServizio = Squadra.nostra;
        _rotationSteps--;
      }
    });
  }

  // Posizione di riferimento (1200×600) per uno slot: quella di attacco,
  // tranne per P1 quando battiamo noi (esce dal campo per servire).
  Offset _refPositionFor(String slot) {
    if (slot == 'P1' && _squadraAlServizio == Squadra.nostra) {
      return _kBattutaP1Position;
    }
    return _kAttackPositions[slot]!;
  }

  // Mappa di ricezione attiva per la rotazione corrente, solo se: stiamo
  // ricevendo (batte l'avversario), c'è un libero in formazione, e i dati di
  // quella rotazione sono completi (P, O, S1, S2, Libero + uno solo tra
  // C1/C2 — vedi nota su P6 incompleto). Altrimenti null: si ricade sulle
  // posizioni di attacco.
  Map<String, Offset>? get _activeDefenseMap {
    if (_squadraAlServizio != Squadra.avversari) return null;
    if (!widget.assignments.containsKey('L1')) return null;
    final map = _kDefensePositions[_currentSlot];
    if (map == null) return null;
    final haUnSoloCentrale = map.containsKey('C1') != map.containsKey('C2');
    final completa = map.containsKey('P') &&
        map.containsKey('O') &&
        map.containsKey('S1') &&
        map.containsKey('S2') &&
        map.containsKey('Libero') &&
        haUnSoloCentrale;
    return completa ? map : null;
  }

  // Slot del libero attualmente in campo (semplificazione: sempre L1 — non
  // modelliamo ancora l'alternanza L1/L2 tra rotazioni): in campo se la
  // mappa di ricezione è attiva, oppure — in attacco/battuta — se c'è un
  // centrale di seconda linea diverso da P1 da sostituire.
  String? get _liberoInCampoSlot {
    if (!widget.assignments.containsKey('L1')) return null;
    if (_activeDefenseMap != null) return 'L1';
    final roleLabels = _roleLabelsFor(_currentSlot, _currentAssignments);
    final slotCentrale = _slotCentraleSecondaLinea(roleLabels);
    return (slotCentrale != null && slotCentrale != 'P1') ? 'L1' : null;
  }

  @override
  void initState() {
    super.initState();
    if (widget.match.stato != StatoPartita.inCorso) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _chiediServizioIniziale());
    }
  }

  Future<void> _chiediServizioIniziale() async {
    final avversario = widget.match.avversario?.trim();
    final nomeAvversario =
        (avversario != null && avversario.isNotEmpty) ? avversario : 'Avversari';

    final scelta = await showDialog<Squadra>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Chi serve per primo?'),
        content: const Text(
            'Indica quale squadra è al servizio per iniziare il set.'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context, Squadra.nostra),
            child: Text(widget.team.nome),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, Squadra.avversari),
            child: Text(nomeAvversario),
          ),
        ],
      ),
    );
    if (scelta == null || !mounted) return;
    await _iniziaSet(scelta);
  }

  Future<void> _iniziaSet(Squadra servizioIniziale) async {
    final matchRepo = ref.read(matchRepositoryProvider);
    final setRepo = ref.read(matchSetRepositoryProvider);

    await matchRepo.updateMatch(
      widget.match.copyWith(stato: StatoPartita.inCorso, setCorrente: 1),
    );
    final set = await setRepo.creaPrimoSet(widget.match.id, servizioIniziale);
    await setRepo.salvaRotazioneIniziale(set.id, widget.assignments);

    if (!mounted) return;
    setState(() => _setCorrente = set);
  }

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

  // Punteggio del set in corso. Segue lo stesso criterio del titolo: il
  // punteggio "nostro" è sempre mostrato sul lato dove sono disegnati i
  // nostri giocatori (a sinistra di default, a destra col cambio campo).
  int _nostroScore = 0;
  int _avversarioScore = 0;

  void _incNostro() => setState(() => _nostroScore++);
  void _decNostro() =>
      setState(() => _nostroScore = (_nostroScore - 1).clamp(0, 999));
  void _incAvversario() => setState(() => _avversarioScore++);
  void _decAvversario() =>
      setState(() => _avversarioScore = (_avversarioScore - 1).clamp(0, 999));

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _kBg,
      drawer: _buildUtilityDrawer(),
      floatingActionButton: _testModeEnabled
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF00008A),
              onPressed: _testAvanza,
              icon: const Icon(Icons.skip_next),
              label: Text(
                '$_currentSlot '
                '${_squadraAlServizio == Squadra.nostra ? "battuta" : "ricezione"}',
              ),
            )
          : null,
      body: Column(
        children: [
          Container(
            height: 60,
            color: _kTopBarBg,
            child: LayoutBuilder(
              builder: (context, headerConstraints) {
                const scoreControlWidth = 76.0;
                final leftScoreLeft =
                    headerConstraints.maxWidth * 0.25 - scoreControlWidth / 2;
                final rightScoreLeft =
                    headerConstraints.maxWidth * 0.75 - scoreControlWidth / 2;
                return Stack(
                  children: [
                    Positioned(
                      left: 56,
                      right: 56,
                      bottom: 4,
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
                    Positioned(
                      left: leftScoreLeft,
                      width: scoreControlWidth,
                      bottom: 4,
                      child: _isRightSide
                          ? _buildScoreControl(_avversarioScore,
                              _decAvversario, _incAvversario)
                          : _buildScoreControl(
                              _nostroScore, _decNostro, _incNostro),
                    ),
                    Positioned(
                      left: rightScoreLeft,
                      width: scoreControlWidth,
                      bottom: 4,
                      child: _isRightSide
                          ? _buildScoreControl(
                              _nostroScore, _decNostro, _incNostro)
                          : _buildScoreControl(_avversarioScore,
                              _decAvversario, _incAvversario),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.menu, color: Colors.white),
                            onPressed: () =>
                                _scaffoldKey.currentState?.openDrawer(),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
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
                              return Stack(
                                children: [
                                  Image.asset(_kCourtImage,
                                      fit: BoxFit.contain),
                                  ..._buildCourtTokens(cw, ch),
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
            const Divider(color: Colors.white24, height: 1),
            SwitchListTile(
              value: _testModeEnabled,
              onChanged: _toggleTestMode,
              title: const Text('Modalità test',
                  style: TextStyle(color: Colors.white)),
              subtitle: const Text(
                'Bottone per scorrere rotazione × chi serve',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
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
            color: Color(widget.team.coloreDivisa),
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

  Widget _buildScoreControl(
      int score, VoidCallback onDecrement, VoidCallback onIncrement) {
    // Stesso identico stile/Text per "-", numero e "+": niente IconButton
    // (la sua area di tocco asimmetrica era la causa del disallineamento
    // verticale rispetto al titolo). Tre Text con lo stesso TextStyle hanno
    // sempre la stessa altezza di riga, quindi restano sulla stessa linea.
    const style = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w600,
      fontSize: 16,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: onDecrement,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('-', style: style),
          ),
        ),
        Text('$score', style: style),
        GestureDetector(
          onTap: onIncrement,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('+', style: style),
          ),
        ),
      ],
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

  // Slot occupato dal giocatore di SECONDA LINEA (P5, P6 o P1) che il libero
  // sostituisce — la coppia è quella scelta in FormationConfigScreen
  // (`widget.ruoloCambiLibero`: centrali o schiacciatori, mai una
  // combinazione). I due della coppia sono sempre opposti nella rotazione (3
  // posizioni di distanza), quindi ce n'è sempre esattamente uno in seconda
  // linea. Null se non c'è libero in formazione, o se per qualche motivo
  // nessuno dei due ruoli della coppia è assegnato (formazione incompleta).
  String? _slotCentraleSecondaLinea(Map<String, String> roleLabels) {
    final ruolo = widget.ruoloCambiLibero;
    if (ruolo == null) return null;
    final etichette =
        ruolo == Ruolo.centrale ? const {'C1', 'C2'} : const {'S1', 'S2'};
    const secondaLinea = {'P5', 'P6', 'P1'};
    for (final entry in roleLabels.entries) {
      if (secondaLinea.contains(entry.key) &&
          etichette.contains(entry.value)) {
        return entry.key;
      }
    }
    return null;
  }

  // Costruisce i token dei 6 giocatori sul campo grande. In ricezione (mappa
  // di difesa attiva per la rotazione corrente): itera per RUOLO sulla mappa
  // di difesa — il centrale di seconda linea non compare (sostituito dal
  // libero). Altrimenti (attacco/battuta, o ricezione senza dati di difesa
  // completi): itera per giocatore sulle posizioni di attacco, sostituendo
  // comunque il centrale di seconda linea col libero — **tranne in P1**
  // (chi sta per servire resta lui: regola "classica", il libero non serve
  // mai; la regola configurabile FIPAV non è ancora implementata, vedi
  // CLAUDE.md).
  List<Widget> _buildCourtTokens(double cw, double ch) {
    final currentAssignments = _currentAssignments;
    final roleLabels = _roleLabelsFor(_currentSlot, currentAssignments);
    final defenseMap = _activeDefenseMap;

    if (defenseMap == null) {
      final slotCentrale = _slotCentraleSecondaLinea(roleLabels);
      final libero = widget.assignments['L1'];
      return [
        for (final entry in currentAssignments.entries)
          if (entry.key == slotCentrale &&
              entry.key != 'P1' &&
              libero != null)
            _buildLiberoCourtToken(
                libero, _displayPosition(_refPositionFor(entry.key)), cw, ch)
          else
            _buildPlayerToken(
                roleLabels[entry.key] ?? entry.key,
                entry.value,
                _displayPosition(_refPositionFor(entry.key)),
                cw,
                ch),
      ];
    }

    final slotPerRuolo = {
      for (final e in roleLabels.entries) e.value: e.key,
    };
    final libero = widget.assignments[_liberoInCampoSlot];
    final tokens = <Widget>[];
    for (final entry in defenseMap.entries) {
      final refPos = _displayPosition(entry.value);
      if (entry.key == 'Libero') {
        if (libero != null) {
          tokens.add(_buildLiberoCourtToken(libero, refPos, cw, ch));
        }
        continue;
      }
      final slot = slotPerRuolo[entry.key];
      final player = slot == null ? null : currentAssignments[slot];
      if (player != null) {
        tokens.add(_buildPlayerToken(entry.key, player, refPos, cw, ch));
      }
    }
    return tokens;
  }

  Widget _buildPlayerToken(
      String roleLabel, Player player, Offset refPos, double cw, double ch) {
    // Raggio = un ventesimo del campo (singolo campo = quadrato 600×600 nello
    // spazio di riferimento, quindi un ventesimo equivale a ch/20).
    final radius = ch / 20;
    final cx = (refPos.dx / 1200) * cw;
    final cy = (refPos.dy / 600) * ch;
    final fillColor = Color(widget.team.coloreDivisa);
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

  // Token del libero quando entra in campo al posto del centrale di seconda
  // linea (fase di ricezione). Stesso posizionamento/animazione di
  // _buildPlayerToken, ma stile del libero (colore invertito, bordo bianco).
  Widget _buildLiberoCourtToken(
      Player player, Offset refPos, double cw, double ch) {
    final radius = ch / 20;
    final cx = (refPos.dx / 1200) * cw;
    final cy = (refPos.dy / 600) * ch;
    final color = _invertedColor(Color(widget.team.coloreDivisa));
    final label = _showJerseyNumbers ? '${player.numero}' : 'L1';

    return AnimatedPositioned(
      key: ValueKey(player.id),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      left: cx - radius,
      top: cy - radius,
      width: radius * 2,
      height: radius * 2,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
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
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: radius * 0.7,
          ),
        ),
      ),
    );
  }

  // Token del/dei libero (L1, opzionale L2): non ruotano con P1-P6, restano
  // ancorati in basso a sinistra (a destra col cambio campo), affiancati.
  // Esclude il libero già disegnato sul campo al posto del centrale (fase di
  // ricezione), per non mostrarlo due volte.
  List<Widget> _buildLiberoTokens(BoxConstraints constraints, double courtWidth) {
    final liberoInCampo = _liberoInCampoSlot;
    final entries = <MapEntry<String, Player>>[];
    for (final slot in const ['L1', 'L2']) {
      if (slot == liberoInCampo) continue;
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
    final color = _invertedColor(Color(widget.team.coloreDivisa));
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
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
        label,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}

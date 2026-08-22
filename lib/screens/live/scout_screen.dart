import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../logic/attack_positions.dart';
import '../../logic/defense_positions.dart';
import '../../logic/ricalcola_stato.dart';
import '../../logic/role_labels.dart';
import '../../models/enums.dart';
import '../../models/jersey_colors.dart';
import '../../providers/database_provider.dart';
import '../../providers/premium_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/court_style.dart';
import '../../tutorial/tutorial_controller.dart';
import '../../tutorial/tutorial_overlay.dart';
import '../../tutorial/tutorial_target.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/enum_l10n.dart';
import '../../widgets/freccia_traiettoria_painter.dart';
import '../../widgets/premium_badge.dart';
import '../premium/paywall_screen.dart';
import '../report/match_report_screen.dart';
import '../report/player_stats_screen.dart';
import '../report/trajectory_report_screen.dart';
import 'end_set_screen.dart';
import 'sostituzione_screen.dart';
import 'tactical_board_screen.dart';
import '../../utils/orientamento.dart';

const _kBg = Color(0xFF143E59);
const _kTopBarBg = Color(0xFF0D2738);
const _kCourtImage = 'assets/images/double_court_bg.png';
const _kSmallCourtImage = 'assets/images/small_court.png';

// Lampeggio del punteggio quando cambia: durata totale (regolabile) e
// mezzo-periodo del singolo lampeggio (l'opacità oscilla avanti/indietro,
// quindi il ciclo completo dura il doppio).
const Duration _kDurataLampeggioPunteggio = Duration(seconds: 2);
const Duration _kPeriodoLampeggioPunteggio = Duration(milliseconds: 350);

// Margine fisso tra il bordo superiore dell'area di gioco (sotto banner/
// bottoni rapidi) e il campo grande — il campo non è più centrato
// verticalmente nello spazio rimanente, ma ancorato in alto a questa
// distanza. Stesso valore usato per calcolare `courtTop` in
// _buildLiberoSwapTokens/_buildBattitoreTapCatcher (Stack esterno,
// coordinate schermo assolute): deve restare identico a quello passato a
// `Positioned(top: ...)` nel campo vero, altrimenti libero/battitore fuori
// campo si disallineano dal campo disegnato.
const double _kCourtTopMargin = 16.0;

// Quanto vicino alla rete (px) il dito deve staccarsi perché quel punto valga
// come tocco a muro nel disegno in-line. Stesso valore di TrajectoryScreen,
// duplicato qui come le altre costanti condivise fra le due schermate.
const double _kToleranzaReteInLine = 24.0;

// Per quanto il dito deve restare nella fascia perché scatti il tocco a muro:
// un attacco che scavalca la rete di slancio non deve lasciare uno snodo, solo
// una sosta deliberata. Stesso valore di TrajectoryScreen.
const Duration _kSoffermamentoReteInLine = Duration(milliseconds: 400);

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
// Le due file esterne stanno a 90 e 510 (non più 130 e 470): allargate di 40
// verso le linee laterali il 2026-08-22, insieme alle tabelle tattiche di
// logic/attack_positions.dart — questi sono i RIPIEGHI usati quando la tabella
// non copre un ruolo, e devono restare in linea con esse. La fila centrale
// (300) non si è mossa: la traslazione è simmetrica.
const Map<String, Offset> _kAttackPositions = {
  'P1': Offset(200, 510),
  'P2': Offset(530, 510),
  'P3': Offset(530, 300),
  'P4': Offset(530, 90),
  'P5': Offset(200, 90),
  'P6': Offset(200, 300),
};

// Posizioni delle 6 zone AVVERSARIE (metà campo opposta): la riflessione delle
// nostre attraverso il centro del campo doppio (1200-x, 600-y). La zona 1
// avversaria è diagonalmente opposta alla nostra (i due angoli di battuta sono
// sempre in diagonale) — usata dalla selezione sul campo del palleggiatore
// avversario a inizio set e, in seguito, dai token placeholder avversari.
// Passa comunque per _displayPosition() come le nostre, così segue il cambio
// campo restando sempre sul lato opposto ai nostri token.
// Riflessione esatta di _kAttackPositions: 1200−x, 600−y. Poiché la
// traslazione del 2026-08-22 è simmetrica attorno a 300, lo specchio di 90 è
// 510 e viceversa — le zone avversarie si allargano insieme alle nostre.
const Map<int, Offset> _kOpponentZonePositions = {
  1: Offset(1000, 90),
  2: Offset(670, 90),
  3: Offset(670, 300),
  4: Offset(670, 510),
  5: Offset(1000, 510),
  6: Offset(1000, 300),
};

// Colore dei token placeholder avversari: grigio neutro (deliberato — sta bene
// con qualsiasi colore della nostra squadra e comunica "placeholder", non un
// roster reale). Da rifinire eventualmente col feedback visivo.
const Color _kColoreTokenAvversario = Color(0xFF757575); // grigio 600

// La posizione del battitore avversario fuori campo non è più una costante
// dedicata: viene dalla mappa tattica (attackMapFor(battuta), ruolo in zona 1
// a X<0) specchiata sulla loro metà — vedi _posizioneAvversario.

// Fase globale di uno scambio: battuta (chi serve) → ricezione (chi riceve) →
// fase libera (attacchi/difese/muri). Chi batte e chi riceve dipende da chi è
// al servizio. Governa tappabilità e fondamentale forzato di ENTRAMBE le
// squadre — vedi _faseScambio.
enum _FaseScambio { servizio, ricezione, libera }

// Quando battiamo noi, chi è in P1 esce dal campo per servire: X = -70,
// cioè il bordo del campo (x=0, la linea di fondo) meno 70 (era -60 con
// token più piccoli, vedi _kTokenSizeScale — aumentato per mantenere lo
// stesso margine visivo di distacco dal campo) — non l'X della posizione di
// attacco meno 70. Il battitore deve stare FUORI dal campo (X negativa), non
// semplicemente più indietro ma ancora dentro. Stessa Y della posizione di
// attacco. Passa comunque per _displayPosition(), quindi si specchia
// correttamente anche ripartendo da destra.
const Offset _kBattutaP1Position = Offset(-70, 510);

// Fattore di scala applicato al raggio "base" (ch/20) di tutti i token
// giocatore — token su campo (_buildPlayerToken), libero attivo/inattivo
// e battitore fuori campo (_swapTokenRadius, stesso Stack esterno, tutti
// via _buildLiberoSwapTokens). Le tre formule derivano tutte dallo
// stesso raggio "base" e vanno scalate insieme, altrimenti i token
// finiscono disallineati in dimensione tra Stack interno ed esterno.
// Aumentato da 1.0 dopo test su tablet fisico (token troppo piccoli).
const double _kTokenSizeScale = 1.4;

// Opacità dei token BLOCCATI dopo un `#` (la squadra che ha appena attaccato):
// attenuati per segnalare che va toccata la squadra che difende — vedi
// _nostriTokenBloccati/_tokenAvversariBloccati. NON si attenuano tutti i token
// non tappabili (troppo aggressivo): solo questo caso, per ora.
const double _kAlphaTokenBloccato = 0.5;

// Bordo del token SELEZIONATO (giocatore nostro o ruolo avversario toccato per
// il voto): giallo, torna bianco alla deselezione — con un breve flash-in
// animato. Rinforza il feedback della selezione.
const Color _kBordoTokenSelezionato = Color(0xFFFFEB3B); // giallo

// Le posizioni TATTICHE di attacco per rotazione/ruolo/fase (ex costanti
// private qui) vivono in logic/attack_positions.dart: condivise con le
// pagine attacchi del report PDF, che ne ricava la "posizione di attacco"
// dei giocatori — vedi _activeAttackMap più sotto.

// Le posizioni di ricezione (battuta avversaria) per rotazione/ruolo/variante
// libero vivono in logic/defense_positions.dart (kDefensePositionsCentrali/
// Schiacciatori + defenseMapFor): estratte per essere riusate dalla formazione
// di ricezione AVVERSARIA (mirror). _activeDefenseMap le seleziona da lì.

// Ordine antiorario degli slot sul campo grande (verificato sulle coordinate
// di _kAttackPositions), usato per calcolare la distanza dal palleggiatore.
const List<String> _kSlotOrder = ['P1', 'P2', 'P3', 'P4', 'P5', 'P6'];

// Modulo che gestisce correttamente anche valori negativi (a differenza di
// `%` in Dart, che mantiene il segno dell'operando).
int _mod(int a, int n) => ((a % n) + n) % n;

// Riflessione di una posizione dal campo SINISTRO (spazio di riferimento
// 1200×600, rete a x=600) alla metà AVVERSARIA (destra), attraverso il centro
// del campo doppio — la stessa trasformazione con cui _kOpponentZonePositions
// specchia _kAttackPositions. Le tabelle tattiche (attackMapFor/defenseMapFor)
// sono sul campo sinistro: per posizionare i token avversari sulla loro metà
// si specchia ogni Offset con questa, poi si passa per _displayPosition (che
// gestisce a parte il cambio campo).
Offset _mirrorAvversario(Offset o) => Offset(1200 - o.dx, 600 - o.dy);

// Le etichette di ruolo per slot (P/O/S1/S2/C1/C2) vivono in
// logic/role_labels.dart (funzione pura roleLabelsFor, testata): gli
// universali (Ruolo.undefined) riempiono le etichette MANCANTI nella
// composizione — dopo un cambio ereditano il ruolo tattico dell'uscente.

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
  // Bordo: bianco/2px di default, giallo e più grosso quando il token è
  // selezionato (vedi _kBordoTokenSelezionato) — colore e spessore animati dal
  // chiamante.
  final Color bordoColor;
  final double bordoWidth;
  const _RoundedHexagonPainter(this.color,
      {this.bordoColor = Colors.white, this.bordoWidth = 2});

  @override
  void paint(Canvas canvas, Size size) {
    final path = _roundedHexagonPath(size, size.shortestSide * 0.08);
    canvas.drawShadow(path, Colors.black, 3, false);
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = bordoColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = bordoWidth,
    );
  }

  @override
  bool shouldRepaint(covariant _RoundedHexagonPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.bordoColor != bordoColor ||
      oldDelegate.bordoWidth != bordoWidth;
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
  // Sistema di gioco della formazione (5-1 / 6-2). Nel 6-2 `palleggiatoreSlot`
  // è lo slot del palleggiatore di RIFERIMENTO (P1). Default 5-1 per sicurezza.
  final SistemaGioco sistemaGioco;

  /// Modalità tutorial: la schermata è identica in tutto — stessi handler,
  /// stesse guardie, stesse scritture — ma sopra allo Scaffold compare
  /// `TutorialOverlay`, che oscura tutto tranne l'elemento del passo corrente
  /// e lascia passare i tap solo lì (vedi lib/tutorial/). Gli unici due punti
  /// che il tutorial tocca qui sono l'helper `_anchor()` (registra dove si
  /// trovano gli elementi) e `onDrawerChanged`. La partita su cui gira è una
  /// sandbox usa-e-getta creata da `avviaTutorial()`.
  final bool tutorial;

  const ScoutScreen({
    super.key,
    required this.match,
    required this.team,
    required this.palleggiatoreSlot,
    required this.assignments,
    this.ruoloCambiLibero,
    this.sistemaGioco = SistemaGioco.palleggiatoreUnico,
    this.tutorial = false,
  });

  @override
  ConsumerState<ScoutScreen> createState() => _ScoutScreenState();
}

class _ScoutScreenState extends ConsumerState<ScoutScreen> with OrientamentoSchermata<ScoutScreen> {
  @override
  List<DeviceOrientation> get orientamentiConsentiti => kOrientamentoLandscape;

  // Set corrente: creato (con relativa rotazione iniziale) non appena si
  // risponde al dialog "Chi serve per primo?" — vedi _chiediServizioIniziale.
  MatchSet? _setCorrente;

  // True mentre si sceglie sul campo la zona del palleggiatore avversario
  // (inizio set, solo se lo scout avversari è attivo): overlay di zone
  // tappabili sulla metà campo avversaria, scout normale sospeso finché non
  // si tocca una zona — vedi _buildSelezionePAvversario/_confermaPAvversario.
  bool _inSelezionePAvversario = false;

  // Rotazione di partenza (posizione 1-6 -> id giocatore), letta dalla
  // formazione confermata — stesso parsing di
  // MatchSetRepository.salvaRotazioneIniziale, ma calcolato qui in memoria:
  // serve a ricalcolaStato() come stato iniziale, non a un'altra lettura DB.
  Map<int, int> get _rotazioneInizialeMap {
    final map = <int, int>{};
    for (final entry in widget.assignments.entries) {
      final pos = int.tryParse(entry.key.replaceFirst('P', ''));
      if (pos != null && pos >= 1 && pos <= 6) {
        map[pos] = entry.value.id;
      }
    }
    return map;
  }

  // Stato reale del set (punteggio, chi serve, rotazione), derivato dagli
  // eventi ScoutAction persistiti — null finché il set non è ancora iniziato
  // (dialog "Chi serve per primo?" non ancora risposto). Punto centrale del
  // principio event-sourcing: niente di tutto questo è salvato come stato
  // mutabile, si ricalcola sempre dalla sequenza di azioni.
  StatoSet? get _statoSetReale {
    final set = _setCorrente;
    if (set == null) return null;
    final azioniAsync = ref.watch(scoutAzioniStreamProvider(set.id));
    final righe = azioniAsync.value ?? const <ScoutAction>[];
    final azioni = [for (final r in righe) azioneScoutDaRiga(r)];
    return ricalcolaStato(
      azioni: azioni,
      servizioIniziale: set.squadraServizioIniziale,
      rotazioneIniziale: _rotazioneInizialeMap,
      palleggiatoreInizialeId: widget.assignments[widget.palleggiatoreSlot]?.id,
      ruoloCambiLiberoIniziale: widget.ruoloCambiLibero,
      liberoInizialeId: widget.assignments['L1']?.id,
      libero2InizialeId: widget.assignments['L2']?.id,
      palleggiatoreAvversarioSlotIniziale: set.palleggiatoreAvversarioSlot,
    );
  }

  // Roster completo della squadra (id -> Player), per risolvere i
  // giocatoreId della rotazione derivata: dopo un cambio giocatore la
  // rotazione può contenere id NON presenti in widget.assignments (il
  // subentrante partiva dalla panchina). Lo stream del roster è fuso SOPRA
  // widget.assignments: il fallback copre i primi frame prima che lo stream
  // emetta (evita token vuoti alla ripresa).
  Map<int, Player> get _rosterById {
    final map = {for (final p in widget.assignments.values) p.id: p};
    final roster = ref.watch(playersStreamProvider(widget.team.id)).value;
    if (roster != null) {
      for (final p in roster) {
        map[p.id] = p;
      }
    }
    return map;
  }

  // Coppia cambi-libero effettiva: può cambiare a set in corso con un
  // cambio giocatore (override nel medesimo evento) — widget.ruoloCambiLibero
  // resta il valore INIZIALE del set (usato da _iniziaSet per persisterlo).
  // In modalità test non ci sono eventi reali: vale il valore iniziale.
  Ruolo? get _ruoloCambiLiberoEffettivo => _testModeEnabled
      ? widget.ruoloCambiLibero
      : (_statoSetReale?.ruoloCambiLibero ?? widget.ruoloCambiLibero);

  // Liberi EFFETTIVI (L1/L2 -> Player): possono cambiare a set in corso con
  // un cambio libero-per-libero (vedi ricalcolaStato) — widget.assignments
  // resta la formazione INIZIALE. Fallback sul widget quando lo stato non è
  // ancora derivato (set non iniziato, modalità test) o il roster stream
  // non ha ancora emesso (primi frame).
  Map<String, Player> get _liberiEffettivi {
    final iniziali = <String, Player>{
      if (widget.assignments['L1'] != null) 'L1': widget.assignments['L1']!,
      if (widget.assignments['L2'] != null) 'L2': widget.assignments['L2']!,
    };
    final stato = _testModeEnabled ? null : _statoSetReale;
    if (stato == null) return iniziali;
    return <String, Player>{
      if (stato.liberoId != null)
        'L1': _rosterById[stato.liberoId] ?? iniziali['L1']!,
      if (stato.libero2Id != null)
        'L2': _rosterById[stato.libero2Id] ?? iniziali['L2']!,
    };
  }

  // Ultima azione registrata nel set (stessa riga che alimenterà in futuro
  // le statistiche/report — vedi Modello dati), per il banner "ultima
  // azione" sopra al campo. Null se il set non è iniziato o non ha ancora
  // azioni. Resta lì finché non ne arriva una successiva (nessun timer di
  // sparizione, nemmeno per punto/errore — vedi "Interfaccia di scout").
  ScoutAction? get _ultimaAzione {
    final set = _setCorrente;
    if (set == null) return null;
    final azioniAsync = ref.watch(scoutAzioniStreamProvider(set.id));
    final righe = azioniAsync.value;
    if (righe == null || righe.isEmpty) return null;
    return righe.last; // watchAzioni ordina per `ordine` crescente
  }

  // Azioni DI GIOCO dell'ultimo scambio — aperto O appena chiuso: quelle che
  // spariscono con "annulla lo scambio", quando l'arbitro fa rigiocare
  // l'azione. Lista vuota se non c'è niente da annullare.
  //
  // NON è `_azioniRallyCorrente` (più sotto), che serve alla logica di fase e
  // per questo considera solo lo scambio ANCORA APERTO e le sole azioni
  // `scout`: qui servono anche i punti/errori rapidi che chiudono lo scambio,
  // ed è proprio uno scambio già chiuso quello che di solito si rigioca.
  //
  // I cambi giocatore sono esclusi: avvengono a palla ferma, quindi non fanno
  // parte dello scambio — ma ne condividono il `rallyId` (in
  // `_registraAzione` solo timeout e correzione rotazione interrompono
  // l'ereditarietà). Stessa esclusione lato repository, vedi annullaRally.
  // Se l'ultima azione NON è di gioco (timeout, correzione, cambio) il gruppo
  // resta vuoto e il tasto si spegne da solo: per quelle c'è l'undo singolo.
  List<ScoutAction> get _azioniUltimoRally {
    final ultima = _ultimaAzione;
    if (ultima == null || !_eDiGioco(ultima)) return const [];
    final set = _setCorrente;
    if (set == null) return const [];
    final righe = ref.watch(scoutAzioniStreamProvider(set.id)).value;
    if (righe == null) return const [];
    return [
      for (final a in righe)
        if (a.rallyId == ultima.rallyId && _eDiGioco(a)) a,
    ];
  }

  // Un'azione "di gioco" apre o continua uno scambio. Le altre
  // (cambioGiocatore, timeout, correzioneRotazione) stanno a palla ferma.
  bool _eDiGioco(ScoutAction a) =>
      a.tipo == TipoAzione.scout ||
      a.tipo == TipoAzione.puntoManuale ||
      a.tipo == TipoAzione.erroreGenerico;

  // Chi è al servizio ora. Fuori dalla modalità test, deriva dallo stato
  // reale (ricalcolaStato sugli eventi persistiti); prima che il set inizi
  // ricade su null. In modalità test, ignora tutto questo e usa
  // _testServizio (vedi sotto).
  Squadra? get _squadraAlServizio => _testModeEnabled
      ? _testServizio
      : (_statoSetReale?.squadraAlServizio ??
            _setCorrente?.squadraServizioIniziale);

  // True se siamo nella sotto-fase "dopo" dello scambio corrente (palla in
  // gioco, voto già dato) — in modalità test deriva da _testDopo (ciclato a
  // mano da _testAvanza), altrimenti da _fondamentaleGiudicatoRallyCorrente
  // (derivato dagli eventi reali). Unifica i due casi per
  // _refPositionFor/_activeAttackMap/_activeDefenseMap.
  bool get _faseDopo =>
      _testModeEnabled ? _testDopo : _fondamentaleGiudicatoRallyCorrente;

  // Chiave del libero attivo (in campo o diretto verso il campo). Segue la
  // convenzione automatica (L1 in ricezione, L2 in servizio) finché non c'è
  // un override manuale da _liberoOverride.
  String get _liberoAttivoKey {
    if (_liberiEffettivi['L2'] == null) return 'L1';
    if (_liberoOverride != null) return _liberoOverride!;
    return _squadraAlServizio == Squadra.avversari ? 'L1' : 'L2';
  }

  // Chiave del libero inattivo (in panchina fissa, tappabile). Null se non
  // c'è doppio libero.
  String? get _liberoInattivoKey {
    if (_liberiEffettivi['L2'] == null) return null;
    return _liberoAttivoKey == 'L1' ? 'L2' : 'L1';
  }

  // --- Modalità test (solo per provare a video tutte le combinazioni
  // rotazione × chi serve, senza dover passare dal flusso reale di gioco) ---
  bool _testModeEnabled = false;
  Squadra _testServizio = Squadra.nostra;
  // Sotto-fase "dopo" (palla in gioco, voto già dato) all'interno di
  // _testServizio — vedi _testAvanza per le 4 combinazioni cicliche.
  bool _testDopo = false;

  void _toggleTestMode(bool value) {
    setState(() {
      _testModeEnabled = value;
      if (value) {
        _rotationSteps = 0;
        _testServizio = Squadra.nostra;
        _testDopo = false;
      }
    });
  }

  // Avanza di un passo tra le 4 fasi vere dello scambio, nello stesso ordine
  // del gioco reale: Battuta → Dopo_Battuta → Ricezione → Dopo_Ricezione →
  // Battuta della rotazione successiva (P1→P6→P5→P4→P3→P2→P1...).
  void _testAvanza() {
    setState(() {
      if (_testServizio == Squadra.nostra && !_testDopo) {
        _testDopo = true; // Battuta -> Dopo_Battuta
      } else if (_testServizio == Squadra.nostra && _testDopo) {
        _testServizio = Squadra.avversari;
        _testDopo = false; // Dopo_Battuta -> Ricezione
      } else if (_testServizio == Squadra.avversari && !_testDopo) {
        _testDopo = true; // Ricezione -> Dopo_Ricezione
      } else {
        _testServizio = Squadra.nostra;
        _testDopo = false;
        _rotationSteps--; // Dopo_Ricezione -> Battuta rotazione successiva
      }
    });
  }

  // Posizione di riferimento (1200×600) per uno slot: quella di attacco,
  // tranne per P1 quando battiamo noi E la battuta di questo scambio non è
  // ancora stata giudicata (vedi _faseDopo) — una volta dato il voto, il
  // battitore si riporta in campo nella sua posizione normale, perché la
  // palla è in gioco. In modalità test segue _testDopo (vedi _testAvanza)
  // invece che i voti reali.
  Offset _refPositionFor(String slot) {
    final inBattuta = _squadraAlServizio == Squadra.nostra && !_faseDopo;
    if (slot == 'P1' && inBattuta) {
      return _kBattutaP1Position;
    }
    return _kAttackPositions[slot]!;
  }

  // Tabella di attacco attiva per rotazione/RUOLO nella fase corrente
  // (Battuta/DopoBattuta/DopoRicezione). Tre varianti coperte: "libero sui
  // centrali" e "libero sugli schiacciatori" (dati diretti, vedi
  // _kAttackBattutaCentrali/_kAttackBattutaSchiacciatori e tabelle gemelle)
  // e "senza libero" (derivata al volo dalle tabelle centrali, vedi
  // _kAttackSenzaLiberoDaCentrali — il centrale altrimenti sostituito gioca
  // semplicemente lui stesso; vale per qualunque variante perché senza
  // libero non c'è alcuna sostituzione da scegliere). Null durante la
  // ricezione in corso (gestita da _activeDefenseMap): in quel caso si
  // ricade su _refPositionFor (logica generica per zona fissa, non per
  // ruolo) — vedi _attackPosition.
  // Sistema di gioco della formazione: pilota il branch 5-1 / 6-2 per le
  // etichette di ruolo e le mappe di posizione. Il resto della meccanica
  // (rotazione, libero, animazioni) è condiviso tra i due sistemi.
  bool get _is62 => widget.sistemaGioco == SistemaGioco.doppioPalleggiatore;

  // Etichette di ruolo della rotazione corrente, secondo il sistema di gioco
  // ({P,O,...} nel 5-1, {P1,P2,...} nel 6-2).
  Map<String, String> _roleLabels(
          String slot, Map<String, Player> assignments) =>
      _is62
          ? roleLabelsFor62(slot, assignments)
          : roleLabelsFor(slot, assignments);

  Map<String, Offset>? get _activeAttackMap {
    // Fase: battuta/dopo-battuta se serviamo noi, dopo-ricezione se
    // servono loro e la ricezione è già stata giudicata; null durante la
    // ricezione in corso (comanda _activeDefenseMap).
    final FaseAttacco fase;
    if (_squadraAlServizio == Squadra.nostra) {
      fase = !_faseDopo ? FaseAttacco.battuta : FaseAttacco.dopoBattuta;
    } else if (_squadraAlServizio == Squadra.avversari && _faseDopo) {
      fase = FaseAttacco.dopoRicezione;
    } else {
      return null;
    }
    final senzaLibero = !_liberiEffettivi.containsKey('L1');
    if (_is62) {
      // Nel 6-2 il libero è sempre sui centrali (variante unica).
      return attackMapFor62(
        rotazione: _currentSlot,
        fase: fase,
        senzaLibero: senzaLibero,
      );
    }
    return attackMapFor(
      rotazione: _currentSlot,
      fase: fase,
      senzaLibero: senzaLibero,
      liberoSuSchiacciatori:
          !senzaLibero && _ruoloCambiLiberoEffettivo == Ruolo.schiacciatore,
    );
  }

  // Posizione di riferimento per il giocatore nello slot (rotazione
  // corrente) indicato, in fase di attacco: usa la tabella per ruolo
  // (_activeAttackMap) se disponibile per questa variante/fase/ruolo,
  // altrimenti ricade su _refPositionFor (zona fissa, non per ruolo) — il
  // fallback resta finché non ci sono le tabelle delle altre varianti
  // libero.
  Offset _attackPosition(String slot, Map<String, String> roleLabels) {
    final mappa = _activeAttackMap;
    final ruolo = roleLabels[slot];
    if (mappa != null && ruolo != null && mappa.containsKey(ruolo)) {
      return mappa[ruolo]!;
    }
    return _refPositionFor(slot);
  }

  // Giocatore + coppia (fondamentale, voto) in corso di composizione nel
  // pannello — null = pannello chiuso. Il pannello è una PULSANTIERA UNICA:
  // le due colonne (fondamentali e voti) sono sempre entrambe a schermo e si
  // riempiono in QUALSIASI ORDINE; l'azione si registra quando la coppia è
  // completa (vedi _provaRegistrare). `fondamentale` arriva già valorizzato
  // quando la fase lo impone (battuta/ricezione, vedi _fondamentaleForzato):
  // in quel caso la colonna dei fondamentali è spenta e basta il voto.
  // Tap sul giocatore (vedi _tapHandlerPerGiocatore) apre; la registrazione
  // (_registraVoto) richiude.
  ({Player giocatore, Fondamentale? fondamentale, Voto? voto})? _votoInCorso;

  // Azione AVVERSARIA in corso: ruolo placeholder toccato (P/O/S1/S2/C1/C2) +
  // la stessa coppia (fondamentale, voto) del pannello nostro. Flusso
  // parallelo e ISOLATO da _votoInCorso (legato a un nostro Player):
  // l'avversario non ha roster, solo il ruolo. Vedi
  // _tapHandlerAvversario/_buildPannelloAvversario/_registraVotoAvversario.
  ({String ruolo, Fondamentale? fondamentale, Voto? voto})? _avversarioInCorso;

  bool get _pannelloAperto =>
      _votoInCorso != null || _avversarioInCorso != null;

  // --- Traiettoria disegnata SUL CAMPO LIVE (sperimentale, solo battuta) ---
  //
  // Attiva solo con Impostazioni.traiettoriaBattutaInLine acceso: si tocca il
  // battitore, si trascina sul campo, poi si vota (il voto chiude l'azione,
  // vedi _registraVoto). Con l'interruttore spento resta tutto com'era e la
  // traiettoria si prende su TrajectoryScreen dopo il voto — le due strade
  // convivono apposta, per poterle confrontare sullo stesso build.
  //
  // Punto in cui è iniziato il gesto in corso (null = nessun dito giù) e se
  // quel gesto è partito SULLA CARD del pannello, dove non si deve disegnare.
  Offset? _pointerGiu;
  bool _gestoSullaCard = false;

  // Freccia da disegnare, in coordinate ASSOLUTE dello Stack del corpo: resta
  // a schermo anche dopo il rilascio, così si vede che è stata presa.
  //
  // È un ValueNotifier e non un campo con setState perché il dito genera un
  // evento di movimento a ogni frame: un setState qui ricostruirebbe TUTTO
  // ScoutScreen (campo, token, log, pannello) 60 volte al secondo. Passato
  // come `repaint` al painter, ridisegna solo la freccia senza toccare
  // l'albero dei widget.
  // `muro` = punto di tocco a muro (solo attacco): quando c'è, la freccia si
  // disegna a due segmenti con uno snodo lì. `inZonaRete` = il dito è dentro
  // la fascia della rete e il soffermamento sta scorrendo: accende la riga
  // gialla. Stanno QUI dentro e non in campi a parte perché così arrivano al
  // painter senza un `setState`.
  final ValueNotifier<
          ({Offset inizio, Offset fine, Offset? muro, bool inZonaRete})?>
      _frecciaInLine = ValueNotifier(null);

  // Timer del soffermamento sulla rete e flag "dito dentro la fascia" — vedi
  // _onPointerMoveCampo.
  Timer? _timerMuroInLine;
  bool _inZonaReteInLine = false;

  // La stessa freccia normalizzata 0..1 sul riquadro campo, calcolata al
  // rilascio (dove la geometria del campo è nota) e usata al momento di
  // registrare. Volutamente NON clampata: il battitore sta fuori dal campo e
  // le sue X sono negative, come _kBattutaP1Position.
  ({double x1, double y1, double x2, double y2, double? muroX, double? muroY})?
      _traiettoriaNormalizzata;

  // Callback "apri il pannello per QUESTO giocatore", messa da parte quando il
  // dito scende su un token (vedi `onTapDown` nei builder) e invocata dal
  // gestore del movimento se quel gesto si rivela un trascinamento. Serve a far
  // partire la traiettoria direttamente dal giocatore, senza il tocco separato
  // che lo seleziona: `onTap` da solo non basta, perché il riconoscitore del
  // tap si arrende appena il dito si muove.
  // `identita` = id del giocatore (nostri) o etichetta di ruolo (avversari):
  // serve a distinguere "sto trascinando da un ALTRO giocatore" (→ si cambia
  // selezione) da "sto ridisegnando il tratto dello stesso" (→ non si tocca
  // niente, altrimenti si azzererebbe un voto già scelto).
  ({VoidCallback apri, Object identita})? _aperturaDaTrascinamento;

  // Chi è selezionato adesso, nello stesso spazio di `identita`.
  Object? get _identitaSelezionata =>
      _votoInCorso?.giocatore.id ?? _avversarioInCorso?.ruolo;

  // Tipo di attacco scelto nella colonna della pulsantiera quando la
  // traiettoria è stata disegnata sul campo (vedi _colonnaTipiAttacco).
  // A differenza del tipo di battuta NON resta mai "armato": varia colpo su
  // colpo, quindi si azzera insieme alla traiettoria — cioè a ogni apertura
  // di pannello, cambio di giocatrice, registrazione e undo, che passano
  // tutti da _azzeraTraiettoriaInLine. Uno solo per entrambi i pannelli:
  // nostro e avversario non convivono mai, come per _traiettoriaNormalizzata.
  TipoAttacco _tipoAttaccoInLine = TipoAttacco.nonSpecificato;

  void _azzeraTraiettoriaInLine() {
    _timerMuroInLine?.cancel();
    _inZonaReteInLine = false;
    _frecciaInLine.value = null;
    _traiettoriaNormalizzata = null;
    _tipoAttaccoInLine = TipoAttacco.nonSpecificato;
  }

  // Il TIPO di esecuzione col disegno in-line è RISOLTO (2026-08-22), da
  // entrambe le parti, e sempre dalla colonna di sinistra della pulsantiera:
  // i tipi di servizio in fase battuta (_colonnaTipiBattuta) e i tipi di
  // attacco dopo un tratto disegnato (_colonnaTipiAttacco). I chip di
  // TrajectoryScreen restano per la strada classica, dove quella schermata si
  // apre ancora. Provata prima la pressione prolungata sul battitore
  // (2026-08-21) e scartata: il gesto non convince, e comunque un gesto non
  // deve mai competere col trascinamento o col tocco singolo.
  //
  // Si disegna se: interruttore acceso, un pannello è aperto, e vale lo stesso
  // gate di TrajectoryScreen (traiettorie attive + premium — vedi
  // _registraVoto). Fuori dalla modalità test, che non scrive azioni vere.
  // Durante il TUTORIAL mai: in questa fase di prova il tutorial passa sempre
  // dalla schermata dedicata, così i suoi passi restano validi qualunque cosa
  // dica l'interruttore.
  //
  // NON si guarda il fondamentale: in fase libera non è ancora stato scelto
  // quando il dito comincia a trascinare, e pretenderlo prima costringerebbe a
  // premere "Attacco" per poter disegnare. Si cattura e basta; poi è chi
  // registra a usare il tratto solo se il fondamentale lo prevede (vedi
  // `richiedeTraiettoria` in _scriviVoto), altrimenti lo butta.
  bool get _traiettoriaInLineAttiva =>
      _pannelloAperto && _traiettorieInLineConsentite;

  // Le condizioni che NON dipendono dal pannello: servono anche un istante
  // prima che si apra, quando il trascinamento parte dal giocatore stesso.
  //
  // Il TUTORIAL passa di qui come una partita vera (dal 2026-08-22): il disegno
  // sul campo è l'unico modo di prendere una traiettoria, quindi insegnarne un
  // altro non avrebbe senso. Durante il tutorial il premio è già attivo e le
  // traiettorie si forzano accese, come per la vecchia schermata dedicata.
  // Resta fuori solo la modalità test, che non scrive azioni vere.
  bool get _traiettorieInLineConsentite {
    if (_testModeEnabled) return false;
    if (!widget.tutorial && !ref.read(impostazioniProvider).traiettorieAbilitate) {
      return false;
    }
    return widget.tutorial || ref.read(statoPremiumProvider).attivo;
  }

  // In battuta il servizio si batte da QUALSIASI punto della linea di fondo,
  // non solo da dove sta disegnato il token: tutta la fascia fuori dal campo,
  // dal lato nostro, arma il battitore. In quell'istante non c'è altro da
  // fare, quindi il gesto non è ambiguo — e il punto da cui parti resta il
  // punto di partenza del tratto, che è un dato vero (da dove ha servito).
  // Stesse condizioni di _buildBattitoreTapCatcher, tenute in un posto solo.
  ({VoidCallback apri, Object identita})? get _aperturaBattitore {
    if (_squadraAlServizio != Squadra.nostra) return null;
    if (_faseDopo) return null;
    final player = _currentAssignments['P1'];
    if (player == null) return null;
    final onTap = _tapHandlerPerGiocatore(player, slot: 'P1');
    if (onTap == null) return null;
    return (apri: onTap, identita: player.id);
  }

  // Speculare per la battuta AVVERSARIA: stesse condizioni del loro
  // tap-catcher. Anche loro servono da tutta la linea di fondo, e la loro
  // fascia sta dal lato opposto alla nostra.
  ({VoidCallback apri, Object identita})? get _aperturaBattitoreAvversario {
    if (!_attesaBattutaAvversaria) return null;
    final slot = _statoSetReale?.palleggiatoreAvversarioSlot;
    if (slot == null) return null;
    final ruolo = etichetteAvversarie(slot)[1]!; // ruolo in zona 1
    final onTap = _tapHandlerAvversario(ruolo, forzato: Fondamentale.battuta);
    if (onTap == null) return null;
    return (apri: onTap, identita: ruolo);
  }

  // La fascia: fuori dal riquadro campo in orizzontale e dentro la sua
  // altezza. `latoDestro` dice quale delle due — la nostra segue il cambio
  // campo, quella avversaria è sempre l'altra.
  bool _nellaFascia(
    Offset p,
    double courtLeft,
    double courtWidth, {
    required bool latoDestro,
  }) {
    final courtHeight = courtWidth / 2;
    if (p.dy < _kCourtTopMargin || p.dy > _kCourtTopMargin + courtHeight) {
      return false;
    }
    return latoDestro ? p.dx > courtLeft + courtWidth : p.dx < courtLeft;
  }

  // Gesti di un token giocatore: il tocco lo seleziona come sempre, e in più
  // `onTapDown` mette da parte la stessa callback perché il gestore del
  // movimento possa invocarla se il gesto si rivela un TRASCINAMENTO — così la
  // traiettoria si può cominciare direttamente dal giocatore, senza il tocco
  // separato. `onTapDown` scatta subito alla pressione, prima che si sappia se
  // sarà tocco o trascinamento; `onTap` invece si arrende appena il dito si
  // muove, ed è il motivo per cui da solo non basterebbe.
  // I due non si sovrappongono mai: se trascini, `onTap` non scatta.
  Widget _tokenConTrascinamento(
    VoidCallback onTap,
    Object identita, [
    Widget? child,
  ]) {
    return GestureDetector(
      onTapDown: (_) =>
          _aperturaDaTrascinamento = (apri: onTap, identita: identita),
      onTap: onTap,
      child: child,
    );
  }

  // Soglia oltre la quale il gesto è un trascinamento e non un tocco: la
  // stessa di TrajectoryScreen, proporzionale al campo con un minimo assoluto
  // (su tablet il campo è molto più grande e gli stessi px direbbero meno).
  static double _sogliaTrascinamento(double courtWidth) =>
      math.max(24.0, courtWidth * 0.04);

  // NB: `_gestoSullaCard` non va azzerato qui. Lo alza il Listener sulla card,
  // che essendo più PROFONDO riceve l'evento PRIMA di questo antenato
  // (HitTestResult.path si costruisce scendendo e dispatchEvent lo percorre in
  // quell'ordine): azzerarlo adesso cancellerebbe quello che è appena stato
  // scritto. Si azzera al rilascio.
  void _onPointerDownCampo(PointerDownEvent event) =>
      _pointerGiu = event.localPosition;

  // Il tocco a muro vale per l'attacco, non per la battuta (attraversare la
  // rete su un servizio è normale). In fase LIBERA il fondamentale non è
  // ancora stato scelto: lì un'azione offensiva può solo essere un attacco —
  // la battuta passa sempre dalla fase servizio — quindi si consente.
  bool get _muroConsentitoInLine =>
      (_votoInCorso?.fondamentale ?? _avversarioInCorso?.fondamentale) !=
      Fondamentale.battuta;

  void _onPointerMoveCampo(
      PointerMoveEvent event, double courtLeft, double courtWidth) {
    final giu = _pointerGiu;
    if (giu == null || _gestoSullaCard) return;
    if (!_traiettorieInLineConsentite) return;
    final pos = event.localPosition;

    // Il dito è sceso su un giocatore e adesso sta trascinando: si apre il
    // pannello per lui, così la traiettoria parte dal token senza il tocco
    // separato che lo seleziona. Vale anche a pannello già aperto — trascinare
    // da un'ALTRA giocatrice cambia selezione, come farebbe un tocco — ma NON
    // se è la stessa già selezionata: lì si sta solo ridisegnando il tratto, e
    // ri-selezionarla azzererebbe un voto eventualmente già scelto.
    // Va fatto PRIMA della cattura, perché il gate _traiettoriaInLineAttiva
    // pretende il pannello aperto — e `_votoInCorso` è valorizzato dentro il
    // setState, quindi subito dopo risulta già aperto.
    var candidato = _aperturaDaTrascinamento;
    // Nessun token sotto al dito, ma siamo nella fascia della linea di fondo
    // mentre si sta per servire: vale come se avessi toccato il battitore. Due
    // fasce, una per squadra: la nostra segue il cambio campo, la loro è
    // sempre quella opposta. I due getter sono già esclusivi fra loro (o
    // serviamo noi o servono loro), ma il lato va controllato lo stesso —
    // altrimenti un tratto partito dalla fascia sbagliata armerebbe comunque
    // il battitore, con un punto di partenza che non ha senso.
    if (candidato == null && !_pannelloAperto) {
      if (_nellaFascia(giu, courtLeft, courtWidth, latoDestro: _isRightSide)) {
        candidato = _aperturaBattitore;
      } else if (_nellaFascia(giu, courtLeft, courtWidth,
          latoDestro: !_isRightSide)) {
        candidato = _aperturaBattitoreAvversario;
      }
    }
    // Battuta: il tratto può partire solo da dietro la linea di fondo di CHI
    // SERVE. Se parte dalla fascia opposta non è una battuta possibile — si
    // ignora invece di registrare una partenza dall'altra parte del campo.
    // Si scarta solo la fascia sbagliata, non tutto: partire un po' dentro al
    // campo resta legittimo, il dito non è preciso al pixel.
    final battutaInCorso =
        (_votoInCorso?.fondamentale ?? _avversarioInCorso?.fondamentale) ==
            Fondamentale.battuta;
    if (battutaInCorso) {
      final latoSbagliato =
          _votoInCorso != null ? !_isRightSide : _isRightSide;
      if (_nellaFascia(giu, courtLeft, courtWidth,
          latoDestro: latoSbagliato)) {
        return;
      }
    }

    if (candidato != null && candidato.identita != _identitaSelezionata) {
      if ((pos - giu).distance < _sogliaTrascinamento(courtWidth)) {
        return; // ancora un tocco: lo gestirà `onTap` al rilascio
      }
      candidato.apri();
    }
    if (!_traiettoriaInLineAttiva) return;
    final precedente = _frecciaInLine.value;
    final inCorso = _traiettoriaNormalizzata == null &&
        precedente != null; // trascinamento già riconosciuto
    if (!inCorso && (pos - giu).distance < _sogliaTrascinamento(courtWidth)) {
      return; // ancora un tocco, non un trascinamento
    }

    // TOCCO A MURO, per soffermamento (vedi _kSoffermamentoReteInLine).
    // Non basta attraversare la rete: bisogna restare nella fascia per un
    // attimo, altrimenti ogni attacco che la scavalca lascerebbe uno snodo.
    // Il dwell NON può basarsi sui soli eventi di movimento (col dito fermo
    // non ne arrivano): serve un Timer avviato all'ingresso nella fascia e
    // annullato se se ne esce prima che scada.
    final xRete = courtLeft + courtWidth / 2;
    final muroGiaPreso = precedente?.muro;
    if (_muroConsentitoInLine && muroGiaPreso == null) {
      final dentroFascia = (pos.dx - xRete).abs() <= _kToleranzaReteInLine;
      if (dentroFascia && !_inZonaReteInLine) {
        _inZonaReteInLine = true;
        _timerMuroInLine = Timer(_kSoffermamentoReteInLine, () {
          final f = _frecciaInLine.value;
          if (!mounted || f == null || f.muro != null) return;
          // Lo snodo si aggancia alla rete, come fa TrajectoryScreen.
          _frecciaInLine.value = (
            inizio: f.inizio,
            fine: f.fine,
            muro: Offset(xRete, f.fine.dy),
            inZonaRete: false,
          );
        });
      } else if (!dentroFascia && _inZonaReteInLine) {
        _inZonaReteInLine = false;
        _timerMuroInLine?.cancel();
      }
    }

    // Niente setState: il disegno passa dal notifier (vedi _frecciaInLine).
    _frecciaInLine.value = (
      inizio: muroGiaPreso != null ? precedente!.inizio : giu,
      fine: pos,
      muro: muroGiaPreso,
      inZonaRete: _inZonaReteInLine && muroGiaPreso == null,
    );
    // Il tratto vecchio è superato: la normalizzata si ricalcola al rilascio.
    _traiettoriaNormalizzata = null;
  }

  void _onPointerUpCampo(
    double courtLeft,
    double courtTop,
    double courtWidth,
    double courtHeight,
  ) {
    _pointerGiu = null;
    _gestoSullaCard = false;
    _aperturaDaTrascinamento = null;
    // Il soffermamento vale solo col dito giù: se il tocco a muro non è
    // scattato prima del rilascio, non deve scattare dopo.
    _timerMuroInLine?.cancel();
    _inZonaReteInLine = false;
    final freccia = _frecciaInLine.value;
    if (freccia == null || _traiettoriaNormalizzata != null) {
      return; // nessun trascinamento in questo gesto
    }
    // Tratto troppo corto (il dito è tornato quasi al punto di partenza):
    // quasi sempre involontario, e una freccia lunga zero non dice nulla e
    // andrebbe poi annullata a mano. Si scarta, come fa TrajectoryScreen.
    final origine = freccia.muro ?? freccia.inizio;
    if ((freccia.fine - origine).distance <
        _sogliaTrascinamento(courtWidth)) {
      _azzeraTraiettoriaInLine();
      return;
    }

    // ALTERNATIVA PROVATA E MESSA DA PARTE — "stacco e ripresa del dito":
    // rilasciare dentro la fascia della rete fissava lo snodo e il
    // trascinamento successivo portava la palla a destinazione, senza timer
    // né sosta col dito fermo. Provata sul device il 2026-08-21 e scartata a
    // favore del soffermamento (vedi _onPointerMoveCampo), che convince di
    // più. Tenuta qui a promemoria perché la porta resta aperta;
    // l'implementazione completa (record con `inSospeso`, ripresa del tratto
    // nel gestore di movimento) sta nel commit 03fb19d, non serve riscriverla
    // da zero se si decide di tornarci.
    //
    //   if (freccia.muro == null &&
    //       _muroConsentitoInLine &&
    //       (freccia.fine.dx - xRete).abs() <= _kToleranzaReteInLine) {
    //     ... snodo agganciato alla rete, attesa del secondo tratto ...
    //   }

    final f = _frecciaInLine.value!;
    _traiettoriaNormalizzata = (
      x1: (f.inizio.dx - courtLeft) / courtWidth,
      y1: (f.inizio.dy - courtTop) / courtHeight,
      x2: (f.fine.dx - courtLeft) / courtWidth,
      y2: (f.fine.dy - courtTop) / courtHeight,
      muroX: f.muro == null ? null : (f.muro!.dx - courtLeft) / courtWidth,
      muroY: f.muro == null ? null : (f.muro!.dy - courtTop) / courtHeight,
    );

    // DOPO aver fissato la traiettoria, mai prima: la preselezione può far
    // partire la registrazione (vedi sotto), che deve trovarla già pronta.
    // Vale ANCHE col tratto appeso alla rete: un trascinamento che finisce lì
    // è già di per sé un attacco — quello sbagliato a rete — e deve poter
    // essere chiuso con un `=` senza altri passaggi. Se invece era l'inizio di
    // un tocco a muro, il secondo tratto arriva e prosegue: il fondamentale
    // era comunque attacco.
    _preselezionaAttaccoDaTraiettoria();
  }

  // In fase LIBERA un tratto disegnato può solo essere un attacco: la battuta
  // passa sempre dalla fase servizio, dove il fondamentale è già imposto, e
  // alzata/muro/difesa non hanno traiettoria. Chiederlo sarebbe un tocco
  // sprecato, quindi si preseleziona da sé.
  //
  // Sovrascrive anche una scelta già fatta nella colonna: se hai disegnato un
  // tratto quell'azione È un attacco, e il tocco precedente era lo sbaglio.
  // NON tocca invece il fondamentale imposto dalla FASE (battuta, ricezione):
  // lì il tratto o è già della battuta giusta, o va buttato — trasformare una
  // ricezione in attacco corromperebbe l'azione. La distinzione è la stessa
  // che regge il chip nell'header: sta fra i quattro della colonna oppure no.
  //
  // Conseguenza voluta: se il voto era già stato scelto, la coppia si completa
  // qui e l'azione parte al rilascio del dito. È la stessa regola di sempre
  // ("si registra quando ci sono entrambe"), applicata a una metà che invece
  // di un bottone arriva da un trascinamento.
  // Mai nella pulsantiera RISTRETTA (dopo un `#` avversario): lì le uniche
  // risposte possibili sono muro e difesa, e preselezionare un attacco
  // disabilitato lascerebbe il pannello in uno stato incoerente.
  void _preselezionaAttaccoDaTraiettoria() {
    if (_votoInCorso != null &&
        _sceltoNellaColonna(_votoInCorso!.fondamentale) &&
        !_difesaErroreForzataNostra) {
      _sceglieFondamentale(Fondamentale.attacco);
    } else if (_avversarioInCorso != null &&
        _sceltoNellaColonna(_avversarioInCorso!.fondamentale) &&
        !_difesaErroreForzataAvversaria) {
      _scegliFondamentaleAvversario(Fondamentale.attacco);
    }
  }

  // `null` (ancora da scegliere) o una delle quattro voci della colonna: in
  // entrambi i casi la scelta è dell'utente e si può sovrascrivere. Battuta e
  // ricezione invece le impone la fase e non si toccano.
  bool _sceltoNellaColonna(Fondamentale? fondamentale) =>
      fondamentale == null || _kFondamentaliPulsantiera.contains(fondamentale);

  // Guardia contro il doppio tocco rapido sull'ultimo bottone della coppia:
  // _registraVoto è async (attende TrajectoryScreen e la scrittura a DB) e
  // senza questa un secondo tocco arrivato nel frattempo registrerebbe due
  // azioni identiche. Abbassata solo a registrazione conclusa.
  bool _registrazioneInCorso = false;

  // Azioni (solo `scout`) dello scambio CORRENTE ancora aperto, o [] se nessuno
  // scambio è aperto (l'ultima azione di scambio ha chiuso il punto, o non ce
  // n'è ancora). DERIVATO dallo stream (non stato locale): così undo/ripresa
  // tornano coerenti da soli. Timeout/correzione rotazione (esito `nessuno` ma
  // non aprono uno scambio) sono ignorati nel decidere se il rally è aperto.
  List<ScoutAction> get _azioniRallyCorrente {
    final set = _setCorrente;
    if (set == null) return const [];
    final righe =
        ref.watch(scoutAzioniStreamProvider(set.id)).value ?? const [];
    ScoutAction? ultimaScambio;
    for (final a in righe.reversed) {
      if (a.tipo == TipoAzione.timeout ||
          a.tipo == TipoAzione.correzioneRotazione) {
        continue;
      }
      ultimaScambio = a;
      break;
    }
    if (ultimaScambio == null ||
        ultimaScambio.esitoPunto != EsitoPunto.nessuno) {
      return const [];
    }
    final rallyId = ultimaScambio.rallyId;
    return [
      for (final a in righe)
        if (a.rallyId == rallyId && a.tipo == TipoAzione.scout) a,
    ];
  }

  // True dopo che il fondamentale giudicabile dello scambio corrente (la NOSTRA
  // battuta se serviamo noi, la NOSTRA ricezione se servono loro) è stato
  // giudicato — palla in gioco, siamo nella fase "dopo". DERIVATO: lo scambio
  // aperto contiene una nostra azione di quel fondamentale. Immune all'undo
  // (prima era un flag manuale ricalcolato a mano, fragile con le azioni
  // avversarie in mezzo). In modalità test la fase "dopo" la governa
  // _testDopo via _faseDopo, quindi qui non si guarda lo stream.
  bool get _fondamentaleGiudicatoRallyCorrente {
    final forzato = _squadraAlServizio == Squadra.nostra
        ? Fondamentale.battuta
        : Fondamentale.ricezione;
    return _azioniRallyCorrente.any(
      (a) => a.squadra == Squadra.nostra && a.fondamentale == forzato,
    );
  }

  // Scout avversari attivo per questo set: c'è uno slot del palleggiatore
  // avversario (toggle ON + zona scelta a inizio set), fuori dalla modalità
  // test. Gate dei token avversari e della fase "battuta avversaria".
  bool get _scoutAvversariAttivo =>
      !_testModeEnabled && _statoSetReale?.palleggiatoreAvversarioSlot != null;

  // Fase globale dello scambio corrente (battuta → ricezione → libera),
  // derivata dalle azioni. Governa la tappabilità e il fondamentale forzato di
  // ENTRAMBE le squadre. Con scout avversari attivo è SIMMETRICA (si registrano
  // battuta e ricezione di chi serve/riceve). Con scout avversari OFF resta il
  // comportamento attuale: serviamo noi → solo la nostra battuta (niente
  // ricezione avversaria → subito libera); servono loro → solo la nostra
  // ricezione (niente loro battuta → si parte dalla fase ricezione).
  _FaseScambio get _faseScambio {
    final azioni = _azioniRallyCorrente;
    final battutaFatta =
        azioni.any((a) => a.fondamentale == Fondamentale.battuta);
    final ricezioneFatta =
        azioni.any((a) => a.fondamentale == Fondamentale.ricezione);
    if (_scoutAvversariAttivo) {
      if (!battutaFatta) return _FaseScambio.servizio;
      if (!ricezioneFatta) return _FaseScambio.ricezione;
      return _FaseScambio.libera;
    }
    if (_squadraAlServizio == Squadra.nostra) {
      return battutaFatta ? _FaseScambio.libera : _FaseScambio.servizio;
    }
    return ricezioneFatta ? _FaseScambio.libera : _FaseScambio.ricezione;
  }

  // Fase "battuta avversaria": fase servizio con loro al servizio (solo con
  // scout avversari attivo, vedi _faseScambio). L'unico tap-target è il loro
  // battitore in zona 1 (fuori campo) — nessun nostro giocatore, nessun altro
  // loro token — specularmente al nostro servizio.
  bool get _attesaBattutaAvversaria =>
      _faseScambio == _FaseScambio.servizio &&
      _squadraAlServizio == Squadra.avversari;

  // Fase "ricezione avversaria": fase ricezione con noi al servizio (solo con
  // scout avversari attivo). I token avversari sono tappabili forzati su
  // Ricezione, i nostri giocatori bloccati — speculare alla nostra ricezione.
  bool get _attesaRicezioneAvversaria =>
      _faseScambio == _FaseScambio.ricezione &&
      _squadraAlServizio == Squadra.nostra;

  // Fase libera dello scambio (palla in gioco, azioni forzate concluse): qui i
  // token avversari sono tappabili per attacco/muro/difesa.
  bool get _faseLiberaScambio => _faseScambio == _FaseScambio.libera;

  // Tappabile in questa fase di gioco, a prescindere dal fondamentale:
  // - servizio: solo il nostro P1 (il battitore), e solo se serviamo noi;
  // - ricezione: chiunque, ma solo se riceviamo noi (servono loro);
  // - libera: chiunque.
  // Il fondamentale (Alzata/Attacco/Muro/Difesa in fase libera) si sceglie nel
  // pannello — vedi _sceglieFondamentale.
  bool _giocatoreTappabile(String? slot) {
    final servizio = _squadraAlServizio;
    switch (_faseScambio) {
      case _FaseScambio.servizio:
        return servizio == Squadra.nostra && slot == 'P1';
      case _FaseScambio.ricezione:
        return servizio == Squadra.avversari;
      case _FaseScambio.libera:
        return true;
    }
  }

  // Fondamentale forzato dalla fase di gioco (battuta in fase servizio,
  // ricezione in fase ricezione), o null in fase libera (va scelto nel
  // pannello tra Alzata/Attacco/Muro/Difesa).
  Fondamentale? _fondamentaleForzato() {
    switch (_faseScambio) {
      case _FaseScambio.servizio:
        return Fondamentale.battuta;
      case _FaseScambio.ricezione:
        return Fondamentale.ricezione;
      case _FaseScambio.libera:
        return null;
    }
  }

  // Le tre posizioni di SECONDA LINEA (zone 1, 6, 5), le stesse in cui gioca
  // il libero. Due forme della stessa cosa: i nostri token sono indicizzati
  // per SLOT ('P1'..'P6'), quelli avversari per ZONA (1..6), che non hanno un
  // roster da cui ricavare uno slot (vedi _buildTokenAvversari).
  static const _kSlotSecondaLinea = {'P1', 'P6', 'P5'};
  static const _kZoneSecondaLinea = {1, 6, 5};

  // In fase LIBERA il fondamentale non lo impone nessuno e va scelto nella
  // colonna: è il tocco in più che pesa di più, perché è il caso più frequente
  // della partita. Chi sta in seconda linea però quasi sempre DIFENDE, quindi
  // aprendo il pannello la difesa è già selezionata.
  //
  // È una PRESELEZIONE, non una scelta: resta correggibile con un tocco sulla
  // colonna e da sola non registra niente — a chiudere l'azione è sempre e
  // solo il voto. Per questo il tocco risparmiato non si paga con un errore
  // possibile, che è invece il difetto della pulsantiera a matrice.
  //
  // Il libero non ha uno slot proprio (`slot` null) ed è per definizione di
  // seconda linea.
  //
  // NB: fra i tre c'è anche il PALLEGGIATORE quando la rotazione lo porta
  // dietro (3 rotazioni su 6 nel 5-1), e quello alza più spesso di quanto
  // difenda. Tenuto comunque a difesa perché è quello che è stato chiesto: se
  // in campo dà fastidio, basta escludere lo slot del palleggiatore qui.
  Fondamentale? _preselezioneSecondaLinea(String? slot) =>
      slot == null || _kSlotSecondaLinea.contains(slot)
          ? Fondamentale.difesa
          : null;

  // Gemella avversaria: stessa regola, ma i loro token sono identificati dal
  // RUOLO e la seconda linea si legge dalla ZONA che quel ruolo occupa nella
  // loro rotazione (`etichetteAvversarie`). Nessun caso "null = libero": gli
  // avversari sono un 5-1 canonico senza libero, quindi zona ignota → nessuna
  // preselezione. Vale anche qui il discorso sul loro palleggiatore dietro.
  Fondamentale? _preselezioneSecondaLineaAvversaria(int? zona) =>
      zona != null && _kZoneSecondaLinea.contains(zona)
          ? Fondamentale.difesa
          : null;

  // Scorciatoia Modello A: se l'ultima azione dello scambio è un'offensiva `#`
  // (ace/kill) dell'ALTRA squadra rispetto a `difensore`, la risposta difensiva
  // è deterministicamente un ERRORE. Ritorna il fondamentale difensivo dovuto
  // (ricezione se il `#` era una battuta, difesa se era un attacco), altrimenti
  // null. Permette il tap "veloce" sul difensore → `=` diretto, saltando il
  // pannello (il pallone contestato/non attribuibile si segna comunque coi
  // bottoni rapidi "Punto avversario/nostro").
  Fondamentale? _erroreDifensivoForzato(Squadra difensore) {
    final azioni = _azioniRallyCorrente;
    if (azioni.isEmpty) return null;
    final ultima = azioni.last;
    if (ultima.voto != Voto.perfetto) return null;
    if (ultima.squadra == difensore) return null; // l'offensiva è dell'altra
    return switch (ultima.fondamentale) {
      Fondamentale.battuta => Fondamentale.ricezione,
      Fondamentale.attacco => Fondamentale.difesa,
      _ => null,
    };
  }

  // Dopo un `#`, deve poter agire SOLO chi difende: i token della squadra che
  // ha appena attaccato sono bloccati (tap ignorato) e mostrati attenuati.
  // Nostri bloccati = abbiamo attaccato noi (attende la difesa avversaria);
  // avversari bloccati = hanno attaccato loro (attende la nostra difesa).
  bool get _nostriTokenBloccati =>
      _erroreDifensivoForzato(Squadra.avversari) != null;
  bool get _tokenAvversariBloccati =>
      _erroreDifensivoForzato(Squadra.nostra) != null;

  // Fondamentale difensivo ancora da registrare per chiudere il punto (Modello
  // A): dopo un `#` di battuta serve la RICEZIONE errata, dopo un `#` di attacco
  // la DIFESA errata — di una delle due squadre (il colpo vincente non chiude
  // da solo). Null se non c'è nulla in sospeso. Alimenta il banner-promemoria
  // "CONCLUDI …"; auto-gated (con scout avversari OFF un `#` chiude subito, il
  // rally non resta aperto e questo torna null).
  Fondamentale? get _difesaDaConcludere =>
      _erroreDifensivoForzato(Squadra.nostra) ??
      _erroreDifensivoForzato(Squadra.avversari);

  // Attenuazione (alpha 0.5) per SQUADRA in base alla fase: la squadra "in
  // attesa" (che non deve agire ORA) si mostra attenuata. DISTINTA dalla
  // tappabilità: nella fase servizio la squadra che batte NON è attenuata
  // anche se solo il battitore accetta il tap. Solo con scout avversari
  // attivo (senza, resta tutto a piena opacità come prima). In fase libera
  // si attenua solo la squadra che ha appena chiuso con un `#` (deve
  // difendere l'altra) — il resto della fase libera tutti pieni.
  //   - servizio: attiva chi serve → l'ALTRA squadra è in attesa;
  //   - ricezione: attiva chi riceve → chi ha servito è in attesa;
  //   - libera: in attesa la squadra bloccata dopo un `#` (nessuna altrimenti).
  bool get _nostriInAttesa {
    if (!_scoutAvversariAttivo) return false;
    switch (_faseScambio) {
      case _FaseScambio.servizio:
        return _squadraAlServizio != Squadra.nostra; // battono loro → riceviamo
      case _FaseScambio.ricezione:
        return _squadraAlServizio == Squadra.nostra; // battiamo noi → ricevono
      case _FaseScambio.libera:
        return _nostriTokenBloccati; // dopo un NOSTRO `#`: difende l'avversario
    }
  }

  bool get _avversariInAttesa {
    if (!_scoutAvversariAttivo) return false;
    switch (_faseScambio) {
      case _FaseScambio.servizio:
        return _squadraAlServizio != Squadra.avversari;
      case _FaseScambio.ricezione:
        return _squadraAlServizio == Squadra.avversari;
      case _FaseScambio.libera:
        return _tokenAvversariBloccati;
    }
  }

  // Modalità "errore difensivo ristretto" del pannello: dopo un `#` di ATTACCO
  // dell'altra squadra (kill), la risposta difensiva può essere muro O difesa
  // (a differenza dell'ace, dove è solo ricezione → tap diretto). Il pannello
  // fondamentali mostra allora SOLO Muro/Difesa in rosso (= errore diretto),
  // Alzata/Attacco disabilitati. `_difesaErroreForzataNostra` = un attacco `#`
  // avversario attende la NOSTRA difesa; l'omologo avversario è speculare.
  bool get _difesaErroreForzataNostra =>
      _erroreDifensivoForzato(Squadra.nostra) == Fondamentale.difesa;
  bool get _difesaErroreForzataAvversaria =>
      _erroreDifensivoForzato(Squadra.avversari) == Fondamentale.difesa;

  // Registra al volo un errore difensivo NOSTRO (scorciatoia sopra): ricezione/
  // difesa `=` per il giocatore toccato, senza pannello. L'esito è
  // `puntoAvversario` (Modello A: il punto dell'ace/kill lo porta la difesa).
  Future<void> _registraErroreDifensivoRapido(
      Player player, Fondamentale fondamentale) async {
    final set = _setCorrente;
    if (set == null) return;
    await ref.read(scoutActionRepositoryProvider).registraAzioneScout(
          setId: set.id,
          squadra: Squadra.nostra,
          giocatoreId: player.id,
          fondamentale: fondamentale,
          voto: Voto.errore,
          esitoPunto: _esitoVoto(fondamentale, Voto.errore),
        );
    if (!mounted) return;
    // Entrambi: la scorciatoia si può innescare anche col pannello dell'altra
    // squadra aperto, da quando toccare un token la cambia al volo.
    _chiudiPannelli();
  }

  // Tap-target per il voto di un giocatore: fuori dalla modalità test, col
  // set già iniziato e questo slot tappabile nella fase corrente (vedi
  // _giocatoreTappabile). `slot` è null per il libero (nessuno slot P1-P6
  // proprio).
  VoidCallback? _tapHandlerPerGiocatore(Player player, {String? slot}) {
    if (_testModeEnabled) return null;
    if (_setCorrente == null) return null;
    // Il pannello avversario aperto NON blocca più: toccare un nostro token ci
    // passa direttamente sopra. Le azioni si susseguono veloci e chiudere
    // prima il pannello era un tocco sprecato. I due pannelli restano
    // mutuamente esclusivi come STATO: chi apre chiude l'altro (sotto).
    // Dopo un NOSTRO `#`: deve difendere l'avversario, i nostri token bloccati.
    if (_nostriTokenBloccati) return null;
    if (!_giocatoreTappabile(slot)) return null;
    // Scorciatoia dopo un `#` avversario:
    // - ace (battuta `#`): la risposta è solo ricezione → `=` diretto, senza
    //   pannello;
    // - kill (attacco `#`): la risposta può essere muro O difesa → apri il
    //   pannello ristretto (Muro/Difesa in rosso → `=`, vedi
    //   _buildPulsantiera con _difesaErroreForzataNostra).
    final erroreForzato = _erroreDifensivoForzato(Squadra.nostra);
    if (erroreForzato == Fondamentale.ricezione) {
      return () => _registraErroreDifensivoRapido(player, erroreForzato!);
    }
    if (erroreForzato == Fondamentale.difesa) {
      return () => setState(() {
            _votoInCorso =
                (giocatore: player, fondamentale: null, voto: null);
            _avversarioInCorso = null;
            _azzeraTraiettoriaInLine();
          });
    }
    final forzato = _fondamentaleForzato();
    // In fase libera (forzato == null) chi gioca dietro parte su Difesa —
    // preselezione correggibile, vedi _preselezioneSecondaLinea.
    final iniziale = forzato ?? _preselezioneSecondaLinea(slot);
    return () => setState(() {
      _votoInCorso = (giocatore: player, fondamentale: iniziale, voto: null);
      _avversarioInCorso = null; // i due pannelli non convivono mai
      // Azione nuova (o cambio di giocatrice a pannello aperto): la freccia
      // eventualmente disegnata era di quella prima e non va ereditata.
      _azzeraTraiettoriaInLine();
      // Il tipo di battuta selezionato resta "armato" da una battuta
      // all'altra dello stesso giocatore (spesso batte sempre nello stesso
      // modo); cambia battitore → si azzera, non si assume che batta uguale.
      if (forzato == Fondamentale.battuta &&
          _giocatoreTipoBattutaArmato != player.id) {
        _tipoBattutaSelezionato = TipoBattuta.nonSpecificato;
        _giocatoreTipoBattutaArmato = player.id;
      }
    });
  }

  // Le due metà della coppia del pannello nostro: colonna sinistra
  // (Difesa/Attacco/Muro/Alzata, solo in fase libera) e colonna destra (i 5
  // voti). Si riempiono in qualsiasi ordine; a coppia completa
  // _provaRegistrare fa partire la scrittura. Ri-toccare la stessa colonna
  // CORREGGE la scelta senza scrivere nulla — è il motivo per cui la
  // registrazione è rimandata al momento in cui entrambe sono valorizzate.
  void _sceglieFondamentale(Fondamentale fondamentale) {
    final inCorso = _votoInCorso;
    if (inCorso == null) return;
    setState(() {
      _votoInCorso = (
        giocatore: inCorso.giocatore,
        fondamentale: fondamentale,
        voto: inCorso.voto,
      );
    });
    _provaRegistrare();
  }

  void _scegliVoto(Voto voto) {
    final inCorso = _votoInCorso;
    if (inCorso == null) return;
    setState(() {
      _votoInCorso = (
        giocatore: inCorso.giocatore,
        fondamentale: inCorso.fondamentale,
        voto: voto,
      );
    });
    _provaRegistrare();
  }

  void _provaRegistrare() {
    final inCorso = _votoInCorso;
    if (inCorso?.fondamentale == null || inCorso?.voto == null) return;
    _registraVoto();
  }

  // Tipo di battuta opzionale. Si sceglie in DUE posti che scrivono lo stesso
  // campo, quindi non possono divergere: la colonna di sinistra della
  // pulsantiera quando la fase è il servizio (vedi _colonnaTipiBattuta) e la
  // riga di chip di TrajectoryScreen, dove la schermata si apre ancora.
  // nonSpecificato ("Generico") di default, mai bloccante per il flusso
  // veloce: se non lo tocchi, il voto registra lo stesso.
  // Resta ARMATO per lo stesso battitore (spesso serve sempre allo stesso
  // modo) e si azzera al cambio battitore — vedi _tapHandlerPerGiocatore.
  TipoBattuta _tipoBattutaSelezionato = TipoBattuta.nonSpecificato;

  // Gemello per la battuta AVVERSARIA. Resta armato come il nostro: il loro
  // battitore È identificabile — è il RUOLO in zona 1, che ricaviamo dalla
  // loro rotazione (`etichetteAvversarie`), la stessa identità che usano i
  // token avversari. Cambia il ruolo al servizio → si riparte da Generico.
  // Il ruolo indica la posizione nella loro rotazione, non una persona: fra
  // un set e l'altro potrebbe essere un'altra giocatrice, ma lo stato vive in
  // ScoutScreen e si azzera comunque a ogni set.
  TipoBattuta _tipoBattutaAvversario = TipoBattuta.nonSpecificato;
  String? _ruoloTipoBattutaArmato;

  // Sceglie il tipo di servizio dalla pulsantiera e lo ARMA per quel
  // battitore. Non registra: a chiudere l'azione è sempre e solo il voto.
  void _scegliTipoBattuta(Player battitore, TipoBattuta tipo) {
    setState(() {
      _tipoBattutaSelezionato = tipo;
      _giocatoreTipoBattutaArmato = battitore.id;
    });
  }
  int? _giocatoreTipoBattutaArmato;

  // Esito automatico del voto (Modello A — "la difesa porta il punto"):
  // - qualunque fondamentale con voto "errore" → punto avversario (battuta in
  //   rete/fuori, ricezione non tenuta, attacco murato/fuori, difesa sbagliata,
  //   muro out);
  // - muro "perfetto" → punto nostro (muro punto, terminale di suo);
  // - battuta/attacco "perfetto" (ace/schiacciata vincente): punto diretto SOLO
  //   con scout avversari OFF; con scout avversari attivo NON chiude (nessuno)
  //   — il punto lo porta la loro ricezione/difesa errata registrata dopo (vedi
  //   Modello A), così l'ace/kill non viene contato due volte;
  // - tutto il resto (alzata, ricezione/difesa non terminali) → nessuno.
  EsitoPunto _esitoVoto(Fondamentale fondamentale, Voto voto) {
    if (voto == Voto.errore) return EsitoPunto.puntoAvversario;
    if (fondamentale == Fondamentale.muro && voto == Voto.perfetto) {
      return EsitoPunto.puntoNostro;
    }
    if ((fondamentale == Fondamentale.battuta ||
            fondamentale == Fondamentale.attacco) &&
        voto == Voto.perfetto) {
      return _scoutAvversariAttivo
          ? EsitoPunto.nessuno
          : EsitoPunto.puntoNostro;
    }
    return EsitoPunto.nessuno;
  }

  // Registra la coppia (fondamentale, voto) composta nel pannello. Chiamata
  // solo da _provaRegistrare, cioè quando entrambe le colonne sono state
  // toccate — in qualsiasi ordine.
  Future<void> _registraVoto() async {
    if (_registrazioneInCorso) return;
    final set = _setCorrente;
    final inCorso = _votoInCorso;
    final fondamentale = inCorso?.fondamentale;
    final voto = inCorso?.voto;
    if (set == null || inCorso == null || fondamentale == null || voto == null) {
      return;
    }
    _registrazioneInCorso = true;
    try {
      await _scriviVoto(set, inCorso.giocatore, fondamentale, voto);
    } finally {
      _registrazioneInCorso = false;
    }
  }

  Future<void> _scriviVoto(
    MatchSet set,
    Player giocatore,
    Fondamentale fondamentale,
    Voto voto,
  ) async {
    final esito = _esitoVoto(fondamentale, voto);

    // La traiettoria è già stata disegnata sul campo PRIMA del voto: qui non si
    // apre nessuna schermata, si prende quello che c'è (o niente, se non è
    // stato disegnato — è il vecchio "salta", senza un bottone per dirlo).
    // `richiedeTraiettoria` serve perché il tratto si cattura anche in fase
    // libera, quando il fondamentale non è ancora stato scelto: se poi si
    // rivela un'alzata o una difesa, il disegno si butta.
    // GATE PREMIUM E IMPOSTAZIONI: stanno dentro _traiettorieInLineConsentite,
    // che decide anche se il tratto si poteva disegnare. Per un utente free non
    // si disegna e basta — nessun paywall in mezzo alla presa dati (quello
    // compare solo da menu e report, che sono azioni deliberate).
    final inLine = _traiettoriaInLineAttiva && fondamentale.richiedeTraiettoria
        ? _traiettoriaNormalizzata
        : null;

    // I tipi di esecuzione vengono dalla colonna della pulsantiera: quelli di
    // servizio in fase battuta, quelli di attacco dopo un tratto disegnato
    // (vedi _colonnaTipiBattuta / _colonnaTipiAttacco).
    final tipoEsecuzione = switch (fondamentale) {
      Fondamentale.battuta => _tipoBattutaSelezionato.name,
      Fondamentale.attacco => _tipoAttaccoInLine.name,
      _ => 'nonSpecificato',
    };

    await ref
        .read(scoutActionRepositoryProvider)
        .registraAzioneScout(
          setId: set.id,
          squadra: Squadra.nostra,
          giocatoreId: giocatore.id,
          fondamentale: fondamentale,
          voto: voto,
          esitoPunto: esito,
          tipoEsecuzione: tipoEsecuzione,
          traiettoriaX1: inLine?.x1,
          traiettoriaY1: inLine?.y1,
          traiettoriaX2: inLine?.x2,
          traiettoriaY2: inLine?.y2,
          traiettoriaMuroX: inLine?.muroX,
          traiettoriaMuroY: inLine?.muroY,
        );
    if (!mounted) return;
    setState(() {
      _votoInCorso = null;
      _azzeraTraiettoriaInLine();
      // _fondamentaleGiudicatoRallyCorrente è ora derivato dallo stream: si
      // aggiorna da solo appena l'azione entra nel replay.
      // I tipi selezionati NON si azzerano qui: restano "armati" se lo
      // stesso giocatore ripete la stessa azione (vedi
      // _tapHandlerPerGiocatore/_sceglieFondamentale).
    });
  }

  // --- Flusso azioni AVVERSARIE (parallelo, isolato dal nostro) ---

  // Esito INVERTITO rispetto a _esitoVoto, dal punto di vista dell'AVVERSARIO
  // (Modello A). Le azioni avversarie esistono solo con scout avversari attivo,
  // quindi qui il Modello A vale sempre:
  // - loro errore (battuta out, attacco fuori, ricezione/difesa sbagliata) →
  //   punto NOSTRO;
  // - loro muro perfetto (muro punto) → punto LORO (terminale);
  // - loro battuta/attacco perfetto (ace/kill) → nessuno: il punto lo porta la
  //   NOSTRA ricezione/difesa errata registrata dopo (no doppio conteggio);
  // - resto → nessuno.
  EsitoPunto _esitoVotoAvversario(Fondamentale fondamentale, Voto voto) {
    if (voto == Voto.errore) return EsitoPunto.puntoNostro;
    if (fondamentale == Fondamentale.muro && voto == Voto.perfetto) {
      return EsitoPunto.puntoAvversario;
    }
    return EsitoPunto.nessuno;
  }

  // Registra al volo un errore difensivo AVVERSARIO (scorciatoia simmetrica):
  // loro ricezione/difesa `=` dopo un NOSTRO `#` (ace/kill), senza pannello.
  // Esito `puntoNostro` (Modello A: il punto lo porta la loro difesa errata).
  Future<void> _registraErroreDifensivoAvversarioRapido(
      String ruolo, Fondamentale fondamentale) async {
    final set = _setCorrente;
    if (set == null) return;
    await ref.read(scoutActionRepositoryProvider).registraAzioneAvversaria(
          setId: set.id,
          ruoloAvversario: ruolo,
          fondamentale: fondamentale,
          voto: Voto.errore,
          esitoPunto: _esitoVotoAvversario(fondamentale, Voto.errore),
        );
    if (!mounted) return;
    _chiudiPannelli(); // vedi il gemello nostro

  }

  // Tap su un token avversario: apre il pannello avversario (scelta
  // fondamentale poi voto). Disabilitato in modalità test, prima dell'inizio
  // del set o durante la selezione della zona iniziale. Il nostro pannello
  // voto aperto NON blocca: il tocco lo sostituisce.
  // `zona` (1-6) serve solo alla preselezione della difesa in fase libera:
  // si passa da lì, non dal ruolo, perché è la POSIZIONE a dire chi difende.
  VoidCallback? _tapHandlerAvversario(String ruolo,
      {Fondamentale? forzato, int? zona}) {
    if (_testModeEnabled) return null;
    if (_setCorrente == null) return null;
    if (_inSelezionePAvversario) return null;
    // Come sopra: il nostro pannello aperto non blocca il tocco su un token
    // avversario, lo sostituisce.
    // Dopo un `#` avversario: dobbiamo difendere noi, i loro token bloccati.
    if (_tokenAvversariBloccati) return null;
    // Scorciatoia dopo un NOSTRO `#` (speculare a _tapHandlerPerGiocatore):
    // - ace (battuta `#`): loro ricezione `=` diretta;
    // - kill (attacco `#`): pannello ristretto Muro/Difesa → `=`.
    final erroreForzato = _erroreDifensivoForzato(Squadra.avversari);
    if (erroreForzato == Fondamentale.ricezione) {
      return () =>
          _registraErroreDifensivoAvversarioRapido(ruolo, erroreForzato!);
    }
    if (erroreForzato == Fondamentale.difesa) {
      return () => setState(() {
            _avversarioInCorso =
                (ruolo: ruolo, fondamentale: null, voto: null);
            _votoInCorso = null;
            _azzeraTraiettoriaInLine();
          });
    }
    // In fase libera (forzato == null) chi gioca dietro parte su Difesa,
    // come i nostri — vedi _preselezioneSecondaLineaAvversaria.
    final iniziale = forzato ?? _preselezioneSecondaLineaAvversaria(zona);
    return () => setState(() {
          _avversarioInCorso =
              (ruolo: ruolo, fondamentale: iniziale, voto: null);
          _votoInCorso = null; // i due pannelli non convivono mai
          // Stessa regola del nostro battitore: il tipo resta armato finché
          // serve lo stesso RUOLO, e si azzera quando cambia.
          if (forzato == Fondamentale.battuta &&
              _ruoloTipoBattutaArmato != ruolo) {
            _tipoBattutaAvversario = TipoBattuta.nonSpecificato;
            _ruoloTipoBattutaArmato = ruolo;
          }
          // Come nel pannello nostro: la freccia di un'azione precedente non
          // va ereditata dalla nuova.
          _azzeraTraiettoriaInLine();
        });
  }

  // Le due metà della coppia avversaria — speculari a _sceglieFondamentale/
  // _scegliVoto, stessa regola: si registra solo quando entrambe ci sono.
  void _scegliFondamentaleAvversario(Fondamentale fondamentale) {
    final inCorso = _avversarioInCorso;
    if (inCorso == null) return;
    setState(() => _avversarioInCorso = (
          ruolo: inCorso.ruolo,
          fondamentale: fondamentale,
          voto: inCorso.voto,
        ));
    _provaRegistrareAvversario();
  }

  void _scegliVotoAvversario(Voto voto) {
    final inCorso = _avversarioInCorso;
    if (inCorso == null) return;
    setState(() => _avversarioInCorso = (
          ruolo: inCorso.ruolo,
          fondamentale: inCorso.fondamentale,
          voto: voto,
        ));
    _provaRegistrareAvversario();
  }

  void _provaRegistrareAvversario() {
    final inCorso = _avversarioInCorso;
    if (inCorso?.fondamentale == null || inCorso?.voto == null) return;
    _registraVotoAvversario();
  }

  Future<void> _registraVotoAvversario() async {
    if (_registrazioneInCorso) return;
    final set = _setCorrente;
    final inCorso = _avversarioInCorso;
    final fondamentale = inCorso?.fondamentale;
    final voto = inCorso?.voto;
    if (set == null || inCorso == null || fondamentale == null || voto == null) {
      return;
    }
    _registrazioneInCorso = true;
    try {
      await _scriviVotoAvversario(set, inCorso.ruolo, fondamentale, voto);
    } finally {
      _registrazioneInCorso = false;
    }
  }

  Future<void> _scriviVotoAvversario(
    MatchSet set,
    String ruolo,
    Fondamentale fondamentale,
    Voto voto,
  ) async {
    final esito = _esitoVotoAvversario(fondamentale, voto);

    // Traiettoria per battuta/attacco avversari — stesso flusso del nostro
    // _scriviVoto: il tratto si disegna sul campo prima del voto, dal token
    // avversario (loro metà) verso la nostra.
    final inLine = _traiettoriaInLineAttiva && fondamentale.richiedeTraiettoria
        ? _traiettoriaNormalizzata
        : null;

    // Dalla colonna della pulsantiera, come per noi. Il tipo di battuta resta
    // "armato" finché serve lo stesso RUOLO (vedi _ruoloTipoBattutaArmato);
    // quello di attacco non si arma mai, né per noi né per loro.
    final tipoEsecuzione = switch (fondamentale) {
      Fondamentale.battuta => _tipoBattutaAvversario.name,
      Fondamentale.attacco => _tipoAttaccoInLine.name,
      _ => 'nonSpecificato',
    };

    await ref.read(scoutActionRepositoryProvider).registraAzioneAvversaria(
          setId: set.id,
          ruoloAvversario: ruolo,
          fondamentale: fondamentale,
          voto: voto,
          esitoPunto: esito,
          tipoEsecuzione: tipoEsecuzione,
          traiettoriaX1: inLine?.x1,
          traiettoriaY1: inLine?.y1,
          traiettoriaX2: inLine?.x2,
          traiettoriaY2: inLine?.y2,
          traiettoriaMuroX: inLine?.muroX,
          traiettoriaMuroY: inLine?.muroY,
        );
    if (!mounted) return;
    // La fase (_fondamentaleGiudicatoRallyCorrente/_attesaBattutaAvversaria) è
    // derivata dallo stream: si aggiorna da sola con la nuova azione.
    setState(() {
      _avversarioInCorso = null;
      _azzeraTraiettoriaInLine();
    });
  }

  // Mappa di ricezione attiva per la rotazione corrente, solo se: stiamo
  // ricevendo (batte l'avversario), la ricezione di questo scambio non è
  // ancora stata giudicata (una volta giudicata con un voto non terminale,
  // la palla è in gioco verso l'attacco: i giocatori si spostano in
  // posizione di gioco, stessa logica del battitore dopo la battuta — vedi
  // _faseDopo), e i dati di quella rotazione sono completi. Senza libero in
  // formazione: stessa "forma" difensiva ma con le posizioni REALI di tutti
  // i 6 ruoli, nessuna sostituzione (vedi _kDefensePositionsComplete). Con
  // libero: la tabella e la coppia sostituita dipendono da
  // _ruoloCambiLiberoEffettivo — se centrali, deve restare un solo C1/C2
  // (l'altro è il libero) e S1/S2 entrambi presenti; se schiacciatori, il
  // contrario. In modalità test segue _testDopo (vedi _testAvanza) invece
  // dei voti reali.
  Map<String, Offset>? get _activeDefenseMap {
    if (_squadraAlServizio != Squadra.avversari) return null;
    if (_faseDopo) return null;
    if (_is62) {
      // Nel 6-2 il libero è sempre sui centrali (variante unica).
      return defenseMapFor62(
        rotazione: _currentSlot,
        senzaLibero: !_liberiEffettivi.containsKey('L1'),
      );
    }
    if (!_liberiEffettivi.containsKey('L1')) {
      return defenseMapFor(
        rotazione: _currentSlot,
        senzaLibero: true,
        liberoSuSchiacciatori: false,
      );
    }
    // Il ruolo→variante e il fallback su ruolo inatteso (null) restano qui, per
    // preservare esattamente il comportamento precedente; la selezione tabella
    // + controllo di completezza è in defenseMapFor.
    final ruolo = _ruoloCambiLiberoEffettivo;
    final bool liberoSuSchiacciatori;
    if (ruolo == Ruolo.centrale || ruolo == Ruolo.undefined) {
      liberoSuSchiacciatori = false;
    } else if (ruolo == Ruolo.schiacciatore) {
      liberoSuSchiacciatori = true;
    } else {
      return null;
    }
    return defenseMapFor(
      rotazione: _currentSlot,
      senzaLibero: false,
      liberoSuSchiacciatori: liberoSuSchiacciatori,
    );
  }

  // Slot di rotazione del palleggiatore avversario ('P1'..'P6'), o null se lo
  // scout avversari non è attivo per il set. Determina l'intera rotazione
  // avversaria (5-1 canonico, vedi etichetteAvversarie) e ruota sui loro
  // sideout tramite ricalcolaStato.
  String? get _currentSlotAvversario {
    final slot = _statoSetReale?.palleggiatoreAvversarioSlot;
    return slot == null ? null : 'P$slot';
  }

  // Mappa TATTICA ruolo→posizione dell'avversario per la fase corrente, sul
  // campo SINISTRO (da specchiare con _mirrorAvversario). Speculare a
  // _activeAttackMap/_activeDefenseMap ma pilotata da _faseScambio (globale) e
  // dalla rotazione avversaria. L'avversario è un placeholder che gioca il
  // nostro stesso 5-1 SENZA libero, quindi senzaLibero: true sempre:
  //   - loro servizio, battuta non ancora fatta → attackMapFor(battuta)
  //     (il battitore in zona 1 finisce fuori campo, X<0 → mirror X>1200);
  //   - loro servizio, battuta fatta → attackMapFor(dopoBattuta);
  //   - nostro servizio, loro ricezione non ancora fatta (fase servizio o
  //     ricezione) → defenseMapFor (formazione di ricezione);
  //   - nostro servizio, loro ricezione fatta (fase libera) →
  //     attackMapFor(dopoRicezione).
  Map<String, Offset>? get _mappaAvversario {
    final slot = _currentSlotAvversario;
    if (slot == null) return null;
    if (_squadraAlServizio == Squadra.avversari) {
      final fase = _faseScambio == _FaseScambio.servizio
          ? FaseAttacco.battuta
          : FaseAttacco.dopoBattuta;
      return attackMapFor(
        rotazione: slot,
        fase: fase,
        senzaLibero: true,
        liberoSuSchiacciatori: false,
      );
    }
    if (_faseScambio != _FaseScambio.libera) {
      return defenseMapFor(
        rotazione: slot,
        senzaLibero: true,
        liberoSuSchiacciatori: false,
      );
    }
    return attackMapFor(
      rotazione: slot,
      fase: FaseAttacco.dopoRicezione,
      senzaLibero: true,
      liberoSuSchiacciatori: false,
    );
  }

  // Posizione (spazio di riferimento 1200×600, metà avversaria) di un ruolo
  // avversario: mirror della sua posizione tattica sul campo sinistro
  // (_mappaAvversario), con fallback alla zona di rotazione fissa
  // (_kOpponentZonePositions) se la mappa non copre quel ruolo — non dovrebbe
  // capitare col 5-1 senza libero (6 ruoli completi), è una guardia.
  Offset _posizioneAvversario(String ruolo, int zonaFallback) {
    final base = _mappaAvversario?[ruolo];
    if (base != null) return _mirrorAvversario(base);
    return _kOpponentZonePositions[zonaFallback]!;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _avviaOCaricaSet());
  }

  @override
  void dispose() {
    _timerLampeggio?.cancel();
    _timerLampeggioTick?.cancel();
    _timerMuroInLine?.cancel();
    _frecciaInLine.dispose();
    super.dispose();
  }

  // Lampeggio ON/OFF del punteggio (vedi _rilevaCambioPunteggio /
  // _buildScoreDisplay): un timer periodico alterna acceso/spento, un timer
  // one-shot lo ferma dopo la durata totale.
  Timer? _timerLampeggio; // stop dopo la durata totale
  Timer? _timerLampeggioTick; // alterna acceso/spento
  bool _lampeggioAcceso = true; // false = numero nascosto (fase "off")
  // Lato il cui numero sta lampeggiando ora (null = nessuno).
  Squadra? _squadraLampeggiante;
  // Ultimo punteggio "stabilito" per rilevare i cambi. `null` finché lo
  // stream delle azioni non ha prodotto il primo dato: così alla ripresa di
  // una partita già in corso il salto 0 → punteggio reale NON fa lampeggiare
  // (diventa solo la baseline).
  int? _prevPunteggioNostro;
  int? _prevPunteggioAvversario;

  // Chiamata in cima a build: confronta il punteggio corrente con l'ultimo
  // stabilito e, se è cambiato, avvia il lampeggio sul lato che è cambiato.
  // Gate su `hasValue` dello stream: durante il caricamento _statoSetReale
  // vale 0-0 (azioni vuote), non deve contare come baseline.
  void _rilevaCambioPunteggio() {
    final set = _setCorrente;
    final pronto = set != null &&
        ref.watch(scoutAzioniStreamProvider(set.id)).hasValue;
    if (!pronto) return;
    final n = _punteggioNostro;
    final a = _punteggioAvversario;
    if (_prevPunteggioNostro != null &&
        (_prevPunteggioNostro != n || _prevPunteggioAvversario != a)) {
      final cambiata =
          _prevPunteggioNostro != n ? Squadra.nostra : Squadra.avversari;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _avviaLampeggioPunteggio(cambiata);
      });
    }
    _prevPunteggioNostro = n;
    _prevPunteggioAvversario = a;
  }

  void _avviaLampeggioPunteggio(Squadra squadra) {
    _timerLampeggio?.cancel();
    _timerLampeggioTick?.cancel();
    setState(() {
      _squadraLampeggiante = squadra;
      _lampeggioAcceso = true; // parte visibile, primo "off" dopo un periodo
    });
    _timerLampeggioTick = Timer.periodic(_kPeriodoLampeggioPunteggio, (_) {
      if (!mounted) return;
      setState(() => _lampeggioAcceso = !_lampeggioAcceso);
    });
    _timerLampeggio = Timer(_kDurataLampeggioPunteggio, () {
      if (!mounted) return;
      _timerLampeggioTick?.cancel();
      setState(() {
        _squadraLampeggiante = null;
        _lampeggioAcceso = true; // sempre visibile a fine lampeggio
      });
    });
  }

  // Punto di ingresso unico per l'avvio dello schermo: provo a caricare il
  // set numero `match.setCorrente`. Se esiste già (ripresa di una partita
  // in corso, O di una partita già `terminata` che si vuole correggere —
  // vedi sotto) lo riprendo senza richiedere di nuovo "chi serve per
  // primo". Se non esiste ancora — sia il primissimo set della partita
  // (stato ancora `configurazione`), sia un nuovo set dopo "Prossimo Set"
  // in `EndSetScreen` (stato già `inCorso`, ma `setCorrente` è stato
  // incrementato a monte e quel set non è stato ancora creato) — lo
  // richiedo e lo creo: stessa logica per entrambi i casi, non serve più
  // distinguerli guardando `stato`.
  Future<void> _avviaOCaricaSet() async {
    final setRepo = ref.read(matchSetRepositoryProvider);
    final esistente = await setRepo.caricaSet(
      widget.match.id,
      widget.match.setCorrente,
    );
    if (!mounted) return;
    if (esistente != null) {
      // Riprendere lo scout (anche da MatchesScreen → "Riprendi" su una
      // partita già `terminata`, es. per correggere un'azione) significa
      // che si torna a scoutare attivamente: `terminata` deve sempre voler
      // dire "scout non in corso ora", quindi torna `inCorso` — solo "Fine
      // Partita" la riporta a `terminata`.
      if (widget.match.stato != StatoPartita.inCorso) {
        await ref
            .read(matchRepositoryProvider)
            .updateMatch(widget.match.copyWith(stato: StatoPartita.inCorso));
      }
      if (!mounted) return;
      setState(() => _setCorrente = esistente);
    } else {
      await _chiediServizioIniziale();
    }
  }

  Future<void> _chiediServizioIniziale() async {
    final avversario = widget.match.avversario?.trim();
    final nomeAvversario = (avversario != null && avversario.isNotEmpty)
        ? avversario
        : AppLocalizations.of(context).scoutAvversariGenerico;

    final scelta = await showDialog<Squadra>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(AppLocalizations.of(context).scoutServizioTitolo),
        content: Text(AppLocalizations.of(context).scoutServizioTesto),
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

    // `setCorrente` non si tocca qui: è già quello giusto, impostato alla
    // creazione della partita (1) o incrementato da EndSetScreen prima di
    // arrivare a questa schermata ("Prossimo Set").
    await matchRepo.updateMatch(
      widget.match.copyWith(stato: StatoPartita.inCorso),
    );
    final set = await setRepo.creaSet(
      widget.match.id,
      widget.match.setCorrente,
      servizioIniziale,
    );
    await setRepo.salvaRotazioneIniziale(
      set.id,
      widget.assignments,
      ruoloCambiLibero: widget.ruoloCambiLibero,
      sistemaGioco: widget.sistemaGioco,
    );

    if (!mounted) return;
    setState(() => _setCorrente = set);

    // Se lo scout avversari è attivo, si sceglie sul campo la zona del
    // palleggiatore avversario a inizio set: da lì ricalcolaStato deriva la
    // loro rotazione placeholder. Solo per i set nuovi (qui): alla ripresa lo
    // slot è già persistito e si rilegge da _setCorrente.
    if (ref.read(impostazioniProvider).scoutAvversariAbilitato) {
      setState(() => _inSelezionePAvversario = true);
    }
  }

  /// Conferma la zona (1-6) toccata sul campo per il palleggiatore avversario:
  /// salva lo slot sul MatchSet (`salvaPalleggiatoreAvversario`), aggiorna la
  /// copia locale ed esce dalla modalità selezione.
  Future<void> _confermaPAvversario(int zona) async {
    final set = _setCorrente;
    if (set == null) return;
    final aggiornato = await ref
        .read(matchSetRepositoryProvider)
        .salvaPalleggiatoreAvversario(set.id, zona);
    if (!mounted) return;
    setState(() {
      _setCorrente = aggiornato;
      _inSelezionePAvversario = false;
    });
  }

  // Numero di rotazioni applicate da inizio set — usato SOLO in modalità
  // test (positivo = avanti, P1→P2; negativo = indietro, P1→P6) per simulare
  // tutte le combinazioni senza eventi reali. Fuori dalla modalità test la
  // rotazione vera viene da _statoSetReale (derivata dagli eventi).
  int _rotationSteps = 0;

  String get _currentSlot {
    final stato = _testModeEnabled ? null : _statoSetReale;
    if (stato != null) {
      // Il palleggiatore designato EFFETTIVO viene dallo stato derivato
      // (può cambiare con un cambio giocatore, override nell'evento) — il
      // fallback su widget copre solo stato senza palleggiatoreId.
      final palleggiatoreId =
          stato.palleggiatoreId ??
          widget.assignments[widget.palleggiatoreSlot]?.id;
      for (final entry in stato.rotazione.entries) {
        if (entry.value == palleggiatoreId) return 'P${entry.key}';
      }
    }
    final originalIndex = _kSlotOrder.indexOf(widget.palleggiatoreSlot);
    return _kSlotOrder[_mod(
      originalIndex + _rotationSteps,
      _kSlotOrder.length,
    )];
  }

  // Mappa slot -> giocatore aggiornata in base alla rotazione corrente.
  Map<String, Player> get _currentAssignments {
    final stato = _testModeEnabled ? null : _statoSetReale;
    if (stato != null) {
      // _rosterById (non widget.assignments): dopo un cambio giocatore la
      // rotazione può contenere il subentrante, che partiva dalla panchina.
      final idToPlayer = _rosterById;
      final result = <String, Player>{};
      for (final entry in stato.rotazione.entries) {
        final player = idToPlayer[entry.value];
        if (player != null) result['P${entry.key}'] = player;
      }
      if (result.length == 6) return result;
    }
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

  // Slot (1-6) del palleggiatore DOPO una correzione rotazione nel verso dato,
  // per la label del bottone: `avanti` (rotazione di gioco/sideout) porta il
  // palleggiatore a slot−1 (P1→P6), `indietro` a slot+1 (P1→P2).
  int _slotDestinazioneCorrezione(DirezioneRotazione direzione) {
    final s = int.parse(_currentSlot.substring(1));
    return direzione == DirezioneRotazione.avanti
        ? (s == 1 ? 6 : s - 1)
        : (s == 6 ? 1 : s + 1);
  }

  // Correzione manuale della rotazione (bottoni sotto la mini-mappa): registra
  // l'evento loggato — punteggio/rotazione si ri-derivano da _statoSetReale,
  // undo standard la annulla. Non tocca _fondamentaleGiudicatoRallyCorrente
  // (una correzione non giudica un fondamentale né apre/chiude uno scambio).
  Future<void> _correggiRotazione(DirezioneRotazione direzione) async {
    final set = _setCorrente;
    if (set == null || _testModeEnabled) return;
    await ref
        .read(scoutActionRepositoryProvider)
        .registraCorrezioneRotazione(setId: set.id, direzione: direzione);
  }

  // Slot del palleggiatore AVVERSARIO dopo la correzione nel verso dato (label
  // del bottone) — parte dallo slot CORRENTE derivato (che si sposta della
  // stessa quantità dell'iniziale, vedi _correggiRotazioneAvversario). Stessa
  // convenzione della nostra: avanti = slot−1 (P1→P6), indietro = slot+1.
  int _slotDestinazioneCorrezioneAvversario(DirezioneRotazione direzione) {
    final s = _statoSetReale?.palleggiatoreAvversarioSlot ??
        _setCorrente?.palleggiatoreAvversarioSlot ??
        1;
    return direzione == DirezioneRotazione.avanti
        ? (s == 1 ? 6 : s - 1)
        : (s == 6 ? 1 : s + 1);
  }

  // Correzione della rotazione AVVERSARIA. A differenza della nostra (evento
  // loggato), qui si edita l'UNICO dato da cui deriva tutta la loro rotazione:
  // lo slot INIZIALE del palleggiatore avversario su MatchSet. Spostarlo di ±1
  // sposta la rotazione corrente della stessa quantità E ricalcola
  // RETROATTIVAMENTE zone/report di tutte le loro azioni (tutto replaya da lì) —
  // così si rimedia a un'identificazione sbagliata del loro alzatore a inizio
  // set. Non è un evento (come la correzione manuale del punteggio, vive su
  // MatchSet): si "annulla" ruotando indietro.
  Future<void> _correggiRotazioneAvversario(DirezioneRotazione direzione) async {
    final set = _setCorrente;
    if (set == null || _testModeEnabled) return;
    final iniziale = set.palleggiatoreAvversarioSlot;
    if (iniziale == null) return;
    final nuovo = direzione == DirezioneRotazione.avanti
        ? (iniziale == 1 ? 6 : iniziale - 1)
        : (iniziale == 6 ? 1 : iniziale + 1);
    final aggiornato = await ref
        .read(matchSetRepositoryProvider)
        .salvaPalleggiatoreAvversario(set.id, nuovo);
    if (!mounted) return;
    setState(() => _setCorrente = aggiornato);
  }

  // Slot (1-6) del palleggiatore in uno stato derivato — posizione che tiene
  // il palleggiatore designato effettivo; fallback sullo slot iniziale.
  int _slotPalleggiatore(StatoSet stato) {
    final id = stato.palleggiatoreId ??
        widget.assignments[widget.palleggiatoreSlot]?.id;
    for (final entry in stato.rotazione.entries) {
      if (entry.value == id) return entry.key;
    }
    return int.tryParse(widget.palleggiatoreSlot.substring(1)) ?? 1;
  }

  // Etichetta "Rotazione P{iniziale} → P{finale}" per ogni correzione
  // rotazione del set: lo slot del palleggiatore PRIMA e DOPO ciascuna, così
  // ogni voce del log è corretta al suo momento (non la rotazione attuale).
  // Riusa ricalcolaStato() sui prefissi delle azioni (nessuna duplicazione
  // della logica di replay). Calcolata solo se c'è almeno una correzione.
  Map<int, String> _computeLabelsCorrezione() {
    final set = _setCorrente;
    if (set == null) return const {};
    final righe =
        ref.watch(scoutAzioniStreamProvider(set.id)).value ??
            const <ScoutAction>[];
    if (!righe.any((r) => r.tipo == TipoAzione.correzioneRotazione)) {
      return const {};
    }
    final eventi = [for (final r in righe) azioneScoutDaRiga(r)];
    StatoSet prefisso(int count) => ricalcolaStato(
          azioni: eventi.sublist(0, count),
          servizioIniziale: set.squadraServizioIniziale,
          rotazioneIniziale: _rotazioneInizialeMap,
          palleggiatoreInizialeId:
              widget.assignments[widget.palleggiatoreSlot]?.id,
          ruoloCambiLiberoIniziale: widget.ruoloCambiLibero,
          liberoInizialeId: widget.assignments['L1']?.id,
          libero2InizialeId: widget.assignments['L2']?.id,
        );
    final result = <int, String>{};
    for (var i = 0; i < righe.length; i++) {
      if (righe[i].tipo != TipoAzione.correzioneRotazione) continue;
      final iniziale = _slotPalleggiatore(prefisso(i));
      final finale = _slotPalleggiatore(prefisso(i + 1));
      result[righe[i].id] = 'Rotazione P$iniziale → P$finale';
    }
    return result;
  }

  // Quando la squadra ataca dal campo di destra, le posizioni vanno
  // riflesse rispetto al centro dell'immagine doppia (rotazione di 180°,
  // non un semplice mirror orizzontale): chi era in basso a sinistra finisce
  // in alto a destra. Coordinate di riferimento 1200×600.
  bool _isRightSide = false;

  // null = convenzione automatica (L1 in ricezione, L2 in servizio);
  // 'L1' o 'L2' = libero bloccato per il resto del set (tap manuale).
  // Si resetta automaticamente al set successivo (nuova istanza ScoutScreen).
  String? _liberoOverride;

  void _toggleSide() => setState(() => _isRightSide = !_isRightSide);

  Offset _displayPosition(Offset refPos) =>
      _isRightSide ? Offset(1200 - refPos.dx, 600 - refPos.dy) : refPos;

  // "Nome nostro - Nome avversario" di default: il nome della squadra di cui
  // si fa lo scout va sempre sul lato dove sono disegnati i suoi giocatori
  // (non dipende da casa/trasferta, solo dal cambio campo).
  String get _matchTitle {
    final nostro = widget.team.nome;
    final avversarioRaw = widget.match.avversario?.trim();
    final avversario = (avversarioRaw != null && avversarioRaw.isNotEmpty)
        ? avversarioRaw
        : AppLocalizations.of(context).scoutAvversariMaiuscolo;
    final nostroASinistra = !_isRightSide;
    return nostroASinistra ? '$nostro - $avversario' : '$avversario - $nostro';
  }

  // Di default i token mostrano il numero di maglia; disattivando il toggle
  // mostrano il ruolo.
  bool _showJerseyNumbers = true;

  // Log azioni (toggle nel drawer, VISIBILE di default): pannello
  // scrollabile ancorato al bordo destro con tutte le ScoutAction del SET
  // CORRENTE, più recente in alto, aggiornato in tempo reale dallo stesso
  // stream di _statoSetReale. Nascosto mentre il pannello voto è aperto
  // (occupa la stessa zona dello schermo).
  bool _showActionLog = true;

  // Mini-map: quale rotazione mostra il badge. Default la NOSTRA; con scout
  // avversario attivo un tap sulla finestra alterna con quella avversaria
  // (distinta dal colore del badge). I due bottoni di correzione rotazione
  // agiscono sulla squadra selezionata. Riparte da false a ogni set (nuova
  // istanza ScoutScreen).
  bool _minimapAvversari = false;

  // Punteggio del set in corso, derivato da _statoSetReale (eventi reali) +
  // l'eventuale correzione manuale persistita su MatchSet (vedi
  // _correggiPunteggio — override diretto del valore mostrato, NON loggato
  // come ScoutAction: fine set/match sono già decisioni manuali, non serve
  // restare fedeli al log eventi per il punteggio). Segue lo stesso
  // criterio del titolo: il punteggio "nostro" è sempre mostrato sul lato
  // dove sono disegnati i nostri giocatori (a sinistra di default, a
  // destra col cambio campo).
  int get _punteggioNostro =>
      (_statoSetReale?.punteggioNostro ?? 0) +
      (_setCorrente?.correzionePuntiNostri ?? 0);
  int get _punteggioAvversario =>
      (_statoSetReale?.punteggioAvversario ?? 0) +
      (_setCorrente?.correzionePuntiAvversari ?? 0);

  // Bottoni rapidi (+1 Noi/+1 Loro/Errore nostro/Errore avversario):
  // percorso alternativo ai 3 tocchi, registrano subito un ScoutAction.
  // Disabilitati prima dell'inizio del set e durante la modalità test (per
  // non sporcare i dati reali del set con azioni di prova). Stessa
  // condizione usata per i bottoni di correzione punteggio (_correggiPunteggio).
  bool get _bottoniRapidiAttivi =>
      _setCorrente != null &&
      !_testModeEnabled &&
      !_inSelezionePAvversario;

  // Override manuale del punteggio (bottoni +/- accanto al numero): somma
  // il delta alla correzione già persistita su MatchSet (mai loggato come
  // ScoutAction, vedi sopra) e aggiorna `_setCorrente` localmente — non
  // c'è uno stream da osservare per questi due campi, quindi va fatto a
  // mano (a differenza di punteggio/rotazione "veri", derivati da
  // _statoSetReale che osserva scoutAzioniStreamProvider).
  Future<void> _correggiPunteggio(Squadra squadra, int delta) async {
    final set = _setCorrente;
    if (set == null) return;
    final aggiornato = await ref
        .read(matchSetRepositoryProvider)
        .correggiPunteggio(
          set.id,
          deltaNostro: squadra == Squadra.nostra ? delta : 0,
          deltaAvversario: squadra == Squadra.avversari ? delta : 0,
        );
    if (!mounted) return;
    setState(() => _setCorrente = aggiornato);
  }

  Future<void> _registraAzioneRapida(
    Squadra squadra,
    TipoAzione tipo,
    EsitoPunto esito, {
    String tipoEsecuzione = 'nonSpecificato',
  }) async {
    final set = _setCorrente;
    if (set == null) return;
    await ref
        .read(scoutActionRepositoryProvider)
        .registraAzioneRapida(
          setId: set.id,
          squadra: squadra,
          tipo: tipo,
          esitoPunto: esito,
          tipoEsecuzione: tipoEsecuzione,
        );
    if (!mounted) return;
    setState(() {
      // _fondamentaleGiudicatoRallyCorrente è derivato dallo stream: il punto
      // chiude lo scambio e la fase si aggiorna da sola.
      // Un bottone rapido chiude comunque lo scambio: il pannello voto,
      // se ancora aperto, non avrebbe più senso (l'esito è già stato
      // deciso per un'altra via).
      _votoInCorso = null;
      _azzeraTraiettoriaInLine();
    });
  }

  // Undo: attivo solo col set iniziato, fuori dalla modalità test (che non
  // scrive azioni reali) e con almeno un'azione da annullare.
  bool get _puoAnnullare =>
      !_testModeEnabled && _setCorrente != null && _ultimaAzione != null;

  // "Annulla lo scambio": stesse condizioni dell'undo singolo, più il fatto
  // che ci sia davvero uno scambio da annullare. Se l'ultima azione è un
  // timeout, una correzione rotazione o un cambio, _azioniUltimoRally torna
  // vuota e il tasto resta spento (per quelle c'è l'undo singolo).
  bool get _puoAnnullareRally =>
      _puoAnnullare && _azioniUltimoRally.isNotEmpty;

  // Conferma prima di cancellare TUTTO lo scambio (irreversibile: non c'è un
  // redo). Mostra solo il CONTEGGIO, non l'elenco: si legge a bordo campo,
  // quando l'arbitro ha appena fischiato di rigiocare.
  Future<void> _confermaAnnullaRally() async {
    final azioni = _azioniUltimoRally;
    if (azioni.isEmpty) return;
    final confermato = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l = AppLocalizations.of(context);
        return AlertDialog(
          scrollable: true,
          title: Text(l.scoutUndoRallyTitolo, style: const TextStyle(fontSize: 14)),
          content: Text(
            l.scoutUndoRallyTesto(azioni.length),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.comuneAnnulla),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.comuneConferma),
            ),
          ],
        );
      },
    );
    if (confermato != true) return;
    final set = _setCorrente;
    if (set == null) return;
    await ref
        .read(scoutActionRepositoryProvider)
        .annullaRally(setId: set.id, rallyId: azioni.first.rallyId);
    if (!mounted) return;
    // Come l'undo singolo: punteggio/servizio/rotazione si ricalcolano da soli
    // dallo stream, qui basta chiudere un eventuale pannello voto aperto.
    setState(() {
      _votoInCorso = null;
      _azzeraTraiettoriaInLine();
    });
  }

  // Dialog di conferma prima dell'undo vero e proprio (irreversibile: una
  // volta eliminata l'azione non c'è un "redo") — mostra una descrizione
  // dell'azione che verrebbe eliminata, riusando _descrizioneAzione (stesso
  // testo/voto del banner ultima azione).
  Future<void> _confermaAnnullaUltimaAzione() async {
    final azione = _ultimaAzione;
    if (azione == null) return;
    final descrizione = _descrizioneAzione(azione);
    var testoAzione = descrizione.voto == null
        ? descrizione.testo
        : '${descrizione.testo} ${descrizione.voto}';
    // Un blocco di cambi (es. doppio cambio) si annulla per intero:
    // avvisare se l'undo eliminerà più di una riga.
    final gruppo = azione.gruppoCambio;
    if (azione.tipo == TipoAzione.cambioGiocatore &&
        gruppo != null &&
        _setCorrente != null) {
      final n = await ref
          .read(scoutActionRepositoryProvider)
          .contaGruppoCambio(_setCorrente!.id, gruppo);
      if (n > 1) {
        testoAzione =
            '$testoAzione\n(verranno annullati tutti '
            'i $n cambi confermati insieme)';
      }
      if (!mounted) return;
    }
    final confermato = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(
          AppLocalizations.of(context).scoutUndoTitolo,
          style: const TextStyle(fontSize: 14),
        ),
        content: Text(
          testoAzione,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context).comuneAnnulla),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context).comuneConferma),
          ),
        ],
      ),
    );
    if (confermato == true) await _annullaUltimaAzione();
  }

  // Elimina l'azione con `ordine` massimo nel set (vedi
  // ScoutActionRepository.annullaUltimaAzione) — punteggio/servizio/
  // rotazione si ricalcolano da soli perché _statoSetReale osserva lo stesso
  // stream. `_fondamentaleGiudicatoRallyCorrente` è ora derivato dallo stream
  // (come punteggio/rotazione): dopo l'eliminazione dell'ultima azione, la
  // fase si ricalcola da sola: nessun aggiornamento manuale.
  Future<void> _annullaUltimaAzione() async {
    final set = _setCorrente;
    if (set == null) return;
    final repo = ref.read(scoutActionRepositoryProvider);
    await repo.annullaUltimaAzione(set.id);
    if (!mounted) return;
    setState(() {
      _votoInCorso = null;
      _azzeraTraiettoriaInLine();
    });
  }

  // --- Sostituzione (cambio giocatore) ---
  //
  // Flusso dalla voce "Sostituzione" del drawer: push di SostituzioneScreen
  // (campo con la rotazione CORRENTE + panchina, N cambi pending in una
  // visita — replica l'esperienza di inizio partita) → FormationConfigScreen
  // in modalità conferma (SEMPRE mostrata, precompilata coi valori
  // effettivi: nessun rilevamento automatico) → al ritorno, diff posizione
  // per posizione e UNA riga registraSostituzione per ogni cambio (gli
  // override di configurazione sull'ultima). Back a metà flusso = nessuna
  // riga scritta.
  Future<void> _avviaSostituzione() async {
    final set = _setCorrente;
    if (set == null || _testModeEnabled) return;

    final currentAssignments = _currentAssignments;
    final seiCorrenti = <String, Player>{
      for (final slot in _kSlotOrder)
        if (currentAssignments[slot] != null) slot: currentAssignments[slot]!,
    };
    if (seiCorrenti.length != 6) return; // dato incoerente, niente cambio
    final palleggiatoreSlotCorrente = _currentSlot;

    // Panchina: roster meno i 6 in campo, meno i liberi correnti. I
    // giocatori con ruolo libero RESTANO in panchina: un libero si può
    // cambiare, ma solo al posto di un altro libero (SostituzioneScreen
    // abilita/disabilita per ruolo in base alla card selezionata).
    final liberi = Map<String, Player>.of(_liberiEffettivi);
    final idsInCampo = {for (final p in seiCorrenti.values) p.id};
    final idsLiberi = {for (final p in liberi.values) p.id};
    final panchina = [
      for (final p in _rosterById.values)
        if (!idsInCampo.contains(p.id) && !idsLiberi.contains(p.id)) p,
    ];

    final risultato = await Navigator.push<RisultatoSostituzione>(
      context,
      MaterialPageRoute(
        builder: (_) => SostituzioneScreen(
          match: widget.match,
          team: widget.team,
          seiCorrenti: seiCorrenti,
          panchina: panchina,
          liberi: liberi,
          palleggiatoreSlotCorrente: palleggiatoreSlotCorrente,
          ruoloCambiLiberoCorrente: _ruoloCambiLiberoEffettivo,
          sistemaGioco: widget.sistemaGioco,
        ),
      ),
    );
    if (risultato == null || !mounted) return;

    // Difesa in profondità: mai scrivere eventi che metterebbero lo stesso
    // giocatore in due posizioni (dati corrotti, ValueKey duplicate in UI)
    // — id unici sull'unione di sei in campo + liberi.
    final tuttiFinali = [
      ...risultato.seiFinali.values,
      ...risultato.liberiFinali.values,
    ];
    final idsFinali = {for (final p in tuttiFinali) p.id};
    if (idsFinali.length != tuttiFinali.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).scoutSostituzioneNonValida,
          ),
        ),
      );
      return;
    }

    // Diff posizione per posizione: originale ≠ finale → un cambio. Vale
    // anche per L1/L2 (cambio libero-per-libero): ricalcolaStato riconosce
    // dall'esceId che si tratta del libero e aggiorna quello invece della
    // rotazione.
    final cambi = <({int esceId, int entraId})>[];
    for (final slot in _kSlotOrder) {
      final originale = seiCorrenti[slot];
      final finale = risultato.seiFinali[slot];
      if (originale != null && finale != null && originale.id != finale.id) {
        cambi.add((esceId: originale.id, entraId: finale.id));
      }
    }
    for (final key in const ['L1', 'L2']) {
      final originale = liberi[key];
      final finale = risultato.liberiFinali[key];
      if (originale != null && finale != null && originale.id != finale.id) {
        cambi.add((esceId: originale.id, entraId: finale.id));
      }
    }

    // Override di configurazione: solo se diversi dai valori effettivi
    // correnti (null = invariato, la riga evento resta minimale).
    final setterIdCorrente =
        _statoSetReale?.palleggiatoreId ??
        widget.assignments[widget.palleggiatoreSlot]?.id;
    final nuovoPalleggiatore = risultato.seiFinali[risultato.palleggiatoreSlot];
    final overridePalleggiatore =
        (nuovoPalleggiatore != null &&
            nuovoPalleggiatore.id != setterIdCorrente)
        ? nuovoPalleggiatore.id
        : null;
    final ruoloCambiCorrente = _ruoloCambiLiberoEffettivo;
    final overrideRuoloCambi = risultato.ruoloCambiLibero != ruoloCambiCorrente
        ? risultato.ruoloCambiLibero
        : null;

    if (cambi.isEmpty &&
        overridePalleggiatore == null &&
        overrideRuoloCambi == null) {
      return; // niente da registrare
    }

    final repo = ref.read(scoutActionRepositoryProvider);
    // Tutte le righe di questo blocco condividono lo stesso gruppoCambio:
    // l'undo le elimina insieme (annullare solo metà di un doppio cambio
    // non ha senso pallavolistico). Un timestamp è unico a sufficienza tra
    // blocchi diversi dello stesso set.
    final gruppoCambio = DateTime.now().millisecondsSinceEpoch;
    if (cambi.isEmpty) {
      // Solo riconfigurazione (nessun cambio di giocatori): una riga
      // no-op con esceId == entraId che porta solo gli override —
      // ricalcolaStato la rigioca senza toccare la rotazione.
      final ancoraId = nuovoPalleggiatore?.id ?? seiCorrenti['P1']!.id;
      await repo.registraSostituzione(
        setId: set.id,
        entraId: ancoraId,
        esceId: ancoraId,
        nuovoPalleggiatoreId: overridePalleggiatore,
        nuovoRuoloCambiLibero: overrideRuoloCambi,
        gruppoCambio: gruppoCambio,
      );
    } else {
      for (var i = 0; i < cambi.length; i++) {
        final ultimo = i == cambi.length - 1;
        await repo.registraSostituzione(
          setId: set.id,
          entraId: cambi[i].entraId,
          esceId: cambi[i].esceId,
          // Gli override viaggiano sull'ULTIMA riga: applicati quando
          // tutti i cambi del blocco sono già in campo.
          nuovoPalleggiatoreId: ultimo ? overridePalleggiatore : null,
          nuovoRuoloCambiLibero: ultimo ? overrideRuoloCambi : null,
          gruppoCambio: gruppoCambio,
        );
      }
    }
    if (!mounted) return;
    // Palla morta: un eventuale pannello voto aperto non ha più senso.
    // _fondamentaleGiudicatoRallyCorrente NON si tocca: il cambio non
    // chiude lo scambio (si può sostituire tra un punto e l'altro senza
    // alterare la fase di gioco).
    setState(() {
      _votoInCorso = null;
      _azzeraTraiettoriaInLine();
    });
  }

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // --- Tutorial (vedi widget.tutorial e lib/tutorial/) ------------------
  //
  // Marca un elemento come "evidenziabile": ne registra la GlobalKey (così
  // l'overlay sa dove bucare il velo) e ne segnala i tocchi. Fuori dal
  // tutorial ritorna il figlio invariato — zero costo e zero effetti.
  //
  // Il `Listener` è un ANTENATO del GestureDetector reale: intercetta il
  // tocco senza sottrarlo all'arena dei gesti, quindi il bottone sottostante
  // continua a funzionare esattamente come prima.
  //
  // Non usarlo mai attorno a un Positioned/AnimatedPositioned (KeyedSubtree
  // spezzerebbe il posizionamento nello Stack): ancorare il figlio.
  Widget _anchor(TutorialTarget target, Widget child) {
    if (!widget.tutorial) return child;
    final controller = ref.read(tutorialControllerProvider.notifier);
    return KeyedSubtree(
      key: controller.registro.keyFor(target),
      child: Listener(
        onPointerUp: (_) => controller.tapSuTarget(target),
        child: child,
      ),
    );
  }

  // Variante condizionale, per i builder chiamati sia per la nostra squadra
  // sia per l'avversaria (punteggio, timeout): solo uno dei due è il target.
  Widget _anchorSe(bool condizione, TutorialTarget target, Widget child) =>
      condizione ? _anchor(target, child) : child;

  // Variante per i builder che ciclano su un enum (voti, fondamentali): il
  // target arriva già risolto da una delle funzioni targetXxx(), che torna
  // null per i valori senza un bottone corrispondente.
  Widget _anchorOpz(TutorialTarget? target, Widget child) =>
      target == null ? child : _anchor(target, child);

  // actionId → "Rotazione P{iniziale} → P{finale}" per ogni correzione
  // rotazione del set, ricalcolata a ogni build (vedi _computeLabelsCorrezione)
  // e letta da _descrizioneAzione per banner e log azioni — così ogni voce
  // mostra la rotazione al SUO momento, non quella attuale.
  Map<int, String> _labelsCorrezione = const {};

  @override
  Widget build(BuildContext context) {
    _labelsCorrezione = _computeLabelsCorrezione();
    _rilevaCambioPunteggio();
    final scaffold = Scaffold(
      key: _scaffoldKey,
      backgroundColor: _kBg,
      // Unico segnale che il tutorial non riesce a dedurre da solo: il drawer
      // non ha un widget "ancorabile" finché non è aperto.
      onDrawerChanged: widget.tutorial
          ? (aperto) => ref.read(tutorialControllerProvider.notifier).segnale(
                aperto
                    ? SegnaleTutorial.drawerAperto
                    : SegnaleTutorial.drawerChiuso,
              )
          : null,
      drawer: _buildUtilityDrawer(),
      floatingActionButton: _testModeEnabled
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF00008A),
              onPressed: _testAvanza,
              icon: const Icon(Icons.skip_next),
              label: Text(
                '$_currentSlot '
                '${_testServizio == Squadra.nostra ? "battuta" : "ricezione"}'
                '${_testDopo ? " (dopo)" : ""}',
              ),
            )
          : null,
      body: Column(
        children: [
          Container(
            height: 80,
            color: _kTopBarBg,
            child: LayoutBuilder(
              builder: (context, headerConstraints) {
                const scoreControlWidth = 116.0;
                final leftScoreLeft =
                    headerConstraints.maxWidth * 0.30 - scoreControlWidth / 2;
                // Offset dei pallini timeout dal bordo: 237 (allineati col
                // bottone timeout della riga sotto, posizione fissa) quando
                // c'è spazio, ma su schermi stretti (smartphone) quella X
                // finirebbe SOPRA il gruppo punteggio al 30%/70% — in quel
                // caso si spostano appena all'esterno del gruppo (verso il
                // bordo), mai sotto le icone menu/undo (minimo 60).
                final timeoutDotsOffset = math.max(
                  60.0,
                  math.min(237.0, leftScoreLeft - 34 - 8),
                );
                final rightScoreLeft =
                    headerConstraints.maxWidth * 0.70 - scoreControlWidth / 2;
                return Stack(
                  children: [
                    // Margini simmetrici da 104 = due icone (48+48) più aria:
                    // a destra ci sono "annulla scambio" + undo, a sinistra
                    // solo il menu. Simmetrici e non 56/104 per non spostare
                    // il centro del titolo, che è centrato: su telefono costa
                    // un po' di larghezza (va in ellissi prima), ma il titolo
                    // resta dov'è invece di apparire storto.
                    Positioned(
                      left: 104,
                      right: 104,
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
                    // Center: il contenuto (−/numero/+, ~76px) è più stretto
                    // del riquadro da 116 — senza, la Row resta allineata a
                    // sinistra in entrambi i riquadri e i due punteggi
                    // risultano asimmetrici rispetto al titolo centrato.
                    Positioned(
                      left: leftScoreLeft,
                      width: scoreControlWidth,
                      bottom: 4,
                      child: Center(
                        child: _isRightSide
                            ? _buildScoreDisplay(
                                _punteggioAvversario,
                                Squadra.avversari,
                              )
                            : _buildScoreDisplay(
                                _punteggioNostro,
                                Squadra.nostra,
                              ),
                      ),
                    ),
                    Positioned(
                      left: rightScoreLeft,
                      width: scoreControlWidth,
                      bottom: 4,
                      child: Center(
                        child: _isRightSide
                            ? _buildScoreDisplay(
                                _punteggioNostro,
                                Squadra.nostra,
                              )
                            : _buildScoreDisplay(
                                _punteggioAvversario,
                                Squadra.avversari,
                              ),
                      ),
                    ),
                    // Pallini timeout: nell'header, alla stessa X del
                    // bottone timeout nella riga sottostante — centro
                    // bottone a 254px dal bordo (padding 24 + 44+8+44 +
                    // gap 112 + 22), riga pallini larga 34 → offset 237,
                    // clampato su schermi stretti (vedi timeoutDotsOffset).
                    // Il lato segue i gruppi punto/errore (_isRightSide).
                    Positioned(
                      left: timeoutDotsOffset,
                      bottom: 8,
                      child: _buildTimeoutDots(
                        _isRightSide ? Squadra.avversari : Squadra.nostra,
                      ),
                    ),
                    Positioned(
                      right: timeoutDotsOffset,
                      bottom: 8,
                      child: _buildTimeoutDots(
                        _isRightSide ? Squadra.nostra : Squadra.avversari,
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _anchor(
                            TutorialTarget.bottoneMenu,
                            IconButton(
                              icon: const Icon(Icons.menu, color: Colors.white),
                              onPressed: () =>
                                  _scaffoldKey.currentState?.openDrawer(),
                            ),
                          ),
                          const Spacer(),
                          // "Si rigioca l'azione": cancella l'intero scambio.
                          // Sta PRIMA dell'undo singolo, che resta all'estremo
                          // destro dove il dito lo cerca già.
                          // Il colore va su IconButton, NON sull'Icon: un
                          // `Icon(color: ...)` esplicito vince su quello che
                          // il bottone applica da disabilitato, e l'icona
                          // resterebbe bianca anche spenta.
                          IconButton(
                            // Icona disegnata a mano: ImageIcon la ricolora
                            // usando SOLO l'alpha della sagoma, quindi segue
                            // color/disabledColor come le icone Material.
                            icon: const ImageIcon(
                              AssetImage('assets/ui_icons/annulla_scambio.png'),
                            ),
                            color: Colors.white,
                            disabledColor: Colors.white38,
                            tooltip: AppLocalizations.of(
                              context,
                            ).scoutUndoRallyTooltip,
                            onPressed: _puoAnnullareRally
                                ? _confermaAnnullaRally
                                : null,
                          ),
                          _anchor(
                            TutorialTarget.bottoneUndo,
                            IconButton(
                              icon: const Icon(Icons.undo),
                              color: Colors.white,
                              disabledColor: Colors.white38,
                              onPressed: _puoAnnullare
                                  ? _confermaAnnullaUltimaAzione
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              // Banner ultima azione al centro, tra i due gruppi (i timeout
              // sono sui lati interni): non ha più una riga propria sotto.
              children: _isRightSide
                  ? [
                      _gruppoRapido(_buildBottoniAvversario()),
                      _bannerCentrale(),
                      _gruppoRapido(_buildBottoniNostri()),
                    ]
                  : [
                      _gruppoRapido(_buildBottoniNostri()),
                      _bannerCentrale(),
                      _gruppoRapido(_buildBottoniAvversario()),
                    ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Margine sinistro/destro del 21% dello schermo: il campo
                // occupa il restante 58% della larghezza, centrato — MA mai
                // più alto dello spazio disponibile (su smartphone lo
                // schermo è basso e il 58% della larghezza sborderebbe in
                // verticale): l'altezza del campo è courtWidth/2, quindi si
                // clampa la larghezza a (altezza utile)×2. Su tablet vince
                // sempre il 58% e non cambia nulla. Sicuro per costruzione:
                // token e overlay esterni (libero/battitore) ricevono tutti
                // QUESTO courtWidth e le coordinate sono proporzionali.
                final courtWidth = math.min(
                  constraints.maxWidth * 0.58,
                  (constraints.maxHeight - _kCourtTopMargin - 8) * 2,
                );
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
                // Geometria del riquadro campo in coordinate di QUESTO Stack:
                // la stessa formula di centratura usata da _buildLiberoSwapTokens
                // e dai tap-catcher, qui serve a normalizzare la traiettoria
                // disegnata a mano libera.
                final courtHeight = courtWidth / 2;
                final courtLeft = (constraints.maxWidth - courtWidth) / 2;
                const courtTop = _kCourtTopMargin;
                // `Listener` ANTENATO dello Stack: riceve ogni evento che
                // colpisce qualunque cosa lì dentro, a prescindere da chi lo
                // assorbe, e — non partecipando all'arena dei gesti — non
                // sottrae un solo tocco ai bottoni e ai token. È lo stesso
                // motivo per cui _anchor usa un Listener per il tutorial.
                // Serve perché un GestureDetector con onPan* qui sopra
                // ruberebbe i tap, e sotto non riceverebbe i trascinamenti che
                // partono fuori dal campo (il battitore ha X negativa).
                return Listener(
                  // `translucent` e non il default `deferToChild`: senza, questo
                  // Listener entrerebbe nel percorso del tocco solo se un suo
                  // discendente viene colpito, e nella fascia VUOTA fuori dal
                  // campo non c'è niente da colpire (lo scrim lì è spento
                  // finché non si apre un pannello). Con translucent si
                  // aggiunge sempre al percorso e i figli restano colpibili
                  // come prima — e non partecipando all'arena dei gesti non
                  // sottrae comunque un tocco a nessuno.
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: _onPointerDownCampo,
                  onPointerMove: (e) =>
                      _onPointerMoveCampo(e, courtLeft, courtWidth),
                  onPointerUp: (_) => _onPointerUpCampo(
                      courtLeft, courtTop, courtWidth, courtHeight),
                  onPointerCancel: (_) {
                    _pointerGiu = null;
                    _gestoSullaCard = false;
                    _aperturaDaTrascinamento = null;
                    _timerMuroInLine?.cancel();
                    _inZonaReteInLine = false;
                  },
                  child: Stack(
                  children: [
                    // Primo figlio = ultimo a ricevere il tocco: vedi
                    // _buildScrimPannelli per il perché sta quaggiù, e perché
                    // c'è sempre invece di comparire e sparire.
                    _buildScrimPannelli(),
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
                                final cw = courtConstraints.maxWidth;
                                final ch = courtConstraints.maxHeight;
                                return Stack(
                                  // Il battitore in P1 esce dal campo (X
                                  // negativa, vedi _kBattutaP1Position): senza
                                  // Clip.none lo Stack lo taglierebbe via
                                  // (default Clip.hardEdge) invece di
                                  // disegnarlo comunque sopra.
                                  clipBehavior: Clip.none,
                                  children: [
                                    // L'immagine del campo INTERCETTA il
                                    // tocco, quindi non lo lascia scendere
                                    // fino allo scrim (vedi
                                    // _buildScrimPannelli): il chiuditore va
                                    // messo qui sopra. Sta come primo figlio,
                                    // cioè sotto ai token: fra i due gesti
                                    // vince quello del token, che viene
                                    // colpito per primo — così toccare una
                                    // giocatrice la sostituisce e toccare il
                                    // campo vuoto annulla.
                                    GestureDetector(
                                      behavior: _pannelloAperto
                                          ? HitTestBehavior.opaque
                                          : HitTestBehavior.deferToChild,
                                      onTap:
                                          _pannelloAperto ? _chiudiPannelli : null,
                                      child: Image.asset(
                                        _kCourtImage,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                    ..._buildCourtTokens(cw, ch),
                                    ..._buildTokenAvversari(cw, ch),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: constraints.maxHeight * 0.05,
                      left: minimapLeft,
                      width: smallCourtSize,
                      height: smallCourtSize,
                      // Col pannello aperto il tocco deve cadere sullo scrim
                      // (che chiude), non alternare la mini-map: lo scrim ora
                      // sta SOTTO, vedi _buildScrimPannelli.
                      child: IgnorePointer(
                        ignoring: _pannelloAperto,
                        child: _anchor(
                        TutorialTarget.minimappa,
                          GestureDetector(
                          // Tap sulla finestra: alterna rotazione nostra/
                          // avversaria (solo con scout avversario attivo).
                          behavior: HitTestBehavior.opaque,
                          onTap: _scoutAvversariAttivo
                              ? () => setState(
                                  () => _minimapAvversari = !_minimapAvversari)
                              : null,
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
                                    angle: _minimapSpecchiata ? math.pi : 0,
                                    child: Image.asset(
                                      _kSmallCourtImage,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  _buildRotationBadge(smallCourtSize),
                                ],
                              ),
                            ),
                          ),
                        ),
                        ),
                      ),
                    ),
                    // Bottoni di rotazione manuale: utili solo in modalità
                    // test (la rotazione reale segue gli eventi via
                    // _statoSetReale, non più un contatore manuale).
                    if (_testModeEnabled)
                      Positioned(
                        top: constraints.maxHeight * 0.05 + smallCourtSize + 8,
                        left: minimapLeft,
                        width: smallCourtSize,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildRotationButton(
                              Icons.rotate_right,
                              _rotateBackward,
                              smallCourtSize,
                            ),
                            _buildRotationButton(
                              Icons.rotate_left,
                              _rotateForward,
                              smallCourtSize,
                            ),
                          ],
                        ),
                      ),
                    // Correzione manuale della rotazione (gioco reale): due
                    // bottoni con label = rotazione di ARRIVO (avanti a
                    // sinistra, es. P1→P6; indietro a destra, P1→P2). Agiscono
                    // sulla squadra SELEZIONATA nella mini-map: la nostra
                    // (evento loggato, undo standard) o l'avversaria (edita lo
                    // slot iniziale, retroattivo — vedi _correggiRotazioneAvversario).
                    if (_bottoniRapidiAttivi)
                      Positioned(
                        top: constraints.maxHeight * 0.05 + smallCourtSize + 8,
                        left: minimapLeft,
                          width: smallCourtSize,
                          // Col pannello aperto questi bottoni devono lasciar
                          // passare il tocco allo scrim sottostante: correggere
                          // la rotazione per sbaglio scriverebbe un evento.
                          child: IgnorePointer(
                            ignoring: _pannelloAperto,
                            child: _anchor(
                            TutorialTarget.bottoniCorrezioneRotazione,
                            Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: _minimapAvversari && _scoutAvversariAttivo
                                ? [
                                    _buildRotationCorrectionButton(
                                      'P${_slotDestinazioneCorrezioneAvversario(DirezioneRotazione.avanti)}',
                                      () => _correggiRotazioneAvversario(
                                          DirezioneRotazione.avanti),
                                      smallCourtSize,
                                    ),
                                    _buildRotationCorrectionButton(
                                      'P${_slotDestinazioneCorrezioneAvversario(DirezioneRotazione.indietro)}',
                                      () => _correggiRotazioneAvversario(
                                          DirezioneRotazione.indietro),
                                      smallCourtSize,
                                    ),
                                  ]
                                : [
                                    _buildRotationCorrectionButton(
                                      'P${_slotDestinazioneCorrezione(DirezioneRotazione.avanti)}',
                                      () => _correggiRotazione(
                                          DirezioneRotazione.avanti),
                                      smallCourtSize,
                                    ),
                                    _buildRotationCorrectionButton(
                                      'P${_slotDestinazioneCorrezione(DirezioneRotazione.indietro)}',
                                      () => _correggiRotazione(
                                          DirezioneRotazione.indietro),
                                      smallCourtSize,
                                    ),
                                  ],
                          ),
                        ),
                        ),
                      ),
                    ..._buildLiberoSwapTokens(constraints, courtWidth),
                    ..._buildBattitoreTapCatcher(constraints, courtWidth),
                    ..._buildBattitoreAvversarioTapCatcher(
                        constraints, courtWidth),
                    ..._buildSelezionePAvversario(constraints, courtWidth),
                    ..._buildActionLog(),
                    // Freccia della traiettoria in-line: sopra al campo e ai
                    // token, sotto ai pannelli. IgnorePointer perché è puro
                    // disegno e non deve mai intercettare un tocco.
                    _buildFrecciaInLine(
                        courtLeft, courtTop, courtWidth, courtHeight),
                    ..._buildPannelloVoto(),
                    ..._buildPannelloAvversario(),
                  ],
                ),
                );
              },
            ),
          ),
        ],
      ),
    );
    if (!widget.tutorial) return scaffold;
    // Overlay FRATELLO dello Scaffold, non dentro il body: così copre anche il
    // drawer aperto, e sparisce da solo quando si naviga a una schermata
    // figlia (traiettoria, fine set) senza doverne gestire il ciclo di vita.
    return Stack(
      fit: StackFit.expand,
      children: [scaffold, TutorialOverlay(setId: _setCorrente?.id)],
    );
  }

  // Pannello laterale per i bottoni "di utilità" usati raramente (es.
  // cambio campo), per non affollare l'area sopra il campo grande.
  // Gate premium (vedi docs/TODO_strada_A.md): true = utente free, apre il
  // paywall e il chiamante NON deve procedere — stesso pattern di
  // MatchesScreen._richiedePremium.
  bool _richiedePremium() {
    if (ref.read(statoPremiumProvider).attivo) return false;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PaywallScreen()),
    );
    return true;
  }

  Widget _buildUtilityDrawer() {
    final l = AppLocalizations.of(context);
    return _anchor(
      TutorialTarget.drawer,
        Drawer(
        backgroundColor: _kBg,
        child: SafeArea(
          // ListView, non Column: su smartphone (schermo basso) le voci non
          // ci stanno tutte in altezza e la Column sborderebbe — così il
          // drawer scrolla. Su tablet non cambia nulla.
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  l.scoutDrawerTitolo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              _anchor(
                TutorialTarget.voceCambiaCampo,
                ListTile(
                  leading: const Icon(Icons.swap_horiz, color: Colors.white),
                  title: Text(
                    l.scoutCambiaCampo,
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    _toggleSide();
                    _scaffoldKey.currentState?.closeDrawer();
                  },
                ),
              ),
              // Sostituzione (cambio giocatore) — stessa condizione dei
              // bottoni rapidi: set iniziato e fuori dalla modalità test (il
              // cambio scrive un evento reale).
              ListTile(
                enabled: _bottoniRapidiAttivi,
                leading: Icon(
                  Icons.swap_vert,
                  color: _bottoniRapidiAttivi ? Colors.white : Colors.white38,
                ),
                title: Text(
                  l.scoutSostituzione,
                  style: TextStyle(
                    color: _bottoniRapidiAttivi ? Colors.white : Colors.white38,
                  ),
                ),
                onTap: () {
                  _scaffoldKey.currentState?.closeDrawer();
                  _avviaSostituzione();
                },
              ),
              // Lavagna tattica (premium): campo per disporre le chip dei ruoli
              // e disegnare durante il timeout — vedi TacticalBoardScreen.
              ListTile(
                leading: const Icon(Icons.dashboard, color: Colors.white),
                title: Text(
                  l.scoutLavagnaTattica,
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: const PremiumBadge(),
                onTap: () {
                  _scaffoldKey.currentState?.closeDrawer();
                  if (_richiedePremium()) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TacticalBoardScreen(team: widget.team),
                    ),
                  );
                },
              ),
              const Divider(color: Colors.white24, height: 1),
              ListTile(
                leading: const Icon(Icons.bar_chart, color: Colors.white),
                title: Text(
                  l.scoutStatisticheFondamentali,
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  _scaffoldKey.currentState?.closeDrawer();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlayerStatsScreen(
                        match: widget.match,
                        team: widget.team,
                      ),
                    ),
                  );
                },
              ),
              // Report completo della partita (la stessa pagina del bottone
              // "Report" di MatchesScreen): consultabile anche a partita in
              // corso — i dati si ricaricano ad ogni apertura, come per le
              // statistiche.
              ListTile(
                leading: const Icon(Icons.description, color: Colors.white),
                title: Text(
                  l.partiteReport,
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  _scaffoldKey.currentState?.closeDrawer();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MatchReportScreen(match: widget.match),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.arrow_forward, color: Colors.white),
                title: Text(
                  l.scoutTraiettorieBattute,
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: const PremiumBadge(),
                onTap: () {
                  _scaffoldKey.currentState?.closeDrawer();
                  if (_richiedePremium()) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TrajectoryReportScreen(
                        match: widget.match,
                        team: widget.team,
                        fondamentale: Fondamentale.battuta,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.trending_up, color: Colors.white),
                title: Text(
                  l.scoutTraiettorieAttacco,
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: const PremiumBadge(),
                onTap: () {
                  _scaffoldKey.currentState?.closeDrawer();
                  if (_richiedePremium()) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TrajectoryReportScreen(
                        match: widget.match,
                        team: widget.team,
                        fondamentale: Fondamentale.attacco,
                      ),
                    ),
                  );
                },
              ),
              const Divider(color: Colors.white24, height: 1),
              SwitchListTile(
                value: _showJerseyNumbers,
                onChanged: (v) => setState(() => _showJerseyNumbers = v),
                title: Text(
                  _showJerseyNumbers ? l.scoutMostraRuoli : l.scoutMostraNumeri,
                  style: const TextStyle(color: Colors.white),
                ),
                activeThumbColor: Colors.white,
                activeTrackColor: const Color(0xFF00008A),
                inactiveThumbColor: Colors.white70,
                inactiveTrackColor: Colors.white24,
              ),
              // Strumento di sviluppo per visualizzare a video tutte le
              // combinazioni rotazione × fase: in debug sempre, in release solo
              // negli APK "per tester" (--dart-define=PREMIUM_OVERRIDE=true),
              // come il toggle "Simula premium". Nascosto in produzione.
              if (overridePremiumDisponibile)
                SwitchListTile(
                  value: _testModeEnabled,
                  onChanged: _toggleTestMode,
                  title: Text(
                    l.scoutModalitaTest,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    l.scoutModalitaTestSottotitolo,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  activeThumbColor: Colors.white,
                  activeTrackColor: const Color(0xFF00008A),
                  inactiveThumbColor: Colors.white70,
                  inactiveTrackColor: Colors.white24,
                ),
              SwitchListTile(
                value: _showActionLog,
                onChanged: (v) => setState(() => _showActionLog = v),
                title: Text(
                  l.scoutLogAzioni,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  l.scoutLogAzioniSottotitolo,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                activeThumbColor: Colors.white,
                activeTrackColor: const Color(0xFF00008A),
                inactiveThumbColor: Colors.white70,
                inactiveTrackColor: Colors.white24,
              ),
              const Divider(color: Colors.white24, height: 1),
              ListTile(
                leading: const Icon(Icons.sports_score, color: Colors.white),
                title: Text(
                  l.scoutFine,
                  style: const TextStyle(color: Colors.white),
                ),
                // A differenza di "Indietro" qui si fa un push, non un pop:
                // niente local history entry da gestire, basta chiudere il
                // drawer per pulizia visiva prima di navigare.
                onTap: () {
                  _scaffoldKey.currentState?.closeDrawer();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          EndSetScreen(match: widget.match, team: widget.team),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.arrow_back, color: Colors.white),
                title: Text(
                  l.scoutIndietro,
                  style: const TextStyle(color: Colors.white),
                ),
                // Il Drawer registra una "local history entry" sulla route:
                // mentre è aperto, Navigator.pop(context) chiude SOLO il
                // drawer (consuma quella entry) invece di tornare alla
                // schermata precedente. Si cattura il Navigator prima di
                // chiudere il drawer esplicitamente, poi si naviga davvero
                // sul Navigator catturato.
                //
                // Destinazione: se il set ha già almeno un'azione registrata
                // (partita "cominciata"), si torna direttamente alla lista
                // partite (route '/matches', vedi HomeScreen) — non ha senso
                // ripassare da configurazione/formazione, che rifarebbero il
                // setup; `popUntil` per nome regge qualsiasi profondità di
                // stack (flusso normale vs. "Riprendi" che bypassa lineup/
                // config). Se invece non è ancora stata presa nessuna azione,
                // si torna com'era alla schermata precedente (configurazione).
                onTap: () {
                  final navigator = Navigator.of(context);
                  final set = _setCorrente;
                  final haAzioni = set != null &&
                      (ref
                              .read(scoutAzioniStreamProvider(set.id))
                              .value
                              ?.isNotEmpty ??
                          false);
                  _scaffoldKey.currentState?.closeDrawer();
                  if (haAzioni) {
                    navigator
                        .popUntil((route) => route.settings.name == '/matches');
                  } else {
                    navigator.pop();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // La mini-map è specchiata (180°) col cambio campo E quando mostra la
  // rotazione avversaria (la loro metà è il mirror della nostra): i due
  // effetti si compongono (XOR).
  bool get _minimapSpecchiata =>
      _isRightSide != (_minimapAvversari && _scoutAvversariAttivo);

  Widget _buildRotationBadge(double courtSize) {
    // Squadra selezionata sulla mini-map: badge col suo slot e col suo colore
    // (nostro colore squadra o grigio avversario) — è il colore a dire di chi
    // è la rotazione mostrata.
    final avversari = _minimapAvversari && _scoutAvversariAttivo;
    final slot = avversari ? (_currentSlotAvversario ?? _currentSlot) : _currentSlot;
    final colore =
        avversari ? _kColoreTokenAvversario : Color(widget.team.coloreDivisa);
    final baseAnchor = _kRotationBadgeAnchor[slot] ?? Alignment.bottomLeft;
    // L'ancoraggio del badge segue la stessa rotazione 180° della mini-map
    // (negare entrambe le componenti), mentre il testo resta dritto e leggibile.
    final anchor = _minimapSpecchiata
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
            color: colore,
            borderRadius: BorderRadius.circular(badgeHeight * 0.1),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Text(
            slot,
            style: TextStyle(
              color: contrastingTextColor(colore),
              fontWeight: FontWeight.bold,
              fontSize: badgeHeight * 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Player? _playerPerId(int? id) {
    if (id == null) return null;
    // _rosterById (non widget.assignments): un subentrato da cambio
    // giocatore parte dalla panchina, non è nella formazione iniziale.
    return _rosterById[id];
  }

  // Pannello di debug col log delle azioni del SET CORRENTE (vedi
  // _showActionLog): una riga per ScoutAction — "ordine·rally  descrizione
  // voto" (stesso testo/colori di _descrizioneAzione) — più recente in
  // alto. Vive nello Stack esterno, ancorato al bordo destro; nascosto
  // quando il pannello voto è aperto (stessa zona).
  List<Widget> _buildActionLog() {
    // Il log sta sul lato OPPOSTO alla mini-map: a destra col nostro campo a
    // sinistra (_isRightSide == false), a sinistra col cambio campo. Va
    // nascosto:
    // - SEMPRE durante la battuta avversaria: il loro battitore esce dal campo
    //   proprio sul lato del log (qualunque orientamento) e ci finirebbe sotto;
    //   riappare da solo appena la battuta è registrata (fase → ricezione),
    //   con o senza traiettoria;
    // - all'apertura di un pannello voto (nostro o avversario) SOLO quando il
    //   log è a destra: i pannelli sono ancorati a destra, quindi col log a
    //   sinistra non lo coprono e può restare visibile.
    final pannelloVotoAperto =
        _votoInCorso != null || _avversarioInCorso != null;
    final logADestra = !_isRightSide;
    if (!_showActionLog ||
        _attesaBattutaAvversaria ||
        (pannelloVotoAperto && logADestra)) {
      return const [];
    }
    final set = _setCorrente;
    if (set == null) return const [];
    final righe =
        ref.watch(scoutAzioniStreamProvider(set.id)).value ??
        const <ScoutAction>[];
    // Punteggio parziale dopo ogni azione che chiude un rally (esito non
    // "nessuno"): replay leggero dei soli esiti, in ordine. Non include le
    // correzioni manuali del punteggio (vivono su MatchSet, non nel log).
    final parziali = <int, String>{}; // ScoutAction.id -> "n–a"
    var nostro = 0, avversario = 0;
    for (final r in righe) {
      switch (r.esitoPunto) {
        case EsitoPunto.puntoNostro:
          nostro++;
        case EsitoPunto.puntoAvversario:
          avversario++;
        case EsitoPunto.nessuno:
          continue;
      }
      parziali[r.id] = '$nostro–$avversario';
    }
    // Numero di scambio progressivo (r1, r2, r3...) per la sola
    // visualizzazione: a DB rallyId è l'`ordine` della prima azione dello
    // scambio (r1, r3, r6... — semantica comoda per le query ma poco
    // leggibile qui).
    final numeroRally = <int, int>{}; // rallyId -> progressivo 1-based
    for (final r in righe) {
      numeroRally.putIfAbsent(r.rallyId, () => numeroRally.length + 1);
    }
    // Pannello log scalato con l'altezza schermo: su smartphone (~360dp)
    // largo/testi ridotti, su tablet (>=760dp) i valori pieni di prima.
    final h = MediaQuery.of(context).size.height;
    final t = ((h - 360) / 400).clamp(0.0, 1.0);
    double sc(double telefono, double tablet) =>
        telefono + (tablet - telefono) * t;
    return [
      Positioned(
        top: 8,
        bottom: 8,
        // Lato OPPOSTO alla mini-map (che segue _isRightSide): default a
        // destra, ma col cambio campo la mini-map va a destra e il log si
        // sposta a sinistra per non finirci sopra.
        left: _isRightSide ? 8 : null,
        right: _isRightSide ? null : 8,
        width: sc(160, 240),
        child: _anchor(
            TutorialTarget.logAzioni,
            Container(
            padding: EdgeInsets.all(sc(5, 8)),
            decoration: BoxDecoration(
              color: _kTopBarBg.withAlpha(235),
              borderRadius: BorderRadius.circular(sc(6, 8)),
              border: Border.all(color: Colors.white24),
            ),
            child: righe.isEmpty
                ? Center(
                    child: Text(
                      AppLocalizations.of(context).scoutNessunaAzione,
                      style:
                          TextStyle(color: Colors.white54, fontSize: sc(10, 12)),
                    ),
                  )
                : ListView.builder(
                    itemCount: righe.length,
                    itemBuilder: (context, i) {
                      final a = righe[righe.length - 1 - i]; // recente in alto
                      // Riga SOTTO nel pannello = azione PRECEDENTE nel tempo
                      // (la lista è rovesciata). Se appartiene a un altro
                      // scambio, `a` è la prima azione del suo rally: ci si
                      // disegna sotto una linea, così ogni gruppo di righe
                      // resta visivamente uno scambio. Nessun separatore in
                      // fondo alla lista (sotto non c'è nulla da separare).
                      final precedente = i + 1 < righe.length
                          ? righe[righe.length - 2 - i]
                          : null;
                      final fineScambio =
                          precedente != null && precedente.rallyId != a.rallyId;
                      final desc = _descrizioneAzione(a);
                      // Il blu brand del "Cambio" è illeggibile sul fondo
                      // scuro del pannello: solo qui si schiarisce.
                      final coloreTesto = desc.colore == AppColors.brandPrimary
                          ? Colors.lightBlueAccent
                          : desc.colore;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text:
                                        '${a.ordine}·r${numeroRally[a.rallyId]}  ',
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: sc(10, 13),
                                    ),
                                  ),
                                  TextSpan(
                                    text: desc.testo,
                                    style: TextStyle(
                                      // Per punto/errore/cambio (voto assente)
                                      // il colore semantico va sul testo; per i
                                      // voti resta sul solo simbolo, più
                                      // leggibile.
                                      color: desc.voto == null
                                          ? coloreTesto
                                          : Colors.white,
                                      fontSize: sc(11, 14),
                                    ),
                                  ),
                                  if (desc.voto != null)
                                    TextSpan(
                                      text: '  ${desc.voto}',
                                      style: TextStyle(
                                        color: coloreTesto,
                                        fontSize: sc(12, 16),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  if (parziali[a.id] != null)
                                    TextSpan(
                                      text: '  ${parziali[a.id]}',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: sc(11, 14),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (fineScambio)
                            Divider(
                              height: sc(7, 9),
                              thickness: 1,
                              color: Colors.white24,
                            ),
                        ],
                      );
                    },
                  ),
          ),
          ),
      ),
    ];
  }

  // Testo + colore per il banner "ultima azione". Azione di scout (voto su
  // un fondamentale): "Numero - Cognome - Fondamentale | Voto" — separatore
  // finale "|" invece di "-" perché il simbolo del voto può essere lui
  // stesso "-" (negativo): con due trattini di seguito si confondeva con un
  // separatore. Colorato come il voto stesso. Bottoni rapidi (punto/errore,
  // nessun giocatore): solo l'etichetta, verde per i punti (stesso
  // AppColors.success del voto "perfetto" — un punto generico è più vicino
  // a "perfetto" che a "positivo") e rosso per gli errori — stessi colori
  // dei bottoni che li generano (vedi _buildQuickActionButton).
  ({String testo, String? voto, Color colore}) _descrizioneAzione(
    ScoutAction azione,
  ) {
    final player = _playerPerId(azione.giocatoreId);
    final fondamentale = azione.fondamentale;
    final voto = azione.voto;
    if (azione.tipo == TipoAzione.scout &&
        player != null &&
        fondamentale != null &&
        voto != null) {
      return (
        testo: '${player.numero} - ${player.cognome} - ${fondamentaleLabel(fondamentale, AppLocalizations.of(context))}',
        voto: voto.simbolo,
        colore: CourtStyle.votoColor(voto),
      );
    }
    // Azione avversaria (nessun giocatore, solo il ruolo placeholder): es.
    // "Avv S1 - Attacco". Stesso stile/colore voto del nostro scout.
    if (azione.tipo == TipoAzione.scout &&
        azione.ruoloAvversario != null &&
        fondamentale != null &&
        voto != null) {
      return (
        testo: 'Avv ${siglaRuolo(azione.ruoloAvversario!, AppLocalizations.of(context))} - ${fondamentaleLabel(fondamentale, AppLocalizations.of(context))}',
        voto: voto.simbolo,
        colore: CourtStyle.votoColor(voto),
      );
    }
    // Cambio giocatore: giocatoreId = chi entra, giocatoreUscenteId = chi
    // esce. Colore neutro (nessun punto per nessuno). Se un giocatore è
    // stato eliminato dopo il cambio (FK setNull), si mostra "?" — la riga
    // resta comunque leggibile.
    if (azione.tipo == TipoAzione.cambioGiocatore) {
      final esce = _playerPerId(azione.giocatoreUscenteId);
      String etichetta(Player? p) =>
          p == null ? '?' : '${p.numero} ${p.cognome}';
      return (
        testo: 'Cambio: esce ${etichetta(esce)}, entra ${etichetta(player)}',
        voto: null,
        colore: AppColors.brandPrimary,
      );
    }
    // Correzione rotazione: colore neutro come cambio/timeout. Etichetta
    // "Rotazione P{iniziale} → P{finale}" precalcolata per actionId in
    // _computeLabelsCorrezione (rotazione al momento di QUELLA azione, non
    // quella attuale) — così ogni voce del log resta corretta.
    if (azione.tipo == TipoAzione.correzioneRotazione) {
      return (
        testo: _labelsCorrezione[azione.id] ??
            AppLocalizations.of(context).scoutRotazioneCorretta,
        voto: null,
        colore: AppColors.brandPrimary,
      );
    }
    // Timeout: stesso colore neutro del cambio (nessun punto per nessuno),
    // nome squadra come per punto/errore qui sotto.
    if (azione.tipo == TipoAzione.timeout) {
      final squadraLabel = azione.squadra == Squadra.nostra
          ? widget.team.nome
          : 'avversario';
      return (
        testo: 'Timeout $squadraLabel',
        voto: null,
        colore: AppColors.brandPrimary,
      );
    }
    // Per la nostra squadra si usa il nome reale (es. "Punto Nettunia")
    // invece del generico "nostro" — stesso testo sia nel banner ultima
    // azione sia nel dialog di conferma undo (entrambi riusano questa
    // funzione). Per l'avversario resta "avversario": il nome può non
    // essere impostato (vedi _matchTitle), quindi non c'è un equivalente
    // sempre disponibile.
    final squadraLabel = azione.squadra == Squadra.nostra
        ? widget.team.nome
        : 'avversario';
    final isPunto = azione.tipo == TipoAzione.puntoManuale;
    var testo = '${isPunto ? "Punto" : "Errore"} $squadraLabel';
    // Motivo dell'errore (scelto con la pressione prolungata sul bottone
    // "Errore avversario", salvato in tipoEsecuzione — vedi MotivoErrore):
    // aggiunto in coda, es. "Errore avversario - Battuta". `generico` (il
    // tap veloce) non si mostra, non aggiunge informazione.
    if (azione.tipo == TipoAzione.erroreGenerico) {
      final motivo = MotivoErrore.values
          .where((m) => m.name == azione.tipoEsecuzione)
          .firstOrNull;
      if (motivo != null && motivo != MotivoErrore.generico) {
        testo = '$testo - ${motivoErroreLabel(motivo, AppLocalizations.of(context))}';
      }
    }
    return (
      testo: testo,
      voto: null,
      colore: isPunto ? AppColors.success : Colors.red,
    );
  }

  // Banner ultima azione al CENTRO della riga dei bottoni rapidi (nello
  // spazio vuoto tra i due bottoni timeout), invece che in una riga propria
  // sotto — così non occupa altezza dedicata e il campo è più grande.
  // Expanded prende lo spazio centrale; FittedBox(scaleDown) rimpicciolisce
  // il banner se il testo è più largo dello spazio (es. un cambio lungo).
  // Un gruppo di bottoni rapidi (punto/errore + timeout) nella riga sopra al
  // campo. È disegnato a misura fissa — i bottoni e il distacco da 112 del
  // timeout — quindi con poca larghezza i due gruppi insieme sforerebbero:
  // succede in portrait, nel frame in cui la schermata viene costruita prima
  // che il dispositivo abbia finito di ruotare (i due gruppi chiedono 504dp
  // contro i ~363 di un telefono in verticale).
  //
  // Flexible + FittedBox(scaleDown): il gruppo si rimpicciolisce in
  // proporzione solo quando lo spazio manca — tap compresi, il
  // GestureDetector sta dentro la scala. Dove lo spazio c'è la scala è 1 e
  // non cambia nulla, compreso l'allineamento dei pallini timeout
  // nell'header, che assume le misure piene.
  Widget _gruppoRapido(Widget gruppo) => Flexible(
        child: FittedBox(fit: BoxFit.scaleDown, child: gruppo),
      );

  Widget _bannerCentrale() {
    // Priorità al promemoria "CONCLUDI …" quando un `#` attende la difesa
    // errata (Modello A) — è il momento in cui lo scout DEVE ancora agire.
    final concludi = _difesaDaConcludere;
    if (concludi != null) {
      return Expanded(
        child: FittedBox(
            fit: BoxFit.scaleDown, child: _buildBannerConcludi(concludi)),
      );
    }
    final banner = _buildBannerUltimaAzione();
    return Expanded(
      child: banner == null
          ? const SizedBox.shrink()
          : FittedBox(fit: BoxFit.scaleDown, child: banner),
    );
  }

  // Promemoria giallo evidente: dopo un colpo vincente (`#`) il punto non è
  // ancora chiuso (Modello A) — lo scout deve registrare la difesa errata
  // toccando il difensore. Solo promemoria, nessun tap (la conclusione la fa
  // sempre lo scout). Ricezione dopo una battuta, Difesa dopo un attacco.
  Widget _buildBannerConcludi(Fondamentale difesa) {
    final label = difesa == Fondamentale.ricezione
        ? AppLocalizations.of(context).scoutConcludiRicezione
        : AppLocalizations.of(context).scoutConcludiDifesa;
    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: _sc(16, 20), vertical: _sc(6, 8)),
      decoration: BoxDecoration(
        color: _kBordoTokenSelezionato, // giallo, come il bordo del selezionato
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: _sc(14, 16),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget? _buildBannerUltimaAzione() {
    final azione = _ultimaAzione;
    if (azione == null) return null;
    final descrizione = _descrizioneAzione(azione);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: _sc(16, 20), vertical: _sc(6, 8)),
      decoration: BoxDecoration(
        color: descrizione.colore,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            descrizione.testo,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: _sc(13, 15),
              height: 1.0,
            ),
          ),
          if (descrizione.voto != null) ...[
            const SizedBox(width: 10),
            Text(
              descrizione.voto!,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: _sc(20, 22),
                height: 1.0,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Punteggio + bottoni di correzione manuale (+/-) — override diretto del
  // valore mostrato (vedi _correggiPunteggio), non loggato come ScoutAction.
  // Disabilitati con le stesse condizioni dei bottoni rapidi
  // (_bottoniRapidiAttivi); "-" disabilitato anche a punteggio già a 0 (un
  // punteggio reale non scende mai sotto zero).
  // Avvolge il numero del punteggio in un lampeggio (opacità che oscilla tra
  // piena e quasi trasparente) SOLO sul lato appena cambiato; gli altri
  // restano invariati. Vedi _avviaLampeggioPunteggio / _rilevaCambioPunteggio.
  Widget _lampeggiaSe(Squadra squadra, Widget child) {
    if (_squadraLampeggiante != squadra) return child;
    // ON/OFF netto: opacità 1 o 0 (Opacity mantiene lo spazio, il layout non
    // "salta"), nessuna dissolvenza intermedia.
    return Opacity(opacity: _lampeggioAcceso ? 1.0 : 0.0, child: child);
  }

  Widget _buildScoreDisplay(int score, Squadra squadra) {
    final attivo = _bottoniRapidiAttivi;
    // Il tutorial indica il gruppo punteggio NOSTRO: qui, e non nel build,
    // perché quale dei due riquadri sia il nostro dipende da _isRightSide.
    return _anchorSe(
      squadra == Squadra.nostra,
      TutorialTarget.barraPunteggio,
      Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildScoreAdjustButton(
            Icons.remove,
            attivo && score > 0 ? () => _correggiPunteggio(squadra, -1) : null,
          ),
          // Distacco tra bottoni e numero (prima erano attaccati).
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: _lampeggiaSe(
              squadra,
              Text(
                '$score',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildScoreAdjustButton(
            Icons.add,
            attivo ? () => _correggiPunteggio(squadra, 1) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildScoreAdjustButton(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(onTap != null ? 30 : 10),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          color: onTap != null ? Colors.white : Colors.white38,
          size: 20,
        ),
      ),
    );
  }

  // Distanza tra il gruppo punto/errore e il bottone timeout della stessa
  // squadra: spazio in cui starebbero altri due bottoni rapidi (2×44 + gap).
  static const double _kTimeoutGap = 112;

  // Riga "Errore nostro" (rosso, X) + "Punto nostro" (verde, check — stesso
  // colore del voto "perfetto", non blu: un punto generico è semanticamente
  // più vicino a "perfetto" che a "positivo") + bottone timeout staccato
  // sul lato interno (verso il centro dello schermo, segue _isRightSide).
  Widget _buildBottoniNostri() {
    final base = [
      _buildQuickActionButton(
        icon: Icons.close,
        color: Colors.red,
        onTap: _bottoniRapidiAttivi
            ? () => _registraAzioneRapida(
                Squadra.nostra,
                TipoAzione.erroreGenerico,
                EsitoPunto.puntoAvversario,
              )
            : null,
      ),
      const SizedBox(width: 8),
      _anchor(
        TutorialTarget.puntoNostro,
        _buildQuickActionButton(
          icon: Icons.check,
          color: AppColors.success,
          onTap: _bottoniRapidiAttivi
              ? () => _registraAzioneRapida(
                  Squadra.nostra,
                  TipoAzione.puntoManuale,
                  EsitoPunto.puntoNostro,
                )
              : null,
        ),
      ),
    ];
    final timeout = _buildTimeoutButton(Squadra.nostra);
    const gap = SizedBox(width: _kTimeoutGap);
    return _anchor(
      TutorialTarget.bottoniRapidiNostri,
      Row(
        mainAxisSize: MainAxisSize.min,
        // Gruppo a sinistra (default): timeout in coda; coi lati invertiti il
        // gruppo va a destra e il timeout passa in testa — resta verso il
        // centro in entrambi i casi.
        children: _isRightSide
            ? [timeout, gap, ...base]
            : [...base, gap, timeout],
      ),
    );
  }

  // Speculare a _buildBottoniNostri: "Punto avversario" (verde, check) +
  // "Errore avversario" (rosso, X) — ordine invertito per simmetria visiva.
  Widget _buildBottoniAvversario() {
    final base = [
      _buildQuickActionButton(
        icon: Icons.check,
        color: AppColors.success,
        onTap: _bottoniRapidiAttivi
            ? () => _registraAzioneRapida(
                Squadra.avversari,
                TipoAzione.puntoManuale,
                EsitoPunto.puntoAvversario,
              )
            : null,
      ),
      const SizedBox(width: 8),
      _buildQuickActionButton(
        icon: Icons.close,
        color: Colors.red,
        onTap: _bottoniRapidiAttivi
            ? () => _registraAzioneRapida(
                Squadra.avversari,
                TipoAzione.erroreGenerico,
                EsitoPunto.puntoNostro,
                tipoEsecuzione: MotivoErrore.generico.name,
              )
            : null,
        // Pressione prolungata: scegli il motivo dell'errore (Battuta/
        // Fallo di posizione/Invasione) invece del default "Generico"
        // del tap singolo — vedi MotivoErrore in enums.dart. Se va bene,
        // si può estendere lo stesso meccanismo ad altri bottoni rapidi.
        onLongPressStart: _bottoniRapidiAttivi
            ? (details) => _scegliMotivoErroreAvversario(details.globalPosition)
            : null,
      ),
    ];
    final timeout = _buildTimeoutButton(Squadra.avversari);
    const gap = SizedBox(width: _kTimeoutGap);
    return Row(
      mainAxisSize: MainAxisSize.min,
      // Gruppo a destra (default): timeout in testa; specchiato con
      // _isRightSide — vedi _buildBottoniNostri.
      children: _isRightSide
          ? [...base, gap, timeout]
          : [timeout, gap, ...base],
    );
  }

  // Timeout già chiamati da una squadra nel set corrente — derivato dallo
  // stesso stream di _statoSetReale contando le righe `TipoAzione.timeout`
  // (nessuno stato locale: undo e ripresa partita tornano coerenti da soli).
  int _timeoutChiamati(Squadra squadra) {
    final set = _setCorrente;
    if (set == null) return 0;
    final righe =
        ref.watch(scoutAzioniStreamProvider(set.id)).value ??
        const <ScoutAction>[];
    return righe
        .where((a) => a.tipo == TipoAzione.timeout && a.squadra == squadra)
        .length;
  }

  // Bottone timeout di una squadra (blu, orologio) — due per set per
  // allenatore nel volley. I due pallini di stato stanno nell'header, in
  // corrispondenza orizzontale di questo bottone (_buildTimeoutDots); al
  // secondo timeout il bottone si disabilita. Nessun dialog di conferma:
  // il timeout è una riga di log come le altre, il banner ultima azione lo
  // mostra e l'undo lo annulla.
  Widget _buildTimeoutButton(Squadra squadra) {
    return _anchorSe(
      squadra == Squadra.nostra,
      TutorialTarget.bottoneTimeoutNostro,
      _buildQuickActionButton(
        icon: Icons.access_time,
        color: AppColors.brandPrimary,
        onTap: _bottoniRapidiAttivi && _timeoutChiamati(squadra) < 2
            ? () => _timeout(squadra)
            : null,
      ),
    );
  }

  // Pallini di stato dei timeout (14×14): grigi da chiamare, gialli
  // chiamati. Mostrati nell'header, allineati in orizzontale col bottone
  // timeout della stessa squadra nella riga sottostante.
  Widget _buildTimeoutDots(Squadra squadra) {
    final chiamati = _timeoutChiamati(squadra);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 2; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              // Grigio Colors.grey (0xFF9E9E9E) scurito del 30%.
              color: i < chiamati ? Colors.yellow : const Color(0xFF6F6F6F),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ],
    );
  }

  // Registra il timeout come evento nel log (esito `nessuno`: no-op per
  // punteggio/rotazione nel replay) — così l'undo esistente lo annulla e i
  // pallini si aggiornano via stream, senza stato locale.
  Future<void> _timeout(Squadra squadra) async {
    final set = _setCorrente;
    if (set == null || _testModeEnabled) return;
    // Riconteggio con ref.read (siamo in un callback, non nel build): il
    // bottone è già disabilitato a 2, questa è solo una guardia in più.
    final righe =
        ref.read(scoutAzioniStreamProvider(set.id)).value ??
        const <ScoutAction>[];
    final chiamati = righe
        .where((a) => a.tipo == TipoAzione.timeout && a.squadra == squadra)
        .length;
    if (chiamati >= 2) return;
    await ref
        .read(scoutActionRepositoryProvider)
        .registraAzioneRapida(
          setId: set.id,
          squadra: squadra,
          tipo: TipoAzione.timeout,
          esitoPunto: EsitoPunto.nessuno,
        );
  }

  Future<void> _scegliMotivoErroreAvversario(Offset posizione) async {
    final scelto = await showMenu<MotivoErrore>(
      context: context,
      position: RelativeRect.fromLTRB(
        posizione.dx,
        posizione.dy,
        posizione.dx,
        posizione.dy,
      ),
      items: [
        for (final motivo in MotivoErrore.values)
          PopupMenuItem(
              value: motivo,
              child: Text(motivoErroreLabel(motivo, AppLocalizations.of(context)))),
      ],
    );
    if (scelto == null) return;
    _registraAzioneRapida(
      Squadra.avversari,
      TipoAzione.erroreGenerico,
      EsitoPunto.puntoNostro,
      tipoEsecuzione: scelto.name,
    );
  }

  // Interpolazione lineare tra valore "telefono" e "tablet" in base
  // all'altezza schermo (smartphone ~360dp → tablet >=760dp): usata per far
  // tornare grandi su tablet gli elementi rimpiccioliti per lo smartphone
  // (bottoni rapidi, banner). Stessa logica del pannello log.
  double _sc(double telefono, double tablet) {
    final t = ((MediaQuery.of(context).size.height - 360) / 400)
        .clamp(0.0, 1.0);
    return telefono + (tablet - telefono) * t;
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
    void Function(LongPressStartDetails)? onLongPressStart,
  }) {
    final abilitato = onTap != null;
    final lato = _sc(36, 44);
    return GestureDetector(
      onTap: onTap,
      onLongPressStart: onLongPressStart,
      child: Container(
        width: lato,
        height: lato,
        decoration: BoxDecoration(
          color: abilitato ? color : color.withAlpha(80),
          borderRadius: BorderRadius.circular(_sc(8, 10)),
          boxShadow: abilitato
              ? [
                  BoxShadow(
                    color: Colors.black.withAlpha(120),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Icon(icon, color: Colors.white, size: _sc(20, 24)),
      ),
    );
  }

  // Le 4 voci della colonna fondamentali, sempre nello stesso ordine e sempre
  // negli stessi slot: sono coordinate fisse su cui si forma la memoria
  // muscolare, non vanno riordinate né sostituite a seconda della fase.
  // Battuta e ricezione non sono qui: quando la fase le impone il fondamentale
  // è già deciso e compare come chip nell'header (vedi _buildPulsantiera).
  static const _kFondamentaliPulsantiera = [
    Fondamentale.attacco,
    Fondamentale.muro,
    Fondamentale.difesa,
    Fondamentale.alzata,
  ];

  // Misure della pulsantiera. Le due colonne hanno righe della STESSA altezza
  // così i fondamentali si allineano ai primi 4 voti e la griglia si legge a
  // colpo d'occhio (il 5° voto resta da solo in fondo).
  static const double _kAltezzaRigaPulsantiera = 64;
  static const double _kGapPulsantiera = 8;
  // Colonne strette per un motivo preciso: col CAMBIO CAMPO il battitore esce
  // dal campo sul lato destro (X oltre la linea di fondo, vedi
  // _kBattutaP1Position specchiata) e finisce proprio dove sta la card — e da
  // lì ci si deve partire col dito per disegnare la traiettoria. Misurato su
  // un tablet da ~1274dp: il token arriva a 0,84×larghezza schermo, quindi
  // l'ingombro della card dal bordo destro non può superare ~196dp. Con i
  // margini ridotti al minimo (vedi sotto) restano 85dp a colonna.
  // "Attacco" a 16px sta in 85−12 di padding; oltre si tronca con l'ellissi
  // invece di sfondare il bottone.
  static const double _kLarghezzaFondamentale = 85;
  static const double _kLarghezzaVoto = 85;

  // L'header del pannello va vincolato a questa larghezza: il FittedBox passa
  // vincoli ILLIMITATI, quindi un cognome lungo allargherebbe tutta la card
  // (e, per compensare, la rimpicciolirebbe di scala) invece di troncarsi.
  static const double _kLarghezzaPulsantiera =
      _kLarghezzaFondamentale + _kGapPulsantiera + _kLarghezzaVoto;

  // ===== PROVA USA-E-GETTA (2026-08-21) =====================================
  // Griglia 4 colonne x 5 righe alla larghezza che la card aveva PRIMA di
  // stringerla per il cambio campo (236dp totali): serve solo a vedere quanto
  // verrebbero grandi i bottoni. Per toglierla: questa costante a false e via
  // il metodo _buildProvaGriglia4x5.
  static const bool _kProvaGriglia4x5 = false;

  // Larghezza di una cella: è LA MANOPOLA della prova, cambia solo questo
  // numero e ricarica. La card viene 4 x cella + 3 gap da 8 + 12 di padding,
  // e l'ingombro dal bordo destro è quello + 4.
  //   50 -> card 236  (quanto era prima di stringerla per il cambio campo)
  //   62 -> card 284  (etichette su una riga, ma sfonda il limite del
  //                    battitore col cambio campo, che sta a ~196)
  // Altezza riga invariata, 64.
  static const double _kProvaLarghezzaCella = 62;

  Widget _buildProvaGriglia4x5() {
    // Contenuto plausibile solo per giudicare la leggibilità alla misura:
    // fondamentali, voti, tipi di battuta, tipi di attacco.
    const colonne = <List<String>>[
      ['Difesa', 'Attacco', 'Muro', 'Alzata', ''],
      ['#', '+', '/', '-', '='],
      ['Dal basso', 'Float', 'Salto', 'Salto float', ''],
      ['Forte', 'Piazzata', 'Pallonetto', '', ''],
    ];
    const colori = <Color>[
      AppColors.brandPrimary,
      AppColors.neutral,
      AppColors.brandPrimary,
      AppColors.brandPrimary,
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var c = 0; c < colonne.length; c++) ...[
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var r = 0; r < 5; r++) ...[
                Container(
                  width: _kProvaLarghezzaCella,
                  height: _kAltezzaRigaPulsantiera,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: colonne[c][r].isEmpty
                        ? Colors.white10
                        : (c == 1
                            ? CourtStyle.votoColor(Voto.values[r])
                            : colori[c]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    colonne[c][r],
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: c == 1 ? 28 : 12,
                    ),
                  ),
                ),
                if (r < 4) const SizedBox(height: _kGapPulsantiera),
              ],
            ],
          ),
          if (c < colonne.length - 1)
            const SizedBox(width: _kGapPulsantiera),
        ],
      ],
    );
  }
  // ===== FINE PROVA USA-E-GETTA ============================================

  // PULSANTIERA UNICA: fondamentali a sinistra, voti a destra, sempre
  // entrambi a schermo. Si tocca una voce per colonna, in QUALSIASI ORDINE, e
  // alla coppia completa l'azione parte da sé (vedi _provaRegistrare). Toccare
  // di nuovo la stessa colonna corregge la scelta senza scrivere nulla.
  //
  // Tre configurazioni, tutte con la stessa forma e le stesse coordinate:
  // - fase LIBERA: entrambe le colonne attive;
  // - fase FORZATA (battuta/ricezione): colonna fondamentali spenta — il
  //   fondamentale lo impone la fase — basta il voto;
  // - RISTRETTA (dopo un `#` avversario, scorciatoia kill): solo Muro/Difesa
  //   attivi e rossi, un tocco registra subito il `=`; la colonna voti è
  //   spenta col `=` evidenziato, come anteprima di quello che verrà scritto.
  // Colonna di sinistra "normale": i 4 fondamentali.
  List<Widget> _colonnaFondamentali({
    required Fondamentale? selezionato,
    required bool bloccata,
    required bool ristretto,
    required void Function(Fondamentale) onFondamentale,
    required void Function(Fondamentale) onErroreDifensivo,
    required TutorialTarget? Function(Fondamentale) targetFond,
  }) {
    return [
      for (final f in _kFondamentaliPulsantiera)
        _anchorOpz(
          targetFond(f),
          _buildBottoneFondamentale(
            fondamentale: f,
            bloccato: bloccata,
            ristretto: ristretto,
            selezionato: f == selezionato,
            // Si attenuano le voci NON scelte solo quando una scelta in questa
            // colonna c'è: finché è vuota devono restare tutte piene,
            // altrimenti il pannello si apre con l'aria di essere tutto
            // disattivato.
            attenuato: selezionato != null && f != selezionato,
            onNormale: () => onFondamentale(f),
            onErroreDifensivo: () => onErroreDifensivo(f),
          ),
        ),
    ];
  }

  // Colonna di sinistra in BATTUTA: i tipi di servizio al posto dei quattro
  // fondamentali, che lì sono spenti e non dicono niente — è lo stesso spazio,
  // usato per l'unico dato che in battuta manca. Sono 5 come i voti, quindi le
  // due colonne restano allineate.
  // "Generico" è una voce come le altre: si parte da lì e si torna lì.
  // Colore BLU come i fondamentali: l'ambra era stata scelta per distinguere
  // la colonna, ma sul giallo le etichette si leggevano male — e la fase la
  // dice già il chip nell'header, quindi il colore non deve dirla due volte.
  List<Widget> _colonnaTipiBattuta({
    required TipoBattuta selezionato,
    required void Function(TipoBattuta) onTipo,
  }) {
    return [
      for (final tipo in TipoBattuta.values)
        _buildBottonePulsantiera(
          larghezza: _kLarghezzaFondamentale,
          colore: AppColors.brandPrimary,
          abilitato: true,
          selezionato: tipo == selezionato,
          attenuato: tipo != selezionato,
          onTap: () => onTipo(tipo),
          child: Text(
            tipoBattutaLabel(tipo, AppLocalizations.of(context)),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
    ];
  }

  // Colonna di sinistra dopo un tratto DISEGNATO in fase libera: i tipi di
  // attacco al posto dei fondamentali, che a quel punto non servono più — il
  // disegno ha già deciso che è un attacco (vedi
  // _preselezionaAttaccoDaTraiettoria). Stessa forma della colonna che
  // sostituisce (4 voci) e stesso blu: la card non cambia larghezza.
  // È l'unico modo per indicare il tipo di attacco col disegno in-line, dove
  // TrajectoryScreen — che ospita i chip — non si apre mai.
  List<Widget> _colonnaTipiAttacco() {
    return [
      for (final tipo in TipoAttacco.values)
        _buildBottonePulsantiera(
          larghezza: _kLarghezzaFondamentale,
          colore: AppColors.brandPrimary,
          abilitato: true,
          selezionato: tipo == _tipoAttaccoInLine,
          attenuato: tipo != _tipoAttaccoInLine,
          onTap: () => setState(() => _tipoAttaccoInLine = tipo),
          child: Text(
            tipoAttaccoLabel(tipo, AppLocalizations.of(context)),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
    ];
  }

  Widget _buildPulsantiera({
    required Fondamentale? selezionato,
    required Voto? votoSelezionato,
    required bool colonnaFondBloccata,
    required bool ristretto,
    required void Function(Fondamentale) onFondamentale,
    required void Function(Fondamentale) onErroreDifensivo,
    required void Function(Voto) onVoto,
    required TutorialTarget? Function(Fondamentale) targetFond,
    required TutorialTarget? Function(Voto) targetVoto,
    // Voci della colonna di SINISTRA già costruite: i 4 fondamentali di
    // norma, i tipi di battuta quando la fase è il servizio (vedi
    // _colonnaTipiBattuta). Passarle dall'esterno tiene le àncore del tutorial
    // dove sono e questo metodo si limita a impaginare.
    required List<Widget> vociSinistra,
  }) {
    if (_kProvaGriglia4x5) return _buildProvaGriglia4x5(); // PROVA, da togliere
    // Colonna di sinistra VUOTA = forma a COLONNA SINGOLA: la fase impone il
    // fondamentale e non c'è nessun tipo di esecuzione da offrire (ricezione),
    // quindi quattro bottoni spenti sarebbero solo campo coperto.
    // I voti si prendono tutta la larghezza della card: ALLARGATI, non
    // centrati alla misura solita. La card resta larga uguale (l'header la
    // vincola a _kLarghezzaPulsantiera), quindi il bordo destro di ogni
    // bottone NON si sposta — il dito li ritrova dove li ha imparati e in più
    // il bersaglio cresce. Centrandoli a 85 si sposterebbero verso il campo,
    // che è l'unica cosa che la memoria muscolare non perdona.
    final soloVoti = vociSinistra.isEmpty;
    final colonnaVoti = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final voto in Voto.values) ...[
          _anchorOpz(
            targetVoto(voto),
            _buildBottoneVoto(
              voto: voto,
              larghezza: soloVoti ? _kLarghezzaPulsantiera : _kLarghezzaVoto,
              // Nel ristretto il `=` è solo un'anteprima: evidenziato ma
              // non tappabile, la registrazione parte dal fondamentale.
              bloccato: ristretto,
              selezionato:
                  ristretto ? voto == Voto.errore : voto == votoSelezionato,
              attenuato: votoSelezionato != null && voto != votoSelezionato,
              onTap: () => onVoto(voto),
            ),
          ),
          if (voto != Voto.values.last)
            const SizedBox(height: _kGapPulsantiera),
        ],
      ],
    );
    if (soloVoti) return colonnaVoti;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < vociSinistra.length; i++) ...[
              vociSinistra[i],
              if (i < vociSinistra.length - 1)
                const SizedBox(height: _kGapPulsantiera),
            ],
          ],
        ),
        const SizedBox(width: _kGapPulsantiera),
        colonnaVoti,
      ],
    );
  }

  // Bottone della colonna fondamentali, condiviso tra pannello nostro e
  // avversario. `bloccato` = la fase impone già il fondamentale (spento non
  // tappabile). `ristretto` = scorciatoia kill: SOLO Muro/Difesa attivi e
  // rossi → `onErroreDifensivo` registra subito quel fondamentale con voto
  // `=`, senza passare dalla colonna voti.
  Widget _buildBottoneFondamentale({
    required Fondamentale fondamentale,
    required bool bloccato,
    required bool ristretto,
    required bool selezionato,
    required bool attenuato,
    required VoidCallback onNormale,
    required VoidCallback onErroreDifensivo,
  }) {
    final difensivo = fondamentale == Fondamentale.muro ||
        fondamentale == Fondamentale.difesa;
    final abilitato = !bloccato && (!ristretto || difensivo);
    final rosso = ristretto && difensivo;
    return _buildBottonePulsantiera(
      larghezza: _kLarghezzaFondamentale,
      colore: !abilitato
          ? AppColors.neutral
          : (rosso ? Colors.red : AppColors.brandPrimary),
      abilitato: abilitato,
      selezionato: selezionato,
      attenuato: attenuato,
      onTap: ristretto ? onErroreDifensivo : onNormale,
      child: Text(
        fondamentaleLabel(fondamentale, AppLocalizations.of(context)),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildBottoneVoto({
    required Voto voto,
    // _kLarghezzaVoto nella forma a due colonne, tutta la card in quella a
    // colonna singola (vedi _buildPulsantiera).
    required double larghezza,
    required bool bloccato,
    required bool selezionato,
    required bool attenuato,
    required VoidCallback onTap,
  }) {
    return _buildBottonePulsantiera(
      larghezza: larghezza,
      colore: bloccato && !selezionato
          ? AppColors.neutral
          : CourtStyle.votoColor(voto),
      abilitato: !bloccato,
      selezionato: selezionato,
      attenuato: attenuato,
      onTap: onTap,
      child: Text(
        voto.simbolo,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 28,
        ),
      ),
    );
  }

  // Forma comune ai bottoni delle due colonne: la selezione si legge da un
  // bordo bianco spesso, e le voci NON scelte della stessa colonna si
  // attenuano — così a colpo d'occhio si vede cosa manca per chiudere la
  // coppia. Un bottone spento resta al suo posto (non sparisce mai): è la
  // stabilità delle coordinate il motivo per cui la pulsantiera è unica.
  Widget _buildBottonePulsantiera({
    required double larghezza,
    required Color colore,
    required bool abilitato,
    required bool selezionato,
    required bool attenuato,
    required VoidCallback onTap,
    required Widget child,
  }) {
    // La selezione vince sul blocco: nella pulsantiera ristretta il `=` è
    // spento ma va comunque letto bene, è l'anteprima di cosa verrà scritto.
    final opacita = selezionato
        ? 1.0
        : !abilitato
            ? 0.4
            : (attenuato ? 0.55 : 1.0);
    return Opacity(
      opacity: opacita,
      child: GestureDetector(
        onTap: abilitato ? onTap : null,
        child: Container(
          width: larghezza,
          height: _kAltezzaRigaPulsantiera,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: colore,
            borderRadius: BorderRadius.circular(10),
            border: selezionato
                ? Border.all(color: Colors.white, width: 3)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(120),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  // Sfondo che chiude il pannello aperto toccando fuori dalla card.
  //
  // Va messo come PRIMO figlio dello Stack, cioè in FONDO a tutto: lo Stack
  // cerca il bersaglio del tocco dall'ultimo figlio verso il primo e si ferma
  // al primo che lo reclama. Con lo scrim in cima (dov'era) il tocco su un
  // token non arrivava mai al token: il pannello si chiudeva e basta, e per
  // passare a un'altra giocatrice servivano due tocchi. In fondo, invece, i
  // token lo intercettano prima — così un tocco su un'altra giocatrice
  // SOSTITUISCE quella in corso (vedi _tapHandlerPerGiocatore, che riparte da
  // una coppia vuota: fondamentale e voto già scelti NON si trascinano dietro,
  // altrimenti il cambio registrerebbe da solo) — mentre un tocco sul campo
  // vuoto o sullo sfondo cade quaggiù e chiude, come prima. L'immagine del
  // campo non intercetta i tocchi, quindi non fa da schermo.
  //
  // Conseguenza da tenere a mente: tutto ciò che è interattivo e sta sopra
  // (mini-map, bottoni di correzione rotazione) adesso riceverebbe il tocco
  // invece di chiudere — per questo in build sono avvolti in `IgnorePointer`
  // mentre un pannello è aperto.
  // SEMPRE in albero, spento con IgnorePointer quando non serve, e con una
  // key esplicita. Non è pignoleria: comparendo e sparendo da QUESTA
  // posizione faceva slittare di uno tutti i figli dello Stack, e Flutter
  // accoppiava l'elemento dello scrim col widget del campo — stesso tipo
  // (`Positioned`) e stessa key (nessuna), quindi `canUpdate` vero. Risultato:
  // l'intero sottoalbero del campo ricostruito da zero a ogni apertura o
  // chiusura del pannello, con gli `AnimatedPositioned` dei token rimontati e
  // quindi **senza animazione** di rotazione. Con una lunghezza costante e una
  // key il problema non si pone.
  Widget _buildScrimPannelli() {
    return Positioned.fill(
      key: const ValueKey('scrim-pannelli'),
      child: IgnorePointer(
        ignoring: !_pannelloAperto,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _chiudiPannelli,
        ),
      ),
    );
  }

  void _chiudiPannelli() => setState(() {
        _votoInCorso = null;
        _avversarioInCorso = null;
        _azzeraTraiettoriaInLine();
      });

  // Freccia della traiettoria disegnata sul campo live. Resta visibile anche
  // dopo il rilascio, fino a che l'azione non viene registrata o il pannello
  // chiuso: è l'unica conferma che il tratto è stato preso.
  //
  // Sempre in albero, anche quando non c'è niente da disegnare: il painter si
  // ridisegna da solo osservando `_frecciaInLine`, e montarlo/smontarlo
  // vorrebbe dire tornare a un setState per ogni frame del trascinamento.
  // Key esplicita per lo stesso motivo dello scrim: i builder che la
  // precedono nello Stack hanno lunghezza variabile (il log azioni compare e
  // sparisce), e senza key un `Positioned` può essere accoppiato con quello
  // sbagliato quando gli indici slittano.
  Widget _buildFrecciaInLine(
    double courtLeft,
    double courtTop,
    double courtWidth,
    double courtHeight,
  ) =>
      Positioned.fill(
        key: const ValueKey('freccia-in-line'),
        child: IgnorePointer(
          child: CustomPaint(
            painter: _FrecciaLivePainter(
              _frecciaInLine,
              xRete: courtLeft + courtWidth / 2,
              cimaCampo: courtTop,
              altezzaCampo: courtHeight,
            ),
          ),
        ),
      );

  // Chip del fondamentale imposto dalla fase (battuta/ricezione), nell'header
  // del pannello: quelle due voci non stanno nella colonna — che ha 4 slot
  // fissi — ma vanno comunque mostrate, altrimenti non si saprebbe cosa si sta
  // votando.
  Widget _buildChipFondamentaleForzato(Fondamentale fondamentale) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.brandPrimary,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Text(
        fondamentaleLabel(fondamentale, AppLocalizations.of(context)),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }

  // Pannello voto: si apre toccando un giocatore tappabile (battitore in
  // battuta, qualunque ricevitore in ricezione — vedi
  // _tapHandlerPerGiocatore), ancorato al bordo destro dello schermo, 5
  // bottoni verticali (uno per Voto, stesso ordine dell'enum: # + / - =).
  // Per la battuta, anche la griglia opzionale del tipo (vedi sopra).
  // Niente traiettoria per ora.
  // Ritorna [] se il pannello è chiuso. Quando aperto: uno sfondo
  // trasparente a tutto schermo (tap fuori dal pannello → annulla, vedi
  // sotto) + il pannello stesso.
  List<Widget> _buildPannelloVoto() {
    final inCorso = _votoInCorso;
    if (inCorso == null) return const [];
    final player = inCorso.giocatore;
    // Battuta e ricezione non hanno uno slot nella colonna: se il pannello si
    // è aperto su uno dei due, è la fase ad averlo imposto → chip nell'header
    // e colonna bloccata. Derivato da cosa c'è nella colonna, non da
    // _fondamentaleForzato(), così i due non possono divergere.
    final fondForzato = inCorso.fondamentale != null &&
            !_kFondamentaliPulsantiera.contains(inCorso.fondamentale)
        ? inCorso.fondamentale
        : null;

    // Tratto DISEGNATO in fase libera: il fondamentale l'ha già deciso il
    // disegno (vedi _preselezionaAttaccoDaTraiettoria), quindi la colonna dei
    // fondamentali non serve più e può passare ai tipi di attacco — l'unico
    // modo di indicarli con l'in-line, dove TrajectoryScreen non si apre.
    final tipiAttacco = fondForzato == null &&
        _traiettoriaNormalizzata != null &&
        inCorso.fondamentale == Fondamentale.attacco;

    // Quale colonna di sinistra: la fase e il disegno decidono, la
    // pulsantiera si limita a impaginare quello che le arriva (vedi
    // _buildPulsantiera).
    final List<Widget> vociSinistra;
    if (fondForzato == Fondamentale.battuta) {
      // In battuta la colonna diventa i tipi di servizio: i fondamentali lì
      // sono spenti e sprecherebbero lo spazio dove manca proprio quel dato.
      vociSinistra = _colonnaTipiBattuta(
        selezionato: _tipoBattutaSelezionato,
        onTipo: (t) => _scegliTipoBattuta(player, t),
      );
    } else if (fondForzato != null) {
      // Ricezione: niente da scegliere a sinistra e nessun tipo da offrire in
      // cambio — via la colonna, i voti si allargano su tutta la card.
      vociSinistra = const [];
    } else if (tipiAttacco) {
      vociSinistra = _colonnaTipiAttacco();
    } else {
      vociSinistra = _colonnaFondamentali(
        selezionato: inCorso.fondamentale,
        bloccata: false,
        ristretto: _difesaErroreForzataNostra,
        onFondamentale: _sceglieFondamentale,
        onErroreDifensivo: (f) => _registraErroreDifensivoRapido(player, f),
        targetFond: targetFondamentaleNostro,
      );
    }

    // Il chip nell'header dice qual è il fondamentale quando NON lo si legge
    // dalla colonna: imposto dalla fase (battuta/ricezione) oppure — da quando
    // la colonna può diventare i tipi di attacco — deciso dal disegno.
    // Senza, tolta la colonna non resterebbe scritto da nessuna parte che
    // quella che stai per registrare è una schiacciata.
    final fondChip = fondForzato ?? (tipiAttacco ? Fondamentale.attacco : null);

    return [
      Positioned(
        // 4 e non 16: ogni dp fra la card e il bordo dello schermo è un dp in
        // meno di campo coperto, e col cambio campo lì sotto c'è il battitore.
        right: 4,
        // Margini verticali minimi: su smartphone la scala del pannello è
        // vincolata dall'altezza disponibile (vedi FittedBox sotto), ogni
        // px recuperato qui ingrandisce la bottoniera dei voti.
        top: 4,
        bottom: 4,
        child: Align(
          alignment: Alignment.topCenter,
          // FittedBox(scaleDown): su smartphone l'altezza non basta per la
          // colonna dei 5 voti (5×64 + header) e il pannello sborderebbe —
          // si rimpicciolisce in proporzione (tap compresi, il
          // GestureDetector sta DENTRO la scala). Su tablet scala = 1.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            // Un trascinamento partito sulla card non deve disegnare una
            // traiettoria. Questo Listener è più PROFONDO di quello che
            // avvolge lo Stack, quindi riceve l'evento prima e fa in tempo ad
            // alzare il flag (vedi _onPointerDownCampo).
            child: Listener(
              onPointerDown: (_) => _gestoSullaCard = true,
              child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {}, // assorbe il tap, non deve propagarsi allo sfondo
              child: _anchor(
                TutorialTarget.pannelloVoto,
                Container(
                  // Padding stretto: orizzontale perché la card non deve
                  // invadere il campo (vedi _kLarghezzaFondamentale),
                  // verticale perché su telefono è l'altezza a decidere di
                  // quanto il FittedBox rimpicciolisce tutto — meno padding
                  // qui vuol dire bottoni più grandi, non più piccoli.
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _kTopBarBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: _kLarghezzaPulsantiera,
                        child: Column(
                          children: [
                            Text(
                              '${player.numero}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 26,
                              ),
                            ),
                            // Il cognome ha ora tutta la larghezza della
                            // pulsantiera (212dp contro i 100 di prima):
                            // serve a confermare a colpo d'occhio di aver
                            // toccato la giocatrice giusta, quindi va letto
                            // senza fermarsi. Resta su una riga: se non ci
                            // sta si tronca, non manda a capo la card.
                            Text(
                              player.cognome,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 18,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (fondChip != null)
                              _buildChipFondamentaleForzato(fondChip),
                          ],
                        ),
                      ),
                      const SizedBox(height: _kGapPulsantiera),
                      _buildPulsantiera(
                        selezionato: inCorso.fondamentale,
                        votoSelezionato: inCorso.voto,
                        colonnaFondBloccata: fondForzato != null,
                        ristretto: _difesaErroreForzataNostra,
                        onFondamentale: _sceglieFondamentale,
                        onErroreDifensivo: (f) =>
                            _registraErroreDifensivoRapido(player, f),
                        onVoto: _scegliVoto,
                        targetFond: targetFondamentaleNostro,
                        targetVoto: targetVotoNostro,
                        vociSinistra: vociSinistra,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ),
          ),
        ),
      ),
    ];
  }

  // Pannello per un'azione AVVERSARIA: si apre toccando un token avversario
  // (vedi _tapHandlerAvversario). Stessa struttura/stile/pulsantiera di
  // _buildPannelloVoto (scrim + card a destra), ma header col RUOLO
  // placeholder invece del giocatore, e esito invertito (vedi
  // _registraVotoAvversario). Ritorna [] se chiuso.
  List<Widget> _buildPannelloAvversario() {
    final inCorso = _avversarioInCorso;
    if (inCorso == null) return const [];
    // Come nel pannello nostro: battuta/ricezione non hanno uno slot nella
    // colonna, quindi se sono selezionate le ha imposte la fase.
    final fondForzato = inCorso.fondamentale != null &&
            !_kFondamentaliPulsantiera.contains(inCorso.fondamentale)
        ? inCorso.fondamentale
        : null;

    // Colonna di sinistra e chip: stesse tre forme del pannello nostro —
    // tipi di servizio in battuta, niente colonna in ricezione, tipi di
    // attacco dopo un tratto disegnato.
    final tipiAttacco = fondForzato == null &&
        _traiettoriaNormalizzata != null &&
        inCorso.fondamentale == Fondamentale.attacco;

    final List<Widget> vociSinistra;
    if (fondForzato == Fondamentale.battuta) {
      vociSinistra = _colonnaTipiBattuta(
        selezionato: _tipoBattutaAvversario,
        onTipo: (t) => setState(() => _tipoBattutaAvversario = t),
      );
    } else if (fondForzato != null) {
      vociSinistra = const [];
    } else if (tipiAttacco) {
      vociSinistra = _colonnaTipiAttacco();
    } else {
      vociSinistra = _colonnaFondamentali(
        selezionato: inCorso.fondamentale,
        bloccata: false,
        ristretto: _difesaErroreForzataAvversaria,
        onFondamentale: _scegliFondamentaleAvversario,
        onErroreDifensivo: (f) =>
            _registraErroreDifensivoAvversarioRapido(inCorso.ruolo, f),
        targetFond: targetFondamentaleAvversario,
      );
    }

    final fondChip = fondForzato ?? (tipiAttacco ? Fondamentale.attacco : null);

    return [
      Positioned(
        right: 4, // vedi il gemello in _buildPannelloVoto
        top: 4,
        bottom: 4,
        child: Align(
          alignment: Alignment.topCenter,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            // Come nel pannello nostro: un trascinamento partito sulla card
            // non deve disegnare una traiettoria (vedi _onPointerDownCampo).
            child: Listener(
              onPointerDown: (_) => _gestoSullaCard = true,
              child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: _anchor(
                TutorialTarget.pannelloAvversario,
                Container(
                  // Padding stretto: orizzontale perché la card non deve
                  // invadere il campo (vedi _kLarghezzaFondamentale),
                  // verticale perché su telefono è l'altezza a decidere di
                  // quanto il FittedBox rimpicciolisce tutto — meno padding
                  // qui vuol dire bottoni più grandi, non più piccoli.
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _kTopBarBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: _kLarghezzaPulsantiera,
                        child: Column(
                          children: [
                            Text(
                              AppLocalizations.of(
                                context,
                              ).scoutAvversarioEtichetta,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              siglaRuolo(
                                  inCorso.ruolo, AppLocalizations.of(context)),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 26,
                              ),
                            ),
                            if (fondChip != null)
                              _buildChipFondamentaleForzato(fondChip),
                          ],
                        ),
                      ),
                      const SizedBox(height: _kGapPulsantiera),
                      _buildPulsantiera(
                        selezionato: inCorso.fondamentale,
                        votoSelezionato: inCorso.voto,
                        colonnaFondBloccata: fondForzato != null,
                        ristretto: _difesaErroreForzataAvversaria,
                        onFondamentale: _scegliFondamentaleAvversario,
                        onErroreDifensivo: (f) =>
                            _registraErroreDifensivoAvversarioRapido(
                                inCorso.ruolo, f),
                        onVoto: _scegliVotoAvversario,
                        targetFond: targetFondamentaleAvversario,
                        targetVoto: targetVotoAvversario,
                        vociSinistra: vociSinistra,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ),
          ),
        ),
      ),
    ];
  }


  Widget _buildRotationButton(
    IconData icon,
    VoidCallback onTap,
    double smallCourtSize,
  ) {
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

  // Bottone di correzione rotazione: stesso stile/dimensione di
  // _buildRotationButton ma con una label testuale (la rotazione di ARRIVO,
  // es. "P6") invece dell'icona. FittedBox così la label sta sempre dentro il
  // bottone anche su schermi piccoli.
  Widget _buildRotationCorrectionButton(
    String label,
    VoidCallback onTap,
    double smallCourtSize,
  ) {
    final buttonSize = smallCourtSize * 0.45;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: buttonSize,
        height: buttonSize,
        alignment: Alignment.center,
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
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: EdgeInsets.all(buttonSize * 0.14),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Slot occupato dal giocatore di SECONDA LINEA (P5, P6 o P1) che il libero
  // sostituisce — la coppia è quella scelta in FormationConfigScreen
  // (`_ruoloCambiLiberoEffettivo`: centrali o schiacciatori, mai una
  // combinazione). I due della coppia sono sempre opposti nella rotazione (3
  // posizioni di distanza), quindi ce n'è sempre esattamente uno in seconda
  // linea. Null se non c'è libero in formazione, o se per qualche motivo
  // nessuno dei due ruoli della coppia è assegnato (formazione incompleta).
  String? _slotCentraleSecondaLinea(Map<String, String> roleLabels) {
    final ruolo = _ruoloCambiLiberoEffettivo;
    if (ruolo == null) return null;
    final etichette = (ruolo == Ruolo.centrale || ruolo == Ruolo.undefined)
        ? const {'C1', 'C2'}
        : const {'S1', 'S2'};
    const secondaLinea = {'P5', 'P6', 'P1'};
    for (final entry in roleLabels.entries) {
      if (secondaLinea.contains(entry.key) && etichette.contains(entry.value)) {
        return entry.key;
      }
    }
    return null;
  }

  // Costruisce i token dei giocatori sul campo grande, ESCLUSO lo slot della
  // coppia cambi-libero (`_slotCentraleSecondaLinea`): libero e relativo
  // sostituito vivono nello Stack esterno (vedi _buildLiberoSwapTokens),
  // perché devono potersi animare anche verso/da la panchina ancorata allo
  // schermo, fuori dai confini di questo campo. In ricezione (mappa di
  // difesa attiva per la rotazione corrente): itera per RUOLO sulla mappa di
  // difesa. Altrimenti: itera per giocatore sulle posizioni di attacco.
  List<Widget> _buildCourtTokens(double cw, double ch) {
    final currentAssignments = _currentAssignments;
    final roleLabels = _roleLabels(_currentSlot, currentAssignments);
    final defenseMap = _activeDefenseMap;
    final slotCentrale = _slotCentraleSecondaLinea(roleLabels);
    // Attenuazione per SQUADRA in base alla fase (vedi _nostriInAttesa): i
    // nostri token si attenuano quando siamo la squadra "in attesa" (loro
    // servizio/ricezione, o dopo un NOSTRO `#`). La tappabilità resta guidata
    // a parte da _tapHandlerPerGiocatore/_giocatoreTappabile.
    final bloccati = _nostriInAttesa;

    if (defenseMap == null) {
      return [
        for (final entry in currentAssignments.entries)
          if (entry.key != slotCentrale)
            _buildPlayerToken(
              roleLabels[entry.key] ?? entry.key,
              entry.value,
              _displayPosition(_attackPosition(entry.key, roleLabels)),
              cw,
              ch,
              onTap: _tapHandlerPerGiocatore(entry.value, slot: entry.key),
              disabilitato: bloccati,
            ),
      ];
    }

    final slotPerRuolo = {for (final e in roleLabels.entries) e.value: e.key};
    final tokens = <Widget>[];
    for (final entry in defenseMap.entries) {
      if (entry.key == 'Libero') continue; // gestito nello Stack esterno
      final slot = slotPerRuolo[entry.key];
      final player = slot == null ? null : currentAssignments[slot];
      if (player != null) {
        tokens.add(
          _buildPlayerToken(
            entry.key,
            player,
            _displayPosition(entry.value),
            cw,
            ch,
            onTap: _tapHandlerPerGiocatore(player, slot: slot),
            disabilitato: bloccati,
          ),
        );
      }
    }
    return tokens;
  }

  // Libero e relativo sostituito (centrale/schiacciatore di seconda linea):
  // chi è "in campo" e chi è "in panchina" si scambiano a ogni rotazione, e
  // la panchina deve restare ancorata ai bordi reali dello schermo (non al
  // riquadro del campo, che è centrato con margini) — quindi entrambi vivono
  // in QUESTO Stack esterno (coordinate schermo assolute), non in quello
  // interno del campo grande. Stessa key (player.id) sia in campo sia in
  // panchina: AnimatedPositioned anima il movimento in entrambi i casi.
  List<Widget> _buildLiberoSwapTokens(
    BoxConstraints constraints,
    double courtWidth,
  ) {
    final liberiEffettivi = _liberiEffettivi;
    final liberoKey = _liberoAttivoKey;
    final libero = liberiEffettivi[liberoKey];
    if (libero == null) return const [];

    final radius = _swapTokenRadius(courtWidth);
    final bench0 = _benchScreenPos(constraints, radius);
    final bench1 = _bench1ScreenPos(constraints, radius);

    // Libero inattivo (slot 1): sempre in panchina fissa, tappabile.
    // Usa ValueKey(player.id) come tutti i token: Flutter può così animare
    // il movimento quando attivo e inattivo si scambiano (stesso key, nuova
    // posizione → AnimatedPositioned interpola fluidamente tra le due).
    final inattivoKey = _liberoInattivoKey;
    final inattivo = inattivoKey != null ? liberiEffettivi[inattivoKey] : null;
    final bench1Token = inattivo != null
        ? _buildAbsoluteToken(
            inattivoKey!,
            inattivo,
            bench1,
            radius,
            isLibero: true,
            onTap: () => setState(() => _liberoOverride = inattivoKey),
          )
        : null;

    final currentAssignments = _currentAssignments;
    final roleLabels = _roleLabels(_currentSlot, currentAssignments);
    final slotCentrale = _slotCentraleSecondaLinea(roleLabels);
    if (slotCentrale == null) {
      // Nessuna coppia di cambio derivabile (formazione incompleta): il
      // libero attivo resta in panchina (slot 0).
      return [
        _buildAbsoluteToken(liberoKey, libero, bench0, radius, isLibero: true),
        ?bench1Token,
      ];
    }
    final giocatoreCoppia = currentAssignments[slotCentrale];
    if (giocatoreCoppia == null) {
      return [?bench1Token];
    }

    final defenseMap = _activeDefenseMap;
    // L'eccezione del servizio (libero in panchina) vale SOLO quando stiamo
    // per servire noi e il sostituito è in P1 — non quando `defenseMap` è
    // null per un altro motivo (es. ricezione già giudicata, fase di
    // attacco: il libero deve restare in campo anche se il sostituito è
    // rotato in P1, perché in quella fase P1 non significa "deve servire").
    final stiamoServendo = _squadraAlServizio == Squadra.nostra;
    final sostituzioneAttiva = !(stiamoServendo && slotCentrale == 'P1');
    final courtHeight = courtWidth / 2;
    final courtLeft = (constraints.maxWidth - courtWidth) / 2;
    final courtTop = _kCourtTopMargin;
    Offset toScreen(Offset ref) => Offset(
      courtLeft + (ref.dx / 1200) * courtWidth,
      courtTop + (ref.dy / 600) * courtHeight,
    );

    if (sostituzioneAttiva) {
      // In ricezione il libero ha una sua posizione dedicata (mappa di
      // difesa); in battuta prende esattamente il posto del sostituito. È
      // in campo → tappabile (solo in ricezione, vedi _fondamentaleTappabile
      // con slot=null: il libero non ha uno slot P1-P6 proprio).
      final liberoRef = defenseMap != null
          ? defenseMap['Libero']!
          : (_activeAttackMap?['Libero'] ?? _refPositionFor(slotCentrale));
      return [
        _buildAbsoluteToken(
          liberoKey,
          libero,
          toScreen(_displayPosition(liberoRef)),
          radius,
          isLibero: true,
          onTap: _tapHandlerPerGiocatore(libero),
          // Attenuazione per squadra (vedi _nostriInAttesa): il libero in
          // campo segue i nostri token.
          disabilitato: _nostriInAttesa,
        ),
        // Il sostituito è in panchina (slot 0): non tappabile.
        _buildAbsoluteToken(
          roleLabels[slotCentrale] ?? slotCentrale,
          giocatoreCoppia,
          bench0,
          radius,
        ),
        ?bench1Token,
      ];
    }
    // Eccezione del servizio (P1): il sostituito resta in campo (tappabile:
    // è il battitore in battuta, un ricevitore normale in ricezione), il
    // libero attivo va in panchina (slot 0, non tappabile).
    return [
      _buildAbsoluteToken(
        roleLabels[slotCentrale] ?? slotCentrale,
        giocatoreCoppia,
        toScreen(_displayPosition(_attackPosition(slotCentrale, roleLabels))),
        radius,
        onTap: _tapHandlerPerGiocatore(giocatoreCoppia, slot: slotCentrale),
        disabilitato: _nostriInAttesa,
      ),
      _buildAbsoluteToken(liberoKey, libero, bench0, radius, isLibero: true),
      ?bench1Token,
    ];
  }

  // Area di tap per il battitore quando è fuori dal campo (X negativa, vedi
  // _kBattutaP1Position): il token resta visibile lì grazie a Clip.none
  // sullo Stack interno, ma quella zona è fuori dai limiti di hit-test del
  // SizedBox/AspectRatio che racchiude il campo (Clip.none evita solo il
  // clip del DISEGNO, non quello del tocco) — quindi un GestureDetector
  // dentro lo Stack interno lì non riceverebbe mai il tap. Stessa soluzione
  // già usata per libero/panchina: un overlay nello Stack esterno
  // (coordinate schermo assolute, sempre dentro i suoi limiti), sovrapposto
  // esattamente al token visibile. Solo quando battiamo noi: in ricezione
  // P1 è una posizione normale in campo, già tappabile dal proprio token
  // (qui sarebbe solo un overlay ridondante) — stesso motivo una volta che
  // la battuta è già stata giudicata in questo scambio (_faseDopo): il
  // battitore è rientrato in posizione di attacco, di nuovo coperto dal
  // proprio token normale.
  List<Widget> _buildBattitoreTapCatcher(
    BoxConstraints constraints,
    double courtWidth,
  ) {
    if (_squadraAlServizio != Squadra.nostra) return const [];
    if (_faseDopo) return const [];
    final player = _currentAssignments['P1'];
    if (player == null) return const [];
    final onTap = _tapHandlerPerGiocatore(player, slot: 'P1');
    if (onTap == null) return const [];

    final roleLabels = _roleLabels(_currentSlot, _currentAssignments);
    final radius = _swapTokenRadius(courtWidth);
    final tokenRadius = _currentSlot == 'P1' ? radius * 1.1 : radius;
    final courtHeight = courtWidth / 2;
    final courtLeft = (constraints.maxWidth - courtWidth) / 2;
    final courtTop = _kCourtTopMargin;
    final refPos = _displayPosition(_attackPosition('P1', roleLabels));
    final cx = courtLeft + (refPos.dx / 1200) * courtWidth;
    final cy = courtTop + (refPos.dy / 600) * courtHeight;

    return [
      Positioned(
        left: cx - tokenRadius,
        top: cy - tokenRadius,
        width: tokenRadius * 2,
        height: tokenRadius * 2,
        // Ancorato QUI e non sul token disegnato nello Stack interno: questa
        // è l'area di tap vera del battitore, ed è già in coordinate schermo.
        child: _anchor(
          TutorialTarget.tokenBattitore,
          _tokenConTrascinamento(onTap, player.id),
        ),
      ),
    ];
  }

  // Tap-catcher del BATTITORE avversario fuori dal campo (fase "battuta
  // avversaria"): il token è disegnato fuori dai confini del riquadro campo
  // (X oltre la loro linea di fondo) e lì il tap non arriverebbe allo Stack
  // interno (limiti di hit-test) — stesso trucco del nostro battitore. Apre il
  // pannello avversario forzato su Battuta.
  List<Widget> _buildBattitoreAvversarioTapCatcher(
    BoxConstraints constraints,
    double courtWidth,
  ) {
    if (!_attesaBattutaAvversaria) return const [];
    final slot = _statoSetReale?.palleggiatoreAvversarioSlot;
    if (slot == null) return const [];
    final ruolo = etichetteAvversarie(slot)[1]!; // ruolo in zona 1 (battitore)
    final onTap =
        _tapHandlerAvversario(ruolo, forzato: Fondamentale.battuta);
    if (onTap == null) return const [];

    final radius = _swapTokenRadius(courtWidth);
    final courtHeight = courtWidth / 2;
    final courtLeft = (constraints.maxWidth - courtWidth) / 2;
    final courtTop = _kCourtTopMargin;
    // Stessa posizione tattica del token del battitore in _buildTokenAvversari
    // (fuori campo, X<0 → mirror X>1200), così overlay di tap e token
    // coincidono — come per il nostro battitore.
    final refPos = _displayPosition(_posizioneAvversario(ruolo, 1));
    final cx = courtLeft + (refPos.dx / 1200) * courtWidth;
    final cy = courtTop + (refPos.dy / 600) * courtHeight;

    return [
      Positioned(
        left: cx - radius,
        top: cy - radius,
        width: radius * 2,
        height: radius * 2,
        child: _tokenConTrascinamento(onTap, ruolo),
      ),
    ];
  }

  // Overlay di selezione (inizio set, scout avversari attivo): 6 zone tappabili
  // sulla metà campo avversaria + scrim che sospende lo scout normale finché
  // non si sceglie. Coordinate schermo assolute (stesso Stack esterno di
  // libero/battitore): _kOpponentZonePositions è già la metà opposta, passa
  // per _displayPosition() così segue il cambio campo.
  List<Widget> _buildSelezionePAvversario(
    BoxConstraints constraints,
    double courtWidth,
  ) {
    if (!_inSelezionePAvversario) return const [];
    final courtHeight = courtWidth / 2;
    final courtLeft = (constraints.maxWidth - courtWidth) / 2;
    final courtTop = _kCourtTopMargin;
    final radius = _swapTokenRadius(courtWidth);
    Offset toScreen(Offset ref) => Offset(
          courtLeft + (ref.dx / 1200) * courtWidth,
          courtTop + (ref.dy / 600) * courtHeight,
        );

    return [
      // Scrim: assorbe i tap sul resto del campo (i cerchi zona stanno sopra),
      // leggero velo scuro per segnalare la modalità.
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: Container(color: Colors.black.withAlpha(90)),
        ),
      ),
      // Istruzione in alto, sopra il campo.
      Positioned(
        top: courtTop + 6,
        left: 0,
        right: 0,
        child: Center(
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _kTopBarBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              AppLocalizations.of(context).scoutSelezionaPAvversario,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
      // Le 6 zone avversarie tappabili.
      for (final entry in _kOpponentZonePositions.entries)
        () {
          final center = toScreen(_displayPosition(entry.value));
          return Positioned(
            left: center.dx - radius,
            top: center.dy - radius,
            width: radius * 2,
            height: radius * 2,
            child: GestureDetector(
              onTap: () => _confermaPAvversario(entry.key),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.brandAccent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  'P${entry.key}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        }(),
    ];
  }

  // Raggio in pixel reali (non in unità di riferimento): un ventesimo del
  // campo, dove "il campo" è l'altezza renderizzata (courtWidth/2), stessa
  // proporzione di _buildPlayerToken (ch/20).
  double _swapTokenRadius(double courtWidth) =>
      (courtWidth / 2) / 20 * _kTokenSizeScale;

  // Stessa posizione/dimensione della vecchia card fissa ad angolo: margine
  // 3% dai bordi reali dello schermo, ancorata in basso (a destra col cambio
  // campo) — non al riquadro del campo, che è centrato con margini propri.
  // Ritorna il CENTRO del token (usato da _buildAbsoluteToken con top/left).
  Offset _benchScreenPos(BoxConstraints constraints, double radius) {
    final margin = constraints.maxWidth * 0.03;
    final size = radius * 2;
    final left = _isRightSide ? constraints.maxWidth - size - margin : margin;
    final top = constraints.maxHeight - margin - size;
    return Offset(left + radius, top + radius);
  }

  // Centro del secondo slot in panchina (libero inattivo), affiancato al
  // primo. Su lato sinistro: slot 1 è a destra di slot 0; su lato destro: a
  // sinistra — stessa logica del lato per mini-map e bottoni di rotazione.
  Offset _bench1ScreenPos(BoxConstraints constraints, double radius) {
    final bench0 = _benchScreenPos(constraints, radius);
    final step = (radius * 2 + 8.0) * (_isRightSide ? -1.0 : 1.0);
    return Offset(bench0.dx + step, bench0.dy);
  }

  // Token "assoluto": stesso stile di _buildPlayerToken (cerchio, colore
  // invertito per il libero) ma posizionato in pixel di SCHERMO già
  // calcolati (non da scalare da uno spazio di riferimento) — necessario
  // perché questo Stack esterno copre sia l'area del campo sia l'area
  // "panchina" ancorata ai bordi schermo.
  // Avvolge il disegno di un token in un'animazione della selezione: `t` va da
  // 0 (deselezionato, bordo bianco sottile) a 1 (selezionato, bordo giallo più
  // grosso verso l'ESTERNO) con un breve flash-in, e torna a 0 alla
  // deselezione. `build` riceve `t` e disegna il token (cerchio o esagono)
  // derivandone colore e spessore del bordo. Condiviso dai tre builder.
  Widget _tokenConBordoAnimato(bool selezionato, Widget Function(double t) build) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: selezionato ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 220),
      builder: (context, t, _) => build(t),
    );
  }

  // Anello giallo ESTERNO del token selezionato (BoxShadow con spread: cresce
  // fuori dal token, non mangia il numero), da comporre con l'ombra nera del
  // token. Vuoto a t=0. `t` = valore di selezione animato.
  List<BoxShadow> _ombreTokenSelezione(double t) => [
        const BoxShadow(
          color: Color(0x78000000), // nero 47%, ombra base del token
          blurRadius: 4,
          offset: Offset(0, 2),
        ),
        if (t > 0)
          BoxShadow(
            color: _kBordoTokenSelezionato,
            spreadRadius: t * 4,
            blurRadius: t * 3,
          ),
      ];

  Widget _buildAbsoluteToken(
    String roleLabel,
    Player player,
    Offset center,
    double radius, {
    bool isLibero = false,
    VoidCallback? onTap,
    bool disabilitato = false,
  }) {
    final fillColor = isLibero
        ? _invertedColor(Color(widget.team.coloreDivisa))
        : Color(widget.team.coloreDivisa);
    final label = _showJerseyNumbers
        ? '${player.numero}'
        : siglaRuolo(roleLabel, AppLocalizations.of(context));
    final selezionato = _votoInCorso?.giocatore.id == player.id;
    final tokenVisual = _tokenConBordoAnimato(
      selezionato,
      (t) => Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fillColor,
          border: Border.all(
              color: Color.lerp(Colors.white, _kBordoTokenSelezionato, t)!,
              width: 2),
          boxShadow: _ombreTokenSelezione(t),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: contrastingTextColor(fillColor),
            fontWeight: FontWeight.bold,
            fontSize: radius * 0.7,
          ),
        ),
      ),
    );
    return AnimatedPositioned(
      key: ValueKey(player.id),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      left: center.dx - radius,
      top: center.dy - radius,
      width: radius * 2,
      height: radius * 2,
      child: _anchorSe(
        isLibero,
        TutorialTarget.tokenLibero,
        disabilitato
            ? Opacity(opacity: _kAlphaTokenBloccato, child: tokenVisual)
            : (onTap == null
                ? tokenVisual
                : _tokenConTrascinamento(onTap, player.id, tokenVisual)),
      ),
    );
  }

  Widget _buildPlayerToken(
    String roleLabel,
    Player player,
    Offset refPos,
    double cw,
    double ch, {
    VoidCallback? onTap,
    bool disabilitato = false,
  }) {
    // Raggio = un ventesimo del campo (singolo campo = quadrato 600×600 nello
    // spazio di riferimento, quindi un ventesimo equivale a ch/20), scalato
    // da _kTokenSizeScale.
    final radius = ch / 20 * _kTokenSizeScale;
    final cx = (refPos.dx / 1200) * cw;
    final cy = (refPos.dy / 600) * ch;
    final fillColor = Color(widget.team.coloreDivisa);
    // Esagono per il palleggiatore: 'P' nel 5-1, 'P1'/'P2' nel 6-2 (entrambi
    // i palleggiatori).
    final isPalleggiatore =
        roleLabel == 'P' || roleLabel == 'P1' || roleLabel == 'P2';
    final label = _showJerseyNumbers
        ? '${player.numero}'
        : siglaRuolo(roleLabel, AppLocalizations.of(context));
    // L'esagono del palleggiatore è il 10% più grande dei token circolari.
    final tokenRadius = isPalleggiatore ? radius * 1.1 : radius;

    final text = Text(
      label,
      style: TextStyle(
        color: contrastingTextColor(fillColor),
        fontWeight: FontWeight.bold,
        fontSize: radius * 0.7,
      ),
    );

    final selezionato = _votoInCorso?.giocatore.id == player.id;
    final tokenVisual = _tokenConBordoAnimato(
      selezionato,
      (t) => isPalleggiatore
          ? CustomPaint(
              painter: _RoundedHexagonPainter(
                fillColor,
                bordoColor: Color.lerp(Colors.white, _kBordoTokenSelezionato, t)!,
                bordoWidth: 2 + t * 3,
              ),
              child: Center(child: text),
            )
          : Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fillColor,
                border: Border.all(
                    color: Color.lerp(Colors.white, _kBordoTokenSelezionato, t)!,
                    width: 2),
                boxShadow: _ombreTokenSelezione(t),
              ),
              child: text,
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
      child: _anchorOpz(
        targetRuoloNostro(roleLabel),
        disabilitato
            ? Opacity(opacity: _kAlphaTokenBloccato, child: tokenVisual)
            : (onTap == null
                ? tokenVisual
                : _tokenConTrascinamento(onTap, player.id, tokenVisual)),
      ),
    );
  }

  // Token placeholder della squadra AVVERSARIA sulla metà campo opposta: 6
  // cerchi grigi per ruolo (P/O/S1/S2/C1/C2) derivati dallo slot del loro
  // palleggiatore (`_statoSetReale.palleggiatoreAvversarioSlot`) in un 5-1
  // canonico (`etichetteAvversarie`). Posizioni TATTICHE (come le nostre):
  // ogni ruolo va dove le tabelle attacco/difesa lo schierano nella fase
  // corrente (`_posizioneAvversario` → `_mappaAvversario`, specchiate sulla
  // loro metà), non nella zona di rotazione fissa — così la traiettoria
  // disegnata parte davvero dal token toccato. Fallback alla zona
  // (`_kOpponentZonePositions`) solo se la mappa non copre un ruolo. Vuoto se
  // lo scout avversari non è attivo per il set, in modalità test o durante la
  // selezione della zona iniziale.
  List<Widget> _buildTokenAvversari(double cw, double ch) {
    if (_testModeEnabled || _inSelezionePAvversario) return const [];
    final slot = _statoSetReale?.palleggiatoreAvversarioSlot;
    if (slot == null) return const [];
    final etichette = etichetteAvversarie(slot); // zona -> ruolo
    final zonaPerRuolo = {for (final e in etichette.entries) e.value: e.key};
    final ruoloBattitore = etichette[1]!; // ruolo in zona 1 = battitore
    final radius = ch / 20 * _kTokenSizeScale;
    final attesaBattuta = _attesaBattutaAvversaria;
    final attesaRicezione = _attesaRicezioneAvversaria;
    final faseLibera = _faseLiberaScambio;
    // Attenuazione per SQUADRA in base alla fase (vedi _avversariInAttesa): i
    // loro token si attenuano quando l'avversario è la squadra "in attesa"
    // (nostro servizio/ricezione, o dopo un `#` avversario).
    final bloccati = _avversariInAttesa;
    return [
      for (final entry in etichette.entries)
        () {
          final ruolo = entry.value;
          final battitore = ruolo == ruoloBattitore;
          // Posizione tattica (mirror sulla loro metà), fallback alla zona.
          // Durante la loro battuta il battitore è già fuori campo nella mappa
          // (X<0 → mirror X>1200), come il nostro P1.
          final refBase = _posizioneAvversario(ruolo, zonaPerRuolo[ruolo]!);
          // Tappabilità per fase:
          // - attesa battuta: il battitore è fuori campo → il suo tap lo
          //   cattura _buildBattitoreAvversarioTapCatcher (Stack esterno), qui
          //   onTap null; gli altri token nessuno;
          // - attesa ricezione (battiamo noi): tutti tappabili, forzati su
          //   Ricezione;
          // - fase libera: tutti tappabili, fondamentale a scelta
          //   (Attacco/Muro/Difesa nel pannello);
          // - resto (nostro servizio, nostra ricezione): nessuno.
          final VoidCallback? onTap;
          if (attesaBattuta && battitore) {
            onTap = null;
          } else if (attesaRicezione) {
            onTap = _tapHandlerAvversario(ruolo,
                forzato: Fondamentale.ricezione);
          } else if (faseLibera) {
            onTap = _tapHandlerAvversario(ruolo, zona: zonaPerRuolo[ruolo]!);
          } else {
            onTap = null;
          }
          return _buildTokenAvversario(ruolo, refBase, radius, cw, ch,
              onTap: onTap, disabilitato: bloccati);
        }(),
    ];
  }

  Widget _buildTokenAvversario(
    String roleLabel,
    Offset refBase,
    double radius,
    double cw,
    double ch, {
    VoidCallback? onTap,
    bool disabilitato = false,
  }) {
    final refPos = _displayPosition(refBase);
    final cx = (refPos.dx / 1200) * cw;
    final cy = (refPos.dy / 600) * ch;
    final isPalleggiatore = roleLabel == 'P';
    final tokenRadius = isPalleggiatore ? radius * 1.1 : radius;

    final text = Text(
      siglaRuolo(roleLabel, AppLocalizations.of(context)),
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: radius * 0.7,
      ),
    );

    final selezionato = _avversarioInCorso?.ruolo == roleLabel;
    final tokenVisual = _tokenConBordoAnimato(
      selezionato,
      (t) => isPalleggiatore
          ? CustomPaint(
              painter: _RoundedHexagonPainter(
                _kColoreTokenAvversario,
                bordoColor: Color.lerp(Colors.white, _kBordoTokenSelezionato, t)!,
                bordoWidth: 2 + t * 3,
              ),
              child: Center(child: text),
            )
          : Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kColoreTokenAvversario,
                border: Border.all(
                    color: Color.lerp(Colors.white, _kBordoTokenSelezionato, t)!,
                    width: 2),
                boxShadow: _ombreTokenSelezione(t),
              ),
              child: text,
            ),
    );

    // Key = etichetta di ruolo (l'avversario non ha id giocatore): quando la
    // rotazione sposta un ruolo da una zona all'altra, AnimatedPositioned lo
    // anima invece di teletrasportarlo — come i nostri token.
    return AnimatedPositioned(
      key: ValueKey('avv-$roleLabel'),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      left: cx - tokenRadius,
      top: cy - tokenRadius,
      width: tokenRadius * 2,
      height: tokenRadius * 2,
      child: _anchorOpz(
        targetRuoloAvversario(roleLabel),
        disabilitato
            ? Opacity(opacity: _kAlphaTokenBloccato, child: tokenVisual)
            : (onTap == null
                ? tokenVisual
                : _tokenConTrascinamento(onTap, roleLabel, tokenVisual)),
      ),
    );
  }
}

/// Disegna la freccia della traiettoria in-line leggendola da un
/// `ValueNotifier`, passato anche come `repaint`: così il tratto segue il dito
/// ridisegnando SOLO questo layer, senza un `setState` — e quindi senza
/// ricostruire campo, token, log e pannello — a ogni frame del trascinamento.
///
/// Il disegno vero è quello condiviso con `TrajectoryScreen`
/// (`FrecciaTraiettoriaPainter`), qui solo delegato: una copia sola, così le
/// due strade non divergono mentre le si confronta.
class _FrecciaLivePainter extends CustomPainter {
  final ValueNotifier<
      ({Offset inizio, Offset fine, Offset? muro, bool inZonaRete})?> freccia;

  /// Geometria del riquadro campo, per la riga sulla rete: `xRete` è la sua
  /// ascissa, `cimaCampo`/`altezzaCampo` la sua estensione verticale.
  final double xRete;
  final double cimaCampo;
  final double altezzaCampo;

  _FrecciaLivePainter(
    this.freccia, {
    required this.xRete,
    required this.cimaCampo,
    required this.altezzaCampo,
  }) : super(repaint: freccia);

  @override
  void paint(Canvas canvas, Size size) {
    final f = freccia.value;
    if (f == null) return;
    // Riga sulla rete: "sei nella fascia, resta fermo un attimo e lo snodo si
    // fissa qui". Stesso segnale visivo di TrajectoryScreen; sparisce appena
    // il tocco a muro scatta (da lì in poi parla lo snodo della freccia) o se
    // si esce dalla fascia prima che il soffermamento maturi.
    if (f.inZonaRete) {
      canvas.drawLine(
        Offset(xRete, cimaCampo),
        Offset(xRete, cimaCampo + altezzaCampo),
        Paint()
          ..color = AppColors.brandAccent
          ..strokeWidth = 10,
      );
    }
    FrecciaTraiettoriaPainter(f.inizio, f.fine, f.muro).paint(canvas, size);
  }

  // Il ridisegno del TRATTO lo governa `repaint`; qui restano solo i valori
  // che cambiano a ogni build (geometria del campo, stato del muro).
  @override
  bool shouldRepaint(covariant _FrecciaLivePainter oldDelegate) =>
      oldDelegate.freccia != freccia ||
      oldDelegate.xRete != xRete ||
      oldDelegate.cimaCampo != cimaCampo ||
      oldDelegate.altezzaCampo != altezzaCampo;
}

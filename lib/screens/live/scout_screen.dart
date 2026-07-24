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
import '../../theme/court_style.dart';
import '../../widgets/premium_badge.dart';
import '../premium/paywall_screen.dart';
import '../report/match_report_screen.dart';
import '../report/player_stats_screen.dart';
import '../report/trajectory_report_screen.dart';
import 'end_set_screen.dart';
import 'sostituzione_screen.dart';
import 'tactical_board_screen.dart';
import 'trajectory_screen.dart';

const _kBg = Color(0xFF143E59);
const _kTopBarBg = Color(0xFF0D2738);
const _kCourtImage = 'assets/images/double_court_bg.png';
const _kSmallCourtImage = 'assets/images/small_court.png';

// Margine fisso tra il bordo superiore dell'area di gioco (sotto banner/
// bottoni rapidi) e il campo grande — il campo non è più centrato
// verticalmente nello spazio rimanente, ma ancorato in alto a questa
// distanza. Stesso valore usato per calcolare `courtTop` in
// _buildLiberoSwapTokens/_buildBattitoreTapCatcher (Stack esterno,
// coordinate schermo assolute): deve restare identico a quello passato a
// `Positioned(top: ...)` nel campo vero, altrimenti libero/battitore fuori
// campo si disallineano dal campo disegnato.
const double _kCourtTopMargin = 16.0;

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

// Posizioni delle 6 zone AVVERSARIE (metà campo opposta): la riflessione delle
// nostre attraverso il centro del campo doppio (1200-x, 600-y). La zona 1
// avversaria è diagonalmente opposta alla nostra (i due angoli di battuta sono
// sempre in diagonale) — usata dalla selezione sul campo del palleggiatore
// avversario a inizio set e, in seguito, dai token placeholder avversari.
// Passa comunque per _displayPosition() come le nostre, così segue il cambio
// campo restando sempre sul lato opposto ai nostri token.
const Map<int, Offset> _kOpponentZonePositions = {
  1: Offset(1000, 130),
  2: Offset(670, 130),
  3: Offset(670, 300),
  4: Offset(670, 470),
  5: Offset(1000, 470),
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
const Offset _kBattutaP1Position = Offset(-70, 470);

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

  // Giocatore + fondamentale per cui è aperto il pannello di voto — null =
  // pannello chiuso. `fondamentale` è null quando il giocatore è stato
  // toccato in fase "libera" (dopo battuta/ricezione già giudicate): in quel
  // caso il pannello mostra prima la scelta tra Alzata/Attacco/Muro/Difesa
  // (vedi _sceglieFondamentale), altrimenti è già forzato da
  // _fondamentaleForzato (battuta/ricezione). Tap sul giocatore (vedi
  // _tapHandlerPerGiocatore) lo apre; la selezione di un voto (_registraVoto)
  // lo richiude.
  ({Player giocatore, Fondamentale? fondamentale})? _votoInCorso;

  // Azione AVVERSARIA in corso: ruolo placeholder toccato (P/O/S1/S2/C1/C2) +
  // fondamentale scelto (null finché non si sceglie Attacco/Battuta/Muro nel
  // pannello). Flusso parallelo e ISOLATO da _votoInCorso (legato a un nostro
  // Player): l'avversario non ha roster, solo il ruolo. Vedi
  // _tapHandlerAvversario/_buildPannelloAvversario/_registraVotoAvversario.
  ({String ruolo, Fondamentale? fondamentale})? _avversarioInCorso;

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
    setState(() => _votoInCorso = null);
  }

  // Tap-target per il voto di un giocatore: fuori dalla modalità test, col
  // set già iniziato e questo slot tappabile nella fase corrente (vedi
  // _giocatoreTappabile). `slot` è null per il libero (nessuno slot P1-P6
  // proprio).
  VoidCallback? _tapHandlerPerGiocatore(Player player, {String? slot}) {
    if (_testModeEnabled) return null;
    if (_setCorrente == null) return null;
    if (_avversarioInCorso != null) return null; // pannello avversario aperto
    // Dopo un NOSTRO `#`: deve difendere l'avversario, i nostri token bloccati.
    if (_nostriTokenBloccati) return null;
    if (!_giocatoreTappabile(slot)) return null;
    // Scorciatoia dopo un `#` avversario:
    // - ace (battuta `#`): la risposta è solo ricezione → `=` diretto, senza
    //   pannello;
    // - kill (attacco `#`): la risposta può essere muro O difesa → apri il
    //   pannello ristretto (Muro/Difesa in rosso → `=`, vedi
    //   _buildSceltaFondamentale con _difesaErroreForzataNostra).
    final erroreForzato = _erroreDifensivoForzato(Squadra.nostra);
    if (erroreForzato == Fondamentale.ricezione) {
      return () => _registraErroreDifensivoRapido(player, erroreForzato!);
    }
    if (erroreForzato == Fondamentale.difesa) {
      return () =>
          setState(() => _votoInCorso = (giocatore: player, fondamentale: null));
    }
    final forzato = _fondamentaleForzato();
    return () => setState(() {
      _votoInCorso = (giocatore: player, fondamentale: forzato);
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

  // Sceglie il fondamentale (Alzata/Attacco/Muro/Difesa) per il giocatore già
  // selezionato in fase "libera" (_votoInCorso.fondamentale == null) — tap su
  // uno dei 4 bottoni del pannello, vedi _buildSceltaFondamentale.
  void _sceglieFondamentale(Fondamentale fondamentale) {
    final inCorso = _votoInCorso;
    if (inCorso == null) return;
    setState(() {
      _votoInCorso = (giocatore: inCorso.giocatore, fondamentale: fondamentale);
    });
  }

  // Tipo di battuta opzionale, scelto su TrajectoryScreen (riga di chip
  // orizzontale sotto al campo, non più nel pannello voto qui) — passato
  // come valore iniziale alla navigazione e riletto dal risultato al
  // ritorno (vedi _registraVoto). nonSpecificato di default, non bloccante
  // per il flusso veloce. Vedi _tapHandlerPerGiocatore per quando si azzera.
  TipoBattuta _tipoBattutaSelezionato = TipoBattuta.nonSpecificato;
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

  Future<void> _registraVoto(Voto voto) async {
    final set = _setCorrente;
    final inCorso = _votoInCorso;
    final fondamentale = inCorso?.fondamentale;
    if (set == null || inCorso == null || fondamentale == null) return;
    final esito = _esitoVoto(fondamentale, voto);

    // Solo battuta/attacco chiedono la traiettoria — schermata dedicata,
    // niente bottoni "salta"/"conferma": il back la salta (registra
    // comunque un risultato, solo senza coordinate — vedi TrajectoryScreen),
    // il rilascio del drag la conferma subito. Per la battuta,
    // TrajectoryScreen mostra anche la scelta del tipo (sotto al campo,
    // spostata qui dal pannello voto): si passa il valore "armato" attuale
    // come iniziale e si rilegge quello (eventualmente cambiato) dal
    // risultato, per restare "armato" anche tra una traiettoria e l'altra.
    // Con le traiettorie disattivate nelle Impostazioni si salta la
    // schermata: azione registrata subito con coordinate null (stesso
    // percorso del "salta"). Nota: anche la scelta del tipo battuta/attacco
    // vive su TrajectoryScreen, quindi resta 'nonSpecificato' — accettato
    // per ora (flusso ultra-veloce), eventuale rientro dei chip nel
    // pannello voto da valutare in futuro.
    // GATE PREMIUM: per un utente free le traiettorie sono spente a
    // prescindere dal toggle (come se fosse disabilitato) — dopo il voto si
    // procede subito, nessun paywall in mezzo alla presa dati (il paywall
    // compare solo dalle voci di menu/report, azioni deliberate).
    Traiettoria? traiettoria;
    if (fondamentale.richiedeTraiettoria &&
        ref.read(impostazioniProvider).traiettorieAbilitate &&
        ref.read(statoPremiumProvider).attivo) {
      traiettoria = await Navigator.push<Traiettoria>(
        context,
        MaterialPageRoute(
          builder: (_) => TrajectoryScreen(
            giocatore: inCorso.giocatore,
            fondamentale: fondamentale,
            voto: voto,
            tipoBattutaIniziale: fondamentale == Fondamentale.battuta
                ? _tipoBattutaSelezionato
                : null,
          ),
        ),
      );
      if (!mounted) return;
      if (fondamentale == Fondamentale.battuta && traiettoria != null) {
        _tipoBattutaSelezionato = traiettoria.tipoBattuta;
      }
    }

    final tipoEsecuzione = switch (fondamentale) {
      Fondamentale.battuta => _tipoBattutaSelezionato.name,
      Fondamentale.attacco =>
        (traiettoria?.tipoAttacco ?? TipoAttacco.nonSpecificato).name,
      _ => 'nonSpecificato',
    };

    await ref
        .read(scoutActionRepositoryProvider)
        .registraAzioneScout(
          setId: set.id,
          squadra: Squadra.nostra,
          giocatoreId: inCorso.giocatore.id,
          fondamentale: fondamentale,
          voto: voto,
          esitoPunto: esito,
          tipoEsecuzione: tipoEsecuzione,
          traiettoriaX1: traiettoria?.x1,
          traiettoriaY1: traiettoria?.y1,
          traiettoriaX2: traiettoria?.x2,
          traiettoriaY2: traiettoria?.y2,
          traiettoriaMuroX: traiettoria?.muroX,
          traiettoriaMuroY: traiettoria?.muroY,
        );
    if (!mounted) return;
    setState(() {
      _votoInCorso = null;
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
    setState(() => _avversarioInCorso = null);
  }

  // Tap su un token avversario: apre il pannello avversario (scelta
  // fondamentale poi voto). Disabilitato in modalità test, prima dell'inizio
  // del set, durante la selezione della zona iniziale, o col nostro pannello
  // voto già aperto (i due flussi sono mutuamente esclusivi).
  VoidCallback? _tapHandlerAvversario(String ruolo, {Fondamentale? forzato}) {
    if (_testModeEnabled) return null;
    if (_setCorrente == null) return null;
    if (_inSelezionePAvversario) return null;
    if (_votoInCorso != null) return null;
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
      return () => setState(
          () => _avversarioInCorso = (ruolo: ruolo, fondamentale: null));
    }
    return () => setState(
        () => _avversarioInCorso = (ruolo: ruolo, fondamentale: forzato));
  }

  void _scegliFondamentaleAvversario(Fondamentale fondamentale) {
    final inCorso = _avversarioInCorso;
    if (inCorso == null) return;
    setState(() =>
        _avversarioInCorso = (ruolo: inCorso.ruolo, fondamentale: fondamentale));
  }

  Future<void> _registraVotoAvversario(Voto voto) async {
    final set = _setCorrente;
    final inCorso = _avversarioInCorso;
    final fondamentale = inCorso?.fondamentale;
    if (set == null || inCorso == null || fondamentale == null) return;
    final esito = _esitoVotoAvversario(fondamentale, voto);

    // Traiettoria per battuta/attacco avversari — stesso flusso del nostro
    // _registraVoto (gate traiettorie + premium). TrajectoryScreen disegna
    // sulla stessa immagine campo doppio: il drag parte dal token avversario
    // (loro metà) verso la nostra. `giocatore` è null, si passa l'etichetta
    // di ruolo per il banner. Il tipo battuta/attacco NON resta "armato" per
    // l'avversario (nessun roster): parte sempre da nonSpecificato.
    Traiettoria? traiettoria;
    if (fondamentale.richiedeTraiettoria &&
        ref.read(impostazioniProvider).traiettorieAbilitate &&
        ref.read(statoPremiumProvider).attivo) {
      traiettoria = await Navigator.push<Traiettoria>(
        context,
        MaterialPageRoute(
          builder: (_) => TrajectoryScreen(
            etichettaAvversario: inCorso.ruolo,
            fondamentale: fondamentale,
            voto: voto,
            tipoBattutaIniziale: fondamentale == Fondamentale.battuta
                ? TipoBattuta.nonSpecificato
                : null,
          ),
        ),
      );
      if (!mounted) return;
    }

    final tipoEsecuzione = switch (fondamentale) {
      Fondamentale.battuta =>
        (traiettoria?.tipoBattuta ?? TipoBattuta.nonSpecificato).name,
      Fondamentale.attacco =>
        (traiettoria?.tipoAttacco ?? TipoAttacco.nonSpecificato).name,
      _ => 'nonSpecificato',
    };

    await ref.read(scoutActionRepositoryProvider).registraAzioneAvversaria(
          setId: set.id,
          ruoloAvversario: inCorso.ruolo,
          fondamentale: fondamentale,
          voto: voto,
          esitoPunto: esito,
          tipoEsecuzione: tipoEsecuzione,
          traiettoriaX1: traiettoria?.x1,
          traiettoriaY1: traiettoria?.y1,
          traiettoriaX2: traiettoria?.x2,
          traiettoriaY2: traiettoria?.y2,
          traiettoriaMuroX: traiettoria?.muroX,
          traiettoriaMuroY: traiettoria?.muroY,
        );
    if (!mounted) return;
    // La fase (_fondamentaleGiudicatoRallyCorrente/_attesaBattutaAvversaria) è
    // derivata dallo stream: si aggiorna da sola con la nuova azione.
    setState(() => _avversarioInCorso = null);
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
        : 'Avversari';

    final scelta = await showDialog<Squadra>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Chi serve per primo?'),
        content: const Text(
          'Indica quale squadra è al servizio per iniziare il set.',
        ),
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
        : 'AVVERSARI';
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
    });
  }

  // Undo: attivo solo col set iniziato, fuori dalla modalità test (che non
  // scrive azioni reali) e con almeno un'azione da annullare.
  bool get _puoAnnullare =>
      !_testModeEnabled && _setCorrente != null && _ultimaAzione != null;

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
        title: const Text(
          'Annullare l\'ultima azione?',
          style: TextStyle(fontSize: 14),
        ),
        content: Text(
          testoAzione,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Conferma'),
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
    setState(() => _votoInCorso = null);
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
        const SnackBar(
          content: Text(
            'Sostituzione non valida: un giocatore comparirebbe due '
            'volte in campo',
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
    setState(() => _votoInCorso = null);
  }

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // actionId → "Rotazione P{iniziale} → P{finale}" per ogni correzione
  // rotazione del set, ricalcolata a ogni build (vedi _computeLabelsCorrezione)
  // e letta da _descrizioneAzione per banner e log azioni — così ogni voce
  // mostra la rotazione al SUO momento, non quella attuale.
  Map<int, String> _labelsCorrezione = const {};

  @override
  Widget build(BuildContext context) {
    _labelsCorrezione = _computeLabelsCorrezione();
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
                          IconButton(
                            icon: const Icon(Icons.menu, color: Colors.white),
                            onPressed: () =>
                                _scaffoldKey.currentState?.openDrawer(),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.undo, color: Colors.white),
                            onPressed: _puoAnnullare
                                ? _confermaAnnullaUltimaAzione
                                : null,
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
                      _buildBottoniAvversario(),
                      _bannerCentrale(),
                      _buildBottoniNostri(),
                    ]
                  : [
                      _buildBottoniNostri(),
                      _bannerCentrale(),
                      _buildBottoniAvversario(),
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
                                    Image.asset(
                                      _kCourtImage,
                                      fit: BoxFit.contain,
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
                      child: GestureDetector(
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
                        child: Row(
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
                    ..._buildLiberoSwapTokens(constraints, courtWidth),
                    ..._buildBattitoreTapCatcher(constraints, courtWidth),
                    ..._buildBattitoreAvversarioTapCatcher(
                        constraints, courtWidth),
                    ..._buildSelezionePAvversario(constraints, courtWidth),
                    ..._buildActionLog(),
                    ..._buildPannelloVoto(),
                    ..._buildPannelloAvversario(),
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
    return Drawer(
      backgroundColor: _kBg,
      child: SafeArea(
        // ListView, non Column: su smartphone (schermo basso) le voci non
        // ci stanno tutte in altezza e la Column sborderebbe — così il
        // drawer scrolla. Su tablet non cambia nulla.
        child: ListView(
          padding: EdgeInsets.zero,
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
              title: const Text(
                'Cambia campo',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                _toggleSide();
                _scaffoldKey.currentState?.closeDrawer();
              },
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
                'Sostituzione',
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
              title: const Text(
                'Lavagna tattica',
                style: TextStyle(color: Colors.white),
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
              title: const Text(
                'Statistiche fondamentali',
                style: TextStyle(color: Colors.white),
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
              title: const Text(
                'Report',
                style: TextStyle(color: Colors.white),
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
              title: const Text(
                'Traiettorie battute',
                style: TextStyle(color: Colors.white),
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
              title: const Text(
                'Traiettorie attacco',
                style: TextStyle(color: Colors.white),
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
                _showJerseyNumbers ? 'Mostra ruoli' : 'Mostra numeri',
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
                title: const Text(
                  'Modalità test',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Bottone visualizzazione rotazioni',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                activeThumbColor: Colors.white,
                activeTrackColor: const Color(0xFF00008A),
                inactiveThumbColor: Colors.white70,
                inactiveTrackColor: Colors.white24,
              ),
            SwitchListTile(
              value: _showActionLog,
              onChanged: (v) => setState(() => _showActionLog = v),
              title: const Text(
                'Log azioni',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Lista delle azioni del set corrente',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              activeThumbColor: Colors.white,
              activeTrackColor: const Color(0xFF00008A),
              inactiveThumbColor: Colors.white70,
              inactiveTrackColor: Colors.white24,
            ),
            const Divider(color: Colors.white24, height: 1),
            ListTile(
              leading: const Icon(Icons.sports_score, color: Colors.white),
              title: const Text('Fine', style: TextStyle(color: Colors.white)),
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
              title: const Text(
                'Indietro',
                style: TextStyle(color: Colors.white),
              ),
              // Il Drawer registra una "local history entry" sulla route:
              // mentre è aperto, Navigator.pop(context) chiude SOLO il
              // drawer (consuma quella entry) invece di tornare alla
              // schermata precedente. Si cattura il Navigator prima di
              // chiudere il drawer esplicitamente, poi si fa il pop vero
              // sul Navigator catturato.
              onTap: () {
                final navigator = Navigator.of(context);
                _scaffoldKey.currentState?.closeDrawer();
                navigator.pop();
              },
            ),
          ],
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
        child: Container(
          padding: EdgeInsets.all(sc(5, 8)),
          decoration: BoxDecoration(
            color: _kTopBarBg.withAlpha(235),
            borderRadius: BorderRadius.circular(sc(6, 8)),
            border: Border.all(color: Colors.white24),
          ),
          child: righe.isEmpty
              ? Center(
                  child: Text(
                    'Nessuna azione',
                    style:
                        TextStyle(color: Colors.white54, fontSize: sc(10, 12)),
                  ),
                )
              : ListView.builder(
                  itemCount: righe.length,
                  itemBuilder: (context, i) {
                    final a = righe[righe.length - 1 - i]; // recente in alto
                    final desc = _descrizioneAzione(a);
                    // Il blu brand del "Cambio" è illeggibile sul fondo
                    // scuro del pannello: solo qui si schiarisce.
                    final coloreTesto = desc.colore == AppColors.brandPrimary
                        ? Colors.lightBlueAccent
                        : desc.colore;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${a.ordine}·r${numeroRally[a.rallyId]}  ',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: sc(10, 13),
                              ),
                            ),
                            TextSpan(
                              text: desc.testo,
                              style: TextStyle(
                                // Per punto/errore/cambio (voto assente) il
                                // colore semantico va sul testo; per i voti
                                // resta sul solo simbolo, più leggibile.
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
                    );
                  },
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
        testo: '${player.numero} - ${player.cognome} - ${fondamentale.label}',
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
        testo: 'Avv ${azione.ruoloAvversario} - ${fondamentale.label}',
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
        testo: _labelsCorrezione[azione.id] ?? 'Rotazione corretta',
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
        testo = '$testo - ${motivo.label}';
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
  Widget _bannerCentrale() {
    final banner = _buildBannerUltimaAzione();
    return Expanded(
      child: banner == null
          ? const SizedBox.shrink()
          : FittedBox(fit: BoxFit.scaleDown, child: banner),
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
  Widget _buildScoreDisplay(int score, Squadra squadra) {
    final attivo = _bottoniRapidiAttivi;
    return Row(
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
          child: Text(
            '$score',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _buildScoreAdjustButton(
          Icons.add,
          attivo ? () => _correggiPunteggio(squadra, 1) : null,
        ),
      ],
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
    ];
    final timeout = _buildTimeoutButton(Squadra.nostra);
    const gap = SizedBox(width: _kTimeoutGap);
    return Row(
      mainAxisSize: MainAxisSize.min,
      // Gruppo a sinistra (default): timeout in coda; coi lati invertiti il
      // gruppo va a destra e il timeout passa in testa — resta verso il
      // centro in entrambi i casi.
      children: _isRightSide
          ? [timeout, gap, ...base]
          : [...base, gap, timeout],
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
    return _buildQuickActionButton(
      icon: Icons.access_time,
      color: AppColors.brandPrimary,
      onTap: _bottoniRapidiAttivi && _timeoutChiamati(squadra) < 2
          ? () => _timeout(squadra)
          : null,
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
          PopupMenuItem(value: motivo, child: Text(motivo.label)),
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

  // Bottoni di scelta del fondamentale (Alzata/Attacco/Muro/Difesa), mostrati
  // nel pannello voto quando _votoInCorso.fondamentale è ancora null (fase
  // "libera", dopo che battuta/ricezione sono già state giudicate in questo
  // scambio) — vedi _sceglieFondamentale.
  Widget _buildSceltaFondamentale(Player giocatore) {
    const opzioni = [
      Fondamentale.alzata,
      Fondamentale.attacco,
      Fondamentale.muro,
      Fondamentale.difesa,
    ];
    final ristretto = _difesaErroreForzataNostra;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final f in opzioni) ...[
          _buildBottoneFondamentale(
            fondamentale: f,
            ristretto: ristretto,
            onNormale: () => _sceglieFondamentale(f),
            onErroreDifensivo: () => _registraErroreDifensivoRapido(giocatore, f),
          ),
          if (f != opzioni.last) const SizedBox(height: 10),
        ],
      ],
    );
  }

  // Bottone del pannello scelta-fondamentale, condiviso tra pannello nostro e
  // avversario. In modalità normale (`ristretto == false`) tutti abilitati
  // (blu) → `onNormale` sceglie il fondamentale. In modalità "errore difensivo
  // ristretto" (dopo un `#` di attacco dell'altra squadra) SOLO Muro/Difesa
  // sono abilitati e rossi → `onErroreDifensivo` registra subito quel
  // fondamentale con voto `=`; Alzata/Attacco sono grigi e disabilitati.
  Widget _buildBottoneFondamentale({
    required Fondamentale fondamentale,
    required bool ristretto,
    required VoidCallback onNormale,
    required VoidCallback onErroreDifensivo,
  }) {
    final difensivo = fondamentale == Fondamentale.muro ||
        fondamentale == Fondamentale.difesa;
    final abilitato = !ristretto || difensivo;
    final rosso = ristretto && difensivo;
    final colore = !abilitato
        ? AppColors.neutral
        : (rosso ? Colors.red : AppColors.brandPrimary);
    return Opacity(
      opacity: abilitato ? 1.0 : 0.4,
      child: GestureDetector(
        onTap: !abilitato
            ? null
            : (ristretto ? onErroreDifensivo : onNormale),
        child: Container(
          width: 150,
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colore,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(120),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            fondamentale.label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
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

    return [
      // Tap fuori dal pannello = annulla. Lo Stack ferma la ricerca del
      // tocco al primo figlio che lo "reclama" (vedi GestureDetector del
      // pannello sotto, che lo assorbe con un onTap no-op): quindi un tap
      // sul pannello non arriva mai qui, solo un tap altrove sullo schermo.
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _votoInCorso = null),
        ),
      ),
      Positioned(
        right: 16,
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
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {}, // assorbe il tap, non deve propagarsi allo sfondo
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 12,
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
                      width: 100,
                      child: Column(
                        children: [
                          Text(
                            '${player.numero}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                            ),
                          ),
                          Text(
                            player.cognome,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (inCorso.fondamentale == null) ...[
                      const SizedBox(height: 4),
                      _buildSceltaFondamentale(player),
                    ] else ...[
                      Text(
                        inCorso.fondamentale!.label,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final voto in Voto.values) ...[
                        GestureDetector(
                          onTap: () => _registraVoto(voto),
                          child: Container(
                            width: 100,
                            height: 64,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: CourtStyle.votoColor(voto),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(120),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              voto.simbolo,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 28,
                              ),
                            ),
                          ),
                        ),
                        if (voto != Voto.values.last)
                          const SizedBox(height: 12),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ];
  }

  // Pannello per un'azione AVVERSARIA: si apre toccando un token avversario
  // (vedi _tapHandlerAvversario). Stessa struttura/stile di _buildPannelloVoto
  // (scrim + card a destra), ma header col RUOLO placeholder (niente giocatore)
  // e — non essendoci una fase forzata — chiede SEMPRE prima il fondamentale
  // tra Attacco/Battuta/Muro, poi il voto (esito invertito, vedi
  // _registraVotoAvversario). Ritorna [] se chiuso.
  List<Widget> _buildPannelloAvversario() {
    final inCorso = _avversarioInCorso;
    if (inCorso == null) return const [];

    return [
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _avversarioInCorso = null),
        ),
      ),
      Positioned(
        right: 16,
        top: 4,
        bottom: 4,
        child: Align(
          alignment: Alignment.topCenter,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 12,
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
                      width: 100,
                      child: Column(
                        children: [
                          const Text(
                            'Avversario',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            inCorso.ruolo,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (inCorso.fondamentale == null) ...[
                      const SizedBox(height: 8),
                      // In fase libera l'avversario può aver attaccato, murato o
                      // difeso (battuta e ricezione passano dai flussi forzati
                      // di zona 1 / fase ricezione, non da qui). Dopo un NOSTRO
                      // `#` di attacco il pannello è ristretto a Muro/Difesa in
                      // rosso (→ `=` diretto, vedi _difesaErroreForzataAvversaria).
                      for (final f in const [
                        Fondamentale.attacco,
                        Fondamentale.muro,
                        Fondamentale.difesa,
                      ]) ...[
                        _buildBottoneFondamentale(
                          fondamentale: f,
                          ristretto: _difesaErroreForzataAvversaria,
                          onNormale: () => _scegliFondamentaleAvversario(f),
                          onErroreDifensivo: () =>
                              _registraErroreDifensivoAvversarioRapido(
                                  inCorso.ruolo, f),
                        ),
                        if (f != Fondamentale.difesa)
                          const SizedBox(height: 10),
                      ],
                    ] else ...[
                      Text(
                        inCorso.fondamentale!.label,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final voto in Voto.values) ...[
                        GestureDetector(
                          onTap: () => _registraVotoAvversario(voto),
                          child: Container(
                            width: 100,
                            height: 64,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: CourtStyle.votoColor(voto),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(120),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              voto.simbolo,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 28,
                              ),
                            ),
                          ),
                        ),
                        if (voto != Voto.values.last)
                          const SizedBox(height: 12),
                      ],
                    ],
                  ],
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
    final roleLabels = roleLabelsFor(_currentSlot, currentAssignments);
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
    final roleLabels = roleLabelsFor(_currentSlot, currentAssignments);
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

    final roleLabels = roleLabelsFor(_currentSlot, _currentAssignments);
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
        child: GestureDetector(onTap: onTap),
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
        child: GestureDetector(onTap: onTap),
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
            child: const Text(
              'Tocca la zona del palleggiatore avversario',
              style: TextStyle(
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
    final label = _showJerseyNumbers ? '${player.numero}' : roleLabel;
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
      child: disabilitato
          ? Opacity(opacity: _kAlphaTokenBloccato, child: tokenVisual)
          : (onTap == null
              ? tokenVisual
              : GestureDetector(onTap: onTap, child: tokenVisual)),
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
    final isPalleggiatore = roleLabel == 'P';
    final label = _showJerseyNumbers ? '${player.numero}' : roleLabel;
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
      child: disabilitato
          ? Opacity(opacity: _kAlphaTokenBloccato, child: tokenVisual)
          : (onTap == null
              ? tokenVisual
              : GestureDetector(onTap: onTap, child: tokenVisual)),
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
            onTap = _tapHandlerAvversario(ruolo);
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
      roleLabel,
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
      child: disabilitato
          ? Opacity(opacity: _kAlphaTokenBloccato, child: tokenVisual)
          : (onTap == null
              ? tokenVisual
              : GestureDetector(onTap: onTap, child: tokenVisual)),
    );
  }
}

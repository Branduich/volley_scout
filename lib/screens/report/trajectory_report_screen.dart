import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../models/enums.dart';
import '../../providers/database_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/court_style.dart';

const _kCourtImage = 'assets/images/double_court_bg.png';
const _kBg = Color(0xFF143E59);
const _kTopBarBg = Color(0xFF0D2738);
const double _kCourtWidthFraction = 0.58;
const double _kCourtTopMargin = 16.0;

const _kSlots = ['P1', 'P2', 'P3', 'P4', 'P5', 'P6'];

// Stessa logica di _ruotata in ricalcola_stato.dart (privata lì) — chi era
// in posizione p+1 si sposta in posizione p al momento di un sideout.
Map<int, int> _ruotata(Map<int, int> rot) =>
    {for (var p = 1; p <= 6; p++) p: rot[(p % 6) + 1]!};

class _TrajData {
  final double x1, y1, x2, y2;
  final Color color;
  const _TrajData(this.x1, this.y1, this.x2, this.y2, this.color);
}

/// Schermata di visualizzazione traiettorie per un singolo fondamentale
/// (battuta o attacco). Per l'attacco aggiunge il filtro rotazione
/// (slot del palleggiatore al momento dell'azione).
class TrajectoryReportScreen extends ConsumerStatefulWidget {
  final VolleyMatch match;
  final Team team;
  final Fondamentale fondamentale;

  const TrajectoryReportScreen({
    super.key,
    required this.match,
    required this.team,
    required this.fondamentale,
  });

  String get _title => fondamentale == Fondamentale.battuta
      ? 'Traiettorie battute'
      : 'Traiettorie attacco';

  // Etichetta per la cella "vincente" della mini-tabella.
  String get _labelVincente =>
      fondamentale == Fondamentale.battuta ? 'Ace  #' : 'Punto  #';

  @override
  ConsumerState<TrajectoryReportScreen> createState() =>
      _TrajectoryReportScreenState();
}

class _TrajectoryReportScreenState
    extends ConsumerState<TrajectoryReportScreen> {
  List<MatchSet> _sets = [];
  Map<int, List<ScoutAction>> _azioniPerSet = {};
  List<Player> _players = [];
  bool _loading = true;

  MatchSet? _setFiltro;     // null = partita intera
  Player? _playerFiltro;    // null = tutti i giocatori
  String? _rotazioneFiltro; // null = tutte; 'P1'..'P6' — solo attacco

  // actionId → slot del palleggiatore al momento dell'azione (solo attacco).
  Map<int, String> _slotPerAzioneId = {};

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    final setRepo = ref.read(matchSetRepositoryProvider);
    final actionRepo = ref.read(scoutActionRepositoryProvider);
    final teamRepo = ref.read(teamRepositoryProvider);

    final sets = await setRepo.caricaSetsPartita(widget.match.id);
    final players = await teamRepo.getPlayersForTeam(widget.team.id);
    final Map<int, List<ScoutAction>> azioniPerSet = {};
    for (final s in sets) {
      azioniPerSet[s.id] = await actionRepo.caricaAzioni(s.id);
    }

    // Per l'attacco: calcola in quale rotazione era la squadra al momento
    // di ogni azione (O(n) per set, identico a ricalcolaStato).
    Map<int, String> slotPerAzioneId = {};
    if (widget.fondamentale == Fondamentale.attacco) {
      slotPerAzioneId = await _computeRotazioni(sets, azioniPerSet);
    }

    if (!mounted) return;
    setState(() {
      _sets = sets;
      _players = players;
      _azioniPerSet = azioniPerSet;
      _slotPerAzioneId = slotPerAzioneId;
      if (sets.isNotEmpty) {
        _setFiltro = sets.firstWhere(
          (s) => s.numero == widget.match.setCorrente,
          orElse: () => sets.last,
        );
      }
      _loading = false;
    });
  }

  // Per ogni ScoutAction di attacco: determina lo slot del palleggiatore
  // al momento dell'azione, ricalcolando lo stato in O(n) per set con la
  // stessa logica di ricalcolaStato() — ma azione per azione invece che
  // solo al termine, per poter associare ogni attacco alla sua rotazione.
  Future<Map<int, String>> _computeRotazioni(
      List<MatchSet> sets, Map<int, List<ScoutAction>> azioniPerSet) async {
    final setRepo = ref.read(matchSetRepositoryProvider);
    final Map<int, String> result = {};

    for (final set in sets) {
      final formazione = await setRepo.caricaFormazione(set.id);
      if (formazione == null) continue;

      // Rotazione iniziale: posizione (1-6) → giocatoreId.
      final rotazioneIniziale = <int, int>{};
      for (final e in formazione.assignments.entries) {
        if (!e.key.startsWith('P')) continue;
        final pos = int.tryParse(e.key.substring(1));
        if (pos != null) rotazioneIniziale[pos] = e.value.id;
      }

      final setterPlayerId =
          formazione.assignments[formazione.palleggiatoreSlot]?.id;
      if (setterPlayerId == null) continue;

      final azioni = azioniPerSet[set.id] ?? [];
      final ordinate = [...azioni]
        ..sort((a, b) => a.ordine.compareTo(b.ordine));

      var rotazione = Map<int, int>.from(rotazioneIniziale);
      var nostraAlServizio = set.squadraServizioIniziale == Squadra.nostra;

      for (final a in ordinate) {
        // Registra la rotazione corrente PRIMA di applicare l'esito
        // dell'azione — l'attacco avviene durante il rally, prima della
        // rotazione causata dall'eventuale punto.
        if (a.fondamentale == Fondamentale.attacco &&
            a.tipo == TipoAzione.scout) {
          final setterEntry = rotazione.entries
              .where((e) => e.value == setterPlayerId)
              .firstOrNull;
          if (setterEntry != null) result[a.id] = 'P${setterEntry.key}';
        }

        // Applica l'effetto sul servizio/rotazione (identico a ricalcolaStato).
        if (a.esitoPunto == EsitoPunto.puntoNostro && !nostraAlServizio) {
          rotazione = _ruotata(rotazione);
          nostraAlServizio = true;
        } else if (a.esitoPunto == EsitoPunto.puntoNostro) {
          nostraAlServizio = true;
        } else if (a.esitoPunto == EsitoPunto.puntoAvversario) {
          nostraAlServizio = false;
        }
      }
    }
    return result;
  }

  // ── Getter filtrati ──────────────────────────────────────────────────────────

  List<ScoutAction> get _azioniFiltrate {
    return _azioniPerSet.entries
        .where((e) => _setFiltro == null || e.key == _setFiltro!.id)
        .expand((e) => e.value)
        .where((a) =>
            a.fondamentale == widget.fondamentale &&
            a.tipo == TipoAzione.scout)
        .where((a) =>
            _playerFiltro == null || a.giocatoreId == _playerFiltro!.id)
        .where((a) =>
            _rotazioneFiltro == null ||
            _slotPerAzioneId[a.id] == _rotazioneFiltro)
        .toList();
  }

  List<ScoutAction> get _azioniConTraj => _azioniFiltrate
      .where((a) =>
          a.traiettoriaX1 != null &&
          a.traiettoriaY1 != null &&
          a.traiettoriaX2 != null &&
          a.traiettoriaY2 != null)
      .toList();

  // Giocatori con almeno un'azione nel set/rotazione correnti — si
  // restringe al cambio di filtro.
  List<Player> get _giocatoriFiltrati {
    final ids = _azioniPerSet.entries
        .where((e) => _setFiltro == null || e.key == _setFiltro!.id)
        .expand((e) => e.value)
        .where((a) =>
            a.fondamentale == widget.fondamentale &&
            a.tipo == TipoAzione.scout)
        .where((a) =>
            _rotazioneFiltro == null ||
            _slotPerAzioneId[a.id] == _rotazioneFiltro)
        .map((a) => a.giocatoreId)
        .whereType<int>()
        .toSet();
    return _players.where((p) => ids.contains(p.id)).toList();
  }

  // Normalizza: partenza sempre da sinistra (x1 < 0.5). Verde brillante
  // per le azioni vincenti (#), rosso per gli errori (=), bianco per il
  // resto (in campo — nessuna distinzione ulteriore in questa vista).
  _TrajData _buildTrajData(ScoutAction a) {
    var x1 = a.traiettoriaX1!;
    var y1 = a.traiettoriaY1!;
    var x2 = a.traiettoriaX2!;
    var y2 = a.traiettoriaY2!;
    if (x1 > 0.5) {
      x1 = 1.0 - x1;
      y1 = 1.0 - y1;
      x2 = 1.0 - x2;
      y2 = 1.0 - y2;
    }
    final Color color;
    if (a.voto == Voto.perfetto) {
      color = CourtStyle.trajectoryAce;
    } else if (a.voto == Voto.errore) {
      color = Colors.red;
    } else {
      color = Colors.white;
    }
    return _TrajData(x1, y1, x2, y2, color);
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          if (_loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            _buildFilterRow(),
            Expanded(child: _buildBody()),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 60,
      color: _kTopBarBg,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            left: 56,
            right: 56,
            bottom: 4,
            child: Text(
              widget._title,
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
            left: 0,
            bottom: 0,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  // Azzera _playerFiltro se non è più presente in _giocatoriFiltrati con i
  // filtri correnti. Va chiamato DOPO aver aggiornato _setFiltro /
  // _rotazioneFiltro, così il getter usa già i valori nuovi.
  void _validaFiltri() {
    if (_playerFiltro != null &&
        !_giocatoriFiltrati.any((p) => p.id == _playerFiltro!.id)) {
      _playerFiltro = null;
    }
  }

  Widget _buildFilterRow() {
    final isAttacco = widget.fondamentale == Fondamentale.attacco;
    return Container(
      color: _kTopBarBg,
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
      child: Row(
        children: [
          Expanded(
            child: _buildDropdown<MatchSet?>(
              value: _setFiltro,
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('Partita intera')),
                ..._sets.map((s) => DropdownMenuItem(
                    value: s, child: Text('Set ${s.numero}'))),
              ],
              onChanged: (v) {
                setState(() {
                  _setFiltro = v;
                  // Azzera rotazione se non ha attacchi nel nuovo set.
                  if (isAttacco && _rotazioneFiltro != null) {
                    final ok = _azioniPerSet.entries
                        .where((e) => v == null || e.key == v.id)
                        .expand((e) => e.value)
                        .any((a) =>
                            a.fondamentale == widget.fondamentale &&
                            a.tipo == TipoAzione.scout &&
                            _slotPerAzioneId[a.id] == _rotazioneFiltro);
                    if (!ok) _rotazioneFiltro = null;
                  }
                  // Azzera giocatore se non è più in _giocatoriFiltrati
                  // (tiene conto di set e rotazione già aggiornati sopra).
                  _validaFiltri();
                });
              },
            ),
          ),
          if (isAttacco) ...[
            const SizedBox(width: 16),
            Expanded(
              child: _buildDropdown<String?>(
                value: _rotazioneFiltro,
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('Tutte le rotazioni')),
                  ..._kSlots.map((s) => DropdownMenuItem(
                      value: s, child: Text('Rotazione $s'))),
                ],
                onChanged: (v) {
                  setState(() {
                    _rotazioneFiltro = v;
                    _validaFiltri();
                  });
                },
              ),
            ),
          ],
          const SizedBox(width: 16),
          Expanded(
            child: _buildDropdown<Player?>(
              value: _playerFiltro,
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('Tutti i giocatori')),
                ..._giocatoriFiltrati.map((p) => DropdownMenuItem(
                    value: p, child: Text('${p.numero}  ${p.cognome}'))),
              ],
              onChanged: (v) => setState(() => _playerFiltro = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButton<T>(
      value: value,
      dropdownColor: _kTopBarBg,
      style: const TextStyle(color: Colors.white),
      iconEnabledColor: Colors.white,
      underline: Container(height: 1, color: Colors.white38),
      isExpanded: true,
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _buildBody() {
    final tutte = _azioniFiltrate;
    final conTraj = _azioniConTraj;
    final trajectories = conTraj.map(_buildTrajData).toList();

    return LayoutBuilder(builder: (context, constraints) {
      final courtWidth = constraints.maxWidth * _kCourtWidthFraction;
      final courtHeight = courtWidth / 2;
      final courtLeft = (constraints.maxWidth - courtWidth) / 2;
      const courtTop = _kCourtTopMargin;

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
              painter: _MultiTrajectoryPainter(
                trajectories: trajectories,
                courtLeft: courtLeft,
                courtTop: courtTop,
                courtWidth: courtWidth,
                courtHeight: courtHeight,
              ),
            ),
          if (tutte.isEmpty)
            Positioned(
              top: courtTop + courtHeight + 24,
              left: 0,
              right: 0,
              child: const Center(
                child: Text(
                  'Nessuna azione registrata per i filtri selezionati.',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            Positioned(
              top: courtTop + courtHeight + 16,
              left: 0,
              right: 0,
              child: _buildMiniTable(tutte, conTraj.length),
            ),
        ],
      );
    });
  }

  Widget _buildMiniTable(List<ScoutAction> tutte, int conTraj) {
    final vincenti = tutte.where((a) => a.voto == Voto.perfetto).length;
    final normali = tutte
        .where((a) =>
            a.voto == Voto.positivo ||
            a.voto == Voto.mezzoPunto ||
            a.voto == Voto.negativo)
        .length;
    final errori = tutte.where((a) => a.voto == Voto.errore).length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStatCell(widget._labelVincente, vincenti, AppColors.success),
            const SizedBox(width: 12),
            _buildStatCell('In campo', normali, Colors.grey.shade600),
            const SizedBox(width: 12),
            _buildStatCell('Errore  =', errori, Colors.red),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Totale: ${tutte.length}  •  con traiettoria: $conTraj',
          style: const TextStyle(color: Colors.white, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStatCell(String label, int count, Color color) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 28,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _MultiTrajectoryPainter extends CustomPainter {
  final List<_TrajData> trajectories;
  final double courtLeft, courtTop, courtWidth, courtHeight;

  _MultiTrajectoryPainter({
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

      canvas.drawLine(inizio, fine, paint);

      final direzione = fine - inizio;
      if (direzione.distance >= 4) {
        final angolo = direzione.direction;
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
  bool shouldRepaint(covariant _MultiTrajectoryPainter old) =>
      old.trajectories != trajectories ||
      old.courtLeft != courtLeft ||
      old.courtTop != courtTop;
}

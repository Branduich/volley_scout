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

class _TrajData {
  final double x1, y1, x2, y2;
  final Color color;
  const _TrajData(this.x1, this.y1, this.x2, this.y2, this.color);
}

class TrajectoryReportScreen extends ConsumerStatefulWidget {
  final VolleyMatch match;
  final Team team;

  const TrajectoryReportScreen({
    super.key,
    required this.match,
    required this.team,
  });

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

  // null = partita intera
  MatchSet? _setFiltro;
  // null = tutti i giocatori
  Player? _playerFiltro;

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

    if (!mounted) return;
    setState(() {
      _sets = sets;
      _players = players;
      _azioniPerSet = azioniPerSet;
      // Default: set corrente (o l'ultimo se non trovato, o null se nessun set)
      if (sets.isNotEmpty) {
        _setFiltro = sets.firstWhere(
          (s) => s.numero == widget.match.setCorrente,
          orElse: () => sets.last,
        );
      }
      _loading = false;
    });
  }

  // Tutte le azioni di tipo "battuta scout" che rispettano i filtri correnti.
  List<ScoutAction> get _battuteFiltrate {
    return _azioniPerSet.entries
        .where((e) => _setFiltro == null || e.key == _setFiltro!.id)
        .expand((e) => e.value)
        .where((a) =>
            a.fondamentale == Fondamentale.battuta &&
            a.tipo == TipoAzione.scout)
        .where((a) =>
            _playerFiltro == null || a.giocatoreId == _playerFiltro!.id)
        .toList();
  }

  // Battute con traiettoria completa registrata.
  List<ScoutAction> get _battuteConTraj => _battuteFiltrate
      .where((a) =>
          a.traiettoriaX1 != null &&
          a.traiettoriaY1 != null &&
          a.traiettoriaX2 != null &&
          a.traiettoriaY2 != null)
      .toList();

  // Giocatori che hanno almeno una battuta nel set selezionato (o in tutti
  // i set se _setFiltro == null). La lista si restringe al cambio di set.
  List<Player> get _giocatoriConBattute {
    final ids = _azioniPerSet.entries
        .where((e) => _setFiltro == null || e.key == _setFiltro!.id)
        .expand((e) => e.value)
        .where((a) =>
            a.fondamentale == Fondamentale.battuta &&
            a.tipo == TipoAzione.scout)
        .map((a) => a.giocatoreId)
        .whereType<int>()
        .toSet();
    return _players.where((p) => ids.contains(p.id)).toList();
  }

  // Normalizza la traiettoria in modo che la battuta vada sempre da
  // sinistra verso destra (x1 < 0.5 = battitore sul lato sinistro).
  // Il battitore è dietro la linea di fondo, quindi x1 ≈ −0.06 (lato
  // sinistro) o x1 ≈ 1.06 (lato destro): se x1 > 0.5 si specchia
  // attorno al centro del campo (x'=1−x, y'=1−y per entrambi i punti).
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
    // Verde = ace (#), rosso = errore (=), bianco = tutto il resto
    // (positivo/mezzoPunto/negativo: la palla è in gioco, nessuna
    // distinzione ulteriore in questa vista).
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
          const Positioned(
            left: 56,
            right: 56,
            bottom: 4,
            child: Text(
              'Traiettorie battute',
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
    );
  }

  Widget _buildFilterRow() {
    final giocatori = _giocatoriConBattute;
    return Container(
      color: _kTopBarBg,
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
      child: Row(
        children: [
          Expanded(
            child: DropdownButton<MatchSet?>(
              value: _setFiltro,
              dropdownColor: _kTopBarBg,
              style: const TextStyle(color: Colors.white),
              iconEnabledColor: Colors.white,
              underline: Container(height: 1, color: Colors.white38),
              isExpanded: true,
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Partita intera'),
                ),
                ..._sets.map(
                  (s) => DropdownMenuItem(
                    value: s,
                    child: Text('Set ${s.numero}'),
                  ),
                ),
              ],
              onChanged: (v) {
                setState(() {
                  _setFiltro = v;
                  // Azzera il filtro giocatore se non ha battute nel nuovo set
                  final player = _playerFiltro;
                  if (player != null) {
                    final hasBattute = _azioniPerSet.entries
                        .where((e) => v == null || e.key == v.id)
                        .expand((e) => e.value)
                        .any((a) =>
                            a.fondamentale == Fondamentale.battuta &&
                            a.tipo == TipoAzione.scout &&
                            a.giocatoreId == player.id);
                    if (!hasBattute) _playerFiltro = null;
                  }
                });
              },
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: DropdownButton<Player?>(
              value: _playerFiltro,
              dropdownColor: _kTopBarBg,
              style: const TextStyle(color: Colors.white),
              iconEnabledColor: Colors.white,
              underline: Container(height: 1, color: Colors.white38),
              isExpanded: true,
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Tutti i giocatori'),
                ),
                ...giocatori.map(
                  (p) => DropdownMenuItem(
                    value: p,
                    child: Text('${p.numero}  ${p.cognome}'),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _playerFiltro = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final tutte = _battuteFiltrate;
    final conTraj = _battuteConTraj;
    final trajectories = conTraj.map(_buildTrajData).toList();

    return LayoutBuilder(builder: (context, constraints) {
      final courtWidth = constraints.maxWidth * _kCourtWidthFraction;
      final courtHeight = courtWidth / 2; // aspect ratio 1200/600
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
                  'Nessuna battuta registrata per i filtri selezionati.',
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
    final ace = tutte.where((a) => a.voto == Voto.perfetto).length;
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
            _buildStatCell('Ace  #', ace, AppColors.success),
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

      // Pallino di partenza
      canvas.drawCircle(inizio, 4, Paint()..color = t.color.withAlpha(220));
    }
  }

  @override
  bool shouldRepaint(covariant _MultiTrajectoryPainter old) =>
      old.trajectories != trajectories ||
      old.courtLeft != courtLeft ||
      old.courtTop != courtTop;
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../models/enums.dart';
import '../../providers/database_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/court_trajectories_view.dart';

const _kBg = Color(0xFF143E59);
const _kTopBarBg = Color(0xFF0D2738);

const _kSlots = ['P1', 'P2', 'P3', 'P4', 'P5', 'P6'];

// Filtro attacchi (solo fondamentale attacco): stessa partizione binaria di
// PlayerStatsScreen/report — "su ricezione" = primo attacco dopo un voto di
// ricezione nello stesso scambio (idAttacchiSuRicezione), il resto "su
// difesa".
enum _FiltroAttacco {
  tutti('Tutti gli attacchi'),
  suRicezione('Su ricezione'),
  suDifesa('Su difesa');

  final String label;
  const _FiltroAttacco(this.label);
}

// Stessa logica di _ruotata in ricalcola_stato.dart (privata lì) — chi era
// in posizione p+1 si sposta in posizione p al momento di un sideout.
Map<int, int> _ruotata(Map<int, int> rot) =>
    {for (var p = 1; p <= 6; p++) p: rot[(p % 6) + 1]!};

/// Schermata di visualizzazione traiettorie per un singolo fondamentale
/// (battuta o attacco). Per l'attacco aggiunge il filtro rotazione
/// (slot del palleggiatore al momento dell'azione).
class TrajectoryReportScreen extends ConsumerStatefulWidget {
  final VolleyMatch match;
  final Team team;
  final Fondamentale fondamentale;

  /// Set su cui posizionare il filtro all'apertura: `true` = set corrente
  /// (default, sensato dallo scout live in corso), `false` = tutti i set
  /// / partita intera (default sensato dal report a partita finita).
  final bool setCorrenteAllAvvio;

  const TrajectoryReportScreen({
    super.key,
    required this.match,
    required this.team,
    required this.fondamentale,
    this.setCorrenteAllAvvio = true,
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
  _FiltroAttacco _filtroAttacco = _FiltroAttacco.tutti; // solo attacco

  // actionId → slot del palleggiatore al momento dell'azione (solo attacco).
  Map<int, String> _slotPerAzioneId = {};

  // Id degli attacchi "su ricezione" (helper condiviso, calcolato una volta
  // in _carica — solo attacco); il complemento è "su difesa".
  Set<int> _idSuRicezione = {};

  // Vero se l'azione passa il filtro attacchi corrente.
  bool _passaFiltroAttacco(ScoutAction a) => switch (_filtroAttacco) {
        _FiltroAttacco.tutti => true,
        _FiltroAttacco.suRicezione => _idSuRicezione.contains(a.id),
        _FiltroAttacco.suDifesa => !_idSuRicezione.contains(a.id),
      };

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
    Set<int> idSuRicezione = {};
    if (widget.fondamentale == Fondamentale.attacco) {
      slotPerAzioneId = await _computeRotazioni(sets, azioniPerSet);
      idSuRicezione = idAttacchiSuRicezione(azioniPerSet.values);
    }

    if (!mounted) return;
    setState(() {
      _sets = sets;
      _players = players;
      _azioniPerSet = azioniPerSet;
      _slotPerAzioneId = slotPerAzioneId;
      _idSuRicezione = idSuRicezione;
      if (widget.setCorrenteAllAvvio && sets.isNotEmpty) {
        _setFiltro = sets.firstWhere(
          (s) => s.numero == widget.match.setCorrente,
          orElse: () => sets.last,
        );
      }
      // altrimenti _setFiltro resta null = "Partita intera" (tutti i set).
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

      final setterIniziale =
          formazione.assignments[formazione.palleggiatoreSlot]?.id;
      if (setterIniziale == null) continue;
      // Palleggiatore designato EFFETTIVO: può cambiare a set in corso con
      // un cambio giocatore (override nell'evento) — vedi ricalcolaStato().
      var setterPlayerId = setterIniziale;

      final azioni = azioniPerSet[set.id] ?? [];
      final ordinate = [...azioni]
        ..sort((a, b) => a.ordine.compareTo(b.ordine));

      var rotazione = Map<int, int>.from(rotazioneIniziale);
      var nostraAlServizio = set.squadraServizioIniziale == Squadra.nostra;

      for (final a in ordinate) {
        // Cambio giocatore: il subentrante prende la posizione dell'uscente,
        // la rotazione non cambia — stessa regola (e stesse guardie sui
        // dati incoerenti) di ricalcolaStato() in ricalcola_stato.dart:
        // uscente non in campo o subentrante già in campo → no-op.
        if (a.tipo == TipoAzione.cambioGiocatore &&
            a.giocatoreId != null &&
            a.giocatoreUscenteId != null) {
          final entra = a.giocatoreId!;
          final esce = a.giocatoreUscenteId!;
          final duplicherebbe =
              esce != entra && rotazione.containsValue(entra);
          if (!duplicherebbe) {
            rotazione = {
              for (final e in rotazione.entries)
                e.key: e.value == esce ? entra : e.value,
            };
            setterPlayerId = a.nuovoPalleggiatoreId ?? setterPlayerId;
          }
        }

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
        .where(_passaFiltroAttacco)
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
        .where(_passaFiltroAttacco)
        .map((a) => a.giocatoreId)
        .whereType<int>()
        .toSet();
    return _players.where((p) => ids.contains(p.id)).toList();
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
      height: 80,
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
            const SizedBox(width: 16),
            Expanded(
              child: _buildDropdown<_FiltroAttacco>(
                value: _filtroAttacco,
                items: [
                  for (final f in _FiltroAttacco.values)
                    DropdownMenuItem(value: f, child: Text(f.label)),
                ],
                onChanged: (v) {
                  setState(() {
                    _filtroAttacco = v ?? _FiltroAttacco.tutti;
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
    final trajectories = conTraj.map(buildTrajData).toList();

    // footer posizionato a courtTop+courtHeight+16 dentro CourtTrajectoriesView:
    // per il messaggio "vuoto" aggiungo 8px in cima per riprodurre il vecchio
    // scostamento a +24, la mini-tabella resta a +16.
    final Widget footer = tutte.isEmpty
        ? const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Center(
              child: Text(
                'Nessuna azione registrata per i filtri selezionati.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMiniTable(tutte, conTraj.length),
              const SizedBox(height: 14),
              _buildDistribuzioneTipi(tutte),
            ],
          );

    return CourtTrajectoriesView(trajectories: trajectories, footer: footer);
  }

  // Distribuzione per tipo di esecuzione (TipoBattuta per la battuta,
  // TipoAttacco per l'attacco) sulle azioni FILTRATE `tutte` — riflette
  // quindi set/giocatore/(rotazione+su ric./difesa per l'attacco). Mostra
  // solo i tipi con conteggio > 0, incluso `nonSpecificato` (dice quante
  // azioni non sono state taggate). Parsing per `.name` come l'export CSV.
  Widget _buildDistribuzioneTipi(List<ScoutAction> tutte) {
    final isBattuta = widget.fondamentale == Fondamentale.battuta;
    // (label, name) in ordine di dichiarazione dell'enum.
    final tipi = isBattuta
        ? [for (final t in TipoBattuta.values) (t.label, t.name)]
        : [for (final t in TipoAttacco.values) (t.label, t.name)];
    final validi = {for (final t in tipi) t.$2};

    final conteggi = <String, int>{};
    for (final a in tutte) {
      final n = validi.contains(a.tipoEsecuzione)
          ? a.tipoEsecuzione
          : 'nonSpecificato';
      conteggi[n] = (conteggi[n] ?? 0) + 1;
    }
    final totale = tutte.length;

    final celle = <Widget>[
      for (final (label, name) in tipi)
        if ((conteggi[name] ?? 0) > 0)
          _buildTipoCell(label, conteggi[name]!, totale),
    ];
    if (celle.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          isBattuta ? 'Tipo di battuta' : 'Tipo di attacco',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: celle,
        ),
      ],
    );
  }

  // Cella compatta della distribuzione: label + "conteggio (%)". Colore
  // neutro (i colori esito sono già usati dalla mini-tabella sopra).
  Widget _buildTipoCell(String label, int count, int totale) {
    final pct = totale == 0 ? 0 : (count * 100 / totale).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade700,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$count  ($pct%)',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
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

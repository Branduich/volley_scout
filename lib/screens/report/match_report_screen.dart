import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../models/enums.dart';
import '../../providers/database_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/court_style.dart';
import '../../widgets/debug_paint_toggle.dart';

// Punteggio finale (eventi + correzione manuale) di un singolo set +
// durata di gioco (prima→ultima azione registrata, null se < 2 azioni).
typedef _RigaSet = ({
  int numero,
  int nostro,
  int avversario,
  Duration? durata,
});

// Riga del riepilogo fondamentali: conteggi per voto + totale.
typedef _RigaFondamentale = ({String label, Map<Voto, int> conteggi, int totale});

// Ordine/etichette delle righe del riepilogo fondamentali, fissato dallo
// sviluppatore — "Attacco" è il totale di tutti gli attacchi, "Attacco su
// ricezione"/"Attacco su Difesa" sono il sottoinsieme dedotto dalla
// sequenza dello scambio (vedi _riepilogoFondamentali).
const _ordineFondamentali = [
  ('battuta', 'Battuta'),
  ('ricezione', 'Ricezione'),
  ('difesa', 'Difesa'),
  ('attacco', 'Attacco'),
  ('attaccoSuRicezione', 'Attacco su ricezione'),
  ('attaccoSuDifesa', 'Attacco su Difesa'),
  ('muro', 'Muro'),
  ('alzata', 'Alzata'),
];

/// Report di una partita (Fase 4) — pagina 1: dati partita, punteggio
/// finale (set vinti), punteggio di ogni set e riepilogo di tutti i
/// fondamentali (set selezionabile o partita intera). Niente statistiche
/// per giocatore (vedi `PlayerStatsScreen`) o traiettorie per ora.
class MatchReportScreen extends ConsumerStatefulWidget {
  final VolleyMatch match;
  const MatchReportScreen({super.key, required this.match});

  @override
  ConsumerState<MatchReportScreen> createState() => _MatchReportScreenState();
}

class _MatchReportScreenState extends ConsumerState<MatchReportScreen> {
  Team? _team;
  List<MatchSet>? _sets;
  List<_RigaSet>? _righeSet;
  Map<int, List<ScoutAction>>? _azioniPerSet; // setId -> azioni

  int? _setSelezionato; // null = Partita intera (default)

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    final setRepo = ref.read(matchSetRepositoryProvider);
    final azioniRepo = ref.read(scoutActionRepositoryProvider);
    final teamId = widget.match.teamId;
    var team = teamId == null
        ? null
        : await ref.read(teamRepositoryProvider).getTeam(teamId);
    // Partite giocate prima del fix di TeamSelectionScreen possono avere
    // teamId rimasto null pur avendo una squadra realmente selezionata —
    // vedi MatchSetRepository.inferisciSquadraDaRotazioni.
    team ??= await setRepo.inferisciSquadraDaRotazioni(widget.match.id);
    final sets = await setRepo.caricaSetsPartita(widget.match.id);

    final righeSet = <_RigaSet>[];
    final azioniPerSet = <int, List<ScoutAction>>{};
    for (final set in sets) {
      final stato = await setRepo.calcolaStatoFinale(set);
      final azioni = await azioniRepo.caricaAzioni(set.id);
      azioniPerSet[set.id] = azioni;
      righeSet.add((
        numero: set.numero,
        nostro: stato.punteggioNostro + set.correzionePuntiNostri,
        avversario: stato.punteggioAvversario + set.correzionePuntiAvversari,
        durata: _durataSet(azioni),
      ));
    }
    if (!mounted) return;
    setState(() {
      _team = team;
      _sets = sets;
      _righeSet = righeSet;
      _azioniPerSet = azioniPerSet;
    });
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  // Durata di gioco di un set: dalla prima all'ultima azione registrata
  // (per lo scout live i timestamp sono reali; per la partita demo sono
  // sintetici, quindi la durata lì è solo indicativa). Null se il set ha
  // meno di due azioni.
  Duration? _durataSet(List<ScoutAction> azioni) {
    if (azioni.length < 2) return null;
    // caricaAzioni ordina per `ordine` crescente: prima = inizio, ultima =
    // fine set. I timestamp sono monotoni con l'ordine.
    return azioni.last.timestamp.difference(azioni.first.timestamp);
  }

  String _formatDurata(Duration d) =>
      '${d.inMinutes}:${_pad(d.inSeconds % 60)}';

  // Trailing condiviso dalle righe "Set N" e dalla riga "Totale":
  // punteggio a larghezza fissa (colonne allineate) · pallino esito ·
  // durata. `esitoNostro`/`esitoAvversario` pilotano il colore del pallino
  // separatamente dal punteggio mostrato — per il Totale il pallino segue
  // i SET vinti, non i punti fatti/subiti.
  Widget _trailingPunteggio({
    required int nostro,
    required int avversario,
    required Duration? durata,
    int? esitoNostro,
    int? esitoAvversario,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 84,
          child: Text(
            '$nostro - $avversario',
            textAlign: TextAlign.end,
            style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        const SizedBox(width: 28),
        _pallinoEsito(esitoNostro ?? nostro, esitoAvversario ?? avversario),
        const SizedBox(width: 28),
        _durataLabel(durata),
      ],
    );
  }

  // Pallino esito del set: verde = vinto, rosso = perso, grigio = parità
  // (set non concluso, non dovrebbe capitare in una partita terminata).
  Widget _pallinoEsito(int nostro, int avversario) {
    final color = nostro > avversario
        ? AppColors.success
        : (avversario > nostro ? AppColors.danger : AppColors.neutral);
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  // Durata di gioco del set (mm:ss) con icona orologio; "—" se non
  // calcolabile (meno di due azioni registrate).
  Widget _durataLabel(Duration? durata) {
    return SizedBox(
      // largo abbastanza per il totale di partita (minuti a 3 cifre).
      width: 78,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule, size: 15, color: Colors.black45),
          const SizedBox(width: 4),
          Text(
            durata == null ? '—' : _formatDurata(durata),
            style: const TextStyle(color: Colors.black54, fontSize: 14),
          ),
        ],
      ),
    );
  }

  List<List<ScoutAction>> get _listeAzioniNelloScope {
    final azioniPerSet = _azioniPerSet;
    final sets = _sets;
    if (azioniPerSet == null || sets == null) return const [];
    if (_setSelezionato == null) {
      return azioniPerSet.values.toList();
    }
    for (final s in sets) {
      if (s.numero == _setSelezionato) {
        final lista = azioniPerSet[s.id];
        return lista == null ? const [] : [lista];
      }
    }
    return const [];
  }

  // Per ogni attacco, risale a ricezione/difesa più recente nello stesso
  // scambio (`rallyId`, scope per set) per classificarlo come "su
  // ricezione" o "su Difesa" — non è un campo salvato, va dedotto dalla
  // sequenza (battuta/ricezione/alzata/attacco/muro/difesa nell'ordine in
  // cui sono stati registrati).
  List<_RigaFondamentale> get _riepilogoFondamentali {
    final contatori = <String, Map<Voto, int>>{
      for (final (chiave, _) in _ordineFondamentali) chiave: <Voto, int>{},
    };
    void incrementa(String chiave, Voto voto) {
      final mappa = contatori[chiave]!;
      mappa[voto] = (mappa[voto] ?? 0) + 1;
    }

    for (final azioniSet in _listeAzioniNelloScope) {
      int? rallyCorrente;
      Fondamentale? ultimoTipo; // ricezione o difesa più recente nello scambio
      for (final azione in azioniSet) {
        if (azione.tipo != TipoAzione.scout) continue;
        final fondamentale = azione.fondamentale;
        final voto = azione.voto;
        if (fondamentale == null || voto == null) continue;
        if (azione.rallyId != rallyCorrente) {
          rallyCorrente = azione.rallyId;
          ultimoTipo = null;
        }
        switch (fondamentale) {
          case Fondamentale.battuta:
            incrementa('battuta', voto);
          case Fondamentale.ricezione:
            incrementa('ricezione', voto);
            ultimoTipo = Fondamentale.ricezione;
          case Fondamentale.difesa:
            incrementa('difesa', voto);
            ultimoTipo = Fondamentale.difesa;
          case Fondamentale.attacco:
            incrementa('attacco', voto);
            // Ragionamento per fasi, non per fondamentale: l'attacco "su
            // ricezione" è sempre il primo dopo un voto di ricezione nello
            // stesso scambio — tutti gli altri (dopo una difesa, dopo un
            // altro attacco, o senza alcun contesto registrato) sono
            // "su Difesa". Partizione binaria: la somma dei due torna
            // sempre il totale "Attacco".
            if (ultimoTipo == Fondamentale.ricezione) {
              incrementa('attaccoSuRicezione', voto);
            } else {
              incrementa('attaccoSuDifesa', voto);
            }
          case Fondamentale.muro:
            incrementa('muro', voto);
          case Fondamentale.alzata:
            incrementa('alzata', voto);
          case Fondamentale.errore:
            break; // mai assegnato da ScoutScreen
        }
      }
    }

    return [
      for (final (chiave, label) in _ordineFondamentali)
        (
          label: label,
          conteggi: contatori[chiave]!,
          totale: contatori[chiave]!.values.fold(0, (a, b) => a + b),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final sets = _sets;
    final righeSet = _righeSet;
    if (sets == null || righeSet == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Report partita')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final avversario = widget.match.avversario?.trim();
    final nomeAvversario =
        (avversario != null && avversario.isNotEmpty) ? avversario : 'Avversari';
    final dt = widget.match.dataOra;
    final dataOraStr =
        '${_pad(dt.day)}/${_pad(dt.month)}/${dt.year} ${_pad(dt.hour)}:${_pad(dt.minute)}';
    final nomeNostro = _team?.nome ?? 'Nostra squadra';

    var setVintiNostri = 0;
    var setVintiAvversario = 0;
    var puntiNostri = 0;
    var puntiAvversari = 0;
    var durataTotale = Duration.zero;
    for (final riga in righeSet) {
      if (riga.nostro > riga.avversario) setVintiNostri++;
      if (riga.avversario > riga.nostro) setVintiAvversario++;
      puntiNostri += riga.nostro;
      puntiAvversari += riga.avversario;
      if (riga.durata != null) durataTotale += riga.durata!;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report partita'),
        actions: const [DebugPaintToggle()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: double.infinity),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$nomeNostro - $nomeAvversario',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(widget.match.nome, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(dataOraStr, style: Theme.of(context).textTheme.bodyLarge),
              if (widget.match.palestra != null &&
                  widget.match.palestra!.trim().isNotEmpty)
                Text(widget.match.palestra!.trim(),
                    style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 32),
              Text('Punteggio finale', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(nomeNostro,
                            style: Theme.of(context).textTheme.titleMedium),
                      ),
                      Text(
                        '$setVintiNostri - $setVintiAvversario',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Expanded(
                        child: Text(
                          nomeAvversario,
                          textAlign: TextAlign.end,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text('Punteggio per set', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (righeSet.isEmpty)
                const Text('Nessun set giocato.')
              else
                Card(
                  // clipBehavior: lo sfondo colorato della riga Totale deve
                  // rispettare gli angoli arrotondati della Card.
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final riga in righeSet) ...[
                        ListTile(
                          title: Text('Set ${riga.numero}'),
                          trailing: _trailingPunteggio(
                            nostro: riga.nostro,
                            avversario: riga.avversario,
                            durata: riga.durata,
                          ),
                        ),
                        const Divider(height: 1),
                      ],
                      // Riga Totale: punti fatti-subiti su tutta la partita,
                      // pallino sull'esito della PARTITA (set vinti, non
                      // punti) e durata totale. Sfondo azzurro come la riga
                      // "Totale" di PlayerStatsScreen.
                      ListTile(
                        tileColor:
                            const Color.fromARGB(255, 213, 242, 255),
                        title: const Text('Totale',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        trailing: _trailingPunteggio(
                          nostro: puntiNostri,
                          avversario: puntiAvversari,
                          durata: durataTotale,
                          esitoNostro: setVintiNostri,
                          esitoAvversario: setVintiAvversario,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 32),
              Text('Riepilogo fondamentali',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<int?>(
                  initialValue: _setSelezionato,
                  decoration: const InputDecoration(
                    labelText: 'Set',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Partita intera'),
                    ),
                    for (final s in sets)
                      DropdownMenuItem(
                        value: s.numero,
                        child: Text('Set ${s.numero}'),
                      ),
                  ],
                  onChanged: (v) => setState(() => _setSelezionato = v),
                ),
              ),
              const SizedBox(height: 8),
              _buildTabellaFondamentali(_riepilogoFondamentali),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabellaFondamentali(List<_RigaFondamentale> righe) {
    const voti = Voto.values;
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(3.2),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1),
        3: FlexColumnWidth(1),
        4: FlexColumnWidth(1),
        5: FlexColumnWidth(1),
        6: FlexColumnWidth(1),
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(color: AppColors.surfaceDim),
          children: [
            _headerCell('Fondamentale', allineaSinistra: true),
            for (final v in voti) _headerCell(v.simbolo, fontSize: 22),
            _headerCell('TOT'),
          ],
        ),
        for (var i = 0; i < righe.length; i++)
          TableRow(
            decoration: BoxDecoration(
              color: i.isEven ? Colors.white : AppColors.surface,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                child: Text(righe[i].label,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              ),
              for (final v in voti)
                _votoCell(righe[i].conteggi[v] ?? 0, righe[i].totale, v),
              _totaleCell(righe[i].totale),
            ],
          ),
      ],
    );
  }

  Widget _headerCell(String text, {bool allineaSinistra = false, double? fontSize}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Text(
          text,
          textAlign: allineaSinistra ? TextAlign.left : TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize),
        ),
      );

  Widget _votoCell(int count, int totale, Voto voto) {
    final pct = totale == 0 ? 0 : (count * 100 / totale).round();
    final color = CourtStyle.votoColor(voto);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$count',
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 22)),
          Text('$pct%', style: TextStyle(color: color, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _totaleCell(int totale) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Text('$totale',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        ),
      );
}

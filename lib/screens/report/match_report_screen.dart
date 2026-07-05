import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../models/enums.dart';
import '../../providers/database_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/court_style.dart';
import '../../widgets/court_view.dart';
import '../../widgets/debug_paint_toggle.dart';
import 'trajectory_report_screen.dart';

// Punteggio finale (eventi + correzione manuale) di un singolo set +
// durata di gioco (prima→ultima azione registrata, null se < 2 azioni).
typedef _RigaSet = ({int numero, int nostro, int avversario, Duration? durata});

// Riga del riepilogo fondamentali: conteggi per voto + totale.
typedef _RigaFondamentale = ({
  String label,
  Map<Voto, int> conteggi,
  int totale,
});

// Riepilogo dei punti/errori generici (bottoni rapidi, senza giocatore) +
// scomposizione degli errori avversari per motivo.
typedef _RiepilogoGenerici = ({
  int puntiNostri,
  int erroriNostri,
  int puntiAvversari,
  int erroriAvversari,
  Map<MotivoErrore, int> motiviAvversari,
});

// Formazione di partenza di un set — stesso record di
// MatchSetRepository.caricaFormazione().
typedef _Formazione = ({
  Map<String, Player> assignments,
  String palleggiatoreSlot,
  Ruolo? ruoloCambiLibero,
});

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

// Rotazione oraria a un sideout: chi era in posizione p+1 va in p. Stessa
// logica di ricalcola_stato.dart / trajectory_report_screen.dart.
Map<int, int> _ruotata(Map<int, int> rot) =>
    {for (var p = 1; p <= 6; p++) p: rot[(p % 6) + 1]!};

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
  List<Player>? _giocatori; // roster della squadra (per il filtro)
  Map<int, _Formazione>? _formazioni; // setId -> formazione di partenza

  int? _setSelezionato; // null = Partita intera (default)
  int? _giocatoreSelezionato; // null = Tutti (default)
  int? _setDistribuzione; // null = Partita intera — sezione distribuzione alzate

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
    final giocatori = team == null
        ? <Player>[]
        : await ref.read(teamRepositoryProvider).getPlayersForTeam(team.id);
    final sets = await setRepo.caricaSetsPartita(widget.match.id);

    final righeSet = <_RigaSet>[];
    final azioniPerSet = <int, List<ScoutAction>>{};
    final formazioni = <int, _Formazione>{};
    for (final set in sets) {
      final stato = await setRepo.calcolaStatoFinale(set);
      final azioni = await azioniRepo.caricaAzioni(set.id);
      azioniPerSet[set.id] = azioni;
      final formazione = await setRepo.caricaFormazione(set.id);
      if (formazione != null) formazioni[set.id] = formazione;
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
      _giocatori = giocatori;
      _formazioni = formazioni;
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
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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

  // Giocatori con almeno un'azione di scout nella partita (per il dropdown
  // di filtro) — lista match-wide, non set-scoped, così la selezione resta
  // valida anche cambiando set. Ordinati per numero (getPlayersForTeam).
  List<Player> get _giocatoriConAzioni {
    final azioniPerSet = _azioniPerSet;
    final giocatori = _giocatori;
    if (azioniPerSet == null || giocatori == null) return const [];
    final ids = <int>{
      for (final azioni in azioniPerSet.values)
        for (final a in azioni)
          if (a.tipo == TipoAzione.scout && a.giocatoreId != null)
            a.giocatoreId!,
    };
    return [
      for (final p in giocatori)
        if (ids.contains(p.id)) p,
    ];
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
        // Il filtro giocatore conta solo le SUE azioni, ma `ultimoTipo`
        // (contesto dello scambio per la classifica attacco su ricezione/
        // difesa) va aggiornato su TUTTI i giocatori: chi riceve/difende
        // può essere diverso da chi attacca.
        final delGiocatore =
            _giocatoreSelezionato == null ||
            azione.giocatoreId == _giocatoreSelezionato;
        switch (fondamentale) {
          case Fondamentale.battuta:
            if (delGiocatore) incrementa('battuta', voto);
          case Fondamentale.ricezione:
            if (delGiocatore) incrementa('ricezione', voto);
            ultimoTipo = Fondamentale.ricezione;
          case Fondamentale.difesa:
            if (delGiocatore) incrementa('difesa', voto);
            ultimoTipo = Fondamentale.difesa;
          case Fondamentale.attacco:
            if (delGiocatore) {
              incrementa('attacco', voto);
              // Ragionamento per fasi, non per fondamentale: l'attacco "su
              // ricezione" è sempre il primo dopo un voto di ricezione
              // nello stesso scambio — tutti gli altri (dopo una difesa,
              // dopo un altro attacco, o senza alcun contesto registrato)
              // sono "su Difesa". Partizione binaria: la somma dei due
              // torna sempre il totale "Attacco".
              if (ultimoTipo == Fondamentale.ricezione) {
                incrementa('attaccoSuRicezione', voto);
              } else {
                incrementa('attaccoSuDifesa', voto);
              }
            }
          case Fondamentale.muro:
            if (delGiocatore) incrementa('muro', voto);
          case Fondamentale.alzata:
            if (delGiocatore) incrementa('alzata', voto);
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

  // Conta i punti/errori generici (bottoni rapidi: tipo puntoManuale /
  // erroreGenerico, senza giocatore) nello scope del set selezionato. Il
  // filtro giocatore non si applica — questi eventi non hanno un giocatore.
  // Per gli errori avversari raggruppa per MotivoErrore (colonna
  // polimorfica `tipoEsecuzione`; valori non riconosciuti → generico).
  _RiepilogoGenerici get _riepilogoGenerici {
    var puntiNostri = 0,
        erroriNostri = 0,
        puntiAvversari = 0,
        erroriAvversari = 0;
    final motivi = <MotivoErrore, int>{};
    for (final azioniSet in _listeAzioniNelloScope) {
      for (final a in azioniSet) {
        if (a.tipo == TipoAzione.puntoManuale) {
          if (a.squadra == Squadra.nostra) {
            puntiNostri++;
          } else {
            puntiAvversari++;
          }
        } else if (a.tipo == TipoAzione.erroreGenerico) {
          if (a.squadra == Squadra.nostra) {
            erroriNostri++;
          } else {
            erroriAvversari++;
            final m = _motivoDa(a.tipoEsecuzione);
            motivi[m] = (motivi[m] ?? 0) + 1;
          }
        }
      }
    }
    return (
      puntiNostri: puntiNostri,
      erroriNostri: erroriNostri,
      puntiAvversari: puntiAvversari,
      erroriAvversari: erroriAvversari,
      motiviAvversari: motivi,
    );
  }

  MotivoErrore _motivoDa(String tipoEsecuzione) {
    for (final m in MotivoErrore.values) {
      if (m.name == tipoEsecuzione) return m;
    }
    return MotivoErrore.generico; // 'nonSpecificato' o valori legacy
  }

  // Distribuzione delle alzate per zona (P1..P6), dedotta dalla posizione di
  // rotazione dell'attaccante al momento di ogni attacco: replay set per set
  // (rotazione iniziale da caricaFormazione + sideout/cambi, stessa logica di
  // ricalcolaStato). Scope dal selettore `_setDistribuzione`.
  ({Map<String, int> conteggi, int totale}) get _distribuzioneAlzate {
    final conteggi = <String, int>{
      'P1': 0, 'P2': 0, 'P3': 0, 'P4': 0, 'P5': 0, 'P6': 0,
    };
    final formazioni = _formazioni;
    final azioniPerSet = _azioniPerSet;
    final sets = _sets;
    if (formazioni != null && azioniPerSet != null && sets != null) {
      for (final set in sets) {
        if (_setDistribuzione != null && set.numero != _setDistribuzione) {
          continue;
        }
        final f = formazioni[set.id];
        final azioni = azioniPerSet[set.id];
        if (f == null || azioni == null) continue;

        // Rotazione iniziale: posizione (1-6) → giocatoreId.
        var rot = <int, int>{};
        for (final e in f.assignments.entries) {
          final pos =
              e.key.startsWith('P') ? int.tryParse(e.key.substring(1)) : null;
          if (pos != null) rot[pos] = e.value.id;
        }
        var nostraAlServizio = set.squadraServizioIniziale == Squadra.nostra;
        final ordinate = [...azioni]..sort((a, b) => a.ordine.compareTo(b.ordine));

        for (final a in ordinate) {
          // Cambio giocatore: il subentrante prende la posizione dell'uscente
          // (no-op se duplicherebbe), stessa guardia di ricalcolaStato.
          if (a.tipo == TipoAzione.cambioGiocatore &&
              a.giocatoreId != null &&
              a.giocatoreUscenteId != null) {
            final entra = a.giocatoreId!;
            final esce = a.giocatoreUscenteId!;
            if (!(esce != entra && rot.containsValue(entra))) {
              rot = {
                for (final e in rot.entries)
                  e.key: e.value == esce ? entra : e.value,
              };
            }
          }

          // Attribuisci l'attacco alla zona dell'attaccante PRIMA di applicare
          // l'esito (l'attacco avviene durante il rally, prima del sideout).
          if (a.tipo == TipoAzione.scout &&
              a.fondamentale == Fondamentale.attacco &&
              a.giocatoreId != null) {
            for (final e in rot.entries) {
              if (e.value == a.giocatoreId) {
                conteggi['P${e.key}'] = conteggi['P${e.key}']! + 1;
                break;
              }
            }
          }

          if (a.esitoPunto == EsitoPunto.puntoNostro && !nostraAlServizio) {
            rot = _ruotata(rot);
            nostraAlServizio = true;
          } else if (a.esitoPunto == EsitoPunto.puntoNostro) {
            nostraAlServizio = true;
          } else if (a.esitoPunto == EsitoPunto.puntoAvversario) {
            nostraAlServizio = false;
          }
        }
      }
    }
    final totale = conteggi.values.fold(0, (s, v) => s + v);
    return (conteggi: conteggi, totale: totale);
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
    final nomeAvversario = (avversario != null && avversario.isNotEmpty)
        ? avversario
        : 'Avversari';
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
              Text(
                widget.match.nome,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(dataOraStr, style: Theme.of(context).textTheme.bodyLarge),
              if (widget.match.palestra != null &&
                  widget.match.palestra!.trim().isNotEmpty)
                Text(
                  widget.match.palestra!.trim(),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              const SizedBox(height: 32),
              Text(
                'Punteggio finale',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          nomeNostro,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
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
              Text(
                'Punteggio per set',
                style: Theme.of(context).textTheme.titleLarge,
              ),
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
                        tileColor: const Color.fromARGB(255, 213, 242, 255),
                        title: const Text(
                          'Totale',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
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
              Text(
                'Riepilogo fondamentali',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
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
                  SizedBox(
                    width: 260,
                    child: DropdownButtonFormField<int?>(
                      initialValue: _giocatoreSelezionato,
                      decoration: const InputDecoration(
                        labelText: 'Giocatore',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Tutti'),
                        ),
                        for (final p in _giocatoriConAzioni)
                          DropdownMenuItem(
                            value: p.id,
                            child: Text('${p.numero} ${p.cognome}'),
                          ),
                      ],
                      onChanged: (v) =>
                          setState(() => _giocatoreSelezionato = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildTabellaFondamentali(_riepilogoFondamentali),
              const SizedBox(height: 32),
              Text(
                'Punti ed errori generici',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              _buildSpecchiettoGenerici(
                _riepilogoGenerici,
                nomeNostro: nomeNostro,
                nomeAvversario: nomeAvversario,
              ),
              // Le traiettorie hanno filtri propri (set/giocatore, +rotazione
              // per l'attacco): si aprono nella schermata dedicata. Solo con
              // una squadra risolta — senza roster non c'è nulla su cui
              // filtrare (teamId può essere rimasto null, vedi _carica).
              if (_team != null) ...[
                const SizedBox(height: 32),
                Text(
                  'Traiettorie',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Traiettorie battute'),
                      onPressed: () => _apriTraiettorie(Fondamentale.battuta),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.trending_up),
                      label: const Text('Traiettorie attacco'),
                      onPressed: () => _apriTraiettorie(Fondamentale.attacco),
                    ),
                  ],
                ),
              ],
              if (_formazioni != null && _formazioni!.isNotEmpty) ...[
                const SizedBox(height: 32),
                Text(
                  'Formazioni di partenza',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, c) {
                    const spacing = 16.0;
                    // Tre card affiancate per riga.
                    final cardWidth = (c.maxWidth - 2 * spacing) / 3;
                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        for (final s in sets)
                          if (_formazioni![s.id] != null)
                            SizedBox(
                              width: cardWidth,
                              child: _buildFormazioneSet(
                                s.numero,
                                _formazioni![s.id]!,
                                servizio: s.squadraServizioIniziale,
                              ),
                            ),
                      ],
                    );
                  },
                ),
              ],
              const SizedBox(height: 32),
              Text(
                'Distribuzione alzate',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<int?>(
                  initialValue: _setDistribuzione,
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
                  onChanged: (v) => setState(() => _setDistribuzione = v),
                ),
              ),
              const SizedBox(height: 8),
              _buildDistribuzioneCourt(_distribuzioneAlzate),
            ],
          ),
        ),
      ),
    );
  }

  // Formazione di partenza di un set: card con campo read-only (CourtView,
  // slot P1–P6) + didascalia con il/i libero/i e la coppia che
  // sostituiscono. Il campo è renderizzato a 460×460 e scalato con FittedBox
  // (CourtView ha margini fissi in px, non regge un SizedBox più piccolo). Il
  // libero non è disegnato sul campo (CourtView rende solo P1–P6).
  Widget _buildFormazioneSet(
    int numero,
    _Formazione f, {
    required Squadra servizio,
  }) {
    final liberi = [f.assignments['L1'], f.assignments['L2']]
        .whereType<Player>()
        .toList();
    final cambi = f.ruoloCambiLibero; // centrale/schiacciatore, o null
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icona pallone a destra solo se la battuta iniziale del set era
            // nostra (la card mostra la nostra formazione).
            Row(
              children: [
                Text('Set $numero - ${f.palleggiatoreSlot}',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (servizio == Squadra.nostra)
                  const Icon(Icons.sports_volleyball, size: 20),
              ],
            ),
            const SizedBox(height: 6),
            AspectRatio(
              aspectRatio: 1,
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: 460,
                  height: 460,
                  child: CourtView(
                    assignments: f.assignments,
                    selectedSlots: {f.palleggiatoreSlot},
                    selectionColor: Colors.red,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            if (liberi.isNotEmpty)
              Text(
                'Libero: ${liberi.map((p) => '${p.numero} ${p.cognome}').join(' · ')}'
                '${cambi != null ? ' — cambi: ${cambi.label}' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  // Campo a piena dimensione (come un singolo set) con la % di alzate per
  // zona: riusa CourtView (stessa geometria/posizione delle card giocatore)
  // con un contenuto per slot che mostra la percentuale. La % è sul totale
  // degli attacchi nello scope; il numero sotto è il conteggio di quella zona.
  Widget _buildDistribuzioneCourt(
      ({Map<String, int> conteggi, int totale}) d) {
    if (d.totale == 0) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Nessun attacco registrato per lo scope selezionato.'),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, c) {
            const spacing = 16.0;
            // Stessa larghezza di una card di formazione ("un singolo set"),
            // allineata a sinistra; renderizzata a 460 e scalata come quelle,
            // così le celle mantengono le stesse proporzioni.
            final size = (c.maxWidth - 2 * spacing) / 3;
            return Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: size,
                height: size,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: 460,
                    height: 460,
                    child: CourtView(
                      assignments: const {},
                      slotContent: {
                        for (final slot in const ['P1', 'P2', 'P3', 'P4', 'P5', 'P6'])
                          slot: _cellaPercentuale(slot, d),
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Contenuto di una cella della distribuzione: percentuale grande al centro
  // e conteggio sotto, stesso stile della card giocatore (numero 31 +
  // secondario 13, vedi CourtView._slotPlayer).
  Widget _cellaPercentuale(
      String slot, ({Map<String, int> conteggi, int totale}) d) {
    final count = d.conteggi[slot] ?? 0;
    final pct = d.totale == 0 ? 0 : (count * 100 / d.totale).round();
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            '$pct%',
            style: const TextStyle(
              fontSize: 31,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  void _apriTraiettorie(Fondamentale fondamentale) {
    final team = _team;
    if (team == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TrajectoryReportScreen(
          match: widget.match,
          team: team,
          fondamentale: fondamentale,
          // Dal report (partita finita) parti da tutti i set, non dal corrente.
          setCorrenteAllAvvio: false,
        ),
      ),
    );
  }

  Widget _buildTabellaFondamentali(List<_RigaFondamentale> righe) {
    const voti = Voto.values;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Table(
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
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 8,
                    ),
                    child: Text(
                      righe[i].label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  for (final v in voti)
                    _votoCell(righe[i].conteggi[v] ?? 0, righe[i].totale, v),
                  _totaleCell(righe[i].totale),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // Specchietto punti/errori generici: tabella 2 colonne (Nostri/Avversari)
  // per punti e errori, più la scomposizione per motivo degli errori
  // avversari se ce ne sono.
  Widget _buildSpecchiettoGenerici(
    _RiepilogoGenerici r, {
    required String nomeNostro,
    required String nomeAvversario,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2.4),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1),
              },
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: AppColors.surfaceDim),
                  children: [
                    _headerCell('', allineaSinistra: true),
                    _headerCell(nomeNostro),
                    _headerCell(nomeAvversario),
                  ],
                ),
                TableRow(
                  decoration: const BoxDecoration(color: Colors.white),
                  children: [
                    _labelCell('Punti generici'),
                    _totaleCell(r.puntiNostri),
                    _totaleCell(r.puntiAvversari),
                  ],
                ),
                TableRow(
                  decoration: const BoxDecoration(color: AppColors.surface),
                  children: [
                    _labelCell('Errori generici'),
                    _totaleCell(r.erroriNostri),
                    _totaleCell(r.erroriAvversari),
                  ],
                ),
              ],
            ),
            if (r.erroriAvversari > 0) ...[
              const SizedBox(height: 16),
              Text(
                'Tipologia errori avversari',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  for (final m in MotivoErrore.values)
                    _motivoChip(m.label, r.motiviAvversari[m] ?? 0),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _labelCell(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
    child: Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
    ),
  );

  Widget _motivoChip(String label, int count) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: AppColors.surfaceDim),
    ),
    child: Text(
      '$label: $count',
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
    ),
  );

  Widget _headerCell(
    String text, {
    bool allineaSinistra = false,
    double? fontSize,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text('$pct%', style: TextStyle(color: color, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _totaleCell(int totale) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Center(
      child: Text(
        '$totale',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    ),
  );
}

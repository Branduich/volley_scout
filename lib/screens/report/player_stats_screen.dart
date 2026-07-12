import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../models/enums.dart';
import '../../providers/database_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/court_style.dart';

// `murati`: attacchi con muro punto subito (voto `=` + tocco a muro + palla
// tornata nel campo dell'attaccante — vedi attaccoMurato in
// database_provider.dart). Sempre 0 per i fondamentali diversi dall'attacco.
typedef _RigaGiocatore = ({
  Player player,
  Map<Voto, int> conteggi,
  int totale,
  int murati,
});

/// Filtro aggiuntivo, solo per il fondamentale attacco: tutti gli attacchi
/// (default), solo quelli su ricezione o solo quelli su difesa — la
/// classificazione è dedotta dalla sequenza dello scambio (vedi
/// `idAttacchiSuRicezione` in database_provider.dart, stessa regola del
/// riepilogo fondamentali di MatchReportScreen).
enum _FiltroAttacco {
  tutti('Tutti gli attacchi'),
  suRicezione('Su ricezione'),
  suDifesa('Su difesa');

  final String label;
  const _FiltroAttacco(this.label);
}

/// Statistiche per giocatore e per fondamentale (Fase 4) — consultabile sia
/// a partita terminata sia **durante una partita in corso** (raggiunta dal
/// drawer di utilità di `ScoutScreen`, icona statistiche). Set per set (o
/// "Partita intera"), tabella dei giocatori che hanno registrato almeno un
/// voto nel fondamentale selezionato. Dati caricati una volta (one-shot,
/// niente stream): cambiare set/fondamentale ricalcola solo in memoria.
class PlayerStatsScreen extends ConsumerStatefulWidget {
  final VolleyMatch match;
  final Team team;
  const PlayerStatsScreen({super.key, required this.match, required this.team});

  @override
  ConsumerState<PlayerStatsScreen> createState() => _PlayerStatsScreenState();
}

class _PlayerStatsScreenState extends ConsumerState<PlayerStatsScreen> {
  List<MatchSet>? _sets;
  Map<int, List<ScoutAction>>? _azioniPerSet; // setId -> azioni
  List<Player>? _giocatori;

  int? _setSelezionato; // null = Partita intera
  Fondamentale _fondamentale = Fondamentale.battuta;
  _FiltroAttacco _filtroAttacco = _FiltroAttacco.tutti; // solo per attacco

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    final setRepo = ref.read(matchSetRepositoryProvider);
    final azioniRepo = ref.read(scoutActionRepositoryProvider);
    final sets = await setRepo.caricaSetsPartita(widget.match.id);
    final azioniPerSet = <int, List<ScoutAction>>{};
    for (final set in sets) {
      azioniPerSet[set.id] = await azioniRepo.caricaAzioni(set.id);
    }
    final giocatori =
        await ref.read(teamRepositoryProvider).getPlayersForTeam(widget.team.id);
    if (!mounted) return;
    setState(() {
      _sets = sets;
      _azioniPerSet = azioniPerSet;
      _giocatori = giocatori;
      // Default: il set più recente (durante una partita in corso è il set
      // attualmente in gioco; a fine partita, l'ultimo giocato).
      _setSelezionato = sets.isEmpty ? null : sets.last.numero;
    });
  }

  List<ScoutAction> get _azioniNelloScope {
    final azioniPerSet = _azioniPerSet;
    final sets = _sets;
    if (azioniPerSet == null || sets == null) return const [];
    if (_setSelezionato == null) {
      return azioniPerSet.values.expand((azioni) => azioni).toList();
    }
    MatchSet? set;
    for (final s in sets) {
      if (s.numero == _setSelezionato) {
        set = s;
        break;
      }
    }
    if (set == null) return const [];
    return azioniPerSet[set.id] ?? const [];
  }

  List<_RigaGiocatore> get _righe {
    // Classificazione degli attacchi (solo se serve al filtro): calcolata su
    // TUTTI i set — dipende dalla sequenza dello scambio, non dallo scope.
    final filtroAttivo =
        _fondamentale == Fondamentale.attacco &&
            _filtroAttacco != _FiltroAttacco.tutti;
    final suRicezione = filtroAttivo
        ? idAttacchiSuRicezione((_azioniPerSet ?? const {}).values)
        : const <int>{};

    final perGiocatore = <int, Map<Voto, int>>{};
    final muratiPerGiocatore = <int, int>{};
    for (final azione in _azioniNelloScope) {
      if (azione.tipo != TipoAzione.scout) continue;
      if (azione.fondamentale != _fondamentale) continue;
      if (filtroAttivo &&
          suRicezione.contains(azione.id) !=
              (_filtroAttacco == _FiltroAttacco.suRicezione)) {
        continue;
      }
      final giocatoreId = azione.giocatoreId;
      final voto = azione.voto;
      if (giocatoreId == null || voto == null) continue;
      final conteggi = perGiocatore.putIfAbsent(giocatoreId, () => {});
      conteggi[voto] = (conteggi[voto] ?? 0) + 1;
      if (attaccoMurato(azione)) {
        muratiPerGiocatore[giocatoreId] =
            (muratiPerGiocatore[giocatoreId] ?? 0) + 1;
      }
    }
    final righe = <_RigaGiocatore>[];
    for (final player in _giocatori ?? const <Player>[]) {
      final conteggi = perGiocatore[player.id];
      if (conteggi == null) continue; // nessun voto in questo scope/fondamentale
      final totale = conteggi.values.fold(0, (a, b) => a + b);
      righe.add((
        player: player,
        conteggi: conteggi,
        totale: totale,
        murati: muratiPerGiocatore[player.id] ?? 0,
      ));
    }
    righe.sort((a, b) => a.player.numero.compareTo(b.player.numero));
    return righe;
  }

  @override
  Widget build(BuildContext context) {
    final sets = _sets;
    return Scaffold(
      appBar: AppBar(title: Text(widget.team.nome)),
      body: sets == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 200,
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
                      const SizedBox(width: AppSpacing.md),
                      SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<Fondamentale>(
                          initialValue: _fondamentale,
                          decoration: const InputDecoration(
                            labelText: 'Fondamentale',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            for (final f in const [
                              Fondamentale.battuta,
                              Fondamentale.ricezione,
                              Fondamentale.difesa,
                              Fondamentale.attacco,
                              Fondamentale.muro,
                              Fondamentale.alzata,
                            ])
                              DropdownMenuItem(value: f, child: Text(f.label)),
                          ],
                          onChanged: (v) => setState(() {
                            _fondamentale = v!;
                            // Il filtro attacchi vale solo per l'attacco:
                            // cambiando fondamentale riparte da "tutti".
                            _filtroAttacco = _FiltroAttacco.tutti;
                          }),
                        ),
                      ),
                      if (_fondamentale == Fondamentale.attacco) ...[
                        const SizedBox(width: AppSpacing.md),
                        SizedBox(
                          width: 220,
                          child: DropdownButtonFormField<_FiltroAttacco>(
                            initialValue: _filtroAttacco,
                            decoration: const InputDecoration(
                              labelText: 'Attacchi',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (final f in _FiltroAttacco.values)
                                DropdownMenuItem(
                                    value: f, child: Text(f.label)),
                            ],
                            onChanged: (v) =>
                                setState(() => _filtroAttacco = v!),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Expanded(
                    child: _righe.isEmpty
                        ? const Center(child: Text('Nessun voto registrato.'))
                        : SingleChildScrollView(child: _buildTabella(_righe)),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTabella(List<_RigaGiocatore> righe) {
    const voti = Voto.values;
    // Colonna "Murati" solo per l'attacco (sottoinsieme degli errori `=`,
    // deducibile dalla traiettoria — vedi attaccoMurato).
    final mostraMurati = _fondamentale == Fondamentale.attacco;
    final totaliPerVoto = <Voto, int>{};
    var totaleComplessivo = 0;
    var totaleMurati = 0;
    for (final riga in righe) {
      for (final v in voti) {
        totaliPerVoto[v] = (totaliPerVoto[v] ?? 0) + (riga.conteggi[v] ?? 0);
      }
      totaleComplessivo += riga.totale;
      totaleMurati += riga.murati;
    }
    return Table(
      columnWidths: {
        0: const FlexColumnWidth(2.6),
        for (var i = 1; i <= voti.length; i++) i: const FlexColumnWidth(1),
        if (mostraMurati) voti.length + 1: const FlexColumnWidth(1),
        (mostraMurati ? voti.length + 2 : voti.length + 1):
            const FlexColumnWidth(1), // TOT
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(color: AppColors.surfaceDim),
          children: [
            _headerCell('Giocatori', allineaSinistra: true),
            for (final v in voti) _headerCell(v.simbolo, fontSize: 28),
            if (mostraMurati) _headerCell('Murati'),
            _headerCell('TOT'),
          ],
        ),
        for (var i = 0; i < righe.length; i++)
          TableRow(
            decoration: BoxDecoration(
              color: i.isEven ? Colors.white : AppColors.surface,
            ),
            children: [
              _giocatoreCell(righe[i].player),
              for (final v in voti)
                _votoCell(righe[i].conteggi[v] ?? 0, righe[i].totale, v),
              if (mostraMurati)
                _muratiCell(righe[i].murati, righe[i].totale),
              _totaleCell(righe[i].totale),
            ],
          ),
        TableRow(
          decoration: const BoxDecoration(color: AppColors.surfaceDim),
          children: [
            _headerCell('Totale', allineaSinistra: true),
            for (final v in voti)
              _votoCell(totaliPerVoto[v] ?? 0, totaleComplessivo, v),
            if (mostraMurati) _muratiCell(totaleMurati, totaleComplessivo),
            _totaleCell(totaleComplessivo),
          ],
        ),
      ],
    );
  }

  // Conteggio murati + percentuale sul totale attacchi del giocatore —
  // stesso layout di _votoCell, colore neutro (il rosso è già dell'errore,
  // di cui i murati sono un sottoinsieme).
  Widget _muratiCell(int count, int totale) {
    final pct = totale == 0 ? 0 : (count * 100 / totale).round();
    // Stesso neutro scurito del 15% dei voti neutri (mezzoPunto/negativo),
    // per coerenza dei grigi nella tabella.
    final coloreMurati = AppColors.darken(AppColors.neutral, 0.15);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$count',
              style: TextStyle(
                  color: coloreMurati,
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
          Text('$pct%',
              style: TextStyle(color: coloreMurati, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _headerCell(String text,
          {bool allineaSinistra = false, double? fontSize}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Text(
          text,
          textAlign: allineaSinistra ? TextAlign.left : TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize),
        ),
      );

  Widget _giocatoreCell(Player p) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        // Nome sopra, ruolo sotto (come conteggio/percentuale in _votoCell).
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(children: [
                TextSpan(text: '${p.numero}'),
                // Spazio extra tra numero e cognome (WidgetSpan così il
                // testo continua a poter andare a capo se lungo).
                const WidgetSpan(child: SizedBox(width: 10)),
                TextSpan(text: p.cognome),
              ]),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            Text(
              p.ruolo.label,
              style: const TextStyle(color: Colors.black54, fontSize: 14),
            ),
          ],
        ),
      );

  // Colori dei voti scuriti del 15% (HSL) SOLO in questa tabella — più
  // leggibili sulle righe chiare — senza toccare CourtStyle.votoColor, che
  // resta condiviso con scout/report/PDF.
  Color _coloreVoto(Voto voto) =>
      AppColors.darken(CourtStyle.votoColor(voto), 0.15);

  Widget _votoCell(int count, int totale, Voto voto) {
    final pct = totale == 0 ? 0 : (count * 100 / totale).round();
    final color = _coloreVoto(voto);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$count',
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 18)),
          Text('$pct%', style: TextStyle(color: color, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _totaleCell(int totale) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Center(
          child: Text('$totale',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ),
      );
}

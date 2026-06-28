import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../providers/database_provider.dart';

// Punteggio finale (eventi + correzione manuale) di un singolo set, già
// pronto per la visualizzazione — vedi _MatchReportScreenState._carica.
typedef _RigaSet = ({int numero, int nostro, int avversario});

({Team? team, List<_RigaSet> set}) _datiVuoti() => (team: null, set: const []);

/// Report di una partita (Fase 4) — pagina 1: dati partita, punteggio
/// finale (set vinti) e punteggio di ogni set. Niente statistiche per
/// giocatore o traiettorie per ora (vedi CLAUDE.md).
class MatchReportScreen extends ConsumerWidget {
  final VolleyMatch match;
  const MatchReportScreen({super.key, required this.match});

  Future<({Team? team, List<_RigaSet> set})> _carica(WidgetRef ref) async {
    final setRepo = ref.read(matchSetRepositoryProvider);
    final teamId = match.teamId;
    var team =
        teamId == null ? null : await ref.read(teamRepositoryProvider).getTeam(teamId);
    // Partite giocate prima del fix di TeamSelectionScreen possono avere
    // teamId rimasto null pur avendo una squadra realmente selezionata —
    // vedi MatchSetRepository.inferisciSquadraDaRotazioni.
    team ??= await setRepo.inferisciSquadraDaRotazioni(match.id);
    final sets = await setRepo.caricaSetsPartita(match.id);

    final righe = <_RigaSet>[];
    for (final set in sets) {
      final stato = await setRepo.calcolaStatoFinale(set);
      righe.add((
        numero: set.numero,
        nostro: stato.punteggioNostro + set.correzionePuntiNostri,
        avversario: stato.punteggioAvversario + set.correzionePuntiAvversari,
      ));
    }
    return (team: team, set: righe);
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avversario = match.avversario?.trim();
    final nomeAvversario =
        (avversario != null && avversario.isNotEmpty) ? avversario : 'Avversari';
    final dt = match.dataOra;
    final dataOraStr =
        '${_pad(dt.day)}/${_pad(dt.month)}/${dt.year} ${_pad(dt.hour)}:${_pad(dt.minute)}';

    return Scaffold(
      appBar: AppBar(title: const Text('Report partita')),
      body: FutureBuilder(
        future: _carica(ref),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final dati = snapshot.data ?? _datiVuoti();
          final nomeNostro = dati.team?.nome ?? 'Nostra squadra';

          var setVintiNostri = 0;
          var setVintiAvversario = 0;
          for (final riga in dati.set) {
            if (riga.nostro > riga.avversario) setVintiNostri++;
            if (riga.avversario > riga.nostro) setVintiAvversario++;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$nomeNostro - $nomeAvversario',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(match.nome, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(dataOraStr, style: Theme.of(context).textTheme.bodyLarge),
                  if (match.palestra != null && match.palestra!.trim().isNotEmpty)
                    Text(match.palestra!.trim(),
                        style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 32),
                  Text('Punteggio finale',
                      style: Theme.of(context).textTheme.titleLarge),
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
                  Text('Punteggio per set',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  if (dati.set.isEmpty)
                    const Text('Nessun set giocato.')
                  else
                    Card(
                      child: Column(
                        children: [
                          for (final riga in dati.set) ...[
                            ListTile(
                              title: Text('Set ${riga.numero}'),
                              trailing: Text(
                                '${riga.nostro} - ${riga.avversario}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                            if (riga != dati.set.last) const Divider(height: 1),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

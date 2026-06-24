import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../models/enums.dart';
import '../../providers/database_provider.dart';
import 'lineup_screen.dart';

const _kBg = Color(0xFF143E59);

/// Schermata "fine set", raggiunta dal drawer di utilità di `ScoutScreen`
/// (voce "Fine"). Placeholder essenziale: due bottoni — "Prossimo Set"
/// (incrementa `VolleyMatch.setCorrente` e riparte da zero dalla scelta
/// della formazione, nessuna formazione precompilata: in pallavolo si può
/// cambiare rotazione/formazione tra un set e l'altro) e "Fine Partita"
/// (segna la partita come `terminata` e torna a `MatchesScreen`). In Fase 4
/// diventerà probabilmente la pagina delle statistiche del set — per ora
/// resta un placeholder, il salvataggio dei punteggi è da decidere a parte.
class EndSetScreen extends ConsumerWidget {
  final VolleyMatch match;
  final Team team;

  const EndSetScreen({super.key, required this.match, required this.team});

  Future<bool> _confermaDialog(
      BuildContext context, String titolo, String testo) async {
    final confermato = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titolo),
        content: Text(testo),
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
    return confermato ?? false;
  }

  Future<void> _prossimoSet(BuildContext context, WidgetRef ref) async {
    final confermato = await _confermaDialog(
      context,
      'Iniziare il prossimo set?',
      'Il set corrente verrà chiuso e si ripartirà dalla scelta della '
          'formazione (nessuna formazione precompilata).',
    );
    if (!confermato || !context.mounted) return;
    final nuovoMatch = match.copyWith(setCorrente: match.setCorrente + 1);
    await ref.read(matchRepositoryProvider).updateMatch(nuovoMatch);
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LineupScreen(match: nuovoMatch, team: team),
      ),
    );
  }

  Future<void> _finePartita(BuildContext context, WidgetRef ref) async {
    final confermato = await _confermaDialog(
      context,
      'Terminare la partita?',
      'La partita verrà segnata come terminata.',
    );
    if (!confermato || !context.mounted) return;
    await ref
        .read(matchRepositoryProvider)
        .updateMatch(match.copyWith(stato: StatoPartita.terminata));
    if (!context.mounted) return;
    // Pop fino a MatchesScreen (vedi RouteSettings(name: '/matches') in
    // main.dart) — robusto a quante schermate si siano accumulate nello
    // stack per i set precedenti (LineupScreen/FormationConfigScreen/
    // ScoutScreen/EndSetScreen ripetuti ad ogni "Prossimo Set").
    Navigator.popUntil(context, ModalRoute.withName('/matches'));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        foregroundColor: Colors.white,
        title: const Text('Fine set'),
      ),
      body: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 220,
              height: 64,
              child: FilledButton(
                onPressed: () => _prossimoSet(context, ref),
                child: const Text('Prossimo Set',
                    style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 24),
            SizedBox(
              width: 220,
              height: 64,
              child: FilledButton(
                style:
                    FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => _finePartita(context, ref),
                child: const Text('Fine Partita',
                    style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/enums.dart';
import '../providers/database_provider.dart';
import '../providers/settings_provider.dart';
import '../screens/live/scout_screen.dart';
import 'tutorial_controller.dart';
import 'tutorial_sandbox.dart';

/// Avvia il tutorial: semina la partita di prova, apre la VERA `ScoutScreen`
/// in modalità tutorial e, al ritorno (qualunque sia la via d'uscita — back di
/// sistema, "Indietro" nel drawer, "X" sulla card, ultimo passo), cancella
/// tutto.
///
/// Unico punto dell'app che sa dell'esistenza della sandbox: `ScoutScreen`
/// riceve dati come se fossero quelli di una partita vera.
Future<void> avviaTutorial(BuildContext context, WidgetRef ref) async {
  // Preso PRIMA degli await: i passi si costruiscono già tradotti, e usare
  // `context` dopo un await farebbe scattare use_build_context_synchronously.
  final l = AppLocalizations.of(context);
  final db = ref.read(appDatabaseProvider);
  final prefs = ref.read(sharedPreferencesProvider);
  final dati = await TutorialSandbox.semina(db, prefs, l);

  // Formazione ricostruita dal DB con lo stesso percorso di "Riprendi" in
  // MatchesScreen: se un domani cambia il formato, il tutorial lo segue.
  final setRepo = ref.read(matchSetRepositoryProvider);
  final formazione = await setRepo.caricaFormazione(dati.setId);

  if (formazione == null) {
    // Non dovrebbe succedere: la sandbox appena seminata è completa.
    await TutorialSandbox.pulisci(db, prefs);
    return;
  }

  ref.read(tutorialControllerProvider.notifier).inizia(l);
  if (!context.mounted) {
    await TutorialSandbox.pulisci(db, prefs);
    return;
  }

  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ScoutScreen(
        match: dati.match,
        team: dati.team,
        palleggiatoreSlot: formazione.palleggiatoreSlot,
        assignments: formazione.assignments,
        ruoloCambiLibero: formazione.ruoloCambiLibero,
        sistemaGioco:
            formazione.sistemaGioco ?? SistemaGioco.palleggiatoreUnico,
        tutorial: true,
      ),
    ),
  );

  ref.read(tutorialControllerProvider.notifier).termina();
  await TutorialSandbox.pulisci(db, prefs);
}

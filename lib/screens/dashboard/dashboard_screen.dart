import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:volley_stats/volley_stats.dart';
import 'package:volley_ui/pagina_squadra.dart';

import '../../data/backup_json.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/database_provider.dart';
import '../../utils/orientamento.dart';

/// Il backup **in memoria**, costruito dal database del dispositivo.
///
/// Nessun file di mezzo: `leggiTutto()` prende le righe e `costruisciBackup()`
/// — la stessa funzione pura che alimenta l'export — le traduce nei DTO neutri
/// che i widget della dashboard sanno già leggere. È ciò che permette all'app
/// e alla pagina web di mostrare gli **stessi numeri** senza due calcoli.
///
/// `autoDispose`: la fotografia si rifà a ogni apertura della schermata, così
/// chi torna indietro, scouta un set e rientra vede i dati aggiornati. Non è
/// uno stream come il resto dell'app (convenzione #3) di proposito —
/// ricostruire l'intero backup a ogni azione registrata sarebbe uno spreco, e
/// una dashboard di stagione non ha bisogno di aggiornarsi mentre la guardi.
final backupInMemoriaProvider =
    FutureProvider.autoDispose<BackupCompleto>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final righe = await BackupRepository(db).leggiTutto();
  return costruisciBackup(righe, app: '', schemaDb: db.schemaVersion);
});

/// La dashboard di stagione dentro l'app: gli stessi widget della pagina web,
/// sugli stessi dati, senza esportare né caricare niente.
///
/// **Non è una copia della dashboard web**: è letteralmente la stessa
/// `PaginaSquadra`, che vive in `volley_ui`. Se le due divergessero, l'utente
/// vedrebbe numeri diversi a seconda di dove guarda — che è il modo più veloce
/// per non fidarsi più di nessuno dei due.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with OrientamentoSchermata<DashboardScreen> {
  // Si consulta, non si scouta: comoda anche in verticale. Il tabellone scorre
  // in orizzontale e la riga KPI va a capo, quindi reggono lo schermo stretto.
  @override
  List<DeviceOrientation> get orientamentiConsentiti => kOrientamentoTutti;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final backup = ref.watch(backupInMemoriaProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.homeDashboard)),
      body: backup.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('${l.comuneErrore}: $e'),
          ),
        ),
        data: (dati) => dati.partite.isEmpty
            // Senza partite la dashboard sarebbe una sequenza di trattini: chi
            // apre deve capire che manca il presupposto, non che è rotta.
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l.dashboardNessunDato,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              )
            : PaginaSquadra(
                backup: dati,
                // Niente banner della sorgente e niente bottoni per caricare o
                // rimuovere un file: qui i dati sono già quelli del
                // dispositivo, e non c'è nessun documento da gestire.
                mostraSorgente: false,
              ),
      ),
    );
  }
}

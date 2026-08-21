import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:volley_stats/volley_stats.dart';
import 'package:volley_ui/kpi_riga.dart';
import 'package:volley_ui/tabellone_stagionale.dart';

/// Dashboard stagionale (passi 6 e 7 del piano in docs/dati-stagionali.md).
///
/// Carica un backup di esempio come asset e mostra la riga KPI di squadra più
/// il tabellone per giocatrice, ordinabile. Mancano ancora i filtri (7b), il
/// caricamento del file dell'utente (8) e i grafici (9).
void main() => runApp(const DashboardApp());

class DashboardApp extends StatelessWidget {
  const DashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Volley Scout Stratego — Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1E3A8A),
        useMaterial3: true,
      ),
      home: const CaricaBackupDemo(),
    );
  }
}

/// Il **guscio** è l'unico che sa da dove arrivano i dati: qui un asset, al
/// passo 8 un file trascinato dall'utente più IndexedDB, e nella pagina dentro
/// l'app (passo 9b) il database drift. La pagina sotto riceve dati già pronti.
class CaricaBackupDemo extends StatefulWidget {
  const CaricaBackupDemo({super.key});

  @override
  State<CaricaBackupDemo> createState() => _CaricaBackupDemoState();
}

class _CaricaBackupDemoState extends State<CaricaBackupDemo> {
  late final Future<BackupCompleto> _backup = _carica();

  Future<BackupCompleto> _carica() async {
    final testo = await rootBundle.loadString('assets/backup_demo.json');
    // `BackupCompleto.fromJson` è nel package condiviso e fa già i controlli su
    // formato e versione: la dashboard legge gli stessi file che l'app esporta,
    // con lo stesso codice.
    return BackupCompleto.fromJson(jsonDecode(testo) as Map<String, Object?>);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BackupCompleto>(
      future: _backup,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Backup non leggibile: ${snapshot.error}')),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return PaginaSquadra(backup: snapshot.data!, dimostrativo: true);
      },
    );
  }
}

/// La vista di squadra. **Non sa da dove arrivano i dati**: è ciò che le
/// permetterà di finire dentro l'app senza modifiche.
class PaginaSquadra extends StatelessWidget {
  const PaginaSquadra({
    super.key,
    required this.backup,
    this.dimostrativo = false,
  });

  final BackupCompleto backup;

  /// Sta guardando i dati di esempio e non i suoi: va detto, non lasciato
  /// intuire.
  final bool dimostrativo;

  @override
  Widget build(BuildContext context) {
    final riepilogo = riepilogoStagione(backup);
    final squadra = backup.squadre.isEmpty ? '—' : backup.squadre.first.nome;
    final tema = Theme.of(context);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(squadra, style: tema.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              '${dimostrativo ? 'Dati dimostrativi · ' : ''}'
              '${riepilogo.azioni} azioni in ${riepilogo.partite} partite',
              style: tema.textTheme.bodyMedium
                  ?.copyWith(color: tema.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            KpiRiga(kpi: kpiDaRiepilogo(riepilogo)),
            const SizedBox(height: 32),
            Text('Giocatrici', style: tema.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Tocca l\'intestazione di una colonna per ordinare.',
              style: tema.textTheme.bodySmall
                  ?.copyWith(color: tema.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TabelloneStagionale(stats: statGiocatori(backup)),
          ],
        ),
      ),
    );
  }
}

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volley_scout/data/backup_json.dart';
import 'package:volley_scout/data/backup_model.dart';
import 'package:volley_scout/data/backup_share.dart';
import 'package:volley_scout/data/database.dart';
import 'package:volley_scout/data/demo_match_importer.dart';
import 'package:volley_scout/providers/database_provider.dart';

/// `BackupRepository` è il punto in cui l'export tocca il database; la
/// conversione in DTO è già coperta da `test/data/backup_json_test.dart`.
/// Qui interessa che legga DAVVERO tutte le tabelle e che il caso "database
/// vuoto" non produca un file fasullo.
void main() {
  late AppDatabase db;
  late BackupRepository repo;

  setUp(() {
    db = AppDatabase.perTest(NativeDatabase.memory());
    repo = BackupRepository(db);
  });

  tearDown(() async => db.close());

  Future<void> seminaDemo() => DemoMatchImporter(db)
      .importaDaJson(File('assets/demo/demo_match.json').readAsStringSync());

  test('su database vuoto produce un backup valido ma senza partite',
      () async {
    final backup = leggiBackupDaStringa(await repo.esportaTutto());

    expect(backup.partite, isEmpty);
    expect(backup.squadre, isEmpty);
    // Il file resta comunque leggibile: è la condizione che permette alla UI
    // di decidere in base ai conteggi invece che a un errore di parsing.
    expect(backup.formatoVersione, kFormatoVersioneBackup);
  });

  test('i conteggi guidano il messaggio mostrato all\'utente', () async {
    expect((await repo.conteggi()).partite, 0);

    await seminaDemo();
    final dopo = await repo.conteggi();

    expect(dopo.partite, 1);
    expect(dopo.azioni, greaterThan(400));
  });

  test('esporta squadra, giocatrici, set, rotazioni e azioni', () async {
    await seminaDemo();

    final backup = leggiBackupDaStringa(
        await repo.esportaTutto(app: '1.0.0+11'));

    expect(backup.app, '1.0.0+11');
    expect(backup.schemaDb, db.schemaVersion);
    expect(backup.squadre, hasLength(1));
    expect(backup.giocatori.length, greaterThanOrEqualTo(12));

    final partita = backup.partite.single;
    expect(partita.sets, hasLength(5));
    expect(partita.sets.first.rotazioni, hasLength(6));
    expect(partita.sets.expand((s) => s.azioni).length, greaterThan(400));
  });

  test('il nome del file porta la data, così i backup non si sovrascrivono',
      () {
    expect(nomeFileBackup(DateTime(2026, 9, 28)),
        'volley_stratego_backup_2026-09-28.json');
    // Mese e giorno a due cifre: senza padding l'ordinamento alfabetico nella
    // cartella Download mescolerebbe gennaio e ottobre.
    expect(nomeFileBackup(DateTime(2026, 1, 5)),
        'volley_stratego_backup_2026-01-05.json');
  });
}

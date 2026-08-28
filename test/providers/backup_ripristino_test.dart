import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volley_scout/data/backup_json.dart';
import 'package:volley_scout/data/backup_model.dart';
import 'package:volley_scout/data/database.dart';
import 'package:volley_scout/data/demo_match_importer.dart';
import 'package:volley_scout/providers/database_provider.dart';

/// Ripristino "sostituisci tutto" (passo 4a del piano in
/// docs/dati-stagionali.md).
///
/// È il vero collaudo del formato: se il giro completo **attraverso l'app**
/// (database → file → database) è fedele, la dashboard stagionale non potrà
/// trovare buchi. Il test più severo qui non conta le righe: riesporta dopo il
/// ripristino e pretende un file **identico** al primo.
void main() {
  final ancoraFissa = DateTime(2026, 8, 18, 12);

  late AppDatabase origine;
  late AppDatabase destinazione;

  setUp(() {
    origine = AppDatabase.perTest(NativeDatabase.memory());
    destinazione = AppDatabase.perTest(NativeDatabase.memory());
  });

  tearDown(() async {
    await origine.close();
    await destinazione.close();
  });

  Future<void> seminaDemo(AppDatabase db) => DemoMatchImporter(db)
      .importaDaJson(File('packages/volley_stats/assets/backup_demo.json').readAsStringSync());

  /// Export con `esportatoIl` fisso, così due file dello stesso contenuto sono
  /// confrontabili carattere per carattere.
  Future<String> esporta(AppDatabase db) async => codificaBackup(
        costruisciBackup(
          await BackupRepository(db).leggiTutto(),
          app: 'test',
          schemaDb: db.schemaVersion,
          esportatoIl: ancoraFissa,
        ),
      );

  test('database → file → database: il riesportato è IDENTICO', () async {
    await seminaDemo(origine);
    final primo = await esporta(origine);

    await BackupRepository(destinazione)
        .ripristinaSostituendo(leggiBackupDaStringa(primo));

    // Nessuna tolleranza: stesse squadre, stessi giocatori, stessi set, stesse
    // azioni con gli stessi voti, traiettorie e tempi. Se un campo si perdesse
    // nella traduzione uid → id, i due file divergerebbero.
    expect(await esporta(destinazione), primo);
  });

  test('gli uid sopravvivono al ripristino', () async {
    await seminaDemo(origine);
    final backup = leggiBackupDaStringa(await esporta(origine));

    await BackupRepository(destinazione).ripristinaSostituendo(backup);

    final squadre = await destinazione.select(destinazione.teams).get();
    final giocatori = await destinazione.select(destinazione.players).get();
    expect(squadre.single.uid, backup.squadre.single.uid);
    expect(
      giocatori.map((g) => g.uid).toSet(),
      backup.giocatori.map((g) => g.uid).toSet(),
    );
  });

  test('i timestamp delle azioni si ricostruiscono dall\'ancora', () async {
    await seminaDemo(origine);
    final originali = (await origine.select(origine.scoutActions).get())
      ..sort((a, b) => a.ordine.compareTo(b.ordine));

    await BackupRepository(destinazione)
        .ripristinaSostituendo(leggiBackupDaStringa(await esporta(origine)));

    final ripristinate =
        (await destinazione.select(destinazione.scoutActions).get())
          ..sort((a, b) => a.ordine.compareTo(b.ordine));

    expect(ripristinate.length, originali.length);
    // Al secondo: `t` è in secondi, quindi i millisecondi non sopravvivono —
    // ed è una perdita voluta (vedi docs/backup-format.md).
    for (var i = 0; i < originali.length; i++) {
      expect(
        ripristinate[i].timestamp.difference(originali[i].timestamp).inSeconds,
        0,
        reason: 'azione ${originali[i].ordine}: orario diverso',
      );
    }
  });

  test('i riferimenti fra tabelle puntano alle righe giuste', () async {
    await seminaDemo(origine);
    await BackupRepository(destinazione)
        .ripristinaSostituendo(leggiBackupDaStringa(await esporta(origine)));

    final giocatori = await destinazione.select(destinazione.players).get();
    final idValidi = giocatori.map((g) => g.id).toSet();
    final rotazioni = await destinazione.select(destinazione.rotations).get();
    final azioni = await destinazione.select(destinazione.scoutActions).get();

    expect(rotazioni, isNotEmpty);
    // Un id rimasto a puntare al dispositivo di origine sarebbe un riferimento
    // pendente: nessun errore a schermo, statistiche sbagliate mesi dopo.
    for (final r in rotazioni) {
      expect(idValidi, contains(r.giocatoreId));
    }
    for (final a in azioni.where((a) => a.giocatoreId != null)) {
      expect(idValidi, contains(a.giocatoreId));
    }
    // I set puntano ai liberi giusti.
    final sets = await destinazione.select(destinazione.matchSets).get();
    for (final s in sets.where((s) => s.liberoId != null)) {
      expect(idValidi, contains(s.liberoId));
    }
  });

  test('sostituisce davvero: i dati preesistenti spariscono', () async {
    await seminaDemo(origine);
    // La destinazione ha una sua squadra, che il ripristino deve cancellare.
    await destinazione.into(destinazione.teams).insert(
          TeamsCompanion.insert(
            nome: 'Squadra da cancellare',
            categoria: 'Under 16',
            coloreDivisa: 0xFF00FF00,
          ),
        );

    await BackupRepository(destinazione)
        .ripristinaSostituendo(leggiBackupDaStringa(await esporta(origine)));

    final squadre = await destinazione.select(destinazione.teams).get();
    expect(squadre, hasLength(1));
    expect(squadre.single.nome, isNot('Squadra da cancellare'));
  });

  test('il collegamento gara → partita si ricostruisce per uid', () async {
    await seminaDemo(origine);
    // Una qualunque delle cinque partite della stagione di esempio: al
    // collegamento gara -> partita interessa l'uid, non quale sia.
    final partita =
        (await origine.select(origine.volleyMatches).get()).first;
    final campionatoId = await origine.into(origine.campionati).insert(
          CampionatiCompanion.insert(
            nome: 'GIRONE X',
            dataImport: DateTime(2026, 8, 1),
          ),
        );
    await origine.into(origine.gare).insert(
          GareCompanion.insert(
            campionatoId: campionatoId,
            dataOra: DateTime(2026, 10, 12, 11),
            squadraCasa: 'CASA',
            squadraOspite: 'OSPITE',
            matchId: Value(partita.id),
          ),
        );

    await BackupRepository(destinazione)
        .ripristinaSostituendo(leggiBackupDaStringa(await esporta(origine)));

    final gara = await destinazione.select(destinazione.gare).getSingle();
    final partitaNuova = (await destinazione.select(destinazione.volleyMatches).get())
        .firstWhere((p) => p.uid == partita.uid);
    // Gli id sono cambiati, il collegamento no.
    expect(gara.matchId, partitaNuova.id);
    expect(partitaNuova.uid, partita.uid);
  });

  test('riepilogo: partite e data dell\'ultima, per il dialog di conferma',
      () async {
    final repo = BackupRepository(origine);
    expect((await repo.riepilogoCorrente()).vuoto, isTrue);

    await seminaDemo(origine);
    final riepilogo = await repo.riepilogoCorrente();

    expect(riepilogo.vuoto, isFalse);
    expect(riepilogo.partite, 5);
    expect(riepilogo.ultimaPartita, isNotNull);
  });

  test('rileva il file più vecchio di ciò che si ha in app', () {
    final vecchio = RiepilogoDati(
        partite: 8, ultimaPartita: DateTime(2026, 10, 12));
    final recente = RiepilogoDati(
        partite: 11, ultimaPartita: DateTime(2026, 11, 2));

    // È il caso in cui "sostituisci tutto" è quasi sempre un errore: la UI lo
    // tratta a parte invece di annegarlo in un avviso generico.
    expect(vecchio.piuVecchioDi(recente), isTrue);
    expect(recente.piuVecchioDi(vecchio), isFalse);
    // Senza date da confrontare non si allarma nessuno.
    expect(
      const RiepilogoDati(partite: 0).piuVecchioDi(recente),
      isFalse,
    );
  });

  test('un backup vuoto svuota il database, senza errori', () async {
    await seminaDemo(destinazione);

    await BackupRepository(destinazione).ripristinaSostituendo(
      BackupCompleto(
        formatoVersione: kFormatoVersioneBackup,
        schemaDb: 19,
        app: 'test',
        esportatoIl: ancoraFissa,
      ),
    );

    expect(await destinazione.select(destinazione.volleyMatches).get(), isEmpty);
    expect(await destinazione.select(destinazione.scoutActions).get(), isEmpty);
    expect(await destinazione.select(destinazione.teams).get(), isEmpty);
  });
}

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:volley_scout/data/database.dart';
import 'package:volley_scout/models/enums.dart';

/// Migrazione v18 -> v19 (uid stabili) su un database che contiene GIÀ dei
/// dati: è il caso reale di chi aggiorna l'app, e l'unico in cui la migrazione
/// può rompersi (le installazioni pulite passano da createAll).
///
/// Il v18 si ottiene degradando uno schema corrente: si tolgono indice e
/// colonna `uid` e si riporta `user_version` a 18, così alla riapertura drift
/// esegue davvero il ramo `from < 19`.
void main() {
  late Database raw;

  setUp(() => raw = sqlite3.openInMemory());
  tearDown(() => raw.close());

  Future<void> creaSchemaV18ConDati() async {
    final db = AppDatabase.perTest(
        NativeDatabase.opened(raw, closeUnderlyingOnClose: false));
    final teamId = await db.into(db.teams).insert(TeamsCompanion.insert(
          nome: 'Nettunia',
          categoria: 'Under 18',
          coloreDivisa: 0xFF0000FF,
        ));
    for (final numero in [4, 7, 10]) {
      await db.into(db.players).insert(PlayersCompanion.insert(
            teamId: teamId,
            nome: 'Nome$numero',
            cognome: 'Cognome$numero',
            numero: numero,
            ruolo: Ruolo.schiacciatore,
          ));
    }
    for (final n in [1, 2]) {
      await db.into(db.volleyMatches).insert(VolleyMatchesCompanion.insert(
            nome: 'Partita $n',
            dataOra: DateTime(2026, 9, n + 10),
            inCasa: n.isOdd,
            stato: StatoPartita.configurazione,
            setCorrente: 1,
          ));
    }
    await db.close();

    for (final t in ['teams', 'players', 'volley_matches']) {
      raw.execute('DROP INDEX idx_${t}_uid');
      raw.execute('ALTER TABLE $t DROP COLUMN uid');
    }
    raw.execute('PRAGMA user_version = 18');
  }

  test('le righe già esistenti ricevono un uid valido e unico', () async {
    await creaSchemaV18ConDati();

    final db = AppDatabase.perTest(NativeDatabase.opened(raw));
    addTearDown(db.close);

    final squadre = await db.select(db.teams).get();
    final giocatori = await db.select(db.players).get();
    final partite = await db.select(db.volleyMatches).get();

    final hex32 = RegExp(r'^[0-9a-f]{32}$');
    for (final uid in [
      ...squadre.map((t) => t.uid),
      ...giocatori.map((p) => p.uid),
      ...partite.map((m) => m.uid),
    ]) {
      expect(uid, matches(hex32));
    }
    // randomblob è valutato riga per riga: tre giocatori, tre uid diversi.
    expect(giocatori.map((p) => p.uid).toSet().length, 3);
    expect(partite.map((m) => m.uid).toSet().length, 2);
    // I dati preesistenti sopravvivono alla migrazione.
    expect(squadre.single.nome, 'Nettunia');
    expect(giocatori.map((p) => p.numero).toList()..sort(), [4, 7, 10]);
  });

  test('dopo la migrazione l\'indice unico è attivo', () async {
    await creaSchemaV18ConDati();

    final db = AppDatabase.perTest(NativeDatabase.opened(raw));
    addTearDown(db.close);
    final esistente = (await db.select(db.teams).getSingle()).uid;

    expect(
      () => db.into(db.teams).insert(TeamsCompanion.insert(
            nome: 'Clone',
            categoria: 'Under 18',
            coloreDivisa: 0xFF00FF00,
            uid: Value(esistente),
          )),
      throwsA(isA<SqliteException>()),
    );
  });

  test('rieseguire la migrazione non riscrive gli uid già assegnati', () async {
    // Le ALTER TABLE non sono atomiche: un aggiornamento interrotto a metà
    // rieseguirà questo ramo. Deve convergere, non rigenerare identità (gli
    // uid già finiti in un backup resterebbero orfani).
    await creaSchemaV18ConDati();

    final db = AppDatabase.perTest(
        NativeDatabase.opened(raw, closeUnderlyingOnClose: false));
    final primi = (await db.select(db.players).get()).map((p) => p.uid).toSet();
    await db.close();

    raw.execute('PRAGMA user_version = 18'); // simula il retry
    final db2 = AppDatabase.perTest(NativeDatabase.opened(raw));
    addTearDown(db2.close);
    final dopo = (await db2.select(db2.players).get()).map((p) => p.uid).toSet();

    expect(dopo, primi);
  });
}

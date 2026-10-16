import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:volley_scout/data/database.dart';
import 'package:volley_scout/models/enums.dart';

/// Migrazione v19 -> v20 (ruolo in campo su `rotations` e `scout_actions`) su
/// un database con dati: stesso schema di prova di migrazione_uid_test — si
/// crea lo schema corrente, lo si degrada togliendo le colonne nuove e
/// riportando `user_version` a 19, poi si riapre.
void main() {
  late Database raw;

  setUp(() => raw = sqlite3.openInMemory());
  tearDown(() => raw.close());

  Future<void> creaSchemaV19ConDati() async {
    final db = AppDatabase.perTest(
        NativeDatabase.opened(raw, closeUnderlyingOnClose: false));
    final teamId = await db.into(db.teams).insert(TeamsCompanion.insert(
          nome: 'Nettunia',
          categoria: 'Under 18',
          coloreDivisa: 0xFF0000FF,
        ));
    final giocatori = <int>[];
    for (final numero in [1, 2, 3, 4, 5, 6, 7]) {
      giocatori.add(await db.into(db.players).insert(PlayersCompanion.insert(
            teamId: teamId,
            nome: 'Nome$numero',
            cognome: 'Cognome$numero',
            numero: numero,
            ruolo: numero == 1 ? Ruolo.palleggiatore : Ruolo.schiacciatore,
          )));
    }
    final matchId = await db.into(db.volleyMatches).insert(
          VolleyMatchesCompanion.insert(
            nome: 'Partita',
            dataOra: DateTime(2026, 10, 12),
            inCasa: true,
            stato: StatoPartita.inCorso,
            setCorrente: 1,
          ),
        );
    final setId = await db.into(db.matchSets).insert(MatchSetsCompanion.insert(
          matchId: matchId,
          numero: 1,
          squadraServizioIniziale: Squadra.nostra,
        ));
    for (var pos = 1; pos <= 6; pos++) {
      await db.into(db.rotations).insert(RotationsCompanion.insert(
            setId: setId,
            squadra: Squadra.nostra,
            posizione: pos,
            giocatoreId: giocatori[pos - 1],
          ));
    }
    await db.into(db.scoutActions).insert(ScoutActionsCompanion.insert(
          setId: setId,
          rallyId: 1,
          ordine: 1,
          timestamp: DateTime(2026, 10, 12, 20),
          squadra: Squadra.nostra,
          tipo: TipoAzione.cambioGiocatore,
          esitoPunto: EsitoPunto.nessuno,
          giocatoreId: Value(giocatori[6]),
          giocatoreUscenteId: Value(giocatori[2]),
        ));
    await db.close();

    for (final t in ['rotations', 'scout_actions']) {
      raw.execute('ALTER TABLE $t DROP COLUMN ruolo_in_campo');
    }
    raw.execute('PRAGMA user_version = 19');
  }

  test('le colonne arrivano vuote e i dati restano intatti', () async {
    await creaSchemaV19ConDati();

    final db = AppDatabase.perTest(NativeDatabase.opened(raw));
    addTearDown(db.close);

    final rotazioni = await db.select(db.rotations).get();
    final azioni = await db.select(db.scoutActions).get();
    expect(rotazioni, hasLength(6));
    expect(rotazioni.every((r) => r.ruoloInCampo == null), isTrue);
    expect(azioni.single.tipo, TipoAzione.cambioGiocatore);
    expect(azioni.single.ruoloInCampo, isNull);
  });

  test('dopo la migrazione il ruolo in campo si scrive e si rilegge',
      () async {
    await creaSchemaV19ConDati();

    final db = AppDatabase.perTest(NativeDatabase.opened(raw));
    addTearDown(db.close);
    final azione = (await db.select(db.scoutActions).get()).single;
    await (db.update(db.scoutActions)..where((a) => a.id.equals(azione.id)))
        .write(const ScoutActionsCompanion(ruoloInCampo: Value(Ruolo.centrale)));

    final riletta = (await db.select(db.scoutActions).get()).single;
    expect(riletta.ruoloInCampo, Ruolo.centrale);
  });

  test('rieseguire la migrazione non fallisce', () async {
    // Le ALTER TABLE non sono atomiche: un aggiornamento interrotto rieseguirà
    // il ramo con le colonne già presenti.
    await creaSchemaV19ConDati();

    final db = AppDatabase.perTest(
        NativeDatabase.opened(raw, closeUnderlyingOnClose: false));
    await db.select(db.rotations).get();
    await db.close();

    raw.execute('PRAGMA user_version = 19'); // simula il retry
    final db2 = AppDatabase.perTest(NativeDatabase.opened(raw));
    addTearDown(db2.close);
    expect(await db2.select(db2.rotations).get(), hasLength(6));
  });
}

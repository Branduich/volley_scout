import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volley_scout/data/database.dart';
import 'package:volley_scout/data/uid.dart';
import 'package:volley_scout/models/enums.dart';

/// Gli uid stabili (schema v19) sono la base del backup/ripristino: se due
/// righe ne condividessero uno, un reimport ne perderebbe una in silenzio.
/// Vedi data/uid.dart.
AppDatabase _dbInMemoria() => AppDatabase.perTest(NativeDatabase.memory());

final _hex32 = RegExp(r'^[0-9a-f]{32}$');

Future<int> _creaSquadra(AppDatabase db, String nome) =>
    db.into(db.teams).insert(TeamsCompanion.insert(
          nome: nome,
          categoria: 'Under 18',
          coloreDivisa: 0xFF0000FF,
        ));

Future<int> _creaGiocatore(AppDatabase db, int teamId, int numero) =>
    db.into(db.players).insert(PlayersCompanion.insert(
          teamId: teamId,
          nome: 'Nome$numero',
          cognome: 'Cognome$numero',
          numero: numero,
          ruolo: Ruolo.schiacciatore,
        ));

Future<int> _creaPartita(AppDatabase db, String nome) =>
    db.into(db.volleyMatches).insert(VolleyMatchesCompanion.insert(
          nome: nome,
          dataOra: DateTime(2026, 9, 28, 18, 30),
          inCasa: true,
          stato: StatoPartita.configurazione,
          setCorrente: 1,
        ));

void main() {
  late AppDatabase db;

  setUp(() => db = _dbInMemoria());
  tearDown(() async => db.close());

  group('nuovoUid()', () {
    test('produce 32 caratteri esadecimali minuscoli', () {
      // Stesso formato di lower(hex(randomblob(16))) usato dalla migrazione
      // v19: se divergessero, righe vecchie e nuove non sarebbero confrontabili
      // a occhio nei file di backup.
      expect(nuovoUid(), matches(_hex32));
    });

    test('non si ripete su molte chiamate', () {
      final generati = List.generate(1000, (_) => nuovoUid()).toSet();
      expect(generati.length, 1000);
    });
  });

  group('uid assegnati dal database', () {
    test('ogni squadra/giocatore/partita nasce con un uid valido', () async {
      final teamId = await _creaSquadra(db, 'Nettunia');
      await _creaGiocatore(db, teamId, 4);
      await _creaPartita(db, 'Nettunia - Masi');

      final squadra = await db.select(db.teams).getSingle();
      final giocatore = await db.select(db.players).getSingle();
      final partita = await db.select(db.volleyMatches).getSingle();

      expect(squadra.uid, matches(_hex32));
      expect(giocatore.uid, matches(_hex32));
      expect(partita.uid, matches(_hex32));
    });

    test('righe diverse hanno uid diversi', () async {
      final a = await _creaSquadra(db, 'Nettunia');
      final b = await _creaSquadra(db, 'Masi Volley');
      await _creaGiocatore(db, a, 4);
      await _creaGiocatore(db, a, 7);
      await _creaPartita(db, 'Prima');
      await _creaPartita(db, 'Seconda');

      final squadre = await db.select(db.teams).get();
      final giocatori = await db.select(db.players).get();
      final partite = await db.select(db.volleyMatches).get();

      expect(squadre.map((t) => t.uid).toSet().length, 2);
      expect(giocatori.map((p) => p.uid).toSet().length, 2);
      expect(partite.map((m) => m.uid).toSet().length, 2);
      expect(b, isNot(a)); // due squadre distinte, non un reinserimento
    });

    test('un uid duplicato viene rifiutato dal DB', () async {
      // L'indice UNIQUE è la rete di sicurezza: senza, un bug nel ripristino
      // potrebbe fondere due giocatrici in una.
      final uid = nuovoUid();
      await db.into(db.teams).insert(TeamsCompanion.insert(
            nome: 'Prima',
            categoria: 'Under 18',
            coloreDivisa: 0xFF0000FF,
            uid: Value(uid),
          ));

      expect(
        () => db.into(db.teams).insert(TeamsCompanion.insert(
              nome: 'Seconda',
              categoria: 'Under 18',
              coloreDivisa: 0xFF00FF00,
              uid: Value(uid),
            )),
        throwsA(isA<SqliteException>()),
      );
    });

    test('un uid esplicito viene conservato (serve al ripristino)', () async {
      final uid = nuovoUid();
      await db.into(db.volleyMatches).insert(VolleyMatchesCompanion.insert(
            nome: 'Da backup',
            dataOra: DateTime(2026, 9, 28),
            inCasa: false,
            stato: StatoPartita.terminata,
            setCorrente: 3,
            uid: Value(uid),
          ));

      final partita = await db.select(db.volleyMatches).getSingle();
      expect(partita.uid, uid);
    });
  });
}

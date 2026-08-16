import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volley_scout/data/database.dart';
import 'package:volley_scout/models/enums.dart';
import 'package:volley_scout/providers/database_provider.dart';

/// Test di `ScoutActionRepository.annullaRally` — l'undo dell'INTERO scambio
/// ("si rigioca l'azione"). Database in memoria, niente device.
///
/// Le azioni si registrano con i metodi veri del repository, non con insert a
/// mano: il caso interessante è proprio come `_registraAzione` assegna il
/// `rallyId` (ereditato finché lo scambio è aperto), che è ciò che decide quali
/// righe spariscono.
AppDatabase _dbInMemoria() => AppDatabase.perTest(NativeDatabase.memory());

void main() {
  late AppDatabase db;
  late ScoutActionRepository repo;
  late MatchSet set;
  late int giocatoreA;
  late int giocatoreB;

  setUp(() async {
    db = _dbInMemoria();
    repo = ScoutActionRepository(db);

    final teamId = await db.into(db.teams).insert(
          TeamsCompanion.insert(
            nome: 'Nettunia',
            categoria: 'Terza Divisione',
            coloreDivisa: 0xFF0000FF,
          ),
        );
    giocatoreA = await db.into(db.players).insert(
          PlayersCompanion.insert(
            teamId: teamId,
            nome: 'Anna',
            cognome: 'Rossi',
            numero: 7,
            ruolo: Ruolo.schiacciatore,
          ),
        );
    giocatoreB = await db.into(db.players).insert(
          PlayersCompanion.insert(
            teamId: teamId,
            nome: 'Elisa',
            cognome: 'Bianchi',
            numero: 9,
            ruolo: Ruolo.schiacciatore,
          ),
        );
    final matchId = await db.into(db.volleyMatches).insert(
          VolleyMatchesCompanion.insert(
            nome: 'Partita test',
            dataOra: DateTime(2026, 8, 16, 18, 30),
            inCasa: true,
            stato: StatoPartita.inCorso,
            setCorrente: 1,
          ),
        );
    set = await MatchSetRepository(db).creaSet(matchId, 1, Squadra.nostra);
  });

  tearDown(() async => db.close());

  /// Uno scambio completo: battuta positiva (non chiude) + attacco vincente
  /// (chiude il punto). Due righe, stesso `rallyId`.
  Future<void> scambioConPunto() async {
    await repo.registraAzioneScout(
      setId: set.id,
      squadra: Squadra.nostra,
      giocatoreId: giocatoreA,
      fondamentale: Fondamentale.battuta,
      voto: Voto.positivo,
      esitoPunto: EsitoPunto.nessuno,
    );
    await repo.registraAzioneScout(
      setId: set.id,
      squadra: Squadra.nostra,
      giocatoreId: giocatoreA,
      fondamentale: Fondamentale.attacco,
      voto: Voto.perfetto,
      esitoPunto: EsitoPunto.puntoNostro,
    );
  }

  Future<List<ScoutAction>> azioni() => repo.caricaAzioni(set.id);

  test('cancella tutte le azioni dello scambio indicato', () async {
    await scambioConPunto();
    final prima = await azioni();
    expect(prima.length, 2);
    expect(prima.first.rallyId, prima.last.rallyId,
        reason: 'le due azioni devono appartenere allo stesso scambio');

    await repo.annullaRally(setId: set.id, rallyId: prima.last.rallyId);

    expect(await azioni(), isEmpty);
  });

  test('gli scambi precedenti restano intatti', () async {
    await scambioConPunto(); // scambio 1
    await scambioConPunto(); // scambio 2
    final tutte = await azioni();
    expect(tutte.length, 4);
    final rallyDaAnnullare = tutte.last.rallyId;
    final rallyPrecedente = tutte.first.rallyId;
    expect(rallyDaAnnullare, isNot(rallyPrecedente));

    await repo.annullaRally(setId: set.id, rallyId: rallyDaAnnullare);

    final rimaste = await azioni();
    expect(rimaste.length, 2);
    expect(rimaste.every((a) => a.rallyId == rallyPrecedente), isTrue);
  });

  // Caso limite che ha motivato l'esclusione dei cambi: la sostituzione
  // avviene a palla ferma, ma la prima azione dello scambio SUCCESSIVO ne
  // eredita il `rallyId` (in _registraAzione solo timeout e correzione
  // rotazione interrompono l'ereditarietà). Senza l'esclusione, un
  // "si rigioca" rimanderebbe in panchina un giocatore appena entrato.
  test('una sostituzione con lo stesso rallyId sopravvive', () async {
    await repo.registraSostituzione(
      setId: set.id,
      entraId: giocatoreB,
      esceId: giocatoreA,
    );
    await scambioConPunto();

    final tutte = await azioni();
    final cambio = tutte.first;
    expect(cambio.tipo, TipoAzione.cambioGiocatore);
    expect(tutte.last.rallyId, cambio.rallyId,
        reason: 'lo scambio eredita il rallyId della sostituzione: è proprio '
            'il caso da cui ci si difende');

    await repo.annullaRally(setId: set.id, rallyId: cambio.rallyId);

    final rimaste = await azioni();
    expect(rimaste.length, 1);
    expect(rimaste.single.tipo, TipoAzione.cambioGiocatore);
    expect(rimaste.single.giocatoreId, giocatoreB);
  });

  test('un timeout con rallyId proprio non viene toccato', () async {
    await repo.registraAzioneRapida(
      setId: set.id,
      squadra: Squadra.nostra,
      tipo: TipoAzione.timeout,
      esitoPunto: EsitoPunto.nessuno,
    );
    await scambioConPunto();

    final tutte = await azioni();
    final timeout = tutte.first;
    expect(timeout.tipo, TipoAzione.timeout);
    expect(tutte.last.rallyId, isNot(timeout.rallyId),
        reason: 'il timeout non apre uno scambio: quello dopo ne inizia uno nuovo');

    await repo.annullaRally(setId: set.id, rallyId: tutte.last.rallyId);

    final rimaste = await azioni();
    expect(rimaste.length, 1);
    expect(rimaste.single.tipo, TipoAzione.timeout);
  });
}

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volley_scout/data/database.dart';
import 'package:volley_scout/models/enums.dart';
import 'package:volley_scout/providers/database_provider.dart';

/// Ruolo in campo a inizio set (schema v20): LineupScreen passa la formazione
/// con una COPIA del Player col ruolo sostituito, e il repository deve
/// salvarlo sulla rotazione solo quando differisce dall'anagrafico, poi
/// restituirlo alla ripresa dello scout.
void main() {
  late AppDatabase db;
  late MatchSetRepository repo;
  late Map<String, Player> formazione;
  late int setId;

  setUp(() async {
    db = AppDatabase.perTest(NativeDatabase.memory());
    repo = MatchSetRepository(db);
    final teamId = await db.into(db.teams).insert(TeamsCompanion.insert(
          nome: 'Nettunia',
          categoria: 'Under 18',
          coloreDivisa: 0xFF1E3A8A,
        ));
    const ruoli = [
      Ruolo.palleggiatore,
      Ruolo.schiacciatore,
      Ruolo.centrale,
      Ruolo.opposto,
      Ruolo.schiacciatore,
      Ruolo.schiacciatore, // in campo farà il centrale
    ];
    formazione = {};
    for (var i = 0; i < 6; i++) {
      final id = await db.into(db.players).insert(PlayersCompanion.insert(
            teamId: teamId,
            nome: 'Nome',
            cognome: 'Giocatrice${i + 1}',
            numero: i + 1,
            ruolo: ruoli[i],
          ));
      formazione['P${i + 1}'] = await (db.select(db.players)
            ..where((p) => p.id.equals(id)))
          .getSingle();
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
    setId = (await repo.creaSet(matchId, 1, Squadra.nostra)).id;
  });

  tearDown(() async => db.close());

  test('si salva solo il ruolo diverso dall\'anagrafico', () async {
    await repo.salvaRotazioneIniziale(setId, {
      ...formazione,
      'P6': formazione['P6']!.copyWith(ruolo: Ruolo.centrale),
    });

    final righe = await db.select(db.rotations).get();
    final conRuolo = righe.where((r) => r.ruoloInCampo != null).toList();
    expect(conRuolo, hasLength(1));
    expect(conRuolo.single.posizione, 6);
    expect(conRuolo.single.ruoloInCampo, Ruolo.centrale);
  });

  test('alla ripresa la formazione torna col ruolo in campo', () async {
    await repo.salvaRotazioneIniziale(setId, {
      ...formazione,
      'P6': formazione['P6']!.copyWith(ruolo: Ruolo.centrale),
    });

    final ripresa = (await repo.caricaFormazione(setId))!;
    expect(ripresa.assignments['P6']!.ruolo, Ruolo.centrale);
    expect(ripresa.assignments['P2']!.ruolo, Ruolo.schiacciatore);
    expect(ripresa.palleggiatoreSlot, 'P1');
    // L'anagrafica non si tocca: è un dato della partita.
    final anagrafica = await (db.select(db.players)
          ..where((p) => p.id.equals(formazione['P6']!.id)))
        .getSingle();
    expect(anagrafica.ruolo, Ruolo.schiacciatore);
  });

  test('il palleggiatore si trova anche se lo è solo in campo', () async {
    // Palleggiatrice infortunata: una schiacciatrice alza dall'inizio del set.
    await repo.salvaRotazioneIniziale(setId, {
      ...formazione,
      'P1': formazione['P1']!.copyWith(ruolo: Ruolo.schiacciatore),
      'P5': formazione['P5']!.copyWith(ruolo: Ruolo.palleggiatore),
    });

    final ripresa = (await repo.caricaFormazione(setId))!;
    expect(ripresa.palleggiatoreSlot, 'P5');
  });
}

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database.dart';
import '../models/enums.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

class TeamRepository {
  TeamRepository(this._db);

  final AppDatabase _db;

  // --- Squadre ---

  Stream<List<Team>> watchTeams() {
    return _db.select(_db.teams).watch();
  }

  Future<int> addTeam(TeamsCompanion team) {
    return _db.into(_db.teams).insert(team);
  }

  Future<bool> updateTeam(Team team) {
    return _db.update(_db.teams).replace(team);
  }

  Future<int> deleteTeam(int teamId) {
    return (_db.delete(_db.teams)..where((t) => t.id.equals(teamId))).go();
  }

  // --- Giocatori ---

  Stream<List<Player>> watchPlayersForTeam(int teamId) {
    return (_db.select(_db.players)
          ..where((p) => p.teamId.equals(teamId))
          ..orderBy([(p) => OrderingTerm.asc(p.numero)]))
        .watch();
  }

  Future<int> addPlayer(PlayersCompanion player) {
    return _db.into(_db.players).insert(player);
  }

  Future<bool> updatePlayer(Player player) {
    return _db.update(_db.players).replace(player);
  }

  Future<int> deletePlayer(int playerId) {
    return (_db.delete(_db.players)..where((p) => p.id.equals(playerId))).go();
  }
}

final teamRepositoryProvider = Provider<TeamRepository>((ref) {
  return TeamRepository(ref.watch(appDatabaseProvider));
});

final teamsStreamProvider = StreamProvider<List<Team>>((ref) {
  return ref.watch(teamRepositoryProvider).watchTeams();
});

final playersStreamProvider =
    StreamProvider.family<List<Player>, int>((ref, teamId) {
  return ref.watch(teamRepositoryProvider).watchPlayersForTeam(teamId);
});

// --- Partite ---

class MatchRepository {
  MatchRepository(this._db);
  final AppDatabase _db;

  Stream<List<VolleyMatch>> watchMatches() {
    return (_db.select(_db.volleyMatches)
          ..orderBy([(m) => OrderingTerm.desc(m.dataOra)]))
        .watch();
  }

  Future<int> addMatch(VolleyMatchesCompanion match) {
    return _db.into(_db.volleyMatches).insert(match);
  }

  Future<bool> updateMatch(VolleyMatch match) {
    return _db.update(_db.volleyMatches).replace(match);
  }

  Future<int> deleteMatch(int matchId) {
    return (_db.delete(_db.volleyMatches)..where((m) => m.id.equals(matchId)))
        .go();
  }
}

final matchRepositoryProvider = Provider<MatchRepository>((ref) {
  return MatchRepository(ref.watch(appDatabaseProvider));
});

final matchesStreamProvider = StreamProvider<List<VolleyMatch>>((ref) {
  return ref.watch(matchRepositoryProvider).watchMatches();
});

// --- Set e rotazioni (avvio dello scout) ---

class MatchSetRepository {
  MatchSetRepository(this._db);
  final AppDatabase _db;

  /// Carica il set esistente di una partita già in corso (ripresa: la
  /// partita ha `stato == inCorso`, quindi il dialog "Chi serve per primo?"
  /// non va richiesto di nuovo) — null se non esiste (dato incoerente, non
  /// dovrebbe succedere se `stato == inCorso`).
  Future<MatchSet?> caricaSet(int matchId, int numero) {
    return (_db.select(_db.matchSets)
          ..where((s) => s.matchId.equals(matchId) & s.numero.equals(numero)))
        .getSingleOrNull();
  }

  /// Crea il primo set di una partita, registrando chi serve per primo
  /// (input necessario a ricalcolaStato(), non derivabile dagli eventi).
  Future<MatchSet> creaPrimoSet(int matchId, Squadra servizioIniziale) async {
    final id = await _db.into(_db.matchSets).insert(
          MatchSetsCompanion.insert(
            matchId: matchId,
            numero: 1,
            squadraServizioIniziale: servizioIniziale,
          ),
        );
    return (_db.select(_db.matchSets)..where((s) => s.id.equals(id)))
        .getSingle();
  }

  /// Salva la rotazione iniziale del set a partire dalla formazione
  /// confermata (slot 'P1'..'P6' -> Player). Il libero (L1/L2) non ha una
  /// posizione di rotazione e viene ignorato.
  Future<void> salvaRotazioneIniziale(
      int setId, Map<String, Player> assignments) async {
    final righe = <RotationsCompanion>[];
    for (final entry in assignments.entries) {
      final posizione = int.tryParse(entry.key.replaceFirst('P', ''));
      if (posizione == null || posizione < 1 || posizione > 6) continue;
      righe.add(RotationsCompanion.insert(
        setId: setId,
        squadra: Squadra.nostra,
        posizione: posizione,
        giocatoreId: entry.value.id,
      ));
    }
    await _db.batch((batch) => batch.insertAll(_db.rotations, righe));
  }
}

final matchSetRepositoryProvider = Provider<MatchSetRepository>((ref) {
  return MatchSetRepository(ref.watch(appDatabaseProvider));
});

// --- Azioni di scout (eventi che alimentano ricalcolaStato()) ---

class ScoutActionRepository {
  ScoutActionRepository(this._db);
  final AppDatabase _db;

  Stream<List<ScoutAction>> watchAzioni(int setId) {
    return (_db.select(_db.scoutActions)
          ..where((a) => a.setId.equals(setId))
          ..orderBy([(a) => OrderingTerm.asc(a.ordine)]))
        .watch();
  }

  /// Registra un'azione dei bottoni rapidi (+1 Noi/+1 Loro/Errore): nessun
  /// giocatore/fondamentale/voto, solo squadra + tipo + esito.
  Future<void> registraAzioneRapida({
    required int setId,
    required Squadra squadra,
    required TipoAzione tipo,
    required EsitoPunto esitoPunto,
  }) {
    return _registraAzione(
      setId: setId,
      squadra: squadra,
      tipo: tipo,
      esitoPunto: esitoPunto,
    );
  }

  /// Registra il voto di un fondamentale per un giocatore (oggi solo
  /// battuta — primo pezzo del flusso a 3 tocchi).
  Future<void> registraAzioneScout({
    required int setId,
    required Squadra squadra,
    required int giocatoreId,
    required Fondamentale fondamentale,
    required Voto voto,
    required EsitoPunto esitoPunto,
  }) {
    return _registraAzione(
      setId: setId,
      squadra: squadra,
      tipo: TipoAzione.scout,
      esitoPunto: esitoPunto,
      giocatoreId: giocatoreId,
      fondamentale: fondamentale,
      voto: voto,
    );
  }

  Future<void> _registraAzione({
    required int setId,
    required Squadra squadra,
    required TipoAzione tipo,
    required EsitoPunto esitoPunto,
    int? giocatoreId,
    Fondamentale? fondamentale,
    Voto? voto,
  }) async {
    final maxOrdine = await (_db.selectOnly(_db.scoutActions)
          ..addColumns([_db.scoutActions.ordine.max()])
          ..where(_db.scoutActions.setId.equals(setId)))
        .map((row) => row.read(_db.scoutActions.ordine.max()))
        .getSingleOrNull();
    final ordine = (maxOrdine ?? 0) + 1;

    // Se l'ultima azione del set è ancora "in corso" (esitoPunto = nessuno,
    // es. una battuta non terminale), questa azione fa parte dello stesso
    // scambio — stesso rallyId. Altrimenti inizia un nuovo scambio.
    final ultima = await (_db.select(_db.scoutActions)
          ..where((a) => a.setId.equals(setId))
          ..orderBy([(a) => OrderingTerm.desc(a.ordine)])
          ..limit(1))
        .getSingleOrNull();
    final rallyId = (ultima != null && ultima.esitoPunto == EsitoPunto.nessuno)
        ? ultima.rallyId
        : ordine;

    await _db.into(_db.scoutActions).insert(
          ScoutActionsCompanion.insert(
            setId: setId,
            rallyId: rallyId,
            ordine: ordine,
            timestamp: DateTime.now(),
            squadra: squadra,
            tipo: tipo,
            esitoPunto: esitoPunto,
            giocatoreId: Value(giocatoreId),
            fondamentale: Value(fondamentale),
            voto: Value(voto),
          ),
        );
  }
}

final scoutActionRepositoryProvider = Provider<ScoutActionRepository>((ref) {
  return ScoutActionRepository(ref.watch(appDatabaseProvider));
});

final scoutAzioniStreamProvider =
    StreamProvider.family<List<ScoutAction>, int>((ref, setId) {
  return ref.watch(scoutActionRepositoryProvider).watchAzioni(setId);
});

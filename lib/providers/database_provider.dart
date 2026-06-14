import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database.dart';

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

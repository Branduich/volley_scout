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

  /// Singola squadra per id (non uno stream) — usata da `MatchesScreen`
  /// quando "Riprendi" salta `TeamSelectionScreen` e serve solo leggere una
  /// volta la squadra già fissata sulla partita (`match.teamId`).
  Future<Team?> getTeam(int id) {
    return (_db.select(_db.teams)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
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

  /// Carica il set numero `numero` di una partita, se esiste — null se non
  /// esiste ancora (va richiesto/creato, vedi `creaSet`). Ordina per `id`
  /// decrescente e prende il primo invece di `getSingleOrNull()`: tollera
  /// eventuali righe duplicate già presenti nel DB (vedi `creaSet`) senza
  /// lanciare "Bad state: Too many elements" — prende la più recente.
  Future<MatchSet?> caricaSet(int matchId, int numero) {
    return (_db.select(_db.matchSets)
          ..where((s) => s.matchId.equals(matchId) & s.numero.equals(numero))
          ..orderBy([(s) => OrderingTerm.desc(s.id)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Crea un set della partita (numero generico, non solo il primo: vale
  /// anche per "Prossimo Set" in `EndSetScreen`, che incrementa
  /// `VolleyMatch.setCorrente` prima di arrivare qui), registrando chi
  /// serve per primo (input necessario a ricalcolaStato(), non derivabile
  /// dagli eventi). Idempotente: se un set con questo numero esiste già per
  /// questa partita (es. doppia chiamata accidentale), lo restituisce
  /// invece di inserirne un duplicato.
  Future<MatchSet> creaSet(
      int matchId, int numero, Squadra servizioIniziale) async {
    final esistente = await caricaSet(matchId, numero);
    if (esistente != null) return esistente;
    final id = await _db.into(_db.matchSets).insert(
          MatchSetsCompanion.insert(
            matchId: matchId,
            numero: numero,
            squadraServizioIniziale: servizioIniziale,
          ),
        );
    return (_db.select(_db.matchSets)..where((s) => s.id.equals(id)))
        .getSingle();
  }

  /// Salva la rotazione iniziale del set a partire dalla formazione
  /// confermata (slot 'P1'..'P6' -> Player). Il libero (L1/L2) e
  /// `ruoloCambiLibero` non hanno una posizione di rotazione, quindi non
  /// finiscono in `Rotations`: vengono salvati sul `MatchSet` stesso, per
  /// poter ricostruire la formazione quando si riprende lo scout senza
  /// passare di nuovo da LineupScreen/FormationConfigScreen — vedi
  /// `caricaFormazione()`.
  Future<void> salvaRotazioneIniziale(
      int setId, Map<String, Player> assignments,
      {Ruolo? ruoloCambiLibero}) async {
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

    await (_db.update(_db.matchSets)..where((s) => s.id.equals(setId))).write(
          MatchSetsCompanion(
            liberoId: Value(assignments['L1']?.id),
            libero2Id: Value(assignments['L2']?.id),
            ruoloCambiLibero: Value(ruoloCambiLibero),
          ),
        );
  }

  /// Ricostruisce la formazione iniziale di un set già a DB (assignments,
  /// palleggiatoreSlot, ruoloCambiLibero) — usata da `TeamSelectionScreen`
  /// per bypassare `LineupScreen`/`FormationConfigScreen` quando si riprende
  /// lo scout di un set già iniziato (anche se la partita è `terminata`).
  /// Null se il set non ha ancora una rotazione salvata (set nuovo, mai
  /// iniziato) — in quel caso va comunque attraverso il flusso normale di
  /// selezione formazione.
  Future<
      ({
        Map<String, Player> assignments,
        String palleggiatoreSlot,
        Ruolo? ruoloCambiLibero,
      })?> caricaFormazione(int setId) async {
    final set = await (_db.select(_db.matchSets)
          ..where((s) => s.id.equals(setId)))
        .getSingleOrNull();
    if (set == null) return null;
    final righeRotazione = await (_db.select(_db.rotations)
          ..where((r) => r.setId.equals(setId)))
        .get();
    if (righeRotazione.isEmpty) return null;

    final assignments = <String, Player>{};
    String? palleggiatoreSlot;
    for (final r in righeRotazione) {
      final player = await (_db.select(_db.players)
            ..where((p) => p.id.equals(r.giocatoreId)))
          .getSingleOrNull();
      if (player == null) continue; // giocatore eliminato dopo la creazione
      final slot = 'P${r.posizione}';
      assignments[slot] = player;
      if (player.ruolo == Ruolo.palleggiatore) palleggiatoreSlot = slot;
    }
    if (palleggiatoreSlot == null) return null; // dato incoerente

    final liberoId = set.liberoId;
    if (liberoId != null) {
      final libero = await (_db.select(_db.players)
            ..where((p) => p.id.equals(liberoId)))
          .getSingleOrNull();
      if (libero != null) assignments['L1'] = libero;
    }
    final libero2Id = set.libero2Id;
    if (libero2Id != null) {
      final libero2 = await (_db.select(_db.players)
            ..where((p) => p.id.equals(libero2Id)))
          .getSingleOrNull();
      if (libero2 != null) assignments['L2'] = libero2;
    }

    return (
      assignments: assignments,
      palleggiatoreSlot: palleggiatoreSlot,
      ruoloCambiLibero: set.ruoloCambiLibero,
    );
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

  /// Azione con `ordine` massimo del set, o null se non ce ne sono ancora.
  Future<ScoutAction?> ultimaAzione(int setId) {
    return (_db.select(_db.scoutActions)
          ..where((a) => a.setId.equals(setId))
          ..orderBy([(a) => OrderingTerm.desc(a.ordine)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Undo: elimina l'azione con `ordine` massimo nel set. Punteggio/
  /// rotazione si ricalcolano da soli (derivati dagli eventi rimanenti via
  /// ricalcolaStato()) — nessuna logica di "inversione" manuale.
  Future<void> annullaUltimaAzione(int setId) async {
    final ultima = await ultimaAzione(setId);
    if (ultima == null) return;
    await (_db.delete(_db.scoutActions)..where((a) => a.id.equals(ultima.id)))
        .go();
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

  /// Registra il voto di un fondamentale per un giocatore (oggi battuta e
  /// ricezione). `tipoEsecuzione` è il .name di TipoBattuta/TipoAttacco in
  /// base al fondamentale (colonna polimorfica, vedi Modello dati) —
  /// 'nonSpecificato' di default, non bloccante per il flusso veloce.
  Future<void> registraAzioneScout({
    required int setId,
    required Squadra squadra,
    required int giocatoreId,
    required Fondamentale fondamentale,
    required Voto voto,
    required EsitoPunto esitoPunto,
    String tipoEsecuzione = 'nonSpecificato',
  }) {
    return _registraAzione(
      setId: setId,
      squadra: squadra,
      tipo: TipoAzione.scout,
      esitoPunto: esitoPunto,
      giocatoreId: giocatoreId,
      fondamentale: fondamentale,
      voto: voto,
      tipoEsecuzione: tipoEsecuzione,
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
    String tipoEsecuzione = 'nonSpecificato',
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
    final ultima = await ultimaAzione(setId);
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
            tipoEsecuzione: Value(tipoEsecuzione),
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

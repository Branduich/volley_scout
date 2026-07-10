import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database.dart';
import '../logic/attack_positions.dart';
import '../logic/ricalcola_stato.dart';
import '../logic/role_labels.dart';
import '../models/enums.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Mappa una riga `ScoutAction` nell'evento minimale che serve a
/// `ricalcolaStato()` — unico punto di conversione riga→evento, usato sia
/// da `ScoutScreen._statoSetReale` (stream) sia da
/// `MatchSetRepository.calcolaStatoFinale` (one-shot): i due replay restano
/// così sempre allineati. Il campo `sostituzione` si valorizza solo per
/// `tipo == cambioGiocatore` con entrambi i giocatori presenti (una riga
/// degradata da FK setNull — giocatore eliminato — diventa un no-op).
AzioneScout azioneScoutDaRiga(ScoutAction a) => AzioneScout(
      ordine: a.ordine,
      esitoPunto: a.esitoPunto,
      sostituzione: (a.tipo == TipoAzione.cambioGiocatore &&
              a.giocatoreId != null &&
              a.giocatoreUscenteId != null)
          ? SostituzioneGiocatore(
              esceId: a.giocatoreUscenteId!,
              entraId: a.giocatoreId!,
              nuovoPalleggiatoreId: a.nuovoPalleggiatoreId,
              nuovoRuoloCambiLibero: a.nuovoRuoloCambiLibero,
            )
          : null,
    );

/// Id delle azioni di attacco classificate "su ricezione": un attacco che
/// segue un voto di ricezione nello stesso scambio (`rallyId`, scope per
/// set — ogni lista in [azioniPerSet] è UN set, ordinata per `ordine`).
/// Tutti gli altri attacchi sono "su difesa" — partizione binaria, stessa
/// regola di `MatchReportScreen._riepilogoFondamentali` (tenere allineate):
/// non è un campo salvato, si deduce dalla sequenza. Usata dal filtro
/// attacchi di `PlayerStatsScreen` (e in futuro dal report PDF).
/// True se l'attacco risulta "murato" (muro punto subito): voto `=`, tocco
/// a muro registrato durante il drag della traiettoria E palla tornata nel
/// campo dell'attaccante (punto d'arrivo dallo stesso lato della rete del
/// punto di partenza — rete a x=0.5 nello spazio normalizzato). Deducibile
/// SOLO se la traiettoria è stata disegnata: senza (saltata o disattivata
/// nelle Impostazioni) resta un normale errore d'attacco. Usata dalla
/// colonna "Murati" di `PlayerStatsScreen` (e in futuro dal report PDF).
bool attaccoMurato(ScoutAction a) {
  if (a.tipo != TipoAzione.scout ||
      a.fondamentale != Fondamentale.attacco ||
      a.voto != Voto.errore) {
    return false;
  }
  final x1 = a.traiettoriaX1;
  final x2 = a.traiettoriaX2;
  if (x1 == null || x2 == null) return false;
  if (a.traiettoriaMuroX == null || a.traiettoriaMuroY == null) return false;
  return (x1 < 0.5) == (x2 < 0.5);
}

Set<int> idAttacchiSuRicezione(Iterable<List<ScoutAction>> azioniPerSet) {
  final ids = <int>{};
  for (final azioniSet in azioniPerSet) {
    int? rallyCorrente;
    Fondamentale? ultimoTipo; // ricezione o difesa più recente nello scambio
    for (final azione in azioniSet) {
      if (azione.tipo != TipoAzione.scout) continue;
      final fondamentale = azione.fondamentale;
      if (fondamentale == null || azione.voto == null) continue;
      if (azione.rallyId != rallyCorrente) {
        rallyCorrente = azione.rallyId;
        ultimoTipo = null;
      }
      switch (fondamentale) {
        case Fondamentale.ricezione:
          ultimoTipo = Fondamentale.ricezione;
        case Fondamentale.difesa:
          ultimoTipo = Fondamentale.difesa;
        case Fondamentale.attacco:
          if (ultimoTipo == Fondamentale.ricezione) ids.add(azione.id);
        default:
          break;
      }
    }
  }
  return ids;
}

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

  /// Stessi giocatori di `watchPlayersForTeam`, come query one-shot (non
  /// stream) — usata da `PlayerStatsScreen`, che carica i dati una volta e
  /// poi filtra/raggruppa solo in memoria ad ogni cambio di set/fondamentale.
  Future<List<Player>> getPlayersForTeam(int teamId) {
    return (_db.select(_db.players)
          ..where((p) => p.teamId.equals(teamId))
          ..orderBy([(p) => OrderingTerm.asc(p.numero)]))
        .get();
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

  /// actionId → (zona TATTICA 1-6 dell'attaccante, rotazione = posizione
  /// 1-6 del palleggiatore) al momento di ogni azione di attacco. La zona
  /// è dove il giocatore era schierato secondo le stesse tabelle di
  /// posizione che ScoutScreen usa per i token
  /// (logic/attack_positions.dart) — es. lo schiacciatore di prima linea
  /// attacca quasi sempre da zona 4, a prescindere dalla sua zona di
  /// rotazione. Replay per set: rotazione (sideout + cambi con le guardie
  /// di ricalcolaStato), palleggiatore e ruolo cambi libero effettivi
  /// (override dei cambi), etichette di ruolo via roleLabelsFor, fase
  /// dopo-battuta/dopo-ricezione in base a chi serviva. Azioni non
  /// ricostruibili (formazione mancante, attaccante non in rotazione,
  /// ruolo senza posizione in tabella) restano fuori dalla mappa.
  /// Usata dalle pagine attacchi e distribuzione alzate del PDF e dalla
  /// distribuzione alzate di MatchReportScreen.
  Future<Map<int, ({int zona, int rotazione})>> zonaTatticaPerAzione(
    List<MatchSet> sets,
    Map<int, List<ScoutAction>> azioniPerSet,
    List<Player> players,
  ) async {
    final result = <int, ({int zona, int rotazione})>{};
    final perId = {for (final p in players) p.id: p};
    for (final set in sets) {
      final formazione = await caricaFormazione(set.id);
      if (formazione == null) continue;
      var rot = <int, Player>{};
      for (final e in formazione.assignments.entries) {
        if (!e.key.startsWith('P')) continue;
        final pos = int.tryParse(e.key.substring(1));
        if (pos != null) rot[pos] = e.value;
      }
      if (rot.length != 6) continue; // dato incoerente
      var setterId = formazione.assignments[formazione.palleggiatoreSlot]?.id;
      var ruoloCambi = formazione.ruoloCambiLibero;
      final conLibero = formazione.assignments.containsKey('L1');
      var nostraAlServizio = set.squadraServizioIniziale == Squadra.nostra;

      final ordinate = [...(azioniPerSet[set.id] ?? const <ScoutAction>[])]
        ..sort((a, b) => a.ordine.compareTo(b.ordine));
      for (final a in ordinate) {
        if (a.tipo == TipoAzione.cambioGiocatore &&
            a.giocatoreId != null &&
            a.giocatoreUscenteId != null) {
          final entra = perId[a.giocatoreId!];
          final esceId = a.giocatoreUscenteId!;
          final duplicherebbe = esceId != a.giocatoreId &&
              rot.values.any((p) => p.id == a.giocatoreId);
          if (entra != null && !duplicherebbe) {
            rot = {
              for (final e in rot.entries)
                e.key: e.value.id == esceId ? entra : e.value,
            };
          }
          setterId = a.nuovoPalleggiatoreId ?? setterId;
          ruoloCambi = a.nuovoRuoloCambiLibero ?? ruoloCambi;
        }

        if (a.tipo == TipoAzione.scout &&
            a.fondamentale == Fondamentale.attacco &&
            a.giocatoreId != null) {
          int? posAttaccante;
          int? posSetter;
          rot.forEach((pos, p) {
            if (p.id == a.giocatoreId) posAttaccante = pos;
            if (p.id == setterId) posSetter = pos;
          });
          if (posAttaccante != null && posSetter != null) {
            final assignments = {
              for (final e in rot.entries) 'P${e.key}': e.value,
            };
            final ruolo =
                roleLabelsFor('P$posSetter', assignments)['P$posAttaccante'];
            final mappa = attackMapFor(
              rotazione: 'P$posSetter',
              // L'attacco avviene a palla in gioco: dopo-battuta se
              // servivamo noi in questo scambio, dopo-ricezione altrimenti.
              fase: nostraAlServizio
                  ? FaseAttacco.dopoBattuta
                  : FaseAttacco.dopoRicezione,
              senzaLibero: !conLibero,
              liberoSuSchiacciatori:
                  conLibero && ruoloCambi == Ruolo.schiacciatore,
            );
            final posizione = ruolo == null ? null : mappa?[ruolo];
            if (posizione != null) {
              result[a.id] = (
                zona: zonaDaPosizione(posizione),
                rotazione: posSetter!,
              );
            }
          }
        }

        if (a.esitoPunto == EsitoPunto.puntoNostro && !nostraAlServizio) {
          rot = {for (var p = 1; p <= 6; p++) p: rot[(p % 6) + 1]!};
          nostraAlServizio = true;
        } else if (a.esitoPunto == EsitoPunto.puntoNostro) {
          nostraAlServizio = true;
        } else if (a.esitoPunto == EsitoPunto.puntoAvversario) {
          nostraAlServizio = false;
        }
      }
    }
    return result;
  }

  /// Aggiusta l'override manuale del punteggio (bottoni +/- accanto al
  /// punteggio in `ScoutScreen`) — somma `deltaNostro`/`deltaAvversario` al
  /// valore già presente su `MatchSet`, **non** loggato come `ScoutAction`
  /// (vedi `correzionePuntiNostri`/`correzionePuntiAvversari` in
  /// `database.dart`). Ritorna il `MatchSet` aggiornato, per aggiornare lo
  /// stato locale di `ScoutScreen` senza dover rileggere il set da capo.
  Future<MatchSet> correggiPunteggio(int setId,
      {int deltaNostro = 0, int deltaAvversario = 0}) async {
    final set =
        await (_db.select(_db.matchSets)..where((s) => s.id.equals(setId)))
            .getSingle();
    await (_db.update(_db.matchSets)..where((s) => s.id.equals(setId))).write(
          MatchSetsCompanion(
            correzionePuntiNostri:
                Value(set.correzionePuntiNostri + deltaNostro),
            correzionePuntiAvversari:
                Value(set.correzionePuntiAvversari + deltaAvversario),
          ),
        );
    return (_db.select(_db.matchSets)..where((s) => s.id.equals(setId)))
        .getSingle();
  }

  /// Tutti i set di una partita, in ordine di numero — usata dal report per
  /// ricostruire il punteggio finale di ciascuno (vedi calcolaStatoFinale).
  Future<List<MatchSet>> caricaSetsPartita(int matchId) {
    return (_db.select(_db.matchSets)
          ..where((s) => s.matchId.equals(matchId))
          ..orderBy([(s) => OrderingTerm.asc(s.numero)]))
        .get();
  }

  /// Stato finale di un set, rigiocando le sue `ScoutAction` con
  /// `ricalcolaStato()` — stesso pattern di `ScoutScreen._statoSetReale`,
  /// ma come query one-shot (non stream) per il report. **Non include**
  /// `correzionePuntiNostri`/`correzionePuntiAvversari`: il chiamante deve
  /// sommarli a parte, come fa `ScoutScreen._punteggioNostro`/
  /// `_punteggioAvversario` — qui si ritorna solo il punteggio derivato
  /// dagli eventi. La `Rotation` persistita serve come rotazione iniziale
  /// (necessaria a `ricalcolaStato()` per non lanciare un null-check su un
  /// sideout, anche se il report non usa il campo `rotazione` del risultato).
  Future<StatoSet> calcolaStatoFinale(MatchSet set) async {
    final righeRotazione = await (_db.select(_db.rotations)
          ..where((r) => r.setId.equals(set.id)))
        .get();
    final rotazioneIniziale = {
      for (final r in righeRotazione) r.posizione: r.giocatoreId,
    };
    final righeAzioni = await (_db.select(_db.scoutActions)
          ..where((a) => a.setId.equals(set.id))
          ..orderBy([(a) => OrderingTerm.asc(a.ordine)]))
        .get();
    final azioni = [for (final a in righeAzioni) azioneScoutDaRiga(a)];
    return ricalcolaStato(
      azioni: azioni,
      servizioIniziale: set.squadraServizioIniziale,
      rotazioneIniziale: rotazioneIniziale,
    );
  }

  /// Risale alla squadra di una partita quando `VolleyMatch.teamId` è
  /// `null` per il bug corretto in `TeamSelectionScreen._onTeamSelected`
  /// (prima del fix, ogni `updateMatch(match.copyWith(...))` successivo —
  /// in `ScoutScreen`/`EndSetScreen` — sovrascriveva il teamId appena
  /// salvato di nuovo a `null`, quindi le partite già giocate prima del fix
  /// restano con `teamId == null` anche se la squadra è stata davvero
  /// selezionata). Recupera un `giocatoreId` da una qualunque `Rotation`
  /// già persistita per questa partita e risale al suo `Team` — funziona
  /// solo se è stato confermato almeno un set (altrimenti nessuna
  /// `Rotation` esiste e si ritorna `null`, nessun modo di recuperare il
  /// dato). Usata solo per la visualizzazione nel report: non riscrive
  /// `VolleyMatch.teamId` nel DB.
  Future<Team?> inferisciSquadraDaRotazioni(int matchId) async {
    final sets = await caricaSetsPartita(matchId);
    if (sets.isEmpty) return null;
    for (final set in sets) {
      final riga = await (_db.select(_db.rotations)
            ..where((r) => r.setId.equals(set.id))
            ..limit(1))
          .getSingleOrNull();
      if (riga == null) continue;
      final player = await (_db.select(_db.players)
            ..where((p) => p.id.equals(riga.giocatoreId)))
          .getSingleOrNull();
      if (player == null) continue;
      return (_db.select(_db.teams)..where((t) => t.id.equals(player.teamId)))
          .getSingleOrNull();
    }
    return null;
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

  /// Stesse azioni di `watchAzioni`, come query one-shot — usata da
  /// `PlayerStatsScreen` per caricare tutti i set una volta sola e poi
  /// filtrare/raggruppare in memoria ad ogni cambio di selettore.
  Future<List<ScoutAction>> caricaAzioni(int setId) {
    return (_db.select(_db.scoutActions)
          ..where((a) => a.setId.equals(setId))
          ..orderBy([(a) => OrderingTerm.asc(a.ordine)]))
        .get();
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
  /// Se l'ultima azione è un cambio giocatore con `gruppoCambio`, elimina
  /// l'INTERO gruppo (i cambi confermati insieme, es. doppio cambio, si
  /// annullano insieme — annullarne solo metà non ha senso pallavolistico).
  Future<void> annullaUltimaAzione(int setId) async {
    final ultima = await ultimaAzione(setId);
    if (ultima == null) return;
    final gruppo = ultima.gruppoCambio;
    if (ultima.tipo == TipoAzione.cambioGiocatore && gruppo != null) {
      await (_db.delete(_db.scoutActions)
            ..where(
                (a) => a.setId.equals(setId) & a.gruppoCambio.equals(gruppo)))
          .go();
      return;
    }
    await (_db.delete(_db.scoutActions)..where((a) => a.id.equals(ultima.id)))
        .go();
  }

  /// Quante righe appartengono a un gruppo di cambi (per il testo del
  /// dialog di conferma undo: "verranno annullati N cambi").
  Future<int> contaGruppoCambio(int setId, int gruppoCambio) async {
    final count = _db.scoutActions.id.count();
    final row = await (_db.selectOnly(_db.scoutActions)
          ..addColumns([count])
          ..where(_db.scoutActions.setId.equals(setId) &
              _db.scoutActions.gruppoCambio.equals(gruppoCambio)))
        .getSingle();
    return row.read(count) ?? 0;
  }

  /// Registra un'azione dei bottoni rapidi (+1 Noi/+1 Loro/Errore): nessun
  /// giocatore/fondamentale/voto, solo squadra + tipo + esito.
  /// `tipoEsecuzione` qui porta il `.name` di un `MotivoErrore` quando
  /// `tipo == erroreGenerico` (stessa colonna polimorfica di
  /// TipoBattuta/TipoAttacco, vedi enums.dart) — 'nonSpecificato' di
  /// default per gli altri tipi (+1 Noi/+1 Loro), che non hanno un motivo.
  Future<void> registraAzioneRapida({
    required int setId,
    required Squadra squadra,
    required TipoAzione tipo,
    required EsitoPunto esitoPunto,
    String tipoEsecuzione = 'nonSpecificato',
  }) {
    return _registraAzione(
      setId: setId,
      squadra: squadra,
      tipo: tipo,
      esitoPunto: esitoPunto,
      tipoEsecuzione: tipoEsecuzione,
    );
  }

  /// Registra il voto di un fondamentale per un giocatore (oggi battuta e
  /// ricezione). `tipoEsecuzione` è il .name di TipoBattuta/TipoAttacco in
  /// base al fondamentale (colonna polimorfica, vedi Modello dati) —
  /// 'nonSpecificato' di default, non bloccante per il flusso veloce.
  /// `traiettoria*` (coordinate normalizzate 0.0-1.0) solo per
  /// battuta/attacco — vedi `Fondamentale.richiedeTraiettoria` e
  /// `TrajectoryScreen`; `null` se l'utente ha saltato la traiettoria.
  /// `traiettoriaMuro*` solo per attacco, `null` se la traiettoria non ha
  /// incrociato la rete durante il drag (nessun tocco a muro simulato).
  Future<void> registraAzioneScout({
    required int setId,
    required Squadra squadra,
    required int giocatoreId,
    required Fondamentale fondamentale,
    required Voto voto,
    required EsitoPunto esitoPunto,
    String tipoEsecuzione = 'nonSpecificato',
    double? traiettoriaX1,
    double? traiettoriaY1,
    double? traiettoriaX2,
    double? traiettoriaY2,
    double? traiettoriaMuroX,
    double? traiettoriaMuroY,
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
      traiettoriaX1: traiettoriaX1,
      traiettoriaY1: traiettoriaY1,
      traiettoriaX2: traiettoriaX2,
      traiettoriaY2: traiettoriaY2,
      traiettoriaMuroX: traiettoriaMuroX,
      traiettoriaMuroY: traiettoriaMuroY,
    );
  }

  /// Registra un cambio giocatore (sostituzione a set in corso) — UNA sola
  /// riga per cambio, scritta a flusso completato (dialog di configurazione
  /// compreso): l'undo esistente (elimina la riga con `ordine` massimo)
  /// riporta così l'intero cambio indietro in un colpo solo.
  /// `giocatoreId` = chi entra, `giocatoreUscenteId` = chi esce;
  /// `nuovoPalleggiatoreId`/`nuovoRuoloCambiLibero` sono gli override di
  /// configurazione decisi col cambio (null = invariato). `esitoPunto` è
  /// sempre `nessuno`: il cambio non tocca punteggio né rotazione (il
  /// subentrante prende la posizione dell'uscente — vedi ricalcolaStato()).
  Future<void> registraSostituzione({
    required int setId,
    required int entraId,
    required int esceId,
    int? nuovoPalleggiatoreId,
    Ruolo? nuovoRuoloCambiLibero,
    int? gruppoCambio,
  }) {
    return _registraAzione(
      setId: setId,
      squadra: Squadra.nostra,
      tipo: TipoAzione.cambioGiocatore,
      esitoPunto: EsitoPunto.nessuno,
      giocatoreId: entraId,
      giocatoreUscenteId: esceId,
      nuovoPalleggiatoreId: nuovoPalleggiatoreId,
      nuovoRuoloCambiLibero: nuovoRuoloCambiLibero,
      gruppoCambio: gruppoCambio,
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
    double? traiettoriaX1,
    double? traiettoriaY1,
    double? traiettoriaX2,
    double? traiettoriaY2,
    double? traiettoriaMuroX,
    double? traiettoriaMuroY,
    int? giocatoreUscenteId,
    int? nuovoPalleggiatoreId,
    Ruolo? nuovoRuoloCambiLibero,
    int? gruppoCambio,
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
    // Un timeout ha esito `nessuno` ma non apre né continua uno scambio:
    // senza l'esclusione, l'azione successiva erediterebbe il suo rallyId
    // invece di iniziarne uno nuovo.
    final ultima = await ultimaAzione(setId);
    final rallyId = (ultima != null &&
            ultima.esitoPunto == EsitoPunto.nessuno &&
            ultima.tipo != TipoAzione.timeout)
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
            traiettoriaX1: Value(traiettoriaX1),
            traiettoriaY1: Value(traiettoriaY1),
            traiettoriaX2: Value(traiettoriaX2),
            traiettoriaY2: Value(traiettoriaY2),
            traiettoriaMuroX: Value(traiettoriaMuroX),
            traiettoriaMuroY: Value(traiettoriaMuroY),
            giocatoreUscenteId: Value(giocatoreUscenteId),
            nuovoPalleggiatoreId: Value(nuovoPalleggiatoreId),
            nuovoRuoloCambiLibero: Value(nuovoRuoloCambiLibero),
            gruppoCambio: Value(gruppoCambio),
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

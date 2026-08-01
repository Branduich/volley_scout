import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/database.dart';
import '../models/enums.dart';

/// Squadra + partita + set finti su cui gira il tutorial: dati veri a DB (la
/// schermata di scout è quella reale e ha bisogno di un `MatchSet` vero), ma
/// **usa e getta** — si cancellano all'uscita dal tutorial.
///
/// Perché non un flag `tutorial` sulle tabelle: obbligherebbe a filtrare in
/// ogni query attuale e futura (liste, CSV, PDF, statistiche, campionato) per
/// una feature effimera, e una dimenticanza sarebbe un bug silenzioso. Qui il
/// ciclo di vita è chiuso da due soli punti: il launcher (`avvia_tutorial.dart`)
/// che pulisce al ritorno dal push, e `main()` che pulisce all'avvio — così
/// anche un'app chiusa a metà tutorial non lascia residui visibili.
///
/// Gli id seminati sono ricordati in `SharedPreferences`: si cancella per id,
/// mai per nome, così una squadra vera dell'utente non può mai essere colpita
/// da una collisione di nomi.
class TutorialSandbox {
  static const _kMatchId = 'tutorial.matchId';
  static const _kTeamId = 'tutorial.teamId';

  static const nomeTeam = 'Squadra tutorial';
  static const nomeMatch = 'Partita di prova';

  /// Cancella la partita e la squadra di prova dell'ultima sessione, se ci
  /// sono. Idempotente: se non c'è nulla non fa nulla.
  static Future<void> pulisci(AppDatabase db, SharedPreferences prefs) async {
    final matchId = prefs.getInt(_kMatchId);
    if (matchId != null) {
      // Cascade: MatchSets -> Rotations/ScoutActions spariscono con la partita.
      await (db.delete(db.volleyMatches)..where((m) => m.id.equals(matchId)))
          .go();
      await prefs.remove(_kMatchId);
    }
    final teamId = prefs.getInt(_kTeamId);
    if (teamId != null) {
      await (db.delete(db.teams)..where((t) => t.id.equals(teamId))).go();
      await prefs.remove(_kTeamId);
    }
  }

  /// Semina lo scenario di partenza e restituisce gli id.
  ///
  /// Il set viene creato **già completo** (servizio iniziale, rotazione,
  /// palleggiatore avversario): così `ScoutScreen._avviaOCaricaSet` lo trova
  /// esistente e non mostra né il dialog "Chi serve per primo?" né la
  /// selezione del palleggiatore avversario — nessun `if (tutorial)` nella
  /// schermata.
  ///
  /// Serviamo NOI di proposito: in fase di servizio l'unico giocatore
  /// toccabile è il battitore, quindi il primo dei "tre tocchi" è
  /// deterministico e il tutorial può indicarlo con certezza.
  static Future<({VolleyMatch match, Team team, int setId})> semina(
    AppDatabase db,
    SharedPreferences prefs,
  ) async {
    await pulisci(db, prefs);

    final team = await db.into(db.teams).insertReturning(TeamsCompanion.insert(
          nome: nomeTeam,
          categoria: Categoria.terzaDivisione.label,
          coloreDivisa: 0xFF1E3A8A,
        ));
    final teamId = team.id;
    await prefs.setInt(_kTeamId, teamId);

    // Formazione 5-1 nella disposizione che le tabelle di posizione danno per
    // scontata (vedi kAttackBattutaCentrali['P1']): a partire dal
    // palleggiatore e procedendo per numeri di zona crescenti l'ordine è
    // P, S1, C1, O, S2, C2. Qui il palleggiatore è in P6, quindi:
    // P1=S1, P2=C1, P3=O, P4=S2, P5=C2, P6=P.
    //
    // Rotazione scelta di proposito: batte uno SCHIACCIATORE (in P1) e il
    // centrale che il libero sostituisce è in P5. Con altre rotazioni si
    // finisce nei casi limite — alla rotazione P2, per esempio, a battere è il
    // centrale di seconda linea, che quindi resta in campo e lascia fuori il
    // libero: corretto ma confuso da spiegare come primo esempio.
    final rosa = <String, ({String nome, String cognome, int numero, Ruolo ruolo})>{
      'P1': (nome: 'Anna', cognome: 'Bianchi', numero: 4, ruolo: Ruolo.schiacciatore),
      'P2': (nome: 'Elisa', cognome: 'Ricci', numero: 6, ruolo: Ruolo.centrale),
      'P3': (nome: 'Marta', cognome: 'Ferri', numero: 9, ruolo: Ruolo.opposto),
      'P4': (nome: 'Giulia', cognome: 'Moretti', numero: 7, ruolo: Ruolo.schiacciatore),
      'P5': (nome: 'Chiara', cognome: 'Gallo', numero: 5, ruolo: Ruolo.centrale),
      'P6': (nome: 'Sara', cognome: 'Conti', numero: 1, ruolo: Ruolo.palleggiatore),
      'L1': (nome: 'Luisa', cognome: 'Rossi', numero: 3, ruolo: Ruolo.libero),
    };

    final assignments = <String, Player>{};
    for (final entry in rosa.entries) {
      final p = entry.value;
      assignments[entry.key] = await db.into(db.players).insertReturning(
            PlayersCompanion.insert(
              teamId: teamId,
              nome: p.nome,
              cognome: p.cognome,
              numero: p.numero,
              ruolo: p.ruolo,
            ),
          );
    }

    final match = await db.into(db.volleyMatches).insertReturning(
          VolleyMatchesCompanion.insert(
            nome: nomeMatch,
            dataOra: DateTime.now(),
            inCasa: true,
            avversario: const Value('Avversari'),
            teamId: Value(teamId),
            // Già `inCorso`: evita l'UPDATE che ScoutScreen farebbe altrimenti
            // per riportarla in corso alla ripresa.
            stato: StatoPartita.inCorso,
            setCorrente: 1,
          ),
        );
    await prefs.setInt(_kMatchId, match.id);

    final setId = await db.into(db.matchSets).insertReturning(
          MatchSetsCompanion.insert(
            matchId: match.id,
            numero: 1,
            squadraServizioIniziale: Squadra.nostra,
            liberoId: Value(assignments['L1']!.id),
            ruoloCambiLibero: const Value(Ruolo.centrale),
            sistemaGioco: const Value(SistemaGioco.palleggiatoreUnico),
            // Valorizzato a mano: se resta null ScoutScreen chiede di
            // posizionare il palleggiatore avversario a inizio set.
            palleggiatoreAvversarioSlot: const Value(1),
          ),
        );

    await db.batch((batch) => batch.insertAll(db.rotations, [
          for (final entry in assignments.entries)
            if (entry.key.startsWith('P'))
              RotationsCompanion.insert(
                setId: setId.id,
                squadra: Squadra.nostra,
                posizione: int.parse(entry.key.substring(1)),
                giocatoreId: entry.value.id,
              ),
        ]));

    return (match: match, team: team, setId: setId.id);
  }
}

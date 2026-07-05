import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/enums.dart';
import 'database.dart';

/// Importa la partita demo (Clai Imola - Nettunia 30/04/2026, persa 2-3 in
/// trasferta) da `assets/demo/demo_match.json` — log azione per azione
/// convertito dall'export xlsx dell'app "Volleyball Scout" (vedi CLAUDE.md,
/// sezione partita demo). Serve a sviluppare/provare i report con dati
/// realistici: 5 set, ~460 azioni con voti reali, traiettorie sintetiche.
///
/// Idempotente: una partita demo già presente (stesso nome) viene eliminata
/// e ricreata; la squadra demo e i suoi giocatori vengono riusati se
/// esistono già (match per numero di maglia).
class DemoMatchImporter {
  DemoMatchImporter(this._db);
  final AppDatabase _db;

  static const assetPath = 'assets/demo/demo_match.json';

  static const _votoPerSimbolo = {
    '#': Voto.perfetto,
    '+': Voto.positivo,
    '/': Voto.mezzoPunto,
    '-': Voto.negativo,
    '=': Voto.errore,
  };

  /// Ritorna il nome della partita importata (per la SnackBar di conferma).
  Future<String> importa() async {
    final json = jsonDecode(await rootBundle.loadString(assetPath))
        as Map<String, dynamic>;
    final matchNome = json['matchNome'] as String;
    final dataOra = DateTime.parse(json['dataOra'] as String);

    // Idempotenza: via la partita demo precedente (cascade su set/rotazioni/
    // azioni). La squadra resta e viene riusata.
    await (_db.delete(_db.volleyMatches)
          ..where((m) => m.nome.equals(matchNome)))
        .go();

    // Squadra demo: riusa per nome, altrimenti crea.
    final teamNome = json['teamNome'] as String;
    final teamEsistente = await (_db.select(_db.teams)
          ..where((t) => t.nome.equals(teamNome)))
        .getSingleOrNull();
    final teamId = teamEsistente?.id ??
        await _db.into(_db.teams).insert(TeamsCompanion.insert(
              nome: teamNome,
              categoria: Categoria.terzaDivisione,
              coloreDivisa: json['coloreDivisa'] as int,
            ));

    // Giocatori: match per numero di maglia, crea i mancanti.
    final esistenti = await (_db.select(_db.players)
          ..where((p) => p.teamId.equals(teamId)))
        .get();
    final idPerNumero = {for (final p in esistenti) p.numero: p.id};
    for (final pj in json['players'] as List) {
      final numero = pj['numero'] as int;
      if (idPerNumero.containsKey(numero)) continue;
      idPerNumero[numero] = await _db.into(_db.players).insert(
            PlayersCompanion.insert(
              teamId: teamId,
              nome: pj['nome'] as String,
              cognome: pj['cognome'] as String,
              numero: numero,
              ruolo: Ruolo.values.byName(pj['ruolo'] as String),
            ),
          );
    }

    final sets = json['sets'] as List;
    final matchId = await _db.into(_db.volleyMatches).insert(
          VolleyMatchesCompanion.insert(
            nome: matchNome,
            dataOra: dataOra,
            inCasa: false,
            avversario: Value(json['avversario'] as String?),
            teamId: Value(teamId),
            stato: StatoPartita.terminata,
            setCorrente: sets.length,
          ),
        );

    for (final sj in sets) {
      final setId = await _db.into(_db.matchSets).insert(
            MatchSetsCompanion.insert(
              matchId: matchId,
              numero: sj['numero'] as int,
              squadraServizioIniziale:
                  Squadra.values.byName(sj['servizioIniziale'] as String),
              liberoId: Value(idPerNumero[sj['liberoNumero']]),
              libero2Id: Value(idPerNumero[sj['libero2Numero']]),
              // I due liberi demo giocano per i centrali (convenzione più
              // comune, non ricostruibile dall'export).
              ruoloCambiLibero: const Value(Ruolo.centrale),
            ),
          );

      final rotazione = sj['rotazione'] as Map<String, dynamic>;
      await _db.batch((b) => b.insertAll(_db.rotations, [
            for (final e in rotazione.entries)
              RotationsCompanion.insert(
                setId: setId,
                squadra: Squadra.nostra,
                posizione: int.parse(e.key),
                giocatoreId: idPerNumero[e.value]!,
              ),
          ]));

      // Azioni: ordine progressivo, rallyId con la stessa regola di
      // ScoutActionRepository._registraAzione (eredita il rally se l'azione
      // precedente aveva esito `nessuno`, altrimenti ne apre uno nuovo).
      var ordine = 0;
      var rallyId = 0;
      var esitoPrecedente = EsitoPunto.puntoNostro; // la prima apre un rally
      final companions = <ScoutActionsCompanion>[];
      for (final aj in sj['azioni'] as List) {
        ordine++;
        if (esitoPrecedente != EsitoPunto.nessuno) rallyId = ordine;
        final esito = EsitoPunto.values.byName(aj['esito'] as String);
        final tipoStr = aj['tipo'] as String;
        final squadra = Squadra.values
            .byName((aj['squadra'] as String?) ?? 'nostra');

        final companion = switch (tipoStr) {
          'scout' => ScoutActionsCompanion.insert(
              setId: setId,
              rallyId: rallyId,
              ordine: ordine,
              timestamp: dataOra.add(Duration(seconds: ordine)),
              squadra: Squadra.nostra,
              tipo: TipoAzione.scout,
              esitoPunto: esito,
              giocatoreId: Value(idPerNumero[aj['numero']]),
              fondamentale: Value(
                  Fondamentale.values.byName(aj['fondamentale'] as String)),
              voto: Value(_votoPerSimbolo[aj['voto']]),
              traiettoriaX1: Value((aj['tx1'] as num?)?.toDouble()),
              traiettoriaY1: Value((aj['ty1'] as num?)?.toDouble()),
              traiettoriaX2: Value((aj['tx2'] as num?)?.toDouble()),
              traiettoriaY2: Value((aj['ty2'] as num?)?.toDouble()),
            ),
          'erroreGenerico' => ScoutActionsCompanion.insert(
              setId: setId,
              rallyId: rallyId,
              ordine: ordine,
              timestamp: dataOra.add(Duration(seconds: ordine)),
              squadra: squadra,
              tipo: TipoAzione.erroreGenerico,
              esitoPunto: esito,
              tipoEsecuzione: Value(
                  (aj['motivo'] as String?) ?? MotivoErrore.generico.name),
            ),
          'puntoManuale' => ScoutActionsCompanion.insert(
              setId: setId,
              rallyId: rallyId,
              ordine: ordine,
              timestamp: dataOra.add(Duration(seconds: ordine)),
              squadra: squadra,
              tipo: TipoAzione.puntoManuale,
              esitoPunto: esito,
            ),
          _ => null,
        };
        if (companion == null) {
          // Tipo non gestito nel JSON: non deve succedere (il convertitore
          // emette solo i tre tipi sopra) — salta senza consumare l'ordine.
          ordine--;
          continue;
        }
        companions.add(companion);
        esitoPrecedente = esito;
      }
      await _db.batch((b) => b.insertAll(_db.scoutActions, companions));
    }
    return matchNome;
  }
}

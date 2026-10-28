import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volley_scout/data/database.dart';
import 'package:volley_scout/data/demo_match_importer.dart';
import 'package:volley_scout/models/enums.dart';
import 'package:volley_scout/providers/database_provider.dart';

/// Rete di sicurezza su `zonaTatticaPerAzione`: ~100 righe che rigiocano cambi
/// e rotazioni per dire in che zona TATTICA Ã¨ avvenuto ogni attacco, e che
/// alimentano la distribuzione alzate del report e del PDF.
///
/// Non aveva alcun test (segnata come mancante in
/// docs/context/scout-avversario.md), e un errore qui non fa crashare niente:
/// produce zone sbagliate, che si notano mesi dopo guardando una statistica
/// che non torna. I valori attesi sono la fotografia del comportamento al
/// 2026-08-20, presa PRIMA di spostare la logica nel package (passo 5.5).
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.perTest(NativeDatabase.memory());
    await DemoMatchImporter(db)
        .importaDaJson(File('packages/volley_stats/assets/backup_demo.json').readAsStringSync());
  });

  tearDown(() async => db.close());

  /// Le zone calcolate, piÃ¹ la firma `set.ordine â†’ zona/rotazione`, che Ã¨
  /// indipendente dagli id autoincrement (quelli cambiano se cambia l'ordine
  /// di inserimento, la firma no).
  Future<({Map<int, ({int zona, int rotazione})> zone, List<String> firma})>
      calcola() async {
    final repo = MatchSetRepository(db);
    final sets = await db.select(db.matchSets).get();
    final azioni = await db.select(db.scoutActions).get();
    final azioniPerSet = <int, List<ScoutAction>>{};
    for (final a in azioni) {
      (azioniPerSet[a.setId] ??= []).add(a);
    }
    final players = await db.select(db.players).get();
    final zone = await repo.zonaTatticaPerAzione(sets, azioniPerSet, players);

    final numeroSet = {for (final s in sets) s.id: s.numero};
    final perId = {for (final a in azioni) a.id: a};
    final firma = zone.entries
        .map((e) => (
              set: numeroSet[perId[e.key]!.setId]!,
              ordine: perId[e.key]!.ordine,
              v: e.value,
            ))
        .toList()
      ..sort((a, b) =>
          a.set == b.set ? a.ordine.compareTo(b.ordine) : a.set.compareTo(b.set));
    return (
      zone: zone,
      firma: [
        for (final f in firma) '${f.set}.${f.ordine}=${f.v.zona}/${f.v.rotazione}'
      ],
    );
  }

  test('assegna una zona a 63 attacchi della demo', () async {
    // 63 su 332: la zona TATTICA si ricava dalla formazione in campo, e
    // nella stagione di esempio solo la gara del 30 aprile ha le rotazioni
    // (le altre vengono da un export che non le registra). Il numero non Ã¨
    // sbagliato: Ã¨ tutto ciÃ² che si puÃ² calcolare su quei dati.
    final r = await calcola();
    expect(r.zone.length, 63);
  });

  test('distribuzione per zona e per rotazione', () async {
    final r = await calcola();

    final perZona = <int, int>{};
    final perRotazione = <int, int>{};
    for (final v in r.zone.values) {
      perZona[v.zona] = (perZona[v.zona] ?? 0) + 1;
      perRotazione[v.rotazione] = (perRotazione[v.rotazione] ?? 0) + 1;
    }

    // Zona 5 assente: nella demo nessun attacco parte da lÃ¬. Le zone sono
    // TATTICHE (dalle coordinate della mappa di attacco), non zone di
    // rotazione â€” vedi zonaDaPosizione.
    expect(perZona, {1: 12, 2: 12, 3: 5, 4: 22, 6: 12});
    expect(perRotazione, {1: 20, 2: 20, 3: 8, 4: 6, 5: 4, 6: 5});
  });

  // Ruolo in campo (schema v20): una schiacciatrice schierata da centrale.
  // Le sue zone d'attacco devono cambiare, e i due percorsi â€” inizio set
  // (Rotations.ruoloInCampo) e riga di cambio â€” devono dare lo stesso
  // risultato. Nella demo il primo set schiera quattro schiacciatrici e
  // nessun centrale, che Ã¨ proprio il caso di una che fa il centrale.
  group('ruolo in campo', () {
    Future<List<int>> zoneDi(int setId, int giocatoreId) async {
      final r = await calcola();
      final azioni = await db.select(db.scoutActions).get();
      final perId = {for (final a in azioni) a.id: a};
      final ordinate = r.zone.entries
          .where((e) =>
              perId[e.key]!.setId == setId &&
              perId[e.key]!.giocatoreId == giocatoreId)
          .toList()
        ..sort((a, b) => perId[a.key]!.ordine.compareTo(perId[b.key]!.ordine));
      return [for (final e in ordinate) e.value.zona];
    }

    /// Una schiacciatrice titolare del primo set con la rotazione, che abbia
    /// attacchi con una zona: altrimenti non ci sarebbe niente da confrontare.
    Future<({int setId, Rotation riga, List<int> zone})> bersaglio() async {
      final rotazioni = await db.select(db.rotations).get();
      final ruolo = {
        for (final p in await db.select(db.players).get()) p.id: p.ruolo,
      };
      final setId = rotazioni.first.setId;
      for (final r in rotazioni.where((r) =>
          r.setId == setId && ruolo[r.giocatoreId] == Ruolo.schiacciatore)) {
        final zone = await zoneDi(setId, r.giocatoreId);
        if (zone.isNotEmpty) return (setId: setId, riga: r, zone: zone);
      }
      throw StateError('nessuna schiacciatrice con attacchi nel set $setId');
    }

    Future<void> daCentraleAInizioSet(Rotation riga) =>
        (db.update(db.rotations)..where((r) => r.id.equals(riga.id)))
            .write(const RotationsCompanion(
                ruoloInCampo: Value(Ruolo.centrale)));

    test('a inizio set sposta le zone d\'attacco', () async {
      final k = await bersaglio();

      await daCentraleAInizioSet(k.riga);
      final dopo = await zoneDi(k.setId, k.riga.giocatoreId);

      // Da centrale attacca al centro della rete. PuÃ² avere MENO attacchi
      // con una zona: in seconda linea il centrale lo sostituisce il libero,
      // quindi le tabelle non hanno una posizione per lei.
      expect(dopo, isNot(k.zone));
      expect(dopo, isNotEmpty);
      expect(dopo, everyElement(3));
    });

    test('con una riga di cambio dÃ  lo stesso risultato di inizio set',
        () async {
      final k = await bersaglio();
      // Riga "no-op" (esce == entra) in testa al set: cambia il ruolo senza
      // sostituire, come fa ricalcolaStato.
      await db.into(db.scoutActions).insert(ScoutActionsCompanion.insert(
            setId: k.setId,
            rallyId: 0,
            ordine: 0,
            timestamp: DateTime(2026, 4, 30),
            squadra: Squadra.nostra,
            tipo: TipoAzione.cambioGiocatore,
            esitoPunto: EsitoPunto.nessuno,
            giocatoreId: Value(k.riga.giocatoreId),
            giocatoreUscenteId: Value(k.riga.giocatoreId),
            ruoloInCampo: const Value(Ruolo.centrale),
          ));
      final conCambio = await zoneDi(k.setId, k.riga.giocatoreId);

      await (db.delete(db.scoutActions)..where((a) => a.ordine.equals(0)))
          .go();
      await daCentraleAInizioSet(k.riga);
      final inizioSet = await zoneDi(k.setId, k.riga.giocatoreId);

      expect(conCambio, isNot(k.zone));
      expect(conCambio, inizioSet);
    });
  });

  // Libero entrato a set in corso: le zone d'attacco devono passare alle
  // tabelle col libero da quel momento. Prova per equivalenza: lo stesso
  // set, fatto partire SENZA libero e col libero che entra prima del primo
  // scambio, deve dare esattamente le zone di quando il libero c'era giÃ .
  //
  // Coppia degli SCHIACCIATORI di proposito: con il libero sui centrali le
  // tabelle "senza libero" derivano da quelle col libero e per gli
  // attaccanti coincidono quasi sempre â€” il test passerebbe anche col
  // replay sbagliato. Il controllo intermedio lo garantisce.
  test('libero entrato a inizio set equivale a libero in formazione',
      () async {
    final set = (await db.select(db.matchSets).get())
        .firstWhere((s) => s.liberoId != null);
    Future<void> scriviSet(int? libero, Ruolo? coppia) =>
        (db.update(db.matchSets)..where((s) => s.id.equals(set.id))).write(
            MatchSetsCompanion(
                liberoId: Value(libero),
                libero2Id: const Value(null),
                ruoloCambiLibero: Value(coppia)));

    await scriviSet(set.liberoId, Ruolo.schiacciatore);
    final conLiberoDaSubito = await calcola();

    await scriviSet(null, null);
    final senzaLibero = await calcola();
    expect(senzaLibero.firma, isNot(conLiberoDaSubito.firma),
        reason: 'i due scenari devono essere distinguibili');

    await db.into(db.scoutActions).insert(ScoutActionsCompanion.insert(
          setId: set.id,
          rallyId: 0,
          ordine: 0,
          timestamp: DateTime(2026, 4, 30),
          squadra: Squadra.nostra,
          tipo: TipoAzione.cambioGiocatore,
          esitoPunto: EsitoPunto.nessuno,
          giocatoreId: Value(set.liberoId),
          giocatoreUscenteId: Value(set.liberoId),
          nuovoRuoloCambiLibero: const Value(Ruolo.schiacciatore),
        ));
    final liberoEntrato = await calcola();

    expect(liberoEntrato.firma, conLiberoDaSubito.firma);
  });

  // Il gemello: libero TOLTO prima del primo scambio â‰¡ set senza libero.
  // Stessa coppia degli schiacciatori, perchÃ© i due scenari si distinguano
  // (verificato nel test sopra).
  test('libero tolto a inizio set equivale a set senza libero', () async {
    final set = (await db.select(db.matchSets).get())
        .firstWhere((s) => s.liberoId != null);
    Future<void> scriviSet(int? libero, Ruolo? coppia) =>
        (db.update(db.matchSets)..where((s) => s.id.equals(set.id))).write(
            MatchSetsCompanion(
                liberoId: Value(libero),
                libero2Id: const Value(null),
                ruoloCambiLibero: Value(coppia)));

    await scriviSet(null, null);
    final senzaLibero = await calcola();

    await scriviSet(set.liberoId, Ruolo.schiacciatore);
    await db.into(db.scoutActions).insert(ScoutActionsCompanion.insert(
          setId: set.id,
          rallyId: 0,
          ordine: 0,
          timestamp: DateTime(2026, 4, 30),
          squadra: Squadra.nostra,
          tipo: TipoAzione.cambioGiocatore,
          esitoPunto: EsitoPunto.nessuno,
          giocatoreId: Value(set.liberoId),
          giocatoreUscenteId: Value(set.liberoId),
        ));
    final liberoTolto = await calcola();

    expect(liberoTolto.firma, senzaLibero.firma);
  });

  test('firma per-azione stabile (set.ordine = zona/rotazione)', () async {
    final r = await calcola();

    // I primi attacchi di ogni set: se una regola di rotazione o di
    // sostituzione cambiasse, questi slitterebbero.
    expect(r.firma.take(6), [
      '1.17=4/4',
      '1.28=4/2',
      '1.36=6/1',
      '1.67=4/2',
      '1.71=1/2',
      '1.77=6/1',
    ]);
    expect(r.firma.length, 63);
    // Nessuna zona fuori 1-6, nessuna rotazione fuori 1-6.
    for (final v in r.zone.values) {
      expect(v.zona, inInclusiveRange(1, 6));
      expect(v.rotazione, inInclusiveRange(1, 6));
    }
  });
}

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volley_scout/data/database.dart';
import 'package:volley_scout/data/demo_match_importer.dart';
import 'package:volley_scout/providers/database_provider.dart';

/// Rete di sicurezza su `zonaTatticaPerAzione`: ~100 righe che rigiocano cambi
/// e rotazioni per dire in che zona TATTICA è avvenuto ogni attacco, e che
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

  /// Le zone calcolate, più la firma `set.ordine → zona/rotazione`, che è
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
    // (le altre vengono da un export che non le registra). Il numero non è
    // sbagliato: è tutto ciò che si può calcolare su quei dati.
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

    // Zona 5 assente: nella demo nessun attacco parte da lì. Le zone sono
    // TATTICHE (dalle coordinate della mappa di attacco), non zone di
    // rotazione — vedi zonaDaPosizione.
    expect(perZona, {1: 12, 2: 12, 3: 5, 4: 22, 6: 12});
    expect(perRotazione, {1: 20, 2: 20, 3: 8, 4: 6, 5: 4, 6: 5});
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

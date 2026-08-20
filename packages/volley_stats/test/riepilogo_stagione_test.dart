import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:volley_stats/backup_model.dart';
import 'package:volley_stats/riepilogo_stagione.dart';

/// Aggregati di squadra letti da un file di backup **vero** (la partita demo
/// esportata col formato v1), non da dati inventati: è lo stesso file che la
/// dashboard mostra come esempio.
///
/// `test/fixtures/` è anche il posto dove terrà una copia per ogni versione del
/// formato, così un cambio incompatibile si nota qui invece che sul telefono di
/// un utente (vedi Rischi in docs/dati-stagionali.md).
/// `flutter test` usa come cartella di lavoro quella da cui lo si lancia: dal
/// package è `test/fixtures/…`, dalla root del monorepo
/// `packages/volley_stats/test/fixtures/…`. Si provano entrambe, invece di
/// obbligare a lanciare i test da un posto preciso — la suite completa parte
/// dalla root (vedi CLAUDE.md).
File _fixture(String nome) {
  for (final percorso in [
    'test/fixtures/$nome',
    'packages/volley_stats/test/fixtures/$nome',
  ]) {
    final file = File(percorso);
    if (file.existsSync()) return file;
  }
  throw StateError('fixture "$nome" non trovata da ${Directory.current.path}');
}

void main() {
  late BackupCompleto backup;

  setUpAll(() {
    backup = BackupCompleto.fromJson(
      jsonDecode(_fixture('backup_v1.json').readAsStringSync())
          as Map<String, Object?>,
    );
  });

  test('set vinti e persi rigiocando gli eventi', () {
    final r = riepilogoStagione(backup);

    // Referto reale di Clai Imola - Nettunia: 25-16, 15-25, 21-25, 25-16,
    // 25-23 dal punto di vista avversario ⇒ noi vinciamo il 2° e il 3°.
    expect(r.partite, 1);
    expect(r.setVinti, 2);
    expect(r.setPersi, 3);
    expect(r.partiteVinte, 0);
    expect(r.partitePerse, 1);
  });

  test('punti, errori e azioni contate solo sulle NOSTRE azioni votate', () {
    final r = riepilogoStagione(backup);

    expect(r.azioni, greaterThan(300));
    expect(r.punti, greaterThan(0));
    expect(r.errori, greaterThan(0));
    // I punti sono `#` di battuta/attacco/muro: non possono superare il totale.
    expect(r.punti, lessThan(r.azioni));
  });

  test('le percentuali esistono e stanno in un intervallo sensato', () {
    final r = riepilogoStagione(backup);

    expect(r.efficienzaAttacco, isNotNull);
    expect(r.percentualeAce, inInclusiveRange(0, 100));
    expect(r.ricezionePerfetta, inInclusiveRange(0, 100));
    // L'efficienza può essere negativa, ma non oltre il -100%.
    expect(r.efficienzaAttacco, inInclusiveRange(-100, 100));
  });

  test('filtrando per una squadra che non esiste non resta nulla', () {
    final r = riepilogoStagione(backup, squadraUid: 'inesistente');

    expect(r.partite, 0);
    expect(r.azioni, 0);
    // Niente azioni ⇒ percentuali null, non zero.
    expect(r.efficienzaAttacco, isNull);
  });
}

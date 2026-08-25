import 'package:flutter_test/flutter_test.dart';
import 'package:idb_shim/idb_client_memory.dart';
import 'package:volley_web/archivio.dart';

/// L'archivio riceve la `IdbFactory` da fuori: qui si passa quella in memoria e
/// i test girano sulla VM, senza browser e senza scrivere su disco. È lo stesso
/// codice che nel guscio riceve quella del browser.
void main() {
  late ArchivioBackup archivio;

  setUp(() {
    // Una factory nuova per ogni test: due test che condividessero l'archivio
    // passerebbero o fallirebbero a seconda dell'ordine.
    archivio = ArchivioBackup(newIdbFactoryMemory());
  });

  test('un archivio mai usato non ha niente da restituire', () async {
    expect(await archivio.leggi(), isNull);
  });

  test('quello che si salva si rilegge identico', () async {
    await archivio.salva(nomeFile: 'stagione.json', json: '{"a":1}');

    final salvato = await archivio.leggi();
    expect(salvato, isNotNull);
    expect(salvato!.nomeFile, 'stagione.json');
    expect(salvato.json, '{"a":1}');
  });

  test('il testo si conserva alla lettera, non ri-serializzato', () async {
    // L'archivio non deve interpretare il documento: se lo rileggesse e lo
    // riscrivesse perderebbe l'ordine delle chiavi e i decimali com'erano.
    // Qui dentro c'è anche roba che un JSON mal ricopiato rovinerebbe.
    const originale =
        '{"formato":"volley_stratego_backup","x":0.1234,"nome":"Nettùnia \\"B\\""}';
    await archivio.salva(nomeFile: 'x.json', json: originale);

    expect((await archivio.leggi())!.json, originale);
  });

  test('salvare di nuovo sostituisce, non accumula', () async {
    // Un documento per volta: riesportare il backup a fine settimana deve
    // rimpiazzare quello vecchio, non lasciarne due in archivio.
    await archivio.salva(nomeFile: 'vecchio.json', json: '{"v":1}');
    await archivio.salva(nomeFile: 'nuovo.json', json: '{"v":2}');

    final salvato = await archivio.leggi();
    expect(salvato!.nomeFile, 'nuovo.json');
    expect(salvato.json, '{"v":2}');
  });

  test('azzerare toglie davvero il documento', () async {
    // È la promessa fatta a chi guarda la pagina su un computer non suo.
    await archivio.salva(nomeFile: 'stagione.json', json: '{"a":1}');
    await archivio.azzera();

    expect(await archivio.leggi(), isNull);
  });

  test('azzerare un archivio già vuoto non è un errore', () async {
    // Il bottone può essere premuto due volte, e la seconda non deve lanciare.
    await archivio.azzera();
    await archivio.azzera();

    expect(await archivio.leggi(), isNull);
  });

  test('un documento sopravvive alla chiusura della pagina', () async {
    // Il vero motivo per cui l'archivio esiste: F5 e i dati sono ancora lì.
    // Un'istanza nuova sulla stessa factory è ciò che più somiglia a una
    // seconda visita — l'oggetto Dart di prima non c'è più, l'archivio sì.
    final factory = newIdbFactoryMemory();
    await ArchivioBackup(factory)
        .salva(nomeFile: 'stagione.json', json: '{"a":1}');

    final dopoIlRicaricamento = await ArchivioBackup(factory).leggi();
    expect(dopoIlRicaricamento!.nomeFile, 'stagione.json');
  });

  test('un record senza i campi attesi vale come archivio vuoto', () async {
    // Difesa contro un record scritto da una versione futura o troncato: la
    // pagina deve ripartire dall'esempio, non rompersi su un campo mancante.
    final factory = newIdbFactoryMemory();
    final db = await factory.open('volley_dashboard', version: 1,
        onUpgradeNeeded: (e) => e.database.createObjectStore('documento'));
    final txn = db.transaction('documento', idbModeReadWrite);
    await txn.objectStore('documento').put({'altro': 'roba'}, 'corrente');
    await txn.completed;
    db.close();

    expect(await ArchivioBackup(factory).leggi(), isNull);
  });
}

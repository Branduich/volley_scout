import 'package:idb_shim/idb.dart';

/// Il documento che l'utente ha caricato, così com'è arrivato.
///
/// Si conserva il **testo JSON grezzo**, non l'oggetto già letto. Costa una
/// rilettura all'apertura della pagina, e in cambio: l'archivio non sa niente
/// del modello (quindi non va toccato quando il modello cambia), e un documento
/// scritto da una versione vecchia ripassa dagli stessi controlli di formato e
/// versione di un file appena trascinato — viene rifiutato con il messaggio
/// giusto invece di essere letto a metà.
class DocumentoSalvato {
  const DocumentoSalvato({
    required this.nomeFile,
    required this.json,
    required this.salvatoIl,
  });

  final String nomeFile;
  final String json;
  final DateTime salvatoIl;
}

/// L'ultimo backup caricato, conservato nel browser di chi guarda la pagina.
///
/// **Non è un server**: i dati non lasciano il computer, ed è la promessa
/// scritta nel banner della dashboard. IndexedDB è per-origine e per-browser,
/// quindi non passa ad altri dispositivi né ad altre persone.
///
/// La `IdbFactory` arriva da fuori, non viene importata qui: così il guscio
/// passa quella del browser e i test quella in memoria, e questo file non
/// dipende da `dart:html` — è ciò che lo rende collaudabile senza un browser.
///
/// I metodi **lasciano passare gli errori**. Uno spazio negato (navigazione in
/// incognito, archiviazione disattivata) non è un caso che l'archivio possa
/// risolvere: la politica — proseguire senza memoria invece di rompere la
/// pagina — sta nel guscio, in un punto solo.
class ArchivioBackup {
  ArchivioBackup(this._factory);

  final IdbFactory _factory;

  static const String _nomeDb = 'volley_dashboard';
  static const String _archivio = 'documento';
  // Un documento per volta: la dashboard mostra una stagione, e sostituirla è
  // il gesto normale. Una lista di documenti sarebbe un'altra funzione.
  static const String _chiave = 'corrente';

  static const String _campoNome = 'nomeFile';
  static const String _campoJson = 'json';
  static const String _campoData = 'salvatoIl';

  Future<Database> _apri() => _factory.open(
        _nomeDb,
        version: 1,
        onUpgradeNeeded: (VersionChangeEvent e) {
          e.database.createObjectStore(_archivio);
        },
      );

  Future<DocumentoSalvato?> leggi() async {
    final db = await _apri();
    try {
      final txn = db.transaction(_archivio, idbModeReadOnly);
      final valore = await txn.objectStore(_archivio).getObject(_chiave);
      await txn.completed;
      if (valore is! Map) return null;
      final nome = valore[_campoNome];
      final json = valore[_campoJson];
      final data = valore[_campoData];
      // Un record scritto da una versione precedente, o corrotto a metà, si
      // tratta come "niente in archivio": la pagina riparte dall'esempio
      // invece di rompersi su un campo mancante.
      if (nome is! String || json is! String) return null;
      return DocumentoSalvato(
        nomeFile: nome,
        json: json,
        salvatoIl: data is int
            ? DateTime.fromMillisecondsSinceEpoch(data)
            : DateTime.now(),
      );
    } finally {
      db.close();
    }
  }

  Future<void> salva({required String nomeFile, required String json}) async {
    final db = await _apri();
    try {
      final txn = db.transaction(_archivio, idbModeReadWrite);
      await txn.objectStore(_archivio).put({
        _campoNome: nomeFile,
        _campoJson: json,
        _campoData: DateTime.now().millisecondsSinceEpoch,
      }, _chiave);
      await txn.completed;
    } finally {
      db.close();
    }
  }

  Future<void> azzera() async {
    final db = await _apri();
    try {
      final txn = db.transaction(_archivio, idbModeReadWrite);
      await txn.objectStore(_archivio).delete(_chiave);
      await txn.completed;
    } finally {
      db.close();
    }
  }
}

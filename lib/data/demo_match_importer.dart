import 'package:flutter/services.dart' show rootBundle;

import '../providers/database_provider.dart';
import 'backup_json.dart';
import 'database.dart';

/// Carica nel database la **stagione dimostrativa**: cinque partite vere
/// (Nettunia, aprile 2026) con nomi inventati, la stessa che la dashboard web
/// mostra a chi arriva senza l'app.
///
/// Serve a sviluppare e provare report, statistiche e traiettorie con dati
/// realistici invece che con due azioni inserite a mano.
///
/// **Era un parser su misura di 190 righe** (passo 13 del piano in
/// docs/dati-stagionali.md): leggeva un formato inventato apposta per il demo,
/// con le sue chiavi e le sue conversioni. Ora il demo È un file di backup, e
/// caricarlo vuol dire ripristinarlo: la lettura la fa lo stesso codice che
/// legge i backup degli utenti. Un formato in meno da tenere in piedi, e il
/// demo diventa anche una prova continua che il ripristino funziona.
///
/// **SOSTITUISCE tutto** il contenuto del database, non aggiunge: è il
/// comportamento del ripristino, e il vecchio importatore invece accodava. Il
/// bottone che lo chiama vive solo in debug (`kDebugMode` in `MatchesScreen`)
/// e chiede conferma, quindi nessun utente può incontrarlo. Per accodare
/// servirebbe il merge per uid — il passo 4b, rimandato.
class DemoMatchImporter {
  DemoMatchImporter(this._db);
  final AppDatabase _db;

  /// Il file sta in `volley_stats` perché lo usa anche la dashboard web: una
  /// copia sola per due consumatori (vedi il pubspec di quel package).
  static const assetPath = 'packages/volley_stats/assets/backup_demo.json';

  /// Quante partite e azioni sono entrate.
  Future<({int partite, int azioni})> importa() async =>
      importaDaJson(await rootBundle.loadString(assetPath));

  /// Come [importa] ma sul JSON già letto. Serve ai test, che prendono l'asset
  /// con `File` (la cwd dei test è la root del progetto) e restano così puri:
  /// `rootBundle` richiederebbe il binding di Flutter.
  Future<({int partite, int azioni})> importaDaJson(String sorgente) =>
      BackupRepository(_db).ripristinaSostituendo(leggiBackupDaStringa(sorgente));
}

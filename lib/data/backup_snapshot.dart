import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Copia di sicurezza scattata **prima** di un ripristino distruttivo, per
/// poterlo annullare.
///
/// È ciò che trasforma "sostituisci tutto" da operazione irreversibile a
/// operazione con un passo indietro: un avviso, per quanto grosso, non protegge
/// nessuno — i dialog rossi si imparano a chiudere — mentre un "Annulla il
/// ripristino" a portata di mano sì.
///
/// **Un solo slot**: interessa l'ultimo ripristino, non la loro storia. Il file
/// vive nella cartella privata dell'app (non è pensato per essere aperto a mano
/// dall'utente: per quello c'è "Esporta backup", che passa dallo share sheet).
class SnapshotRipristino {
  static const _nomeFile = 'ripristino_precedente.json';

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _nomeFile));
  }

  /// Salva lo stato corrente prima di sovrascriverlo.
  static Future<void> salva(String json) async {
    final file = await _file();
    await file.writeAsString(json, flush: true);
  }

  /// Il backup precedente, se c'è, con la data in cui è stato scattato (che è
  /// quella mostrata nella voce "Annulla il ripristino").
  static Future<({String json, DateTime creato})?> leggi() async {
    final file = await _file();
    if (!await file.exists()) return null;
    return (
      json: await file.readAsString(),
      creato: await file.lastModified(),
    );
  }

  static Future<DateTime?> dataUltimo() async {
    final file = await _file();
    return await file.exists() ? file.lastModified() : null;
  }

  static Future<void> cancella() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
  }
}

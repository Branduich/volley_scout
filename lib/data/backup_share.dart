import 'dart:convert';

import 'package:share_plus/share_plus.dart';

/// Condivisione del file di backup tramite lo share sheet di Android (Drive,
/// WhatsApp, email, salva su File…). Sta in un file suo perché è l'unico pezzo
/// del backup che dipende da un plugin: `backup_json.dart` resta puro rispetto
/// alla piattaforma e `backup_model.dart` anche rispetto a drift.
///
/// Il nome del file porta la data, così i backup successivi non si sovrascrivono
/// a vicenda nella cartella Download.
String nomeFileBackup(DateTime adesso) {
  String due(int n) => n.toString().padLeft(2, '0');
  return 'volley_stratego_backup_'
      '${adesso.year}-${due(adesso.month)}-${due(adesso.day)}.json';
}

Future<void> condividiBackup(String json, {DateTime? adesso}) async {
  final nomeFile = nomeFileBackup(adesso ?? DateTime.now());

  // Stessa combinazione dell'export CSV, e per gli stessi motivi (vedi il
  // commento in match_csv_exporter.dart): `XFile.fromData` +
  // `fileNameOverrides` è l'unico modo in cui share_plus applica davvero il
  // nome — con un XFile costruito da un path l'override viene ignorato e il
  // file può arrivare all'app ricevente senza nome né estensione. E `subject`
  // deve essere il nome COMPLETO di estensione, perché "Salva su Drive" lo usa
  // come titolo del documento al posto del nome del file.
  await SharePlus.instance.share(ShareParams(
    files: [
      XFile.fromData(utf8.encode(json), mimeType: 'application/json'),
    ],
    fileNameOverrides: [nomeFile],
    subject: nomeFile,
  ));
}

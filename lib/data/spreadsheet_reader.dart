import 'dart:typed_data';

import 'xls_reader.dart';
import 'xlsx_reader.dart';

/// Punto unico di lettura di un foglio di calcolo: riconosce il formato dai
/// primi byte e delega al lettore giusto — `.xls` binario (BIFF8 in
/// contenitore OLE2, il formato dell'export FIPAV) o `.xlsx` (Open XML).
///
/// Si guarda il CONTENUTO, non l'estensione: un file rinominato a mano
/// funziona lo stesso, e chi sbaglia file riceve un messaggio sensato invece
/// di un errore di parsing incomprensibile.
List<List<String>> leggiFoglioCalcolo(Uint8List bytes) {
  if (_iniziaCon(bytes, const [0xD0, 0xCF, 0x11, 0xE0])) {
    return leggiXls(bytes);
  }
  if (_iniziaCon(bytes, const [0x50, 0x4B])) {
    // 'PK': un archivio zip. L'.xlsx lo è; altri zip falliranno più avanti
    // con un messaggio del lettore xlsx.
    return leggiXlsx(bytes);
  }
  if (_iniziaCon(bytes, const [0x3C])) {
    throw const FormatException(
      'Questo file contiene HTML, non un foglio di calcolo.',
    );
  }
  throw const FormatException(
    'Formato non riconosciuto: serve un file Excel .xls o .xlsx.',
  );
}

bool _iniziaCon(Uint8List bytes, List<int> firma) {
  if (bytes.length < firma.length) return false;
  for (var i = 0; i < firma.length; i++) {
    if (bytes[i] != firma[i]) return false;
  }
  return true;
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Lettore minimale di file **.xlsx** (Open XML: uno zip di XML), gemello di
/// `xls_reader.dart` per il formato moderno. Restituisce la stessa griglia
/// densa di stringhe, così tutto ciò che sta a valle (`parseGareFipav`,
/// classifica, repository, UI) non cambia di una riga.
///
/// Come per il `.xls`, NON è un lettore Excel generico: legge la prima
/// worksheet, risolve le stringhe condivise e rende ogni cella come testo.
/// Formattazione, formule (di cui si legge il risultato memorizzato), grafici
/// e fogli successivi sono ignorati.
///
/// **Date**: i calendari FIPAV hanno date e orari come TESTO (`12/10/2025`,
/// `11:00`), quindi non c'è nessuna conversione da seriale Excel — un file in
/// cui le date fossero numeri con un formato data mostrerebbe qui il numero
/// grezzo. Se un domani servisse, andrebbe letto `xl/styles.xml`.
List<List<String>> leggiXlsx(Uint8List bytes) {
  final Archive archivio;
  try {
    archivio = ZipDecoder().decodeBytes(bytes);
  } catch (e) {
    throw const FormatException(
      'File .xlsx illeggibile: l\'archivio è corrotto o incompleto.',
    );
  }

  String? contenuto(String percorso) {
    final file = archivio.findFile(percorso);
    if (file == null) return null;
    return utf8.decode(file.readBytes() ?? const [], allowMalformed: true);
  }

  final stringhe = _sharedStrings(contenuto('xl/sharedStrings.xml'));
  final percorsoFoglio = _percorsoPrimoFoglio(archivio, contenuto);
  final xmlFoglio = contenuto(percorsoFoglio);
  if (xmlFoglio == null) {
    throw const FormatException(
      'Nessun foglio di lavoro trovato nel file .xlsx.',
    );
  }

  return _celle(xmlFoglio, stringhe);
}

/// `xl/sharedStrings.xml` → lista indicizzata. Una `<si>` può essere spezzata
/// in più `<t>` (rich text: pezzi con formattazione diversa): si concatenano.
/// I `<rPh>` (guide fonetiche giapponesi) non sono testo della cella e vanno
/// esclusi, altrimenti finirebbero dentro al valore.
List<String> _sharedStrings(String? xml) {
  if (xml == null) return const [];
  final doc = XmlDocument.parse(xml);
  return [
    for (final si in doc.findAllElements('si'))
      si
          .findAllElements('t')
          .where((t) => t.parentElement?.localName != 'rPh')
          .map((t) => t.innerText)
          .join(),
  ];
}

/// Trova la prima worksheet seguendo `workbook.xml` → relazioni. Il nome
/// `sheet1.xml` è solo una convenzione: non tutti i generatori la rispettano,
/// quindi è il fallback e non la strada principale.
String _percorsoPrimoFoglio(
  Archive archivio,
  String? Function(String) contenuto,
) {
  final workbook = contenuto('xl/workbook.xml');
  final rels = contenuto('xl/_rels/workbook.xml.rels');
  if (workbook != null && rels != null) {
    try {
      final sheets = XmlDocument.parse(workbook).findAllElements('sheet');
      if (sheets.isNotEmpty) {
        final rid = sheets.first.getAttribute('r:id') ??
            sheets.first.getAttribute('id');
        if (rid != null) {
          for (final r in XmlDocument.parse(rels).findAllElements(
            'Relationship',
          )) {
            if (r.getAttribute('Id') != rid) continue;
            var target = r.getAttribute('Target') ?? '';
            if (target.isEmpty) break;
            if (target.startsWith('/')) return target.substring(1);
            if (!target.startsWith('xl/')) target = 'xl/$target';
            if (archivio.findFile(target) != null) return target;
          }
        }
      }
    } on XmlException {
      // XML malformato: si ricade sul percorso convenzionale.
    }
  }
  return 'xl/worksheets/sheet1.xml';
}

/// Scorre le celle del foglio e costruisce la griglia densa.
///
/// Le celle vuote non vengono registrate: è ciò che rende innocue le **righe
/// di riempimento** che alcuni generatori (Google Sheets in testa) aggiungono
/// in coda — un export di 43 righe utili può arrivare con 1000 `<row>`, e
/// senza questo accorgimento la griglia avrebbe centinaia di righe fantasma.
List<List<String>> _celle(String xml, List<String> stringhe) {
  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(xml);
  } on XmlException {
    throw const FormatException('Il foglio del file .xlsx è illeggibile.');
  }

  final celle = <int, Map<int, String>>{};
  var maxRiga = -1;
  var maxCol = -1;
  var rigaImplicita = 0;

  for (final riga in doc.findAllElements('row')) {
    // L'attributo `r` è opzionale: se manca si contano le righe in ordine.
    final r = int.tryParse(riga.getAttribute('r') ?? '');
    final indiceRiga = (r ?? rigaImplicita + 1) - 1;
    rigaImplicita = indiceRiga + 1;
    var colImplicita = 0;

    for (final cella in riga.findElements('c')) {
      final rif = cella.getAttribute('r');
      final indiceCol =
          rif != null ? _colonnaDaRiferimento(rif) : colImplicita;
      colImplicita = indiceCol + 1;

      final valore = _valoreCella(cella, stringhe);
      if (valore.isEmpty) continue;

      (celle[indiceRiga] ??= <int, String>{})[indiceCol] = valore;
      if (indiceRiga > maxRiga) maxRiga = indiceRiga;
      if (indiceCol > maxCol) maxCol = indiceCol;
    }
  }

  if (maxRiga < 0) return const [];
  return [
    for (var r = 0; r <= maxRiga; r++)
      [for (var c = 0; c <= maxCol; c++) celle[r]?[c] ?? ''],
  ];
}

/// Il valore testuale di una cella, in base al suo tipo (`t`):
/// `s` indice nella tabella condivisa, `inlineStr` testo annidato,
/// `str` risultato testuale di formula, `b` booleano, assente/`n` numero.
String _valoreCella(XmlElement cella, List<String> stringhe) {
  final tipo = cella.getAttribute('t');
  if (tipo == 'inlineStr') {
    final is_ = cella.getElement('is');
    return is_ == null
        ? ''
        : is_.findAllElements('t').map((t) => t.innerText).join();
  }

  final v = cella.getElement('v');
  if (v == null) return '';
  final grezzo = v.innerText;

  switch (tipo) {
    case 's':
      final i = int.tryParse(grezzo);
      return (i != null && i >= 0 && i < stringhe.length) ? stringhe[i] : '';
    case 'b':
      return grezzo == '1' ? 'VERO' : 'FALSO';
    case 'e': // errore di formula (#N/D, ...): non è un dato
      return '';
    case 'str':
      return grezzo;
    default:
      return _numero(grezzo);
  }
}

/// Numeri resi senza `.0` inutile, come nel lettore `.xls`: le colonne di
/// questo export sono testo, ma un altro generatore potrebbe scrivere
/// "Gara N" come numero.
String _numero(String grezzo) {
  final d = double.tryParse(grezzo);
  if (d == null) return grezzo;
  if (d == d.roundToDouble() && d.abs() < 1e15) return d.toInt().toString();
  return d.toString();
}

/// `"AB12"` → indice di colonna 0-based (AB = 27).
int _colonnaDaRiferimento(String riferimento) {
  var n = 0;
  for (final unita in riferimento.codeUnits) {
    if (unita >= 65 && unita <= 90) {
      n = n * 26 + (unita - 64);
    } else if (unita >= 97 && unita <= 122) {
      n = n * 26 + (unita - 96);
    } else {
      break; // sono iniziate le cifre della riga
    }
  }
  return n > 0 ? n - 1 : 0;
}

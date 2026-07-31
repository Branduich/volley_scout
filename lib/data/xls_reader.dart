import 'dart:convert';
import 'dart:typed_data';

/// Lettore minimale di file **.xls binari legacy** (BIFF8 dentro un
/// contenitore OLE2/CFB), scritto a mano perché **nessun package Dart legge
/// questo formato**: `excel`, `excel_plus` e `spreadsheet_decoder` gestiscono
/// solo l'Open XML `.xlsx` (zip + XML). Serve per importare il calendario di
/// campionato esportato dal sito FIPAV (vedi `logic/fipav_calendario.dart`).
///
/// Non è un lettore Excel generico: implementa solo il sottoinsieme di record
/// che quell'export usa davvero (celle stringa dalla SST, più i numerici per
/// sicurezza), sulla PRIMA worksheet del file. Formattazione, formule, date
/// come seriale, grafici e fogli successivi sono ignorati.
///
/// Restituisce una griglia densa di stringhe: `righe[r][c]`, celle mancanti
/// come stringa vuota. Lancia [FormatException] con un messaggio leggibile
/// dall'utente se il file non è del formato atteso.
List<List<String>> leggiXls(Uint8List bytes) {
  final workbook = _estraiWorkbookStream(bytes);
  return _BiffParser(workbook).leggiPrimoFoglio();
}

// ===========================================================================
// Livello 1 — contenitore OLE2 / Compound File Binary
// ===========================================================================

const _kSignatureOle2 = [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1];

/// Marcatori di fine catena nella FAT.
const int _kEndOfChain = 0xFFFFFFFE;
const int _kFreeSect = 0xFFFFFFFF;

/// Estrae la stream `Workbook` (o `Book`, nome usato dai file più vecchi) dal
/// contenitore OLE2.
Uint8List _estraiWorkbookStream(Uint8List bytes) {
  if (bytes.length < 512) {
    throw const FormatException(
      'File troppo piccolo per essere un .xls valido.',
    );
  }
  for (var i = 0; i < _kSignatureOle2.length; i++) {
    if (bytes[i] != _kSignatureOle2[i]) {
      // Diagnostica mirata sugli errori più probabili dell'utente.
      if (bytes[0] == 0x50 && bytes[1] == 0x4B) {
        throw const FormatException(
          'Questo è un file .xlsx, non un .xls. Dal sito FIPAV scegli '
          'l\'esportazione in formato Excel 97-2003 (.xls).',
        );
      }
      if (bytes[0] == 0x3C) {
        throw const FormatException(
          'Questo file contiene HTML, non un foglio Excel binario.',
        );
      }
      throw const FormatException(
        'Formato non riconosciuto: non è un file Excel .xls.',
      );
    }
  }

  final d = ByteData.sublistView(bytes);
  final settoreSize = 1 << d.getUint16(30, Endian.little);
  final miniSettoreSize = 1 << d.getUint16(32, Endian.little);
  final dirStart = d.getUint32(48, Endian.little);
  final miniCutoff = d.getUint32(56, Endian.little);
  final miniFatStart = d.getUint32(60, Endian.little);
  final difatStart = d.getUint32(68, Endian.little);
  final difatCount = d.getUint32(72, Endian.little);

  if (settoreSize < 128 || settoreSize > 65536) {
    throw const FormatException('Header OLE2 non valido (settore).');
  }

  Uint8List settore(int n) {
    final inizio = 512 + n * settoreSize;
    if (inizio < 0 || inizio + settoreSize > bytes.length) {
      throw const FormatException('File .xls troncato o corrotto.');
    }
    return Uint8List.sublistView(bytes, inizio, inizio + settoreSize);
  }

  // --- FAT: la lista dei settori che la compongono sta nel DIFAT (i primi
  // 109 elementi sono inline nell'header, il resto in una catena di settori).
  final settoriFat = <int>[];
  for (var i = 0; i < 109; i++) {
    final s = d.getUint32(76 + i * 4, Endian.little);
    if (s == _kFreeSect || s == _kEndOfChain) break;
    settoriFat.add(s);
  }
  var difat = difatStart;
  var difatRimasti = difatCount;
  while (difat != _kEndOfChain && difat != _kFreeSect && difatRimasti > 0) {
    final blocco = ByteData.sublistView(settore(difat));
    final perSettore = settoreSize ~/ 4 - 1; // l'ultimo è il link al prossimo
    for (var i = 0; i < perSettore; i++) {
      final s = blocco.getUint32(i * 4, Endian.little);
      if (s == _kFreeSect || s == _kEndOfChain) continue;
      settoriFat.add(s);
    }
    difat = blocco.getUint32(perSettore * 4, Endian.little);
    difatRimasti--;
  }

  final fat = <int>[];
  for (final s in settoriFat) {
    final blocco = ByteData.sublistView(settore(s));
    for (var i = 0; i < settoreSize ~/ 4; i++) {
      fat.add(blocco.getUint32(i * 4, Endian.little));
    }
  }

  /// Concatena la catena di settori che parte da [inizio], per [dimensione]
  /// byte. [tabella] è la FAT o la mini-FAT, [leggi] il lettore del settore
  /// corrispondente.
  Uint8List catena(
    int inizio,
    int dimensione,
    List<int> tabella,
    Uint8List Function(int) leggi,
    int passo,
  ) {
    final out = BytesBuilder(copy: false);
    var s = inizio;
    var guardia = 0;
    while (s != _kEndOfChain && s != _kFreeSect && out.length < dimensione) {
      if (s < 0 || s >= tabella.length) {
        throw const FormatException('Catena di settori non valida nel .xls.');
      }
      out.add(leggi(s));
      s = tabella[s];
      if (++guardia > tabella.length + 1) {
        throw const FormatException('Catena di settori ciclica nel .xls.');
      }
    }
    final tutto = out.takeBytes();
    return dimensione < tutto.length
        ? Uint8List.sublistView(tutto, 0, dimensione)
        : tutto;
  }

  // --- Directory: entry da 128 byte, cerchiamo "Workbook"/"Book" e la Root
  // (serve come contenitore della mini-stream).
  final dir = catena(dirStart, 1 << 30, fat, settore, settoreSize);
  final dd = ByteData.sublistView(dir);

  int? wbStart;
  int? wbSize;
  var rootStart = 0;
  var rootSize = 0;

  for (var off = 0; off + 128 <= dir.length; off += 128) {
    final lunghezzaNome = dd.getUint16(off + 64, Endian.little);
    if (lunghezzaNome < 2 || lunghezzaNome > 64) continue;
    final nome = _utf16(dir, off, lunghezzaNome - 2);
    final tipo = dir[off + 66];
    final start = dd.getUint32(off + 116, Endian.little);
    final size = dd.getUint32(off + 120, Endian.little);
    if (tipo == 5) {
      rootStart = start;
      rootSize = size;
    } else if (tipo == 2 && (nome == 'Workbook' || nome == 'Book')) {
      wbStart = start;
      wbSize = size;
    }
  }

  if (wbStart == null || wbSize == null || wbSize == 0) {
    throw const FormatException(
      'Nessun foglio di lavoro trovato nel file .xls.',
    );
  }

  if (wbSize >= miniCutoff) {
    return catena(wbStart, wbSize, fat, settore, settoreSize);
  }

  // Stream piccola: vive nella mini-stream, che a sua volta è la stream del
  // Root Entry nei settori normali.
  final miniStream = catena(rootStart, rootSize, fat, settore, settoreSize);
  final miniFatBytes = catena(miniFatStart, 1 << 30, fat, settore, settoreSize);
  final mf = ByteData.sublistView(miniFatBytes);
  final miniFat = <int>[
    for (var i = 0; i < miniFatBytes.length ~/ 4; i++)
      mf.getUint32(i * 4, Endian.little),
  ];
  Uint8List miniSettore(int n) {
    final inizio = n * miniSettoreSize;
    if (inizio + miniSettoreSize > miniStream.length) {
      throw const FormatException('Mini-stream troncata nel file .xls.');
    }
    return Uint8List.sublistView(miniStream, inizio, inizio + miniSettoreSize);
  }

  return catena(wbStart, wbSize, miniFat, miniSettore, miniSettoreSize);
}

String _utf16(Uint8List bytes, int offset, int lunghezza) {
  final unita = <int>[];
  for (var i = 0; i + 1 < lunghezza; i += 2) {
    unita.add(bytes[offset + i] | (bytes[offset + i + 1] << 8));
  }
  return String.fromCharCodes(unita);
}

// ===========================================================================
// Livello 2 — record BIFF8
// ===========================================================================

// Identificatori dei record che ci interessano; tutto il resto viene saltato.
const int _recBof = 0x0809;
const int _recEof = 0x000A;
const int _recBoundsheet = 0x0085;
const int _recSst = 0x00FC;
const int _recContinue = 0x003C;
const int _recLabelSst = 0x00FD;
const int _recLabel = 0x0204;
const int _recNumber = 0x0203;
const int _recRk = 0x027E;
const int _recMulRk = 0x00BD;

class _Record {
  const _Record(this.tipo, this.inizio, this.lunghezza);
  final int tipo;
  final int inizio; // offset del PAYLOAD nella stream
  final int lunghezza;
}

class _BiffParser {
  _BiffParser(this._stream) : _d = ByteData.sublistView(_stream);

  final Uint8List _stream;
  final ByteData _d;

  List<String> _sst = const [];

  List<_Record> _scansiona(int da) {
    final records = <_Record>[];
    var off = da;
    while (off + 4 <= _stream.length) {
      final tipo = _d.getUint16(off, Endian.little);
      final len = _d.getUint16(off + 2, Endian.little);
      if (off + 4 + len > _stream.length) break;
      records.add(_Record(tipo, off + 4, len));
      off += 4 + len;
    }
    return records;
  }

  List<List<String>> leggiPrimoFoglio() {
    final globals = _scansiona(0);
    if (globals.isEmpty || globals.first.tipo != _recBof) {
      throw const FormatException(
        'Il file .xls non è in formato BIFF8 (Excel 97-2003).',
      );
    }

    int? offsetFoglio;
    for (var i = 0; i < globals.length; i++) {
      final r = globals[i];
      if (r.tipo == _recBoundsheet && offsetFoglio == null) {
        offsetFoglio = _d.getUint32(r.inizio, Endian.little);
      } else if (r.tipo == _recSst) {
        _sst = _leggiSst(globals, i);
      } else if (r.tipo == _recEof) {
        break;
      }
    }

    if (offsetFoglio == null || offsetFoglio >= _stream.length) {
      throw const FormatException('Nessun foglio trovato nel file .xls.');
    }
    return _leggiCelle(offsetFoglio);
  }

  /// Decodifica la Shared String Table. Le stringhe possono essere spezzate su
  /// più record `CONTINUE`: al confine, il record successivo riparte con un
  /// **proprio byte di flags** che ridichiara la sola codifica (compressa
  /// Latin-1 vs UTF-16) della parte residua — una stringa può quindi cambiare
  /// codifica a metà. Per questo la lettura passa da un cursore che conosce i
  /// confini dei blocchi, invece di concatenarne ciecamente i payload.
  List<String> _leggiSst(List<_Record> records, int indiceSst) {
    final blocchi = <_Record>[records[indiceSst]];
    for (var i = indiceSst + 1; i < records.length; i++) {
      if (records[i].tipo != _recContinue) break;
      blocchi.add(records[i]);
    }
    final cur = _SstCursor(_stream, _d, blocchi);
    cur.salta(4); // conteggio totale (con ripetizioni), non ci serve
    final uniche = cur.uint32();
    final out = <String>[];
    for (var i = 0; i < uniche; i++) {
      if (cur.finito) break;
      out.add(cur.stringa());
    }
    return out;
  }

  List<List<String>> _leggiCelle(int offsetFoglio) {
    final celle = <int, Map<int, String>>{};
    var maxRiga = -1;
    var maxCol = -1;

    void set(int riga, int col, String valore) {
      if (valore.isEmpty) return;
      (celle[riga] ??= <int, String>{})[col] = valore;
      if (riga > maxRiga) maxRiga = riga;
      if (col > maxCol) maxCol = col;
    }

    for (final r in _scansiona(offsetFoglio)) {
      switch (r.tipo) {
        case _recEof:
          // Fine della PRIMA worksheet: i fogli successivi non ci servono.
          return _griglia(celle, maxRiga, maxCol);
        case _recLabelSst:
          final riga = _d.getUint16(r.inizio, Endian.little);
          final col = _d.getUint16(r.inizio + 2, Endian.little);
          final idx = _d.getUint32(r.inizio + 6, Endian.little);
          if (idx < _sst.length) set(riga, col, _sst[idx]);
        case _recLabel:
          final riga = _d.getUint16(r.inizio, Endian.little);
          final col = _d.getUint16(r.inizio + 2, Endian.little);
          set(riga, col, _stringaInline(r.inizio + 6));
        case _recNumber:
          final riga = _d.getUint16(r.inizio, Endian.little);
          final col = _d.getUint16(r.inizio + 2, Endian.little);
          set(riga, col, _numero(_d.getFloat64(r.inizio + 6, Endian.little)));
        case _recRk:
          final riga = _d.getUint16(r.inizio, Endian.little);
          final col = _d.getUint16(r.inizio + 2, Endian.little);
          set(riga, col,
              _numero(_daRk(_d.getUint32(r.inizio + 6, Endian.little))));
        case _recMulRk:
          final riga = _d.getUint16(r.inizio, Endian.little);
          final primaCol = _d.getUint16(r.inizio + 2, Endian.little);
          // payload: riga, colPrima, poi N × (xf 2B + rk 4B), infine colUltima
          final n = (r.lunghezza - 6) ~/ 6;
          for (var i = 0; i < n; i++) {
            final rk = _d.getUint32(r.inizio + 4 + i * 6 + 2, Endian.little);
            set(riga, primaCol + i, _numero(_daRk(rk)));
          }
        default:
          break; // BLANK, MULBLANK, ROW, DIMENSIONS, formattazione, ...
      }
    }
    return _griglia(celle, maxRiga, maxCol);
  }

  /// Stringa Unicode inline (record LABEL): `u16 cch`, `u8 flags`, caratteri.
  String _stringaInline(int offset) {
    final cch = _d.getUint16(offset, Endian.little);
    final flags = _stream[offset + 2];
    final dati = offset + 3;
    if (flags & 0x01 != 0) return _utf16(_stream, dati, cch * 2);
    return latin1.decode(Uint8List.sublistView(_stream, dati, dati + cch));
  }

  List<List<String>> _griglia(
    Map<int, Map<int, String>> celle,
    int maxRiga,
    int maxCol,
  ) {
    if (maxRiga < 0) return const [];
    return [
      for (var r = 0; r <= maxRiga; r++)
        [
          for (var c = 0; c <= maxCol; c++) celle[r]?[c] ?? '',
        ],
    ];
  }
}

/// I valori RK impacchettano un double in 32 bit: bit0 = "diviso 100",
/// bit1 = intero (30 bit con segno) invece dei 34 bit alti di un IEEE754.
double _daRk(int rk) {
  final centesimi = rk & 0x01 != 0;
  double v;
  if (rk & 0x02 != 0) {
    v = (rk.toSigned(32) >> 2).toDouble();
  } else {
    // I 30 bit utili sono i bit ALTI di un double: nel layout little-endian
    // finiscono nei byte 4..7, i primi quattro restano a zero.
    final b = ByteData(8)..setUint32(4, rk & 0xFFFFFFFC, Endian.little);
    v = b.getFloat64(0, Endian.little);
  }
  return centesimi ? v / 100 : v;
}

/// Numeri resi come stringa senza `.0` inutile: il parser a valle lavora su
/// testo (le colonne di questo export sono tutte stringhe, questo ramo è una
/// tolleranza per export di altri comitati).
String _numero(double v) {
  if (v == v.roundToDouble() && v.abs() < 1e15) {
    return v.toInt().toString();
  }
  return v.toString();
}

/// Cursore sui blocchi SST + CONTINUE, che gestisce il byte di flags
/// ridichiarato a ogni confine di record (vedi `_leggiSst`).
class _SstCursor {
  _SstCursor(this._stream, this._d, this._blocchi);

  final Uint8List _stream;
  final ByteData _d;
  final List<_Record> _blocchi;

  int _blocco = 0;
  int _offset = 0; // relativo al payload del blocco corrente

  bool get finito => _blocco >= _blocchi.length;

  int get _rimasti =>
      finito ? 0 : _blocchi[_blocco].lunghezza - _offset;

  /// Passa al blocco successivo quando quello corrente è esaurito.
  void _normalizza() {
    while (!finito && _rimasti <= 0) {
      _blocco++;
      _offset = 0;
    }
  }

  int _byte() {
    _normalizza();
    if (finito) throw const FormatException('SST troncata nel file .xls.');
    return _stream[_blocchi[_blocco].inizio + _offset++];
  }

  void salta(int n) {
    var rimanenti = n;
    while (rimanenti > 0) {
      _normalizza();
      if (finito) return;
      final passo = rimanenti < _rimasti ? rimanenti : _rimasti;
      _offset += passo;
      rimanenti -= passo;
    }
  }

  int uint16() {
    _normalizza();
    if (!finito && _rimasti >= 2) {
      final v = _d.getUint16(_blocchi[_blocco].inizio + _offset, Endian.little);
      _offset += 2;
      return v;
    }
    return _byte() | (_byte() << 8);
  }

  int uint32() => uint16() | (uint16() << 16);

  /// Legge una stringa SST, seguendo i cambi di codifica al confine dei
  /// blocchi: `cch` conta CARATTERI, non byte, quindi si legge carattere per
  /// carattere ricontrollando il flag a ogni nuovo blocco.
  String stringa() {
    final cch = uint16();
    final flags = _byte();
    var compressa = flags & 0x01 == 0;
    var nRuns = 0;
    var cbExt = 0;
    if (flags & 0x08 != 0) nRuns = uint16();
    if (flags & 0x04 != 0) cbExt = uint32();

    final unita = <int>[];
    var bloccoCorrente = _blocco;
    for (var i = 0; i < cch; i++) {
      _normalizza();
      if (finito) break;
      if (_blocco != bloccoCorrente) {
        // Nuovo record CONTINUE: il primo byte ridichiara la codifica.
        compressa = _byte() & 0x01 == 0;
        bloccoCorrente = _blocco;
        _normalizza();
        if (finito) break;
      }
      unita.add(compressa ? _byte() : (_byte() | (_byte() << 8)));
    }

    salta(nRuns * 4 + cbExt);
    return String.fromCharCodes(unita);
  }
}

import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volley_scout/data/spreadsheet_reader.dart';
import 'package:volley_scout/data/xlsx_reader.dart';
import 'package:volley_scout/logic/classifica.dart';
import 'package:volley_scout/logic/fipav_calendario.dart';

/// Fixture reale: lo stesso calendario FIPAV convertito in .xlsx (generato da
/// Google Sheets), girone COMPLETO — 42 gare, con le ultime due giornate
/// svuotate a mano per simulare le gare non ancora giocate.
Uint8List _fixture() => File(
      'docs/samples/Calendario completo senza 14 giornata.xlsx',
    ).readAsBytesSync();

/// Costruisce al volo un .xlsx minimo, per i casi che la fixture non copre.
Uint8List _xlsxDiProva({
  required String foglio,
  String? sharedStrings,
}) {
  final archivio = Archive();
  void aggiungi(String nome, String contenuto) {
    final b = contenuto.codeUnits;
    archivio.add(ArchiveFile.bytes(nome, Uint8List.fromList(b)));
  }

  aggiungi(
    'xl/workbook.xml',
    '<workbook xmlns:r="http://x"><sheets>'
        '<sheet name="Foglio" sheetId="1" r:id="rId1"/></sheets></workbook>',
  );
  aggiungi(
    'xl/_rels/workbook.xml.rels',
    '<Relationships><Relationship Id="rId1" Target="worksheets/foglio.xml"/>'
        '</Relationships>',
  );
  aggiungi('xl/worksheets/foglio.xml', foglio);
  if (sharedStrings != null) {
    aggiungi('xl/sharedStrings.xml', sharedStrings);
  }
  return Uint8List.fromList(ZipEncoder().encode(archivio));
}

void main() {
  group('leggiXlsx sulla fixture reale', () {
    test('legge le righe utili ignorando quelle di riempimento', () {
      final righe = leggiXlsx(_fixture());

      // Google Sheets scrive 1000 <row>, ma solo 43 hanno celle:
      // intestazione + 42 gare (girone completo di 7 squadre, A/R).
      expect(righe.length, 43);
      expect(righe.first.length, 12);
    });

    test('header identico a quello del .xls', () {
      expect(leggiXlsx(_fixture()).first, [
        'Campionato',
        'Gara N',
        'Giornata',
        'Data',
        'Ora',
        'SquadraCasa',
        'SquadraOspite',
        'Risultato',
        'Parziali',
        'StatoDescrizione',
        'Impianto',
        'IndirizzoImpianto',
      ]);
    });

    test('prima riga dati completa', () {
      final riga = leggiXlsx(_fixture())[1];

      expect(riga[1], '386');
      expect(riga[3], '12/10/2025');
      expect(riga[4], '11:00');
      expect(riga[5], 'MASI VOLLEY PINK B');
      expect(riga[6], 'NETTUNIA');
      expect(riga[7], '3-0');
      expect(riga[8], '26-24 25-15 25-12');
      expect(riga[10], 'Sc.Galilei 1 - CASALECCHIO DI RENO (BO)');
    });

    test('le gare non giocate hanno risultato, parziali e stato vuoti', () {
      final righe = leggiXlsx(_fixture());
      final ultima = righe.last;

      expect(ultima[5], isNotEmpty); // le squadre ci sono
      expect(ultima[6], isNotEmpty);
      expect(ultima[7], isEmpty); // Risultato
      expect(ultima[8], isEmpty); // Parziali
      expect(ultima[9], isEmpty); // StatoDescrizione
    });

    test('gli spazi finali dei nomi squadra sono conservati nel grezzo', () {
      // xml:space="preserve" su "MOLINVOLLEY ": il trim tocca a parseGareFipav.
      final nomi = leggiXlsx(_fixture())
          .skip(1)
          .expand((r) => [r[5], r[6]])
          .toSet();

      expect(nomi.any((n) => n != n.trim()), isTrue);
    });
  });

  group('la catena completa funziona identica al .xls', () {
    EsitoParsingFipav parsing() => parseGareFipav(leggiXlsx(_fixture()));

    test('42 gare, nessuna riga scartata (il riempimento non conta)', () {
      final esito = parsing();

      expect(esito.gare.length, 42);
      expect(esito.righeScartate, 0);
    });

    test('le ultime due giornate risultano da giocare', () {
      final gare = parsing().gare;

      // 2 giornate × 3 gare (7 squadre: una riposa a turno).
      expect(gare.where((g) => !g.giocata).length, 6);
      expect(gare.last.giocata, isFalse);
      expect(gare.last.risultato, isNull);
    });

    test('girone completo: la classifica NON è segnalata come parziale', () {
      final gare = parsing().gare;

      expect(squadraUnicaDelFiltro(gare), isNull);
      final c = calcolaClassifica(gare);
      expect(c.length, 7);
      // Ogni squadra riposa una volta per girone: 12 gare giocate a testa
      // meno quelle dell'ultima giornata non disputata.
      expect(c.every((r) => r.giocate > 0), isTrue);
      expect(c.map((r) => r.punti).reduce((a, b) => a + b), greaterThan(0));
    });

    test('i nomi squadra vengono trimmati come nel .xls', () {
      final nomi = {for (final g in parsing().gare) ...g.squadre};

      expect(nomi.length, 7);
      expect(nomi, contains('MOLINVOLLEY'));
      expect(nomi.any((n) => n != n.trim()), isFalse);
    });
  });

  group('leggiXlsx — casi limite', () {
    test('stringhe inline e valori numerici', () {
      final bytes = _xlsxDiProva(
        foglio: '<worksheet><sheetData>'
            '<row r="1">'
            '<c r="A1" t="inlineStr"><is><t>Ciao</t></is></c>'
            '<c r="B1"><v>42</v></c>'
            '<c r="C1"><v>3.5</v></c>'
            '</row></sheetData></worksheet>',
      );

      expect(leggiXlsx(bytes), [
        ['Ciao', '42', '3.5'],
      ]);
    });

    test('rich text: i pezzi di una stessa cella si concatenano', () {
      final bytes = _xlsxDiProva(
        sharedStrings: '<sst><si><r><t>VOLLEY</t></r><r><t xml:space='
            '"preserve"> CASTELLO</t></r></si></sst>',
        foglio: '<worksheet><sheetData><row r="1">'
            '<c r="A1" t="s"><v>0</v></c>'
            '</row></sheetData></worksheet>',
      );

      expect(leggiXlsx(bytes).first.first, 'VOLLEY CASTELLO');
    });

    test('colonne oltre la Z (AA, AB) finiscono nella posizione giusta', () {
      final bytes = _xlsxDiProva(
        foglio: '<worksheet><sheetData><row r="1">'
            '<c r="A1" t="inlineStr"><is><t>prima</t></is></c>'
            '<c r="AB1" t="inlineStr"><is><t>ventottesima</t></is></c>'
            '</row></sheetData></worksheet>',
      );

      final riga = leggiXlsx(bytes).first;
      expect(riga.length, 28);
      expect(riga.first, 'prima');
      expect(riga.last, 'ventottesima');
    });

    test('celle con errore di formula diventano vuote', () {
      final bytes = _xlsxDiProva(
        foglio: '<worksheet><sheetData><row r="1">'
            '<c r="A1" t="e"><v>#N/A</v></c>'
            '<c r="B1" t="inlineStr"><is><t>ok</t></is></c>'
            '</row></sheetData></worksheet>',
      );

      expect(leggiXlsx(bytes).first, ['', 'ok']);
    });

    test('un file zip che non è un xlsx viene rifiutato', () {
      final archivio = Archive()
        ..add(ArchiveFile.bytes(
          'lettera.txt',
          Uint8List.fromList('ciao'.codeUnits),
        ));
      final bytes = Uint8List.fromList(ZipEncoder().encode(archivio));

      expect(() => leggiXlsx(bytes), throwsA(isA<FormatException>()));
    });
  });

  group('leggiFoglioCalcolo — riconoscimento del formato', () {
    test('riconosce l\'xlsx dai byte', () {
      expect(leggiFoglioCalcolo(_fixture()).length, 43);
    });

    test('riconosce il .xls binario dai byte', () {
      final xls =
          File('docs/samples/GareNettunia.xls').readAsBytesSync();

      expect(leggiFoglioCalcolo(xls).length, 13);
    });

    test('HTML rifiutato con messaggio dedicato', () {
      final html = Uint8List.fromList('<html><body>'.codeUnits);

      expect(
        () => leggiFoglioCalcolo(html),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('HTML'))),
      );
    });

    test('formato ignoto rifiutato', () {
      expect(
        () => leggiFoglioCalcolo(Uint8List.fromList(List.filled(64, 0x41))),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

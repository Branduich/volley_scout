import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:volley_scout/data/xls_reader.dart';

/// Fixture reale: export del calendario FIPAV (BIFF8 binario in contenitore
/// OLE2) filtrato sulla società NETTUNIA — 12 gare di un girone Under 18.
Uint8List _fixture() =>
    File('docs/samples/GareNettunia.xls').readAsBytesSync();

void main() {
  group('leggiXls', () {
    test('legge la griglia della fixture FIPAV', () {
      final righe = leggiXls(_fixture());

      // header + 12 gare (la giornata 7 manca: turno di riposo)
      expect(righe.length, 13);
      expect(righe.first.length, 12);
    });

    test('header con i nomi delle colonne attesi', () {
      final header = leggiXls(_fixture()).first;

      expect(header, [
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
      final riga = leggiXls(_fixture())[1];

      expect(riga[0], 'UNDER 18 FEMMINILE GIRONE B');
      expect(riga[1], '386');
      expect(riga[2], '1');
      expect(riga[3], '12/10/2025');
      expect(riga[4], '11:00');
      expect(riga[5], 'MASI VOLLEY PINK B');
      expect(riga[6], 'NETTUNIA');
      expect(riga[7], '3-0');
      expect(riga[8], '26-24 25-15 25-12');
      expect(riga[9], 'gara omologata');
      expect(riga[10], 'Sc.Galilei 1 - CASALECCHIO DI RENO (BO)');
      expect(riga[11], 'Via Porrettana 97');
    });

    test('ultima riga dati', () {
      final righe = leggiXls(_fixture());
      final riga = righe.last;

      expect(riga[1], '422');
      expect(riga[3], '18/01/2026');
      expect(riga[5], 'US ZOLA MSP VOLLEY');
      expect(riga[6], 'NETTUNIA');
      expect(riga[7], '3-0');
    });

    test('mantiene i valori ripetuti della SST su tutte le righe', () {
      final righe = leggiXls(_fixture()).skip(1);

      // Il campionato è la stessa stringa condivisa su ogni riga.
      expect(
        righe.every((r) => r[0] == 'UNDER 18 FEMMINILE GIRONE B'),
        isTrue,
      );
      // Ogni gara riguarda NETTUNIA (export filtrato per società).
      expect(
        righe.every((r) => r[5] == 'NETTUNIA' || r[6] == 'NETTUNIA'),
        isTrue,
      );
    });

    test('un file xlsx viene rifiutato con un messaggio chiaro', () {
      final finto = Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, ...List.filled(600, 0)]);

      expect(
        () => leggiXls(finto),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('.xlsx'),
          ),
        ),
      );
    });

    test('un file non Excel viene rifiutato', () {
      final finto = Uint8List.fromList(List.filled(600, 0x41));

      expect(() => leggiXls(finto), throwsA(isA<FormatException>()));
    });
  });
}

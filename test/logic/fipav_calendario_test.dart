import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:volley_scout/data/xls_reader.dart';
import 'package:volley_scout/logic/fipav_calendario.dart';

EsitoParsingFipav _daFixture() =>
    parseGareFipav(leggiXls(File('docs/samples/GareNettunia.xls').readAsBytesSync()));

void main() {
  group('parseGareFipav sulla fixture reale', () {
    test('legge tutte le gare senza scartare righe', () {
      final esito = _daFixture();

      expect(esito.gare.length, 12); // la giornata 7 è un turno di riposo
      expect(esito.righeScartate, 0);
    });

    test('prima gara completa', () {
      final g = _daFixture().gare.first;

      expect(g.campionato, 'UNDER 18 FEMMINILE GIRONE B');
      expect(g.garaNumero, 386);
      expect(g.giornata, 1);
      expect(g.dataOra, DateTime(2025, 10, 12, 11, 0));
      expect(g.squadraCasa, 'MASI VOLLEY PINK B');
      expect(g.squadraOspite, 'NETTUNIA');
      expect(g.risultato, '3-0');
      expect(g.impianto, 'Sc.Galilei 1 - CASALECCHIO DI RENO (BO)');
      expect(g.indirizzoImpianto, 'Via Porrettana 97');
      expect(g.statoDescrizione, 'gara omologata');
    });

    test('set e parziali derivati dal risultato', () {
      final g = _daFixture().gare.first;

      expect(g.giocata, isTrue);
      expect(g.setCasa, 3);
      expect(g.setOspite, 0);
      expect(g.parzialiParsed, [(26, 24), (25, 15), (25, 12)]);
    });

    test('i nomi squadra sono trimmati', () {
      // Nel file "MOLINVOLLEY " ha uno spazio finale: senza trim spaccherebbe
      // il raggruppamento della classifica.
      final nomi = {
        for (final g in _daFixture().gare) ...g.squadre,
      };

      expect(nomi, contains('MOLINVOLLEY'));
      expect(nomi.any((n) => n != n.trim()), isFalse);
      // 7 squadre nel girone (6 avversarie + NETTUNIA)
      expect(nomi.length, 7);
    });

    test('gare ordinate per data', () {
      final date = _daFixture().gare.map((g) => g.dataOra).toList();

      expect(date, orderedEquals(List.of(date)..sort()));
      expect(date.last, DateTime(2026, 1, 18, 10, 45));
    });

    test('una gara a 5 set legge tutti i parziali', () {
      final g = _daFixture().gare.firstWhere((g) => g.garaNumero == 407);

      expect(g.risultato, '3-2');
      expect(g.parzialiParsed.length, 5);
      expect(g.parzialiParsed.last, (15, 6));
    });
  });

  group('parseGareFipav — casi limite', () {
    List<List<String>> conRighe(List<List<String>> dati) => [
          ['Campionato', 'Gara N', 'Giornata', 'Data', 'Ora', 'SquadraCasa',
           'SquadraOspite', 'Risultato', 'Parziali'],
          ...dati,
        ];

    test('gara futura: nessun risultato', () {
      final esito = parseGareFipav(conRighe([
        ['Serie C', '1', '1', '05/02/2026', '21:00', 'ALFA', 'BETA', '', ''],
      ]));

      final g = esito.gare.single;
      expect(g.giocata, isFalse);
      expect(g.setCasa, isNull);
      expect(g.parzialiParsed, isEmpty);
    });

    test('ora mancante: mezzanotte', () {
      final esito = parseGareFipav(conRighe([
        ['Serie C', '1', '1', '05/02/2026', '', 'ALFA', 'BETA', '', ''],
      ]));

      expect(esito.gare.single.dataOra, DateTime(2026, 2, 5));
    });

    test('riga con data illeggibile viene scartata e contata', () {
      final esito = parseGareFipav(conRighe([
        ['Serie C', '1', '1', 'da definire', '', 'ALFA', 'BETA', '', ''],
        ['Serie C', '2', '1', '05/02/2026', '21:00', 'GAMMA', 'DELTA', '', ''],
      ]));

      expect(esito.gare.length, 1);
      expect(esito.righeScartate, 1);
    });

    test('riga completamente vuota non conta come scartata', () {
      final esito = parseGareFipav(conRighe([
        ['', '', '', '', '', '', '', '', ''],
      ]));

      expect(esito.gare, isEmpty);
      expect(esito.righeScartate, 0);
    });

    test('header senza le colonne chiave: errore esplicito', () {
      expect(
        () => parseGareFipav([
          ['Pippo', 'Pluto'],
          ['1', '2'],
        ]),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('squadracasa'), contains('Pippo')),
          ),
        ),
      );
    });

    test('colonne in ordine diverso: si mappano per nome', () {
      final esito = parseGareFipav([
        ['SquadraOspite', 'Data', 'SquadraCasa', 'Campionato'],
        ['BETA', '05/02/2026', 'ALFA', 'Serie C'],
      ]);

      final g = esito.gare.single;
      expect(g.squadraCasa, 'ALFA');
      expect(g.squadraOspite, 'BETA');
      expect(g.campionato, 'Serie C');
    });
  });
}

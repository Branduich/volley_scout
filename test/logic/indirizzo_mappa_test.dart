import 'package:flutter_test/flutter_test.dart';
import 'package:volley_scout/logic/indirizzo_mappa.dart';

void main() {
  group('queryMappaDaPalestra — forma dell\'import FIPAV', () {
    test('sposta l\'indirizzo davanti e butta il nome dell\'impianto', () {
      expect(
        queryMappaDaPalestra(
          'Sc.Galilei 1 - CASALECCHIO DI RENO (BO), Via Porrettana 97',
        ),
        'Via Porrettana 97, CASALECCHIO DI RENO (BO)',
      );
    });

    test('tutte le palestre della fixture reale', () {
      const casi = {
        'Sc.Pepoli - BOLOGNA (BO), Largo Lercaro 14':
            'Largo Lercaro 14, BOLOGNA (BO)',
        'Pal.Alberghiero - CASTEL SAN PIETRO TERME (BO), Viale delle Terme 1054':
            'Viale delle Terme 1054, CASTEL SAN PIETRO TERME (BO)',
        'Pal.Comunale Scuole - MOLINELLA (BO), Viale della Liberta\' 6':
            'Viale della Liberta\' 6, MOLINELLA (BO)',
        'Pal.Morselli - SAN GIOVANNI IN PERSICETO (BO), Via Rodari 2':
            'Via Rodari 2, SAN GIOVANNI IN PERSICETO (BO)',
        'Sc.Mezzacasa - SAN GIOVANNI IN PERSICETO (BO), Via Nuova 27/c':
            'Via Nuova 27/c, SAN GIOVANNI IN PERSICETO (BO)',
        'PalaRiale - ZOLA PREDOSA (BO), Via Gesso 26':
            'Via Gesso 26, ZOLA PREDOSA (BO)',
      };

      casi.forEach((input, atteso) {
        expect(queryMappaDaPalestra(input), atteso, reason: input);
      });
    });

    test('un impianto col trattino nel nome usa l\'ultima virgola', () {
      // "Pal.Ex-Gil" contiene un trattino ma senza spazi attorno: il separatore
      // riconosciuto resta " - " prima del comune.
      expect(
        queryMappaDaPalestra('Pal.Ex-Gil - IMOLA (BO), Via Fratelli Bandiera 1'),
        'Via Fratelli Bandiera 1, IMOLA (BO)',
      );
    });
  });

  group('queryMappaDaPalestra — testo scritto a mano, mai riscritto', () {
    test('un indirizzo semplice resta identico', () {
      expect(queryMappaDaPalestra('Via Roma 3, Bologna'),
          'Via Roma 3, Bologna');
    });

    test('un nome generico resta identico', () {
      expect(queryMappaDaPalestra('Palestra della scuola'),
          'Palestra della scuola');
    });

    test('senza virgola resta identico', () {
      expect(queryMappaDaPalestra('Pal.Morselli - MOLINELLA (BO)'),
          'Pal.Morselli - MOLINELLA (BO)');
    });

    test('senza " - " resta identico', () {
      expect(queryMappaDaPalestra('Palestra comunale, Via Roma 3'),
          'Palestra comunale, Via Roma 3');
    });

    test('stringa vuota o soli spazi', () {
      expect(queryMappaDaPalestra(''), '');
      expect(queryMappaDaPalestra('   '), '');
    });

    test('gli spazi ai bordi vengono comunque ripuliti', () {
      expect(queryMappaDaPalestra('  Via Roma 3  '), 'Via Roma 3');
    });
  });
}

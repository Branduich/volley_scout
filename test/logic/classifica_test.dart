import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:volley_scout/data/xls_reader.dart';
import 'package:volley_scout/logic/classifica.dart';
import 'package:volley_scout/logic/fipav_calendario.dart';

GaraFipav _gara(
  String casa,
  String ospite, {
  String? risultato,
  String? parziali,
  int giorno = 1,
}) =>
    GaraFipav(
      campionato: 'Test',
      dataOra: DateTime(2026, 1, giorno),
      squadraCasa: casa,
      squadraOspite: ospite,
      risultato: risultato,
      parziali: parziali,
    );

void main() {
  group('puntiGara — regolamento FIPAV', () {
    test('3-0 e 3-1 danno 3 punti al vincitore e 0 al perdente', () {
      expect(puntiGara(3, 0), (3, 0));
      expect(puntiGara(3, 1), (3, 0));
    });

    test('3-2 dà 2 punti al vincitore e 1 al perdente', () {
      expect(puntiGara(3, 2), (2, 1));
    });
  });

  group('calcolaClassifica', () {
    test('una gara 3-0 assegna 3 punti e i set', () {
      final c = calcolaClassifica([
        _gara('ALFA', 'BETA', risultato: '3-0', parziali: '25-20 25-18 25-10'),
      ]);

      expect(c.first.squadra, 'ALFA');
      expect(c.first.punti, 3);
      expect(c.first.vinte, 1);
      expect(c.first.perse, 0);
      expect(c.first.setVinti, 3);
      expect(c.first.setPersi, 0);
      expect(c.first.puntiFatti, 75);
      expect(c.first.puntiSubiti, 48);

      expect(c.last.squadra, 'BETA');
      expect(c.last.punti, 0);
      expect(c.last.perse, 1);
      expect(c.last.setVinti, 0);
      expect(c.last.puntiFatti, 48);
    });

    test('il tie-break 3-2 dà 1 punto anche a chi perde', () {
      final c = calcolaClassifica([
        _gara('ALFA', 'BETA', risultato: '2-3'),
      ]);

      final alfa = c.firstWhere((r) => r.squadra == 'ALFA');
      final beta = c.firstWhere((r) => r.squadra == 'BETA');
      expect(beta.punti, 2);
      expect(beta.vinte, 1);
      expect(alfa.punti, 1);
      expect(alfa.perse, 1);
      // Chi ha vinto sta comunque davanti: più punti.
      expect(c.first.squadra, 'BETA');
    });

    test('le gare non giocate non contano', () {
      final c = calcolaClassifica([
        _gara('ALFA', 'BETA'),
        _gara('ALFA', 'GAMMA', risultato: '3-1'),
      ]);

      final alfa = c.firstWhere((r) => r.squadra == 'ALFA');
      expect(alfa.giocate, 1);
      expect(alfa.punti, 3);
      // BETA compare comunque in classifica, a zero.
      final beta = c.firstWhere((r) => r.squadra == 'BETA');
      expect(beta.giocate, 0);
      expect(beta.punti, 0);
    });

    test('a parità di punti conta prima il numero di gare vinte', () {
      // ALFA: due vittorie al tie-break (2+2 = 4 punti, 2 vinte).
      // BETA: una vittoria piena + un tie-break perso (3+1 = 4 punti, 1 vinta).
      // Stessi punti, ma ALFA ha vinto di più → sta davanti, anche se il suo
      // quoziente set è peggiore.
      final c = calcolaClassifica([
        _gara('ALFA', 'X', risultato: '3-2'),
        _gara('ALFA', 'Y', risultato: '3-2'),
        _gara('BETA', 'W', risultato: '3-0'),
        _gara('BETA', 'Z', risultato: '2-3'),
      ]);

      final alfa = c.firstWhere((r) => r.squadra == 'ALFA');
      final beta = c.firstWhere((r) => r.squadra == 'BETA');
      expect(alfa.punti, 4);
      expect(beta.punti, 4);
      expect(alfa.vinte, 2);
      expect(beta.vinte, 1);
      expect(alfa.quozienteSet, lessThan(beta.quozienteSet));
      expect(
        c.indexOf(alfa),
        lessThan(c.indexOf(beta)),
        reason: 'le gare vinte battono il quoziente set',
      );
    });

    test('a parità di punti e vittorie ordina per quoziente set', () {
      final c = calcolaClassifica([
        // ALFA: 3-0 (quoziente set infinito-ish)
        _gara('ALFA', 'DELTA', risultato: '3-0'),
        // BETA: 3-2 su GAMMA (2 punti) + 3-0 su DELTA (3 punti) = 5
        _gara('BETA', 'GAMMA', risultato: '3-2'),
        _gara('BETA', 'DELTA', risultato: '3-0'),
        // GAMMA: 1 punto dal tie-break perso + 3-1 = 4
        _gara('GAMMA', 'DELTA', risultato: '3-1'),
      ]);

      expect(c.map((r) => r.squadra).toList(),
          ['BETA', 'GAMMA', 'ALFA', 'DELTA']);
      expect(c[0].punti, 5);
      expect(c[1].punti, 4);
      expect(c[2].punti, 3);
      expect(c[3].punti, 0);
    });

    test('a parità di punti e set decide il quoziente punti', () {
      final c = calcolaClassifica([
        _gara('ALFA', 'X', risultato: '3-0', parziali: '25-10 25-10 25-10'),
        _gara('BETA', 'Y', risultato: '3-0', parziali: '25-23 25-23 25-23'),
      ]);

      expect(c.first.squadra, 'ALFA');
      expect(c.first.punti, c[1].punti);
      expect(c.first.quozientePunti, greaterThan(c[1].quozientePunti));
    });

    test('un risultato malformato viene ignorato senza lanciare', () {
      final c = calcolaClassifica([
        _gara('ALFA', 'BETA', risultato: 'rinviata'),
        _gara('ALFA', 'BETA', risultato: '3-3'), // impossibile
      ]);

      expect(c.every((r) => r.giocate == 0), isTrue);
    });
  });

  group('squadraUnicaDelFiltro', () {
    test('riconosce un export filtrato per società', () {
      final gare = [
        _gara('ALFA', 'NETTUNIA', risultato: '3-0'),
        _gara('NETTUNIA', 'BETA', risultato: '3-0'),
        _gara('GAMMA', 'NETTUNIA', risultato: '3-0'),
      ];

      expect(squadraUnicaDelFiltro(gare), 'NETTUNIA');
    });

    test('null su un girone completo', () {
      final gare = [
        _gara('ALFA', 'BETA', risultato: '3-0'),
        _gara('GAMMA', 'DELTA', risultato: '3-0'),
      ];

      expect(squadraUnicaDelFiltro(gare), isNull);
    });
  });

  group('sulla fixture reale (export filtrato NETTUNIA)', () {
    List<GaraFipav> gare() => parseGareFipav(
          leggiXls(File('docs/samples/GareNettunia.xls').readAsBytesSync()),
        ).gare;

    test('la fixture è riconosciuta come parziale', () {
      expect(squadraUnicaDelFiltro(gare()), 'NETTUNIA');
    });

    test('NETTUNIA ha giocato tutte e 12 le gare del file', () {
      final c = calcolaClassifica(gare());
      final nettunia = c.firstWhere((r) => r.squadra == 'NETTUNIA');

      expect(nettunia.giocate, 12);
      expect(nettunia.vinte + nettunia.perse, 12);
      // 7 squadre totali nel file.
      expect(c.length, 7);
    });

    test('i punti di NETTUNIA tornano col conteggio manuale', () {
      final c = calcolaClassifica(gare());
      final n = c.firstWhere((r) => r.squadra == 'NETTUNIA');

      // Dal file: vinte 3-2 (gara 407) e 3-1 (413) e 3-1 (419) → NETTUNIA
      // vince 3 gare; una di queste al tie-break vale 2 punti.
      expect(n.vinte, 3);
      expect(n.perse, 9);
      // 2 vittorie piene (3) + 1 al tie-break (2) = 8, più i tie-break persi
      // (nessuno: le sconfitte sono tutte 0-3/1-3).
      expect(n.punti, 8);
    });
  });
}

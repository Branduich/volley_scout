import 'package:flutter_test/flutter_test.dart';
import 'package:volley_stats/enums.dart';
import 'package:volley_stats/stat_fondamentali.dart';

/// Le definizioni di efficienza e positività: prima esistevano in tre copie
/// tenute allineate da un commento, e non erano coperte da nessun test.
void main() {
  group('efficienza', () {
    test('punti meno errori, sul totale delle azioni votate', () {
      // 5 perfette, 2 errori, 10 azioni ⇒ (5-2)/10 = 30%.
      expect(efficienza(punti: 5, errori: 2, totale: 10), 30);
    });

    test('è NEGATIVA quando gli errori superano i punti', () {
      // È il motivo per cui non si può usare un tipo senza segno o clampare a
      // zero: un fondamentale in perdita deve poterlo dire.
      expect(efficienza(punti: 1, errori: 4, totale: 10), -30);
    });

    test('senza azioni torna null, non zero', () {
      // "Nessun dato" e "zero per cento" sono cose diverse: chi disegna mostra
      // '—' per il primo. E non si divide mai per zero.
      expect(efficienza(punti: 0, errori: 0, totale: 0), isNull);
    });

    test('le azioni di mezzo abbassano la percentuale', () {
      // Stessi punti ed errori, più azioni neutre: l'efficienza scende.
      expect(efficienza(punti: 3, errori: 0, totale: 6), 50);
      expect(efficienza(punti: 3, errori: 0, totale: 12), 25);
    });

    test('dai conteggi per voto: # meno =, su tutti i voti', () {
      final conteggi = {
        Voto.perfetto: 5,
        Voto.positivo: 2,
        Voto.mezzoPunto: 1,
        Voto.negativo: 0,
        Voto.errore: 2,
      };

      expect(totaleVoti(conteggi), 10);
      expect(efficienzaDaVoti(conteggi), 30);
    });
  });

  group('positività', () {
    test('perfette più positive, sul totale', () {
      final conteggi = {
        Voto.perfetto: 3,
        Voto.positivo: 2,
        Voto.mezzoPunto: 3,
        Voto.negativo: 1,
        Voto.errore: 1,
      };

      // (3+2)/10 = 50%: il mezzo punto NON è positivo.
      expect(positivitaDaVoti(conteggi), 50);
    });

    test('senza azioni torna null', () {
      expect(positivitaDaVoti(const {}), isNull);
      expect(positivita(positive: 0, totale: 0), isNull);
    });

    test('non è mai negativa', () {
      expect(positivita(positive: 0, totale: 8), 0);
    });
  });

  test('conteggioVoto tratta il voto assente come zero', () {
    expect(conteggioVoto(const {Voto.perfetto: 3}, Voto.errore), 0);
    expect(conteggioVoto(const {Voto.perfetto: 3}, Voto.perfetto), 3);
  });
}

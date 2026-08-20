import 'package:flutter_test/flutter_test.dart';
import 'package:volley_stats/enums.dart';
import 'package:volley_stats/heatmap.dart';
import 'package:volley_stats/tiro_scout.dart';

// Test della funzione pura puntiArrivoAvversari (Blocco 1 heatmap): filtri +
// normalizzazione dell'arrivo sul campo singolo.

TiroScout _azione({
  Squadra squadra = Squadra.avversari,
  TipoAzione tipo = TipoAzione.scout,
  Fondamentale? fondamentale = Fondamentale.battuta,
  Voto voto = Voto.positivo,
  double? x1,
  double? y1,
  double? x2,
  double? y2,
}) =>
    TiroScout(
      squadra: squadra,
      tipo: tipo,
      fondamentale: fondamentale,
      voto: voto,
      x1: x1,
      y1: y1,
      x2: x2,
      y2: y2,
    );

void main() {
  group('puntiArrivoAvversari', () {
    test('filtra: solo avversari, scout, quel fondamentale, con traiettoria',
        () {
      final azioni = [
        // OK: avversari, scout, battuta, traiettoria completa
        _azione(x1: 0.2, y1: 0.3, x2: 0.75, y2: 0.4),
        // escluso: squadra nostra
        _azione(squadra: Squadra.nostra, x1: 0.2, y1: 0.3, x2: 0.75, y2: 0.4),
        // escluso: fondamentale diverso (attacco)
        _azione(
            fondamentale: Fondamentale.attacco,
            x1: 0.2,
            y1: 0.3,
            x2: 0.75,
            y2: 0.4),
        // escluso: non scout
        _azione(tipo: TipoAzione.puntoManuale, x1: 0.2, x2: 0.75, y2: 0.4),
        // escluso: senza traiettoria d'arrivo
        _azione(x1: 0.2, y1: 0.3),
      ];
      final punti = puntiArrivoAvversari(azioni, Fondamentale.battuta);
      expect(punti.length, 1);
      expect(punti.first, const Offset(0.75, 0.4)); // arrivo nella metà destra
    });

    test('senza mirror (x1 < 0.5): arrivo (x2, y2) tale e quale', () {
      final punti = puntiArrivoAvversari(
        [_azione(x1: 0.2, y1: 0.3, x2: 0.75, y2: 0.4)],
        Fondamentale.battuta,
      );
      expect(punti, [const Offset(0.75, 0.4)]);
    });

    test('con mirror (x1 > 0.5): specchiato → stesso arrivo nella metà destra',
        () {
      // x1=0.8 → specchia: ex=1-0.25=0.75, ey=1-0.6=0.4.
      final punti = puntiArrivoAvversari(
        [_azione(x1: 0.8, y1: 0.7, x2: 0.25, y2: 0.6)],
        Fondamentale.battuta,
      );
      expect(punti, [const Offset(0.75, 0.4)]);
    });

    test('estremi: rete a x=0.5, fondo a x=1.0 (metà destra)', () {
      final punti = puntiArrivoAvversari(
        [
          _azione(x1: 0.1, y1: 0.5, x2: 0.5, y2: 0.2), // sulla rete → x=0.5
          _azione(x1: 0.1, y1: 0.5, x2: 1.0, y2: 0.9), // fondo campo → x=1.0
        ],
        Fondamentale.battuta,
      );
      expect(punti, [const Offset(0.5, 0.2), const Offset(1.0, 0.9)]);
    });

    test('filtro per attacco', () {
      final azioni = [
        _azione(fondamentale: Fondamentale.battuta, x1: 0.2, x2: 0.75, y2: 0.4),
        _azione(fondamentale: Fondamentale.attacco, x1: 0.2, x2: 0.6, y2: 0.5),
      ];
      final punti = puntiArrivoAvversari(azioni, Fondamentale.attacco);
      expect(punti, [const Offset(0.6, 0.5)]);
    });
  });

  group('puntiArrivoAvversariPerfetti (ace/kill)', () {
    test('solo le battute con voto perfetto (ace)', () {
      final azioni = [
        _azione(voto: Voto.perfetto, x1: 0.2, x2: 0.8, y2: 0.3), // ace
        _azione(voto: Voto.positivo, x1: 0.2, x2: 0.7, y2: 0.4), // in campo
        _azione(voto: Voto.errore, x1: 0.2, x2: 0.9, y2: 0.5), // errore
      ];
      final ace = puntiArrivoAvversariPerfetti(azioni, Fondamentale.battuta);
      expect(ace, [const Offset(0.8, 0.3)]);
      // Tutti gli arrivi (blob) restano 3 (ace incluso).
      expect(puntiArrivoAvversari(azioni, Fondamentale.battuta).length, 3);
    });

    test('per attacco = kill (attacco perfetto)', () {
      final azioni = [
        _azione(
            fondamentale: Fondamentale.attacco,
            voto: Voto.perfetto,
            x1: 0.2,
            x2: 0.6,
            y2: 0.5),
        _azione(
            fondamentale: Fondamentale.attacco,
            voto: Voto.negativo,
            x1: 0.2,
            x2: 0.7,
            y2: 0.5),
      ];
      final kill = puntiArrivoAvversariPerfetti(azioni, Fondamentale.attacco);
      expect(kill, [const Offset(0.6, 0.5)]);
    });
  });
}

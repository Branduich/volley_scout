import 'package:flutter_test/flutter_test.dart';
import 'package:volley_scout/logic/defense_positions.dart';

void main() {
  const rotazioni = ['P1', 'P2', 'P3', 'P4', 'P5', 'P6'];
  const ruoliCompleti = {'P', 'O', 'S1', 'S2', 'C1', 'C2'};

  group('defensePositionsComplete (senza libero)', () {
    test('ogni rotazione ha i 6 ruoli reali (nessun Libero)', () {
      for (final r in rotazioni) {
        final map = defensePositionsComplete(r);
        expect(map, isNotNull, reason: r);
        expect(map!.keys.toSet(), ruoliCompleti, reason: r);
      }
    });

    test('i ruoli condivisi tra centrali e schiacciatori coincidono', () {
      // Invariante su cui si regge la fusione: dove entrambe le tabelle hanno
      // lo stesso ruolo, la coordinata deve essere identica (altrimenti la
      // fusione sceglierebbe arbitrariamente).
      for (final r in rotazioni) {
        final c = kDefensePositionsCentrali[r]!;
        final s = kDefensePositionsSchiacciatori[r]!;
        for (final ruolo in c.keys) {
          if (ruolo == 'Libero') continue;
          if (s.containsKey(ruolo)) {
            expect(s[ruolo], c[ruolo], reason: '$r/$ruolo');
          }
        }
      }
    });
  });

  group('defenseMapFor (con libero)', () {
    test('variante centrali: 5 ruoli, un solo centrale + Libero', () {
      for (final r in rotazioni) {
        final map = defenseMapFor(
          rotazione: r,
          senzaLibero: false,
          liberoSuSchiacciatori: false,
        );
        expect(map, isNotNull, reason: r);
        expect(map!.containsKey('Libero'), isTrue, reason: r);
        // I due schiacciatori restano, dei centrali ne resta uno solo.
        expect(map.containsKey('S1') && map.containsKey('S2'), isTrue,
            reason: r);
        expect(map.containsKey('C1') != map.containsKey('C2'), isTrue,
            reason: r);
      }
    });

    test('variante schiacciatori: 5 ruoli, un solo schiacciatore + Libero', () {
      for (final r in rotazioni) {
        final map = defenseMapFor(
          rotazione: r,
          senzaLibero: false,
          liberoSuSchiacciatori: true,
        );
        expect(map, isNotNull, reason: r);
        expect(map!.containsKey('Libero'), isTrue, reason: r);
        expect(map.containsKey('C1') && map.containsKey('C2'), isTrue,
            reason: r);
        expect(map.containsKey('S1') != map.containsKey('S2'), isTrue,
            reason: r);
      }
    });

    test('rotazione inesistente → null', () {
      expect(
        defenseMapFor(
            rotazione: 'P7', senzaLibero: true, liberoSuSchiacciatori: false),
        isNull,
      );
    });
  });
}

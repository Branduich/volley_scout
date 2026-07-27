import 'package:flutter_test/flutter_test.dart';
import 'package:volley_scout/logic/attack_positions.dart';
import 'package:volley_scout/logic/defense_positions.dart';

// Controlli strutturali + spot-check sulle tabelle 6-2 trascritte dai CSV,
// per intercettare refusi nelle 144 coordinate.

const _rotazioni = ['P1', 'P2', 'P3', 'P4', 'P5', 'P6'];
const _ruoliValidi = {'P1', 'P2', 'S1', 'S2', 'C1', 'C2', 'Libero'};

void _checkTabella(String nome, Map<String, Map<String, Offset>> tabella) {
  test('$nome: 6 rotazioni, 6 ruoli, chiavi valide, P1+P2 presenti', () {
    expect(tabella.keys.toSet(), _rotazioni.toSet());
    for (final rot in _rotazioni) {
      final mappa = tabella[rot]!;
      expect(mappa.length, 6, reason: '$nome[$rot] deve avere 6 giocatori');
      expect(mappa.keys.every(_ruoliValidi.contains), isTrue,
          reason: '$nome[$rot] ha chiavi non valide: ${mappa.keys}');
      expect(mappa.containsKey('P1'), isTrue, reason: '$nome[$rot] senza P1');
      expect(mappa.containsKey('P2'), isTrue, reason: '$nome[$rot] senza P2');
      // Esattamente un centrale + Libero, OPPURE entrambi i centrali
      // (eccezione del servizio) — mai altro.
      final c1 = mappa.containsKey('C1');
      final c2 = mappa.containsKey('C2');
      final lib = mappa.containsKey('Libero');
      final ok = (c1 && c2 && !lib) || (c1 != c2 && lib);
      expect(ok, isTrue,
          reason: '$nome[$rot] combinazione centrali/libero non valida');
    }
  });
}

void main() {
  group('Tabelle 6-2 — struttura', () {
    _checkTabella('kAttackBattuta62', kAttackBattuta62);
    _checkTabella('kAttackDopoBattuta62', kAttackDopoBattuta62);
    _checkTabella('kAttackDopoRicezione62', kAttackDopoRicezione62);
    _checkTabella('kDefensePositions62', kDefensePositions62);
  });

  group('Tabelle 6-2 — spot-check coordinate (dai CSV)', () {
    test('P1 - Battuta', () {
      expect(kAttackBattuta62['P1'], {
        'P1': const Offset(-60, 470),
        'S1': const Offset(530, 470),
        'C1': const Offset(530, 300),
        'P2': const Offset(530, 130),
        'S2': const Offset(200, 130),
        'Libero': const Offset(200, 300),
      });
    });

    test('P1 - Ricezione', () {
      expect(kDefensePositions62['P1'], {
        'P1': const Offset(206, 560),
        'S1': const Offset(240, 482),
        'Libero': const Offset(166, 300),
        'S2': const Offset(240, 114),
        'C1': const Offset(540, 324),
        'P2': const Offset(444, 50),
      });
    });

    test('P1 - Dopo_Battuta (Libero e S2 diversi dal 5-1)', () {
      // Nel 6-2 Libero è in P6 (200,300) e S2 in P5 (200,130) — verifica che
      // NON siano stati copiati dal 5-1 (dove sono scambiati).
      expect(kAttackDopoBattuta62['P1']!['Libero'], const Offset(200, 300));
      expect(kAttackDopoBattuta62['P1']!['S2'], const Offset(200, 130));
    });
  });

  group('Tabelle 6-2 — resolver e caso senza libero', () {
    test('attackMapFor62 ritorna la rotazione corretta', () {
      expect(attackMapFor62(rotazione: 'P3', fase: FaseAttacco.battuta,
              senzaLibero: false),
          kAttackBattuta62['P3']);
    });

    test('senza libero: 6 ruoli reali, nessun Libero (attacco)', () {
      for (final fase in FaseAttacco.values) {
        for (final rot in _rotazioni) {
          final m = attackMapFor62(rotazione: rot, fase: fase, senzaLibero: true)!;
          expect(m.keys.toSet(), {'P1', 'P2', 'S1', 'S2', 'C1', 'C2'},
              reason: 'attacco senza libero $fase[$rot]');
        }
      }
    });

    test('senza libero: 6 ruoli reali, nessun Libero (ricezione)', () {
      for (final rot in _rotazioni) {
        final m = defenseMapFor62(rotazione: rot, senzaLibero: true)!;
        expect(m.keys.toSet(), {'P1', 'P2', 'S1', 'S2', 'C1', 'C2'},
            reason: 'ricezione senza libero [$rot]');
      }
    });
  });
}

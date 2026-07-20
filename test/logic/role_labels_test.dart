import 'package:flutter_test/flutter_test.dart';
import 'package:volley_scout/data/database.dart';
import 'package:volley_scout/logic/role_labels.dart';
import 'package:volley_scout/models/enums.dart';

Player _p(int id, Ruolo ruolo) => Player(
      id: id,
      teamId: 1,
      nome: 'Nome$id',
      cognome: 'Cognome$id',
      numero: id,
      ruolo: ruolo,
    );

void main() {
  group('roleLabelsFor — composizioni senza universali (regressione)', () {
    test('composizione classica: P, S1/S2, C1/C2, O per ruolo reale', () {
      final labels = roleLabelsFor('P1', {
        'P1': _p(1, Ruolo.palleggiatore),
        'P2': _p(2, Ruolo.schiacciatore),
        'P3': _p(3, Ruolo.centrale),
        'P4': _p(4, Ruolo.opposto),
        'P5': _p(5, Ruolo.schiacciatore),
        'P6': _p(6, Ruolo.centrale),
      });

      expect(labels, {
        'P1': 'P',
        'P2': 'S1',
        'P3': 'C1',
        'P4': 'O',
        'P5': 'S2',
        'P6': 'C2',
      });
    });

    test('doppio palleggiatore: l\'extra gioca da opposto se la O è libera',
        () {
      final labels = roleLabelsFor('P1', {
        'P1': _p(1, Ruolo.palleggiatore),
        'P2': _p(2, Ruolo.schiacciatore),
        'P3': _p(3, Ruolo.centrale),
        'P4': _p(4, Ruolo.palleggiatore),
        'P5': _p(5, Ruolo.schiacciatore),
        'P6': _p(6, Ruolo.centrale),
      });

      expect(labels['P1'], 'P');
      expect(labels['P4'], 'O');
    });
  });

  group('roleLabelsFor — universali per completamento', () {
    test('due universali con coppia centrali mancante → C1/C2', () {
      final labels = roleLabelsFor('P1', {
        'P1': _p(1, Ruolo.palleggiatore),
        'P2': _p(2, Ruolo.schiacciatore),
        'P3': _p(3, Ruolo.undefined),
        'P4': _p(4, Ruolo.opposto),
        'P5': _p(5, Ruolo.schiacciatore),
        'P6': _p(6, Ruolo.undefined),
      });

      expect(labels['P3'], 'C1');
      expect(labels['P6'], 'C2');
    });

    test('universale al posto di uno schiacciatore → S2 (opposto nel ring '
        'al compagno S1)', () {
      final labels = roleLabelsFor('P1', {
        'P1': _p(1, Ruolo.palleggiatore),
        'P2': _p(2, Ruolo.schiacciatore),
        'P3': _p(3, Ruolo.centrale),
        'P4': _p(4, Ruolo.opposto),
        'P5': _p(5, Ruolo.undefined), // ring-opposite di P2
        'P6': _p(6, Ruolo.centrale),
      });

      expect(labels['P2'], 'S1');
      expect(labels['P5'], 'S2');
      expect(labels['P3'], 'C1');
      expect(labels['P6'], 'C2');
    });

    test('universale al posto dell\'opposto → O', () {
      final labels = roleLabelsFor('P1', {
        'P1': _p(1, Ruolo.palleggiatore),
        'P2': _p(2, Ruolo.schiacciatore),
        'P3': _p(3, Ruolo.centrale),
        'P4': _p(4, Ruolo.undefined), // ring-opposite di P1
        'P5': _p(5, Ruolo.schiacciatore),
        'P6': _p(6, Ruolo.centrale),
      });

      expect(labels['P4'], 'O');
    });

    test('caso ambiguo 1S+1C+2U: ciascun universale completa la coppia del '
        'proprio opposto nel ring', () {
      final labels = roleLabelsFor('P1', {
        'P1': _p(1, Ruolo.palleggiatore),
        'P2': _p(2, Ruolo.schiacciatore),
        'P3': _p(3, Ruolo.centrale),
        'P4': _p(4, Ruolo.opposto),
        'P5': _p(5, Ruolo.undefined), // ring-opposite di P2 (S)
        'P6': _p(6, Ruolo.undefined), // ring-opposite di P3 (C)
      });

      expect(labels['P5'], 'S2');
      expect(labels['P6'], 'C2');
    });

    test('tre universali: tutti etichettati (S2 + C1/C2), nessuno perso', () {
      final labels = roleLabelsFor('P1', {
        'P1': _p(1, Ruolo.palleggiatore),
        'P2': _p(2, Ruolo.schiacciatore),
        'P3': _p(3, Ruolo.undefined),
        'P4': _p(4, Ruolo.opposto),
        'P5': _p(5, Ruolo.undefined),
        'P6': _p(6, Ruolo.undefined),
      });

      expect(labels['P5'], 'S2'); // ring-opposite di P2
      expect(labels.length, 6); // tutti e 6 gli slot hanno un'etichetta
      expect(labels.values.toSet(),
          {'P', 'O', 'S1', 'S2', 'C1', 'C2'});
    });

    test('sei ruoli tutti coperti da universali tranne il P: composizione '
        'canonica completa', () {
      final labels = roleLabelsFor('P1', {
        'P1': _p(1, Ruolo.palleggiatore),
        'P2': _p(2, Ruolo.undefined),
        'P3': _p(3, Ruolo.undefined),
        'P4': _p(4, Ruolo.undefined),
        'P5': _p(5, Ruolo.undefined),
        'P6': _p(6, Ruolo.undefined),
      });

      expect(labels['P1'], 'P');
      expect(labels['P4'], 'O'); // ring-opposite del palleggiatore
      expect(labels.length, 6);
      expect(labels.values.toSet(),
          {'P', 'O', 'S1', 'S2', 'C1', 'C2'});
    });
  });

  group('etichetteAvversarie — 5-1 canonico dallo slot del P', () {
    test('palleggiatore in zona 1: disposizione standard', () {
      expect(etichetteAvversarie(1), {
        1: 'P',
        2: 'S1',
        3: 'C1',
        4: 'O', // diagonale al palleggiatore
        5: 'S2',
        6: 'C2',
      });
    });

    test('tutte le zone hanno un\'etichetta unica, per ogni slot del P', () {
      for (var slot = 1; slot <= 6; slot++) {
        final e = etichetteAvversarie(slot);
        expect(e.length, 6);
        expect(e.values.toSet(), {'P', 'O', 'S1', 'S2', 'C1', 'C2'});
        expect(e[slot], 'P'); // il P è sempre nella zona del suo slot
      }
    });

    test('l\'opposto è sempre diagonale (3 posizioni) al palleggiatore', () {
      for (var slot = 1; slot <= 6; slot++) {
        final e = etichetteAvversarie(slot);
        final zonaP = e.entries.firstWhere((x) => x.value == 'P').key;
        final zonaO = e.entries.firstWhere((x) => x.value == 'O').key;
        // Distanza di 3 nel ring 1..6 (mod 6).
        expect((zonaO - zonaP + 6) % 6, 3);
      }
    });

    test('ruotando (P da zona 1 a zona 6) le etichette scorrono', () {
      final z1 = etichetteAvversarie(1);
      final z6 = etichetteAvversarie(6);
      // Chi era P in zona 1 ora è in zona 6.
      expect(z6[6], 'P');
      // La stessa etichetta si sposta di una zona indietro (sideout orario).
      expect(z6[1], z1[2]);
    });
  });
}

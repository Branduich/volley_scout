import 'package:flutter_test/flutter_test.dart';
import 'package:volley_scout/data/database.dart';
import 'package:volley_scout/logic/role_labels.dart';
import 'package:volley_scout/models/enums.dart';

// Test di roleLabelsFor62 (modulo 6-2, doppio palleggiatore). I due
// palleggiatori hanno identità fisse P1 (riferimento, su cui è ancorata la
// rotazione) e P2 (l'altro, diagonale). Schiacciatori → S1/S2, centrali →
// C1/C2 per distanza antioraria dallo slot di P1. Anello identico al 5-1 con
// P2 al posto dell'opposto. I casi sono verificati contro le tabelle CSV
// dell'utente (rotazioni P1 e P3, fase Battuta).

Player _p(int id, Ruolo ruolo) => Player(
      id: id,
      teamId: 1,
      nome: 'Nome$id',
      cognome: 'Cognome$id',
      numero: id,
      ruolo: ruolo,
    );

void main() {
  group('roleLabelsFor62 — 2P + 2S + 2C', () {
    test('rotazione P1 (riferimento in slot P1): anello P1,S1,C1,P2,S2,C2', () {
      // Corrisponde a "P1 - Battuta": slot1=P1, 2=S1, 3=C1, 4=P2, 5=S2, 6=C2.
      final labels = roleLabelsFor62('P1', {
        'P1': _p(1, Ruolo.palleggiatore),
        'P2': _p(2, Ruolo.schiacciatore),
        'P3': _p(3, Ruolo.centrale),
        'P4': _p(4, Ruolo.palleggiatore),
        'P5': _p(5, Ruolo.schiacciatore),
        'P6': _p(6, Ruolo.centrale),
      });

      expect(labels, {
        'P1': 'P1',
        'P2': 'S1',
        'P3': 'C1',
        'P4': 'P2',
        'P5': 'S2',
        'P6': 'C2',
      });
    });

    test('rotazione P3 (riferimento in slot P3) — dai dati CSV utente', () {
      // "P3 - Battuta": slot1=S2, 2=C2, 3=P1, 4=S1, 5=C1(libero), 6=P2.
      final labels = roleLabelsFor62('P3', {
        'P3': _p(1, Ruolo.palleggiatore), // P1 (riferimento)
        'P6': _p(4, Ruolo.palleggiatore), // P2 (diagonale)
        'P4': _p(2, Ruolo.schiacciatore), // S1 (dist 1 da P3)
        'P1': _p(5, Ruolo.schiacciatore), // S2 (dist 4)
        'P5': _p(3, Ruolo.centrale), // C1 (dist 2)
        'P2': _p(6, Ruolo.centrale), // C2 (dist 5)
      });

      expect(labels, {
        'P3': 'P1',
        'P6': 'P2',
        'P4': 'S1',
        'P1': 'S2',
        'P5': 'C1',
        'P2': 'C2',
      });
    });

    test('P1 è sempre lo slot di riferimento; l\'altro palleggiatore è P2', () {
      final labels = roleLabelsFor62('P5', {
        'P5': _p(1, Ruolo.palleggiatore),
        'P2': _p(4, Ruolo.palleggiatore),
        'P6': _p(2, Ruolo.schiacciatore),
        'P3': _p(5, Ruolo.schiacciatore),
        'P1': _p(3, Ruolo.centrale),
        'P4': _p(6, Ruolo.centrale),
      });
      expect(labels['P5'], 'P1');
      expect(labels['P2'], 'P2');
      expect(labels.values.where((v) => v == 'P1').length, 1);
      expect(labels.values.where((v) => v == 'P2').length, 1);
    });

    test('tutti e 6 gli slot etichettati, etichette uniche', () {
      final labels = roleLabelsFor62('P1', {
        'P1': _p(1, Ruolo.palleggiatore),
        'P4': _p(4, Ruolo.palleggiatore),
        'P2': _p(2, Ruolo.schiacciatore),
        'P5': _p(5, Ruolo.schiacciatore),
        'P3': _p(3, Ruolo.centrale),
        'P6': _p(6, Ruolo.centrale),
      });
      expect(labels.length, 6);
      expect(labels.values.toSet(), {'P1', 'P2', 'S1', 'S2', 'C1', 'C2'});
    });
  });
}

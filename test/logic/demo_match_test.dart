import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:volley_scout/logic/ricalcola_stato.dart';
import 'package:volley_scout/models/enums.dart';

/// Valida la partita demo (assets/demo/demo_match.json, convertita
/// dall'export xlsx di "Volleyball Scout" — Clai Imola vs Nettunia
/// 30/04/2026): rigiocando gli esiti con ricalcolaStato() i punteggi
/// finali di ogni set devono coincidere con quelli reali del referto.
/// Punteggi (locali-ospiti, noi = Nettunia ospiti): 25-16, 15-25, 21-25,
/// 25-16, 25-23 — persa 2-3.
void main() {
  // (avversario, nostro) per set.
  const attesi = [(25, 16), (15, 25), (21, 25), (25, 16), (25, 23)];

  late Map<String, dynamic> demo;

  setUpAll(() {
    // Lettura diretta da file (cwd dei test = root del progetto): niente
    // rootBundle, il test resta puro e veloce.
    demo = jsonDecode(
            File('assets/demo/demo_match.json').readAsStringSync())
        as Map<String, dynamic>;
  });

  test('la demo ha 5 set e un roster completo', () {
    expect((demo['sets'] as List).length, 5);
    expect((demo['players'] as List).length, greaterThanOrEqualTo(12));
  });

  test('ogni set ha una rotazione iniziale completa (6 posizioni, '
      'giocatori distinti)', () {
    for (final set in demo['sets'] as List) {
      final rotazione = set['rotazione'] as Map<String, dynamic>;
      expect(rotazione.length, 6,
          reason: 'set ${set['numero']}: rotazione incompleta');
      expect(rotazione.values.toSet().length, 6,
          reason: 'set ${set['numero']}: giocatore duplicato in rotazione');
    }
  });

  test('replay con ricalcolaStato(): punteggi finali reali per tutti i set',
      () {
    for (final set in demo['sets'] as List) {
      final numero = set['numero'] as int;
      final rotazione = {
        for (final e in (set['rotazione'] as Map<String, dynamic>).entries)
          int.parse(e.key): e.value as int, // numero maglia come "id"
      };
      var ordine = 0;
      final azioni = [
        for (final a in set['azioni'] as List)
          AzioneScout(
            ordine: ++ordine,
            esitoPunto: EsitoPunto.values.byName(a['esito'] as String),
          ),
      ];
      final stato = ricalcolaStato(
        azioni: azioni,
        servizioIniziale:
            Squadra.values.byName(set['servizioIniziale'] as String),
        rotazioneIniziale: rotazione,
      );
      final (avversario, nostro) = attesi[numero - 1];
      expect((stato.punteggioAvversario, stato.punteggioNostro),
          (avversario, nostro),
          reason: 'set $numero: punteggio replay diverso dal referto');
    }
  });

  test('battute e attacchi hanno la traiettoria sintetica', () {
    for (final set in demo['sets'] as List) {
      for (final a in set['azioni'] as List) {
        if (a['tipo'] != 'scout') continue;
        final f = a['fondamentale'] as String;
        if (f == 'battuta' || f == 'attacco') {
          expect(a['tx1'], isNotNull,
              reason: 'set ${set['numero']}: $f senza traiettoria');
          expect(a['tx2'], isNotNull);
        }
      }
    }
  });
}

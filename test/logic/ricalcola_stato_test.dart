import 'package:flutter_test/flutter_test.dart';
import 'package:volley_scout/logic/ricalcola_stato.dart';
import 'package:volley_scout/models/enums.dart';

void main() {
  const rotazioneIniziale = {1: 10, 2: 20, 3: 30, 4: 40, 5: 50, 6: 60};

  group('_ruotata (tramite ricalcolaStato)', () {
    test('un sideout ruota la formazione in senso orario', () {
      final stato = ricalcolaStato(
        azioni: const [(ordine: 1, esitoPunto: EsitoPunto.puntoNostro)],
        servizioIniziale: Squadra.avversari,
        rotazioneIniziale: rotazioneIniziale,
      );

      expect(stato.rotazione, {1: 20, 2: 30, 3: 40, 4: 50, 5: 60, 6: 10});
    });
  });

  group('ricalcolaStato — casi base', () {
    test('nessuna azione: stato invariato rispetto agli iniziali', () {
      final stato = ricalcolaStato(
        azioni: const [],
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
      );

      expect(stato.punteggioNostro, 0);
      expect(stato.punteggioAvversario, 0);
      expect(stato.squadraAlServizio, Squadra.nostra);
      expect(stato.rotazione, rotazioneIniziale);
    });

    test('azioni con esito "nessuno" non toccano punteggio o rotazione', () {
      final stato = ricalcolaStato(
        azioni: const [
          (ordine: 1, esitoPunto: EsitoPunto.nessuno),
          (ordine: 2, esitoPunto: EsitoPunto.nessuno),
        ],
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
      );

      expect(stato.punteggioNostro, 0);
      expect(stato.punteggioAvversario, 0);
      expect(stato.squadraAlServizio, Squadra.nostra);
      expect(stato.rotazione, rotazioneIniziale);
    });

    test('punto nostro mentre eravamo già al servizio: niente rotazione', () {
      final stato = ricalcolaStato(
        azioni: const [(ordine: 1, esitoPunto: EsitoPunto.puntoNostro)],
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
      );

      expect(stato.punteggioNostro, 1);
      expect(stato.punteggioAvversario, 0);
      expect(stato.squadraAlServizio, Squadra.nostra);
      expect(stato.rotazione, rotazioneIniziale);
    });

    test('punto nostro in ricezione (sideout): ruota e prendiamo il servizio',
        () {
      final stato = ricalcolaStato(
        azioni: const [(ordine: 1, esitoPunto: EsitoPunto.puntoNostro)],
        servizioIniziale: Squadra.avversari,
        rotazioneIniziale: rotazioneIniziale,
      );

      expect(stato.punteggioNostro, 1);
      expect(stato.squadraAlServizio, Squadra.nostra);
      expect(stato.rotazione, isNot(rotazioneIniziale));
    });

    test('punto avversario mentre servivamo noi: sideout per loro, '
        'nessuna rotazione nostra', () {
      final stato = ricalcolaStato(
        azioni: const [(ordine: 1, esitoPunto: EsitoPunto.puntoAvversario)],
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
      );

      expect(stato.punteggioNostro, 0);
      expect(stato.punteggioAvversario, 1);
      expect(stato.squadraAlServizio, Squadra.avversari);
      // Non tracciamo la rotazione avversaria: la nostra resta inalterata.
      expect(stato.rotazione, rotazioneIniziale);
    });

    test('punto avversario mentre servivano già loro: nessun cambiamento '
        'di servizio o rotazione', () {
      final stato = ricalcolaStato(
        azioni: const [(ordine: 1, esitoPunto: EsitoPunto.puntoAvversario)],
        servizioIniziale: Squadra.avversari,
        rotazioneIniziale: rotazioneIniziale,
      );

      expect(stato.punteggioAvversario, 1);
      expect(stato.squadraAlServizio, Squadra.avversari);
      expect(stato.rotazione, rotazioneIniziale);
    });
  });

  group('ricalcolaStato — sequenze realistiche', () {
    test('più sideout consecutivi ruotano la formazione ad ogni cambio', () {
      // Serviamo noi, perdiamo il punto (sideout loro), poi lo riprendiamo
      // (sideout nostro): ci aspettiamo esattamente una rotazione nostra.
      final stato = ricalcolaStato(
        azioni: const [
          (ordine: 1, esitoPunto: EsitoPunto.puntoAvversario), // sideout loro
          (ordine: 2, esitoPunto: EsitoPunto.puntoNostro), // sideout nostro
        ],
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
      );

      expect(stato.punteggioNostro, 1);
      expect(stato.punteggioAvversario, 1);
      expect(stato.squadraAlServizio, Squadra.nostra);
      expect(stato.rotazione, {1: 20, 2: 30, 3: 40, 4: 50, 5: 60, 6: 10});
    });

    test('punti consecutivi della squadra al servizio non ruotano mai', () {
      final stato = ricalcolaStato(
        azioni: const [
          (ordine: 1, esitoPunto: EsitoPunto.puntoNostro),
          (ordine: 2, esitoPunto: EsitoPunto.puntoNostro),
          (ordine: 3, esitoPunto: EsitoPunto.puntoNostro),
        ],
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
      );

      expect(stato.punteggioNostro, 3);
      expect(stato.squadraAlServizio, Squadra.nostra);
      expect(stato.rotazione, rotazioneIniziale);
    });

    test('è indifferente all\'ordine di inserimento, conta "ordine"', () {
      const azioni = [
        (ordine: 3, esitoPunto: EsitoPunto.puntoNostro),
        (ordine: 1, esitoPunto: EsitoPunto.puntoAvversario),
        (ordine: 2, esitoPunto: EsitoPunto.puntoAvversario),
      ];

      final statoInOrdine = ricalcolaStato(
        azioni: azioni,
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
      );
      final statoMescolato = ricalcolaStato(
        azioni: azioni.reversed.toList(),
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
      );

      expect(statoMescolato, statoInOrdine);
      expect(statoInOrdine.punteggioNostro, 1);
      expect(statoInOrdine.punteggioAvversario, 2);
      expect(statoInOrdine.squadraAlServizio, Squadra.nostra);
    });

    test('undo = ricalcolare senza l\'ultima azione (per ordine)', () {
      const tutte = [
        (ordine: 1, esitoPunto: EsitoPunto.puntoAvversario),
        (ordine: 2, esitoPunto: EsitoPunto.puntoNostro),
        (ordine: 3, esitoPunto: EsitoPunto.puntoNostro),
      ];

      final statoCompleto = ricalcolaStato(
        azioni: tutte,
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
      );
      expect(statoCompleto.punteggioNostro, 2);

      final senzaUltima = tutte.where((a) => a.ordine != 3).toList();
      final statoDopoUndo = ricalcolaStato(
        azioni: senzaUltima,
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
      );

      expect(statoDopoUndo.punteggioNostro, 1);
      expect(statoDopoUndo.punteggioAvversario, 1);
      expect(statoDopoUndo.squadraAlServizio, Squadra.nostra);
    });
  });

  group('StatoSet equality', () {
    test('due StatoSet con stessi valori sono uguali', () {
      const a = StatoSet(
        punteggioNostro: 5,
        punteggioAvversario: 3,
        squadraAlServizio: Squadra.nostra,
        rotazione: {1: 10, 2: 20, 3: 30, 4: 40, 5: 50, 6: 60},
      );
      const b = StatoSet(
        punteggioNostro: 5,
        punteggioAvversario: 3,
        squadraAlServizio: Squadra.nostra,
        rotazione: {1: 10, 2: 20, 3: 30, 4: 40, 5: 50, 6: 60},
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('rotazioni diverse rendono gli StatoSet diversi', () {
      const a = StatoSet(
        punteggioNostro: 0,
        punteggioAvversario: 0,
        squadraAlServizio: Squadra.nostra,
        rotazione: {1: 10, 2: 20, 3: 30, 4: 40, 5: 50, 6: 60},
      );
      const b = StatoSet(
        punteggioNostro: 0,
        punteggioAvversario: 0,
        squadraAlServizio: Squadra.nostra,
        rotazione: {1: 20, 2: 30, 3: 40, 4: 50, 5: 60, 6: 10},
      );

      expect(a, isNot(b));
    });
  });
}

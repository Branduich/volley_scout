import 'package:flutter_test/flutter_test.dart';
import 'package:volley_scout/logic/ricalcola_stato.dart';
import 'package:volley_scout/models/enums.dart';

void main() {
  const rotazioneIniziale = {1: 10, 2: 20, 3: 30, 4: 40, 5: 50, 6: 60};

  group('_ruotata (tramite ricalcolaStato)', () {
    test('un sideout ruota la formazione in senso orario', () {
      final stato = ricalcolaStato(
        azioni: const [
          AzioneScout(ordine: 1, esitoPunto: EsitoPunto.puntoNostro),
        ],
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
          AzioneScout(ordine: 1, esitoPunto: EsitoPunto.nessuno),
          AzioneScout(ordine: 2, esitoPunto: EsitoPunto.nessuno),
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
        azioni: const [
          AzioneScout(ordine: 1, esitoPunto: EsitoPunto.puntoNostro),
        ],
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
        azioni: const [
          AzioneScout(ordine: 1, esitoPunto: EsitoPunto.puntoNostro),
        ],
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
        azioni: const [
          AzioneScout(ordine: 1, esitoPunto: EsitoPunto.puntoAvversario),
        ],
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
        azioni: const [
          AzioneScout(ordine: 1, esitoPunto: EsitoPunto.puntoAvversario),
        ],
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
          AzioneScout(
              ordine: 1, esitoPunto: EsitoPunto.puntoAvversario), // sideout loro
          AzioneScout(
              ordine: 2, esitoPunto: EsitoPunto.puntoNostro), // sideout nostro
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
          AzioneScout(ordine: 1, esitoPunto: EsitoPunto.puntoNostro),
          AzioneScout(ordine: 2, esitoPunto: EsitoPunto.puntoNostro),
          AzioneScout(ordine: 3, esitoPunto: EsitoPunto.puntoNostro),
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
        AzioneScout(ordine: 3, esitoPunto: EsitoPunto.puntoNostro),
        AzioneScout(ordine: 1, esitoPunto: EsitoPunto.puntoAvversario),
        AzioneScout(ordine: 2, esitoPunto: EsitoPunto.puntoAvversario),
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
        AzioneScout(ordine: 1, esitoPunto: EsitoPunto.puntoAvversario),
        AzioneScout(ordine: 2, esitoPunto: EsitoPunto.puntoNostro),
        AzioneScout(ordine: 3, esitoPunto: EsitoPunto.puntoNostro),
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

  group('ricalcolaStato — cambio giocatore', () {
    test('il cambio sostituisce il giocatore alla sua posizione, '
        'rotazione altrimenti intatta', () {
      final stato = ricalcolaStato(
        azioni: const [
          AzioneScout(
            ordine: 1,
            esitoPunto: EsitoPunto.nessuno,
            sostituzione: SostituzioneGiocatore(esceId: 30, entraId: 99),
          ),
        ],
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
      );

      expect(stato.rotazione, {1: 10, 2: 20, 3: 99, 4: 40, 5: 50, 6: 60});
      expect(stato.punteggioNostro, 0);
      expect(stato.punteggioAvversario, 0);
      expect(stato.squadraAlServizio, Squadra.nostra);
    });

    test('un sideout DOPO il cambio ruota il subentrante insieme agli altri',
        () {
      final stato = ricalcolaStato(
        azioni: const [
          AzioneScout(
            ordine: 1,
            esitoPunto: EsitoPunto.nessuno,
            sostituzione: SostituzioneGiocatore(esceId: 20, entraId: 99),
          ),
          // Serviamo in ricezione: punto nostro = sideout, ruotiamo.
          AzioneScout(ordine: 2, esitoPunto: EsitoPunto.puntoNostro),
        ],
        servizioIniziale: Squadra.avversari,
        rotazioneIniziale: rotazioneIniziale,
      );

      // Dopo il cambio: {1:10, 2:99, 3:30, ...}. Dopo la rotazione il
      // subentrante (in 2) passa in 1.
      expect(stato.rotazione, {1: 99, 2: 30, 3: 40, 4: 50, 5: 60, 6: 10});
    });

    test('l\'ordine cambia il risultato: sideout PRIMA del cambio', () {
      final stato = ricalcolaStato(
        azioni: const [
          AzioneScout(ordine: 1, esitoPunto: EsitoPunto.puntoNostro),
          AzioneScout(
            ordine: 2,
            esitoPunto: EsitoPunto.nessuno,
            sostituzione: SostituzioneGiocatore(esceId: 20, entraId: 99),
          ),
        ],
        servizioIniziale: Squadra.avversari,
        rotazioneIniziale: rotazioneIniziale,
      );

      // Prima ruota ({1:20, 2:30, ...}), poi il 20 (ora in posizione 1)
      // viene sostituito dal 99.
      expect(stato.rotazione, {1: 99, 2: 30, 3: 40, 4: 50, 5: 60, 6: 10});
    });

    test('uscente non in campo: no-op, nessuna eccezione', () {
      final stato = ricalcolaStato(
        azioni: const [
          AzioneScout(
            ordine: 1,
            esitoPunto: EsitoPunto.nessuno,
            sostituzione: SostituzioneGiocatore(esceId: 999, entraId: 99),
          ),
        ],
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
      );

      expect(stato.rotazione, rotazioneIniziale);
    });

    test('subentrante già in campo: riga incoerente, no-op completo '
        '(nessuna posizione duplicata)', () {
      final stato = ricalcolaStato(
        azioni: const [
          AzioneScout(
            ordine: 1,
            esitoPunto: EsitoPunto.nessuno,
            // 20 è già in posizione 2: applicare il cambio lo
            // duplicherebbe in campo.
            sostituzione: SostituzioneGiocatore(
              esceId: 30,
              entraId: 20,
              nuovoPalleggiatoreId: 20,
            ),
          ),
        ],
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
        palleggiatoreInizialeId: 10,
      );

      expect(stato.rotazione, rotazioneIniziale);
      // Anche gli override della riga incoerente vengono ignorati.
      expect(stato.palleggiatoreId, 10);
    });

    test('riga no-op legittima (esceId == entraId): porta solo gli override',
        () {
      final stato = ricalcolaStato(
        azioni: const [
          AzioneScout(
            ordine: 1,
            esitoPunto: EsitoPunto.nessuno,
            sostituzione: SostituzioneGiocatore(
              esceId: 20,
              entraId: 20,
              nuovoPalleggiatoreId: 20,
            ),
          ),
        ],
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
        palleggiatoreInizialeId: 10,
      );

      expect(stato.rotazione, rotazioneIniziale);
      expect(stato.palleggiatoreId, 20);
    });

    test('palleggiatoreId e ruoloCambiLibero seguono gli override del cambio',
        () {
      final stato = ricalcolaStato(
        azioni: const [
          AzioneScout(
            ordine: 1,
            esitoPunto: EsitoPunto.nessuno,
            sostituzione: SostituzioneGiocatore(
              esceId: 10,
              entraId: 99,
              nuovoPalleggiatoreId: 99,
              nuovoRuoloCambiLibero: Ruolo.schiacciatore,
            ),
          ),
        ],
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
        palleggiatoreInizialeId: 10,
        ruoloCambiLiberoIniziale: Ruolo.centrale,
      );

      expect(stato.palleggiatoreId, 99);
      expect(stato.ruoloCambiLibero, Ruolo.schiacciatore);
      expect(stato.rotazione, {1: 99, 2: 20, 3: 30, 4: 40, 5: 50, 6: 60});
    });

    test('override null: configurazione invariata dopo un cambio semplice',
        () {
      final stato = ricalcolaStato(
        azioni: const [
          AzioneScout(
            ordine: 1,
            esitoPunto: EsitoPunto.nessuno,
            sostituzione: SostituzioneGiocatore(esceId: 20, entraId: 99),
          ),
        ],
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
        palleggiatoreInizialeId: 10,
        ruoloCambiLiberoIniziale: Ruolo.centrale,
      );

      expect(stato.palleggiatoreId, 10);
      expect(stato.ruoloCambiLibero, Ruolo.centrale);
    });

    test('undo del cambio (drop ultima azione) riporta allo stato precedente',
        () {
      const tutte = [
        AzioneScout(ordine: 1, esitoPunto: EsitoPunto.puntoNostro),
        AzioneScout(
          ordine: 2,
          esitoPunto: EsitoPunto.nessuno,
          sostituzione: SostituzioneGiocatore(
            esceId: 20,
            entraId: 99,
            nuovoPalleggiatoreId: 99,
          ),
        ),
      ];

      final statoConCambio = ricalcolaStato(
        azioni: tutte,
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
        palleggiatoreInizialeId: 10,
      );
      expect(statoConCambio.palleggiatoreId, 99);
      expect(statoConCambio.rotazione[2], 99);

      final statoDopoUndo = ricalcolaStato(
        azioni: tutte.where((a) => a.ordine != 2).toList(),
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
        palleggiatoreInizialeId: 10,
      );

      expect(statoDopoUndo.palleggiatoreId, 10);
      expect(statoDopoUndo.rotazione, rotazioneIniziale);
    });
  });

  group('ricalcolaStato — cambio libero (solo libero-per-libero)', () {
    test('esce il libero L1: si aggiorna liberoId, rotazione intatta', () {
      final stato = ricalcolaStato(
        azioni: const [
          AzioneScout(
            ordine: 1,
            esitoPunto: EsitoPunto.nessuno,
            sostituzione: SostituzioneGiocatore(esceId: 70, entraId: 71),
          ),
        ],
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
        liberoInizialeId: 70,
        libero2InizialeId: 80,
      );

      expect(stato.liberoId, 71);
      expect(stato.libero2Id, 80);
      expect(stato.rotazione, rotazioneIniziale);
    });

    test('esce il libero L2: si aggiorna libero2Id', () {
      final stato = ricalcolaStato(
        azioni: const [
          AzioneScout(
            ordine: 1,
            esitoPunto: EsitoPunto.nessuno,
            sostituzione: SostituzioneGiocatore(esceId: 80, entraId: 81),
          ),
        ],
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
        liberoInizialeId: 70,
        libero2InizialeId: 80,
      );

      expect(stato.liberoId, 70);
      expect(stato.libero2Id, 81);
      expect(stato.rotazione, rotazioneIniziale);
    });

    test('subentrante già libero in campo: riga incoerente, no-op', () {
      final stato = ricalcolaStato(
        azioni: const [
          AzioneScout(
            ordine: 1,
            esitoPunto: EsitoPunto.nessuno,
            // 70 è già il libero L1: metterlo anche in rotazione al posto
            // del 30 lo duplicherebbe.
            sostituzione: SostituzioneGiocatore(esceId: 30, entraId: 70),
          ),
        ],
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
        liberoInizialeId: 70,
      );

      expect(stato.rotazione, rotazioneIniziale);
      expect(stato.liberoId, 70);
    });

    test('cambio normale con liberi presenti: i liberi restano invariati',
        () {
      final stato = ricalcolaStato(
        azioni: const [
          AzioneScout(
            ordine: 1,
            esitoPunto: EsitoPunto.nessuno,
            sostituzione: SostituzioneGiocatore(esceId: 30, entraId: 99),
          ),
        ],
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
        liberoInizialeId: 70,
        libero2InizialeId: 80,
      );

      expect(stato.rotazione, {1: 10, 2: 20, 3: 99, 4: 40, 5: 50, 6: 60});
      expect(stato.liberoId, 70);
      expect(stato.libero2Id, 80);
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

    test('palleggiatoreId diverso rende gli StatoSet diversi', () {
      const a = StatoSet(
        punteggioNostro: 0,
        punteggioAvversario: 0,
        squadraAlServizio: Squadra.nostra,
        rotazione: {1: 10, 2: 20, 3: 30, 4: 40, 5: 50, 6: 60},
        palleggiatoreId: 10,
      );
      const b = StatoSet(
        punteggioNostro: 0,
        punteggioAvversario: 0,
        squadraAlServizio: Squadra.nostra,
        rotazione: {1: 10, 2: 20, 3: 30, 4: 40, 5: 50, 6: 60},
        palleggiatoreId: 99,
      );

      expect(a, isNot(b));
    });
  });

  group('ricalcolaStato — correzione manuale rotazione', () {
    test('avanti ruota come un sideout, senza toccare punteggio/servizio', () {
      final stato = ricalcolaStato(
        azioni: const [
          AzioneScout(
            ordine: 1,
            esitoPunto: EsitoPunto.nessuno,
            correzioneRotazione: DirezioneRotazione.avanti,
          ),
        ],
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
      );

      expect(stato.rotazione, {1: 20, 2: 30, 3: 40, 4: 50, 5: 60, 6: 10});
      expect(stato.punteggioNostro, 0);
      expect(stato.punteggioAvversario, 0);
      expect(stato.squadraAlServizio, Squadra.nostra);
    });

    test('indietro ruota nel verso inverso', () {
      final stato = ricalcolaStato(
        azioni: const [
          AzioneScout(
            ordine: 1,
            esitoPunto: EsitoPunto.nessuno,
            correzioneRotazione: DirezioneRotazione.indietro,
          ),
        ],
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
      );

      expect(stato.rotazione, {1: 60, 2: 10, 3: 20, 4: 30, 5: 40, 6: 50});
    });

    test('avanti poi indietro = rotazione identica', () {
      final stato = ricalcolaStato(
        azioni: const [
          AzioneScout(
            ordine: 1,
            esitoPunto: EsitoPunto.nessuno,
            correzioneRotazione: DirezioneRotazione.avanti,
          ),
          AzioneScout(
            ordine: 2,
            esitoPunto: EsitoPunto.nessuno,
            correzioneRotazione: DirezioneRotazione.indietro,
          ),
        ],
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
      );

      expect(stato.rotazione, rotazioneIniziale);
    });

    test('la correzione non cambia chi è al servizio', () {
      final stato = ricalcolaStato(
        azioni: const [
          AzioneScout(
            ordine: 1,
            esitoPunto: EsitoPunto.nessuno,
            correzioneRotazione: DirezioneRotazione.avanti,
          ),
        ],
        servizioIniziale: Squadra.avversari,
        rotazioneIniziale: rotazioneIniziale,
      );

      expect(stato.squadraAlServizio, Squadra.avversari);
      expect(stato.rotazione, {1: 20, 2: 30, 3: 40, 4: 50, 5: 60, 6: 10});
    });

    test('un sideout (avanti) annullato da una correzione indietro', () {
      final stato = ricalcolaStato(
        azioni: const [
          // Sideout: ruota avanti e prendiamo il servizio.
          AzioneScout(ordine: 1, esitoPunto: EsitoPunto.puntoNostro),
          // Correzione manuale nel verso opposto: riporta la rotazione
          // iniziale, ma NON tocca punteggio/servizio del sideout.
          AzioneScout(
            ordine: 2,
            esitoPunto: EsitoPunto.nessuno,
            correzioneRotazione: DirezioneRotazione.indietro,
          ),
        ],
        servizioIniziale: Squadra.avversari,
        rotazioneIniziale: rotazioneIniziale,
      );

      expect(stato.rotazione, rotazioneIniziale);
      expect(stato.punteggioNostro, 1);
      expect(stato.squadraAlServizio, Squadra.nostra);
    });
  });
}

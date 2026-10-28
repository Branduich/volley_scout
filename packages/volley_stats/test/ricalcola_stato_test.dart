import 'package:flutter_test/flutter_test.dart';
import 'package:volley_stats/ricalcola_stato.dart';
import 'package:volley_stats/enums.dart';

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

  // Caso reale (feedback dal campo, 2026-10): centrale infortunato, entra una
  // schiacciatrice che in campo fa il centrale. Il ruolo in campo è un dato
  // della partita e segue la persona.
  group('ricalcolaStato — ruolo in campo', () {
    AzioneScout cambio(int ordine, int esce, int entra, [Ruolo? ruolo]) =>
        AzioneScout(
          ordine: ordine,
          esitoPunto: EsitoPunto.nessuno,
          sostituzione: SostituzioneGiocatore(
              esceId: esce, entraId: entra, ruoloInCampo: ruolo),
        );

    test('chi entra porta il ruolo indicato nel cambio', () {
      final stato = ricalcolaStato(
        azioni: [cambio(1, 30, 99, Ruolo.centrale)],
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
      );

      expect(stato.ruoliInCampo, {99: Ruolo.centrale});
      expect(stato.rotazione[3], 99);
    });

    test('senza ruolo nel cambio la mappa resta vuota (gioca col suo)', () {
      final stato = ricalcolaStato(
        azioni: [cambio(1, 30, 99)],
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
      );

      expect(stato.ruoliInCampo, isEmpty);
    });

    test('chi esce lo perde, anche se era un ruolo di inizio set', () {
      final stato = ricalcolaStato(
        azioni: [cambio(1, 30, 99)],
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
        ruoliInCampoIniziali: {30: Ruolo.centrale, 40: Ruolo.opposto},
      );

      expect(stato.ruoliInCampo, {40: Ruolo.opposto});
    });

    test('segue la persona attraverso la rotazione e i cambi a catena', () {
      final stato = ricalcolaStato(
        azioni: [
          cambio(1, 30, 99, Ruolo.centrale),
          // Sideout: 99 passa dalla posizione 3 alla 2, il ruolo resta suo.
          const AzioneScout(ordine: 2, esitoPunto: EsitoPunto.puntoNostro),
          // Poi esce anche lei: entra 98, di nuovo da centrale.
          cambio(3, 99, 98, Ruolo.centrale),
        ],
        servizioIniziale: Squadra.avversari,
        rotazioneIniziale: rotazioneIniziale,
      );

      expect(stato.rotazione[2], 98);
      expect(stato.ruoliInCampo, {98: Ruolo.centrale});
    });

    test('il cambio libero-per-libero non tocca i ruoli in campo', () {
      final stato = ricalcolaStato(
        azioni: [cambio(1, 70, 71, Ruolo.centrale)],
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
        liberoInizialeId: 70,
        ruoliInCampoIniziali: {30: Ruolo.centrale},
      );

      expect(stato.liberoId, 71);
      expect(stato.ruoliInCampo, {30: Ruolo.centrale});
    });

    test('la riconfigurazione senza cambi non toglie il ruolo all\'àncora', () {
      // Riga no-op (esce == entra): la scrive ScoutScreen quando si cambia
      // solo palleggiatore designato o coppia del libero, appoggiandola a
      // una giocatrice in campo — che deve tenersi il suo ruolo in campo.
      final stato = ricalcolaStato(
        azioni: [cambio(1, 30, 30)],
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
        ruoliInCampoIniziali: {30: Ruolo.centrale},
      );

      expect(stato.ruoliInCampo, {30: Ruolo.centrale});
    });

    test('una riga incoerente (subentrante già in campo) non lo applica', () {
      final stato = ricalcolaStato(
        azioni: [cambio(1, 30, 20, Ruolo.centrale)],
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
      );

      expect(stato.ruoliInCampo, isEmpty);
    });

    test('undo = togliere la riga: si torna allo stato di prima', () {
      final prima = ricalcolaStato(
        azioni: const [],
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
        ruoliInCampoIniziali: {30: Ruolo.centrale},
      );
      final dopo = ricalcolaStato(
        azioni: [cambio(1, 30, 99, Ruolo.centrale)],
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
        ruoliInCampoIniziali: {30: Ruolo.centrale},
      );

      expect(dopo, isNot(prima)); // == confronta anche i ruoli in campo
      expect(prima.ruoliInCampo, {30: Ruolo.centrale});
    });
  });

  // Il set parte senza libero (o con uno solo) e il libero entra dopo: il
  // regolamento lo ammette. La riga è un cambio con esce == entra == il
  // libero, che non è in campo — a differenza della no-op di
  // riconfigurazione, la cui àncora è sempre in rotazione.
  group('ricalcolaStato — ingresso del libero a set in corso', () {
    AzioneScout ingresso(int ordine, int libero, {Ruolo? coppia}) =>
        AzioneScout(
          ordine: ordine,
          esitoPunto: EsitoPunto.nessuno,
          sostituzione: SostituzioneGiocatore(
            esceId: libero,
            entraId: libero,
            nuovoRuoloCambiLibero: coppia,
          ),
        );

    test('set partito senza libero: entra e diventa L1, con la sua coppia',
        () {
      final stato = ricalcolaStato(
        azioni: [ingresso(1, 70, coppia: Ruolo.centrale)],
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
      );

      expect(stato.liberoId, 70);
      expect(stato.libero2Id, isNull);
      expect(stato.ruoloCambiLibero, Ruolo.centrale);
      expect(stato.rotazione, rotazioneIniziale);
    });

    test('con un libero già in campo, il secondo diventa L2', () {
      final stato = ricalcolaStato(
        azioni: [ingresso(1, 80)],
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
        liberoInizialeId: 70,
        ruoloCambiLiberoIniziale: Ruolo.centrale,
      );

      expect(stato.liberoId, 70);
      expect(stato.libero2Id, 80);
    });

    test('entrambi in un colpo solo: L1 poi L2, nell\'ordine delle righe', () {
      final stato = ricalcolaStato(
        azioni: [ingresso(1, 70, coppia: Ruolo.centrale), ingresso(2, 80)],
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
      );

      expect(stato.liberoId, 70);
      expect(stato.libero2Id, 80);
    });

    test('con due liberi già presenti un terzo non entra', () {
      final stato = ricalcolaStato(
        azioni: [ingresso(1, 90)],
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
        liberoInizialeId: 70,
        libero2InizialeId: 80,
      );

      expect(stato.liberoId, 70);
      expect(stato.libero2Id, 80);
    });

    test('dopo l\'ingresso il cambio libero-per-libero funziona', () {
      final stato = ricalcolaStato(
        azioni: [
          ingresso(1, 70, coppia: Ruolo.centrale),
          const AzioneScout(
            ordine: 2,
            esitoPunto: EsitoPunto.nessuno,
            sostituzione: SostituzioneGiocatore(esceId: 70, entraId: 71),
          ),
        ],
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
      );

      expect(stato.liberoId, 71);
    });

    test('la no-op di riconfigurazione (àncora in campo) non crea un libero',
        () {
      final stato = ricalcolaStato(
        azioni: [ingresso(1, 10)], // 10 è in posizione 1
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
      );

      expect(stato.liberoId, isNull);
      expect(stato.rotazione, rotazioneIniziale);
    });

    // Uscita senza sostituto: stessa forma della riga d'ingresso, ma su un
    // libero che è già in campo.
    test('esce l\'unico libero: si gioca senza, e la coppia si azzera', () {
      final stato = ricalcolaStato(
        azioni: [ingresso(1, 70)],
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
        liberoInizialeId: 70,
        ruoloCambiLiberoIniziale: Ruolo.centrale,
      );

      expect(stato.liberoId, isNull);
      expect(stato.libero2Id, isNull);
      expect(stato.ruoloCambiLibero, isNull);
      expect(stato.rotazione, rotazioneIniziale);
    });

    test('esce L1 con L2 presente: L2 resta come libero unico', () {
      final stato = ricalcolaStato(
        azioni: [ingresso(1, 70)],
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
        liberoInizialeId: 70,
        libero2InizialeId: 80,
        ruoloCambiLiberoIniziale: Ruolo.centrale,
      );

      expect(stato.liberoId, 80);
      expect(stato.libero2Id, isNull);
      expect(stato.ruoloCambiLibero, Ruolo.centrale);
    });

    test('esce L2: L1 resta com\'è', () {
      final stato = ricalcolaStato(
        azioni: [ingresso(1, 80)],
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
        liberoInizialeId: 70,
        libero2InizialeId: 80,
        ruoloCambiLiberoIniziale: Ruolo.centrale,
      );

      expect(stato.liberoId, 70);
      expect(stato.libero2Id, isNull);
    });

    test('escono entrambi, uno dopo l\'altro', () {
      final stato = ricalcolaStato(
        azioni: [ingresso(1, 70), ingresso(2, 80)],
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
        liberoInizialeId: 70,
        libero2InizialeId: 80,
        ruoloCambiLiberoIniziale: Ruolo.centrale,
      );

      expect(stato.liberoId, isNull);
      expect(stato.libero2Id, isNull);
      expect(stato.ruoloCambiLibero, isNull);
    });

    test('esce e poi rientra nello stesso set, con la sua coppia', () {
      final stato = ricalcolaStato(
        azioni: [
          ingresso(1, 70),
          ingresso(2, 70, coppia: Ruolo.schiacciatore),
        ],
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
        liberoInizialeId: 70,
        ruoloCambiLiberoIniziale: Ruolo.centrale,
      );

      expect(stato.liberoId, 70);
      expect(stato.ruoloCambiLibero, Ruolo.schiacciatore);
    });

    test('undo = togliere la riga: si torna senza libero', () {
      final stato = ricalcolaStato(
        azioni: const [],
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
      );

      expect(stato.liberoId, isNull);
      expect(stato.ruoloCambiLibero, isNull);
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

  group('ricalcolaStato — rotazione avversaria (scout avversari)', () {
    test('senza slot iniziale non si traccia alcuna rotazione avversaria', () {
      final stato = ricalcolaStato(
        azioni: const [
          AzioneScout(ordine: 1, esitoPunto: EsitoPunto.puntoAvversario),
          AzioneScout(ordine: 2, esitoPunto: EsitoPunto.puntoNostro),
        ],
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
        // palleggiatoreAvversarioSlotIniziale omesso → resta null
      );

      expect(stato.palleggiatoreAvversarioSlot, isNull);
    });

    test('l\'avversario ruota sul SUO sideout (vince mentre servivamo noi)', () {
      final stato = ricalcolaStato(
        azioni: const [
          // Servivamo noi: gli avversari spezzano il servizio → loro sideout.
          AzioneScout(ordine: 1, esitoPunto: EsitoPunto.puntoAvversario),
        ],
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
        palleggiatoreAvversarioSlotIniziale: 1,
      );

      // Rotazione oraria: lo slot del palleggiatore scende (1 → 6).
      expect(stato.palleggiatoreAvversarioSlot, 6);
      expect(stato.squadraAlServizio, Squadra.avversari);
    });

    test('lo slot scende di 1 (caso non-wrap): 3 → 2', () {
      final stato = ricalcolaStato(
        azioni: const [
          AzioneScout(ordine: 1, esitoPunto: EsitoPunto.puntoAvversario),
        ],
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
        palleggiatoreAvversarioSlotIniziale: 3,
      );

      expect(stato.palleggiatoreAvversarioSlot, 2);
    });

    test('l\'avversario NON ruota se serviva già (punto in battuta)', () {
      final stato = ricalcolaStato(
        azioni: const [
          // Servivano loro e fanno punto: nessuna rotazione avversaria.
          AzioneScout(ordine: 1, esitoPunto: EsitoPunto.puntoAvversario),
        ],
        servizioIniziale: Squadra.avversari,
        rotazioneIniziale: rotazioneIniziale,
        palleggiatoreAvversarioSlotIniziale: 3,
      );

      expect(stato.palleggiatoreAvversarioSlot, 3);
    });

    test('l\'avversario NON ruota sui NOSTRI punti (nostro sideout)', () {
      final stato = ricalcolaStato(
        azioni: const [
          // Servivano loro, noi facciamo sideout: ruotiamo NOI, non loro.
          AzioneScout(ordine: 1, esitoPunto: EsitoPunto.puntoNostro),
        ],
        servizioIniziale: Squadra.avversari,
        rotazioneIniziale: rotazioneIniziale,
        palleggiatoreAvversarioSlotIniziale: 3,
      );

      expect(stato.palleggiatoreAvversarioSlot, 3);
      // La nostra rotazione invece è avanzata di un sideout.
      expect(stato.rotazione, {1: 20, 2: 30, 3: 40, 4: 50, 5: 60, 6: 10});
    });

    test('sei sideout avversari riportano lo slot al valore iniziale', () {
      // Ogni sideout avversario è preceduto da un nostro (per restituire il
      // servizio): P avversario ruota solo sui 6 punti "puntoAvversario in
      // ricezione", tornando dopo un giro completo alla posizione di partenza.
      final azioni = <AzioneScout>[];
      var ordine = 1;
      for (var i = 0; i < 6; i++) {
        // Avversari in ricezione (noi al servizio) → loro sideout, ruotano.
        azioni.add(
          AzioneScout(ordine: ordine++, esitoPunto: EsitoPunto.puntoAvversario),
        );
        // Noi in ricezione → nostro sideout, il servizio torna a noi (loro NON
        // ruotano). Salto l'ultimo per lasciare il servizio agli avversari.
        if (i < 5) {
          azioni.add(
            AzioneScout(ordine: ordine++, esitoPunto: EsitoPunto.puntoNostro),
          );
        }
      }

      final stato = ricalcolaStato(
        azioni: azioni,
        servizioIniziale: Squadra.nostra,
        rotazioneIniziale: rotazioneIniziale,
        palleggiatoreAvversarioSlotIniziale: 4,
      );

      expect(stato.palleggiatoreAvversarioSlot, 4);
    });
  });

  group('formazione assente o incompleta', () {
    // Il formato di backup ammette `rotazioni` vuote, e i dati importati da
    // altri sistemi di scout spesso non registrano il sestetto iniziale. Il
    // punteggio non dipende dalla formazione e deve venire fuori lo stesso:
    // prima di questa guardia il primo sideout faceva esplodere il replay su
    // un null-check, e bastava un backup senza formazione per far crashare il
    // report di partita.
    test('senza formazione il punteggio si deriva comunque', () {
      final stato = ricalcolaStato(
        azioni: const [
          // Il primo è un nostro sideout: è l'azione che prima lanciava.
          AzioneScout(ordine: 1, esitoPunto: EsitoPunto.puntoNostro),
          AzioneScout(ordine: 2, esitoPunto: EsitoPunto.puntoNostro),
          AzioneScout(ordine: 3, esitoPunto: EsitoPunto.puntoAvversario),
        ],
        servizioIniziale: Squadra.avversari,
        rotazioneIniziale: const {},
      );

      expect(stato.punteggioNostro, 2);
      expect(stato.punteggioAvversario, 1);
      expect(stato.rotazione, isEmpty);
      // Il servizio continua a seguire gli eventi: è indipendente dalla
      // formazione, e resta l'informazione utile quando quella manca.
      expect(stato.squadraAlServizio, Squadra.avversari);
    });

    test('una formazione parziale resta com\'è invece di perdere giocatori',
        () {
      // Ruotare quattro posizioni su sei ne farebbe sparire due: meglio non
      // ruotare affatto che restituire una formazione mutilata.
      const parziale = {1: 10, 2: 20, 3: 30, 4: 40};
      final stato = ricalcolaStato(
        azioni: const [
          AzioneScout(ordine: 1, esitoPunto: EsitoPunto.puntoNostro),
        ],
        servizioIniziale: Squadra.avversari,
        rotazioneIniziale: parziale,
      );

      expect(stato.punteggioNostro, 1);
      expect(stato.rotazione, parziale);
    });

    test('con la formazione completa si ruota come sempre', () {
      // La guardia non deve cambiare il comportamento normale.
      final stato = ricalcolaStato(
        azioni: const [
          AzioneScout(ordine: 1, esitoPunto: EsitoPunto.puntoNostro),
        ],
        servizioIniziale: Squadra.avversari,
        rotazioneIniziale: const {1: 1, 2: 2, 3: 3, 4: 4, 5: 5, 6: 6},
      );

      expect(stato.rotazione, {1: 2, 2: 3, 3: 4, 4: 5, 5: 6, 6: 1});
    });
  });
}

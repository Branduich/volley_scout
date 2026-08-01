import '../models/enums.dart';
import 'tutorial_controller.dart';
import 'tutorial_target.dart';

/// La sequenza del tutorial. **È l'unico file da toccare per aggiungere,
/// togliere o riordinare un passo**: l'infrastruttura (scrim, registro,
/// controller, overlay, sandbox) non sa nulla di questa lista.
///
/// Per un passo su un elemento non ancora evidenziabile servono solo due
/// aggiunte: un valore in `TutorialTarget` e un `_anchor(...)` attorno al
/// widget in `scout_screen.dart`.
///
/// STATO: scheletro. Cinque passi rappresentativi, uno per ciascun meccanismo
/// di avanzamento, più le card di apertura e chiusura. La lista definitiva è
/// in preparazione (vedi il piano).
///
/// Vincolo da rispettare quando si allunga: **usare voti `+`, mai `#`**. Con
/// lo scout avversari attivo un `#` apre il ramo "errore difensivo forzato"
/// (Modello A) e la schermata si aspetta la risposta dell'altra squadra, cosa
/// che complica il passo successivo.
List<PassoTutorial> passiTutorial() => [
      const PassoTutorial(
        titolo: 'Benvenuto',
        testo:
            'Questa è la pagina di scout di una partita di prova: niente di '
            'quello che registri verrà salvato.\n\n'
            'Segui le indicazioni — a ogni passo puoi premere solo il pulsante '
            'evidenziato e ti mostrerò come dare un punteggio ad ogni '
            'fondamentale.',
        avanzaConBottone: true,
        etichettaBottone: 'Inizia',
      ),

      // --- avanzamento su COMPARSA DI UN ALTRO TARGET ---------------------
      const PassoTutorial(
        titolo: 'Tre tocchi',
        testo:
            'Il modo completo di registrare è a tre tocchi: giocatore, '
            'fondamentale, voto.\n\n'
            'Siamo al servizio: tocca il giocatore che batte, fuori dal campo.',
        bersaglio: TutorialTarget.tokenBattitore,
        avanzaSuComparsaDi: TutorialTarget.pannelloVoto,
      ),

      PassoTutorial(
        titolo: 'Il voto',
        testo:
            'In battuta il fondamentale è già deciso, quindi resta solo il '
            'voto. Per la battuta significano:\n\n'
            '#  battuta punto (ace)\n'
            '+  battuta buona: all\'avversario resta solo un attacco scontato\n'
            '/  battuta normale: il ricevitore ha qualche problema ad '
            'appoggiare bene all\'alzatore\n'
            '−  battuta facile, ricevuta positivamente\n'
            '=  battuta sbagliata (a rete o fuori campo): punto avversario\n\n'
            'Dai un + a questa battuta.',
        testoTraiettoria:
            'Dopo il voto puoi segnare dove è andata la palla: trascina il '
            'dito dal battitore fino al punto di arrivo, al rilascio l\'azione '
            'viene registrata. Sotto al campo puoi anche indicare il tipo di '
            'battuta. Se non ti interessa, torna indietro con la freccia in '
            'alto: l\'azione viene registrata lo stesso, solo senza '
            'traiettoria.',
        bersaglio: TutorialTarget.votoPositivo,
        // Di lato: sopra o sotto coprirebbe gli altri quattro voti.
        lato: LatoCard.sinistra,
        avanzaSuLog: (log, _) => log.any((a) =>
            a.fondamentale == Fondamentale.battuta && a.voto == Voto.positivo),
      ),

      const PassoTutorial(
        titolo: 'Per ora è tutto',
        testo:
            'Questo è lo scheletro del tutorial: gli altri passi arrivano '
            'presto.\n\nAll\'uscita la partita di prova viene cancellata.',
        avanzaConBottone: true,
        etichettaBottone: 'Termina',
      ),
    ];

/// Timeout e annullamento: messi da parte, andranno inseriti più avanti nella
/// sequenza (decisione dell'utente — si parte dalla battuta). Tenuti come
/// codice e non come commento così restano compilati e non invecchiano.
///
/// Vanno reinseriti INSIEME e in quest'ordine: il secondo annulla il timeout
/// registrato dal primo.
List<PassoTutorial> passiTimeout() => [
      // Avanzamento su AZIONE PERSISTITA.
      PassoTutorial(
        titolo: 'Timeout',
        testo:
            'Ogni squadra ha due timeout per set. Chiamane uno per la tua '
            'squadra: premi il pulsante con l\'orologio.',
        bersaglio: TutorialTarget.bottoneTimeoutNostro,
        avanzaSuLog: (log, _) =>
            log.isNotEmpty &&
            log.last.tipo == TipoAzione.timeout &&
            log.last.squadra == Squadra.nostra,
      ),

      // Avanzamento su LOG PIÙ CORTO (undo).
      PassoTutorial(
        titolo: 'Annullare',
        testo:
            'Tutto quello che registri finisce in un elenco e si può '
            'annullare. Annulla il timeout con la freccia in alto a destra: '
            'ti verrà chiesta una conferma.',
        bersaglio: TutorialTarget.bottoneUndo,
        avanzaSuLog: (log, lunghezzaIniziale) => log.length < lunghezzaIniziale,
      ),
    ];

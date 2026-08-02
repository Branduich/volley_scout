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
        bersaglio: TutorialTarget.votoNostroPositivo,
        // Di lato: sopra o sotto coprirebbe gli altri quattro voti.
        lato: LatoCard.sinistra,
        avanzaSuLog: (log, _) => log.any((a) =>
            a.fondamentale == Fondamentale.battuta && a.voto == Voto.positivo),
      ),

      // Dopo la battuta tocca agli avversari ricevere: la fase lo impone, il
      // fondamentale è già deciso come per la nostra battuta.
      const PassoTutorial(
        titolo: 'La squadra avversaria',
        testo:
            'In questa situazione lo scout prevede una squadra avversaria che '
            'è fittizia e utilizzata solo come supporto alla registrazione dei '
            'voti e delle traiettorie.\n\n'
            'Ha ricevuto il loro centrale: toccalo.',
        bersaglio: TutorialTarget.tokenAvversarioRicezione,
        avanzaSuComparsaDi: TutorialTarget.pannelloAvversario,
      ),

      PassoTutorial(
        titolo: 'Il voto della ricezione',
        testo:
            'I voti hanno lo stesso significato, letti dalla parte di chi '
            'riceve: # ricezione perfetta, che lascia all\'alzatore ogni '
            'scelta, fino a = ricezione sbagliata, che vale un punto per noi.'
            '\n\nQui la battuta li ha messi in difficoltà: dai un −.',
        bersaglio: TutorialTarget.votoAvvNegativo,
        // Di lato: sopra o sotto coprirebbe gli altri quattro voti.
        lato: LatoCard.sinistra,
        avanzaSuLog: (log, _) => log.any((a) =>
            a.squadra == Squadra.avversari &&
            a.fondamentale == Fondamentale.ricezione &&
            a.voto == Voto.negativo),
      ),

      // Ricezione fatta: da qui lo scambio è in fase LIBERA, nessun
      // fondamentale è più imposto e va scelto a mano nel pannello.
      const PassoTutorial(
        titolo: 'L\'attacco avversario',
        testo:
            'Ora simuliamo che debba attaccare il loro schiacciatore in '
            'zona 2. Toccalo.',
        bersaglio: TutorialTarget.tokenAvversarioAttacco,
        // NON su `pannelloAvversario`: quello è ancora a schermo per un
        // istante dal passo precedente e il tutorial salterebbe avanti da
        // solo. I bottoni del fondamentale, invece, compaiono solo a
        // pannello appena aperto — cioè esattamente dopo questo tocco.
        avanzaSuComparsaDi: TutorialTarget.fondAvvAttacco,
      ),

      const PassoTutorial(
        titolo: 'Scegliere il fondamentale',
        testo:
            'Battuta e ricezione erano obbligate dalla fase di gioco. Adesso '
            'lo scambio è aperto e sei tu a dire cosa è successo: premi '
            'Attacco.',
        bersaglio: TutorialTarget.fondAvvAttacco,
        lato: LatoCard.sinistra,
        avanzaSuComparsaDi: TutorialTarget.votoAvvMezzoPunto,
      ),

      PassoTutorial(
        titolo: 'Un attacco non risolutivo',
        testo:
            'L\'attacco non chiude il punto: la palla resta in gioco e '
            'torna dalla nostra parte. È un attacco facile da difendere: '
            'dai un /.',
        testoTraiettoria:
            'Anche per l\'attacco puoi segnare la traiettoria: trascina dal '
            'punto di partenza a dove è arrivata la palla. Sotto al campo '
            'puoi indicare il tipo di attacco.\n'
            'Se durante il trascinamento indugi sulla rete, viene registrato '
            'un tocco a muro: la traiettoria si spezza in quel punto.',
        bersaglio: TutorialTarget.votoAvvMezzoPunto,
        lato: LatoCard.sinistra,
        avanzaSuLog: (log, _) => log.any((a) =>
            a.squadra == Squadra.avversari &&
            a.fondamentale == Fondamentale.attacco &&
            a.voto == Voto.mezzoPunto),
      ),

      // La palla torna da noi: la risposta a un attacco è una DIFESA, non una
      // ricezione (quella esiste solo sulla battuta avversaria).
      const PassoTutorial(
        titolo: 'Tocca a noi',
        testo:
            'Il nostro libero, in zona 5, ha difeso benissimo. Toccalo.',
        bersaglio: TutorialTarget.tokenLibero,
        avanzaSuComparsaDi: TutorialTarget.fondNostroDifesa,
      ),

      const PassoTutorial(
        titolo: 'Difesa',
        testo:
            'La palla arrivava da un attacco: il fondamentale da scegliere '
            'è quindi la difesa.',
        bersaglio: TutorialTarget.fondNostroDifesa,
        lato: LatoCard.sinistra,
        avanzaSuComparsaDi: TutorialTarget.votoNostroPerfetto,
      ),

      PassoTutorial(
        titolo: 'Una difesa perfetta',
        testo:
            'La palla è tornata all\'alzatore pulita: può costruire il gioco '
            'come vuole. Dai un #.',
        bersaglio: TutorialTarget.votoNostroPerfetto,
        lato: LatoCard.sinistra,
        avanzaSuLog: (log, _) => log.any((a) =>
            a.squadra == Squadra.nostra &&
            a.fondamentale == Fondamentale.difesa &&
            a.voto == Voto.perfetto),
      ),

      const PassoTutorial(
        titolo: 'Il nostro attacco',
        testo:
            'Alzata al nostro schiacciatore in zona 4, che schiaccia a terra. '
            'Toccalo.',
        bersaglio: TutorialTarget.tokenNostroAttaccante,
        avanzaSuComparsaDi: TutorialTarget.fondNostroAttacco,
      ),

      const PassoTutorial(
        titolo: 'Attacco',
        testo: 'Il fondamentale questa volta è l\'attacco.',
        bersaglio: TutorialTarget.fondNostroAttacco,
        lato: LatoCard.sinistra,
        avanzaSuComparsaDi: TutorialTarget.votoNostroPerfetto,
      ),

      PassoTutorial(
        titolo: 'Schiacciata vincente',
        testo:
            'La palla è finita a terra: dai un #.\n\n'
            'Il punteggio non cambierà subito. Con lo scout avversario attivo '
            'il punto lo porta l\'errore di chi doveva difendere, che '
            'registrerai fra un istante: così l\'azione viene contata una '
            'volta sola.',
        testoTraiettoria:
            'Segna dove è finita la schiacciata: trascina dal punto di '
            'partenza al punto di caduta.\n'
            'Se indugi sulla rete viene registrato un tocco a muro e la '
            'traiettoria si spezza in quel punto.',
        bersaglio: TutorialTarget.votoNostroPerfetto,
        lato: LatoCard.sinistra,
        avanzaSuLog: (log, _) => log.any((a) =>
            a.squadra == Squadra.nostra &&
            a.fondamentale == Fondamentale.attacco &&
            a.voto == Voto.perfetto),
      ),

      // Chiusura dello scambio (Modello A): dopo il nostro `#` i token
      // avversari offrono un pannello RISTRETTO a Muro/Difesa in rosso, che
      // registra il `=` in un colpo solo — e con esso il punto.
      const PassoTutorial(
        titolo: 'Il difensore non è arrivato',
        testo:
            'La palla è caduta nella loro zona 5, dove la difesa non ci è '
            'arrivata. Tocca quel giocatore.',
        bersaglio: TutorialTarget.tokenAvversarioDifesa,
        avanzaSuComparsaDi: TutorialTarget.fondAvvDifesa,
      ),

      PassoTutorial(
        titolo: 'Il punto',
        testo:
            'Il pannello si è ristretto a muro e difesa, in rosso: sono le '
            'sole risposte possibili a una schiacciata a terra, e premendone '
            'una registri direttamente l\'errore (=).\n\n'
            'Premi Difesa: adesso il punteggio si muove.',
        bersaglio: TutorialTarget.fondAvvDifesa,
        lato: LatoCard.sinistra,
        avanzaSuLog: (log, _) => log.any((a) =>
            a.squadra == Squadra.avversari &&
            a.fondamentale == Fondamentale.difesa &&
            a.voto == Voto.errore),
      ),

      const PassoTutorial(
        titolo: 'Il registro',
        testo:
            'Il punteggio adesso è 1 a 0, come si vede nella parte alta dello '
            'schermo.\n\n'
            'Se la finestra di registro dei voti è attiva, come in questo '
            'caso, è possibile consultare tutte le azioni registrate.',
        bersaglio: TutorialTarget.logAzioni,
        avanzaConBottone: true,
      ),

      const PassoTutorial(
        titolo: 'La rotazione',
        testo:
            'Ora siamo in battuta in P6. La mini mappa a sinistra indica la '
            'rotazione e dà anche la possibilità, in caso di errore, di '
            'cambiarla di una posizione in avanti e una all\'indietro tramite '
            'i due bottoni.',
        bersaglio: TutorialTarget.minimappa,
        bersaglioSecondario: TutorialTarget.bottoniCorrezioneRotazione,
        avanzaConBottone: true,
      ),

      const PassoTutorial(
        titolo: 'Per ora è tutto',
        testo:
            'Hai registrato uno scambio intero: battuta, ricezione, attacco, '
            'difesa e il punto che lo chiude.\n\n'
            'Molte altre informazioni sull\'utilizzo di Volley Stratego si '
            'possono trovare alla pagina:\n'
            'https://sites.google.com/view/volleystratego/come-si-usa\n\n'
            'oppure scrivendo una mail a:\n'
            'volleystratego@gmail.com',
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

import '../l10n/app_localizations.dart';
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
/// STATO: sequenza completa e TRADOTTA (2026-08-16). Uno scambio intero —
/// battuta, ricezione, attacco, difesa e il punto che lo chiude — poi
/// registro, rotazione, timeout e annullamento, il menu di utilità in tre
/// passi, infine la card di chiusura coi riferimenti al sito e alla mail.
///
/// I testi vivono in `lib/l10n/*.arb` col prefisso `tutorial*` e arrivano qui
/// già risolti tramite [l]: la sequenza si compone una volta sola in
/// `TutorialController.inizia`, non a ogni build della card.
///
/// Sui voti `#`: con lo scout avversari attivo un `#` NON chiude il punto da
/// solo (Modello A) — la schermata entra in "CONCLUDI …" e aspetta l'errore
/// difensivo dell'altra squadra, registrato con UN tocco e senza pannello.
/// Non è più un divieto (lo era finché nessun passo lo gestiva): dal
/// 2026-08-22 la battuta del tutorial è un ACE e quel ramo si insegna. Ma
/// resta la cosa da ricordare quando si aggiunge un passo: dopo un `#` il
/// passo successivo deve aspettarsi la scorciatoia, non una pulsantiera.
List<PassoTutorial> passiTutorial(AppLocalizations l) => [
      PassoTutorial(
        titolo: l.tutorialBenvenutoTitolo,
        testo: l.tutorialBenvenutoTesto,
        avanzaConBottone: true,
        etichettaBottone: l.tutorialInizia,
      ),

      // Il modello mentale prima di qualunque azione: quanti tocchi servono e
      // dove stanno. Puramente informativo — niente bersaglio, quindi velo
      // pieno e card al centro — così si legge senza il campo che distrae.
      PassoTutorial(
        titolo: l.tutorialAzioniTitolo,
        testo: l.tutorialAzioniTesto,
        avanzaConBottone: true,
      ),

      // --- avanzamento su COMPARSA DI UN ALTRO TARGET ---------------------
      PassoTutorial(
        titolo: l.tutorialTreTocchiTitolo,
        testo: l.tutorialTreTocchiTesto,
        bersaglio: TutorialTarget.tokenBattitore,
        avanzaSuComparsaDi: TutorialTarget.pannelloVoto,
      ),

      PassoTutorial(
        titolo: l.tutorialVotoTitolo,
        testo: l.tutorialVotoTesto,
        bersaglio: TutorialTarget.votoNostroPerfetto,
        // Di lato: sopra o sotto coprirebbe gli altri quattro voti.
        lato: LatoCard.sinistra,
        avanzaSuLog: (log, _) => log.any((a) =>
            a.fondamentale == Fondamentale.battuta && a.voto == Voto.perfetto),
      ),

      // ACE: la battuta `#` NON chiude il punto da sola (Modello A). Lo schermo
      // entra in "CONCLUDI RICEZIONE", i nostri token si spengono e toccare il
      // ricevitore avversario registra la ricezione `=` DIRETTAMENTE, senza
      // pannello — è la scorciatoia dell'ace.
      //
      // Per questo qui NON si può avanzare su `pannelloAvversario`: quel
      // pannello non si apre proprio, e il tutorial resterebbe bloccato. Si
      // avanza sull'azione registrata, che è l'unica cosa che succede davvero.
      // Per lo stesso motivo il passo che votava la ricezione con `−` non
      // esiste più: con la scorciatoia non c'è nessun voto da dare.
      PassoTutorial(
        titolo: l.tutorialAvversariTitolo,
        testo: l.tutorialAvversariTesto,
        bersaglio: TutorialTarget.tokenAvversarioRicezione,
        avanzaSuLog: (log, _) => log.any((a) =>
            a.squadra == Squadra.avversari &&
            a.fondamentale == Fondamentale.ricezione &&
            a.voto == Voto.errore),
      ),

      // Vinto il punto SULLA NOSTRA battuta non si ruota (ricalcolaStato ruota
      // solo sul sideout): al servizio torna la stessa giocatrice, ed è quello
      // che il testo promette. Informativo, con "Avanti": la spiegazione lunga
      // sta qui perché nel passo dopo il campo dev'essere sgombro.
      PassoTutorial(
        titolo: l.tutorialAncoraBattutaTitolo,
        testo: l.tutorialAncoraBattutaTesto,
        // Buco sul giocatore di cui parla la card: si vede di chi si tratta
        // mentre leggi, e sparisce premendo "Avanti" (il passo dopo è a campo
        // libero, senza velo).
        bersaglio: TutorialTarget.tokenBattitore,
        avanzaConBottone: true,
      ),

      // CAMPO LIBERO: né velo né card, così la traiettoria si vede mentre la
      // tracci. Il `testo` è il promemoria di una riga nella fascia centrale
      // (vedi PassoTutorial.campoLibero e ScoutScreen._bannerCentrale).
      //
      // Avanza sul SEGNALE del tratto catturato, non sul tocco del token: il
      // servizio si può far partire da tutta la linea di fondo, e chi comincia
      // il trascinamento un dito più in là disegna comunque ma non tocca mai
      // l'ancora del battitore — il passo non sarebbe avanzato, e senza card
      // né velo non ci sarebbe stato modo di capire perché.
      PassoTutorial(
        testo: l.tutorialTrascinaTesto,
        campoLibero: true,
        traiettoriaConsentita: true,
        // Come sopra: il bersaglio serve solo a dire all'aiuto automatico
        // quale pulsantiera aprire, non a bucare un velo che qui non c'è.
        bersaglio: TutorialTarget.tokenBattitore,
        avanzaSuSegnale: SegnaleTutorial.traiettoriaDisegnata,
        // Chi non trascina non resta davanti a uno schermo muto: dopo qualche
        // secondo l'app apre la pulsantiera al posto suo e si prosegue senza
        // traiettoria (vedi PassoTutorial.aiutoDopo).
        aiutoDopo: const Duration(seconds: 8),
      ),

      // Il voto di QUESTA battuta, la seconda: `+`, mentre la prima era `#`.
      // I due predicati restano quindi distinguibili anche guardando tutto il
      // log — che è come `avanzaSuLog` lavora.
      PassoTutorial(
        titolo: l.tutorialVotoBattutaTitolo,
        testo: l.tutorialVotoBattutaTesto,
        bersaglio: TutorialTarget.votoNostroPositivo,
        // Di lato: sopra o sotto coprirebbe gli altri quattro voti.
        lato: LatoCard.sinistra,
        avanzaSuLog: (log, _) => log.any((a) =>
            a.fondamentale == Fondamentale.battuta && a.voto == Voto.positivo),
      ),

      // Ricezione della SECONDA battuta, che è un `+` e non un ace: niente
      // scorciatoia, gli avversari ricevono davvero e la pulsantiera si apre
      // col fondamentale già imposto su Ricezione.
      //
      // Il bersaglio è il segnaposto in zona 5, che nella rotazione avversaria
      // canonica è `S2` (vedi kRuoliAvversariTutorial): quel ruolo aveva già
      // un target, nato per la difesa di fine scambio, e il token è lo stesso.
      // Un ruolo può avere UN solo target — la corrispondenza inversa prende
      // la prima voce che combacia — quindi si riusa, non se ne aggiunge.
      PassoTutorial(
        titolo: l.tutorialRicezioneAvvTitolo,
        testo: l.tutorialRicezioneAvvTesto,
        bersaglio: TutorialTarget.tokenAvversarioDifesa,
        avanzaSuComparsaDi: TutorialTarget.pannelloAvversario,
      ),

      PassoTutorial(
        titolo: l.tutorialVotoRicezioneTitolo,
        testo: l.tutorialVotoRicezioneTesto,
        bersaglio: TutorialTarget.votoAvvMezzoPunto,
        // Di lato: sopra o sotto coprirebbe gli altri quattro voti.
        lato: LatoCard.sinistra,
        avanzaSuLog: (log, _) => log.any((a) =>
            a.squadra == Squadra.avversari &&
            a.fondamentale == Fondamentale.ricezione &&
            a.voto == Voto.mezzoPunto),
      ),

      // Ricezione fatta: da qui lo scambio è in fase LIBERA, nessun
      // fondamentale è più imposto e va scelto a mano nel pannello.
      // Come per la battuta disegnata: la spiegazione sta in una card con
      // "Avanti", perché nel passo dopo il campo dev'essere sgombro.
      PassoTutorial(
        titolo: l.tutorialAttaccoAvvTitolo,
        testo: l.tutorialAttaccoAvvTesto,
        bersaglio: TutorialTarget.tokenAvversarioAttacco,
        avanzaConBottone: true,
      ),

      PassoTutorial(
        testo: l.tutorialTrascinaTesto,
        campoLibero: true,
        traiettoriaConsentita: true,
        // Serve solo all'aiuto automatico, per sapere quale pulsantiera
        // aprire se il trascinamento non arriva: qui non c'è velo da bucare.
        bersaglio: TutorialTarget.tokenAvversarioAttacco,
        avanzaSuSegnale: SegnaleTutorial.traiettoriaDisegnata,
        aiutoDopo: const Duration(seconds: 8),
      ),

      // NIENTE passo "premi Attacco": il trascinamento l'ha già deciso
      // (_preselezionaAttaccoDaTraiettoria) e ha per giunta sostituito quella
      // colonna coi tipi di attacco — il bottone non esiste più, e un passo
      // che lo aspettava lasciava il tutorial bloccato. La spiegazione della
      // colonna di sinistra è passata al passo della DIFESA, che è il primo
      // punto in cui il fondamentale si sceglie davvero a mano.
      PassoTutorial(
        titolo: l.tutorialAttaccoNonRisolutivoTitolo,
        testo: l.tutorialAttaccoNonRisolutivoTesto,
        bersaglio: TutorialTarget.votoAvvMezzoPunto,
        lato: LatoCard.sinistra,
        avanzaSuLog: (log, _) => log.any((a) =>
            a.squadra == Squadra.avversari &&
            a.fondamentale == Fondamentale.attacco &&
            a.voto == Voto.mezzoPunto),
      ),

      // La palla torna da noi: la risposta a un attacco è una DIFESA, non una
      // ricezione (quella esiste solo sulla battuta avversaria).
      PassoTutorial(
        titolo: l.tutorialToccaANoiTitolo,
        testo: l.tutorialToccaANoiTesto,
        bersaglio: TutorialTarget.tokenLibero,
        avanzaSuTap: true,
      ),

      PassoTutorial(
        titolo: l.tutorialDifesaTitolo,
        testo: l.tutorialDifesaTesto,
        bersaglio: TutorialTarget.fondNostroDifesa,
        lato: LatoCard.sinistra,
        avanzaSuTap: true,
      ),

      PassoTutorial(
        titolo: l.tutorialDifesaPerfettaTitolo,
        testo: l.tutorialDifesaPerfettaTesto,
        bersaglio: TutorialTarget.votoNostroPerfetto,
        lato: LatoCard.sinistra,
        avanzaSuLog: (log, _) => log.any((a) =>
            a.squadra == Squadra.nostra &&
            a.fondamentale == Fondamentale.difesa &&
            a.voto == Voto.perfetto),
      ),

      // Terzo trascinamento, stessa forma dei primi due: card che spiega,
      // poi campo libero.
      PassoTutorial(
        titolo: l.tutorialNostroAttaccoTitolo,
        testo: l.tutorialNostroAttaccoTesto,
        bersaglio: TutorialTarget.tokenNostroAttaccante,
        avanzaConBottone: true,
      ),

      PassoTutorial(
        testo: l.tutorialTrascinaTesto,
        campoLibero: true,
        traiettoriaConsentita: true,
        bersaglio: TutorialTarget.tokenNostroAttaccante,
        avanzaSuSegnale: SegnaleTutorial.traiettoriaDisegnata,
        aiutoDopo: const Duration(seconds: 8),
      ),

      // Come per l'attacco avversario: il disegno ha già scelto il
      // fondamentale, quindi si va dritti al voto.
      PassoTutorial(
        titolo: l.tutorialSchiacciataTitolo,
        testo: l.tutorialSchiacciataTesto,
        bersaglio: TutorialTarget.votoNostroPerfetto,
        lato: LatoCard.sinistra,
        avanzaSuLog: (log, _) => log.any((a) =>
            a.squadra == Squadra.nostra &&
            a.fondamentale == Fondamentale.attacco &&
            a.voto == Voto.perfetto),
      ),

      // Chiusura dello scambio (Modello A): dopo il nostro `#` i token
      // avversari offrono una pulsantiera RISTRETTA a Muro/Difesa in rosso, che
      // registra il `=` in un colpo solo — e con esso il punto.
      PassoTutorial(
        titolo: l.tutorialDifensoreTitolo,
        testo: l.tutorialDifensoreTesto,
        bersaglio: TutorialTarget.tokenAvversarioDifesa,
        avanzaSuTap: true,
      ),

      PassoTutorial(
        titolo: l.tutorialPuntoTitolo,
        testo: l.tutorialPuntoTesto,
        bersaglio: TutorialTarget.fondAvvDifesa,
        lato: LatoCard.sinistra,
        avanzaSuLog: (log, _) => log.any((a) =>
            a.squadra == Squadra.avversari &&
            a.fondamentale == Fondamentale.difesa &&
            a.voto == Voto.errore),
      ),

      PassoTutorial(
        titolo: l.tutorialRegistroTitolo,
        testo: l.tutorialRegistroTesto,
        bersaglio: TutorialTarget.logAzioni,
        avanzaConBottone: true,
      ),

      PassoTutorial(
        titolo: l.tutorialRotazioneTitolo,
        testo: l.tutorialRotazioneTesto,
        bersaglio: TutorialTarget.minimappa,
        bersaglioSecondario: TutorialTarget.bottoniCorrezioneRotazione,
        avanzaConBottone: true,
      ),

      // Timeout e annullamento in coda, appena prima della chiusura: sono i
      // due pulsanti "di servizio" della barra, e il secondo passo annulla il
      // timeout registrato dal primo — vanno quindi tenuti INSIEME e in
      // quest'ordine.
      //
      // Avanzamento su AZIONE PERSISTITA.
      PassoTutorial(
        titolo: l.tutorialTimeoutTitolo,
        testo: l.tutorialTimeoutTesto,
        bersaglio: TutorialTarget.bottoneTimeoutNostro,
        avanzaSuLog: (log, _) =>
            log.isNotEmpty &&
            log.last.tipo == TipoAzione.timeout &&
            log.last.squadra == Squadra.nostra,
      ),

      // Avanzamento su LOG PIÙ CORTO (undo).
      PassoTutorial(
        titolo: l.tutorialAnnullareTitolo,
        testo: l.tutorialAnnullareTesto,
        bersaglio: TutorialTarget.bottoneUndo,
        avanzaSuLog: (log, lunghezzaIniziale) => log.length < lunghezzaIniziale,
      ),

      // --- Il menu di utilità -------------------------------------------
      // Tre passi: aprilo, leggi cosa contiene, chiudilo. Il terzo NON è
      // decorativo: con il drawer aperto il "Termina" della card finale
      // (Navigator.pop) chiuderebbe il drawer invece di uscire dal tutorial,
      // perché il Drawer registra una local history entry sulla route.
      PassoTutorial(
        titolo: l.tutorialMenuTitolo,
        testo: l.tutorialMenuTesto,
        bersaglio: TutorialTarget.bottoneMenu,
        avanzaSuSegnale: SegnaleTutorial.drawerAperto,
      ),

      PassoTutorial(
        titolo: l.tutorialVociMenuTitolo,
        testo: l.tutorialVociMenuTesto,
        // Nessun bersaglio di proposito: il velo copre tutto e NIENTE è
        // premibile. Bucare il drawer intero lo renderebbe tappabile voce per
        // voce, e un tocco su "Fine" o "Indietro" porterebbe l'utente fuori
        // dal tutorial mentre sta solo leggendo. Il menu resta comunque
        // leggibile sotto al velo, che è al 45%.
        //
        // Card a DESTRA: il drawer occupa la sinistra e una card centrata lo
        // coprirebbe a metà — proprio le voci che l'elenco sta descrivendo.
        // Senza buco il lato non contava; ora sì (vedi _cardPasso).
        lato: LatoCard.destra,
        avanzaConBottone: true,
      ),

      PassoTutorial(
        titolo: l.tutorialCambiaCampoTitolo,
        testo: l.tutorialCambiaCampoTesto,
        bersaglio: TutorialTarget.voceCambiaCampo,
        lato: LatoCard.destra,
        avanzaSuSegnale: SegnaleTutorial.drawerChiuso,
      ),

      PassoTutorial(
        titolo: l.tutorialFineTitolo,
        testo: l.tutorialFineTesto,
        // URL e mail restano qui e NON in ARB: non sono testo da tradurre.
        url: 'https://sites.google.com/view/volleystratego/come-si-usa',
        mail: 'volleystratego@gmail.com',
        avanzaConBottone: true,
        etichettaBottone: l.tutorialTermina,
      ),
    ];

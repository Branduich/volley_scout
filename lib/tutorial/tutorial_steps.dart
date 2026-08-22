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
/// Vincolo da rispettare quando si allunga: **usare voti `+`, mai `#`**. Con
/// lo scout avversari attivo un `#` apre il ramo "errore difensivo forzato"
/// (Modello A) e la schermata si aspetta la risposta dell'altra squadra, cosa
/// che complica il passo successivo.
List<PassoTutorial> passiTutorial(AppLocalizations l) => [
      PassoTutorial(
        titolo: l.tutorialBenvenutoTitolo,
        testo: l.tutorialBenvenutoTesto,
        avanzaConBottone: true,
        etichettaBottone: l.tutorialInizia,
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
        bersaglio: TutorialTarget.votoNostroPositivo,
        // Di lato: sopra o sotto coprirebbe gli altri quattro voti.
        lato: LatoCard.sinistra,
        avanzaSuLog: (log, _) => log.any((a) =>
            a.fondamentale == Fondamentale.battuta && a.voto == Voto.positivo),
      ),

      // Dopo la battuta tocca agli avversari ricevere: la fase lo impone, il
      // fondamentale è già deciso come per la nostra battuta.
      PassoTutorial(
        titolo: l.tutorialAvversariTitolo,
        testo: l.tutorialAvversariTesto,
        bersaglio: TutorialTarget.tokenAvversarioRicezione,
        avanzaSuComparsaDi: TutorialTarget.pannelloAvversario,
      ),

      PassoTutorial(
        titolo: l.tutorialVotoRicezioneTitolo,
        testo: l.tutorialVotoRicezioneTesto,
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
      PassoTutorial(
        titolo: l.tutorialAttaccoAvvTitolo,
        testo: l.tutorialAttaccoAvvTesto,
        bersaglio: TutorialTarget.tokenAvversarioAttacco,
        // NON su comparsa di un pezzo del pannello: la pulsantiera è unica,
        // fondamentali e voti esistono già all'apertura — e il pannello del
        // passo precedente può essere ancora a schermo per un istante, quindi
        // qualunque suo target farebbe saltare avanti da solo. Si avanza sul
        // tocco del token, che è esattamente l'azione richiesta.
        avanzaSuTap: true,
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

      PassoTutorial(
        titolo: l.tutorialNostroAttaccoTitolo,
        testo: l.tutorialNostroAttaccoTesto,
        bersaglio: TutorialTarget.tokenNostroAttaccante,
        avanzaSuTap: true,
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

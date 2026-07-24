## Fasi di sviluppo

- **Fase 1 — Squadre e giocatori** (COMPLETATA)
  - [x] Enum, database (Teams, Players), repository, provider
  - [x] HomeScreen con menu
  - [x] Lista squadre + form crea/modifica/elimina squadra
  - [x] Gestione giocatori nella schermata di modifica squadra (layout 2 colonne,
        PlayerFormScreen con nome/cognome/numero/ruolo)
  - [x] Tema centralizzato (AppTheme.light agganciato a main.dart)
  - [x] Enum Voto definito in enums.dart

- **Fase 2 — Gestione partite** (COMPLETATA)
  - [x] Tabella VolleyMatches (schema v3), MatchRepository, provider
  - [x] MatchesScreen: lista partite con badge Casa/Trasferta + FAB + bottone "Inizia"
        (vedi anche Fase 3 per l'evoluzione a due sezioni/"Riprendi")
  - [x] MatchFormScreen: nome, date/time picker, switch casa/trasferta, palestra
  - [x] TeamSelectionScreen: label dinamica, lista squadre, selezione salva teamId,
        crea squadra al volo
  - [x] LineupScreen: selezione formazione (griglia campo, assegnazione giocatori,
        doppio libero, avanzamento automatico CCW, conferma)
  - [x] FormationConfigScreen: sistema di gioco (palleggiatore unico), conferma
        palleggiatore + cambi del libero (centrali/schiacciatori in coppia),
        campo cambi nascosto se la formazione non ha libero
  - [x] ScoutScreen: placeholder con contesto match + team pronto per Fase 3

- **Fase 3 — Scout** (IN CORSO)
  - [x] Setup grafico ScoutScreen: sfondo, barra top, campo doppio + campo
        piccolo proporzionati allo schermo (vedi sezione "Interfaccia di scout")
  - [x] Funzione pura `ricalcolaStato()` (punteggio + rotazione derivati) +
        14 unit test — `lib/logic/ricalcola_stato.dart` /
        `test/logic/ricalcola_stato_test.dart`. Vedi dettagli nel Modello dati.
  - [x] Modello dati a DB (schema v6/v7): tabelle `MatchSet`, `Rotation`,
        `ScoutAction`, campo `StatoPartita`/`setCorrente` su `VolleyMatches`,
        enum `TipoAzione`/`Fondamentale`/`TipoAttacco`/`TipoBattuta` in
        `enums.dart`.
  - [x] Avvio del set: dialog "Chi serve per primo?" in `ScoutScreen`,
        `MatchSetRepository.creaSet()` + `salvaRotazioneIniziale()`
        (vedi Modello dati). `VolleyMatch.stato` passa a `inCorso`.
  - [x] `ScoutActionRepository` + bottoni rapidi (Errore/Punto nostro e
        avversario) collegati a `ricalcolaStato()` su eventi reali —
        punteggio/servizio/rotazione ora **derivati**, non più contatori
        manuali (`_nostroScore`/`_avversarioScore`/`_rotationSteps` rimossi
        fuori dalla modalità test). Vedi Modello dati e "Interfaccia di scout".
  - [x] Voto battuta: tap sul battitore → pannello voto (5 bottoni verticali,
        colori da `CourtStyle.votoColor()`) → `ScoutAction` reale via
        `registraAzioneScout()`, esito automatico (`#`→ace, `=`→errore,
        resto→nessuno), battitore si riporta in campo dopo un voto non
        terminale. Niente traiettoria. Vedi "Interfaccia di scout".
  - [x] Tipo di battuta (opzionale): griglia 2×2 "Dal basso"/"Float"/
        "Salto"/"Salto float" nel pannello voto, solo per la battuta —
        ignorabile per non rallentare il flusso veloce, resta "armata" tra
        battute dello stesso giocatore. Vedi "Interfaccia di scout".
  - [x] Voto ricezione: stesso pannello e flusso della battuta, generalizzato
        a "chiunque riceve" (tutti e 6 i ruoli, libero compreso) quando
        servono gli avversari — `_tapHandlerPerGiocatore`/
        `_giocatoreTappabile` decidono battuta vs ricezione in base a chi
        è al servizio. Esito automatico: solo `errore` → punto avversario
        (la ricezione non vince mai punti da sola). Dopo un voto non
        terminale, `_activeDefenseMap` si disattiva e i giocatori si
        spostano in posizione di attacco secondo la rotazione (stessa
        animazione del battitore dopo la battuta). Vedi "Interfaccia di
        scout".
  - [x] Banner ultima azione: riga sopra al campo, mostra l'ultima
        `ScoutAction` del set (stesso dato che alimenterà le statistiche),
        resta visibile finché non arriva l'azione successiva (nessun timer
        di sparizione). Vedi "Interfaccia di scout".
  - [x] Voto alzata/attacco/muro/difesa: dopo che battuta o ricezione sono
        state giudicate con un voto non terminale (fase "libera" di uno
        scambio), qualunque giocatore è tappabile e il pannello voto chiede
        prima il fondamentale (4 bottoni Alzata/Attacco/Muro/Difesa,
        `_sceglieFondamentale`) poi il voto — generalizza il flusso a 3
        tocchi a tutti i fondamentali tranne `errore`. Esito automatico
        generalizzato: `=` → punto avversario per qualunque fondamentale,
        `#` → punto nostro anche per attacco/muro (oltre alla battuta).
        Riga di chip col tipo di attacco (Forte/Piazzata/Pallonetto), stessa
        meccanica "armata per giocatore" della battuta. Vedi "Interfaccia di
        scout" → "Voto battuta/ricezione/altri fondamentali".
  - [ ] **Nice to have, non in programma ora**: griglia unica 20 bottoni
        (4 colonne Alzata/Attacco/Muro/Difesa × 5 righe Voto) per registrare
        fondamentale+voto in un solo tocco invece dei due passaggi attuali
        ("scegli fondamentale" → "scegli voto"). Richiederebbe spostare
        l'azzeramento di `_tipoAttaccoSelezionato` (oggi in
        `_sceglieFondamentale`) al momento dell'apertura del pannello per un
        nuovo giocatore, dato che non ci sarebbe più un passaggio
        "fondamentale" separato da cui farlo scattare. Per ora si è scelto
        di tenere il flusso a due passi, solo con i bottoni fondamentale
        ingranditi (vedi sopra).
  - [x] Traiettoria battuta/attacco: `TrajectoryScreen` dedicata, drag per
        disegnare la freccia, back per saltare — vedi "Interfaccia di
        scout" per i dettagli.
  - [~] Esito modificabile prima di confermare l'azione (idea annotata nel
        Modello dati) — **SCARTATA** (2026-07-13): non verrà implementata,
        l'esito automatico fondamentale+voto basta. Non riproporla.
  - [x] Override manuale punteggio: bottoni "+"/"-" (`Icons.add`/
        `Icons.remove`, 22×22) accanto a ciascun numero in barra superiore,
        dentro `_buildScoreDisplay` (ora prende anche `Squadra` per sapere
        quale dei due correggere). Override diretto del valore mostrato,
        **non** loggato come `ScoutAction` (fine set/match restano comunque
        decisioni manuali, quindi non serve restare fedeli al log eventi).
        Schema: due colonne su `MatchSet` — `correzionePuntiNostri`/
        `correzionePuntiAvversari` (default 0, schema v9) — che si sommano
        al punteggio calcolato da `ricalcolaStato()` in
        `_punteggioNostro`/`_punteggioAvversario`.
        `MatchSetRepository.correggiPunteggio(setId, {deltaNostro,
        deltaAvversario})` somma il delta al valore già persistito e
        ritorna il `MatchSet` aggiornato — `_correggiPunteggio()` in
        `ScoutScreen` lo richiama e aggiorna `_setCorrente` localmente
        (questi due campi non hanno uno stream da osservare, a differenza
        di punteggio/rotazione "veri" derivati da `_statoSetReale`).
        Bottoni disabilitati con le stesse condizioni dei bottoni rapidi
        (`_bottoniRapidiAttivi`); "-" disabilitato anche a punteggio già a
        0 (un punteggio reale non scende mai sotto zero).
  - [x] **Correzione manuale rotazione** (per errori di scout/segnapunti) —
        IMPLEMENTATA come evento loggato `TipoAzione.correzioneRotazione`
        (nessuna migrazione: il verso `DirezioneRotazione{avanti,indietro}`
        va nel `.name` dentro la colonna polimorfica `tipoEsecuzione`).
        `AzioneScout.correzioneRotazione` + helper `_ruotataIndietro`
        (inversa di `_ruotata`) in `ricalcola_stato.dart`: ruota SOLO le
        posizioni, non punteggio/servizio (`esitoPunto = nessuno`).
        `ScoutActionRepository.registraCorrezioneRotazione(setId, direzione)`
        (rallyId standalone, escluso dall'ereditarietà come il timeout).
        UI: due bottoni sotto la mini-mappa (`_buildRotationCorrectionButton`,
        stile/dimensione di `_buildRotationButton`) visibili in gioco reale
        (`_bottoniRapidiAttivi`), label = rotazione di ARRIVO calcolata live
        (`_slotDestinazioneCorrezione`: avanti = slot−1 P1→P6 a sinistra,
        indietro = slot+1 P1→P2 a destra); applicazione immediata, undo
        standard (è una riga come le altre). Banner/log: "Rotazione
        P{iniziale} → P{finale}" corretta al momento di OGNI correzione —
        `_computeLabelsCorrezione()` calcola gli slot prima/dopo riusando
        `ricalcolaStato()` sui prefissi (non `_currentSlot`, che sarebbe
        uguale per tutte le voci storiche). Le freccette rotazione
        pre-esistenti restano solo per la modalità test. CSV: riga
        "Correzione rotazione" con verso "Avanti"/"Indietro". Test in
        `ricalcola_stato_test.dart` (avanti, indietro, avanti+indietro =
        identità, no-touch punteggio/servizio, mista con un sideout).
  - [x] **Sostituzione giocatore a set in corso ("cambio giocatore")** —
        IMPLEMENTATA (evento `TipoAzione.cambioGiocatore`, schema v11+v12).
        Vincolo chiave confermato dallo sviluppatore: il cambio NON altera
        mai la rotazione — il subentrante prende ESATTAMENTE la posizione
        di rotazione dell'uscente e ruota da lì in poi. Conteggio cambi
        (6, presto 8 per set) rimandato — derivabile contando i gruppi
        `gruppoCambio` distinti (o le righe `cambioGiocatore`).
    - **Flusso UI** (rivisto durante lo sviluppo: i dialog sequenziali
      della prima versione erano scomodi per i cambi multipli — il doppio
      cambio è due sostituzioni insieme): voce "Sostituzione" nel drawer
      (`Icons.swap_vert`, `enabled: _bottoniRapidiAttivi`) →
      `SostituzioneScreen` (campo `CourtView` con la rotazione CORRENTE +
      lista panchina a destra, replica l'esperienza di inizio partita; tap
      card = chi esce, tap panchina = chi entra al suo posto, N cambi
      pending in una visita, badge ✕ per annullare un cambio pending) →
      "Avanti" → `FormationConfigScreen` in **modalità conferma**
      (parametri opzionali `modalitaConferma`/`palleggiatoreSlotIniziale`/
      `ruoloCambiLiberoIniziale`: SEMPRE mostrata, precompilata coi valori
      effettivi — nessun rilevamento automatico "serve il prompt?", scelta
      esplicita dell'utente; il bottone fa pop col record
      `ConfigurazioneFormazione` invece di push verso ScoutScreen; il
      flusso di inizio partita resta invariato coi default) → al ritorno
      `ScoutScreen._avviaSostituzione()` calcola il **diff posizione per
      posizione** e scrive una riga `registraSostituzione` per ogni cambio
      (override di configurazione sull'ULTIMA riga; caso "0 cambi ma
      configurazione cambiata" → riga no-op con esceId == entraId che
      porta solo gli override). Back a metà flusso = nessuna riga scritta.
    - **Undo atomico** (`gruppoCambio`, v12): i cambi confermati insieme
      condividono lo stesso `gruppoCambio` (timestamp ms del blocco) —
      `annullaUltimaAzione()` elimina l'INTERO gruppo se l'ultima riga è
      un cambio con gruppo (annullare solo metà di un doppio cambio non ha
      senso pallavolistico); il dialog di conferma undo avvisa "verranno
      annullati tutti i N cambi confermati insieme"
      (`contaGruppoCambio()`).
    - **Regole anti-duplicazione** (bug reale: stesso giocatore in due
      posizioni → ValueKey duplicate, crash a ogni rebuild): (1) in
      `SostituzioneScreen` gli USCITI pending restano in panchina ma
      disabilitati/grigi — chi esce non può rientrare in un'altra
      posizione, si annulla il suo cambio col ✕ (che a sua volta rifiuta
      se il titolare originale è rientrato altrove); (2)
      `_avviaSostituzione` rifiuta di scrivere se i sei finali hanno id
      duplicati; (3) `ricalcolaStato()` e `_computeRotazioni` rigiocano
      come no-op le righe che duplicherebbero (ripara retroattivamente
      anche i set già corrotti, senza toccare il DB).
    - **Derivazioni in ScoutScreen** (regola "valore effettivo vs
      widget."): `_rosterById` (roster stream fuso SOPRA
      `widget.assignments` — i subentrati partono dalla panchina e non
      sono nella formazione iniziale; il fallback copre i primi frame
      prima che lo stream emetta), `_currentSlot` via
      `stato.palleggiatoreId`, `_currentAssignments`/`_playerPerId` via
      `_rosterById`, `_ruoloCambiLiberoEffettivo`
      (`_statoSetReale?.ruoloCambiLibero ?? widget.ruoloCambiLibero`) al
      posto delle letture dirette di `widget.ruoloCambiLibero` — che resta
      solo in `_iniziaSet` (persiste il valore INIZIALE del set) e come
      fallback. `caricaFormazione()` NON è cambiata: ricostruisce la
      formazione iniziale, i cambi si riapplicano da soli col replay.
    - **Dettagli collegati**: flag undo `_fondamentaleGiudicatoRallyCorrente`
      richiede `tipo == scout` (un cambio ha esito `nessuno` ma non
      giudica nulla); banner/dialog undo con ramo "Cambio: esce N Cognome,
      entra N Cognome" (colore neutro `AppColors.brandPrimary`);
      `roleLabelsFor` gestisce un secondo palleggiatore in campo (gioca
      da opposto se la 'O' è libera, altrimenti da schiacciatore —
      euristica per il doppio cambio); `_computeRotazioni`
      (trajectory_report_screen) replica la regola del cambio nel suo
      replay duplicato, palleggiatore effettivo compreso.
    - **Cambio del LIBERO (IMPLEMENTATO, stesso flusso)**: vincolo di
      dominio confermato — un libero si cambia SOLO con un altro libero
      (infortunio o scelta tecnica), mai un ruolo diverso. In
      `SostituzioneScreen` le card L1/L2 stanno di fianco al campo
      (`_buildLiberoCard`, tap = chi esce, badge ✕ come le altre) e la
      panchina include anche i giocatori con ruolo libero: quando è
      selezionato un libero si abilitano SOLO i liberi, quando è
      selezionato un titolare i liberi sono disabilitati
      (`_panchinaVisibile.ruoloIncompatibile`). Il diff produce la stessa
      riga `cambioGiocatore` (nessuna colonna in più): `ricalcolaStato`
      riconosce dall'esceId che si tratta del libero e aggiorna
      `liberoId`/`libero2Id` invece della rotazione. In `ScoutScreen` i
      liberi si leggono da **`_liberiEffettivi`** (derivato da
      `StatoSet.liberoId`/`libero2Id` via `_rosterById`, fallback su
      `widget.assignments` per set non iniziato/modalità test/primi
      frame) — MAI più `widget.assignments['L1'/'L2']` direttamente,
      tranne che in `_statoSetReale` (valori INIZIALI passati al replay)
      e `_iniziaSet` (persistenza del valore iniziale).
  - [x] **Timeout per set** (`TipoAzione.timeout`, nessuna migrazione):
        bottoni blu con orologio per squadra sulla riga dei bottoni rapidi
        + pallini di stato nell'header — dettagli in "Interfaccia di scout"
        → "Bottoni timeout". Max 2 per squadra per set (bottone
        disabilitato al secondo), conteggio derivato dallo stream, undo e
        banner gratis dall'approccio log-eventi.
  - [x] Undo: bottone (icona `Icons.undo`) nella barra superiore di
        `ScoutScreen`, al posto del bottone "indietro" (spostato nel drawer
        di utilità, vedi "Interfaccia di scout" — libera quella posizione
        fissa e comoda per un'azione usata molto più spesso durante la
        presa dati). `_annullaUltimaAzione()` →
        `ScoutActionRepository.annullaUltimaAzione(setId)` elimina la riga
        con `ordine` massimo; punteggio/servizio/rotazione si ricalcolano da
        soli (derivati dagli eventi rimanenti). Disabilitato
        (`_puoAnnullare`) prima dell'inizio del set, in modalità test, o se
        il set non ha ancora azioni.
  - [x] Riprendi partita: `ScoutScreen.initState` →
        `_avviaOCaricaSet()` carica direttamente il `MatchSet` esistente con
        `MatchSetRepository.caricaSet(matchId, match.setCorrente)` se c'è
        già, senza richiedere di nuovo "Chi serve per primo?" (vedi Modello
        dati per i dettagli, inclusa la generalizzazione a "Prossimo Set").
  - [x] Bypass di `TeamSelectionScreen`/`LineupScreen`/`FormationConfigScreen`
        alla ripresa: `MatchesScreen._avviaOContinua()` (chiamata dal
        bottone "Inizia"/"Riprendi" di ogni card) controlla se il set
        corrente (`match.setCorrente`) ha già una formazione salvata
        (`MatchSetRepository.caricaSet` + `caricaFormazione`) — se sì,
        naviga direttamente a `ScoutScreen` con `team` (letto una volta da
        `TeamRepository.getTeam(match.teamId)`, non in streaming) e
        `assignments`/`palleggiatoreSlot`/`ruoloCambiLibero` ricostruiti dal
        DB (`Rotations` + le 3 nuove colonne su `MatchSet`, schema v8 — vedi
        Modello dati); se no (set nuovo, mai iniziato — `match.teamId` può
        essere ancora null), passa dal flusso normale
        (`TeamSelectionScreen` → `LineupScreen` → `FormationConfigScreen`)
        come prima. **Salta anche la selezione squadra**, non solo
        formazione: a quel punto la squadra è già fissata dalla `Rotation`
        persistita, selezionarne un'altra in `TeamSelectionScreen` creerebbe
        un'incoerenza con i giocatori già salvati — di conseguenza
        `TeamSelectionScreen` ora si raggiunge SOLO quando il set non ha
        ancora una formazione, e la sua vecchia logica di bypass (provata
        prima di scoprire che andava spostata più a monte) è stata rimossa
        perché irraggiungibile/duplicata. Risolve il limite noto della
        ripresa: prima si doveva riselezionare manualmente la stessa
        identica formazione perché `widget.assignments` veniva sempre dalla
        selezione appena fatta, non dalla `Rotation` persistita.
  - [x] Fine set / fine partita: voce "Fine" nel drawer di utilità di
        `ScoutScreen` (icona `Icons.flag`, sopra "Indietro" — push non pop,
        quindi nessun problema di local history entry del Drawer) apre
        `EndSetScreen` (`lib/screens/live/end_set_screen.dart`, NUOVA
        schermata dedicata, **non** dentro `ScoutScreen` — in Fase 4 potrà
        diventare la pagina delle statistiche del set, oggi resta un
        placeholder con AppBar (back automatico) e due bottoni centrali:
        - **"Prossimo Set"**: dialog di conferma → incrementa
          `VolleyMatch.setCorrente` (`MatchRepository.updateMatch`) → push di
          una `LineupScreen` **vuota** (nessuna formazione precompilata:
          deciso esplicitamente — in pallavolo si può cambiare
          rotazione/formazione tra un set e l'altro). Il punteggio del nuovo
          set è automaticamente 0-0: è un `MatchSet` con `id` diverso, niente
          logica di reset manuale (stesso principio event-sourced di
          sempre). Il vecchio stack (vecchia `LineupScreen`/
          `FormationConfigScreen`/`ScoutScreen`/`EndSetScreen`) resta sotto
          nello stack di navigazione invece di essere rimosso — scelta
          deliberata per semplicità (al massimo ~5 set a partita, crescita
          dello stack limitata e accettabile).
        - **"Fine Partita"**: dialog di conferma → `VolleyMatch.stato` a
          `terminata` → `Navigator.popUntil(context,
          ModalRoute.withName('/matches'))`, robusto a quante schermate si
          siano accumulate per i set precedenti. Richiede che la route di
          `MatchesScreen` sia nominata: `main.dart` ora passa
          `MaterialPageRoute(settings: RouteSettings(name: '/matches'), ...)`
          quando la apre da `HomeScreen`.
        - **Salvataggio dei punteggi (set vinti, punteggio finale)**: non
          ancora deciso, discussione rimandata — oggi "Fine Partita" si
          limita a cambiare `stato`, nessun dato di punteggio aggregato
          viene salvato.
  - [x] `MatchesScreen` a due sezioni in base a `StatoPartita`: "Da iniziare /
        in corso" (`configurazione`/`inCorso`/`sospesa`) e "Terminate"
        (`terminata`) — sezione nascosta se vuota, ordine cronologico
        invariato (`watchMatches()` ordina già per `dataOra` desc)
        all'interno di ciascuna. Stesso bottone (`onStart`), label/icona
        dinamiche in base a `match.stato` (`_MatchCard._labelBottone()`/
        `_iconaBottone()`): "Inizia" (`Icons.play_arrow`) se
        `configurazione` (mai cominciata), "Continua"
        (`Icons.play_circle_fill`) se `inCorso`/`sospesa` (set già aperto),
        "Riprendi" (`Icons.replay`) se `terminata` — stesso flusso in tutti
        i casi (`TeamSelectionScreen` → ... → `ScoutScreen`). Larghezza
        **fissa** (`SizedBox(width: 160)`): senza, il bottone si restringe
        per "Inizia" (più corta) rispetto a "Continua"/"Riprendi".
        **Riprendere una partita `terminata`**: voluto esplicitamente (es.
        per correggere un'azione dopo aver chiuso per errore) — quando
        `ScoutScreen._avviaOCaricaSet()` trova il set già esistente, se
        `match.stato != inCorso` lo riporta a `inCorso` (solo "Fine
        Partita" lo rimette a `terminata`): `terminata` deve sempre voler
        dire "scout non in corso ora", mai uno stato ibrido.
        **Bottone "Apri report"**: presente solo per le partite `terminata`
        (icona `Icons.bar_chart`, `OutlinedButton` accanto a "Riprendi") —
        apre `MatchReportScreen` (vedi Fase 4).
        **Punteggi/statistiche per il report**: nessuna nuova colonna
        necessaria — ogni `MatchSet` resta congelato con le sue
        `ScoutAction` una volta passati al set successivo, quindi il
        punteggio finale di ogni set (e il vincitore) si ricalcola in
        qualsiasi momento rigiocandole con `ricalcolaStato()`, esattamente
        come già avviene a runtime in `ScoutScreen`.

- **Fase 4 — Statistiche ed export PDF + condivisione** (IN CORSO)
  - [x] **`MatchReportScreen`** (`lib/screens/report/match_report_screen.dart`,
        raggiunta dal bottone "Report" in `MatchesScreen` — solo partite
        `terminata`). Pagina 1, scope deciso con lo sviluppatore (niente
        traiettorie né statistiche per giocatore per ora — si scout una sola
        squadra, non ancora entrambe):
        - **Dati partita**: nome nostra squadra (da `Team`, letto una volta
          via `TeamRepository.getTeam`) – nome avversario (o "Avversari" se
          non impostato, stessa convenzione di `ScoutScreen._matchTitle`);
          sotto, il **nome della gara** (`VolleyMatch.nome`, es. "Torneo
          estivo" — riga propria, sopra data/ora); poi data/ora, palestra se
          presente.
        - **Punteggio finale**: set vinti da ciascuna squadra (non punti
          totali) — confronto `nostro`/`avversario` per ogni set.
        - **Punteggio per set**: una riga per `MatchSet` (in ordine di
          `numero`) col punteggio finale di quel set.
        - **`MatchSetRepository.caricaSetsPartita(matchId)`**: tutti i
          `MatchSet` di una partita, ordinati per `numero`.
        - **`MatchSetRepository.calcolaStatoFinale(set)`**: stesso pattern di
          `ScoutScreen._statoSetReale` ma come query one-shot (non stream) —
          legge `Rotations` (per la rotazione iniziale, necessaria a
          `ricalcolaStato()` per non lanciare un null-check su un sideout,
          anche se il report non usa il campo `rotazione` del risultato) e
          `ScoutActions` del set, richiama la funzione pura. **Non include**
          la correzione manuale del punteggio — il chiamante (la schermata)
          deve sommare `correzionePuntiNostri`/`correzionePuntiAvversari` a
          parte, esattamente come fa `ScoutScreen._punteggioNostro`/
          `_punteggioAvversario` (dettaglio facile da dimenticare, visto che
          la correzione vive fuori dal log eventi — vedi sopra).
  - [x] **Riepilogo fondamentali** (sotto "Punteggio per set" in
        `MatchReportScreen`, stesso stile tabella di `PlayerStatsScreen` —
        `Table`/`TableRow`, header `AppColors.surfaceDim`, righe alternate
        bianco/`AppColors.surface`, voto colorato con
        `CourtStyle.votoColor()`). A differenza del riepilogo per
        giocatore, qui le righe sono **fondamentali** (non giocatori), in
        ordine fisso: Battuta, Ricezione, Difesa, Attacco, Attacco su
        ricezione, Attacco su Difesa, Muro, Alzata — colonne = 5 `Voto` +
        "TOT". Selettore "Set" (`DropdownButtonFormField<int?>` — "Partita
        intera" di default, o un set specifico) sopra la tabella, stesso
        pattern di `PlayerStatsScreen`: `MatchReportScreen` è diventata
        `ConsumerStatefulWidget` per questo (prima era `ConsumerWidget` con
        `FutureBuilder` one-shot — i dati ora si caricano una volta in
        `initState`/`_carica()` e si ricalcolano solo in memoria ad ogni
        cambio di selettore, stesso schema di `PlayerStatsScreen`).
        - **"Attacco" è il totale di tutti gli attacchi** (`fondamentale ==
          attacco`, senza condizioni). **"Attacco su ricezione"/"Attacco su
          Difesa" sono una partizione binaria dedotta**, non un campo
          salvato — ragionamento per **fasi**, non per fondamentale (scelta
          esplicita dello sviluppatore dopo aver verificato che il
          conteggio per "ultimo fondamentale tra ricezione/difesa
          incontrato" lasciava alcuni attacchi non classificati, es. dopo
          una nostra battuta senza una difesa esplicitamente registrata sul
          rinvio avversario — la somma dei due sottogruppi non tornava
          uguale al totale). Regola attuale: **"su ricezione" è sempre il
          primo attacco dopo un voto di ricezione nello stesso scambio**
          (`rallyId`, scoped al set — `ultimoTipo` resettato a `null` ad
          ogni cambio di `rallyId`); **tutti gli altri attacchi** (dopo una
          difesa, dopo un altro attacco nello stesso scambio, o senza alcun
          contesto registrato) **finiscono in "su Difesa"** — partizione
          binaria, quindi la somma dei due torna sempre uguale al totale
          "Attacco". `ultimoTipo` traccia ancora `difesa` (serve comunque
          al conteggio della riga "Difesa" a sé stante), ma per la
          classifica dell'attacco conta solo se l'ultimo è `ricezione` o no.
        - **Nessuna riga "Totale" in fondo** (a differenza di
          `PlayerStatsScreen`): qui ogni riga è già un aggregato per
          fondamentale, sommare le righe tra loro (battuta + ricezione +
          attacco + ...) non avrebbe un significato utile.
  - [x] **Bug corretto: `teamId` perso a fine partita**. Testando il report
        su una partita giocata per intero (non solo "TEST RIPRESA", risalente
        a prima di questa fase), il titolo mostrava il placeholder "Nostra
        squadra" invece del nome reale, nonostante la squadra fosse stata
        selezionata normalmente. Causa:
        `TeamSelectionScreen._onTeamSelected` salvava `teamId` su DB ma
        passava avanti a `LineupScreen` il **vecchio** oggetto `match` (con
        `teamId` ancora `null` in memoria) — `LineupScreen`,
        `FormationConfigScreen`, `ScoutScreen` ed `EndSetScreen` si limitano
        a passarsi `widget.match` di mano in mano senza ricaricarlo dal DB,
        quindi ogni `updateMatch(match.copyWith(...))` successivo (in
        `ScoutScreen._iniziaSet()` per `stato: inCorso`, in
        `EndSetScreen._finePartita()`/`_prossimoSet()`) faceva un
        `replace()` dell'intera riga usando quel `match` ancora con `teamId:
        null` — sovrascrivendo il valore appena salvato. **Fix**:
        `_onTeamSelected` ora costruisce `aggiornato =
        match.copyWith(teamId: Value(team.id))` e lo passa a `LineupScreen`
        invece del `match` originale — da lì in avanti ogni `copyWith` parte
        da un oggetto con `teamId` già corretto, quindi resta corretto per
        tutta la catena (anche su più set con "Prossimo Set").
        **Recupero per le partite già giocate prima del fix** (rimaste con
        `teamId == null` per sempre, dato che il dato corretto non è più
        nel DB): `MatchSetRepository.inferisciSquadraDaRotazioni(matchId)`
        risale a un `giocatoreId` da una qualunque `Rotation` già
        persistita per quella partita e da lì al suo `Team` — usata da
        `MatchReportScreen._carica` come fallback solo se `team` risulta
        `null` dopo il lookup diretto su `teamId`. Funziona solo se è stato
        confermato almeno un set (altrimenti nessuna `Rotation` esiste);
        non riscrive `VolleyMatch.teamId`, serve solo a visualizzare il
        nome corretto nel report.
  - [x] **Statistiche per giocatore/fondamentale** — non solo a fine
        partita: deve essere consultabile **anche durante una partita in
        corso** — **IMPLEMENTATO**: `PlayerStatsScreen`
        (`lib/screens/report/player_stats_screen.dart`), raggiunta da una
        nuova voce "Statistiche" (icona `Icons.bar_chart`) nel drawer di
        utilità di `ScoutScreen` (sopra il divider di "Modalità test"), e
        riusabile in futuro anche da `MatchesScreen` per le partite
        terminate (oggi raggiunta solo dallo scout live). Schermata
        `ConsumerStatefulWidget`: carica **una volta** (one-shot, niente
        stream) tutti i `MatchSet` della partita + le `ScoutAction` di
        ciascuno + il roster squadra, poi ogni cambio di selettore
        ricalcola solo in memoria (`_righe` filtra/raggruppa senza nuove
        query) — adatto sia a una partita terminata (tutti i set congelati)
        sia in corso (i dati si rileggono da capo ogni volta che si riapre
        la pagina, nessun bisogno di uno stream live dato che non si può
        scoutare e guardare le statistiche contemporaneamente).
        - **Due selettori** in alto: "Set" (`DropdownButtonFormField<int?>`
          — opzioni "Partita intera" (`null`) + un set per ogni `MatchSet`
          esistente, **default l'ultimo** — il set corrente se la partita è
          in corso) e "Fondamentale" (`DropdownButtonFormField<Fondamentale>`
          — tutti tranne `errore`, **default battuta**).
        - **Tabella**: una riga per giocatore che ha registrato almeno un
          voto nel fondamentale/set selezionato (righe senza voti
          nascoste); colonne = numero+cognome+ruolo, poi una colonna per
          ciascuno dei 5 `Voto` (simbolo, colorata con
          `CourtStyle.votoColor()` per coerenza col resto dell'app — non i
          colori arancioni di un mockup di riferimento), conteggio +
          percentuale sul totale del giocatore, poi "Tot." (somma).
          Costruita con `Table`/`TableRow` (non `DataTable`, per controllo
          pieno su righe a due linee per cella) con righe a colori
          alternati (`Colors.white`/`AppColors.surface`) e header
          `AppColors.surfaceDim`.
        - **`TeamRepository.getPlayersForTeam`** e
          **`ScoutActionRepository.caricaAzioni`**: equivalenti one-shot
          (non stream) di `watchPlayersForTeam`/`watchAzioni`, aggiunti per
          questo caricamento one-shot.
        - **Filtro attacchi** (solo con fondamentale Attacco): terzo
          dropdown "Attacchi" — Tutti (default)/Su ricezione/Su difesa,
          si resetta cambiando fondamentale. Classificazione =
          `idAttacchiSuRicezione()` (helper condiviso in
          database_provider.dart): "su ricezione" è l'attacco che segue un
          voto di ricezione nello stesso scambio (`rallyId`, scope per
          set), tutto il resto "su difesa" — STESSA regola del riepilogo
          fondamentali di `MatchReportScreen` (che per ora tiene il suo
          loop interno: tenere allineati).
        - **Colonna "Murati"** (solo Attacco, tra `=` e TOT, colore
          neutro): attacchi con muro punto subito — `attaccoMurato()`
          (helper condiviso): voto `=` + tocco a muro registrato + palla
          tornata nel campo dell'attaccante (arrivo dallo stesso lato
          della rete della partenza). Deducibile SOLO con la traiettoria
          disegnata; senza, resta un normale errore.
  - [x] **Traiettorie battute/attacco** (`lib/screens/report/trajectory_report_screen.dart`,
        `TrajectoryReportScreen` parametrizzata su `fondamentale: Fondamentale`):
        raggiunta da due voci del drawer di `ScoutScreen` — "Traiettorie battute"
        (`Icons.arrow_forward`) e "Traiettorie attacco" (`Icons.trending_up`).
        Stessa schermata parametrizzata per entrambi: stesso layout di
        `TrajectoryScreen` (58% larghezza, `double_court_bg.png`, margine top 16).
        - **Filtri**: set (default set corrente) + giocatore (lista dinamica —
          solo chi ha azioni nel fondamentale per il set/rotazione selezionati,
          con auto-reset al cambio di filtro tramite `_validaFiltri()` che usa
          `_giocatoriFiltrati` già aggiornato per evitare eccezioni dropdown).
          Per l'attacco: filtro rotazione aggiuntivo ("Tutte le rotazioni" /
          "Rotazione P1".."Rotazione P6" — slot del palleggiatore al momento
          dell'azione).
        - **Normalizzazione direzione**: traiettorie sempre sx→dx (x1 > 0.5 →
          mirror attorno al centro: x'=1−x, y'=1−y — applicato anche a
          `traiettoriaMuroX/Y` se presente).
        - **Colori frecce**: `CourtStyle.trajectoryAce` (verde brillante,
          `0xFF00FF08`) per voto `perfetto`; rosso per `errore`; bianco per
          il resto (in campo) — tutte alpha 220.
        - **Rendering traiettoria** (`_MultiTrajectoryPainter`): tre casi in
          ordine di priorità — (1) **tocco a muro** (`traiettoriaMuroX/Y` non
          null): due segmenti dritti con pallino sullo snodo, freccia nella
          direzione `fine−muro`; (2) **pallonetto** (`tipoEsecuzione ==
          'pallonetto'`): arco bezier quadratica, punto di controllo = punto
          medio alzato di `_kPallonettoArcOffset = 40px`, freccia nella
          tangente `fine−ctrl`; (3) **linea retta** per tutto il resto.
        - **Mini-tabella** sotto al campo: celle con sfondo solido (verde
          `AppColors.success` / grigio / rosso), testo bianco. Label:
          "Ace  #"/"Punto  #" (battuta/attacco), "In campo", "Errore  =" +
          riga totale con conteggio "con traiettoria".
        - **`_computeRotazioni()`** (solo attacco): per ogni set carica
          `caricaFormazione(setId)` per ottenere la rotazione iniziale e
          l'id del palleggiatore; scorre le azioni in ordine O(n) tracciando
          la rotazione corrente con la stessa logica di `_ruotata` di
          `ricalcola_stato.dart` (replicata file-privata); registra lo slot
          del palleggiatore per ogni azione di attacco PRIMA di applicare
          l'esito — risultato: `Map<int, String>` actionId→slotLabel.
  - [x] **Partita demo per lo sviluppo del report** (`assets/demo/
        demo_match.json` + `lib/data/demo_match_importer.dart` + bottone
        `Icons.science` nell'AppBar di `MatchesScreen`, SOLO `kDebugMode`):
        partita REALE (Clai Imola - Nettunia 30/04/2026, persa 2-3:
        25-16, 15-25, 21-25, 25-16, 25-23) convertita una tantum
        dall'export xlsx dell'app "Volleyball Scout" (log azione per
        azione; il PDF della stessa app, in `G:\My Drive\_Volley\Partite\
        2026-3-div\2026_04_30_Clai_Nettunia`, è il RIFERIMENTO per le
        prossime iterazioni del report). Dettagli di conversione:
        - Esiti derivati dai delta del punteggio riga per riga del loro log
          (ground truth), non da `_esitoVoto()`; punti senza azione
          scoutata → righe `puntoManuale`. Punteggi validati da
          `test/logic/demo_match_test.dart` (replay con `ricalcolaStato()`
          == referto, tutti e 5 i set).
        - Rotazione iniziale derivata dall'ORDINE DEI BATTITORI (chi batte
          è sempre in P1; la colonna "posizione giocatore" dell'export è
          la ZONA dell'azione, NON lo slot di rotazione — trappola).
          Palleggiatori reali: Millo (set 1-3, 5), Camprini (set 4).
          Cambi a set in corso NON ricostruiti (non derivabili in modo
          affidabile); liberi Corradi/Cerrè su `ruoloCambiLibero:
          centrale` (convenzione). Un sideout di scarto nel set 2
          (correzione manuale del loro scoutman) — accettato.
        - Traiettorie sintetiche plausibili (seed fisso) per battute e
          attacchi: l'export non le contiene.
        - Import idempotente: ricrea la partita (stesso nome), riusa
          squadra "Nettunia (demo)" e giocatori per numero di maglia.
  - [x] **Report a video completato** (`MatchReportScreen`, tutte le sezioni
        dentro `Card` arrotondate con ombra):
    - Punteggio finale con **pallini esito** 14×14 accanto ai nomi (verde
      vinto/rosso perso, `_pallinoEsito` riusato dalla tabella set) e
      punteggio per set con **durata** (prima→ultima azione) + riga Totale.
    - **Bottoni "Traiettorie battute"/"Traiettorie attacco"** → aprono
      `TrajectoryReportScreen`; nuovo parametro `setCorrenteAllAvvio`
      (default `true` per il drawer live; `false` dal report = si entra su
      "Partita intera"). Mostrati solo se `_team != null`.
    - **Punti/errori generici**: tabella 2 colonne (nomi squadre reali come
      header, fallback "Avversari") per `puntoManuale`/`erroreGenerico` +
      chip "Tipologia errori avversari" per `MotivoErrore` (letto da
      `tipoEsecuzione`, valori sconosciuti → generico). Segue il selettore
      Set del riepilogo fondamentali, ignora quello Giocatore (i generici
      non hanno giocatore).
    - **Formazioni di partenza per set**: 3 card per riga (`LayoutBuilder`,
      `(maxWidth − 2×16)/3`), ognuna con `CourtView` renderizzato a 460 e
      scalato via `FittedBox` (i margini interni fissi di CourtView non
      reggono un SizedBox più piccolo), titolo "Set N - P<slot>" + icona
      pallone a destra SOLO se la battuta iniziale era nostra, bordo rosso
      sul palleggiatore (`selectedSlots`), didascalia libero/i. Dati da
      `caricaFormazione(setId)` (caricate in `_carica`).
    - **Distribuzione alzate**: campo singolo largo come una card
      formazione, allineato a sinistra — `CourtView` col nuovo parametro
      `slotContent` (contenuto custom per slot, stessa geometria delle card
      giocatore): % grande (fontSize 31) + conteggio (17) per zona P1–P6.
      Zona = posizione TATTICA dell'attaccante al momento dell'azione —
      STESSA definizione delle pagine attacchi del PDF
      (`MatchSetRepository.zonaTatticaPerAzione`, mappa calcolata una
      volta in `_carica`), NON la zona di rotazione (era la logica
      iniziale, corretta su richiesta dell'utente: "è quella corretta").
      Attacchi con zona non ricostruibile esclusi dal conteggio.
      Selettore Set proprio (`_setDistribuzione`).
    - **Efficienza battuta/attacco** (2 card) e **Positività** (3 card:
      positività ricezione, errore ricezione, positività difesa): formule
      `(# − =)/tot×100` (può essere negativa: verde/rosso/grigio per segno),
      `(# + +)/tot×100`, `(=)/tot×100` — mostrate in piccolo sotto i titoli
      (`_kFormulaStyle`); "—" con totale 0 (mai divisione per zero).
      Selettori Set+Giocatore propri per ciascuna sezione
      (`_setEfficienza`/`_giocatoreEfficienza`,
      `_setPositivita`/`_giocatorePositivita`). Helper condiviso
      `_buildPercentCard`; scope set generalizzato in
      `_listeAzioniPerSet(int? setNumero)`.
  - [x] **Widget `CourtTrajectoriesView` estratto**
        (`lib/widgets/court_trajectories_view.dart`): campo doppio +
        traiettorie già filtrate + footer opzionale — widget puro senza
        filtri/Scaffold, con `TrajData`/`buildTrajData`/`MultiTrajectoryPainter`
        pubblici (ex privati di `trajectory_report_screen`, che ora lo usa).
        Estratto in vista del PDF: verrà catturato in PNG per giocatore.
  - [x] **Export PDF, condivisione — COMPLETO**.
        Deciso con lo sviluppatore: bottone "PDF" (`Icons.picture_as_pdf`)
        sulla card delle partite `terminata` in `MatchesScreen` →
        `MatchPdfScreen` con **`PdfPreview`** (package `printing`):
        anteprima sfogliabile + condividi/stampa integrati (schermate di
        sistema, si esce col back di sistema). Generazione **on-demand**
        nella callback `build` — NIENTE file persistito né auto-generazione
        a fine partita (scartata: PDF sempre aggiornato anche dopo una
        ripresa, nessuna gestione file, layout nuovi validi per partite
        vecchie; il file nasce solo alla condivisione). **A4 landscape
        fisso** (`initialPageFormat`, cambio formato disabilitato — deciso
        per i contenuti futuri, campi più larghi che alti). Font Barlow
        dagli asset; header su ogni pagina (logo
        `assets/icon/icon_foreground.png` — cartella aggiunta agli asset
        runtime — + "Pag. X/Y"); pallini esito come a video (colonna
        "Esito" nella tabella set, pallini accanto ai nomi nel punteggio
        finale; riga Totale segue i SET vinti). Una funzione `pw.*` per
        sezione (`_buildIntestazione`/`_buildPunteggioFinale`/
        `_buildTabellaSet`): i prossimi pezzi si aggiungono lì.
    - **Mega tabella statistiche giocatori** (layout dal foglio Google
      Sheets dell'utente, CSV di riferimento in `assets/demo/`): pagina
      "Partita intera" + UNA PAGINA PER OGNI SET giocato
      (`_buildPaginaStatistiche`, scope parametrico). 34 colonne in gruppi
      colorati (palette del foglio): GIOCATORE (#/Nome troncato/R),
      BATTUTA e ATTACCO (TOT/PT/ER[/MURI]/EF%), ATT. SU RIC./ATT. SU DIF.
      (partizione via `idAttacchiSuRicezione`), RICEZIONE e DIFESA
      (TOT/++/ER/EF%/POS% — `++` = solo voti `#`), MURO (TOT/PT), PT-ERR
      (punti `#` di battuta+attacco+muro; errori `=` dei 5 gruppi, alzata
      esclusa). Formule = card del report a video: EF% `(#−=)/tot`, POS%
      `(#++)/tot`, percentuali INTERE col segno, "—" con tot 0. Riga
      TOTALI gialla. **Larghezze fisse per tipo di colonna** (~790pt su
      ~802 utili, margine pagina 20) + font 8; la riga dei gruppi è una
      Row separata (pw.Table NON ha colspan) con le stesse larghezze —
      richiede **`tableWidth: TableWidth.min`** sulla Table (il default
      `max` stira le colonne oltre le FixedColumnWidth e la riga gruppi si
      disallinea, bug reale corretto). Sotto: specchietto punti/errori
      generici + tipologia errori avversari (`_buildGenerici`).
    - **Pagine "Battute <squadra>"**: un campo per ogni giocatore che ha
      battuto (3 per riga, righe atomiche — MultiPage spezza tra le
      righe), titolo numero+cognome, legenda Ace/In/Err (verde/grigio/
      rosso, font 8). Campo doppio B/N **vettoriale** (`pw.CustomPaint`,
      NON cattura PNG di CourtTrajectoriesView come ipotizzato prima:
      nitido a ogni zoom e adatto alla stampa — `_campoTraiettoriePdf`,
      bordo+linee 3m grigie, rete marcata, padding attorno per il
      battitore fuori campo). Traiettorie normalizzate sx→dx; colori di
      STAMPA: verde ace `0xFF16A34A`, rosso errore, NERO in campo (a video
      è bianco, invisibile su carta). Painter con i 3 casi del
      MultiTrajectoryPainter: retta, tocco a muro (2 segmenti + snodo),
      pallonetto (bezier quadratica→cubica per curveTo).
    - **Pagine "Attacchi <squadra>"**: un campo per OGNI COPPIA giocatore
      + POSIZIONE TATTICA di attacco (titolo "N Cognome — P4"): se uno ha
      attaccato da zona 2 e da zona 4, i campi sono due. La posizione è
      quella in cui il giocatore era SCHIERATO al momento dell'azione
      secondo le tabelle di `logic/attack_positions.dart` (estratte da
      scout_screen: le stesse che posizionano i token) — NON la zona di
      rotazione (uno S di prima linea attacca quasi sempre da zona 4) e
      NON il punto di partenza della traiettoria (entrambe scartate con
      l'utente). `MatchSetRepository.zonaTatticaPerAzione` (condiviso
      con la distribuzione alzate del report a video, che usa la STESSA
      definizione): replay per set (rotazione+
      palleggiatore+ruoloCambiLibero effettivi, guardie di
      ricalcolaStato) + `roleLabelsFor` + fase dopo-battuta/dopo-ricezione
      in base a chi serviva + `attackMapFor()` → `zonaDaPosizione()`
      (prima linea 4/3/2, seconda 5/6/1). Zona non ricostruibile → campo
      del giocatore senza etichetta, in coda. Legenda Pt/In/Err. Cella
      condivisa con le battute (`_cellaTraiettorie`).
    - **Pagina "Formazioni di partenza"**: un campo QUADRATO vettoriale
      B/N per set (rete in alto, P1 in basso a destra, 3 per riga), card
      giocatore con cognome e nome su DUE righe, numero grande, ruolo;
      palleggiatore bordato rosso; pallone vettoriale accanto al titolo
      "Set N - P<slot>" se la battuta iniziale era nostra; didascalia
      libero/i. ATTENZIONE: `pw.Spacer`/flex dentro una Row a larghezza
      illimitata lancia "PdfException: flex children" — serve un SizedBox
      con larghezza esplicita (bug reale corretto).
    - **Pagina "Distribuzione alzate — partita intera"** (ultima): 6 campi
      quadrati per ROTAZIONE P1–P6 (posizione del palleggiatore), in ogni
      zona etichetta Ric/Dif sopra due chip — nera testo bianco = dopo
      ricezione, bianca bordata = dopo difesa — con % grande (11pt bold) +
      conteggio. Percentuali PER FASE dentro la rotazione (K1/K2: le sei
      zone di una fase sommano a 100), "0%" a fase vuota (non "—").
      `zonaTatticaPerAzione` ritorna `(zona, rotazione)` per questo. Nel
      report a video la distribuzione alzate ha il filtro gemello
      "Alzate": Tutte/Su ricezione/Su difesa (`_FiltroAlzate`).
  - [x] **Export CSV azioni partita** (`lib/data/match_csv_exporter.dart`,
        package `csv` + `share_plus`): bottone "CSV" (`Icons.table_view`)
        sulla card delle partite `terminata` in `MatchesScreen`, accanto a
        "PDF" — futura feature premium, per ora sempre visibile (il gating
        arriverà col meccanismo premium, come per il toggle traiettorie).
        Una riga per `ScoutAction`, set per set: colonne "parlanti" (nomi
        giocatori/squadre e label degli enum via join in memoria, mai ID;
        `tipoEsecuzione` risolto con l'enum giusto per contesto —
        TipoBattuta/TipoAttacco/MotivoErrore), punteggio progressivo del
        set derivato contando gli `esitoPunto` (correzioni manuali escluse,
        vivono fuori dal log). Punteggio ed esito in convenzione **referto
        ufficiale Casa/Trasferta** ("Punti casa"/"Punti trasferta", "Punto
        casa"/"Punto trasferta" — lato dato da `match.inCasa`): intestazioni
        fisse tra un file e l'altro, comode per fogli-modello; la colonna
        Squadra coi nomi reali scioglie l'ambiguità su chi era in casa. Compatibilità Excel italiano: separatore
        `;`, decimali con la VIRGOLA (col punto diventerebbero testo),
        **BOM UTF-8** in testa (senza, Excel storpia gli accenti). File
        on-demand in `getTemporaryDirectory()` + `SharePlus.instance.share`
        (niente file persistiti, stesso principio del PDF). Funzione pura
        `righeCsvPartita()` testata in `test/logic/match_csv_test.dart`;
        caricamento dati one-shot in `MatchesScreen._esportaCsv` (stesso
        pattern di `MatchPdfScreen`, incluso il fallback
        `inferisciSquadraDaRotazioni` per le partite pre-fix del teamId).
        **Trappole share_plus risolte** (il file arrivava a Drive senza
        nome/estensione e Sheets rifiutava l'import): (1) `fileNameOverrides`
        è IGNORATO con un XFile creato da path (`if (file.path.isNotEmpty)
        return file;` nel package) — serve `XFile.fromData(bytes)`;
        (2) "Salva su Drive" usa `EXTRA_SUBJECT` come titolo del documento
        al posto del display name → il `subject` DEVE essere il nome file
        completo di estensione, non un titolo libero.

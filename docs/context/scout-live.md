## Flusso dell'app (navigazione)

- **HomeScreen**: layout landscape con area principale a sinistra (vuota per ora)
  e colonna di bottoni a destra: "Setup squadre" e "Gestione partite" centrati
  (tra due `Spacer` simmetrici) + "Impostazioni" in fondo, staccata — apre
  `SettingsScreen` (vedi sezione Impostazioni).
- **Flusso scout** (navigabile end-to-end fino al setup grafico di `ScoutScreen`):
  `MatchesScreen` → [Inizia/Riprendi] → `TeamSelectionScreen` → [Seleziona] → `LineupScreen` → [Conferma formazione] → `FormationConfigScreen` → [Inizia scout] → `ScoutScreen` → [drawer "Fine"] → `EndSetScreen` → [Prossimo Set] → `LineupScreen` (da capo, set successivo) **oppure** [Fine Partita] → `MatchesScreen`
  - **Bypass alla ripresa**: se il set corrente ha già una formazione salvata
    (`MatchSetRepository.caricaFormazione`, vedi Modello dati),
    `MatchesScreen` salta direttamente a `ScoutScreen` — niente
    `TeamSelectionScreen`/`LineupScreen`/`FormationConfigScreen` — con la
    squadra e la formazione ricostruite dal DB. Vale per qualunque
    `StatoPartita` tranne `configurazione` (set mai iniziato, nessuna
    `Rotation` da cui ricostruire).
  - Il `teamId` viene salvato sulla partita nel DB al momento della selezione squadra.
  - Da `TeamSelectionScreen` si può creare una squadra al volo; la lista si aggiorna
    automaticamente via stream al ritorno.
  - `LineupScreen`: layout landscape con sfondo blu scuro; sinistra = campo fisso
    **460×460dp** (era stato ingrandito a 520×520 dopo un test su tablet
    fisico per card troppo piccole, poi **riportato a 460×460** — stessa
    dimensione del campo di `FormationConfigScreen` — perché a 520 col
    libero sotto l'altezza totale sbordava su schermi più bassi) con sfondo
    da PNG asset (`assets/images/court_bg.png`, dichiarato in
    `pubspec.yaml`) — le linee del campo sono nell'immagine, non più
    disegnate a codice. Griglia 3×2 sovrapposta (P1–P6 in senso antiorario),
    card ~140×140 (margini `EdgeInsets.fromLTRB(16, 12, 16, 108)`, ancora
    asimmetrici/vicine al top della cella) + slot libero **di fianco a
    destra** del campo, non più sotto (`_buildLiberoColumn`, `Row` invece di
    `Column` in `_buildCourtSection` — stessa motivazione: l'altezza totale
    ora è quella del solo campo, non campo+libero). **Stessa dimensione
    esatta di una cella della griglia** (460/3 × 460/2, stesso margine di
    default di `_buildSlot`) — non più una misura "circa uguale" (152×152
    con margine diverso): card libero pixel-identica alle card P. **Ancorato
    in basso** (`Column(mainAxisAlignment: MainAxisAlignment.end)` +
    `crossAxisAlignment: CrossAxisAlignment.end` sulla `Row` esterna)
    invece che centrato verticalmente sull'intero campo — così si allinea
    con la riga di fondo (P5-P6-P1, la rete è in alto). L1, opzionalmente
    L2 con checkbox "Doppio libero" impilati verticalmente sopra L1.
    Colonna sinistra centrata e scrollabile (`SingleChildScrollView`) per evitare
    overflow su schermi piccoli. Destra = lista giocatori della squadra (grayed
    out + ✓ quando assegnati, "Aggiungi" per crearne uno al volo). Slot
    selezionato = bordo rosso; slot vuoto = sfondo `Colors.lightBlueAccent` per
    distinguerlo a colpo d'occhio dallo slot occupato (bianco pieno). Card
    giocatore: numero centrato (font 36) con nome/cognome ancorati in alto e
    ruolo ancorato in basso (stesso font, 16px, `height: 1.1` per interlinea
    compatta) — layout realizzato con `Stack` interno e `Positioned top/bottom`
    per garantire che il numero resti sempre centrato. Badge "✕" nero circolare
    a cavallo dell'angolo
    in alto a destra di ogni slot occupato (tap → rimuove il giocatore e
    riseleziona quello slot); vedi convenzione n.8 sul perché va in
    `Positioned.fill` insieme alla card e non come `Stack` annidato semplice.
    Tap giocatore (lista a destra) → assegna al posto selezionato e avanza
    automaticamente al prossimo vuoto in senso antiorario. Tap su giocatore già
    assegnato (lista o badge ✕) → deassegna. "Conferma formazione" abilitato
    solo quando P1–P6 sono tutti riempiti. La formazione è in memoria (non
    ancora persistita a DB).
    Icona matita (`Icons.edit`) nel `trailing` della lista, **visibile solo
    se il giocatore non è assegnato**: apre `PlayerFormScreen` per
    modificarlo. Un giocatore già in formazione non è modificabile finché
    non viene rimosso dallo slot — evita che la card sul campo mostri dati
    superati (l'oggetto `Player` in `_assignments` non si aggiorna da solo
    quando lo stream rilegge i dati modificati).
    Lista giocatori a destra: card arrotondate (`Material` + `ListTile`,
    `BorderRadius.circular(AppRadius.md)`, separate da `SizedBox(height: 8)`
    invece di `Divider`) su sfondo `_kBg` (stesso blu scuro della pagina) —
    bianca se disponibile, `Colors.grey.shade300` se già assegnato.
    **Ingrandita dopo test su tablet fisico** (testo/avatar troppo piccoli su
    schermo reale, più passaggi): `ListTile` senza `dense`, `contentPadding`
    orizzontale 14/verticale 8 (era 12/0 con `dense: true` +
    `VisualDensity(vertical: -4)`), avatar raggio 24 (era 18) con numero
    **20px** (era 13), nome/cognome **20px** bold (era stile default tema),
    ruolo **16px** (era default), icona matita 24 (era 20), icona ✓/chevron
    finale 28 (era default ~24). Avatar
    col **colore squadra raw** (`Color(team.coloreDivisa)`, niente
    scurimento); se assegnato, stesso colore con opacità ridotta
    (`withAlpha(120)`) invece di un grigio slegato. **Libero** (`Ruolo.libero`):
    avatar col colore **invertito canale per canale** (`_invertedColor()` —
    `1.0 - r/g/b` sulla nuova API `Color.from()`), per richiamare la maglia
    di colore diverso che il libero indossa sempre in pallavolo; stessa
    funzione duplicata in `scout_screen.dart` per coerenza tra le due pagine.
  - `FormationConfigScreen` (riceve `match`, `team`, `assignments` da
    `LineupScreen`): sfondo blu scuro (`0xFF0F172A`, stesso di `LineupScreen`).
    AppBar: titolo "Configurazione formazione – [nome squadra]" + bottone
    "Inizia scout" (abilitato solo a selezione completa) nelle `actions`.
    Sotto l'AppBar, riga "Sistema di gioco:" con `DropdownButton<SistemaGioco>`
    (per ora solo `palleggiatoreUnico` ha logica). Corpo: uno o due campi
    affiancati a **dimensione fissa 460×460dp** (stesso PNG/stile di
    `LineupScreen`), centrati con il pattern `ConstrainedBox(minWidth: ...) +
    Center` dentro `SingleChildScrollView(Axis.horizontal)` (centra quando
    c'è spazio, scrolla altrimenti).
    - **Campo sinistro — Palleggiatore**: pre-selezionato in `initState`
      cercando il giocatore con `Ruolo.palleggiatore` negli `assignments`.
      Tap su uno slot occupato lo seleziona/deseleziona; bordo rosso
      (`Colors.red`) quando selezionato. Subtitle statico "Conferma il
      palleggiatore".
    - **Campo destro — Cambi del libero**: visibile **solo se la formazione
      ha un libero** (`assignments` contiene `L1` o `L2` — getter
      `_hasLibero`); se non c'è libero la pagina mostra solo il campo
      sinistro. Pre-selezionati in `initState` i giocatori con
      `Ruolo.centrale` (max 2). Regola pallavolistica implementata: il libero
      sostituisce **o i due centrali o i due schiacciatori**, mai una
      combinazione — tap su un giocatore seleziona automaticamente l'intera
      coppia del suo ruolo (`Ruolo.centrale` o `Ruolo.schiacciatore`),
      deselezionando l'altra coppia; tap sulla coppia già selezionata la
      deseleziona. Slot non centrale/schiacciatore (es. opposto) e lo slot
      già usato come palleggiatore sono disabilitati (`disabledSlots`,
      sfondo grigio, non tappabili). Bordo blu scuro (`0xFF00008A`) quando
      selezionato; subtitle "Conferma i due cambi del libero – X/2
      selezionati" (colore `Colors.lightBlue` a selezione completa).
    - "Inizia scout" abilitato quando: palleggiatore selezionato **e** (nessun
      libero in formazione **oppure** 2 cambi del libero selezionati). Al tap
      naviga a `ScoutScreen` passando anche `palleggiatoreSlot: _palleggiatoreSlot!`
      e `assignments: widget.assignments` (usati per il badge di rotazione e
      le etichette di ruolo dei token giocatore — vedi sezione "Interfaccia
      di scout").
- **`ScoutScreen`**: setup **solo grafico** per ora (Fase 3, vedi sezione
  dedicata sotto) — riceve `match` + `team` + `palleggiatoreSlot` +
  `assignments`, nessuna logica di scouting ancora implementata.

---

## Interfaccia di scout (Fase 3)

### Setup grafico `ScoutScreen` (IMPLEMENTATO)

- Sfondo schermo: `Color(0xFF143E59)`.
- Barra superiore fissa: `Container` alto 60dp, colore `Color(0xFF0D2738)`,
  `Stack` con due livelli: sotto il titolo partita (centrato, vedi `_matchTitle`
  sotto), sopra una `Row` con bottone "menu" (`Icons.menu`, apre il drawer di
  utilità) a **sinistra** e bottone "annulla" (`Icons.undo`,
  `_annullaUltimaAzione`) a **destra** (non centrato come un'AppBar standard —
  scelta deliberata per ergonomia in landscape). `Stack(alignment:
  Alignment.bottomCenter)`: sia il titolo sia la riga di icone sono ancorati
  vicino al **bordo inferiore** della barra, non centrati verticalmente.
  - **Bottone "indietro" spostato nel drawer di utilità** (voce "Indietro",
    vedi sotto): quella posizione fissa a destra è usata molto più spesso
    dall'undo durante la presa dati che dal back (azione rara) — libera
    anche un tap diretto e facilmente raggiungibile per l'azione più
    frequente, a costo di un tap in più (apri il drawer) per uscire dallo
    schermo. Decisione esplicita dello sviluppatore, non un effetto
    collaterale.
  - **`_matchTitle`**: "Nome squadra – Nome avversario" (o "AVVERSARI" se
    `match.avversario` non è impostato). L'ordine **non dipende da
    casa/trasferta**: di default la nostra squadra è sempre a sinistra, e
    segue il lato dei suoi giocatori — si inverte quando si fa "Cambia
    campo" (`nostroASinistra = !_isRightSide`). Padding orizzontale 56px per
    non sovrapporsi alle icone, troncato con ellissi se troppo lungo.
- **Drawer di utilità** (`_buildUtilityDrawer`, apribile via
  `_scaffoldKey.currentState?.openDrawer()` — necessario un
  `GlobalKey<ScaffoldState>` perché la barra superiore è custom, non
  un'AppBar reale): contiene i bottoni usati raramente, per non affollare
  l'area sopra il campo. Sfondo `_kBg` per coerenza col tema scuro.
  - **"Cambia campo"** (`ListTile`, icona `Icons.swap_horiz`): chiama
    `_toggleSide()` e chiude il drawer.
  - **"Sostituzione"** (`ListTile`, icona `Icons.swap_vert`, subito sotto
    "Cambia campo", `enabled: _bottoniRapidiAttivi` — set iniziato e fuori
    dalla modalità test): apre il flusso di cambio giocatore
    (`SostituzioneScreen` → `FormationConfigScreen` in modalità conferma)
    — vedi la voce dedicata in "Fasi di sviluppo" Fase 3.
  - **Toggle "Mostra numeri/ruoli"** (`SwitchListTile`): stato
    `_showJerseyNumbers`, **default `true`** (numeri di maglia visibili
    appena apri lo scout). Label dinamica che descrive l'azione del tap, non
    lo stato corrente: "Mostra ruoli" quando attivo (numeri visibili),
    "Mostra numeri" quando disattivo (ruoli visibili). Quando attivo, i
    token sul campo grande mostrano `player.numero` invece dell'etichetta di
    ruolo (la forma esagono/cerchio del palleggiatore resta comunque basata
    sul ruolo, non sul numero).
  - **Toggle "Modalità test"** (`SwitchListTile`, **default `false`**, solo
    per provare a video tutte le combinazioni rotazione × fase senza
    passare dal flusso reale): stato `_testModeEnabled`. Quando attivo:
    - `_squadraAlServizio` **ignora** `_setCorrente?.squadraServizioIniziale`
      e usa `_testServizio` (parte da `Squadra.nostra`) — funziona anche
      prima di aver risposto al dialog "Chi serve per primo?".
    - Attivandolo si azzera lo stato del test: `_rotationSteps = 0`,
      `_testServizio = Squadra.nostra`, `_testDopo = false` (si riparte
      sempre da "P1 battuta").
    - Compare un `FloatingActionButton.extended` (icona `Icons.skip_next`,
      label dinamica `"$_currentSlot battuta"`/`"...ricezione"`, con
      `" (dopo)"` in coda quando `_testDopo` è true) che ad ogni tap chiama
      `_testAvanza()`: cicla le **4 fasi vere** dello scambio, nello stesso
      ordine del gioco reale — Battuta → Dopo_Battuta → Ricezione →
      Dopo_Ricezione → Battuta della rotazione successiva (`_rotationSteps--`,
      cioè P1→P6→P5→P4→P3→P2→P1...). Sequenza completa: 24 tap per girare
      tutte e 6 le rotazioni nelle quattro fasi.
    - **`_faseDopo`** (getter): unifica la sotto-fase "dopo" tra modalità
      test (`_testDopo`, ciclato a mano) e gioco reale
      (`_fondamentaleGiudicatoRallyCorrente`, derivato dagli eventi) — usato
      da `_refPositionFor`/`_activeAttackMap`/`_activeDefenseMap` al posto di
      controllare `_testModeEnabled` caso per caso.
  - **"Fine"** (`ListTile`, icona `Icons.flag`, subito sopra "Indietro",
    stesso `Divider`): apre `EndSetScreen` (vedi Modello dati e "Fasi di
    sviluppo" per i dettagli di fine set/fine partita) — un `Navigator.push`,
    non un `pop`, quindi nessun problema di local history entry del Drawer
    (quel problema riguarda solo il pop, vedi sotto): basta chiudere il
    drawer per pulizia visiva prima di navigare.
  - **"Indietro"** (`ListTile`, icona `Icons.arrow_back`, in fondo alla
    lista dopo un `Divider`): spostato qui dalla barra superiore (vedi
    sopra) per lasciare il posto all'undo. **Non** un semplice
    `Navigator.pop(context)`: il `Drawer` registra una "local history entry"
    sulla route corrente (è così che il tasto back di sistema chiude prima
    il drawer e solo dopo torna indietro) — chiamare `Navigator.pop` mentre
    il drawer è aperto consuma quella entry e chiude SOLO il drawer, non
    naviga indietro (bug riscontrato: il bottone "non faceva nulla" perché
    in realtà chiudeva il drawer, già aperto, in modo impercettibile).
    Soluzione: catturare `Navigator.of(context)` **prima** di chiudere
    esplicitamente il drawer (`_scaffoldKey.currentState?.closeDrawer()`),
    poi chiamare `.pop()` sul Navigator già catturato — quel pop non passa
    più dalla local history entry (già consumata dalla chiusura esplicita)
    e naviga davvero alla schermata precedente.
- **Annulla lo scambio** (IMPLEMENTATO): secondo bottone in barra superiore
  (icona `Icons.replay`), **a sinistra dell'undo singolo** — che resta
  all'estremo destro, dove il dito lo cerca già. Serve al caso reale in cui
  l'arbitro fa **rigiocare l'azione** (fischio dubbio): cancella in un colpo
  tutte le azioni di gioco dello scambio, punto compreso, invece di premere
  l'undo N volte contando a memoria. Il titolo partita è passato a margini
  `left/right: 104` (erano 56, dimensionati per una icona per lato).
  - `_azioniUltimoRally` (getter, derivato dallo stesso stream): azioni con il
    `rallyId` dell'ultima azione, **escluse quelle non di gioco**. Da NON
    confondere con `_azioniRallyCorrente`, che serve alla logica di fase e
    considera solo lo scambio ANCORA APERTO e le sole azioni `scout`.
  - **I cambi giocatore NON si annullano** con questo tasto: una sostituzione
    avviene a palla ferma, quindi non fa parte dello scambio — ma nel DB ne
    condivide il `rallyId`, perché in `_registraAzione` solo `timeout` e
    `correzioneRotazione` interrompono l'ereditarietà (la prima azione dopo un
    cambio eredita il rallyId del cambio). Senza l'esclusione, un "si rigioca"
    rimanderebbe in panchina un giocatore appena entrato. L'esclusione vive in
    `ScoutActionRepository.annullaRally` ed è coperta da un test dedicato
    (`test/providers/scout_action_repository_test.dart`).
  - `_puoAnnullareRally`: come `_puoAnnullare` più `_azioniUltimoRally` non
    vuota — quindi **spento se l'ultima azione è un timeout, una correzione
    rotazione o un cambio** (per quelle c'è l'undo singolo).
  - Conferma col **solo conteggio** ("Verranno eliminate N azioni dello
    scambio"), non l'elenco: si legge a bordo campo. Irreversibile come
    l'undo singolo. Punteggio/servizio/rotazione si ricalcolano da soli dagli
    eventi rimasti: nessuna inversione manuale.
- **Undo** (IMPLEMENTATO): bottone "annulla" nella barra superiore (vedi
  sopra). `_puoAnnullare` (bool): attivo solo con `_setCorrente != null`,
  fuori dalla modalità test (che non scrive azioni reali) e con almeno
  un'azione nel set (`_ultimaAzione != null`) — altrimenti l'`IconButton` è
  disabilitato (icona grigia di default Material, nessuno stile custom).
  - **Conferma prima dell'undo** (`_confermaAnnullaUltimaAzione`,
    IMPLEMENTATA — l'azione è irreversibile, niente "redo"): `AlertDialog`
    con la descrizione dell'azione che verrebbe eliminata (riusa
    `_descrizioneAzione`, stesso testo/voto del banner ultima azione) +
    bottoni "Annulla" (chiude il dialog, nessun effetto) / "Conferma"
    (chiama `_annullaUltimaAzione()`). Il bottone "annulla" in barra
    superiore chiama questo metodo, non `_annullaUltimaAzione()`
    direttamente.
  - **`_annullaUltimaAzione()`**: chiama
    `ScoutActionRepository.annullaUltimaAzione(setId)` — elimina la riga con
    `ordine` massimo nel set (niente logica di "inversione" manuale:
    punteggio/servizio/rotazione sono derivati da `ricalcolaStato()` sugli
    eventi rimanenti, quindi si aggiornano da soli quando lo
    `scoutAzioniStreamProvider` notifica la modifica). Chiude anche un
    eventuale pannello voto aperto (`_votoInCorso = null`) — coerente con lo
    stesso comportamento dei bottoni rapidi.
  - **`_fondamentaleGiudicatoRallyCorrente` va aggiornato a mano**: a
    differenza di punteggio/rotazione, questo flag è stato locale (non
    derivato dallo stream, vedi sopra), quindi dopo l'undo va ricalcolato in
    base alla **nuova** ultima azione rimasta nel set (non a quella appena
    eliminata) — altrimenti resterebbe quello dell'azione cancellata.
    `_annullaUltimaAzione()` rilegge l'ultima azione rimasta via
    `ScoutActionRepository.ultimaAzione(setId)` (stessa query usata
    internamente da `_registraAzione` per il calcolo del `rallyId`,
    estratta in un metodo pubblico riutilizzabile) e imposta il flag a
    `true` solo se quella riga ha `esitoPunto == nessuno` (`false`,
    compreso il caso "nessuna azione rimasta", se il set torna vuoto).
- `ScoutScreen` riceve da `FormationConfigScreen`: `match`, `team`,
  `palleggiatoreSlot` (slot P1–P6 dove si trova il palleggiatore) e
  `assignments` (`Map<String, Player>` — la formazione completa, usata per
  leggere il ruolo reale di ciascun giocatore).
- **Bottoni rapidi** (IMPLEMENTATI — percorso alternativo ai 3 tocchi, prima
  voce concreta del modello event-sourced, vedi Modello dati): riga sotto la
  barra superiore e sopra il campo (`Padding` orizzontale 24/verticale 8,
  `Row(spaceBetween)`), due gruppi da due bottoni ciascuno:
  - **Gruppo nostro** (`_buildBottoniNostri`): "Errore nostro" (rosso,
    `Icons.close` — `TipoAzione.erroreGenerico`, `Squadra.nostra`,
    `EsitoPunto.puntoAvversario`) + "Punto nostro" (verde, `Icons.check` —
    `TipoAzione.puntoManuale`, `Squadra.nostra`, `EsitoPunto.puntoNostro`).
  - **Gruppo avversario** (`_buildBottoniAvversario`), ordine invertito per
    simmetria visiva: "Punto avversario" (verde, check) + "Errore avversario"
    (rosso, X) — stessi tipi/esiti specchiati (`Squadra.avversari`).
  - **Motivo dell'errore avversario** (IMPLEMENTATO, esperimento — se funziona
    bene si estende lo stesso meccanismo ad altri bottoni rapidi): enum
    `MotivoErrore` (`generico`/`battuta`/`falloDiPosizione`/`invasione`,
    `enums.dart`) salvato nella stessa colonna polimorfica `tipoEsecuzione`
    già usata da `TipoBattuta`/`TipoAttacco` — nessuna nuova colonna a DB.
    Tap singolo su "Errore avversario" registra subito `generico` (percorso
    veloce invariato); **pressione prolungata**
    (`onLongPressStart` su `_buildQuickActionButton`, nuovo parametro
    opzionale) apre `_scegliMotivoErroreAvversario()` — un `showMenu` nativo
    ancorato al punto del tap con i 4 motivi — e registra quello scelto.
    `ScoutActionRepository.registraAzioneRapida()` accetta ora anche
    `tipoEsecuzione` (default `'nonSpecificato'`, usato per gli altri
    bottoni rapidi che non hanno un motivo).
  - **Colori**: rosso `Colors.red` (errore) e verde `AppColors.success`
    (punto — non blu: un punto generico è semanticamente più vicino al voto
    "perfetto" che a "positivo", quindi stesso colore di quello, vedi
    `CourtStyle.votoColor()` sotto), letterali/condivisi con
    `_descrizioneAzione` (banner ultima azione, vedi sotto) — stesso
    significato, stesso colore ovunque.
  - **Segue il lato come titolo/punteggio**: `_isRightSide` decide quale
    gruppo va a sinistra/destra nella `Row`, stessa convenzione di
    `_matchTitle`/`_buildScoreDisplay`.
  - `_buildQuickActionButton`: stesso stile visivo di `_buildRotationButton`
    (quadrato arrotondato 44×44, icona bianca, ombra) ma colore parametrico;
    se disabilitato (`onTap == null`) il colore perde opacità (`withAlpha(80)`)
    e l'ombra non viene disegnata.
  - **Disabilitati** (`_bottoniRapidiAttivi == false`) quando `_setCorrente
    == null` (set non ancora iniziato — dialog "Chi serve per primo?" non
    risposto) o `_testModeEnabled == true` (per non scrivere azioni reali
    nel set mentre si sta solo simulando a video). Il tap chiama
    `_registraAzioneRapida()`, che inserisce subito un `ScoutAction` via
    `ScoutActionRepository` — niente stato locale, il punteggio si aggiorna
    perché `_statoSetReale` osserva lo stream delle azioni del set.
    Restano **sempre tappabili** anche col pannello voto aperto (la riga dei
    bottoni rapidi vive nella `Column` del body, fuori dallo Stack del campo
    dove sta il pannello — non viene coperta dal suo sfondo trasparente):
    `_registraAzioneRapida` chiude comunque `_votoInCorso` (lo riporta a
    `null`), perché un bottone rapido chiude lo scambio per un'altra via e
    il pannello non avrebbe più senso.
- **Bottoni timeout** (IMPLEMENTATI — `TipoAzione.timeout`, vedi Modello
  dati): un bottone per squadra (blu `AppColors.brandPrimary`, icona
  `Icons.access_time`, stesso stile 44×44 dei bottoni rapidi) sulla stessa
  riga dei gruppi punto/errore, sul **lato interno** del rispettivo gruppo,
  staccato da un gap `_kTimeoutGap = 112` (lo spazio di ~2 bottoni — voluto
  per eventuali bottoni futuri in mezzo). Seguono `_isRightSide` col cambio
  campo (il timeout resta sempre verso il centro). Tap →
  `_timeout(squadra)` → riga `registraAzioneRapida` con esito `nessuno`:
  nessun dialog di conferma (decisione esplicita: il banner ultima azione
  mostra "Timeout [squadra]" in blu come conferma visiva, e l'undo standard
  lo annulla — approccio log-eventi preferito al dialog).
  - **Pallini di stato** (`_buildTimeoutDots`): due cerchi 14×14
    **nell'header** (barra superiore, `bottom: 8`), allineati in orizzontale
    col bottone timeout sottostante (offset 237px dal bordo = centro bottone
    254 − metà riga pallini; il lato segue `_isRightSide`). Grigio scuro
    `0xFF6F6F6F` (Colors.grey −30%) da chiamare, **gialli** man mano che si
    chiamano; al secondo timeout il bottone si disabilita. Conteggio
    derivato dallo stream (`_timeoutChiamati`, conta le righe
    `TipoAzione.timeout` del set — nessuno stato locale: undo e ripresa
    partita tornano coerenti da soli; si azzera al set successivo perché il
    log è per-set).
- **Punteggi header al 30%/70%**: i due gruppi −/punteggio/+ sono centrati
  al 30% e 70% della larghezza (erano 25/75, avvicinati su richiesta), con
  un `Center` dentro il riquadro fisso da 116px — senza, la `Row` (~76px)
  resta allineata a sinistra in entrambi i riquadri e i punteggi risultano
  asimmetrici rispetto al titolo centrato (bug reale corretto).
- **Voto battuta/ricezione/altri fondamentali** (IMPLEMENTATO — flusso a 3
  tocchi generalizzato a tutti i fondamentali tranne `errore`: giocatore →
  fondamentale → voto). Nessuna traiettoria per ora.
  - **Due fasi per scambio**: la prima azione giudicabile è sempre forzata
    dalla fase di gioco (battuta se battiamo noi, ricezione se battono
    loro — "chi serve e chi riceve sono sempre squadre diverse"); una volta
    giudicata con un voto non terminale (`_fondamentaleGiudicatoRallyCorrente
    == true`, palla in gioco), le azioni successive dello stesso scambio
    (alzata, attacco, muro, difesa) sono **a scelta libera**: si tocca
    qualunque giocatore e si scegli il fondamentale nel pannello (vedi
    "Scelta del fondamentale" sotto) — non è derivabile dalla sola
    rotazione/fase di gioco quale dei 6 stia eseguendo cosa.
  - **`_giocatoreTappabile(slot)`** (bool): se questo slot è tappabile nella
    fase corrente, a prescindere dal fondamentale. Se battiamo noi: solo
    `slot == 'P1'` (il battitore) prima del voto battuta, **chiunque** dopo
    (fase libera). Se battono loro: sempre **chiunque** (ricezione prima del
    voto, fase libera dopo) — `slot` può essere `null`, usato per il libero
    che non ha uno slot P1-P6 proprio (vedi sotto).
  - **`_fondamentaleForzato()`** (`Fondamentale?`): `null` se siamo in fase
    libera (va scelto nel pannello), altrimenti `Fondamentale.battuta` o
    `Fondamentale.ricezione` in base a chi è al servizio.
  - **Tap su un giocatore tappabile**: `_tapHandlerPerGiocatore(player,
    {slot})` — disabilitato in modalità test o prima dell'inizio del set,
    altrimenti tappabile se `_giocatoreTappabile(slot)`. Tap → apre
    `_votoInCorso` (record `(giocatore, fondamentale, voto)`, `fondamentale`
    da `_fondamentaleForzato()` — `null` in fase libera, dove va scelto nella
    colonna sinistra della pulsantiera; `voto` sempre `null` all'apertura).
    Vale anche **a pannello già aperto**: il tap sostituisce la giocatrice
    (vedi la pulsantiera sotto).
    - **Trabocchetto hit-test fuori dal campo** (`_buildBattitoreTapCatcher`,
      solo quando battiamo noi — in ricezione P1 è una posizione normale in
      campo, già coperta dal proprio token): quando il battitore è in
      posizione di battuta (X negativa, vedi `_kBattutaP1Position`), il
      `GestureDetector` passato a `_buildPlayerToken` **non riceve mai il
      tap**, anche se il token è visibile lì grazie a `Clip.none`. Motivo:
      `Clip.none` evita solo il clip del DISEGNO sullo Stack interno, ma il
      `SizedBox`/`AspectRatio` che racchiude il campo limita comunque
      l'AREA DI HIT-TEST dei suoi figli al proprio `size` — un tap fuori da
      quei limiti non raggiunge mai lo Stack interno, a prescindere da
      `clipBehavior`. Soluzione: stessa tecnica già usata per
      libero/panchina (`_buildLiberoSwapTokens`) — un `GestureDetector`
      trasparente nello Stack **esterno** (coordinate schermo assolute,
      sempre dentro i suoi limiti), posizionato esattamente sopra al token
      visibile (stessa formula `courtLeft`/`courtTop` + conversione spazio
      di riferimento→pixel). Si applica a qualunque futuro token disegnato
      fuori dai confini del riquadro campo — non solo al battitore.
    - **In ricezione, tutti i 6 ruoli sono tappabili**, libero compreso:
      `_buildCourtTokens` passa `onTap` in entrambi i rami (con e senza
      mappa di difesa attiva); `_buildLiberoSwapTokens` passa `onTap` al
      libero solo quando è effettivamente **in campo** (mai al sostituito
      in panchina, né al libero stesso quando è lui in panchina per
      l'eccezione del servizio) — il libero non ha uno slot proprio, quindi
      passa `slot: null` a `_tapHandlerPerGiocatore` (tappabile solo in
      ricezione, mai in battuta: coerente con "il libero non serve mai").
  - **Pannello voto = PULSANTIERA UNICA** (`_buildPannelloVoto` +
    `_buildPulsantiera`, ritorna una lista — vedi sotto): ancorato al bordo
    destro dello schermo (`Positioned(right: 16)`), card scura (`_kTopBarBg`)
    con header (numero di maglia 26 bold; sotto il cognome 18, `maxLines: 1` +
    ellissi) e sotto **due colonne sempre entrambe a schermo**: fondamentali a
    sinistra, voti a destra. Righe della stessa altezza, così i 4 fondamentali
    si allineano ai primi 4 voti e il `=` resta da solo in fondo.
    - **Si tocca una voce per colonna, in QUALSIASI ORDINE**, e alla coppia
      completa l'azione parte da sé (`_sceglieFondamentale`/`_scegliVoto` →
      `_provaRegistrare` → `_registraVoto`). Ri-toccare la stessa colonna
      **corregge** la scelta senza scrivere niente: nulla finisce a DB finché
      la coppia non è completa.
    - **Rifatta il 2026-08-21** (era: prima i 4 fondamentali, POI al loro
      posto i 5 voti). I tocchi restano 3, il guadagno è altrove — i bottoni
      non si spostano né cambiano contenuto fra un tocco e l'altro, quindi
      l'occhio non deve ri-agganciare il pannello e si forma memoria
      muscolare; e sbagliare fondamentale non costa più "chiudi e ricomincia
      dal giocatore". Verificato più veloce sul dispositivo reale.
    - **Ordine libero tenuto di proposito** anche se all'utente viene naturale
      fondamentale→voto: spegnere i voti fino alla scelta del fondamentale
      rimetterebbe dentro il difetto appena tolto (5 bottoni che cambiano
      aspetto richiamano l'occhio via dal campo), e chi usa sempre lo stesso
      ordine non nota differenza. Imporlo dopo è una guardia di una riga in
      `_scegliVoto`; il contrario costa di nuovo tutta la discussione.
    - **Misure** (costanti in cima allo State): righe `_kAltezzaRigaPulsantiera`
      64, gap `_kGapPulsantiera` 8, colonne `_kLarghezzaFondamentale` e
      `_kLarghezzaVoto` entrambe 85; `Positioned(right: 4)` e padding card
      8/6 — **ingombro totale dal bordo destro 194dp**.
      **Non allargare queste misure senza rifare il conto**: col cambio campo
      il battitore esce dal campo a DESTRA (`_kBattutaP1Position` specchiata) e
      finisce proprio dove sta la card — e da lì ci si deve partire col dito
      per la traiettoria in-line. Misurato su tablet da ~1274dp: il token
      arriva a 0,84×larghezza schermo, quindi la card non può superare ~196dp.
      Storia: fondamentali 150×60 → 120 → 100 (uguali ai voti) → 85, e i
      margini portati al minimo prima di toccare i bottoni.
      Il taglio del padding VERTICALE va nella direzione opposta a quella che
      si teme: su telefono è l'altezza a decidere quanto il `FittedBox`
      rimpicciolisce tutto, quindi meno padding = bottoni più grandi.
      L'header va vincolato a `_kLarghezzaPulsantiera`: il `FittedBox` passa
      vincoli **illimitati**, quindi un cognome lungo allargherebbe tutta la
      card invece di troncarsi.
    - **Colonna fondamentali**: 4 voci in ordine **fisso**
      Difesa/Attacco/Muro/Alzata (ordine chiesto dall'utente). Non vanno
      riordinate né sostituite a seconda della fase: sono coordinate su cui si
      forma l'abitudine. Battuta e ricezione **non stanno qui** — quando la
      fase le impone, la colonna è spenta e il fondamentale compare come chip
      evidenziato nell'header (`_buildChipFondamentaleForzato`). Il "forzato"
      si deriva da "il fondamentale selezionato non è fra i 4 della colonna",
      non da `_fondamentaleForzato()`, così i due non possono divergere.
    - **Colonna voti**: 5 bottoni, ordine dell'enum (`#`/`+`/`/`/`-`/`=`),
      colore da `CourtStyle.votoColor()` (vedi sotto).
    - **Feedback di selezione** (`_buildBottonePulsantiera`): bordo bianco 3px
      sul bottone scelto; le altre voci **della stessa colonna** scendono a
      opacità 0.55, ma **solo se in quella colonna una scelta c'è già** —
      attenuando sempre, il pannello si aprirebbe con l'aria di essere tutto
      disattivato. Bottone spento: 0.4, e resta comunque al suo posto.
    - **Pulsantiera RISTRETTA** (scorciatoia kill, dopo un `#` di attacco
      dell'altra squadra): solo Muro/Difesa attivi e rossi, un tocco registra
      subito il `=` (`onErroreDifensivo`, resta a **1 tocco**: è il caso più
      frequente della partita); la colonna voti è spenta col `=` evidenziato
      come anteprima di quello che verrà scritto.
    - **`_registrazioneInCorso`**: guardia contro il doppio tocco rapido
      sull'ultimo bottone della coppia — `_registraVoto` è async (attende
      `TrajectoryScreen` e la scrittura) e senza guardia un secondo tocco
      arrivato nel frattempo registrerebbe due azioni identiche.
    - **`_buildPulsantiera` è condivisa** fra pannello nostro e avversario:
      cambiano solo i callback e le funzioni `targetFond`/`targetVoto` delle
      àncore tutorial.
    - **Tipo battuta** (IMPLEMENTATO, opzionale — "Dal basso"/"Float"/
      "Salto"/"Salto float"): scelto su **`TrajectoryScreen`**, non più nel
      pannello voto qui — riga orizzontale di 4 chip subito sotto al campo
      (spostata via per sgombrare il pannello voto, già pieno; vedi
      "Traiettoria battuta/attacco" più sotto per i dettagli della
      schermata e del meccanismo di passaggio/ritorno del valore "armato").
      Tap su un chip → lo seleziona (sfondo/bordo `AppColors.brandAccent`);
      tap di nuovo sullo stesso chip → lo deseleziona (torna a
      `nonSpecificato`). **Non blocca il flusso veloce**: ignorarlo e
      saltare/disegnare la traiettoria registra comunque l'azione, con
      `tipoEsecuzione = 'nonSpecificato'` come sempre.
      - **Resta "armato" tra una battuta e l'altra dello STESSO giocatore**
        (spesso batte sempre nello stesso modo) — cambia battitore e si
        azzera (non si assume che batta uguale). `_giocatoreTipoBattutaArmato`
        e `_tipoBattutaSelezionato` restano in `ScoutScreen` (unica istanza
        persistente tra una `TrajectoryScreen` e la successiva): la prima
        traccia il `player.id` per cui il valore è valido (resettato a
        `nonSpecificato` in `_tapHandlerPerGiocatore` quando cambia
        battitore), la seconda viene passata come `tipoBattutaIniziale` alla
        navigazione e riletta dal campo `tipoBattuta` del risultato al
        ritorno — `_registraVoto` non la resetta mai esplicitamente (resta
        quella che è finché non cambia battitore).
      - `_registraVoto` passa `tipoEsecuzione: _tipoBattutaSelezionato.name`
        a `registraAzioneScout()` solo se `fondamentale == battuta`,
        `_tipoAttaccoSelezionato.name` se `== attacco`, altrimenti
        `'nonSpecificato'` (ricezione/alzata/muro/difesa non hanno un proprio
        tipo di esecuzione — vedi Modello dati).
    - **Tipo attacco** (IMPLEMENTATO, opzionale — "Forte"/"Piazzata"/
      "Pallonetto" in un'unica riga): scelto anche questo su
      **`TrajectoryScreen`** (non più nel pannello voto), riga orizzontale
      di 3 chip sotto al campo — stessa posizione della riga tipo battuta
      (mai entrambe insieme, sono mutuamente esclusive sullo stesso
      `widget.fondamentale`). **Non resta mai "armato"** tra un attacco e
      l'altro (a differenza della battuta, di solito eseguita sempre nello
      stesso modo dallo stesso giocatore): a differenza del tipo battuta,
      qui `TrajectoryScreen` non riceve né passa indietro un valore
      "iniziale" — parte sempre da `nonSpecificato` a ogni apertura della
      schermata, varia troppo spesso colpo su colpo per assumere che resti
      lo stesso anche per lo stesso giocatore.
    - **`_buildTipoChip`** (in `TrajectoryScreen`, duplicata da
      `ScoutScreen` con lo stesso stile — non più condivisa tra due righe
      nella stessa schermata, dato che entrambe le righe sono migrate
      insieme): chip generica (92×52, stesso stile selezionato/non
      selezionato) parametrizzata su label/selezionato/onTap.
    - **Annulla = tap fuori dal pannello**, non un bottone dedicato. Il
      pannello stesso è avvolto in un `GestureDetector(onTap: () {})`
      `opaque` che **assorbe** il tap — necessario perché lo Stack interrompe
      la ricerca del bersaglio al primo figlio che reclama il tocco (vedi
      `defaultHitTestChildren`): senza, un tap su un punto della card senza un
      proprio `onTap` (lo sfondo, il testo del nome) cadrebbe sullo scrim e
      chiuderebbe il pannello per errore.
    - **Cambio giocatore a pannello aperto, e i due trabocchetti di hit-test**
      (risolti il 2026-08-21; da rileggere prima di toccare l'ordine dei figli
      dello `Stack` di `ScoutScreen`). Toccare un'altra giocatrice
      **sostituisce** quella in corso invece di chiudere, e il pannello
      riparte da coppia vuota — fondamentale e voto già scelti NON si
      trascinano dietro, altrimenti il cambio registrerebbe da solo.
      1. **Lo scrim va in FONDO allo Stack**, cioè come PRIMO figlio
         (`_buildScrimPannelli`, inserito in `build` prima del campo). Lo
         Stack cerca il bersaglio dall'ultimo figlio verso il primo: con lo
         scrim in cima — dov'era — il tocco su un token moriva lì e servivano
         due tocchi per cambiare giocatrice.
      2. **`Image` INTERCETTA i tocchi.** Spostato lo scrim sotto, il tocco
         dentro al campo si fermava sull'immagine di sfondo e non chiudeva
         più: bisognava uscire dal campo. Serve quindi un chiuditore
         sull'immagine stessa, primo figlio dello Stack **interno** (sotto ai
         token): fra i due gesti vince quello del token, colpito per primo.
      Un token NON tappabile viene disegnato senza `GestureDetector`, quindi
      il tocco lo attraversa e chiude — nessun tocco che "non fa niente".
      Conseguenza da tenere a mente: tutto ciò che è interattivo e sta sopra
      allo scrim riceverebbe il tocco invece di lasciarlo chiudere — per
      questo mini-map e bottoni di correzione rotazione sono avvolti in
      `IgnorePointer` mentre un pannello è aperto (correggere la rotazione per
      sbaglio scriverebbe un evento vero).
      3. **Terzo trabocchetto, figlio del primo: i `Positioned` senza key sono
         tutti indistinguibili.** Lo scrim è un `Positioned.fill`, il campo un
         `Positioned`: stesso tipo, entrambi senza key, quindi `canUpdate` è
         vero. Finché lo scrim compariva e spariva da QUELLA posizione (primo
         figlio), chiudere il pannello faceva slittare tutti gli indici e
         Flutter accoppiava l'elemento dello scrim col widget del campo,
         **ricostruendo da zero l'intero sottoalbero del campo** — con gli
         `AnimatedPositioned` dei token rimontati e quindi senza animazione di
         rotazione. Sintomo: "una cosa che dovrebbe animarsi salta", mai un
         errore. Rimedio adottato: lo scrim è **sempre** in albero (spento con
         `IgnorePointer`) e ha una `key` esplicita; stessa key sull'overlay
         della freccia, che sta dopo il log azioni — anch'esso a lunghezza
         variabile. **Regola per il futuro**: in questo Stack convivono
         parecchi builder che restituiscono 0 o N widget; ai figli strutturali
         va data una key, costa nulla e toglie di mezzo un'intera classe di
         bug illeggibili.

  - **Traiettorie SUL CAMPO LIVE** (sperimentale, in prova — interruttore
    `Impostazioni.traiettoriaBattutaInLine`, **default OFF**; il nome della
    chiave dice ancora "battuta" per non rompere le preferenze già salvate,
    ma vale per **battuta E attacco**).
    Ordine: tocchi il giocatore → trascini sul campo → voti. Nasce da una
    prova in partita vera: in battuta il voto si può dare solo dopo aver visto
    l'esito, quindi si è già in ritardo — e la schermata dedicata, aperta
    dopo, ti porta via dal campo proprio mentre lo scambio continua.
    Le due strade convivono APPOSTA, per confrontarle sullo stesso build anche
    a set in corso: `TrajectoryScreen` resta intatta e **non va cancellata**
    finché non c'è un verdetto. O tutto nuovo o tutto vecchio: mezzo e mezzo
    non direbbe niente.
    - **Il voto chiude l'azione**: se voti prima di trascinare la traiettoria
      è persa, come il "salta" di oggi. Nessuna regola nuova.
    - **Il tratto si cattura PRIMA di sapere che fondamentale è.** In fase
      libera il fondamentale si sceglie nel pannello, quindi al momento del
      trascinamento non esiste ancora: pretenderlo prima costringerebbe a
      premere "Attacco" per poter disegnare, cioè l'opposto dell'ordine
      naturale. Si cattura e basta; è `_scriviVoto` a usare il tratto solo se
      `fondamentale.richiedeTraiettoria`, altrimenti lo butta.
    - **Preselezione di Attacco** (`_preselezionaAttaccoDaTraiettoria`): al
      rilascio del tratto il fondamentale si accende da sé su Attacco — in
      fase libera un tratto può solo essere quello (la battuta passa sempre
      dalla fase servizio, alzata/muro/difesa non hanno traiettoria).
      **Sovrascrive** anche una scelta già fatta nella colonna: se hai
      disegnato, quell'azione È un attacco e il tocco precedente era lo
      sbaglio. NON tocca il fondamentale imposto dalla FASE (battuta,
      ricezione) — trasformare una ricezione in attacco corromperebbe
      l'azione; la distinzione è la stessa del chip nell'header
      (`_sceltoNellaColonna`). Mai nella pulsantiera ristretta, dove Attacco è
      disabilitato. Vale anche col tratto **appeso alla rete**, così l'attacco
      sbagliato a rete si chiude con un `=` e basta.
      Conseguenza voluta: col voto già scelto la coppia si completa al
      rilascio del dito e l'azione parte — è sempre la regola "si registra
      quando ci sono entrambe", con una metà che arriva da un trascinamento.
    - **Tocco a muro: SOFFERMAMENTO sulla rete** (solo attacco), lo stesso
      meccanismo di `TrajectoryScreen`. Trascinando, se il dito resta nella
      fascia `_kToleranzaReteInLine` per `_kSoffermamentoReteInLine` (400ms) lo
      snodo si aggancia alla rete e la freccia prosegue a due segmenti. Il
      dwell NON può basarsi sui soli eventi di movimento (col dito fermo non ne
      arrivano): serve un `Timer` avviato all'ingresso nella fascia e annullato
      se se ne esce prima — o al rilascio, perché un soffermamento non concluso
      col dito giù non deve scattare dopo. La riga gialla sulla rete dice
      "resta fermo un attimo e lo snodo si fissa qui". Non si attiva in battuta
      (attraversare la rete su un servizio è normale); in fase libera si
      consente sempre, perché lì l'offensiva può solo essere un attacco.
      **Scelto dopo averli provati entrambi** (2026-08-21): lo "stacco e
      ripresa del dito" (rilascio nella fascia = snodo, secondo trascinamento =
      arrivo) è stato implementato, provato sul device e **messo da parte** —
      il soffermamento convince di più. La porta resta aperta: l'alternativa è
      per intero nel commit `03fb19d`, e in `_onPointerUpCampo` c'è un
      promemoria che la richiama.
    - **`Listener` ANTENATO** dello Stack del corpo: riceve ogni evento a
      prescindere da chi lo assorbe e **non partecipa all'arena dei gesti**,
      quindi non sottrae un solo tocco a bottoni e token. Un `GestureDetector`
      con `onPan*` sopra ruberebbe i tap, sotto non riceverebbe i
      trascinamenti che partono FUORI dal campo (il battitore ha X negativa).
      Stesso motivo per cui `_anchor` usa un `Listener` per il tutorial.
      Un trascinamento partito sulla card non disegna: la card ha un
      `Listener` proprio che alza un flag, e — essendo più profondo — riceve
      l'evento prima dell'antenato (`HitTestResult.path` si costruisce
      scendendo). Per lo stesso motivo quel flag NON va azzerato nel gestore
      dell'antenato, ma al rilascio.
    - **`_frecciaInLine` è un `ValueNotifier` passato come `repaint` al
      painter**, non un campo con `setState`: il dito genera un evento per
      frame, e un `setState` ricostruirebbe tutto `ScoutScreen` 60 volte al
      secondo.
    - Il painter è condiviso con `TrajectoryScreen`
      (`widgets/freccia_traiettoria_painter.dart`, estratto da lì): una copia
      sola, così le due strade non divergono mentre le si confronta.
    - **PUNTO APERTO**: col disegno in-line né il tipo di battuta né quello di
      attacco sono indicabili (i chip vivono su `TrajectoryScreen`), quindi
      `tipoEsecuzione` resta `nonSpecificato`. Sul pallonetto si sente più che
      sulla battuta: il painter disegna l'arco solo se sa che è un pallonetto,
      quindi in-line gli attacchi si vedono tutti come linee dritte. La
      pressione prolungata sul battitore è stata provata e **scartata**
      (2026-08-21): il gesto non convince. Il vincolo per qualunque
      alternativa è che non competa né col trascinamento né col tocco singolo;
      restano da provare doppio tocco sul token, riga di chip nella card
      (costa altezza, che su telefono decide la scala) e scorrimento laterale.
  - **`CourtStyle.votoColor(Voto)`** (`lib/theme/court_style.dart`, prima
    volta usata in UI) aggiornato allo schema scelto per questo pannello:
    `perfetto` verde (`AppColors.success`) — **stesso colore dei bottoni
    rapidi "Punto"** (vedi sopra): un punto generico è semanticamente più
    vicino al voto "perfetto" che a "positivo", quindi condividono il
    colore. `mezzoPunto`/`negativo` grigio neutro (`AppColors.neutral`) —
    nessun trattamento dedicato richiesto, condividono lo stesso neutro.
    `errore` rosso `Colors.red` **letterale** — stesso colore dei bottoni
    rapidi "Errore" e del banner ultima azione
    (`_buildQuickActionButton`/`_descrizioneAzione` in `scout_screen.dart`):
    stesso significato, stesso colore ovunque. `positivo` resta blu
    (`Colors.blue` letterale) — colore indipendente, non condiviso con
    nessun altro elemento dell'interfaccia (il punto generico usa il verde
    di "perfetto", non più il blu di "positivo" come in una versione
    precedente).
  - **Esito automatico** (`_esitoVoto(fondamentale, voto)`, GENERALIZZATO a
    tutti i fondamentali — corrisponde alla regola del Modello dati):
    qualunque fondamentale con voto `errore` → `puntoAvversario` (battuta in
    rete/fuori, ricezione non tenuta, attacco murato/fuori, muro sbagliato,
    ecc.); solo `battuta`/`attacco`/`muro` con voto `perfetto` → `puntoNostro`
    (ace, schiacciata vincente, muro punto) — ricezione/alzata/difesa non
    vincono mai punti da sole, preparano solo la giocata successiva (tutti
    gli altri casi → `nessuno`, palla in gioco).
  - **`_registraVoto()`** (senza parametri: legge fondamentale e voto da
    `_votoInCorso`, ed esce se una delle due metà manca — la chiama solo
    `_provaRegistrare`, a coppia completa): chiama
    `ScoutActionRepository.registraAzioneScout()` (stesso calcolo di
    `ordine` di `registraAzioneRapida`, ma `rallyId` non coincide più
    sempre con `ordine`: se l'ultima azione del set ha `esitoPunto ==
    nessuno` — scambio ancora in corso — la nuova azione eredita il suo
    `rallyId`, altrimenti ne inizia uno nuovo. Generale: pronto per quando
    si aggiungeranno alzata/attacco/ecc. nello stesso scambio). Chiude il
    pannello e aggiorna `_fondamentaleGiudicatoRallyCorrente`.
  - **`_fondamentaleGiudicatoRallyCorrente`** (bool, stato locale): true
    dopo un voto non terminale (battuta o ricezione giudicata, palla in
    gioco) — si resetta a `false` ad ogni azione che chiude lo scambio
    (punto/errore, anche dai bottoni rapidi: stesso reset in
    `_registraAzioneRapida`). Doppio effetto quando true: governa la fase
    libera (vedi sopra, `_fondamentaleForzato()` torna `null`) e, quando
    battiamo noi, `_refPositionFor('P1')` non usa più
    `_kBattutaP1Position`: **il battitore si riporta nella sua posizione di
    attacco in campo**, perché la palla è in gioco (nessun effetto sulle
    posizioni di ricezione, che non hanno un equivalente "fuori campo"). In
    modalità test questo flag viene ignorato (`_refPositionFor` mostra
    sempre la posa di battuta quando si "serve", dato che lì non si
    registrano voti reali).
  - **`_buildBattitoreTapCatcher`** (vedi sopra): oltre al caso "stiamo
    ricevendo", ora salta l'overlay anche quando
    `_fondamentaleGiudicatoRallyCorrente == true` — una volta giudicata la
    battuta, il battitore è già rientrato in posizione di attacco normale
    (coperta dal proprio token, niente più bisogno del trabocchetto fuori
    campo). Evita un overlay ridondante sovrapposto al token durante la fase
    libera, quando P1 torna a essere un tap-target qualunque.
- **Banner ultima azione** (IMPLEMENTATO): riga centrata ad altezza fissa
  32dp tra i bottoni rapidi e il campo (`SizedBox(height: 32) + Center` —
  altezza fissa anche quando non c'è nulla da mostrare, per non far
  "saltare" il campo sottostante ad ogni apparizione/scomparsa). Mostra
  l'**ultima riga `ScoutAction`** del set corrente (`_ultimaAzione`,
  `righe.last` dello stesso stream già osservato da `_statoSetReale` —
  niente stato locale duplicato: è la stessa riga che in futuro alimenterà
  anche le statistiche/report, vedi Modello dati). Resta visibile finché
  non arriva un'azione successiva — **nessun timer di sparizione**
  automatica, nemmeno per punto/errore (deciso esplicitamente: stesso
  comportamento per tutte le azioni, per non introdurre la complessità di
  un timer prima che serva davvero).
  - **`_descrizioneAzione(ScoutAction)`** (testo + voto opzionale + colore):
    - `TipoAzione.scout` (voto su un fondamentale): `testo = "Numero -
      Cognome - Fondamentale"` (es. "7 - Rossi - Battuta") + `voto =
      simbolo del voto` separato (es. "+"), reso dal banner (vedi sotto) con
      un proprio `TextSpan` più grande — niente più separatore `|`,
      superfluo ora che il voto non condivide lo stile del resto della
      riga. Colorato come il voto (`CourtStyle.votoColor()`).
    - `TipoAzione.puntoManuale`/`erroreGenerico` (bottoni rapidi, nessun
      giocatore): solo l'etichetta, `voto = null` — `"Punto [nome
      squadra]"`/`"Punto avversario"` (verde, `AppColors.success`) o
      `"Errore [nome squadra]"`/`"Errore avversario"` (rosso, `Colors.red`
      letterale). Per la nostra squadra si usa il nome reale (`widget.team.
      nome`, es. "Punto Nettunia") invece del generico "nostro" — per
      l'avversario resta "avversario" (il nome può non essere impostato,
      vedi `_matchTitle`). Stessi colori dei bottoni che le generano
      (`_buildQuickActionButton`) e di `CourtStyle.votoColor()` per
      perfetto/errore (vedi sopra): stesso significato, stesso colore in
      tutti e tre i posti. Stesso testo riusato anche dal dialog di
      conferma undo (`_confermaAnnullaUltimaAzione`), che richiama questa
      stessa funzione.
    - **`_buildBannerUltimaAzione`** usa `Text.rich`/`TextSpan` per
      ingrandire **solo il simbolo del voto** (fontSize 20, bold) rispetto
      al resto della riga (fontSize 13, w600) — più leggibile a colpo
      d'occhio mentre si segue il campo. Lo `TextSpan` del voto è assente
      (niente spazio finale residuo) quando `descrizione.voto == null`.
- Area sotto la barra: `LayoutBuilder` + `Stack` con due immagini PNG
  (`assets/images/`):
  - `double_court_bg.png` (campo doppio, rapporto 1200:600): centrato
    orizzontalmente con margine sinistro/destro pari al **21%** della
    larghezza disponibile (occupa il 58% restante — rimpicciolito da 70%/15%
    di margine su richiesta, vedi sotto), **ancorato in alto** (non più
    centrato verticalmente nello spazio rimanente) con margine fisso
    `_kCourtTopMargin = 16.0` (`Positioned(top: _kCourtTopMargin, left: 0,
    right: 0, child: Center(...))` — il `Center` interno mantiene la
    centratura orizzontale). Stesso valore riusato come `courtTop` in
    `_buildLiberoSwapTokens`/`_buildBattitoreTapCatcher` (Stack esterno,
    coordinate schermo assolute): deve restare identico, altrimenti
    libero/battitore fuori campo si disallineano dal campo disegnato.
    Dimensionato con `AspectRatio` — si
    scala con lo schermo, nessuna dimensione fissa in px. **Cambiare questa
    percentuale è sempre sicuro**: tutte le posizioni dei token (attacco,
    ricezione, battitore fuori campo) sono coordinate di riferimento nello
    spazio 1200×600, convertite a runtime in base alla dimensione reale del
    campo (`cw`/`ch`) — e il raggio dei token è `ch/20 × _kTokenSizeScale`,
    quindi anch'esso proporzionale. Nessuna tabella di posizioni va toccata
    quando si ridimensiona il campo. La mini-map e i suoi margini sono
    invece percentuali indipendenti dello schermo (non del campo), quindi
    non seguono questo ridimensionamento a meno di cambiarle a parte.
    Avvolto in un `LayoutBuilder` interno che espone la dimensione renderizzata
    reale (`cw`/`ch`), usata per scalare le posizioni dei token giocatore.
  - `small_court.png` (campo singolo piccolo, overlay in alto a sinistra):
    `Positioned` con margine **5% top**, **3% left**, lato quadrato pari al
    **7%** della larghezza disponibile (proporzionato al campo grande).
    Avvolto in un `Container` con bordo bianco (2px, raggio 6) + `ClipRRect`
    interno — la "card" della mini-map.
- **Badge di rotazione** sul campo piccolo: card rettangolare (50% larghezza ×
  1/3 altezza del campo piccolo, angoli smussati, bordo bianco 2px) con il
  numero di posizione del palleggiatore (`palleggiatoreSlot`, es. "P1"), testo
  bianco bold, sfondo = colore maglia squadra scurito (`AppColors.darken(...)`).
  Ancorata con `Align` (non `Positioned` con offset) così resta **sempre
  dentro i confini** del campo piccolo, flush contro l'angolo/lato corretto —
  niente di sporgente a cavallo del bordo.
  - Mappa `_kRotationBadgeAnchor` in `scout_screen.dart`: il campo piccolo è
    ruotato di 90° in senso orario rispetto a `LineupScreen`, quindi P1→
    `Alignment.bottomLeft`, P2→`bottomRight`, P3→`centerRight` (lato rete),
    P4→`topRight`, P5→`topLeft`, P6→`centerLeft` (girando in senso
    antiorario a partire da P1).
- **Bottoni di rotazione** appena sotto la mini-map (`top: 5%+smallCourtSize+8`),
  affiancati con `Row(spaceBetween)`: quadrati arrotondati blu scuro
  (`0xFF00008A`), icona bianca, stessa ombra dei token giocatore. Sinistro
  (`Icons.rotate_right`) → `_rotateBackward` (palleggiatore P1→P6); destro
  (`Icons.rotate_left`) → `_rotateForward` (palleggiatore P1→P2) — icone
  scambiate rispetto al verso intuitivo per scelta visiva.
  - **`ScoutScreen` è uno `StatefulWidget`** (`_ScoutScreenState`) proprio per
    questo: lo stato `_rotationSteps` (int, positivo = avanti, negativo =
    indietro, nessun wraparound esplicito perché `_mod()` lo gestisce ad ogni
    lettura) tiene il numero di rotazioni applicate da inizio set.
  - `_currentSlot` e `_currentAssignments` sono **getter derivati** da
    `_rotationSteps` (non stato salvato a parte): `_currentSlot` sposta
    l'indice di `widget.palleggiatoreSlot` in `_kSlotOrder`;
    `_currentAssignments` ricostruisce la mappa slot→giocatore intera
    facendo scorrere **tutti** i 6 giocatori insieme (chi era allo slot di
    indice `j` si trova ora a `j + _rotationSteps`) — non solo l'indicatore
    del palleggiatore. `roleLabelsFor` viene chiamata con
    `_currentAssignments`, quindi le etichette di ruolo seguono
    automaticamente ogni giocatore mentre la squadra ruota.
- **Cambio campo** (voce "Cambia campo" nel drawer di utilità, vedi sopra):
  stato `_isRightSide` (bool) + `_toggleSide()`. Quando attivo, le posizioni
  dei token vengono riflesse tramite `_displayPosition()`: **rotazione di
  180°** rispetto al centro dell'immagine doppia (non un mirror orizzontale
  semplice) — `x' = 1200 - x`, `y' = 600 - y`. Es. P1 (200,470, basso-sx) →
  (1000,130, alto-dx). Verificato che la trasformazione mantiene la rete
  sempre adiacente al centro (x≈600) e il fondo campo sempre vicino al bordo
  esterno, per entrambi i lati.
  - **Mini-map e bottoni di rotazione seguono il lato**: `minimapLeft`
    calcolato con lo stesso margine 3% applicato da destra invece che da
    sinistra quando `_isRightSide`. La mini-map stessa viene ruotata di 180°
    (`Transform.rotate(angle: math.pi)`); l'ancoraggio del badge di rotazione
    segue la stessa rotazione (`Alignment(-x, -y)` quando `_isRightSide`),
    mentre il testo del badge resta dritto e leggibile (non ruotato).
- **Dimensione dei token** (`_kTokenSizeScale = 1.4`, in cima al file):
  fattore di scala unico applicato al raggio "base" (un ventesimo del campo)
  di **tutti** i token giocatore — su campo (`_buildPlayerToken`), libero in
  campo/panchina e battitore fuori campo (`_swapTokenRadius`, Stack
  **esterno**) e L2 fisso ad angolo (`_buildLiberoTokens`). Le tre formule
  derivano dallo stesso raggio base e vanno scalate **insieme**, altrimenti i
  token finiscono disallineati in dimensione tra Stack interno (coordinate di
  riferimento 1200×600) ed esterno (pixel schermo assoluti). Aumentato da
  `1.0` a `1.4` dopo test su tablet fisico (token troppo piccoli) — di
  conseguenza anche `_kBattutaP1Position` è passato da X=-60 a X=-70 (stesso
  margine visivo di distacco dal campo con il token più grande).
  **Verificato** dallo sviluppatore a video su tutte e 6 le rotazioni in
  modalità test: con token più grandi 3 posizioni risultavano troppo vicine
  a un token adiacente, corrette in entrambe le tabelle
  (`_kDefensePositionsCentrali`/`_kDefensePositionsSchiacciatori`, stesso
  valore in entrambe per i ruoli condivisi — vedi sopra): P6 ruolo `P`
  X 498→470; P4 ruolo `C2` X 482→460; P3 ruolo `C2` X 480→470 (solo X, Y
  invariata in tutti i casi); P4 ruolo `O` X 188→184→180, Y 542→546→550 (due
  aggiustamenti successivi di -4/+4).
- **Token giocatore (posizioni di attacco)** sul campo grande: 6 cerchi con
  raggio **1/20 × `_kTokenSizeScale`** del campo (un singolo campo è un
  quadrato 600×600 nello spazio di riferimento 1200×600 di
  `double_court_bg.png`), sfondo = **colore maglia squadra raw**
  (`Color(team.coloreDivisa)`, niente scurimento — vedi nota sul
  refactoring colori sotto), bordo bianco 2px, ombra (`BoxShadow` nero 47%
  opacità, blur 4, offset verticale 2).
  - Posizioni fisse `_kAttackPositions` (coordinate di riferimento 1200×600,
    lato sinistro — riflesse a destra da `_displayPosition()` se
    `_isRightSide`): P1(200,470) P2(530,470) P3(530,300) P4(530,130)
    P5(200,130) P6(200,300). Scalate a runtime con `cw/1200` e `ch/600`.
  - **Fasi di gioco e posizioni**: quale coordinata usare per ogni slot
    dipende da chi è al servizio. `_squadraAlServizio` (getter) legge
    `_setCorrente?.squadraServizioIniziale` — provvisorio: finché non si
    registrano azioni vere e non si richiama `ricalcolaStato()` sugli eventi
    reali, coincide sempre con chi serviva per primo nel set (nessun punto
    ancora segnato può averlo cambiato). `_refPositionFor(slot)` sceglie la
    coordinata: per **P1 quando battiamo noi** (`_squadraAlServizio ==
    Squadra.nostra`) usa `_kBattutaP1Position` (200,470 → **-60**,470: stessa
    Y, X = bordo del campo (0) meno 60, non posizione di attacco meno 60 —
    il battitore deve stare FUORI dal campo, X negativa) — per tutti gli
    altri slot, e per P1 quando non battiamo noi, usa
    `_kAttackPositions[slot]`. Passa comunque per `_displayPosition()` come
    tutte le altre coordinate, quindi si specchia automaticamente col cambio
    campo, nessuna logica separata necessaria. Lo `Stack` del campo grande
    (quello con `Image.asset(_kCourtImage)` + `_buildCourtTokens()`) ha
    `clipBehavior: Clip.none`: il default (`Clip.hardEdge`) taglierebbe via
    il token del battitore, che essendo a X negativa cade fuori dai confini
    dello `Stack` stesso.
    - **Posizioni di attacco per RUOLO e FASE** (IMPLEMENTATO, tutte e tre
      le varianti: "libero sui centrali", "libero sugli schiacciatori" —
      vedi sotto — e "senza libero" derivata dalle tabelle centrali).
      **Le tabelle vivono in `lib/logic/attack_positions.dart`**
      (`kAttackBattutaCentrali` ecc., ex costanti private di scout_screen,
      estratte perché condivise con le pagine attacchi del PDF —
      `_activeAttackMap` ora delega la selezione ad `attackMapFor()`):
      stesso formato delle tabelle di
      ricezione (`slot palleggiatore (P1..P6) -> ruolo -> Offset`). A
      differenza della posizione fissa per zona (`_kAttackPositions`), qui la
      posizione dipende dal **ruolo** e dalla **fase** dello scambio — in
      pallavolo reale la zona di rotazione conta solo per la legalità al
      momento del servizio, poi la squadra si sposta nella propria "forma"
      tattica (es. il palleggiatore va sempre verso la stessa zona di rete a
      prescindere dalla zona di rotazione). Le 4 fasi vere sono Battuta,
      Dopo_Battuta, Ricezione (= tabelle di difesa esistenti, invariate) e
      Dopo_Ricezione — **Dopo_Battuta e Dopo_Ricezione non sono sempre
      identiche** (dipende dalla rotazione: lo sviluppatore ha confermato che
      a volte la squadra si schiera diversamente dopo aver servito rispetto a
      dopo aver ricevuto). L'eccezione "il libero non può servire" è già
      implicita nei dati di `_kAttackBattutaCentrali`: quando il centrale di
      seconda linea sta per servire, la tabella mostra lui stesso (es. 'C2')
      invece di 'Libero' — nessuna logica extra in Dart per quel caso.
      - **Variante "libero sugli schiacciatori"** (IMPLEMENTATA):
        `_kAttackBattutaSchiacciatori`/`_kAttackDopoBattutaSchiacciatori`/
        `_kAttackDopoRicezioneSchiacciatori`, stesso formato — qui entrambi i
        centrali restano in campo, il libero sostituisce lo schiacciatore di
        seconda linea. **P3 e P6 non hanno `'Libero'` in Battuta e
        Dopo_Battuta** (a differenza di Dopo_Ricezione, dove ce l'hanno
        tutte e 6): in quelle due rotazioni lo schiacciatore che il libero
        sostituirebbe è proprio quello che deve servire in quel turno —
        stesso pattern già presente per i centrali in `_kAttackBattutaCentrali`/
        `_kAttackDopoBattutaCentrali` alla rotazione P2 (dove serve C2): per
        tutta la durata di quel turno di servizio il libero resta fuori, non
        solo per l'istante della battuta — e quindi anche in Dopo_Battuta
        compaiono entrambi gli schiacciatori reali invece di uno + `Libero`.
        Dati forniti dallo sviluppatore (CSV per rotazione/fase, stesso
        schema della variante "centrali") — **verificato un valore diverso
        nel CSV di Ricezione di P3** (palleggiatore 498,314 contro 470,314
        già presente sia in `_kDefensePositionsCentrali` che in
        `_kDefensePositionsSchiacciatori` per quella rotazione): tenuto il
        valore già a codice, le altre 35 coordinate fornite coincidevano
        esattamente con `_kDefensePositionsSchiacciatori` già esistente.
      - **`_activeAttackMap`** (getter): sceglie la tabella giusta per
        rotazione (`_currentSlot`), fase e variante (`widget.ruoloCambiLibero`
        — `centrale` o `schiacciatore`) — tabella Battuta se stiamo servendo
        e non `_faseDopo`, Dopo_Battuta se stiamo servendo e `_faseDopo`,
        Dopo_Ricezione se servono loro e `_faseDopo` (in ricezione, prima di
        `_faseDopo`, comanda `_activeDefenseMap`, non questa). La
        derivazione "senza libero" (sotto) usa sempre le tabelle "centrali"
        come base, indipendentemente da quale variante si applicherebbe se
        ci fosse un libero — non c'è alcuna sostituzione da scegliere quando
        il libero non è in formazione, quindi è equivalente.
      - **Variante "senza libero"** (`!widget.assignments.containsKey('L1')`):
        nessuna tabella dedicata — derivata al volo dalle tabelle "libero sui
        centrali" tramite `_kAttackSenzaLiberoDaCentrali(tabella, slot)`, che
        sostituisce la chiave `'Libero'` (se presente — durante l'eccezione
        del servizio la tabella è già completa, nessuna sostituzione) con il
        centrale reale di `_kRuoloSostituitoCentrali[slot]` (P1/P2/P6→C2,
        P3/P4/P5→C1 — quale dei due verrebbe sostituito dal libero, dato
        dallo sviluppatore), stessa coordinata: senza libero quel centrale
        gioca semplicemente lui stesso, nella posizione tattica che avrebbe
        occupato il libero. Nessun dato duplicato a mano.
        `_buildLiberoSwapTokens` non entra in gioco in questo caso (esce
        subito, `widget.assignments['L1'] == null`): tutti e 6 i giocatori
        passano dal ciclo normale di `_buildCourtTokens`, che non esclude
        nessuno slot (`_slotCentraleSecondaLinea` torna `null` se
        `widget.ruoloCambiLibero == null`).
      - **`_attackPosition(slot, roleLabels)`**: la funzione che `_buildCourtTokens`/
        `_buildLiberoSwapTokens`/`_buildBattitoreTapCatcher` chiamano davvero
        per ottenere la posizione di un giocatore in fase di attacco — risolve
        il ruolo dello slot (`roleLabels[slot]`) e lo cerca in
        `_activeAttackMap`; se la mappa è `null` o non contiene quel ruolo
        (variante non supportata, o ruolo sostituito dal libero), ricade su
        `_refPositionFor(slot)` (la vecchia logica generica per zona fissa).
        Iterare per **slot** (come faceva già il codice) e tradurre slot→ruolo
        dentro `_attackPosition` è equivalente a iterare per ruolo (1:1 tra
        slot e ruolo in una data rotazione): nessuna riscrittura del ciclo di
        rendering è servita, solo il lookup della posizione è cambiato.
    - **Battuta avversaria (ricezione nostra)**: `_kDefensePositions` —
      mappa `slot palleggiatore (P1..P6) -> ruolo (P/O/S1/S2/C1/C2/Libero) ->
      Offset`, tutte e 6 le rotazioni complete. **Il libero sostituisce il
      centrale di seconda linea**: per ogni rotazione la mappa contiene un
      **solo** centrale (quello a rete, che resta) + `Libero` (al posto
      dell'altro) — l'altro centrale non va disegnato in quella fase.
      - `_activeDefenseMap`: attiva solo se `_squadraAlServizio ==
        Squadra.avversari` **e** la ricezione di questo scambio non è
        ancora stata giudicata (`_fondamentaleGiudicatoRallyCorrente`,
        ignorato in modalità test) **e** c'è un libero in formazione (`L1`
        presente) **e** la mappa della rotazione corrente è completa
        (controllo di completezza tenuto per sicurezza, utile se in futuro
        si aggiungono altre fasi con dati parziali). Una volta giudicata la
        ricezione con un voto non terminale, la mappa si disattiva e
        `_buildCourtTokens()`/`_buildLiberoSwapTokens()` ricadono sulle
        posizioni di attacco: **i giocatori si spostano in posizione di
        gioco secondo la rotazione corrente**, stessa logica (e stessa
        animazione via `AnimatedPositioned`/key sul giocatore) già usata per
        il battitore dopo la battuta — nessun codice di transizione
        dedicato, è un effetto collaterale gratuito di riusare le stesse
        coordinate/key.
      - `_buildCourtTokens()`: in ricezione itera per **ruolo** sulla mappa
        di difesa — il ruolo `Libero` è saltato (`continue`, gestito a parte
        da `_buildLiberoSwapTokens` nello Stack esterno, vedi sotto), gli
        altri 5 ruoli risolvono lo slot via `roleLabelsFor` invertita e
        prendono il giocatore da `_currentAssignments`. In attacco/battuta
        (o ricezione senza dati di difesa completi) itera per **giocatore**
        sulle posizioni di attacco, applicando la stessa sostituzione
        libero↔centrale — vedi sezione dedicata sotto.
      - `_buildLiberoTokens` (i due cerchi fissi ad angolo) **esclude**
        `_liberoInCampoSlot`: il libero già disegnato sul campo non compare
        più anche ad angolo, per non duplicarlo (vale sia in ricezione sia
        in battuta).
    - In futuro probabilmente altre fasi (es. attacco dopo ricezione buona,
      muro/difesa su attacco avversario) avranno ciascuna il proprio set di
      coordinate, sempre scelto in base allo stato derivato dagli eventi.
  - **Logica del libero nelle rotazioni (IMPLEMENTATA, generale — vale sia in
    attacco/battuta sia in ricezione)**. Principio: il libero gioca solo in
    **seconda linea** (zone 1, 6, 5 — nel nostro sistema slot `P1`, `P6`,
    `P5`) e **sostituisce sempre il giocatore della coppia scelta che si
    trova lì** — i due della coppia sono opposti nella rotazione (3
    posizioni di distanza), quindi ce n'è **sempre esattamente uno** in
    seconda linea — il libero non "esce" mai, cambia solo chi sta
    sostituendo. Non è modellato come un settimo giocatore: è una
    sostituzione **derivata** dalla rotazione corrente (come tutto il resto
    dello stato), non memorizzata azione per azione.
    - **La coppia non è fissa**: in `FormationConfigScreen` il libero può
      sostituire **o i due centrali o i due schiacciatori** (mai una
      combinazione, vedi `_onCentraleSlotTap`). La scelta passa a
      `ScoutScreen` come `ruoloCambiLibero` (`Ruolo?` — `centrale`,
      `schiacciatore`, o `null` se non c'è libero), letto dal ruolo di uno
      dei due slot selezionati (`widget.assignments[_centraliSlots.first]
      ?.ruolo`).
    - `_slotCentraleSecondaLinea(roleLabels)`: trova quale slot tra
      `P5`/`P6`/`P1` ha l'etichetta della coppia giusta (`C1`/`C2` se
      `ruoloCambiLibero == Ruolo.centrale`, `S1`/`S2` se
      `Ruolo.schiacciatore`). Generale, usato dal ramo attacco/battuta di
      `_buildCourtTokens`.
    - **Coordinate di ricezione per entrambi i casi**: due tabelle separate,
      stesso formato (rotazione → ruolo → `Offset`) — `_kDefensePositionsCentrali`
      (libero sui centrali, un solo C1/C2 + S1/S2 entrambi) e
      `_kDefensePositionsSchiacciatori` (libero sugli schiacciatori, un solo
      S1/S2 + C1/C2 entrambi). `_activeDefenseMap` scelge la tabella e la
      coppia da verificare in base a `widget.ruoloCambiLibero`, con lo stesso
      controllo di completezza generalizzato (P, O, Libero, coppia fissa
      completa, coppia sostituita con un solo elemento presente).
    - **Ricezione senza libero in formazione**: stessa "forma" difensiva
      delle due tabelle sopra, ma con le posizioni REALI di tutti i 6 ruoli
      (nessuna sostituzione) — `_kDefensePositionsComplete(slot)` unisce le
      due tabelle e scarta la chiave `'Libero'`: il ruolo che in una tabella
      è sostituito dal libero è sempre presente nell'altra (dove la coppia
      sostituita è l'opposta), quindi insieme si completano. Verificato che
      i ruoli condivisi tra le due tabelle (P, O, e il centrale/
      schiacciatore "fisso" di ciascuna coppia) abbiano le stesse coordinate
      in entrambe, per tutte le 6 rotazioni — la fusione non sceglie quindi
      mai arbitrariamente tra due valori in conflitto. `_activeDefenseMap`
      ci ricade quando `widget.assignments['L1'] == null`, prima ancora di
      guardare `widget.ruoloCambiLibero` (che in quel caso è comunque
      `null`, vedi `FormationConfigScreen`).
    - **Eccezione del servizio** (zona 1 = `P1`, chi sta per servire): il
      libero non può servire — in questa fase l'app **non sostituisce mai**
      il centrale in `P1` (resta lui per il servizio, già coperto dalla
      posizione speciale `_kBattutaP1Position`). **Confermato regolamento
      2026: rimane definitivo**, non un placeholder — non serve
      l'impostazione `RegolaServizioLibero`/regola FIPAV "una rotazione"
      ipotizzata dal documento originale, quindi non implementata
      (l'eccezione del servizio resta comunque generale/corretta a
      prescindere). **Importante**: la condizione che attiva l'eccezione è
      `_squadraAlServizio == Squadra.nostra && slotCentrale == 'P1'`
      esplicitamente — **non** "`_activeDefenseMap == null` e
      `slotCentrale == 'P1'`". Bug corretto: prima dell'introduzione della
      disattivazione di `_activeDefenseMap` dopo un voto di ricezione (vedi
      sopra), le due condizioni coincidevano sempre (la mappa era `null`
      solo quando si serviva o mancavano i dati libero), quindi usare
      `defenseMap == null` come proxy funzionava. Da quando la mappa si
      disattiva anche **in ricezione già giudicata** (fase di attacco dopo
      una ricezione non terminale), quella equivalenza non vale più: con la
      vecchia condizione, il libero finiva in panchina per errore ogni volta
      che la rotazione lo portava in zona P1 durante il NOSTRO attacco (dopo
      ricezione), anche se non stavamo affatto servendo.
    - Caso limite già gestito: nessuna sostituzione se il libero non è in
      formazione (`widget.assignments['L1'] == null`) — `_buildLiberoSwapTokens`
      esce subito (`if (libero == null) return const [];`), tutti e 6 i
      giocatori passano per `_buildCourtTokens` normale. La forma difensiva
      in ricezione resta comunque quella delle tabelle (vedi
      `_kDefensePositionsComplete` sopra), solo senza alcuna sostituzione.
    - **Animazione "panchina" libero↔sostituito (IMPLEMENTATA)**: il
      sostituito (centrale/schiacciatore di seconda linea) e il libero si
      scambiano il posto a ogni rotazione/fase. La panchina deve restare
      ancorata ai **bordi reali dello schermo** (com'era la vecchia card
      fissa ad angolo), non al riquadro del campo — che è centrato con
      margini propri e quindi non coincide col bordo schermo su schermi con
      aspect ratio diversi. Per questo libero e sostituito vivono in un
      `Stack` **diverso** da quello dei 6 token "normali":
      - `_buildCourtTokens()` (Stack interno, coordinate di riferimento
        1200×600) disegna i 6 ruoli **escluso** lo slot della coppia
        cambi-libero (`_slotCentraleSecondaLinea`) — quello slot non compare
        mai qui, viene sempre gestito altrove.
      - `_buildLiberoSwapTokens()` (Stack esterno del `LayoutBuilder` del
        corpo, coordinate **pixel di schermo assolute**): calcola
        esplicitamente la trasformazione campo→schermo (`courtLeft`/
        `courtTop` dalla stessa formula di centratura usata da `Center` per
        il riquadro campo) per convertire la posizione "in campo" di
        libero/sostituito in pixel; la posizione "in panchina"
        (`_benchScreenPos`) usa invece la stessa formula della vecchia card
        fissa (margine 3% dai bordi schermo, ancorata in basso, lato secondo
        `_isRightSide`). Sia il token in campo sia quello in panchina usano
        `_buildAbsoluteToken` con la stessa `key: ValueKey(player.id)`, quindi
        `AnimatedPositioned` anima il movimento avanti e indietro tra le due
        posizioni esattamente come la rotazione — nessun salto istantaneo.
      - In ricezione (mappa di difesa attiva) il libero usa la sua posizione
        dedicata (`defenseMap['Libero']`); in battuta, o in attacco dopo una
        ricezione già giudicata (mappa disattivata, vedi sopra), prende
        esattamente il posto del sostituito (`_refPositionFor(slotCentrale)`
        — di nuovo posizione di attacco, perché `_refPositionFor` usa la
        posa di battuta solo se `_squadraAlServizio == nostra`). Eccezione
        del servizio (solo se stiamo per servire noi): il sostituito resta
        in campo nella sua posizione normale, il libero va in panchina.
    - **`_buildLiberoTokens`** ora gestisce **solo L2** (doppio libero): `L1`
      è sempre gestito da `_buildLiberoSwapTokens` (vedi sopra). Per non
      sovrapporsi visivamente, `_buildLiberoTokens` riserva il primo "slot"
      della fila (stessa size/gap) a L1 e posiziona L2 nel secondo. L2 resta
      fisso in basso, non entra mai in campo (alternanza L1/L2 non
      modellata).
    - **Backlog non implementato**: unit test della logica libero su
      tutte e 6 le rotazioni.
    - **Doppio libero attivo (IMPLEMENTATO)**: L1 entra in ricezione (avversari
      al servizio), L2 in servizio (noi al servizio) — auto-switch ad ogni
      cambio di fase (`_liberoAttivoKey` getter: legge `_squadraAlServizio`).
      Stato `_liberoOverride` (String?, default `null`): quando `null` vale la
      convenzione automatica; tap sul libero in panchina → `_liberoOverride`
      si valorizza con quel libero e la convenzione si disattiva per il resto
      del set (il tappato gioca fisso, l'altro resta in panchina — ulteriore
      tap lo rimpiazza). Reset a `null` all'inizio del set successivo (nuova
      istanza `ScoutScreen`). Entrambi i liberi sempre affiancati in basso
      (lato secondo `_isRightSide`): slot 0 = libero attivo (gestito da
      `_buildLiberoSwapTokens`), slot 1 = libero inattivo tappabile (gestito
      da `_buildLiberoTokens`, `key: 'libero-inattivo'`).
  - **Animazione di rotazione**: il rendering itera per **giocatore**
    (`currentAssignments.entries`, non più per slot fisso), e ogni token è
    un `AnimatedPositioned` con `key: ValueKey(player.id)` (non lo slot) —
    `duration: 500ms`, `curve: Curves.easeInOut`. Poiché ruolo ed etichetta
    di un giocatore sono stabili nel tempo (la stessa persona resta "S1" per
    sempre, cambia solo la posizione P che occupa), Flutter riconosce il
    widget tramite la key e ne anima fluidamente lo spostamento da una
    posizione all'altra invece di "teletrasportarlo" istantaneamente.
  - **Etichette di ruolo** (`roleLabelsFor`, estratta in
    `lib/logic/role_labels.dart` — funzione pura, testata in
    `test/logic/role_labels_test.dart`): NON un pattern fisso per
    posizione — leggono il `Ruolo` reale del giocatore assegnato a ciascuno
    slot. Il palleggiatore designato è sempre "P"; l'opposto è sempre "O"
    (trovato cercando `Ruolo.opposto` negli `assignments`, non per offset
    fisso). Tra i due schiacciatori, quello con distanza minore dal
    palleggiatore (in senso antiorario lungo `kSlotOrder`) è "S1", l'altro
    (diametralmente opposto, a 3 posizioni) è "S2" — stessa logica per i
    centrali → "C1"/"C2". Gestisce correttamente anche formazioni dove un
    centrale (non uno schiacciatore) si trova subito dopo il palleggiatore.
    - **Universale = completamento** (fix del bug "sostituzione di un
      undefined"): `Ruolo.undefined` NON è più cablato come centrale —
      gli universali riempiono le etichette MANCANTI del set canonico
      {O, S1, S2, C1, C2}, preferendo per le coppie l'universale a 3
      posizioni (opposto nel ring) dal compagno esistente, e per la 'O'
      quello opposto al P. Dopo un cambio, l'etichetta mancante è
      esattamente quella dell'uscente: l'universale ne eredita il ruolo
      tattico, e le mappe di attacco/difesa (che cercano per etichetta) si
      sistemano da sole. Universali in eccesso → senza etichetta (fallback
      griglia). Prima del fix, un universale entrato per uno schiacciatore
      produceva 3 "centrali": il terzo restava senza etichetta e il token
      SPARIVA in ricezione (mappa di difesa iterata per ruolo).
    - **`ruoloCambiLibero` non è mai più `undefined` per i NUOVI set**:
      `FormationConfigScreen._ruoloCoppiaEffettivo()` deriva sempre
      centrale|schiacciatore (coppia mista universale+reale → il ruolo del
      reale; due universali → il ruolo non coperto dai reali in campo;
      ambiguità → centrale). I check `== Ruolo.undefined` in
      `_activeDefenseMap`/`_slotCentraleSecondaLinea` restano come
      tolleranza per i set persistiti prima di questo fix.
  - **Token del palleggiatore (`label == 'P'`)**: forma distinta rispetto agli
    altri — esagono con angoli arrotondati invece di un cerchio, stesso
    colore/bordo/ombra, **10% più grande** (`tokenRadius = radius * 1.1`,
    centrato sullo stesso punto `(cx, cy)` così cresce simmetricamente senza
    spostarsi). Disegnato con `CustomPaint` + `_RoundedHexagonPainter`:
    `_roundedHexagonPath()` genera i 6 vertici e arrotonda ogni angolo con
    `quadraticBezierTo` (raggio di arrotondamento = `size.shortestSide * 0.08`,
    costante in cima al metodo `paint()`); l'ombra è disegnata con
    `canvas.drawShadow(path, Colors.black, 3, false)` (equivalente alla
    `BoxShadow` dei cerchi). Il testo resta centrato con `Center(child: text)`
    indipendentemente dalla dimensione del token.
- **Token del/dei libero** (`_buildLiberoTokens`, slot `L1`/opzionale `L2`
  letti da `widget.assignments` — non passano per `_currentAssignments`,
  **non ruotano** con P1–P6): cerchi affiancati (gap 8px) ancorati in basso
  a sinistra di default, a destra col cambio campo. Stesso meccanismo di
  posizionamento della mini-map: solo `left` con offset calcolato
  (`liberoLeft`), mai `right` — alternare `left`/`right` con `null` non si
  anima fluidamente con `AnimatedPositioned`. Colore = **invertito canale
  per canale** rispetto al colore squadra (`_invertedColor()`, stessa
  funzione duplicata in `lineup_screen.dart`), bordo e testo bianchi (stesso
  stile degli altri token, non più bordo/testo neri). Etichetta: numero di
  maglia se `_showJerseyNumbers`, altrimenti "L1"/"L2".
- **Traiettoria battuta/attacco** (IMPLEMENTATA): `TrajectoryScreen`
  (`lib/screens/live/trajectory_screen.dart`) — solo per
  `Fondamentale.richiedeTraiettoria` (battuta/attacco), qualunque voto
  (anche `errore`: ha senso vedere dove è finita una battuta in rete/fuori).
  Aperta da `ScoutScreen._registraVoto` **dopo** la scelta del voto e
  **prima** di registrare l'azione — `Navigator.push<Traiettoria>` (typedef
  `({double? x1, y1, x2, y2, muroX, muroY, required TipoBattuta
  tipoBattuta})`, coordinate normalizzate 0.0-1.0 rispetto al campo intero,
  stesso spazio di riferimento 1200×600 usato altrove). Il record tornato
  da `Navigator.pop` **non è mai `null`** (a differenza di prima): porta
  sempre almeno `tipoBattuta` (vedi sotto), con le coordinate a `null`
  quando si è saltata la traiettoria.
  **Nessun bottone "Salta"/"Conferma"**: niente `AppBar` nativa — stessa
  barra superiore custom di `ScoutScreen` (`Container` 60dp,
  `Color(0xFF0D2738)`, titolo "Imposta traiettoria" bianco bold 16px
  ancorato vicino al bordo inferiore della barra), con solo un bottone
  back a sinistra (niente menu/undo/punteggio, non pertinenti qui) — tap
  sul back senza aver disegnato nulla (`_onBack`) = pop con coordinate
  `null` ma `tipoBattuta` valorizzato (salta la traiettoria, non il tipo
  battuta); un **drag** (`onPanStart/Update/End`) dal punto di partenza a
  quello di arrivo conferma subito al rilascio
  (`Navigator.pop(context, risultato)`), niente tocco aggiuntivo. Sfondo
  schermo `Color(0xFF143E59)`, stesso di
  `ScoutScreen` (`_kBg`/`_kTopBarBg` duplicati qui per coerenza visiva,
  stesso pattern di altre costanti duplicate tra schermate). **Stessa
  dimensione/posizionamento del campo di `ScoutScreen`** (58% della
  larghezza disponibile, ancorato in alto con margine fisso 16px — non
  centrato verticalmente, stesse costanti duplicate qui per coerenza
  visiva tra le due schermate), `double_court_bg.png` (`BoxFit.contain`).
  **Banner azione** (`_buildBanner`, tra la barra superiore e il campo,
  stessa altezza fissa 36 di `ScoutScreen`): stesso testo/stile/colore di
  `ScoutScreen._descrizioneAzione` per il caso `TipoAzione.scout`
  ("Numero - Cognome - Fondamentale" + simbolo voto più grande), ma qui
  sull'azione **in corso** (passata a `TrajectoryScreen` come
  `giocatore`/`fondamentale`/`voto` — non è ancora un `ScoutAction`
  salvato a questo punto del flusso, quindi si formatta direttamente dai
  tre parametri invece che da una riga DB). **Spacer di 60px** tra barra
  superiore e banner (`SizedBox(height: 60)`, prima del banner): qui non
  c'è la riga dei bottoni rapidi di `ScoutScreen` (padding verticale 8 +
  bottoni 44 + 8 = 60px) — senza questo spacer banner e campo
  risulterebbero più in alto rispetto a `ScoutScreen`, a parità di
  margine interno del campo (stesso `_kCourtTopMargin`).
  **Tipo battuta/attacco** (`_mostraTipoBattuta`/`_mostraTipoAttacco`, mai
  entrambe — dipendono dallo stesso `widget.fondamentale`): riga
  orizzontale di chip (4 per la battuta, 3 per l'attacco —
  `_buildRigaTipoBattuta`/`_buildRigaTipoAttacco`, entrambe su
  `_buildTipoChip`) ancorata subito sotto al campo (`top: courtTop +
  courtHeight + 24`, dentro lo stesso Stack — c'è spazio perché il campo,
  largo il 58% dello schermo, è molto più basso dell'area disponibile).
  Per la battuta, stato locale `_tipoBattuta` inizializzato da
  `widget.tipoBattutaIniziale` (il valore "armato" corrente letto da
  `ScoutScreen`) e il valore finale torna nel campo `tipoBattuta` del
  risultato (sia da `_onPanEnd` sia da `_onBack`) — così la scelta non si
  perde nemmeno saltando la traiettoria, e resta "armata" per il prossimo
  battitore uguale. Per l'attacco, stato locale `_tipoAttacco` **senza**
  un valore iniziale da `ScoutScreen` (parte sempre da `nonSpecificato`,
  mai "armato" — vedi sopra), ma torna comunque nel campo `tipoAttacco`
  del risultato per lo stesso motivo (non perderlo se si salta la
  traiettoria dopo averlo scelto). Entrambi spostati qui da `ScoutScreen`
  (erano griglie/righe nel pannello voto) per sgombrare quel pannello,
  già pieno.
  `CustomPaint` (`_FrecciaTraiettoriaPainter`) disegna la
  freccia in tempo reale durante il drag (linea + punta a "V" + pallino sul
  punto di partenza), colore/spessore da `CourtStyle.trajectoryArrow`/
  `trajectoryWidth`. **Pallonetto**: se `_tipoAttacco == TipoAttacco.pallonetto`,
  il drag viene disegnato come arco bezier quadratica (stesso offset 40px e
  stessa logica di tangente del painter del report) — muro prevale sull'arco
  se presente. **Tocco a muro**: due segmenti dritti con pallino sullo snodo
  (invariato). Stessa costante `_kArcOffset = 40.0` locale al painter./
  `trajectoryWidth` (già definiti, prima mai usati in UI). **Drag
  catturabile anche fuori dal riquadro del campo** (es. il battitore dietro
  la linea di fondo per la battuta): `GestureDetector` sullo Stack
  **esterno** (coordinate assolute dell'area sotto banner, non del solo
  riquadro 1200×600) — stessa tecnica di
  `ScoutScreen._buildBattitoreTapCatcher`. Le coordinate normalizzate si
  calcolano sottraendo `courtLeft`/`courtTop` e dividendo per
  `courtWidth`/`courtHeight` (il riquadro del campo), **non clampate**: un
  punto fuori dal campo produce valori `<0` o `>1`, coerente con
  `_kBattutaP1Position` (X negativa) usata altrove per lo stesso scopo.
  **`behavior: HitTestBehavior.opaque`** sul `GestureDetector` (bug
  riscontrato: senza, il default `deferToChild` cattura il gesto solo se
  un figlio occupa quel punto — fuori dal riquadro campo non c'è nessun
  figlio lì, quindi un drag poteva **continuare** fuori una volta già
  agganciato, ma non **iniziare** da fuori: l'utente lo ha notato subito
  provandolo).
  L'azione si
  registra **una sola volta** in `ScoutScreen` al ritorno da questa
  schermata (con le coordinate se fornite, altrimenti `null` su tutte e
  quattro) — mai un insert-poi-update separato. Conseguenza gratuita:
  l'**undo** esistente (`annullaUltimaAzione`, elimina la riga con
  `ordine` massimo) cancella già azione e traiettoria insieme, sono la
  stessa riga `ScoutAction` — nessun codice in più necessario.
- **Tocco a muro simulato durante il drag** (solo attacco — schema v10,
  aggiunge `ScoutActions.traiettoriaMuroX`/`traiettoriaMuroY`, nullable):
  se il drag si **sofferma** sulla rete (fascia di tolleranza
  `_kToleranzaRete = 24px` attorno a x normalizzata 0.5, qualunque y —
  "tutta la linea a metà campo" — per almeno `_kSoffermamentoRete = 300ms`),
  si fissa quel punto come `_puntoMuro` e la freccia continua da lì fino al
  rilascio, con uno snodo visibile (due segmenti invece di una linea
  dritta). **Richiede una sosta deliberata, non un semplice
  attraversamento** (un attacco normale che passa sopra la rete durante un
  drag continuo non deve attivarlo) — il dwell-time non può basarsi solo
  sugli eventi `onPanUpdate` (che non arrivano se il dito resta fermo: zero
  movimento = zero eventi), quindi si usa un `Timer` avviato quando il dito
  entra nella fascia di tolleranza (`_inZonaRete` passa a `true`) e
  annullato se ne esce prima che scada (`_timerMuro?.cancel()`, anche in
  `_onPanEnd`/`dispose`); se il timer arriva a scadenza, scatta il tocco.
  **Feedback visivo**: appena `_inZonaRete` diventa `true` (e finché
  `_puntoMuro` resta `null`), una linea gialla (10px, ingrandita da 3px —
  troppo sottile per notarla) sovrapposta alla rete, alta come il campo,
  segnala che il dito è nella fascia —
  sparisce se si esce dalla fascia in tempo o appena il tocco scatta (da lì
  in poi lo snodo della freccia parla da sé). **Solo per
  `Fondamentale.attacco`** (`_muroConsentito`): per la battuta
  attraversare la rete è normale (ogni servizio legale la attraversa),
  quindi lì non si attiva nessuna logica di "tocco". Il punto del muro è
  **salvato** (non solo un aiuto visivo) — `Traiettoria` ora porta anche
  `muroX`/`muroY` (nullable), passati a `registraAzioneScout()` come
  `traiettoriaMuroX`/`traiettoriaMuroY`.
  - **Da provare in futuro (non ancora deciso)**: lo sviluppatore non è
    sicuro che il dwell-time (sosta col dito fermo) sia comodo da usare.
    Alternativa proposta da testare: **stacco e ripresa del dito** invece
    di sosta — si comincia il drag, si stacca il dito vicino alla rete
    (quello fissa il punto di rottura, niente timer), poi si ricomincia un
    nuovo drag che continua dal punto di rottura fino al rilascio finale.
    Richiederebbe ripensare il ciclo di vita del gesto (oggi un solo
    `onPanStart`/`onPanEnd` per tutta la traiettoria, qui ce ne vorrebbero
    due collegati dallo stato `_puntoMuro` già esistente).
- **Refactoring colori (importante)**: il colore squadra è mostrato **sempre
  raw** (`Color(team.coloreDivisa)`), in ogni schermata che lo usa —
  `teams_screen`, `team_selection_screen`, `team_form_screen` (incluso il
  color picker), `lineup_screen`, `scout_screen`. Provato uno scurimento
  globale via `AppColors.darken()` ma annullato su richiesta: troppo
  invasivo applicato indistintamente. L'unica eccezione è il **libero**, che
  usa il colore invertito (non scurito) per richiamare la maglia diversa —
  vedi sopra. Il colore di **sfondo** resta sempre raw/invertito senza
  eccezioni; solo il colore del **testo/numero sopra** quello sfondo usa
  `contrastingTextColor()` (vedi Modello dati → `jerseyPalette`) invece di
  un bianco fisso, da quando il bianco è stato aggiunto alla palette
  (altrimenti un numero bianco su sfondo bianco sarebbe invisibile).
- **Lista giocatori in `TeamFormScreen`** (`_PlayersSection`): stesso
  trattamento di ingrandimento applicato altrove dopo test su tablet fisico
  — avatar raggio 24, numero 20px, nome/cognome 20px bold, ruolo 16px,
  chevron 28px. Avatar del **libero** con colore invertito (`_invertedColor()`,
  stessa funzione duplicata anche qui) invece del colore squadra raw — unica
  eccezione, coerente con `lineup_screen`/`scout_screen`.
- L'unica logica presente finora è l'**avvio del set** (dialog "Chi serve per
  primo?", creazione `MatchSet`/`Rotation` iniziale — vedi sezione Modello
  dati) e il flusso a 3 tocchi giocatore→fondamentale→voto con traiettoria
  per battuta/attacco — vedi le voci IMPLEMENTATE sopra.

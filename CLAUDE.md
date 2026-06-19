# CLAUDE.md — Volley Scout

Contesto persistente del progetto per Claude Code. Leggere questo file all'inizio
di ogni sessione prima di proporre modifiche.

---

## Cos'è l'app

App **Android** (con possibile porting iOS futuro) per fare lo **scout di partite
di pallavolo**: si registrano le azioni di gioco (battuta, ricezione, attacco,
ecc.) con un voto e, per alcuni fondamentali, una traiettoria, per poi produrre
statistiche esportabili in PDF.

Sviluppatore: esperto di Unity, relativamente nuovo a Flutter/Dart. Preferisce
procedere **un pezzo alla volta**, testando sull'emulatore ad ogni passo.

---

## Stack tecnico

- **Flutter / Dart**
- **drift** (database locale SQLite, con code generation via build_runner)
- **flutter_riverpod** (state management)
- Per le fasi successive: **pdf** + **printing** (export), **share_plus** (condivisione)
- Target: **solo orientamento orizzontale (landscape)**

Package già installati:
`flutter_riverpod drift sqlite3_flutter_libs path_provider path`
dev: `drift_dev build_runner`

---

## Convenzioni e decisioni architetturali (IMPORTANTI)

1. **Repository pattern obbligatorio**: la UI non parla mai direttamente col
   database. Ogni schermata usa un repository tramite provider riverpod.
   Questo è il vincolo architetturale chiave per mantenere il codice modificabile.

2. **Solo landscape**: forzato sia in `main.dart`
   (`SystemChrome.setPreferredOrientations` con landscapeLeft/Right) sia nel
   manifest Android (`android:screenOrientation="sensorLandscape"`).

3. **Stream-based**: i repository espongono `Stream` (drift `.watch()`), così le
   schermate si aggiornano automaticamente a ogni modifica del DB.

4. **Enum salvati come testo** nel DB (tramite TypeConverter), per leggibilità e
   robustezza all'aggiunta di nuovi valori.

5. **Codegen**: dopo ogni modifica alle tabelle drift, rilanciare
   `dart run build_runner build`.

6. Lingua dell'interfaccia e dei label: **italiano**.

7. **`@DataClassName`**: usare sempre l'annotazione sulle tabelle drift il cui
   plurale darebbe una data class storpiata (es. `VolleyMatches` → drift genera
   `VolleyMatche`). Soluzione: `@DataClassName('VolleyMatch')` sopra la classe
   tabella. Il Companion mantiene sempre il nome della tabella: `VolleyMatchesCompanion`.

8. **`Stack` e vincoli "loose"**: se un widget a dimensione fissa (es. una card
   che deve riempire una cella) viene messo come figlio NON-positioned di uno
   `Stack`, lo `Stack` gli passa vincoli "loose" (max = spazio disponibile, ma
   min = 0) e il widget si rimpicciolisce per adattarsi al contenuto invece di
   riempire lo spazio — anche se il `Stack` stesso riceve vincoli rigidi dal suo
   parent. Capitato più volte in `lineup_screen.dart`. Soluzione: avvolgere quel
   figlio in `Positioned.fill(child: ...)` (così riceve vincoli rigidi a piena
   dimensione) e usare `Positioned` per gli elementi overlay (badge, icone).

---

## Struttura cartelle

```
lib/
├── main.dart                     (app + HomeScreen con menu; usa AppTheme.light)
├── models/
│   └── enums.dart                (Ruolo, Categoria, Voto + jerseyPalette)
├── data/
│   ├── database.dart             (tabelle Teams, Players, VolleyMatches + AppDatabase)
│   └── database.g.dart           (generato, non editare a mano)
├── providers/
│   └── database_provider.dart    (TeamRepository + MatchRepository,
│                                   tutti i provider: teamsStream, playersStream,
│                                   matchesStream)
├── screens/
│   ├── teams/
│   │   ├── teams_screen.dart      (lista squadre + FAB nuova squadra)
│   │   ├── team_form_screen.dart  (crea/modifica/elimina squadra;
│   │   │                           layout 2 colonne: form | lista giocatori)
│   │   └── player_form_screen.dart (crea/modifica/elimina giocatore)
│   ├── matches/
│   │   ├── matches_screen.dart        (lista partite + FAB + bottone "Inizia" per card)
│   │   ├── match_form_screen.dart     (crea/modifica/elimina partita)
│   │   └── team_selection_screen.dart (scelta squadra prima dello scout;
│   │                                   label dinamica casa/trasferta, crea al volo)
│   └── live/
│       ├── lineup_screen.dart            (selezione formazione di partenza: griglia 3×2 +
│       │                                  libero, assegnazione giocatori, conferma)
│       ├── formation_config_screen.dart  (sistema di gioco + conferma palleggiatore/
│       │                                  cambi del libero, vedi sezione navigazione)
│       └── scout_screen.dart             (setup grafico Fase 3 in corso: sfondo, barra
│                                          top, campo doppio + campo piccolo)
├── theme/
│   ├── app_colors.dart            (palette brand + colori semantici + superfici)
│   ├── app_spacing.dart           (AppSpacing xs/sm/md/lg/xl/xxl, AppRadius sm/md/lg/pill)
│   ├── app_typography.dart        (AppTypography.textTheme — scale tipografica, font Barlow)
│   ├── app_theme.dart             (AppTheme.light — ThemeData principale, usa i file sopra)
│   └── court_style.dart           (CourtStyle — costanti grafiche campo: colori linee,
│                                   rete, token giocatore, traiettoria, votoColor(Voto))
└── widgets/                       (vuota per ora)

assets/
├── images/         (court_bg.png, double_court_bg.png, small_court.png)
└── fonts/Barlow/    (Barlow-Regular/Medium/SemiBold/Bold.ttf — pesi 400/500/600/700)
```

---

## Tema e stili

Il tema è centralizzato in `lib/theme/`. Usare sempre queste costanti invece di
valori hardcoded in widget.

| File | Classe | Uso principale |
|---|---|---|
| `app_colors.dart` | `AppColors` | `brandPrimary` (blu 1E3A8A), `brandAccent` (ambra F59E0B), `success/warning/danger`, `surface/surfaceDim`, `darken(Color, [amount=0.25])` (scurisce un colore via HSL — usato ovunque si mostri il colore maglia di una squadra come avatar/badge: `teams_screen`, `team_selection_screen`, `team_form_screen` incluso il color picker, `scout_screen`) |
| `app_spacing.dart` | `AppSpacing` | padding/gap: `xs`=4, `sm`=8, `md`=16, `lg`=24, `xl`=32, `xxl`=48 |
| `app_spacing.dart` | `AppRadius` | border radius: `sm`=8, `md`=12, `lg`=16, `pill`=999 |
| `app_typography.dart` | `AppTypography` | `textTheme` con headlineMedium, titleLarge/Medium, bodyLarge/Medium/Small, labelLarge |
| `app_theme.dart` | `AppTheme` | `AppTheme.light` — usato in `main.dart` come `theme:` di `MaterialApp` |
| `court_style.dart` | `CourtStyle` | costanti di disegno campo (linee, rete, token, traiettoria) + `votoColor(Voto)` |

`AppTheme.light` definisce già: `filledButtonTheme` (bordi arrotondati `AppRadius.md`),
`inputDecorationTheme` (stessa curvatura), `cardTheme`, `textTheme: AppTypography.textTheme`.

**Font Barlow**: bundlato come asset locale in `assets/fonts/Barlow/` (4 pesi:
400/500/600/700), dichiarato in `pubspec.yaml` sotto `flutter: fonts:`. Scelta
deliberata rispetto al package `google_fonts`: quest'ultimo scarica i file a
runtime al primo utilizzo (richiede rete), mentre l'app deve funzionare offline
in palestra. `AppTypography.textTheme` applica `fontFamily: 'Barlow'` sopra le
dimensioni/pesi già definiti tramite `TextTheme.apply()`.

---

## Modello dati

### Implementato (Fase 1)

**Teams**: id (autoincrement), nome, categoria (enum Categoria), coloreDivisa
(int ARGB).

**Players**: id (autoincrement), teamId (FK -> Teams, cascade delete), nome,
cognome, numero (int), ruolo (enum Ruolo), scadenzaCertificato (DateTime nullable —
riservato a futura segnalazione visiva di scadenza imminente, impostabile via
date picker in `PlayerFormScreen`).

**Enum Ruolo**: palleggiatore, schiacciatore, centrale, opposto, libero, undefined.

**Enum Categoria**: under11..under18, terzaDivisione, secondaDivisione,
primaDivisione, serieD, serieC, serieB, serieB1, serieB2, serieA1, serieA2, serieA3.

**jerseyPalette**: lista fissa di JerseyColor (nome + Color): Rosso, Blu, Verde,
Giallo, Arancione, Viola, Nero.

**Enum SistemaGioco** (in `enums.dart`, usato in `FormationConfigScreen`):
palleggiatoreUnico ("Palleggiatore unico (5-1)"), doppioPalleggiatore
("Doppio palleggiatore (6-2)"). Per ora solo `palleggiatoreUnico` ha logica
implementata.

### Implementato (Fase 2 — parziale)

**VolleyMatch** (`@DataClassName('VolleyMatch')` su tabella `VolleyMatches`):
id, nome, dataOra (DateTime, salvato come int64 ms epoch da drift), inCasa (bool),
palestra (text nullable), teamId (FK -> Teams nullable, setNull on delete),
lat (real nullable), lon (real nullable).
- `lat`/`lon` riservati a futura integrazione Maps/OpenStreetMap, non visibili in UI.
- `teamId` selezionabile da `TeamSelectionScreen` (vedi flusso navigazione).
- Schema DB attuale: **v4** (v4 ha aggiunto `Players.scadenzaCertificato`).

### Da implementare nelle fasi successive (modello previsto, non ancora a DB)

**MatchSet**: id, matchId, numero, puntiCasa, puntiOspiti.

**Rotation**: setId, squadra (nostra/avversari), mappa posizione(1-6) -> giocatoreId.
La posizione 1 è il battitore. Metodo `ruotata()` per il sideout (rotazione oraria).

**ScoutAction**: id, setId, rallyId (raggruppa le azioni di uno scambio), squadra,
giocatoreId (nullable), fondamentale (enum), voto (enum), traiettoria (nullable),
ordine, timestamp, puntiCasaAlMomento, puntiOspitiAlMomento.

**Enum Fondamentale**: battuta, ricezione, alzata, attacco, muro, difesa, errore.
- Battuta e attacco richiedono la traiettoria (getter `richiedeTraiettoria`).

**Enum Voto**: perfetto (#), positivo (+), mezzoPunto (!), negativo (-), errore (=).
Già definito in `enums.dart` (campo `simbolo`); usato da `CourtStyle.votoColor()`.

**Trajectory**: partenza e arrivo come **coordinate normalizzate 0.0-1.0**
(CourtPoint x,y) rispetto al campo intero, rete a x=0.5. Non salvare pixel.
Nel DB: 4 colonne double (traiettoria_x1, y1, x2, y2).

---

## Flusso dell'app (navigazione)

- **HomeScreen**: layout landscape con area principale a sinistra (vuota per ora)
  e colonna di bottoni a destra: "Setup squadre" e "Gestione partite".
- **Flusso scout** (navigabile end-to-end fino al setup grafico di `ScoutScreen`):
  `MatchesScreen` → [Inizia] → `TeamSelectionScreen` → [Seleziona] → `LineupScreen` → [Conferma formazione] → `FormationConfigScreen` → [Inizia scout] → `ScoutScreen`
  - Il `teamId` viene salvato sulla partita nel DB al momento della selezione squadra.
  - Da `TeamSelectionScreen` si può creare una squadra al volo; la lista si aggiorna
    automaticamente via stream al ritorno.
  - `LineupScreen`: layout landscape con sfondo blu scuro; sinistra = campo fisso
    460×460dp con sfondo da PNG asset (`assets/images/court_bg.png`, dichiarato in
    `pubspec.yaml`) — le linee del campo sono nell'immagine, non più disegnate a
    codice. Griglia 3×2 sovrapposta (P1–P6 in senso antiorario), card ~112×112
    con margini asimmetrici (vicine al top della cella) + slot libero sotto
    (L1, opzionalmente L2 con checkbox "Doppio libero", stessa dimensione delle P).
    Colonna sinistra centrata e scrollabile (`SingleChildScrollView`) per evitare
    overflow su schermi piccoli. Destra = lista giocatori della squadra (grayed
    out + ✓ quando assegnati, "Aggiungi" per crearne uno al volo). Slot
    selezionato = bordo rosso; slot vuoto = sfondo `Colors.lightBlueAccent` per
    distinguerlo a colpo d'occhio dallo slot occupato (bianco pieno). Card
    giocatore: numero centrato (font 31, +20%
    rispetto all'originale) con nome/cognome ancorati in alto e ruolo ancorato
    in basso (stesso font, 13px, `height: 1.0` per interlinea compatta) — layout
    realizzato con `Stack` interno e `Positioned top/bottom` per garantire che il
    numero resti sempre centrato. Badge "✕" nero circolare a cavallo dell'angolo
    in alto a destra di ogni slot occupato (tap → rimuove il giocatore e
    riseleziona quello slot); vedi convenzione n.8 sul perché va in
    `Positioned.fill` insieme alla card e non come `Stack` annidato semplice.
    Tap giocatore (lista a destra) → assegna al posto selezionato e avanza
    automaticamente al prossimo vuoto in senso antiorario. Tap su giocatore già
    assegnato (lista o badge ✕) → deassegna. "Conferma formazione" abilitato
    solo quando P1–P6 sono tutti riempiti. La formazione è in memoria (non
    ancora persistita a DB).
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
  `Row` con bottone "menu" (`Icons.menu`, apre il drawer di utilità) a
  **sinistra** e bottone "indietro" (`Icons.arrow_back`, `Navigator.pop`) a
  **destra** (non centrato come un'AppBar standard — scelta deliberata per
  ergonomia in landscape), entrambi ancorati in basso nella barra
  (`crossAxisAlignment: CrossAxisAlignment.end`).
- **Drawer di utilità** (`_buildUtilityDrawer`, apribile via
  `_scaffoldKey.currentState?.openDrawer()` — necessario un
  `GlobalKey<ScaffoldState>` perché la barra superiore è custom, non
  un'AppBar reale): contiene i bottoni usati raramente, per non affollare
  l'area sopra il campo. Sfondo `_kBg` per coerenza col tema scuro.
  - **"Cambia campo"** (`ListTile`, icona `Icons.swap_horiz`): chiama
    `_toggleSide()` e chiude il drawer.
  - **Toggle "Mostra numeri/ruoli"** (`SwitchListTile`): stato
    `_showJerseyNumbers`, **default `true`** (numeri di maglia visibili
    appena apri lo scout). Label dinamica che descrive l'azione del tap, non
    lo stato corrente: "Mostra ruoli" quando attivo (numeri visibili),
    "Mostra numeri" quando disattivo (ruoli visibili). Quando attivo, i
    token sul campo grande mostrano `player.numero` invece dell'etichetta di
    ruolo (la forma esagono/cerchio del palleggiatore resta comunque basata
    sul ruolo, non sul numero).
- `ScoutScreen` riceve da `FormationConfigScreen`: `match`, `team`,
  `palleggiatoreSlot` (slot P1–P6 dove si trova il palleggiatore) e
  `assignments` (`Map<String, Player>` — la formazione completa, usata per
  leggere il ruolo reale di ciascun giocatore).
- Area sotto la barra: `LayoutBuilder` + `Stack` con due immagini PNG
  (`assets/images/`):
  - `double_court_bg.png` (campo doppio, rapporto 1200:600): centrato
    orizzontalmente con margine sinistro/destro pari al **15%** della
    larghezza disponibile (occupa il 70% restante), dimensionato con
    `AspectRatio` — si scala con lo schermo, nessuna dimensione fissa in px.
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
    del palleggiatore. `_roleLabelsFor` viene chiamata con
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
- **Token giocatore (posizioni di attacco)** sul campo grande: 6 cerchi con
  raggio **1/20** del campo (un singolo campo è un quadrato 600×600 nello
  spazio di riferimento 1200×600 di `double_court_bg.png`), sfondo = colore
  maglia squadra scurito, bordo bianco 2px, ombra (`BoxShadow` nero 47%
  opacità, blur 4, offset verticale 2).
  - Posizioni fisse `_kAttackPositions` (coordinate di riferimento 1200×600,
    lato sinistro — riflesse a destra da `_displayPosition()` se
    `_isRightSide`): P1(200,470) P2(530,470) P3(530,300) P4(530,130)
    P5(200,130) P6(200,300). Scalate a runtime con `cw/1200` e `ch/600`. Da
    estendere in futuro con le posizioni di ricezione.
  - **Animazione di rotazione**: il rendering itera per **giocatore**
    (`currentAssignments.entries`, non più per slot fisso), e ogni token è
    un `AnimatedPositioned` con `key: ValueKey(player.id)` (non lo slot) —
    `duration: 500ms`, `curve: Curves.easeInOut`. Poiché ruolo ed etichetta
    di un giocatore sono stabili nel tempo (la stessa persona resta "S1" per
    sempre, cambia solo la posizione P che occupa), Flutter riconosce il
    widget tramite la key e ne anima fluidamente lo spostamento da una
    posizione all'altra invece di "teletrasportarlo" istantaneamente.
  - **Etichette di ruolo** (`_roleLabelsFor`): NON un pattern fisso per
    posizione — leggono il `Ruolo` reale del giocatore assegnato a ciascuno
    slot. Il palleggiatore è sempre "P"; l'opposto è sempre "O" (trovato
    cercando `Ruolo.opposto` negli `assignments`, non per offset fisso). Tra i
    due schiacciatori, quello con distanza minore dal palleggiatore (in senso
    antiorario lungo `_kSlotOrder`) è "S1", l'altro (diametralmente opposto, a
    3 posizioni) è "S2" — stessa logica per i centrali → "C1"/"C2". Gestisce
    correttamente anche formazioni dove un centrale (non uno schiacciatore) si
    trova subito dopo il palleggiatore.
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
- Nessuna logica di scouting ancora presente: il resto di questa sezione
  descrive il design deciso ma non ancora implementato.

### Design deciso, da implementare

- Campo intero disegnato (entrambe le metà, rete al centro), i 6 giocatori della
  propria squadra come token toccabili.
- **Flusso a 3 tocchi**: giocatore -> fondamentale -> voto. L'azione viene
  registrata e tutto si resetta per la successiva.
- **Contestualità**: quando la squadra è al servizio, il giocatore in zona 1 e il
  fondamentale "battuta" sono pre-selezionati (restano solo voto + traiettoria).
- **Traiettoria**: solo per battuta e attacco. Dopo il voto si apre una seconda
  schermata col campo vuoto, dove si inserisce la traiettoria con un **drag**
  (pan): si trascina dal punto di partenza a quello di arrivo, la freccia si
  disegna in tempo reale. Possibilità di "salta traiettoria". Coordinate salvate
  normalizzate.
- In Flutter: `CustomPainter` per il campo + `GestureDetector`/`Listener`
  (onPanStart/Update/End) con `touch-action: none` equivalente. Convertire
  `localPosition` in coordinate normalizzate.

---

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
  - [ ] **PROSSIMO**: logica vera e propria — CustomPainter campo intero,
        token giocatori toccabili, flusso 3 tocchi (giocatore → fondamentale → voto),
        registrazione ScoutAction a DB, traiettorie via drag.
  - [ ] Modello DB: tabelle MatchSet, Rotation, ScoutAction.
  - [ ] Logica rotazioni / sideout.

- **Fase 4 — Statistiche ed export PDF** + condivisione.

---

## Stato attuale

**Fase 1 completata. Fase 2 completata. Fase 3 in corso.**

Il flusso è navigabile end-to-end: lista partite → "Inizia" → selezione squadra →
selezione formazione (`LineupScreen`) → configurazione formazione
(`FormationConfigScreen`: sistema di gioco, conferma palleggiatore e cambi del
libero) → `ScoutScreen` (setup grafico completo: sfondo, barra top, campo
doppio + campo piccolo).
Il prossimo passo è implementare la logica vera della schermata scout:
CustomPainter del campo, token giocatori, flusso 3 tocchi e registrazione
azioni a DB.

Testato sull'emulatore Pixel 7 in landscape. Repo Git su GitHub:
github.com/Branduich/volley_scout

---

## Note operative

- Ambiente di sviluppo: Windows 11, VS Code, emulatore Pixel 7 (o device fisico).
- Modalità sviluppatore Windows attiva (necessaria per i symlink dei plugin).
- Fare **commit frequenti** dopo ogni pezzo funzionante.
- Build Android la prima volta è lenta (Gradle), è normale.

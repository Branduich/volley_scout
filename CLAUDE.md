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
│   └── enums.dart                (Ruolo, Categoria, Voto, SistemaGioco, Squadra,
│                                   EsitoPunto + jerseyPalette)
├── logic/
│   └── ricalcola_stato.dart      (funzione pura ricalcolaStato() — punteggio/
│                                   rotazione derivati dalle azioni di scout,
│                                   nessuna dipendenza da DB/UI; vedi Modello dati)
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

test/
├── widget_test.dart       (smoke test HomeScreen)
└── logic/
    └── ricalcola_stato_test.dart  (14 test su ricalcolaStato(), `flutter test`)
```

---

## Tema e stili

Il tema è centralizzato in `lib/theme/`. Usare sempre queste costanti invece di
valori hardcoded in widget.

| File | Classe | Uso principale |
|---|---|---|
| `app_colors.dart` | `AppColors` | `brandPrimary` (blu 1E3A8A), `brandAccent` (ambra F59E0B), `success/warning/danger`, `surface/surfaceDim`, `darken(Color, [amount=0.25])` (scurisce un colore via HSL — **non più usato da nessuna schermata** dopo il refactoring colori, lasciato disponibile per un eventuale uso futuro nello scout) |
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
palestra (text nullable), avversario (text nullable), teamId (FK -> Teams
nullable, setNull on delete), lat (real nullable), lon (real nullable).
- `lat`/`lon` riservati a futura integrazione Maps/OpenStreetMap, non visibili in UI.
- `avversario`: nome squadra avversaria, opzionale, impostabile in
  `MatchFormScreen` tra il blocco data/ora e il toggle "In casa". Se non
  impostato, `ScoutScreen` mostra "AVVERSARI" come placeholder nel titolo.
- `teamId` selezionabile da `TeamSelectionScreen` (vedi flusso navigazione).
- `stato` (enum StatoPartita) e `setCorrente` (int): aggiunti in v6. Impostati
  a `configurazione`/`1` alla creazione (`MatchFormScreen`); `ScoutScreen`
  porta `stato` a `inCorso` non appena si risponde al dialog "Chi serve per
  primo?" (vedi sotto).
- Schema DB attuale: **v7** (v6 ha aggiunto `stato`/`setCorrente` + le tabelle
  `MatchSets`/`Rotations`/`ScoutActions`; v7 ha aggiunto
  `MatchSets.squadraServizioIniziale`).

### Implementato (Fase 3 — parziale): avvio dello scout

**`MatchSet`** (tabella `MatchSets`): id, matchId (FK cascade), numero,
aperto (bool, default true), `squadraServizioIniziale` (enum Squadra — chi
serve per primo nel set; input necessario a `ricalcolaStato()`, non
derivabile dagli eventi). Niente `puntiCasa`/`puntiOspiti` salvati (si
derivano da `ScoutAction`, non ancora implementata).

**`Rotation`** (tabella `Rotations`): id, setId (FK cascade), squadra (enum
Squadra — solo `nostra` viene scritta), posizione (1-6), giocatoreId (FK
cascade su Players). Una riga per posizione (6 righe per set, popolate dalla
formazione confermata).

**`MatchSetRepository`** (`lib/providers/database_provider.dart`):
- `creaPrimoSet(matchId, servizioIniziale)`: inserisce il `MatchSet` numero 1.
- `salvaRotazioneIniziale(setId, assignments)`: estrae solo gli slot
  `P1`..`P6` dalla mappa `assignments` di `LineupScreen`/`FormationConfigScreen`
  (ignora `L1`/`L2`, il libero non ha una posizione di rotazione) e inserisce
  le 6 righe `Rotation` con `squadra: Squadra.nostra`.

**Dialog "Chi serve per primo?" in `ScoutScreen`**: `ScoutScreen` è ora
`ConsumerStatefulWidget` (serve `ref` per i repository). In `initState`, se
`widget.match.stato != StatoPartita.inCorso`, dopo il primo frame
(`addPostFrameCallback`) mostra un `AlertDialog` non dismissibile con due
bottoni (nome nostra squadra / nome avversario o "Avversari"). Alla scelta,
`_iniziaSet()`: porta `VolleyMatch.stato` a `inCorso`, crea il `MatchSet` e
la rotazione iniziale, salva il `MatchSet` risultante in `_setCorrente`
(stato locale — verrà usato dal prossimo pezzo, la registrazione delle
azioni). Se la partita è già `inCorso` (ripresa, quando esisterà quel
flusso), il dialog non viene mostrato.

### Da implementare nelle fasi successive (modello previsto, non ancora a DB)

**Principio architetturale chiave: stato derivato dagli eventi.** Punteggio e
rotazione correnti NON si salvano come stato mutabile: si **ricalcolano**
rigiocando la sequenza ordinata di `ScoutAction` di un set (event sourcing
leggero).

**`ricalcolaStato()` (IMPLEMENTATA, isolata dal resto)**: `lib/logic/ricalcola_stato.dart`,
testata in `test/logic/ricalcola_stato_test.dart` (14 test, tutti verdi).
Deliberatamente **disaccoppiata da Drift/DB**: non usa la futura tabella
`ScoutActions` ma un typedef minimale `AzioneScout = ({int ordine, EsitoPunto
esitoPunto})` — gli unici due campi che servono a questo calcolo (giocatore,
fondamentale, voto, traiettoria non influenzano punteggio/rotazione). Quando
esisterà la tabella reale, il repository estrarrà questi due campi dalle righe
DB prima di chiamare la funzione.
- Firma: `StatoSet ricalcolaStato({required List<AzioneScout> azioni,
  required Squadra servizioIniziale, required Map<int,int> rotazioneIniziale})`.
  Stato iniziale passato come parametro (non letto da DB): la funzione resta
  pura e testabile senza mock.
- Ordina le azioni per `ordine` prima di rigiocarle (resiliente a input non
  ordinato).
- Logica: `puntoNostro` mentre il servizio non era nostro → sideout, ruota
  (`_ruotata`, oraria) e passiamo al servizio; `puntoNostro` mentre servivamo
  già → solo punteggio, nessuna rotazione. `puntoAvversario` → passano loro al
  servizio (punteggio + cambio `squadraAlServizio`), ma **nessuna rotazione
  nostra** (è il loro sideout, e non tracciamo il loro roster). `nessuno` →
  no-op.
- `StatoSet` (risultato): punteggio nostro/avversario, `squadraAlServizio`,
  `rotazione` (Map posizione→giocatoreId). `==`/`hashCode` ridefiniti per
  confrontare il contenuto della mappa nei test, non l'identità.
- Enum `Squadra` ed `EsitoPunto` aggiunti a `enums.dart` (servivano comunque
  alla futura tabella `ScoutActions`, quindi vivono lì e non in `logic/`).

Conseguenze del principio (ancora da implementare oltre alla funzione pura):
- Ogni azione si scrive a DB nell'istante in cui viene registrata (mai solo in
  memoria) — niente perso se l'app si chiude o il tablet si scarica.
- **Undo** = elimina l'azione con `ordine` massimo nel set, poi ricalcola.
  Nessuna logica di "inversione" manuale di punteggio/rotazione.
- **Riprendi partita** = carica le azioni del set, ricostruisci punteggio e
  rotazione con la stessa funzione di ricalcolo.
- Serve una **funzione pura** `ricalcolaStato(List<ScoutAction>)` che
  restituisce punteggio e rotazione correnti a partire dalla sequenza — è il
  cuore logico di questa fase, va testata con unit test dedicati.
- I contatori manuali di punteggio/rotazione già presenti in `ScoutScreen`
  (`_nostroScore`/`_avversarioScore`, `_rotationSteps`) sono **temporanei**:
  quando si implementa questo modello vanno sostituiti — i bottoni `-`/`+` e
  di rotazione restano nell'interfaccia, ma generano/correggono `ScoutAction`
  invece di incrementare un intero in memoria.

**Avversario resta solo testo** (`VolleyMatches.avversario`, già implementato),
**non** diventa una `Team` con roster in DB — scelta deliberata per non
obbligare a creare/gestire la squadra avversaria. Conseguenze sul modello:
- `Rotations` è popolata **solo per `squadra = nostra`**; il valore
  `avversari` resta nell'enum per un'eventuale estensione futura (roster
  avversario), ma oggi non viene mai scritto.
- `ScoutActions` per i punti avversari (bottone "+1 Loro", errori nostri)
  avranno `giocatoreId = null` — già previsto dallo schema, nessun problema.
- Limite accettato: nessuna statistica per singolo giocatore avversario.

**`ScoutAction` (tabella `ScoutActions`, SCHEMA GIÀ A DB da v6, nessuna UI/
repository la usa ancora)**: id, setId (FK cascade), rallyId (raggruppa le
azioni di uno scambio), ordine (int, progressivo nel set — per sequenza e
undo), timestamp, squadra (enum Squadra), tipo (enum TipoAzione), giocatoreId
(nullable — null per punti manuali/errori generici, FK setNull), fondamentale
(enum Fondamentale, nullable), voto (enum Voto, nullable), tipoEsecuzione
(text, default `'nonSpecificato'` — colonna polimorfica, vedi sotto),
esitoPunto (enum EsitoPunto), traiettoriaX1/Y1/X2/Y2 (double, nullable — solo
battuta/attacco), puntiCasaAlMomento/puntiOspitiAlMomento (int, nullable —
snapshot opzionale/debug, non sostituisce il ricalcolo).

**Enum TipoAzione** (in `enums.dart`): `scout` (giocatore + fondamentale +
voto), `puntoManuale` (bottoni rapidi "+1 Noi"/"+1 Loro", nessun giocatore),
`erroreGenerico` (punto all'altra squadra per errore non dettagliato).

**Enum EsitoPunto**: `nessuno` (azione interna allo scambio, non chiude il
punto), `puntoNostro`, `puntoAvversario`. Da calcolare in automatico in base a
fondamentale+voto (es. attacco/muro/battuta con voto `#` → puntoNostro;
qualunque fondamentale con voto `=` → puntoAvversario), ma **sempre
modificabile** prima di confermare l'azione — logica ancora da implementare
nell'interfaccia (lo schema/enum esistono già).

**Enum Fondamentale**: battuta, ricezione, alzata, attacco, muro, difesa, errore.
- Battuta e attacco richiedono la traiettoria (getter `richiedeTraiettoria`).
- Solo per battuta e attacco compaiono anche i bottoni contestuali del tipo di
  esecuzione (vedi sotto), opzionali e non bloccanti per il flusso veloce.

**Enum TipoAttacco**: `nonSpecificato` (default), `forte`, `piazzata`,
`pallonetto`. **Enum TipoBattuta**: `nonSpecificato` (default),
`floatStaccata`, `salto`, `saltoFloat` (terminologia da confermare). Salvati
entrambi nello stesso campo testo `tipoEsecuzione` (.name dell'enum
pertinente in base al `fondamentale` — colonna "polimorfica", la coerenza è
garantita dall'interfaccia, non dallo schema).

**Enum Voto**: perfetto (#), positivo (+), mezzoPunto (!), negativo (-), errore (=).
Già definito in `enums.dart` (campo `simbolo`); usato da `CourtStyle.votoColor()`.

**Trajectory**: partenza e arrivo come **coordinate normalizzate 0.0-1.0**
(CourtPoint x,y) rispetto al campo intero, rete a x=0.5. Non salvare pixel.
Nel DB: 4 colonne double (traiettoria_x1, y1, x2, y2).

**Bottoni rapidi sempre visibili nello scout** (percorso alternativo ai 3
tocchi): "+1 Noi" (tipo=puntoManuale, esitoPunto=puntoNostro), "+1 Loro"
(tipo=puntoManuale, esitoPunto=puntoAvversario), "Errore" (tipo=erroreGenerico,
punto alla squadra che non sbaglia).

**Query principali previste**: statistiche per giocatore/fondamentale
(filtra `tipo == scout`, esclude i punti manuali che non hanno giocatore);
statistiche per tipo di esecuzione (raggruppa attacco/battuta per
`tipoEsecuzione` — poco informative se molte azioni restano
`nonSpecificato`); punteggio e rotazione (vedi principio architetturale
sopra, su tutti gli eventi del set guardando `esitoPunto`).

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
    Icona matita (`Icons.edit`) nel `trailing` della lista, **visibile solo
    se il giocatore non è assegnato**: apre `PlayerFormScreen` per
    modificarlo. Un giocatore già in formazione non è modificabile finché
    non viene rimosso dallo slot — evita che la card sul campo mostri dati
    superati (l'oggetto `Player` in `_assignments` non si aggiorna da solo
    quando lo stream rilegge i dati modificati).
    Lista giocatori a destra: card arrotondate (`Material` + `ListTile`,
    `BorderRadius.circular(AppRadius.md)`, separate da `SizedBox(height: 8)`
    invece di `Divider`) su sfondo `_kBg` (stesso blu scuro della pagina) —
    bianca se disponibile, `Colors.grey.shade300` se già assegnato. Avatar
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
  utilità) a **sinistra** e bottone "indietro" (`Icons.arrow_back`,
  `Navigator.pop`) a **destra** (non centrato come un'AppBar standard —
  scelta deliberata per ergonomia in landscape). `Stack(alignment:
  Alignment.bottomCenter)`: sia il titolo sia la riga di icone sono ancorati
  vicino al **bordo inferiore** della barra, non centrati verticalmente.
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
  spazio di riferimento 1200×600 di `double_court_bg.png`), sfondo = **colore
  maglia squadra raw** (`Color(team.coloreDivisa)`, niente scurimento — vedi
  nota sul refactoring colori sotto), bordo bianco 2px, ombra (`BoxShadow`
  nero 47% opacità, blur 4, offset verticale 2).
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
    Squadra.nostra`) usa `_kBattutaP1Position` (200,470 → **140**,470: stessa
    Y, X -60 verso la linea di fondo, fuori dalle posizioni di attacco) —
    per tutti gli altri slot, e per P1 quando non battiamo noi, usa
    `_kAttackPositions[slot]`. Passa comunque per `_displayPosition()` come
    tutte le altre coordinate, quindi si specchia automaticamente col cambio
    campo, nessuna logica separata necessaria.
    - **Battuta avversaria (ricezione nostra)**: `_kDefensePositions` —
      mappa `slot palleggiatore (P1..P6) -> ruolo (P/O/S1/S2/C1/C2/Libero) ->
      Offset`, tutte e 6 le rotazioni complete. **Il libero sostituisce il
      centrale di seconda linea**: per ogni rotazione la mappa contiene un
      **solo** centrale (quello a rete, che resta) + `Libero` (al posto
      dell'altro) — l'altro centrale non va disegnato in quella fase.
      - `_activeDefenseMap`: attiva solo se `_squadraAlServizio ==
        Squadra.avversari` **e** c'è un libero in formazione (`L1` presente)
        **e** la mappa della rotazione corrente è completa (controllo di
        completezza tenuto per sicurezza, utile se in futuro si aggiungono
        altre fasi con dati parziali).
      - `_liberoInCampoSlot`: **semplificazione** — sempre `'L1'` quando la
        mappa di ricezione è attiva (l'alternanza L1/L2 tra rotazioni non è
        ancora modellata).
      - `_buildCourtTokens()`: in attacco/battuta itera per **giocatore**
        (come prima); in ricezione itera per **ruolo** sulla mappa di difesa
        — il ruolo `Libero` usa `_buildLiberoCourtToken` (stile invertito,
        stesso posizionamento/animazione di `_buildPlayerToken`), gli altri 5
        ruoli risolvono lo slot via `_roleLabelsFor` invertita e prendono il
        giocatore da `_currentAssignments`.
      - `_buildLiberoTokens` (i due cerchi fissi ad angolo) **esclude**
        `_liberoInCampoSlot`: il libero già disegnato sul campo non compare
        più anche ad angolo, per non duplicarlo.
    - In futuro probabilmente altre fasi (es. attacco dopo ricezione buona,
      muro/difesa su attacco avversario) avranno ciascuna il proprio set di
      coordinate, sempre scelto in base allo stato derivato dagli eventi.
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
- **Refactoring colori (importante)**: il colore squadra è mostrato **sempre
  raw** (`Color(team.coloreDivisa)`), in ogni schermata che lo usa —
  `teams_screen`, `team_selection_screen`, `team_form_screen` (incluso il
  color picker), `lineup_screen`, `scout_screen`. Provato uno scurimento
  globale via `AppColors.darken()` ma annullato su richiesta: troppo
  invasivo applicato indistintamente. L'unica eccezione è il **libero**, che
  usa il colore invertito (non scurito) per richiamare la maglia diversa —
  vedi sopra.
- L'unica logica presente finora è l'**avvio del set** (dialog "Chi serve per
  primo?", creazione `MatchSet`/`Rotation` iniziale — vedi sezione Modello
  dati). Nessuna registrazione di azioni di scout vere e proprie: il resto di
  questa sezione descrive il design deciso ma non ancora implementato.

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
  - [x] Punteggio e rotazione **provvisori** in memoria (`_nostroScore`/
        `_avversarioScore`, `_rotationSteps`) — da sostituire col modello
        event-sourced sotto, non persistiti.
  - [x] Funzione pura `ricalcolaStato()` (punteggio + rotazione derivati) +
        14 unit test — `lib/logic/ricalcola_stato.dart` /
        `test/logic/ricalcola_stato_test.dart`. Vedi dettagli nel Modello dati.
  - [x] Modello dati a DB (schema v6/v7): tabelle `MatchSet`, `Rotation`,
        `ScoutAction` (schema pronto, non ancora usata), campo
        `StatoPartita`/`setCorrente` su `VolleyMatches`, enum
        `TipoAzione`/`Fondamentale`/`TipoAttacco`/`TipoBattuta` in `enums.dart`.
  - [x] Avvio del set: dialog "Chi serve per primo?" in `ScoutScreen`,
        `MatchSetRepository.creaPrimoSet()` + `salvaRotazioneIniziale()`
        (vedi Modello dati). `VolleyMatch.stato` passa a `inCorso`.
  - [ ] **PROSSIMO**: collegare `ricalcolaStato()` ai dati reali — un
        repository per `ScoutAction` (CRUD + stream) che alimenti la funzione
        pura con le azioni del set corrente, sostituendo i contatori
        provvisori in `ScoutScreen` (`_nostroScore`/`_avversarioScore`/
        `_rotationSteps`).
  - [ ] CustomPainter campo intero, token giocatori toccabili, flusso 3 tocchi
        (giocatore → fondamentale → voto) con bottoni contestuali tipo
        esecuzione, bottoni rapidi (+1 Noi/+1 Loro/Errore), traiettorie via drag.
  - [ ] `MatchesScreen`: bottoni "Riprendi"/"Statistiche" in base a `StatoPartita`.

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

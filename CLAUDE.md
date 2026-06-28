# CLAUDE.md — Volley Scout

Contesto persistente del progetto per Claude Code. Leggere questo file all'inizio
di ogni sessione prima di proporre modifiche.

---

## Cos'è l'app

App **Android** (con possibile porting iOS futuro) per fare lo **scout di partite
di pallavolo**: si registrano le azioni di gioco (battuta, ricezione, attacco,
ecc.) con un voto e, per alcuni fondamentali, una traiettoria, per poi produrre
statistiche esportabili in PDF.

**Nome visualizzato dell'app: "Volley Stratego"** (label Android, titolo
`MaterialApp`/`HomeScreen`, `CFBundleDisplayName` iOS) — il nome del progetto/
repo/package Dart resta `volley_scout` (codename interno, non cambia: niente
rinomina del package, che richiederebbe toccare ogni `import
'package:volley_scout/...'`).

**Icona app**: generata con `flutter_launcher_icons` (config in `pubspec.yaml`)
da due varianti dello stesso logo (pallone + torre degli scacchi) in
`assets/icon/`: `icon_foreground.png` (originale, sfondo trasparente — usato
come `adaptive_icon_foreground` per le icone adattive Android 8+, composto
sopra `adaptive_icon_background: "#FFFFFF"`) e `icon.png` (stessa immagine
appiattita su sfondo bianco opaco — usata come `image_path` per le icone
legacy e iOS, che non supporta trasparenza nelle icone: `remove_alpha_ios:
true` nel config). Rigenerare con `dart run flutter_launcher_icons` se il
logo cambia.

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
│   ├── live/
│   │   ├── lineup_screen.dart            (selezione formazione di partenza: griglia 3×2 +
│   │   │                                  libero, assegnazione giocatori, conferma)
│   │   ├── formation_config_screen.dart  (sistema di gioco + conferma palleggiatore/
│   │   │                                  cambi del libero, vedi sezione navigazione)
│   │   ├── scout_screen.dart             (setup grafico Fase 3 in corso: sfondo, barra
│   │   │                                  top, campo doppio + campo piccolo)
│   │   └── end_set_screen.dart           (fine set/partita: "Prossimo Set"/"Fine Partita")
│   └── report/
│       ├── match_report_screen.dart      (Fase 4: dati partita, punteggio finale,
│       │                                  punteggio per set — raggiunta da MatchesScreen)
│       └── player_stats_screen.dart      (Fase 4: statistiche per giocatore/fondamentale,
│                                          set per set — raggiunta dal drawer di ScoutScreen)
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
- Schema DB attuale: **v9** (v6 ha aggiunto `stato`/`setCorrente` + le tabelle
  `MatchSets`/`Rotations`/`ScoutActions`; v7 ha aggiunto
  `MatchSets.squadraServizioIniziale`; v8 ha aggiunto
  `MatchSets.liberoId`/`libero2Id`/`ruoloCambiLibero`; v9 ha aggiunto
  `MatchSets.correzionePuntiNostri`/`correzionePuntiAvversari`).

### Implementato (Fase 3 — parziale): avvio dello scout

**`MatchSet`** (tabella `MatchSets`): id, matchId (FK cascade), numero,
aperto (bool, default true), `squadraServizioIniziale` (enum Squadra — chi
serve per primo nel set; input necessario a `ricalcolaStato()`, non
derivabile dagli eventi). Niente `puntiCasa`/`puntiOspiti` salvati (si
derivano da `ScoutAction`, non ancora implementata). `liberoId`/`libero2Id`
(FK nullable su Players, setNull — `@ReferenceName` dedicato su ciascuna per
evitare il clash di nome sulla relazione inversa generata da drift, dato che
sono due FK separate verso la stessa tabella) e `ruoloCambiLibero` (enum
Ruolo, nullable): formazione iniziale del set che non ha una posizione di
rotazione (vedi `Rotation` sotto), salvata qui per poter ricostruire la
formazione completa quando si riprende lo scout — vedi
`MatchSetRepository.caricaFormazione()`. `correzionePuntiNostri`/
`correzionePuntiAvversari` (int, default 0, schema v9): override manuale
del punteggio (bottoni +/- in `ScoutScreen`), si sommano al punteggio
calcolato da `ricalcolaStato()` — **non** loggati come `ScoutAction` (vedi
"Fasi di sviluppo" per la motivazione). Aggiornati da
`MatchSetRepository.correggiPunteggio()`.

**`Rotation`** (tabella `Rotations`): id, setId (FK cascade), squadra (enum
Squadra — solo `nostra` viene scritta), posizione (1-6), giocatoreId (FK
cascade su Players). Una riga per posizione (6 righe per set, popolate dalla
formazione confermata).

**`MatchSetRepository`** (`lib/providers/database_provider.dart`):
- `caricaSet(matchId, numero)`: il set con quel numero, o `null` se non
  esiste ancora — ordina per `id` decrescente e prende il primo invece di
  `getSingleOrNull()` (tollera righe duplicate già nel DB senza lanciare
  "Bad state: Too many elements", prende la più recente — bug reale
  riscontrato e corretto, vedi sotto).
- `creaSet(matchId, numero, servizioIniziale)`: inserisce un `MatchSet` con
  quel numero (non più solo il numero 1 — vale anche per "Prossimo Set" in
  `EndSetScreen`, che incrementa `VolleyMatch.setCorrente` prima di arrivare
  qui). Idempotente: se un set con quel numero esiste già, lo restituisce
  invece di duplicarlo.
- `salvaRotazioneIniziale(setId, assignments, {ruoloCambiLibero})`: estrae solo gli slot
  `P1`..`P6` dalla mappa `assignments` di `LineupScreen`/`FormationConfigScreen`
  (ignora `L1`/`L2`, il libero non ha una posizione di rotazione) e inserisce
  le 6 righe `Rotation` con `squadra: Squadra.nostra`. Salva anche
  `liberoId`/`libero2Id` (da `assignments['L1']`/`['L2']`, se presenti) e
  `ruoloCambiLibero` sul `MatchSet` stesso (un `UPDATE`, non c'entra con le
  righe `Rotation`).
- `caricaFormazione(setId)`: l'inverso di `salvaRotazioneIniziale` — ricostruisce
  `({assignments, palleggiatoreSlot, ruoloCambiLibero})` leggendo `Rotations`
  (risolvendo ogni `giocatoreId` in un `Player` con una query su `Players`;
  `palleggiatoreSlot` = lo slot del giocatore con `Ruolo.palleggiatore`) +
  `liberoId`/`libero2Id`/`ruoloCambiLibero` dal `MatchSet`. Ritorna `null` se
  il set non ha ancora righe `Rotation` (set nuovo, mai iniziato) o se manca
  un palleggiatore (dato incoerente) — in entrambi i casi il chiamante deve
  ricadere sul flusso normale di selezione formazione. Usata da
  `TeamSelectionScreen` per bypassare `LineupScreen`/`FormationConfigScreen`
  quando si riprende lo scout di un set già iniziato (vedi sotto).

**Dialog "Chi serve per primo?" in `ScoutScreen`**: `ScoutScreen` è ora
`ConsumerStatefulWidget` (serve `ref` per i repository). In `initState`,
`_avviaOCaricaSet()` prova a caricare il set numero `match.setCorrente`
(`MatchSetRepository.caricaSet`): se esiste già lo riprende direttamente
(ripresa di una partita in corso, o ritorno dopo "Prossimo Set" con il set
già creato); se non esiste — sia il primissimo set della partita (`stato`
ancora `configurazione`), sia un nuovo set dopo "Prossimo Set" (`stato` già
`inCorso`, ma `setCorrente` incrementato e quel set non ancora creato) —
mostra, dopo il primo frame (`addPostFrameCallback`), un `AlertDialog` non
dismissibile con due bottoni (nome nostra squadra / nome avversario o
"Avversari"). **Non distingue più i due casi guardando `stato`** (vecchia
logica, rimossa: causava un set "fantasma" mai creato per i set successivi
al primo). Alla scelta, `_iniziaSet()`: porta `VolleyMatch.stato` a
`inCorso` (idempotente se già tale), crea il `MatchSet` (numero
`match.setCorrente`) e la rotazione iniziale, salva il `MatchSet`
risultante in `_setCorrente` (stato locale).

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

Conseguenze del principio:
- Ogni azione si scrive a DB nell'istante in cui viene registrata (mai solo in
  memoria) — niente perso se l'app si chiude o il tablet si scarica.
- **Undo** = elimina l'azione con `ordine` massimo nel set, poi ricalcola.
  Nessuna logica di "inversione" manuale di punteggio/rotazione.
  **IMPLEMENTATO** (bottone "annulla" nella barra superiore di `ScoutScreen`,
  con dialog di conferma — vedi "Interfaccia di scout").
- **Riprendi partita** = carica le azioni del set, ricostruisci punteggio e
  rotazione con la stessa funzione di ricalcolo. **IMPLEMENTATO**:
  `ScoutScreen.initState` → `_avviaOCaricaSet()` carica direttamente il
  `MatchSet` esistente (`MatchSetRepository.caricaSet`) se c'è già, senza
  richiedere di nuovo il servizio iniziale — punteggio/rotazione/bottoni
  rapidi tornano subito attivi, qualunque sia `match.stato` (anche
  `terminata`: riprendere lo scout la riporta a `inCorso`, vedi
  "MatchesScreen a due sezioni" in Fasi di sviluppo). `MatchesScreen`
  bypassa anche `TeamSelectionScreen`/`LineupScreen`/`FormationConfigScreen`,
  ricostruendo squadra/`assignments`/`palleggiatoreSlot`/`ruoloCambiLibero`
  dalla `Rotation`/`MatchSet` già a DB via
  `MatchSetRepository.caricaFormazione()` — vedi Flusso dell'app.
- **`ScoutActionRepository`** (`lib/providers/database_provider.dart`):
  `watchAzioni(setId)` (stream ordinato per `ordine`) +
  `registraAzioneRapida({setId, squadra, tipo, esitoPunto})` (calcola il
  prossimo `ordine` con una query `MAX(ordine)` sul set, `rallyId == ordine`
  perché l'azione è da sola un intero scambio; `giocatoreId`/`fondamentale`/
  `voto`/traiettoria restano `null`, non servono ai bottoni rapidi).
- **`ScoutScreen._statoSetReale`** (getter): collega gli eventi reali a
  `ricalcolaStato()` — `null` finché `_setCorrente` non esiste (set non
  iniziato); altrimenti `ref.watch(scoutAzioniStreamProvider(setId))` +
  `_rotazioneInizialeMap` (P1..P6 di `widget.assignments` → id giocatore,
  stesso parsing di `salvaRotazioneIniziale` ma in memoria) +
  `set.squadraServizioIniziale`. Punteggio (`_punteggioNostro`/
  `_punteggioAvversario`), `_squadraAlServizio` e `_currentSlot`/
  `_currentAssignments` leggono tutti da qui fuori dalla modalità test — i
  vecchi contatori manuali (`_nostroScore`/`_avversarioScore`) sono stati
  rimossi. I bottoni di rotazione manuale (freccette accanto alla mini-map)
  e il vecchio `_rotationSteps` restano **solo per la modalità test**
  (`if (_testModeEnabled)` attorno al loro `Positioned` — fuori da lì la
  rotazione vera segue gli eventi, un contatore manuale in parallelo
  creerebbe disallineamento).
- **Bottoni rapidi** (vedi sezione dedicata sotto "Interfaccia di scout") sono
  l'implementazione di questa pipeline: ogni tap chiama
  `_registraAzioneRapida()` → `ScoutActionRepository.registraAzioneRapida()`
  → il `StreamProvider` notifica → `_statoSetReale` si ricalcola → punteggio/
  servizio/rotazione si aggiornano in UI. Nessuno stato locale duplicato.

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
punto), `puntoNostro`, `puntoAvversario`. Calcolato in automatico in base a
fondamentale+voto (`ScoutScreen._esitoVoto()`, IMPLEMENTATO): qualunque
fondamentale con voto `=` → `puntoAvversario`; solo battuta/attacco/muro con
voto `#` → `puntoNostro` (ace, schiacciata vincente, muro punto — ricezione/
alzata/difesa non vincono mai punti da sole, preparano solo la giocata
successiva). **Non ancora modificabile** prima di confermare l'azione (idea
annotata nel modello originale, non implementata — nessun bottone "cambia
esito" in UI).

**Enum Fondamentale**: battuta, ricezione, alzata, attacco, muro, difesa, errore.
Tutti tranne `errore` (mai assegnato da `ScoutScreen`, riservato a un possibile
uso futuro) sono oggi giudicabili dal pannello voto — vedi "Interfaccia di
scout" → "Voto battuta/ricezione/altri fondamentali".
- Battuta e attacco richiedono la traiettoria (getter `richiedeTraiettoria`) —
  **non ancora implementata** in UI (vedi "Design deciso, da implementare").
- Solo per battuta e attacco compaiono anche i bottoni contestuali del tipo di
  esecuzione (vedi sotto), opzionali e non bloccanti per il flusso veloce.

**Enum TipoAttacco**: `nonSpecificato` (default), `forte`, `piazzata`,
`pallonetto`. **Enum TipoBattuta**: `nonSpecificato` (default), `dalBasso`
("Dal basso"), `float`, `salto`, `saltoFloat` ("Salto float") — terminologia
confermata, i 4 tipi reali di battuta. Salvati entrambi nello stesso campo
testo `tipoEsecuzione` (.name dell'enum pertinente in base al `fondamentale`
— colonna "polimorfica", la coerenza è garantita dall'interfaccia, non dallo
schema).

**Enum Voto**: perfetto (#), positivo (+), mezzoPunto (/), negativo (-), errore (=).
Già definito in `enums.dart` (campo `simbolo`); usato da `CourtStyle.votoColor()` e
dal pannello voto battuta di `ScoutScreen` (vedi "Interfaccia di scout").

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
    520×520dp (**ingrandito da 460×460 dopo test su tablet fisico** — su
    schermo reale le card risultavano troppo piccole) con sfondo da PNG asset
    (`assets/images/court_bg.png`, dichiarato in `pubspec.yaml`) — le linee
    del campo sono nell'immagine, non più disegnate a codice. Griglia 3×2
    sovrapposta (P1–P6 in senso antiorario), card ~140×140 (margini
    `EdgeInsets.fromLTRB(16, 12, 16, 108)`, ancora asimmetrici/vicine al top
    della cella) + slot libero sotto (L1, opzionalmente L2 con checkbox
    "Doppio libero", stessa dimensione delle P — 152×152).
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
    `_votoInCorso` (record `(giocatore, fondamentale)`, `fondamentale` da
    `_fondamentaleForzato()` — `null` in fase libera, il pannello mostrerà
    prima la scelta del fondamentale).
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
  - **Pannello voto** (`_buildPannelloVoto`, ritorna una lista — vedi
    sotto): ancorato al bordo destro dello schermo (`Positioned(right: 16) +
    Center`), card scura (`_kTopBarBg`) con etichetta giocatore (numero di
    maglia, grande; sotto il cognome, più piccolo, `maxLines: 1` +
    ellissi se non ci sta) sempre visibile, poi **due possibili corpi** in
    base a `_votoInCorso.fondamentale`:
    - **`null` (fase libera)**: `_buildSceltaFondamentale()` — 4 bottoni
      rettangolari verticali (150×60, `AppColors.brandPrimary` — ingranditi
      da 110×40 dopo feedback "troppo piccoli sul device vero"), uno per
      Alzata/Attacco/Muro/Difesa. Tap → `_sceglieFondamentale(f)`: aggiorna
      `_votoInCorso` con quel fondamentale (stesso record, ora con
      `fondamentale` non nullo) — il pannello si ridisegna mostrando il
      corpo sotto.
    - **non null**: nome del fondamentale (`Fondamentale.label`) + **solo
      per battuta** la griglia tipo battuta, **solo per attacco** la riga
      tipo attacco (vedi sotto) + 5 bottoni quadrati verticali, uno per
      `Voto` (stesso ordine dell'enum: `#`/`+`/`/`/`-`/`=`), colore da
      `CourtStyle.votoColor()` (vedi sotto).
    - **Griglia tipo battuta** (IMPLEMENTATA, opzionale — "Dal basso"/
      "Float" sopra, "Salto"/"Salto float" sotto, 2×2 invece di una riga di
      4 per avere chip abbastanza grandi da toccare con precisione):
      `_tipoBattutaSelezionato` (`TipoBattuta`, default `nonSpecificato`).
      Tap su un chip → lo seleziona (sfondo/bordo `AppColors.brandAccent`);
      tap di nuovo sullo stesso chip → lo deseleziona (torna a
      `nonSpecificato`). **Non blocca il flusso veloce**: ignorarlo e
      toccare subito un voto registra comunque l'azione, con
      `tipoEsecuzione = 'nonSpecificato'` come sempre.
      - **Resta "armato" tra una battuta e l'altra dello STESSO giocatore**
        (spesso batte sempre nello stesso modo) — cambia battitore e si
        azzera (non si assume che batta uguale). Gestito in
        `_tapHandlerPerGiocatore`: confronta `player.id` con
        `_giocatoreTipoBattutaArmato` quando si apre il pannello con
        `fondamentale` già forzato a battuta; se diverso, resetta
        `_tipoBattutaSelezionato` a `nonSpecificato` e aggiorna
        `_giocatoreTipoBattutaArmato`. `_registraVoto` non lo resetta mai
        esplicitamente (resta quello che è finché non cambia battitore).
      - `_registraVoto` passa `tipoEsecuzione: _tipoBattutaSelezionato.name`
        a `registraAzioneScout()` solo se `fondamentale == battuta`,
        `_tipoAttaccoSelezionato.name` se `== attacco`, altrimenti
        `'nonSpecificato'` (ricezione/alzata/muro/difesa non hanno un proprio
        tipo di esecuzione — vedi Modello dati).
    - **Riga tipo attacco** (IMPLEMENTATA, opzionale — "Forte"/"Piazzata"/
      "Pallonetto" in un'unica riga, solo 3 chip quindi non serve la griglia
      2×2 della battuta): `_tipoAttaccoSelezionato` (`TipoAttacco`, default
      `nonSpecificato`). **Non resta mai "armata"** tra un attacco e l'altro
      (a differenza della battuta, di solito eseguita sempre nello stesso
      modo dallo stesso giocatore): `_sceglieFondamentale` la azzera
      incondizionatamente ogni volta che si scegli `Fondamentale.attacco`,
      anche per lo stesso giocatore — varia troppo spesso colpo su colpo per
      assumere che resti la stessa.
    - **`_buildTipoChip`**: chip generica (64×38, stesso stile
      selezionato/non selezionato) condivisa da entrambe le righe/griglie —
      parametrizzata su label/selezionato/onTap, non più una versione per
      `TipoBattuta` e una per `TipoAttacco`.
    - **Annulla = tap fuori dal pannello**, non un bottone dedicato.
      `_buildPannelloVoto` ritorna **due** widget nello Stack esterno: uno
      sfondo `Positioned.fill` con `GestureDetector(behavior: opaque)` che
      chiude il pannello (`_votoInCorso = null`), più il pannello stesso
      avvolto in un secondo `GestureDetector` (`onTap: () {}`, anch'esso
      `opaque`) che **assorbe** il tap — necessario perché lo Stack
      interrompe la ricerca del bersaglio al primo figlio che reclama il
      tocco (vedi `defaultHitTestChildren`): senza questo assorbimento, un
      tap su un punto del pannello senza un proprio `onTap` (es. lo sfondo
      della card, il testo del nome) cadrebbe comunque sullo sfondo
      sottostante e chiuderebbe il pannello per errore.
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
  - **`_registraVoto(voto)`**: chiama
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
      giocatore): solo l'etichetta, `voto = null` — `"Punto nostro"`/
      `"Punto avversario"` (verde, `AppColors.success`) o `"Errore nostro"`/
      `"Errore avversario"` (rosso, `Colors.red` letterale) — stessi colori
      dei bottoni che le generano (`_buildQuickActionButton`) e di
      `CourtStyle.votoColor()` per perfetto/errore (vedi sopra): stesso
      significato, stesso colore in tutti e tre i posti.
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
    - **Posizioni di attacco per RUOLO e FASE** (IMPLEMENTATO, variante
      "libero sui centrali" + "senza libero" derivata — "libero sugli
      schiacciatori" resta da fare e ricade sulla logica generica sopra):
      `_kAttackBattutaCentrali`/`_kAttackDopoBattutaCentrali`/
      `_kAttackDopoRicezioneCentrali`, stesso formato delle tabelle di
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
      - **`_activeAttackMap`** (getter): sceglie la tabella giusta per
        rotazione (`_currentSlot`) e fase — `_kAttackBattutaCentrali` se
        stiamo servendo e non `_faseDopo`, `_kAttackDopoBattutaCentrali` se
        stiamo servendo e `_faseDopo`, `_kAttackDopoRicezioneCentrali` se
        servono loro e `_faseDopo` (in ricezione, prima di `_faseDopo`,
        comanda `_activeDefenseMap`, non questa). Torna `null` se non c'è
        libero in formazione **e** `widget.ruoloCambiLibero != Ruolo.centrale`
        (variante "libero sugli schiacciatori", non ancora supportata).
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
        altri 5 ruoli risolvono lo slot via `_roleLabelsFor` invertita e
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
    - **Backlog non implementato**: gestione doppio libero (oggi sempre
      `L1` può entrare in campo, mai `L2`); unit test della logica libero su
      tutte e 6 le rotazioni.
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
- **Lista giocatori in `TeamFormScreen`** (`_PlayersSection`): stesso
  trattamento di ingrandimento applicato altrove dopo test su tablet fisico
  — avatar raggio 24, numero 20px, nome/cognome 20px bold, ruolo 16px,
  chevron 28px. Avatar del **libero** con colore invertito (`_invertedColor()`,
  stessa funzione duplicata anche qui) invece del colore squadra raw — unica
  eccezione, coerente con `lineup_screen`/`scout_screen`.
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
  - [ ] **PROSSIMO**: `CustomPainter` campo intero per le traiettorie
        (battuta/attacco) via drag; rendere modificabile l'esito automatico
        prima di confermare l'azione (idea annotata nel Modello dati, non
        ancora in UI).
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
  - [ ] Correzione manuale rotazione (per errori di scout/segnapunti — vale
        la situazione reale in campo): decisione già presa, non ancora
        implementata. **Va loggata** come evento di "cambio di
        configurazione" (al contrario del punteggio) — qui l'event-sourcing
        resta valido (undo, riprendi partita coerenti). Richiede estendere
        `ricalcolaStato()`/`AzioneScout` con un evento dedicato che sposta
        esplicitamente la rotazione in quel punto della sequenza (oggi
        cambia solo come effetto derivato di un sideout su `esitoPunto`).
        Dettagli di schema (nuovo `TipoAzione`? campo dedicato?) da
        decidere.
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
        all'interno di ciascuna. Stesso bottone, label/icona dinamiche:
        "Inizia" (`Icons.play_arrow`) per le prime, "Riprendi"
        (`Icons.replay`) per le terminate — stesso `onStart`, stesso flusso
        (`TeamSelectionScreen` → ... → `ScoutScreen`).
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
  - [ ] **Statistiche per giocatore/fondamentale** — non solo a fine
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
  - [ ] Export PDF, condivisione.

---

## Stato attuale

**Fase 1 completata. Fase 2 completata. Fase 3 in corso.**

Il flusso è navigabile end-to-end: lista partite → "Inizia" → selezione squadra →
selezione formazione (`LineupScreen`) → configurazione formazione
(`FormationConfigScreen`: sistema di gioco, conferma palleggiatore e cambi del
libero) → `ScoutScreen` (setup grafico completo + bottoni rapidi funzionanti +
flusso a 3 tocchi su tutti i fondamentali tranne `errore` — battuta/ricezione
forzati dalla fase di gioco, alzata/attacco/muro/difesa a scelta libera dopo:
punteggio, chi serve e rotazione sono derivati in tempo reale dagli eventi
`ScoutAction` persistiti, vedi Modello dati) → drawer "Fine" → `EndSetScreen`
("Prossimo Set" ripristina la scelta formazione da zero per il set
successivo, "Fine Partita" torna a `MatchesScreen`, ora a due sezioni
"Da iniziare/in corso" / "Terminate" — da queste ultime si può "Riprendere"
lo scout, che riporta `stato` a `inCorso` e salta `LineupScreen`/
`FormationConfigScreen` ricostruendo la formazione già salvata). Nessuna
nuova colonna serve per i punteggi: ogni set congelato si ricalcola sempre
con `ricalcolaStato()`, manca solo la schermata report (Fase 4) che farà
questo replay.
Il prossimo passo è il `CustomPainter` per le traiettorie (battuta/attacco)
via drag.

Testato sull'emulatore Pixel 7 in landscape. Repo Git su GitHub:
github.com/Branduich/volley_scout

---

## Note operative

- Ambiente di sviluppo: Windows 11, VS Code, emulatore Pixel 7 (o device fisico).
- Modalità sviluppatore Windows attiva (necessaria per i symlink dei plugin).
- Fare **commit frequenti** dopo ogni pezzo funzionante.
- Build Android la prima volta è lenta (Gradle), è normale.

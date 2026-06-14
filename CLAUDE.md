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

---

## Struttura cartelle

```
lib/
├── main.dart                     (app + HomeScreen con menu)
├── models/
│   └── enums.dart                (Ruolo, Categoria, JerseyColor + palette)
├── data/
│   ├── database.dart             (tabelle Teams, Players + AppDatabase)
│   ├── database.g.dart           (generato, non editare a mano)
│   └── repositories/
│       └── team_repository.dart  (CRUD squadre + giocatori)
├── providers/
│   └── database_provider.dart    (databaseProvider, teamRepositoryProvider,
│                                   teamsStreamProvider, playersStreamProvider)
├── screens/
│   ├── teams/
│   │   ├── teams_screen.dart      (lista squadre + FAB nuova squadra)
│   │   └── team_form_screen.dart  (crea/modifica/elimina squadra)
│   ├── matches/
│   │   └── matches_screen.dart    (placeholder)
│   └── live/
│       └── scout_screen.dart      (placeholder, si aprirà DA gestione partite)
└── widgets/                       (vuota per ora)
```

---

## Modello dati

### Implementato (Fase 1)

**Teams**: id (autoincrement), nome, categoria (enum Categoria), coloreDivisa
(int ARGB).

**Players**: id (autoincrement), teamId (FK -> Teams, cascade delete), nome,
cognome, numero (int), ruolo (enum Ruolo).

**Enum Ruolo**: palleggiatore, schiacciatore, centrale, opposto, libero, undefined.

**Enum Categoria**: under11..under18, terzaDivisione, secondaDivisione,
primaDivisione, serieD, serieC, serieB, serieB1, serieB2, serieA1, serieA2, serieA3.

**jerseyPalette**: lista fissa di JerseyColor (nome + Color): Rosso, Blu, Verde,
Giallo, Arancione, Viola, Nero.

### Da implementare nelle fasi successive (modello previsto, non ancora a DB)

**VolleyMatch**: id, data, campo, squadraCasaId, squadraOspiteId.

**MatchSet**: id, matchId, numero, puntiCasa, puntiOspiti.

**Rotation**: setId, squadra (nostra/avversari), mappa posizione(1-6) -> giocatoreId.
La posizione 1 è il battitore. Metodo `ruotata()` per il sideout (rotazione oraria).

**ScoutAction**: id, setId, rallyId (raggruppa le azioni di uno scambio), squadra,
giocatoreId (nullable), fondamentale (enum), voto (enum), traiettoria (nullable),
ordine, timestamp, puntiCasaAlMomento, puntiOspitiAlMomento.

**Enum Fondamentale**: battuta, ricezione, alzata, attacco, muro, difesa, errore.
- Battuta e attacco richiedono la traiettoria (getter `richiedeTraiettoria`).

**Enum Voto**: perfetto (#), positivo (+), mezzoPunto (!), negativo (-), errore (=).

**Trajectory**: partenza e arrivo come **coordinate normalizzate 0.0-1.0**
(CourtPoint x,y) rispetto al campo intero, rete a x=0.5. Non salvare pixel.
Nel DB: 4 colonne double (traiettoria_x1, y1, x2, y2).

---

## Flusso dell'app (navigazione)

- **HomeScreen**: layout landscape con area principale a sinistra (vuota per ora)
  e colonna di bottoni a destra: "Setup squadre" e "Gestione partite".
- Lo **scout NON si apre dalla home**: si aprirà da dentro una partita specifica
  (dentro Gestione partite -> dettaglio partita -> Scout), perché lo scout ha
  bisogno del contesto della partita (squadre, set).

---

## Interfaccia di scout (design deciso, da implementare in Fase 3)

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

- **Fase 1 — Squadre e giocatori** (IN CORSO)
  - [x] Enum, database (Teams, Players), repository, provider
  - [x] HomeScreen con menu
  - [x] Lista squadre + form crea/modifica/elimina squadra
  - [ ] **PROSSIMO PASSO: gestione giocatori** dentro la schermata di modifica
    squadra (lista giocatori + aggiungi/modifica/elimina, con nome, cognome,
    numero, ruolo). La sezione giocatori compare solo in modalità modifica
    (squadra già salvata, serve il teamId).

- **Fase 2 — Gestione partite**: modelli VolleyMatch/MatchSet, tabella matches,
  schermata creazione partita (data, campo, scelta delle due squadre), lista
  partite, dettaglio partita da cui parte lo scout.

- **Fase 3 — Scout**: CustomPainter del campo, Rotation, ScoutAction,
  traiettorie via drag, logica rotazioni/sideout.

- **Fase 4 — Statistiche ed export PDF** + condivisione.

---

## Stato attuale

Fase 1 quasi completa. Il prossimo task è la **gestione giocatori** nella
schermata di modifica squadra. Tutto il resto della Fase 1 (squadre) funziona ed
è testato sull'emulatore Pixel 7 in landscape. Repo Git su GitHub:
github.com/Branduich/volley_scout

---

## Note operative

- Ambiente di sviluppo: Windows 11, VS Code, emulatore Pixel 7 (o device fisico).
- Modalità sviluppatore Windows attiva (necessaria per i symlink dei plugin).
- Fare **commit frequenti** dopo ogni pezzo funzionante.
- Build Android la prima volta è lenta (Gradle), è normale.

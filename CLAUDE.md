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
- **pdf** + **printing** (export PDF con anteprima/condivisione/stampa —
  per il PDF `share_plus` non serve: la condivisione è già dentro `printing`)
- **csv** + **share_plus** (export CSV delle azioni partita — qui `printing`
  non basta, condivide solo PDF; vedi Export CSV in Fase 4)
- **shared_preferences** (impostazioni app — vedi `SettingsScreen`)
- **archive** + **xml** (lettura dei file `.xlsx`, che sono zip di XML — vedi
  `data/xlsx_reader.dart` in Campionato)
- **file_selector** (scelta del file `.xls`/`.xlsx` da importare — vedi Campionato).
  Scelto al posto di `file_picker`, che va in **conflitto di versione** con
  `package_info_plus ^10` (win32 ^5 vs ^6): pub risolveva file_picker a 3.0.4,
  del 2021. `file_selector` è mantenuto dal team Flutter e non ha il vincolo.
- Target: **solo orientamento orizzontale (landscape)**

Package già installati:
`flutter_riverpod drift sqlite3_flutter_libs path_provider path pdf printing
shared_preferences csv share_plus file_selector archive xml`
dev: `drift_dev build_runner flutter_launcher_icons`

**Workaround build Android** (`android/gradle.properties`):
`kotlin.incremental=false` — bug noto di Kotlin su Windows ("Could not close
incremental caches", file `.tab` lockati compilando i moduli plugin, visto con
`shared_preferences_android`). Non rimuoverlo senza motivo: senza, la build
fallisce anche dopo `flutter clean`/stop dei daemon.

---

## Convenzioni e decisioni architetturali (IMPORTANTI)

1. **Repository pattern obbligatorio**: la UI non parla mai direttamente col
   database. Ogni schermata usa un repository tramite provider riverpod.
   Questo è il vincolo architetturale chiave per mantenere il codice modificabile.

2. **Orientamento per-schermata** (era "solo landscape"): l'app nasce
   landscape-only, ma alcune schermate di setup sono più comode anche in
   portrait. L'orientamento NON è più un lock globale: `main()` parte
   seguendo il device (`kOrientamentoTutti`) e ogni schermata dichiara i
   propri orientamenti via il mixin `OrientamentoSchermata`
   (`lib/utils/orientamento.dart`), applicati in `initState` + post-frame e
   ri-applicati al ritorno in primo piano (`RouteObserver`/`didPopNext`,
   registrato in `MaterialApp.navigatorObservers`).
   - **`kOrientamentoTutti`** (portrait + landscape): Home, Impostazioni e le
     schermate di setup leggere (`TeamsScreen`, `CategorieScreen`,
     `MatchesScreen`, `TeamSelectionScreen`, `MatchFormScreen`,
     `PlayerFormScreen`). `HomeScreen` è responsive (`OrientationBuilder`:
     2 colonne in landscape, immagine sopra + bottoni sotto in portrait).
   - **`kOrientamentoLandscape`** (solo landscape): tutte le schermate col
     campo (`LineupScreen`, `FormationConfigScreen`, `SostituzioneScreen`,
     `ScoutScreen`, `TacticalBoardScreen`, `EndSetScreen`), i report
     (`MatchReportScreen`, `MatchPdfScreen`, `PlayerStatsScreen`,
     `TrajectoryReportScreen`) e **`TeamFormScreen`** (layout a 2 colonne
     non ancora reso responsive — backlog).
   - Il lock del **manifest Android** (`android:screenOrientation`) è stato
     rimosso: era malformato (fuori dal tag `<activity>`) e senza effetto —
     l'orientamento è gestito solo lato Flutter. Nota: forzare landscape da
     uno stato portrait funziona sui **device fisici**; alcuni **emulatori**
     con auto-rotate off non ruotano davvero (letterbox).
   - **Schermo intero sulle schermate landscape** (getter `schermoIntero` dello
     stesso mixin, default = tutte le solo-landscape): barre di sistema
     nascoste con `SystemUiMode.immersiveSticky`, ripristinate a `edgeToEdge`
     dalle altre. Serve perché `targetSdk` 36 **impone** l'edge-to-edge da
     Android 15 (API 35): il sistema non rimpicciolisce più la finestra e
     l'app disegna SOTTO le barre — su un telefono con navigazione a 3
     pulsanti la barra copriva il campo. Scartato `SafeArea` **sulle schermate
     del campo**: risolverebbe togliendo ~48dp proprio dove lo spazio è più
     prezioso, mentre nascondere le barre ne fa guadagnare.
   - **`SafeArea(top: false)` globale** in `MaterialApp.builder` (`main.dart`):
     sulle schermate NON a schermo intero l'edge-to-edge faceva finire dietro
     alla barra di navigazione il contenuto in fondo (l'ultima voce del menu
     di Home, un bottone) e, in landscape, dietro a quella laterale. `top:
     false` perché la barra di stato la gestisce già l'AppBar. Sulle schermate
     immersive gli inset sono zero, quindi lì è un no-op: un unico punto
     invece di un `SafeArea` per schermata.

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

9. **Supporto smartphone = design fisso + `FittedBox(scaleDown)`**: l'app è
   pensata per tablet ma deve restare usabile su telefono (sempre
   landscape). Le schermate costruite attorno al campo a 460×460dp fisso
   (`LineupScreen`, `FormationConfigScreen`, `SostituzioneScreen`) e il
   trailing della card partite (`MatchesScreen`) NON vanno ridisegnate in
   modo responsive: il blocco a misura fissa si avvolge in
   `FittedBox(fit: BoxFit.scaleDown)` — scala tutto in proporzione (card,
   font, gesture/hit-test compresi) solo quando manca spazio; su tablet
   scala = 1, zero differenze. Stessa tecnica già usata dalle card
   formazione del report (i margini interni fissi di `CourtView` non
   reggono un SizedBox più piccolo, la scala proporzionale sì).
   `ScoutScreen`/`TrajectoryScreen` sono già proporzionali (percentuali
   dello schermo) e non hanno bisogno del FittedBox, ma su schermi BASSI
   servono ritocchi dedicati (fatti): campo clampato in altezza
   (`courtWidth = min(58% larghezza, altezza utile × 2)` — in
   TrajectoryScreen riservando ~84px per la riga chip), drawer di utilità
   come `ListView` (scrolla invece di sbordare), pannello voto in
   `FittedBox(scaleDown)` con margini verticali minimi (4/4), offset dei
   pallini timeout nell'header clampato fuori dal gruppo punteggio
   (`timeoutDotsOffset`: 237 fisso quando c'è spazio, altrimenti
   all'esterno del punteggio al 30%/70%, mai sotto menu/undo).

---

## Struttura cartelle

```
lib/
├── main.dart                     (app + HomeScreen con menu; usa AppTheme.light)
├── models/
│   └── enums.dart                (Ruolo, Categoria, Voto, SistemaGioco, Squadra,
│                                   EsitoPunto + jerseyPalette)
├── logic/
│   ├── attack_positions.dart     (tabelle posizioni TATTICHE di attacco per
│   │                               rotazione/ruolo/fase + attackMapFor() +
│   │                               attackMapFor62() (tabelle 6-2) +
│   │                               zonaDaPosizione() — ex costanti private di
│   │                               scout_screen, condivise con le pagine
│   │                               attacchi del PDF; vedi Fase 4 e Modulo 6-2)
│   ├── ricalcola_stato.dart      (funzione pura ricalcolaStato() — punteggio/
│   │                               rotazione derivati dalle azioni di scout +
│   │                               slot palleggiatore avversario che ruota sul
│   │                               loro sideout; nessuna dip da DB/UI; Modello dati)
│   ├── defense_positions.dart    (posizioni di RICEZIONE per rotazione/ruolo/
│   │                               variante libero + defenseMapFor() +
│   │                               defenseMapFor62()/kDefensePositions62 (6-2) — ex
│   │                               costanti private di scout_screen, estratte per riuso
│   │                               (formazione ricezione avversaria mirror); Scout
│   │                               avversario e Modulo 6-2)
│   ├── fipav_calendario.dart     (funzioni pure parseGareFipav() — griglia
│   │                               grezza dell'export FIPAV -> List<GaraFipav>,
│   │                               header mappato per NOME colonna — e
│   │                               stagioneDaGare() ("2025/26" dalle date, il
│   │                               file non ha la stagione); testate sulle
│   │                               fixture — vedi Campionato)
│   ├── indirizzo_mappa.dart      (queryMappaDaPalestra() — dal testo di
│   │                               VolleyMatches.palestra alla query per l'app
│   │                               di mappe: sposta l'indirizzo davanti al
│   │                               comune e scarta il nome dell'impianto, che
│   │                               confonde la ricerca; testo scritto a mano
│   │                               restituito intatto. Testata)
│   ├── classifica.dart           (funzioni pure calcolaClassifica() (3/2/1/0
│   │                               punti FIPAV, quoziente set/punti) +
│   │                               squadraUnicaDelFiltro() (rileva un export
│   │                               filtrato per società = classifica parziale);
│   │                               testate — vedi Campionato)
│   ├── heatmap.dart              (funzioni pure puntiArrivoAvversari() +
│   │                               puntiArrivoAvversariPerfetti() — punti d'arrivo nel
│   │                               nostro campo delle azioni AVVERSARIE battuta/attacco,
│   │                               normalizzati come buildTrajData; alimentano la heatmap
│   │                               ricezione/difesa; testate; vedi Heatmap in Scout avversario)
│   └── role_labels.dart          (roleLabelsFor() — etichette P/O/S1/S2/C1/C2
│                                   per slot (gli universali riempiono le mancanti)
│                                   + roleLabelsFor62() (6-2: la POSIZIONE vince sul
│                                   ruolo, i due P sono etichette fisse P1/P2)
│                                   + etichetteAvversarie() (5-1 canonico dallo slot
│                                   del P avversario) + kAliasRuoloAvversario
│                                   (alias leggibili ruoli per i selettori report))
├── data/
│   ├── database.dart             (tabelle Categorie, Teams, Players,
│   │                               VolleyMatches + AppDatabase)
│   ├── database.g.dart           (generato, non editare a mano)
│   ├── default_categorie_seeder.dart (semina i 16 default della lista
│   │                               categorie alla prima apertura — vedi
│   │                               Modello dati → Categorie personalizzabili)
│   ├── default_team_seeder.dart  (squadra demo "Volley Star" pre-caricata
│   │                               al primo avvio, seed una-tantum via flag)
│   ├── demo_match_importer.dart  (import partita demo da assets/demo/ —
│   │                               solo debug, vedi Fase 4)
│   ├── match_csv_exporter.dart   (export CSV azioni partita: righeCsvPartita()
│   │                               pura + condividiCsvPartita() con share
│   │                               sheet — bottone "CSV" in MatchesScreen,
│   │                               vedi Export CSV in Fase 4)
│   ├── xls_reader.dart           (leggiXls() — lettore MINIMALE di .xls
│   │                               binario legacy (OLE2 + BIFF8), scritto a
│   │                               mano perché nessun package Dart legge quel
│   │                               formato; vedi Campionato)
│   ├── xlsx_reader.dart          (leggiXlsx() — gemello per l'Open XML
│   │                               (zip + XML via archive/xml); stessa griglia
│   │                               di stringhe in uscita)
│   └── spreadsheet_reader.dart   (leggiFoglioCalcolo() — punto UNICO di
│                                   ingresso: riconosce .xls/.xlsx/HTML dai
│                                   BYTE e delega; è quello che chiama la UI)
├── providers/
│   ├── premium_provider.dart     (StatoPremium + statoPremiumProvider — stub
│   │                               del freemium gate, vedi sezione Premium)
│   ├── campionato_provider.dart  (CampionatoRepository: importa(campionato
│   │                               EsistenteId:) — aggiorna o crea, la scelta
│   │                               la fa la UI via campionatiConNome();
│   │                               impostaSquadraPropria(), eliminaCampionato()
│   │                               (le partite restano), creaPartitaDaGara() +
│   │                               nomePartitaDaGara();
│   │                               provider campionatiStream/gareStream —
│   │                               vedi Campionato)
│   ├── database_provider.dart    (TeamRepository + CategoriaRepository +
│   │                               MatchRepository, tutti i provider:
│   │                               teamsStream, playersStream, categorieStream,
│   │                               matchesStream; helper condivisi su righe
│   │                               ScoutAction: azioneScoutDaRiga(),
│   │                               idAttacchiSuRicezione(), attaccoMurato())
│   └── settings_provider.dart    (Impostazioni + impostazioniProvider su
│                                   shared_preferences; sharedPreferencesProvider
│                                   sovrascritto in main() — vedi Impostazioni)
├── screens/
│   ├── teams/
│   │   ├── teams_screen.dart      (lista squadre + due FAB in basso:
│   │   │                           "Categorie" a sx tonale → CategorieScreen,
│   │   │                           "Nuova squadra" a dx primaria)
│   │   ├── categorie_screen.dart  (gestione lista categorie: aggiungi/
│   │   │                           rinomina con cascata opzionale/elimina/
│   │   │                           riordina — vedi Modello dati → Categorie)
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
│   │   │                                  cambi del libero; riusata in "modalità
│   │   │                                  conferma" dal flusso di sostituzione — vedi
│   │   │                                  sezione navigazione e "cambio giocatore")
│   │   ├── sostituzione_screen.dart      (cambio giocatore a set in corso: campo con
│   │   │                                  rotazione corrente + panchina, N cambi in una
│   │   │                                  visita — vedi "cambio giocatore" in Fase 3)
│   │   ├── scout_screen.dart             (setup grafico Fase 3 in corso: sfondo, barra
│   │   │                                  top, campo doppio + campo piccolo)
│   │   ├── tactical_board_screen.dart    (lavagna tattica premium dal drawer live:
│   │   │                                  chip ruoli trascinabili nella metà campo +
│   │   │                                  disegno linee a mano libera, undo/cestino;
│   │   │                                  effimera, riusa il layout campo di
│   │   │                                  TrajectoryScreen)
│   │   └── end_set_screen.dart           (fine set/partita: "Prossimo Set"/"Fine Partita")
│   ├── report/
│   │   ├── match_report_screen.dart      (Fase 4: report completo — dati partita,
│   │   │                                  punteggio finale/per set con durata e pallini
│   │   │                                  esito, riepilogo fondamentali, punti/errori
│   │   │                                  generici, bottoni traiettorie, formazioni di
│   │   │                                  partenza per set, distribuzione alzate,
│   │   │                                  efficienza e positività — da MatchesScreen)
│   │   ├── match_pdf_screen.dart         (Fase 4: anteprima+condivisione PDF on-demand
│   │   │                                  via PdfPreview — bottone "PDF" sulla card
│   │   │                                  delle partite terminate; pagina 1 punteggi,
│   │   │                                  mega tabella statistiche partita+per set,
│   │   │                                  pagine battute/attacchi con campi vettoriali,
│   │   │                                  vedi Fase 4)
│   │   ├── player_stats_screen.dart      (Fase 4: statistiche per giocatore/fondamentale,
│   │   │                                  set per set, filtro attacchi tutti/su ricezione/
│   │   │                                  su difesa + colonna Murati — dal drawer di
│   │   │                                  ScoutScreen)
│   │   └── trajectory_report_screen.dart (Fase 4: traiettorie battute/attacco con filtri
│   │                                      set/giocatore e, per attacco, rotazione P1-P6 —
│   │                                      dal drawer di ScoutScreen e dai bottoni di
│   │                                      MatchReportScreen; param `modalitaHeatmap`:
│   │                                      riusata come Heatmap ricezione/difesa avversaria
│   │                                      (blob + marker ace/kill, frecce nascoste,
│   │                                      rotazione = NOSTRA formazione) — vedi Fase 4 →
│   │                                      Heatmap in Scout avversario)
│   ├── campionato/
│   │   └── campionato_screen.dart        (import del calendario FIPAV .xls + tab
│   │                                      Calendario (crea partita per gara) e
│   │                                      Classifica — da HomeScreen, vedi Campionato)
│   ├── premium/
│   │   └── paywall_screen.dart           (paywall placeholder — vedi sezione Premium)
│   └── settings/
│       ├── settings_screen.dart          (Impostazioni — toggle traiettorie, toggle
│       │                                  debug "Simula utente free", voce
│       │                                  Informazioni; vedi sezioni Impostazioni
│       │                                  e Premium)
│       └── about_screen.dart             (Informazioni: versione, link legali
│                                          placeholder, supporto, ID supporto —
│                                          vedi sezione Premium)
├── utils/
│   ├── orientamento.dart          (mixin OrientamentoSchermata + RouteObserver
│   │                               per l'orientamento per-schermata — vedi
│   │                               convenzione #2)
│   └── mappe.dart                 (apriInMappe() — cede l'indirizzo all'app di
│                                   mappe del telefono via url_launcher: geo:
│                                   con ripiego sull'URL di Google Maps.
│                                   Nessuna dipendenza nuova, nessuna API key,
│                                   nessun permesso INTERNET — icona nel campo
│                                   palestra di MatchFormScreen)
├── theme/
│   ├── app_colors.dart            (palette brand + colori semantici + superfici)
│   ├── app_spacing.dart           (AppSpacing xs/sm/md/lg/xl/xxl, AppRadius sm/md/lg/pill)
│   ├── app_typography.dart        (AppTypography.textTheme — scale tipografica, font Barlow)
│   ├── app_theme.dart             (AppTheme.light — ThemeData principale, usa i file sopra)
│   └── court_style.dart           (CourtStyle — costanti grafiche campo: colori linee,
│                                   rete, token giocatore, traiettoria, votoColor(Voto))
└── widgets/
    ├── certificato_dot.dart       (CertificatoDot + coloreScadenzaCertificato():
    │                               pallino 14×14 di stato del certificato medico
    │                               — rosso <8 giorni o scaduto, giallo <30,
    │                               verde altrimenti, niente se data assente —
    │                               nel trailing delle liste giocatori di
    │                               TeamFormScreen e LineupScreen)
    ├── court_view.dart            (CourtView + LabeledCourt: campo 3×2 con card
    │                               giocatori, estratti da formation_config_screen —
    │                               condivisi con sostituzione_screen; CourtView ha
    │                               anche badge ✕ opzionali per-slot e `slotContent`
    │                               — contenuto custom per slot a parità di geometria,
    │                               usato dalla distribuzione alzate del report)
    └── court_trajectories_view.dart (CourtTrajectoriesView + TrajData/buildTrajData +
                                    MultiTrajectoryPainter: campo doppio + traiettorie
                                    già filtrate, widget puro estratto da
                                    trajectory_report_screen in vista della cattura
                                    PNG per il PDF; `heatmapPunti` (blob additivi caldi) +
                                    `markerPunti` (cerchietti bordo rosso ace/kill) +
                                    `specchia` (rotazione 180° prospettiva nostra) per la
                                    heatmap ricezione/difesa — vedi Heatmap in Scout avversario)

assets/
├── images/         (court_bg.png, double_court_bg.png, small_court.png)
├── demo/           (demo_match.json — partita reale convertita, vedi Fase 4;
│                    + "VOLLEY STATS PDF - Stats_Match_PDF.csv", foglio di
│                    riferimento della mega tabella statistiche del PDF)
├── icon/           (logo app: anche asset runtime per l'header del PDF)
└── fonts/Barlow/    (Barlow-Regular/Medium/SemiBold/Bold.ttf — pesi 400/500/600/700)

docs/samples/     (fixture reali dell'export calendario FIPAV, usate dai test
│                  del lettore, del parser gare e della classifica)
├── GareNettunia.xls  (.xls binario, export FILTRATO per società: 12 gare,
│                      solo quelle di NETTUNIA -> classifica parziale)
└── "Calendario completo senza 14 giornata.xlsx"
                      (.xlsx, girone COMPLETO: 42 gare, ultime due giornate
                       svuotate per simulare le gare da giocare)

test/
├── widget_test.dart       (smoke test HomeScreen)
├── layout_dimensioni_test.dart (rete di sicurezza sui layout dipendenti dalla
│                           LARGHEZZA: monta Home, Campionato vuoto,
│                           MatchesScreen con partita terminata (caso peggiore:
│                           CSV+PDF+Report), TeamFormScreen in modifica e
│                           ScoutScreen a tre dimensioni fisse — telefono
│                           verticale/orizzontale e tablet — e pretende
│                           `tester.takeException() == null`, cioè nessun
│                           `RenderFlex overflowed` né `RenderBox was not laid
│                           out`. **MAI ESEGUITO** (2026-08-04): scritto e
│                           `analyze`-pulito, ma `flutter test` andava in crash
│                           per un lock su build/native_assets/windows/
│                           sqlite3.dll (processo `flutter_tester` appeso) —
│                           da lanciare, un fallimento può benissimo essere
│                           reale. Lo scenario di ScoutScreen riusa
│                           `TutorialSandbox.semina()`. Vedi la convenzione 2
│                           sulle barre di sistema per il contesto)
├── data/
│   ├── xls_reader_test.dart       (leggiXls() sulla fixture GareNettunia.xls:
│   │                               griglia, header, celle, rifiuto non-Excel)
│   └── xlsx_reader_test.dart      (leggiXlsx() sulla fixture xlsx del girone
│                                   completo + casi limite costruiti al volo
│                                   (inlineStr, rich text, colonne oltre la Z)
│                                   + smistamento di leggiFoglioCalcolo)
├── providers/
│   └── campionato_repository_test.dart (importa()/creaPartitaDaGara() su DB
│                                   drift in memoria — AppDatabase.perTest)
└── logic/
    ├── ricalcola_stato_test.dart  (27 test su ricalcolaStato(), `flutter test`)
    ├── role_labels_test.dart      (8 test su roleLabelsFor() — regressione +
    │                               universali per completamento)
    ├── demo_match_test.dart       (valida la partita demo: replay == referto)
    ├── certificato_dot_test.dart  (soglie del pallino certificato medico)
    ├── indirizzo_mappa_test.dart  (queryMappaDaPalestra(): tutte le forme di
    │                               indirizzo della fixture FIPAV + testo
    │                               scritto a mano, che non va mai riscritto)
    ├── fipav_calendario_test.dart (parseGareFipav(): fixture reale + casi
    │                               limite (gara futura, data illeggibile,
    │                               colonne in ordine diverso))
    ├── classifica_test.dart       (punti 3/2/1/0, quozienti, ordinamento,
    │                               rilevamento export parziale)
    └── match_csv_test.dart        (righeCsvPartita() — header, join nomi,
                                    punteggio progressivo, celle vuote)
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

<!-- Modello dati (DB drift, schema, enum): sezione spostata in docs/context/modello-dati.md, importata qui sotto (contenuto invariato). -->
@docs/context/modello-dati.md

---

<!-- Flusso app + Interfaccia di scout (live): sezione spostata in docs/context/scout-live.md, importata qui sotto (contenuto invariato). -->
@docs/context/scout-live.md

---

<!-- Scout avversario: sezione spostata in docs/context/scout-avversario.md, importata qui sotto (contenuto invariato). -->
@docs/context/scout-avversario.md

---

<!-- Import calendario FIPAV (.xls) + pagina Campionato/Classifica. -->
@docs/context/campionato-fipav.md

---

<!-- Impostazioni + i18n + Premium (Strada A): sezione spostata in docs/context/premium-settings-i18n.md, importata qui sotto (contenuto invariato). -->
@docs/context/premium-settings-i18n.md

---

## Fasi di sviluppo (storico) → docs/context/storico-fasi.md

Cronologia dettagliata delle Fasi 1–4 (cosa è fatto / scartato / da fare, con
le motivazioni e i bug corretti). **NON importato in automatico**: leggere
`docs/context/storico-fasi.md` quando serve il dettaglio storico di una feature
o il razionale di una decisione passata. Lo stato sintetico corrente è nella
sezione "Stato attuale" qui sotto.

---

## Stato attuale

**Fase 1 completata. Fase 2 completata. Fase 3 completata. Fase 4 in corso.**

**Scout avversario** (scout a due squadre): live COMPLETO (selezione P avversario,
token tattici, fase simmetrica + Modello A, dimming per squadra, scorciatoie
difensive, traiettorie in input) e report a video COMPLETO (blocco in coda a
`MatchReportScreen`); manca solo l'export PDF avversario. Vedi la sezione "Scout
avversario". Nella lista partite le due sezioni hanno ordini OPPOSTI, entrambi
espliciti (non si eredita il `desc` di `watchMatches()`): "Da iniziare / in
corso" **crescente** (la partita più imminente in cima), "Terminate"
**decrescente** (l'ultima giocata in cima).

**Modulo 6-2 (doppio palleggiatore)**: IMPLEMENTATO (Fase 1 attacco + Fase 2
ricezione/difesa + PDF/report), persistito su `MatchSets.sistemaGioco` (v16).
Backlog 6-2: libero e scout avversario in 6-2. Vedi "Modulo 6-2" in Modello dati.

**Campionato (import FIPAV + classifica)**: IMPLEMENTATO — lettori `.xls`
binario e `.xlsx` scritti a mano (`data/spreadsheet_reader.dart` smista sui
byte del file, non sull'estensione), **più campionati/squadre** (filtro squadra,
stagione dedotta dalle date, dialog "aggiorna o crea nuovo" al re-import,
eliminazione che conserva le partite), parser gare e classifica puri e
testati, tabelle `Campionati`/`Gare` (v17), `CampionatoScreen` con tab
Calendario/Classifica e creazione partite per gara. Import premium, classifica
libera. Vedi la sezione "Campionato".

**Heatmap ricezione/difesa**: dove cadono le palle avversarie nel nostro campo
(battuta→ricezione, attacco→difesa), riusando `TrajectoryReportScreen` in
modalità heatmap (blob + marker ace/kill, rotazione NOSTRA); dai bottoni del
report. Manca l'export PDF. Vedi "Heatmap ricezione/difesa" in Scout avversario.

Il flusso è navigabile end-to-end: lista partite → "Inizia"/"Continua"/
"Riprendi" → selezione squadra → selezione formazione (`LineupScreen`) →
configurazione formazione (`FormationConfigScreen`: sistema di gioco,
conferma palleggiatore e cambi del libero) → `ScoutScreen` (setup grafico
completo + bottoni rapidi + flusso a 3 tocchi su tutti i fondamentali
tranne `errore`, con traiettoria per battuta/attacco via `TrajectoryScreen`
— punteggio, chi serve e rotazione derivati in tempo reale dagli eventi
`ScoutAction`, vedi Modello dati) → drawer ("Sostituzione" apre il flusso
di cambio giocatore a set in corso — `SostituzioneScreen` +
`FormationConfigScreen` in modalità conferma, vedi Fase 3; "Statistiche"
apre `PlayerStatsScreen` anche a partita in corso; "Fine" apre `EndSetScreen`:
"Prossimo Set" ripristina la scelta formazione da zero per il set
successivo, "Fine Partita" torna a `MatchesScreen`, a due sezioni
"Da iniziare/in corso" / "Terminate" — da queste ultime si può
"Riprendere" lo scout, o aprire `MatchReportScreen` per il report
completo). Bypass automatico di `TeamSelectionScreen`/`LineupScreen`/
`FormationConfigScreen` quando si riprende un set già iniziato.
Fase 4: `MatchReportScreen` è COMPLETO a video (dati partita, punteggio
finale/per set con durata e pallini esito, riepilogo fondamentali,
punti/errori generici con motivi, bottoni traiettorie, formazioni di
partenza per set, distribuzione alzate, efficienza e positività);
`PlayerStatsScreen` con filtro attacchi (tutti/su ricezione/su difesa) e
colonna Murati. Export PDF COMPLETO (`MatchPdfScreen`, on-demand,
A4 landscape): pagina 1 intestazione/punteggi, mega tabella statistiche
(partita intera + una pagina per set, layout dal foglio dell'utente) con
specchietto generici, pagine "Battute" (un campo vettoriale B/N per
battitore), "Attacchi" (un campo per giocatore+posizione TATTICA, dalle
tabelle di `logic/attack_positions.dart`), "Formazioni di partenza" e
"Distribuzione alzate" per rotazione con chip Ric/Dif — vedi la voce
Export PDF in Fase 4. Nello scout live: timeout per set (bottoni + pallini header) e
pagina Impostazioni (toggle traiettorie via shared_preferences, vedi
sezione Impostazioni). In test su dispositivo fisico (APK release).

Testato sull'emulatore Pixel 7 in landscape. Repo Git su GitHub:
github.com/Branduich/volley_scout

---

## Note operative

- Ambiente di sviluppo: Windows 11, VS Code, emulatore Pixel 7 (o device fisico).
- Modalità sviluppatore Windows attiva (necessaria per i symlink dei plugin).
- Fare **commit frequenti** dopo ogni pezzo funzionante — **i commit li fa
  sempre lo sviluppatore, mai Claude** (al massimo segnalare che c'è lavoro
  non committato).
- Build Android la prima volta è lenta (Gradle), è normale.

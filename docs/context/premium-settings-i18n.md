## Impostazioni (SettingsScreen + settings_provider)

Pagina "Impostazioni" raggiunta dal bottone in fondo al menu di `HomeScreen`
(`lib/screens/settings/settings_screen.dart`), persistenza su
**shared_preferences**:

- **`settings_provider.dart`**: `SharedPreferences` caricato in `main()`
  PRIMA di `runApp` e iniettato con
  `sharedPreferencesProvider.overrideWithValue(prefs)` sul `ProviderScope`
  (il provider base lancia `UnimplementedError` se non sovrascritto) — così
  `impostazioniProvider` (`Notifier<Impostazioni>`) si legge in modo
  **sincrono** ovunque, senza FutureProvider. `main()` è diventato `async`
  per questo.
- **`traiettorieAbilitate`** (bool, default `true`, chiave
  `scout.traiettorieAbilitate`): unica impostazione per ora. Se `false`,
  `ScoutScreen._registraVoto` NON apre `TrajectoryScreen` dopo il voto di
  battuta/attacco — l'azione si registra subito con coordinate `null`
  (stesso percorso del "salta", zero impatti su DB/report). **Implicazione
  accettata per ora**: anche i chip tipo battuta/attacco vivono su
  `TrajectoryScreen`, quindi col toggle spento `tipoEsecuzione` resta
  `nonSpecificato` — eventuale rientro dei chip nel pannello voto da
  valutare in futuro (annotato anche nel codice).
- **`scoutAvversariAbilitato`** (bool, default `true`, chiave
  `scout.scoutAvversariAbilitato`): abilita lo Scout avversario (vedi sezione
  dedicata). Se `true`, all'avvio di un nuovo set `ScoutScreen` chiede di
  posizionare il palleggiatore avversario sul campo; se `false` lo scout resta
  a una sola squadra (comportamento originale, zero token avversari).
- **`formatoCsv`** (enum `FormatoCsv`, default `europeo`, chiave
  `export.formatoCsv`): separatore di campo e decimale dell'export CSV —
  `europeo` = `;` + virgola (formato storico, Excel italiano lo apre al
  doppio clic), `internazionale` = `,` + punto. **Non è legato alla lingua
  dell'app**, e non deve diventarlo: a decidere come si legge un CSV sono le
  impostazioni regionali del computer su cui lo si apre, che possono non
  coincidere con la lingua dell'app (app in inglese su un PC italiano). Per
  questo è una voce esplicita in Impostazioni → Export invece che un
  automatismo. Il BOM UTF-8 c'è sempre, in entrambi i formati.
  **Voto errore = `'=` (con l'apice)**, in entrambi i formati: Excel valuta
  come formula ogni cella che comincia con `=` e mostrava `#NAME?`; l'apice è
  il marcatore di testo, che Excel consuma (in cella si legge `=`). Provate
  anche virgolette e `="="`: le prime non bastano, la seconda produce una
  vera formula (illeggibile da script). Gli altri quattro simboli
  (`#`, `+`, `/`, `-`) restano nudi — `+`/`-` diventano formule solo se
  seguiti da qualcosa. Vedi `_simboloVoto` in `match_csv_exporter.dart`.
- **Pensata per il gating premium futuro** (es. traiettorie solo premium):
  il resto del codice legge solo `impostazioniProvider`, il gating potrà
  limitarsi a nascondere/bloccare il toggle in `SettingsScreen`.

---

## Internazionalizzazione (i18n) — IN CORSO (pilota fatto)

Traduzione IT→EN con l'i18n ufficiale di Flutter (`flutter_localizations` +
`intl` + `gen_l10n`, nessuna dip esterna). Sorgente = italiano.

- **File ARB** in `lib/l10n/`: `app_it.arb` (sorgente/template) e
  `app_en.arb` (inglese). Chiave → stringa; le stringhe con interpolazione
  usano i placeholder ARB (`"x": "Set {n}"`). Config in `l10n.yaml`
  (`nullable-getter: false`).
- **Classe generata** `AppLocalizations` (`lib/l10n/app_localizations*.dart`,
  **gitignorata** — rigenerata da `flutter gen-l10n`/`pub get`, `generate:
  true` nel pubspec). Uso: `final l = AppLocalizations.of(context);` (mai
  null) → `l.nomeChiave`. Rilanciare `flutter gen-l10n` dopo ogni modifica
  agli ARB.
- **Selezione lingua**: `linguaProvider` (`lib/providers/lingua_provider.dart`,
  `Notifier<Locale?>`) — `null` = segue il dispositivo (fallback EN),
  altrimenti lingua forzata. Persistito su shared_preferences (chiave
  `app.lingua`). Passato a `MaterialApp.locale`; dropdown compatta
  Sistema/Italiano/English in `SettingsScreen`.
- **Stato** (aggiornato 2026-07-31): tradotte **15 schermate** — Home,
  Impostazioni, tutto il flusso di scout live (lineup, configurazione
  formazione, sostituzione, scout, traiettorie), i report (report partita,
  PDF, statistiche giocatore, traiettorie), lista partite, form squadra/
  giocatore, `court_view` e l'export CSV — più **Paywall** e **Informazioni**.
  Fatte anche le label degli enum e gli export PDF/CSV (seguono la lingua
  dell'app).
  **Completate al 100%** (2026-08-01): home, impostazioni, campionato,
  categorie, fine set, form giocatore, form partita, **form squadra**, setup
  squadre, selezione squadra, paywall, informazioni.

  **Completate anche** (2026-08-15): `matches_screen` (chiavi `partite*`) e
  **tutto lo scout live** — `lineup_screen` (`lineup*`),
  `formation_config_screen` (`config*`), `sostituzione_screen` (`sost*`),
  `scout_screen` (`scout*`), `trajectory_screen` (`traiettoria*`) e
  `tactical_board_screen` (`lavagna*`, prima mai iniziata).

  **Completati anche i report** (2026-08-15): `match_report_screen`,
  `match_pdf_screen`, `trajectory_report_screen`, `player_stats_screen` —
  chiavi `report*` (condivise fra le quattro: filtri Set/Giocatore/Ruolo/
  Rotazione, titoli sezione, formule e dettagli delle card) e `pdf*` (solo
  documento: titoli pagina, intestazioni della mega tabella, chip Ric/Dif).
  Gli enum `_FiltroAttacco`/`_FiltroAlzate` non hanno più un `label` fisso nel
  costruttore: ora è un metodo `label(AppLocalizations l)`.
  Le **sigle di colonna** della mega tabella PDF (TOT, PT, ER, EF%, POS%, ++)
  restano invariate in ogni lingua: le larghezze sono fisse e tradurle
  sfonderebbe la tabella. Tradotti solo i titoli di gruppo e "Nome"/"MURI".
  In `match_pdf_screen` le stringhe si leggono dal getter sincrono `_l`
  (`AppLocalizations.of(context)`): il PDF si costruisce in metodi `async` e
  usare `context` direttamente farebbe scattare
  `use_build_context_synchronously`.

  **Fuori dalle schermate, FATTE** (2026-08-15): la voce "Tutorial" del menu
  di Home (`homeTutorial`), il toggle "Mostra il tutorial nel menu" in
  Impostazioni (`settingsTutorial*`) e il tooltip di `debug_paint_toggle`
  (`debugBordiLayout`) — il tutorial vero e proprio resta da tradurre, vedi
  sotto.

  **Restano in italiano di proposito** (NON sono un backlog): "Excel" in
  `campionato_screen` (nome di prodotto), `Text('P$r')` nel selettore
  rotazione del report (sigla di posizione), i nomi delle giocatrici finte di
  `tutorial_sandbox` (dati demo, non interfaccia).
  Fuori dalle schermate: l'header del CSV (`kCsvHeader` in
  `data/match_csv_exporter.dart`, 22 colonne) è una `const List<String>`
  italiana — i VALORI passano già da `enum_l10n`, l'intestazione no; è usata
  anche dai test, quindi localizzarla vuol dire toccare `match_csv_test`.

  **Tutorial interattivo — FATTO** (2026-08-16): tutti i 23 passi di
  `lib/tutorial/tutorial_steps.dart` (titolo + testo + `testoTraiettoria`) e il
  contorno (`tutorial_overlay.dart`, i due nomi della sandbox) sono in ARB col
  prefisso `tutorial*`. Impianto: `passiTutorial(AppLocalizations l)` costruisce
  la sequenza **già tradotta** — le stringhe si risolvono una volta in
  `TutorialController.inizia(l)`, non a ogni build della card; `avviaTutorial`
  cattura `l` PRIMA degli await e lo passa anche a `TutorialSandbox.semina`
  (nome squadra e partita di prova si vedono nel titolo della barra).
  `PassoTutorial.etichettaBottone` è nullable: `null` = "Avanti", che la card
  risolve da `AppLocalizations` (il default di un parametro deve essere const).
  Da NON tradurre: l'URL del sito e `volleystratego@gmail.com` della scheda
  finale, e i nomi della rosa finta in `tutorial_sandbox.dart` (dati demo).
  **Se rinomini una voce del drawer, allinea `tutorialVociMenuTesto`**: è
  l'unico punto del tutorial che duplica le etichette dell'interfaccia.

  **Inglese AMERICANO** (deciso 2026-08-16): color/defense, non colour/defence.
  Nei testi del tutorial "zona" è reso **position** (non *zone*), così rimanda
  alle etichette P1…P6 dei token in campo.

  **Come contarle davvero** — NON usare `grep -L AppLocalizations`: dice solo
  se il file *importa* la classe, e una schermata con una riga tradotta
  risulta "fatta" (è così che `team_form_screen` è rimasta in italiano per
  sessioni). Il comando giusto cerca le stringhe rimaste:

  ```
  grep -nE "Text\('[A-Za-zÀ-ù]|labelText: '|hintText: '|tooltip: '" lib/screens/**/*.dart
  ```

  Tre risultati sono **falsi positivi voluti**: `"Volley Stratego"` e `"Volley
  Stratego Premium"` (nome del prodotto) e `"Italiano"`/`"English"` nel
  selettore lingua, che si scrivono sempre nella propria lingua.
  - **`Categoria` ESCLUSA dall'i18n** (deciso 2026-07-24): il suo `.label`
    non è mai mostrato a runtime — serve solo a seminare la lista categorie
    al primo avvio (`default_categorie_seeder.dart`), alla migrazione v12→v13
    e ai seeder demo/default team; la UI legge testo libero dal DB
    (`categorieStreamProvider`), non l'enum. Inoltre metà dei valori sono
    denominazioni FIPAV (Serie A1/A2/B/C/D…) che non si traducono. Default
    seminati in **italiano in ogni lingua**, l'utente li edita in
    `CategorieScreen` se vuole. Niente da fare.
  - **Nomi propri non tradotti**: "Volley Stratego" e "Volley Stratego
    Premium" (titolo del paywall) restano hardcoded, sono il nome del
    prodotto.
  - **Convenzione chiavi**: prefisso della schermata (`home*`, `settings*`,
    `paywall*`, `about*`, `categorie*`). Se una stringa è già altrove si riusa
    la chiave esistente invece di duplicarla (es. il titolo di `AboutScreen`
    usa `settingsAbout`, che è la voce che la apre).
  - **Chiavi `comune*`** (2026-07-31): `comuneAnnulla`/`comuneConferma`/
    `comuneSalva`/`comuneElimina`/`comuneRinomina`/`comuneErrore` — i bottoni
    che tornano in ogni dialog. Da usare nelle schermate ancora da tradurre invece di
    `xxxAnnulla` ripetuto. NB: alcune schermate già "localizzate"
    (es. `team_form_screen`) hanno ancora `Text('Annulla')` hardcoded — si
    possono migrare a queste chiavi una riga per volta.
  - **Plurali**: usare l'ICU dell'ARB (`{n, plural, =1{...} other{...}}`), non
    concatenare pezzi di frase in Dart — italiano e inglese accordano il verbo
    in modo diverso. Primo uso in `categorieEliminaConSquadre`/
    `categorieCascataTesto`.
  Per una schermata nuova si può procedere in due modi: passare all'utente la
  lista `chiave → italiano` perché rimandi l'inglese, oppure tradurre
  direttamente (fatto così per Paywall/Informazioni, 2026-07-31 — l'unico
  termine tecnico concordato è "lavagna tattica" → *tactical board*).

---

## Premium — Strada A (in corso)

Percorso di pubblicazione/monetizzazione: roadmap completa in
**`docs/TODO_strada_A.md`** (nessun account, dati locali, abbonamento Play
Store via RevenueCat, trial 15gg gestito dallo store). Stato attuale
(sezione 2 della roadmap, "freemium gate"):

- **`lib/providers/premium_provider.dart`**: `StatoPremium`
  (`free/trial/premium`, estensione `attivo`) + `statoPremiumProvider` —
  UNICO punto di verità del gate, mai logica sparsa nelle schermate.
  **Collegato a RevenueCat** (sezione 4 della roadmap FATTA): lo stato viene
  dall'entitlement `premium` (`_daCustomerInfo`: `free` senza abbonamento,
  `trial` in prova, `premium` da abbonati), aggiornato in tempo reale dal
  listener `addCustomerInfoUpdateListener`. **Più un `AppLifecycleListener`
  che al `resume` richiama `_sincronizza()`**: da `free` forza
  `Purchases.syncPurchases()`, altrimenti solo `getCustomerInfo()`. Serve agli
  acquisti fatti FUORI dall'app — codice promozionale riscattato dal Play
  Store (l'utente esce, riscatta, rientra) o abbonamento comprato su un altro
  dispositivo: senza, il gate resterebbe chiuso finché l'utente non trova
  "Ripristina acquisti" nel paywall. Config in
  `lib/config/revenuecat.dart` (SDK key Android pubblica via
  `String.fromEnvironment` con fallback, entitlement/offering id);
  `Purchases.configure` in `main()` (solo Android, in try/catch — un
  fallimento non blocca l'avvio, resta `free`). **Nuovo default reale =
  `free`** (prima lo stub era `premium`): il toggle "Simula premium" in
  `SettingsScreen` (chiave `premium.debugForzaPremium`) forza `premium` per
  sviluppare/provare le feature senza acquisto — disponibile in debug
  sempre, in **release** solo con la build compilata
  `--dart-define=PREMIUM_OVERRIDE=true` (APK "per tester"; vedi
  `kPremiumOverrideConsentito`/`overridePremiumDisponibile`). La build di
  produzione (senza flag) non lo mostra e ignora la chiave.
- **Gate attivi**: (1) bottoni PDF e CSV in `MatchesScreen` — sempre
  visibili (vetrina), ma `_richiedePremium()` apre `PaywallScreen` invece
  dell'azione per un utente free; (2) **traiettorie**: durante il live, per
  un utente free è come se il toggle traiettorie fosse spento
  (`_registraVoto` controlla anche `statoPremiumProvider` — dopo il voto si
  procede subito, MAI un paywall in mezzo alla presa dati); le voci
  "Traiettorie battute/attacco" del drawer di `ScoutScreen`
  (`_richiedePremium()`) e i bottoni traiettorie di `MatchReportScreen`
  (`_apriTraiettorie`) aprono invece il paywall; il toggle in
  `SettingsScreen` è disabilitato con nota "Funzione premium"; (3) **una
  sola squadra e una sola partita**: da free, i FAB "Nuova squadra"
  (`TeamsScreen` e `TeamSelectionScreen`) e "Nuova partita"
  (`MatchesScreen`) aprono il paywall se ne esiste già almeno una — gate
  SOLO sulla creazione: squadre/partite esistenti restano visibili,
  modificabili e cancellabili (deciso: si deve sempre poter scendere a una
  cancellando le altre; le partite esistenti restano scoutabili, tanto gli
  export/traiettorie sono comunque gated). Badge sul FAB solo quando il
  gate scatterebbe (count ≥ 1); (4) **report parziale**: da free
  `MatchReportScreen` mostra solo dati partita, punteggi e riepilogo
  fondamentali — le altre sezioni (generici, formazioni, distribuzione
  alzate, efficienza, positività) hanno titolo+badge come vetrina e una
  card "Statistica premium" che apre il paywall al posto del contenuto
  (helper `_sezionePremium({titolo, figli})`, unico punto da ritoccare per
  spostare la linea free/premium del report); (5) **lavagna tattica**: voce
  drawer "Lavagna tattica" in `ScoutScreen` (badge premium) → da free apre
  il paywall, da premium `TacticalBoardScreen`.
- **`lib/widgets/premium_badge.dart`**: `PremiumBadge` — iconcina
  `workspace_premium` ambra (stessa del paywall) da affiancare alle feature
  gated, visibile SOLO per utente free (osserva `statoPremiumProvider`,
  `SizedBox.shrink()` con premium attivo — niente `if` nei punti d'uso).
  Piazzata su: bottoni CSV/PDF (`MatchesScreen`), bottoni traiettorie del
  report, voci traiettorie del drawer live, toggle traiettorie in
  `SettingsScreen` (`secondary`). MAI nel flusso di voto live (gate
  silenzioso, per scelta).
- **`lib/screens/premium/paywall_screen.dart`**: paywall REALE — carica
  `offerings.current` (fallback `all['default']`), mostra un bottone per
  pacchetto con `storeProduct.priceString`, "Abbonati" →
  `purchasePackage` (chiude se l'entitlement diventa attivo; cancel
  ignorato via `PurchasesErrorHelper`), "Ripristina acquisti" →
  `restorePurchases`. Offerte vuote (build non su Play) → messaggio
  "Offerte non disponibili", il resto della pagina resta.
- **`lib/screens/settings/about_screen.dart`**: "Informazioni" (voce in
  fondo a `SettingsScreen`) — versione via `package_info_plus`, link
  Privacy Policy e Terms of Use (costanti `_kUrl*`, **valorizzati**: documenti
  generati con **Termly** e pubblicati su Google Sites,
  `sites.google.com/view/volleystratego/...` — requisito Play: policy
  raggiungibile in-app), email supporto `volleystratego@gmail.com`,
  "Gestisci abbonamento" (deep link sottoscrizioni
  Play via `url_launcher`), riga "ID supporto" = `Purchases.appUserID`
  (bottone Copia).
- **Package name Android**: `it.branduich.volleystratego` (identità
  definitiva su Play — `applicationId` in `android/app/build.gradle.kts`; il
  `namespace` interno resta `com.example.volley_scout`, non visibile allo
  store). Deve combaciare con l'app Google Play su RevenueCat e su Play
  Console.

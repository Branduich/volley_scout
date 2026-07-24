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
- **Stato**: PILOTA fatto (`HomeScreen` + `SettingsScreen` — l'inglese di
  queste due l'ho compilato io). Da fare, un pezzo alla volta: tutte le
  altre schermate (il grosso è scout/report/PDF), le **label degli enum**
  (`enums.dart`: `Ruolo`/`Categoria`/`Fondamentale`… — vanno spostate fuori
  dall'enum in una funzione con `context`, `Voto.simbolo` resta com'è), e
  gli **export PDF/CSV** (seguono la lingua dell'app — decisione presa).
  Per ogni schermata nuova: si passa all'utente la lista `chiave → italiano`
  e lui rimanda l'inglese.

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
  listener `addCustomerInfoUpdateListener`. Config in
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
  Privacy/Terms **placeholder** (costanti `_kUrl*` null finché non esistono
  gli URL iubenda — requisito Play: policy raggiungibile in-app), email
  supporto placeholder, "Gestisci abbonamento" (deep link sottoscrizioni
  Play via `url_launcher`), riga "ID supporto" = `Purchases.appUserID`
  (bottone Copia).
- **Package name Android**: `it.branduich.volleystratego` (identità
  definitiva su Play — `applicationId` in `android/app/build.gradle.kts`; il
  `namespace` interno resta `com.example.volley_scout`, non visibile allo
  store). Deve combaciare con l'app Google Play su RevenueCat e su Play
  Console.

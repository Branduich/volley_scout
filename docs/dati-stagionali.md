# Backup JSON + Dashboard stagionale web

> Piano approvato, **non ancora iniziato** (verificato al 2026-08-18: schema DB
> ancora v18, nessun `uid`, nessun package `volley_stats`). Salvato qui perché
> finora viveva solo nella cronologia di una sessione.
>
> Revisione 2026-08-18, quattro chiarimenti recepiti: monorepo = **stesso repo**;
> viste di **squadra a pari grado** con quelle individuali; una **pagina anche
> dentro l'app** sopra gli stessi widget (nuovo passo 9b); deploy v1 su **Google
> Sites + host gratuito**, dashboard **installabile come app** invece di un file
> locale.

## Contesto

L'app produce report per **singola partita**. Manca la domanda che interessa
davvero a un allenatore: *questa giocatrice sta migliorando nel tempo?* Il piano
originale in Drive (`piano-dashboard-stagionale-volley.md`) proponeva una
dashboard web che aggrega N CSV. Verificando il codice, quel percorso non regge:
il CSV (`lib/data/match_csv_exporter.dart`) ha **valori localizzati IT/EN**,
separatore e decimale variabili, voto errore scritto `'=` con apice anti-Excel,
**nessun id stabile** di giocatore o riga, la data solo nel nome del file, e
**manca** formazione, rotazione, sistema 5-1/6-2 e `ruoloAvversario` — quindi
distribuzione alzate, filtro rotazione e statistiche avversarie sono impossibili,
per qualunque quantità di codice.

Deciso con l'utente:

- **Import = un solo file di backup JSON**, non N CSV. Il CSV resta invariato.
- Il nuovo export serve anche come **backup/ripristino** dell'app: una feature,
  due scopi. Oggi tablet perso = stagione perduta.
- La pagina web è **vetrina + strumento**: chi arriva senza l'app vede una
  dashboard piena di dati demo, esplorabile senza registrarsi, con CTA al
  download; chi ha l'app carica il proprio backup.
- Gli stessi dati si vedono **anche da una pagina dentro l'app** (dove il file
  non serve: legge il DB), ma il posto dove danno il meglio è lo schermo grande
  del PC.
- Le viste di **squadra** (tipico: dove cadono le palle in ricezione su tutte le
  partite del periodo) stanno **a pari grado** con quelle per singola giocatrice.
- **Elaborazione 100% nel browser**, zero backend, zero account, zero upload.
  Persistenza in IndexedDB. I dati contengono cognomi di minorenni: senza upload
  non c'è trattamento, quindi nessun adempimento GDPR.

Esito atteso: la feature backup consegnabile da sola al passo 3, e una vetrina
pubblica linkabile che fa da traino all'app.

## Il percorso utente (validato su un caso concreto)

Un utente premium che ha scoutato 4 partite a settembre:

1. Scouta normalmente — l'export non è qualcosa da ricordarsi *durante*.
2. **Impostazioni → Backup e ripristino → Esporta**: share sheet Android, file
   `volley_stratego_backup_2026-09-28.json`, ~200 KB per 4 partite.
3. Per guardare **sul tablet**: salva in File/Download, apre Chrome, carica. Tre
   tap, nessun trasferimento. Per guardare **sul PC**: Drive / "Messaggio a te
   stesso" su WhatsApp / email, poi scarica dal PC. **È l'unico punto di frizione
   reale**, ed è ineliminabile senza un backend che sincronizzi — cioè
   esattamente ciò che si è deciso di non fare.
4. Apre l'URL: **nessuna registrazione, nessun login**. Vede subito la dashboard
   demo col banner "dati dimostrativi", trascina il file, i numeri diventano i
   suoi. Alle visite successive da quel PC i dati sono già lì (IndexedDB).
5. **Installa la dashboard come app del PC** (l'icona "Installa" di Chrome): da
   lì in poi è un'icona sul desktop, finestra propria, nessun indirizzo da
   ricordare, e col service worker del build web funziona **anche offline**.
   L'URL serve una volta sola. Chi non vuole installare mette un segnalibro.

**Perché non un singolo file `.html` da aprire in locale**, che sarebbe la
scorciatoia ovvia: da `file://` un'app Flutter non parte (il browser blocca il
caricamento di motore/asset come cross-origin → pagina bianca) e **IndexedDB non
è disponibile** su origine opaca, quindi salterebbe proprio il "la seconda volta
i dati sono già lì". Un `.html` autonomo davvero funzionante sarebbe HTML+JS
scritti a mano: niente riuso di `MultiTrajectoryPainter`, formule in doppia
copia, e nessun URL da condividere. L'installazione come app dà la stessa
comodità senza rinunce.

**Conseguenza che semplifica il piano: il backup è sempre completo** (tutte le
partite dall'inizio), quindi nel flusso normale l'ultimo file caricato sostituisce
il precedente e basta. Il merge per `uid` serve solo nei casi limite (due
dispositivi, partite cancellate dall'app), non nel percorso principale — quindi
al passo 8 basta "sostituisci", il merge può slittare.

**Conseguenza sull'ordine dei passi: il tabellone aggregato viene prima del
grafico di tendenza.** Con 4 partite il tabellone è già utile; una retta di
regressione su 4 punti è statisticamente vuota e mostrarla con sicurezza è
fuorviante. Il trend acquista senso verso l'ottava-decima partita. Quindi i passi
7 e 9 sono invertiti rispetto alla prima stesura (vedi sotto), e la striscia del
volume nel grafico non è un abbellimento: è ciò che impedisce di leggere un
miglioramento costruito su tre attacchi.

## UI/UX della dashboard

**Struttura: tre tab con barra filtri comune, e lista giocatrici a sinistra
nella tab Giocatrici.** Sfrutta lo schermo grande, che è la ragione per cui la
dashboard sta sul web e non dentro l'app.

```
┌─────────────────────────────────────────────────────────────┐
│ Volley Stratego   I tuoi dati · 12 partite      [Cambia file]│
├─────────────────────────────────────────────────────────────┤
│ Periodo [Tutta la stagione ▾]  Campo [Tutte ▾]  Set [Tutti ▾]│
├─────────────────────────────────────────────────────────────┤
│   SQUADRA  │▎GIOCATRICI▐│  TRAIETTORIE                       │
├────────────┴────────────┴───────────────────────────────────┤
│ Ordina: EF%▾│  Anna Bianchi · Schiacciatore · #4             │
│             │  ┌────────┬────────┬────────┬────────┐         │
│▎A. Bianchi  │  │ATT 42% │RIC 61% │BAT 18% │MURO 9pt│         │
│▎  EF 42% ▲  │  │  ▲ +6  │  ▼ −2  │  ▲ +3  │  ▲ +2  │         │
│  E. Ricci   │  └────────┴────────┴────────┴────────┘         │
│    EF 38% ▲ │  Efficienza attacco nel tempo                  │
│  M. Ferri   │  60%│         ╭─╮      ╭──── ← lei             │
│    EF 31% ▼ │     │ ───╯····╰──────╯      ← compagne (grigio)│
│  G. Conti   │  20%│ ░░ ▁▃▂▅▃▄▂▅▄▃▅ ← volume azioni           │
│    EF 29% ─ │     └────────────────────────                  │
│             │      g1  g3  g5  g7  g9  g11                   │
│             │  Andata 38% → Ritorno 47%  (+9)                │
└─────────────┴───────────────────────────────────────────────┘
```

**Barra filtri globale** (vale per tutte le tab): `Periodo` con preset — Tutta la
stagione / Andata / Ritorno / Ultime 5 / Ultimo mese / Personalizzato (da–a) —
più `Campo` (tutte / casa / trasferta) e `Set` (tutti / 1-5). `Avversario` in v2.

**La giocatrice NON è nella barra filtri**: è una *selezione* (cambia di chi
guardi la scheda), non un filtro (quali dati). Sta nella lista laterale, sempre a
un clic, ordinabile per la colonna che interessa — così la domanda "e allora
questa perché è più in basso?" nasce da sola.

**Tab SQUADRA**: riga KPI (partite, V/P, efficienza attacco, punti/errori totali,
% ace, % ricezione perfetta) + una linea per fondamentale nel tempo con media
mobile + riepilogo fondamentali di squadra aggregato (lo stesso di
`MatchReportScreen`, su N partite) + distribuzione alzate per rotazione sulla
stagione. È la vista che la vetrina mostra per prima.

**Tab GIOCATRICI**: lista + scheda. Nella scheda: KPI per fondamentale **con
delta rispetto al periodo precedente**; grafico di tendenza col volume; riga
`Andata → Ritorno (+9)` che risponde alla domanda del miglioramento **senza
toccare i filtri**; distribuzione dei voti come barra divergente.

**Tab TRAIETTORIE**: campo con traiettorie aggregate del periodo filtrato +
heatmap arrivi avversari, selettori fondamentale (battuta/attacco) e giocatrice.
Riusa `MultiTrajectoryPainter` e `heatmap.dart`.

### Il dato di SQUADRA è di pari grado, non un contorno

Non solo "questa giocatrice migliora?", ma anche *"dove mi cadono le palle in
ricezione in tutte le partite del periodo?"*. Costa **meno** del dato
individuale, non di più: nel modello a eventi il giocatore è un campo su una
riga, non una dimensione dell'archivio — le funzioni esistenti aggregano già una
lista piatta di azioni e non sanno nemmeno cosa sia un giocatore (vedi
`puntiArrivoAvversari` in [heatmap.dart:22-52](../lib/logic/heatmap.dart#L22-L52),
che filtra solo per squadra/tipo/fondamentale). La vista di squadra è il caso
**senza** filtro giocatrice: si toglie un `where`, non se ne aggiunge uno.

Conseguenze concrete:

- **Ovunque ci sia un selettore giocatrice, la prima voce è "Tutte"** — vale per
  traiettorie, heatmap, distribuzione voti, tabellone.
- Heatmap ricezione/difesa **stagionale**: l'esempio d'uso principale. I blob
  sono tutti gli arrivi, i marker cerchiati sono le palle effettivamente cadute
  (sotto il Modello A un ace è battuta avversaria `#` + nostra ricezione `=`,
  cioè esattamente `puntiArrivoAvversariPerfetti`). Su una partita è aneddoto, su
  venti è la mappa di dove l'avversario ti fa male.
- Riga **totali di squadra** in fondo al tabellone stagionale (passo 7).
- Distribuzione alzate di squadra per rotazione aggregata sulla stagione.

**Ogni vista mostra su quante azioni è costruita.** Non è un dettaglio di
cortesia: la heatmap esiste solo dove le traiettorie sono state *registrate*
(serve scout avversari + toggle traiettorie attivi e il drag effettivamente
fatto), e le azioni senza `traiettoriaX2/Y2` vengono scartate in silenzio
([heatmap.dart:44](../lib/logic/heatmap.dart#L44)). Un aggregato senza il suo
denominatore inganna — stesso principio della striscia del volume nel grafico di
tendenza. Nessun formato può recuperare un dato mai preso.

**Emphasis, non multi-serie**: la giocatrice selezionata a colori, le compagne in
grigio sottile come contesto. Cinque linee colorate sono spaghetti illeggibili.

**Responsive**: sotto ~900px di larghezza la lista laterale collassa in un
dropdown e i grafici passano a colonna singola — serve perché un utente può
aprire la dashboard dal tablet con cui ha scoutato (vedi percorso utente).

## Decisioni chiave

| Tema | Scelta |
|---|---|
| Packaging | Monorepo pub workspace **nello stesso repo `volley_scout`** (non un repo a parte): root (mobile) + `packages/volley_stats` (logica pura) + `packages/volley_ui` (widget della dashboard) + `packages/volley_web` (guscio web). Creato al **passo 5**, non subito. Un repo solo perché il rischio n.1 è la deriva di formato: il commit che aggiunge un campo tocca app e web insieme, o non compila. |
| Dove si vedono i dati | **Due gusci sottili sopra gli stessi widget**: il sito (dati da file JSON + IndexedDB) e una **pagina dentro l'app** (dati letti direttamente da drift — in-app il backup non serve affatto). Le schermate NON nascono dentro `volley_web`, altrimenti sono due dashboard da tenere allineate. |
| Id stabili | Nuova colonna `uid` su `Teams`/`Players`/`VolleyMatches` (**schema v19**) via `clientDefault`. |
| Formato | JSON versionato (`formatoVersione`), enum come `.name` (mai localizzati), chiavi corte nelle azioni, coordinate a 4 decimali. Nessuna compressione in v1, ma guardia magic-byte gzip. |
| Rendering web | **`CustomPainter` funziona su Flutter Web** (CanvasKit): `MultiTrajectoryPainter` si riusa verbatim. Niente da riscrivere in SVG. |
| Storage web | IndexedDB via `idb_shim` come archivio di documenti JSON. **Non** drift-wasm (OPFS richiede header COOP/COEP non impostabili su GitHub Pages, e non serve SQL). **Non** `shared_preferences` (sul web è localStorage, ~5 MB in UTF-16). |
| Grafici | `fl_chart`. Scartato `syncfusion` (licenza con soglie su prodotto commerciale). |
| Gate premium | **Nessuno** sull'export: è portabilità dei dati, ed è il ponte verso la vetrina. Il limite c'è già gratis — free = 1 partita ⇒ dashboard vuota per costruzione. |

## Formato del file

Envelope con `formato`, `formatoVersione` (int monotono), `schemaDb`, `app`,
`esportatoIl`, poi `categorie` / `squadre` / `giocatori` / `partite` /
`campionati` (quest'ultima chiave la dashboard la salta: serve solo al
ripristino). Ogni partita annida `sets`, ogni set annida `rotazioni` e `azioni`.

Scelte non ovvie, con il motivo:

- **`uid` stabili.** Senza, unire due export ("carico la stagione, poi aggiungo
  la partita nuova") richiede euristiche sui nomi, il ripristino non è
  idempotente e non si può seguire una giocatrice che cambia numero di maglia.
  L'alternativa `cognome|nome|numero` fallisce su rinomine e omonime.
- **Le azioni non hanno `uid`**: si importano a blocchi, l'identità è
  `(partitaUid, set.numero, ordine)`. Il parser assegna a ogni azione un `int id`
  progressivo al load, così `idAttacchiSuRicezione` e `zonaTatticaPerAzione`
  (mappe keyed su `ScoutAction.id`) funzionano **senza toccare la logica**.
- **Voto come `"perfetto"`, non `"#"`.** Il simbolo è presentazione — è proprio
  ciò che ha costretto il CSV a inventarsi `'=`
  ([match_csv_exporter.dart:74-77](../lib/data/match_csv_exporter.dart#L74-L77)).
- **Chiavi corte nelle azioni** (`o`/`r`/`f`/`v`), lunghe altrove: le azioni sono
  il 95% del file, `"fondamentale"` × 15.000 costa 200 KB di sole chiavi.
- **`t` = secondi dall'inizio partita**, non timestamp assoluto: `_durataSet`
  usa solo differenze, e il file diventa immune al fuso orario.
- Misura: `demo_match.json` è 109 KB per 456 azioni ma è pretty-printed con 16
  decimali. Con queste scelte: ~40-50 KB/partita, ~1,5 MB per una stagione.

Regola di versionamento: **campi nuovi sono additivi e non alzano la versione**,
il lettore ignora le chiavi che non conosce. La versione sale solo per cambi
incompatibili. Un `formatoVersione` più recente del supportato viene **rifiutato
con messaggio esplicito**, mai parsato parzialmente.

`assets/demo/demo_match.json` **non va esteso ma sostituito**: è una conversione
lossy da un'altra app (voti come simboli, `nome: "-"`, nessuna rotazione
avversaria, nessun `sistemaGioco`). Resta però un'ottima *sorgente di dati* per
generare la stagione demo.

## File critici

- [lib/data/database.dart](../lib/data/database.dart) — migrazione v19, pattern
  idempotente già in uso alle righe 325-336
- [lib/data/match_csv_exporter.dart](../lib/data/match_csv_exporter.dart) — modello
  per il nuovo `backup_json.dart`, e il pattern di share alle righe 247-263 (quel
  commento documenta l'unica combinazione che funziona con Drive)
- [lib/providers/database_provider.dart](../lib/providers/database_provider.dart) —
  dove nasce `BackupRepository`; da estrarre `attaccoMurato` /
  `idAttacchiSuRicezione` (58-97) e `zonaTatticaPerAzione` (454)
- [lib/screens/report/match_pdf_screen.dart](../lib/screens/report/match_pdf_screen.dart)
  — **formule canoniche** da promuovere: `_eff`/`_pos`/`_pctSu` (853-860),
  `_calcolaStatGiocatori` (765-845), `puntiTotali`/`erroriTotali` (90-99). Sono la
  versione più completa delle tre copie esistenti
- [lib/widgets/court_trajectories_view.dart](../lib/widgets/court_trajectories_view.dart)
  — `buildTrajData` (47) e `MultiTrajectoryPainter` (160), riusabili sul web
- [lib/logic/heatmap.dart](../lib/logic/heatmap.dart) — già pura e già
  aggregante: le viste di squadra sulla stagione sono queste stesse funzioni con
  in pasto le azioni di N partite. Nessuna logica nuova
- [lib/data/demo_match_importer.dart](../lib/data/demo_match_importer.dart) — si
  riduce a "leggi asset → ripristina" al passo 13

## La mossa che rende economico il refactor

Tutta la logica riusabile è tipizzata sulle righe drift. Per non riscrivere i
call-site nelle 20 schermate:

> Il package espone la funzione pura sui **tipi neutri**; l'app tiene nello
> stesso file di prima un **adapter di 3 righe con la firma vecchia**.

Esempio reale: `role_labels.dart` prende `Map<String, Player>` ma legge **solo
`.ruolo`**. Nel package diventa `roleLabelsFor(String, Map<String, Ruolo>)`;
nell'app resta un wrapper che mappa. Zero modifiche a `scout_screen.dart`,
`formation_config_screen.dart`, `database_provider.dart:520`.

`volley_stats` non importa mai `drift`, `flutter_riverpod`, `AppLocalizations` o
`BuildContext`. Regola secca: **se compila con solo `flutter`, gira sul web.**

`volley_ui` (i widget: grafici, tabelle, campo) può ovviamente usare
`BuildContext`, ma vale la stessa regola sulle dipendenze: solo `flutter` +
`fl_chart` + `volley_stats`, mai drift né riverpod. Riceve **dati già pronti** e
callback; chi glieli passa è il guscio — dal DB nell'app, dal JSON sul web. È
quello che rende la pagina in-app quasi solo colla.

## Passi

Ogni passo è verificabile da solo e non lascia l'app rotta.

**1. `uid` stabili (schema v19).** `clientDefault(nuovoUid)` su
`Teams`/`Players`/`VolleyMatches`; migrazione `ALTER TABLE` + `UPDATE …
randomblob(16)`, idempotente come le altre; `dart run build_runner build`.
*Verifica*: l'app apre con i dati esistenti; test su `AppDatabase.perTest` (pattern
di `test/providers/scout_action_repository_test.dart`) che asserisce uid non vuoto
e unico. *Prima di tutto*, perché rimandarlo costa un formato v2.

**2. DTO + serializzazione.** `lib/data/backup_model.dart` (zero import drift —
al passo 5 si sposta con un `git mv`) + `lib/data/backup_json.dart` (mapping
drift→DTO, `toJson`/`fromJson`, guardia gzip, guardia versione).
`docs/backup-format.md`.
*Verifica*: test che importa la demo, esporta, ri-parsa e confronta conteggi; poi
asserisce che `ricalcolaStato()` sulle azioni ri-parsate dà **lo stesso punteggio
finale** del referto (pattern di `test/logic/demo_match_test.dart`) — è il test
che dimostra "non ho perso niente".

**3. Export + share → feature consegnabile.** `BackupRepository.esportaTutto()`
in `database_provider.dart`; sezione "Backup e ripristino" in `SettingsScreen`
(che ha già la sezione Export a riga 139), con la riga "il file resta sul tuo
telefono, nessun dato viene inviato a noi"; share col pattern di
`match_csv_exporter.dart:259`, `mimeType: application/json`; chiavi ARB IT/EN
prefisso `backup*` + `flutter gen-l10n`.
*Verifica*: Impostazioni → Esporta → share sheet → apri il `.json` e guardalo.
**Qui hai già una feature vendibile, senza una riga di web.**

**4. Ripristino in-app.** `openFile` come
[campionato_screen.dart:407-424](../lib/screens/campionato/campionato_screen.dart#L407-L424)
→ parse → `ripristina(modalita:)`. Due modalità: `aggiungi` (dedup per uid,
default) e `sostituisciTutto` (distruttiva, conferma esplicita).
*Verifica*: emulatore pulito → ripristina il file del passo 3 → il report di una
partita mostra numeri identici; re-importa → "0 nuove, N già presenti".
**È il vero test del formato**: se il round-trip attraverso l'app è perfetto, la
dashboard non può trovare buchi.

**5. Package condiviso.** Un file per commit, mai un commit da 40 file.
- 5.0 (5 min): `packages/volley_stats` vuoto + `workspace:` → `flutter pub get` +
  `dart run build_runner build`. Se il codegen drift gira, procedi; se no,
  degrada a `path:` dependency togliendo tre righe. È l'unico rischio da provare
  prima.
- 5.1 `git mv` di DTO e serializzazione.
- 5.2 `ricalcola_stato.dart`, `attack_positions.dart`, `defense_positions.dart`;
  l'app li re-esporta con una riga `export 'package:volley_stats/…';` ⇒ nessun
  import da cambiare.
- 5.3 `role_labels`, `heatmap`, `traj_data`, `multi_trajectory_painter` con la
  tecnica pura+adapter; elimina il duplicato `_TrajPdf`
  ([match_pdf_screen.dart:1470-1499](../lib/screens/report/match_pdf_screen.dart#L1470-L1499)).
- 5.4 `stat_fondamentali.dart`: promuovi le formule dal PDF e fai puntare lì
  anche `match_report_screen.dart:570-591` (tre copie → una).
- 5.5 `zonaTatticaPerAzione` sincrona nel package — **RIMANDATO** (2026-08-20),
  insieme a `_calcolaStatGiocatori`. Motivo: il passo 6 non ne ha bisogno (la
  riga KPI si costruisce con `stat_fondamentali` e i DTO, già nel package),
  mentre l'estrazione richiede un tipo neutro molto più ricco di `TiroScout`
  (azioni con id/ordine/esito e i tre riferimenti del cambio giocatore, più la
  formazione per set) su cento righe che rigiocano cambi e rotazioni. Lavoro
  delicato il cui valore arriva al passo 12: si fa quando la dashboard chiederà
  la distribuzione alzate. **In compenso quella funzione ora è TESTATA**
  (`test/providers/zona_tattica_test.dart`, buco segnalato da mesi in
  docs/context/scout-avversario.md): la rete di sicurezza per spostarla c'è già.
*Verifica dopo ogni sotto-passo*: `flutter analyze` pulito, `flutter test` verde,
e **numeri identici a prima**. Per gli spostamenti di formule non si guarda un
PDF a memoria: si scrive un test usa-e-getta che rimette le vecchie formule
verbatim e le confronta con le nuove su tutte le combinazioni (fatto al 5.4:
35.658 confronti, zero differenze), poi si cancella — tenerlo congelerebbe
proprio le copie che si stanno eliminando.

**6. Dashboard, primo pixel.** `packages/volley_ui` (i widget) + `packages/volley_web`
con `flutter create --platforms=web` (guscio); carica un backup come asset e
mostra **solo** la tab Squadra con la riga KPI. Nessun filtro ancora. Anche il
primo widget nasce in `volley_ui`, non nel guscio: è la separazione che al passo
9b rende la pagina in-app quasi gratis.
*Verifica*: `flutter run -d chrome`, numeri che coincidono col report dell'app.

**7. Tabellone stagionale + lista laterale** (era il 9 — vedi "percorso utente":
è ciò che dà valore già a 4 partite). La mega-tabella del PDF aggregata sulla
stagione, ordinabile per colonna; la lista laterale della tab Giocatrici è la sua
versione compatta, stessi dati. Riusa `_calcolaStatGiocatori` verbatim. In fondo
la **riga totali di squadra**, e in cima il conteggio delle azioni su cui è
costruita.
*Verifica*: su una partita sola, celle identiche a quelle del PDF.

**7b. Barra filtri globale.** Periodo (preset + intervallo), Campo, Set. Un solo
oggetto `Filtro` immutabile passato alle funzioni pure di `volley_stats` — nessun
filtro applicato dentro i widget, così è testabile senza UI.
*Verifica*: "Solo in casa" + "Set 1" su una partita nota dà gli stessi numeri che
si ottengono a mano dal referto.

**8. Import + IndexedDB.** Sostituzione integrale del documento: il merge per
`uid` slitta, non serve al percorso normale. Diviso in due commit, perché la
prima metà si verifica senza persistenza e la seconda ha bisogno del browser.
- 8a **Caricare un backup** (fatto): trascinamento (`desktop_drop`, che sul web
  espone `DropItem extends XFile` — `readAsString()` funziona dove i path non
  esistono) + bottone con `file_selector`, banner della sorgente, "torna ai dati
  di esempio". `PaginaSquadra` è uscita da `main.dart` in un file suo: il guscio
  importa i plugin del browser, i test girano sulla VM, e separandoli la pagina
  si monta senza browser. **Due reset dei filtri, non uno**: `ValueKey` sul nome
  file (documento diverso → rimonta) e `didUpdateWidget` (stesso nome, contenuto
  nuovo → il backup si riesporta ogni settimana con lo stesso nome, quindi la
  chiave non cambia). Senza, un filtro rimasto appeso mostra la pagina vuota e
  sembra un file letto male.
- 8b **Ricordarlo** (fatto): `ArchivioBackup` su `idb_shim`. Conserva il **testo
  JSON grezzo**, non l'oggetto letto: l'archivio non sa niente del modello, e un
  documento scritto da una versione vecchia ripassa dagli stessi controlli di
  formato e versione di un file appena trascinato invece di essere letto a metà
  (se non passa, viene rimosso e lo si dice — altrimenti resterebbe illeggibile
  a ogni visita). La `IdbFactory` **arriva da fuori**: il guscio passa quella del
  browser, i test quella in memoria, e il file non dipende da `dart:html`. I
  metodi lasciano passare gli errori: la politica — proseguire senza memoria
  invece di rompere la pagina — sta nel guscio, in un punto solo, e il banner
  smette di promettere una memoria che non c'è.
  - **Un bottone solo invece di due** (scelta diversa dal piano): "torna alla
    demo" e "azzera" sono diventati **"Rimuovi i miei dati"**. Tenerli separati
    creava uno stato — guardo l'esempio ma i miei dati sono ancora salvati — in
    cui il banner non sa più cosa dire, e lasciava il documento archiviato
    irraggiungibile. Il bisogno vero è togliere i propri dati da un computer non
    proprio; l'esempio è lo stato d'ingresso a cui si torna, non una vista da
    visitare. Chi vuole solo cambiare file ha "Apri un altro backup".
*Verifica*: droppi il backup → i numeri cambiano; **F5 → i dati sono ancora lì**.
Archivio testato col backend in-memory di `idb_shim`, senza browser.
**Per provarlo a mano serve `flutter run -d chrome --web-port=8080`**: per un
browser l'origine è schema + host + **porta**, e `flutter run` senza `--web-port`
ne sceglie una nuova a ogni lancio. Con la porta che cambia, ogni esecuzione
guarda in un IndexedDB diverso e la memoria sembra non funzionare anche quando
funziona. Vale solo in sviluppo: dopo il passo 10 l'origine è un dominio fisso.
Da ricordare anche che quel server vive quanto il comando — un URL salvato nei
preferiti non risponde più quando `flutter run` è finito.

**9. Il grafico di tendenza** (era il 7). Selettore giocatrice + `fl_chart`:
eff/pos per fondamentale nel tempo, retta di tendenza, **striscia volume**, filtro
minimo-azioni.
*Verifica*: su una partita sola il grafico ha un punto e non esplode; con la
stagione demo mostra una tendenza leggibile. Con meno di ~6 partite la retta va
nascosta o marcata come poco significativa, non disegnata come un fatto.

**9b. Pagina dashboard dentro l'app.** Voce nel menu di `HomeScreen` → schermata
che legge il DB via un repository, mappa sui DTO neutri e passa gli stessi widget
di `volley_ui`. **Nessun export/import di mezzo**: i dati sono già lì, aggiornati
all'ultima azione registrata. Orientamento `kOrientamentoTutti`, layout che si
adatta (vedi convenzione #9).
*Perché DOPO il web e non prima*: sul telefono la dashboard è compressa — dodici
colonne per dodici giocatrici, o un grafico con le compagne in grigio, su 6
pollici in verticale non si leggono. Progettare i grafici sullo schermo più
scomodo e poi allargarli è l'ordine sbagliato. In-app vanno le viste che reggono
lo spazio stretto (KPI di squadra, scheda giocatrice, tendenza); tabellone
completo e traiettorie aggregate restano leggibili su tablet e danno il meglio
sul PC. Nessuna funzione tolta, solo il layout che si adatta.
*Verifica*: stessa partita, numeri identici fra pagina in-app, PDF e dashboard web.

**10. Vetrina + deploy.** Google Sites (già esistente) come porta d'ingresso +
host statico gratuito per la dashboard + installabile come app. Vedi sotto.

**11. Stagione demo vera** (12 partite con tendenze). Script `dart run` con seed
fisso, non un export manuale — altrimenti dopo il secondo cambio di formato la
demo non parsa più. **Non toccare i voti terminali**: cambiare un `#` in `=` su
un'azione con `esitoPunto` rompe il punteggio. Muovi solo i voti su azioni con
esito `nessuno`, e per creare tendenze in attacco **riassegna l'esecutore** a
un'altra giocatrice dello stesso ruolo (l'esito resta, le percentuali cambiano).
*Verifica*: test che (a) parsa, (b) `ricalcolaStato()` riproduce ogni referto,
(c) "Bianchi migliora in attacco fra prima e ultima partita" è **vero** — la
storia della vetrina garantita da un test, non dalla fortuna.

**12. Traiettorie aggregate + heatmap + distribuzione alzate** sul web (riuso del
painter, costo quasi zero).

**13. Unifica il demo in-app** sul formato backup; `demo_match_importer.dart` si
riduce a due righe.

**14. Revisione dei contenuti — ULTIMO passo, quando tutto il resto è in piedi.**
Rivedere *quali* dati la dashboard mostra e *come* li mostra: oggi la vista di
squadra è cresciuta un pezzo alla volta (KPI, tabellone, tendenza) seguendo
l'ordine in cui erano pronti i calcoli, non l'ordine in cui un allenatore se li
chiede. Va guardata intera, con una stagione vera davanti, e riordinata —
togliendo quello che non si guarda mai e dando spazio a quello che si guarda
sempre.
*Perché alla fine e non prima*: con cinque partite demo e metà delle viste
ancora da fare (traiettorie aggregate, heatmap) qualunque riordino sarebbe una
decisione presa su un disegno incompleto, da rifare al passo dopo. Deciso con
l'utente il 2026-08-28, subito dopo aver visto 9b funzionare.

*Primo giro fatto il 2026-08-29*, guardando la pagina intera:
- **Riga KPI**: ordine rifatto — Partite, Set, Punti, Errori, Ace, Efficienza
  attacco, Positività ricezione. Le tessere sono tutte alte uguali (la riga del
  sottopancia c'è sempre, vuota quando non serve: un'altezza in pixel si
  sfascerebbe al primo cambio di font). Le due percentuali portano la formula
  sotto, con le stesse stringhe delle card del report nell'app.
  **"Ricezione perfetta" è diventata "Positività ricezione"** — non solo
  l'etichetta: `RiepilogoStagione.positivitaRicezione` somma `#` e `+`. La
  perfetta da sola dava 0% su una stagione intera, cioè un numero che non si
  guarda.
- **Tabellone**: si chiama **Atleti** (come il filtro della tendenza e delle
  traiettorie: "giocatrice" è sparito dall'interfaccia) e ha un selettore
  Riepilogo / Battuta / Attacco / Ricezione / Difesa / Muro. Il riepilogo
  risponde a "chi sta giocando bene"; le viste per fondamentale sono la fetta
  corrispondente della **mega tabella del PDF**, sotto-blocchi "su ricezione" e
  "su difesa" compresi — che è la ragione per cui l'allenatore la stampava.
  Chi non ha toccato quel fondamentale mostra `0` nel totale e **celle vuote**
  nel resto: la riga resta (si vede chi non riceve mai) senza riempirsi di zeri
  e trattini che sembrano dati.
- Tutto questo NON è costato un calcolo nuovo: `StatGiocatore` teneva già i
  conteggi per voto di tutti e cinque i fondamentali più la partizione
  dell'attacco. Era solo questione di quali mostrare.

**15. Colore alla dashboard — ULTIMA miglioria** (decisa con l'utente il
2026-08-29, dopo il passo 14). Portare sulla dashboard i **colori per gruppo di
colonne della mega tabella del PDF**: battuta pesca `FCE5CD`, attacco verde
`D9EAD3` coi due sotto-blocchi in `EBF3E8`, ricezione `C9DAF8`, difesa `9FC5E8`,
muro `EAD1DC`, punti/errori `D5A6BD` — la lista sta in `_buildMegaTabella`
(`screens/report/match_pdf_screen.dart`), presa a suo tempo dal foglio Google
dell'utente.

*Perché non è decorazione*: la vista per fondamentale del tabellone È la fetta
corrispondente del PDF. Con gli stessi colori le due cose si riconoscono come lo
stesso documento invece di sembrare due tabelle che dicono per caso le stesse
cose. Il colore qui **richiama il dato**, che è esattamente l'uso buono del
colore in una tabella di numeri.

Due vincoli da rispettare quando si farà:
- **Gli stessi widget girano sotto due temi diversi** — il guscio web
  (`ThemeData(colorSchemeSeed: 0xFF1E3A8A)`) e la pagina dentro l'app
  (`AppTheme.light`, Barlow e palette del brand). I colori del PDF sono valori
  fissi e vanno bene come tali, ma tutto il resto (testo, sfondi, bordi) deve
  continuare a uscire da `Theme.of(context).colorScheme`, o la dashboard in-app
  stona con l'app che le sta intorno. Verificare il contrasto del testo sopra
  ognuna delle tinte: sono pastelli nati per la carta.
- **Non colorare anche i numeri per valore** (efficienza rossa/verde) nello
  stesso momento: due codici colore sovrapposti nella stessa tabella non si
  leggono più. Se un domani serve, prima si toglie quello per gruppo.

## La vetrina: deploy e SEO

### v1: Google Sites (già esistente) + host statico gratuito

**Nessun dominio da comprare, e la landing HTML fatta a mano slitta.** L'assetto
della prima versione:

- **Google Sites resta la faccia pubblica** — è la pagina che già ospita privacy
  e termini (requisito Play, vedi `about_screen.dart`). Ci si aggiungono
  istruzioni, screenshot e le parole chiave reali, e un pulsante grosso **"Apri
  la dashboard"**. È testo vero e già indicizzabile: copre da sola il problema
  SEO descritto sotto, che nasceva dal fatto che una pagina Flutter per Google è
  vuota. Per l'utente c'è **un indirizzo solo da ricordare**, quello che già
  conosce.
- **La dashboard gira altrove**, perché Google Sites non è un hosting: non
  permette di caricare file, e un'app Flutter Web è `index.html` + motore + font
  + asset da servire. Serve un host statico — Cloudflare Pages o Netlify, che
  danno un sottodominio gratuito con HTTPS (`…pages.dev`). Zero euro, nessuna
  carta, nessun dominio.
- **Link, non "Incorpora".** Il gadget di embed di Google Sites metterebbe la
  dashboard in un iframe di terza parte: Safari **blocca** lo storage e Chrome lo
  **partiziona** ⇒ salta "la seconda volta i dati sono già lì"; salta anche
  l'installazione come app (non offerta dentro un iframe); e un'altezza fissa
  produce una barra di scorrimento dentro un'altra. Un link che apre in scheda
  nuova costa niente e conserva tutto.
- **Quando arriverà il dominio**: due record DNS, la dashboard passa a
  `dashboard.…`, e sul Sites cambia l'URL del pulsante. Niente da riscrivere.

### Se un domani la landing la fai tua

Flutter Web disegna su canvas, quindi **per Google la pagina non ha testo**. Se
la vetrina è "solo Flutter", il traino non funziona. Soluzione: **la landing è
HTML vero, Flutter si monta in un div.**

1. `web/index.html` con il contenuto di marketing come HTML statico (h1, prosa
   con le parole chiave reali — "statistiche pallavolo", "scout partita",
   "efficienza attacco" — screenshot con `alt`, link Play Store, FAQ): visibile
   subito, indicizzabile, leggibile prima che Flutter scarichi.
2. `_flutter.loader.load({ config: { hostElement: … } })` monta la dashboard in
   `#dashboard`, sotto la piega, con un bottone "Esplora la demo".
3. Open Graph + `twitter:card`: metà del traino in questo settore è il link
   incollato in WhatsApp. Oggi `web/index.html` dice ancora *"A new Flutter
   project"*.
4. `application/ld+json` schema `SoftwareApplication`, `robots.txt`, `sitemap.xml`.
5. Hosting: Cloudflare Pages o Netlify (header controllabili), non FTP — MIME
   errati su `.wasm` rompono il caricamento in silenzio. Costo ricorrente a
   regime: 0 € di hosting, e non scala col numero di utenti perché l'elaborazione
   è nei loro browser. La scelta dell'host specifico non è bloccante: fino al
   passo 10 si prova in locale con `flutter run -d chrome`.

### Installabile come app (da curare al passo 10)

Manifest e icone a posto ⇒ Chrome offre "Installa" e la dashboard diventa
**un'icona sul desktop**, in finestra propria, senza barra indirizzi. È la
risposta al "non voglio digitare un indirizzo ogni volta", e col service worker
del build web funziona **anche offline** dopo la prima visita — cioè quello che
si sperava dal file locale, che invece non è praticabile (vedi percorso utente).
HTTPS è un requisito, ed è incluso nel sottodominio gratuito. Da verificare in
concreto qui, non darlo per scontato.

## Rischi

- **Privacy, bloccante per il passo 10**: `assets/demo/demo_match.json` contiene
  cognomi reali di giocatrici di squadre reali (righe 10-82). Oggi è dietro
  `kDebugMode`, quindi tollerabile; su una vetrina indicizzata è pubblicazione di
  dati personali di terzi, potenzialmente minorenni. Il demo pubblico **deve**
  usare nomi inventati.
- **Deriva di schema app/dashboard**: additività come regola; rifiuto esplicito
  delle versioni future; un fixture JSON per versione in
  `packages/volley_stats/test/fixtures/` con un test che li parsa tutti; monorepo
  così il commit che aggiunge un campo tocca app e web insieme.
- **IndexedDB**: navigazione privata e "cancella dati siti" lo svuotano; Safari
  scarta i dati dopo settimane di inattività. Il banner deve dire "salvato in
  questo browser" — è una cache, non un archivio. Metti `onUpgradeNeeded` da
  subito, anche se v1 non fa nulla.
- **Grafici**: mai doppio asse Y per efficienza e volume (barre sottili sotto la
  linea, stesso asse X); il volume *va mostrato*, perché il 100% su 3 attacchi non
  è un miglioramento. La distribuzione dei voti è una scala **ordinata**: barra
  divergente, non 5 colori. Attenzione che `CourtStyle.votoColor` mappa
  `positivo → blue`, giusto nell'app live ma arcobaleno in un grafico: serve una
  `votoRamp` separata solo per i grafici. `AppColors.success/warning/danger` sono
  colori di stato, non serie.
- **Monetizzazione**: una dashboard gratuita e completa potrebbe erodere la
  ragione per abbonarsi. Oggi il freno è naturale (free = 1 partita), ma se un
  giorno alzi il limite free la dashboard diventa il prodotto e l'app la
  commodity. Decisione da prendere consapevolmente.
- `--base-href` sbagliato = pagina bianca senza errori: verificalo per primo.
  `index.html` va servito `no-cache`.

## Verifica end-to-end

Quando i passi 1-8 sono chiusi: esporta il backup dall'app su un dispositivo,
apri la dashboard in Chrome, droppa il file, e controlla che **l'efficienza
attacco di una giocatrice su una singola partita coincida cifra per cifra con la
mega-tabella del PDF** della stessa partita. Poi F5 e verifica che i dati siano
ancora lì. Quello è il momento in cui il giro è completo.

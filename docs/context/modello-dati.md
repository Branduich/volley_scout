## Modello dati

### Implementato (Fase 1)

**Teams**: id (autoincrement), nome, categoria (**testo libero** — nome della
categoria scelto da una lista modificabile, vedi Categorie personalizzabili;
da schema v13, prima era `enum Categoria` via `CategoriaConverter`),
coloreDivisa (int ARGB).

**Players**: id (autoincrement), teamId (FK -> Teams, cascade delete), nome,
cognome, numero (int), ruolo (enum Ruolo), scadenzaCertificato (DateTime nullable —
riservato a futura segnalazione visiva di scadenza imminente, impostabile via
date picker in `PlayerFormScreen`).

**Enum Ruolo**: palleggiatore, schiacciatore, centrale, opposto, libero,
undefined. Il valore `undefined` ha label **"Universale"**: può giocare al
posto di qualsiasi ruolo tranne il libero (assume l'etichetta tattica
mancante nella composizione — vedi `roleLabelsFor` in
`logic/role_labels.dart`). Il nome Dart resta `undefined` per
compatibilità: `RuoloConverter` persiste `.name` a DB e rinominarlo
romperebbe `byName()` sulle righe esistenti (players.ruolo,
match_sets.ruolo_cambi_libero, scout_actions.nuovo_ruolo_cambi_libero).

**Enum Categoria**: under11..under18, terzaDivisione, secondaDivisione,
primaDivisione, serieD, serieC, serieB, serieB1, serieB2, serieA1, serieA2, serieA3.
Da schema v13 **NON è più il tipo salvato** su `Teams.categoria` (ora testo
libero): resta solo come **sorgente dei default** della lista `Categorie`
(`default_categorie_seeder.dart` inserisce `Categoria.values[i].label`). Il
`CategoriaConverter` è stato rimosso — salvare il `.name` era fragile
(`byName()` lanciava se un valore veniva rinominato/rimosso, impossibile con
una lista personalizzabile).

**Categorie personalizzabili (tabella `Categorie`, schema v13)**: lista
modificabile delle categorie di squadra. Colonne: id, nome (text), ordine
(int, per il riordino manuale). Seminata coi 16 default alla PRIMA apertura
(`default_categorie_seeder.dart`, flag `db.defaultCategorieSeeded` +
condizione "tabella vuota" — copre sia install pulito sia aggiornamento da
<v13, dove la migrazione crea la tabella vuota e il seeder la riempie).
- **La squadra NON referenzia una riga qui**: salva il **nome** della
  categoria come testo. Scelta deliberata (più semplice/sicuro di una FK):
  eliminare o rinominare una voce NON può mai rompere una squadra esistente
  (niente riferimenti pendenti, niente policy di integrità sul delete).
- **Migrazione v12→v13**: crea la tabella `Categorie` + riscrive
  `teams.categoria` dai nomi enum alle etichette (`UPDATE teams SET
  categoria = <label> WHERE categoria = <name>` per ogni `Categoria.values`).
  La colonna era già TEXT (il converter era solo Dart-side), quindi nessun
  ALTER. Idempotente: a un retry i valori sono già etichette, nessuna riga
  combacia coi nomi enum.
- **`CategoriaRepository`** (`database_provider.dart`): `watchCategorie()`
  (stream ordinato per `ordine`), `aggiungiCategoria(nome)` (in coda,
  `ordine = max+1`), `rinominaCategoria({id, vecchioNome, nuovoNome,
  aggiornaSquadre})` (se `aggiornaSquadre`, riscrive anche `teams.categoria`
  dal vecchio al nuovo nome — cascata esplicita, ritorna il numero di squadre
  toccate), `contaSquadreConCategoria(nome)` (per gli avvisi),
  `eliminaCategoria(id)`, `riordina(idInOrdine)` (batch di UPDATE ordine).
  Provider: `categoriaRepositoryProvider`, `categorieStreamProvider`.
- **`CategorieScreen`** (`screens/teams/categorie_screen.dart`, da "Setup
  squadre"): `ReorderableListView` con drag handle esplicito
  (`buildDefaultDragHandles: false` + `ReorderableDragStartListener`, usa
  `onReorderItem` — il `newIndex` è già l'indice finale, non il deprecato
  `onReorder`). Aggiungi/rinomina via dialog con validazione (niente vuoti né
  duplicati case-insensitive). Rinomina: se N squadre usano il vecchio nome,
  dialog a 3 vie (Annulla / Solo la lista / Aggiorna le N squadre) — è qui che
  vive la cascata opzionale (es. "Under 18" → "Under 19" a inizio stagione).
  Elimina: avvisa se in uso ("N squadre resteranno marcate col vecchio testo,
  la voce sparisce dalla lista").
- **Dropdown categoria in `TeamFormScreen`**: letto da `categorieStreamProvider`.
  Nuova squadra → default alla prima categoria della lista. Se una squadra ha
  una categoria "legacy" non più in lista (rinominata/eliminata dopo la
  creazione), il dropdown la mostra comunque come voce "(non in lista)" per
  non perderla/crashare — stesso trucco del dropdown colore fuori palette.

**jerseyPalette**: lista fissa di JerseyColor (nome + Color): Rosso, Blu, Verde,
Giallo, Arancione, Viola, Nero, Bianco. Nello stesso file,
**`contrastingTextColor(Color)`**: nero se lo sfondo è chiaro
(`computeLuminance() > 0.6`, non un controllo esplicito solo sul bianco —
resta corretto anche per il colore invertito del libero, che può diventare
chiaro se il colore squadra originale è scuro), altrimenti bianco. Usata
ovunque un numero/etichetta si disegna sopra al colore squadra (raw o
invertito) invece del precedente `Colors.white` fisso — altrimenti, scelto
il bianco come colore squadra, il numero diventerebbe invisibile: lista
giocatori in `TeamFormScreen`/`LineupScreen`, badge di rotazione/token su
campo/token libero in `ScoutScreen` (`_buildRotationBadge`,
`_buildAbsoluteToken`, `_buildPlayerToken`, `_buildLiberoToken`).

**Enum SistemaGioco** (in `enums.dart`, usato in `FormationConfigScreen`):
palleggiatoreUnico ("Palleggiatore unico (5-1)"), doppioPalleggiatore
("Doppio palleggiatore (6-2)"). **Entrambi implementati**: la scelta è
persistita su `MatchSets.sistemaGioco` (v16) e passata a `ScoutScreen`/report/
PDF — vedi Modulo 6-2 sotto.

**Modulo 6-2 (doppio palleggiatore) — IMPLEMENTATO** (Fase 1 attacco + Fase 2
ricezione/difesa + PDF/report). Modello scelto: 6-2 **standard** = 2
palleggiatori diagonali (3 posizioni di distanza) + 2 schiacciatori + 2
centrali, **nessun opposto dedicato** — il palleggiatore di seconda linea alza,
quello di prima linea attacca da opposto. Punti chiave:
- **Persistenza**: `MatchSets.sistemaGioco` (v16, `.name`; `null` = 5-1 legacy),
  letta/scritta da `salvaRotazioneIniziale`/`caricaFormazione` e portata su
  `ScoutScreen`/`ConfigurazioneFormazione`. La rotazione continua a tracciare il
  **palleggiatore di riferimento** (setter 1) come `palleggiatoreSlot`;
  l'alternanza del setter attivo è derivata dalle POSIZIONI (chi è in back row),
  non uno stato nuovo → `ricalcolaStato()` invariato.
- **`FormationConfigScreen`**: col 6-2 il campo "conferma palleggiatore" chiede
  **due** palleggiatori (preselezionati i due `Ruolo.palleggiatore`), passa
  `sistemaGioco` + lo slot del setter di riferimento.
- **Etichette**: `roleLabelsFor62(currentAssignments)` (`role_labels.dart`) — la
  **POSIZIONE vince sul ruolo**: il palleggiatore in back row (P1/P6/P5) → 'P',
  l'altro → 'O'; schiacciatori → S1/S2, centrali → C1/C2. I due P sono etichette
  fisse P1/P2. Un non-palleggiatore messo nello slot diagonale (es. cambio
  alzatore→opposto confermato alzatore) diventa comunque P2. Call site in
  `scout_screen` sceglie `roleLabelsFor` vs `roleLabelsFor62` su
  `widget.sistemaGioco`.
- **Posizioni**: tabelle 6-2 in `attack_positions.dart` (`attackMapFor62`) e
  `defense_positions.dart` (`kDefensePositions62`/`defenseMapFor62`), stesso
  formato del 5-1, chiavate sullo slot del setter di riferimento (dati CSV
  utente).
- **PDF/report**: formazioni di partenza col 6-2 mostrano **due bordi rossi**
  (riferimento + diagonale, `_cellaFormazione`); `zonaTatticaPerAzione` ha un
  branch `is62` (`roleLabelsFor62`+`attackMapFor62`) che alimenta distribuzione
  alzate a video e PDF.
- **Backlog 6-2**: regole del libero nel 6-2 (Fase 3 — nel 6-2 il libero
  sostituisce tipicamente un centrale di seconda linea, mai il setter che alza)
  e scout avversario in 6-2 (Fase 5).

**BACKLOG POST-LANCIO — Configuratore posizioni** (differito 2026-07-13). Un
configuratore visuale per far posizionare all'allenatore le proprie coordinate
(attacco + ricezione, per modulo/variante/fase/rotazione/ruolo) sulla mappa, con
il default hardcodato sempre come fallback; set custom **globale per modulo**.
Innesti già centralizzati: `attackMapFor`/`attackMapFor62`
(`logic/attack_positions.dart`) e `_activeDefenseMap` (`scout_screen.dart`) →
farli passare da un resolver "custom-first, default-fallback" + tabella drift di
override. Fasi: (1) store override + resolver; (2) editor visuale (token
trascinabili, riusa `tactical_board_screen`).

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
- Schema DB attuale: **v16** (v6 ha aggiunto `stato`/`setCorrente` + le tabelle
  `MatchSets`/`Rotations`/`ScoutActions`; v7 ha aggiunto
  `MatchSets.squadraServizioIniziale`; v8 ha aggiunto
  `MatchSets.liberoId`/`libero2Id`/`ruoloCambiLibero`; v9 ha aggiunto
  `MatchSets.correzionePuntiNostri`/`correzionePuntiAvversari`; v10 ha
  aggiunto `ScoutActions.traiettoriaMuroX`/`traiettoriaMuroY`; v11 ha
  aggiunto `ScoutActions.giocatoreUscenteId`/`nuovoPalleggiatoreId`/
  `nuovoRuoloCambiLibero` per il cambio giocatore; v12 ha aggiunto
  `ScoutActions.gruppoCambio` per l'undo atomico dei cambi confermati
  insieme — vedi "cambio giocatore" in Fase 3; v13 ha aggiunto la tabella
  `Categorie` e trasformato `Teams.categoria` in testo libero — vedi
  Categorie personalizzabili sopra; v14 ha aggiunto
  `MatchSets.palleggiatoreAvversarioSlot` (int nullable — slot 1-6 del
  palleggiatore avversario a inizio set); v15 ha aggiunto
  `ScoutActions.ruoloAvversario` (text nullable — ruolo placeholder P/O/S1/
  S2/C1/C2 dell'azione avversaria) — entrambi per lo Scout avversario, vedi
  la sezione dedicata; v16 ha aggiunto `MatchSets.sistemaGioco` (text nullable,
  `.name` di `SistemaGioco`; `null` = 5-1 legacy) per il modulo 6-2 — vedi
  Modulo 6-2 sotto).

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
testata in `test/logic/ricalcola_stato_test.dart` (27 test, tutti verdi).
Deliberatamente **disaccoppiata da Drift/DB**: non usa la tabella
`ScoutActions` ma una classe minimale `AzioneScout` (const: `ordine`,
`esitoPunto`, `sostituzione` opzionale — era un record typedef, promossa a
classe per il campo opzionale del cambio giocatore) — giocatore,
fondamentale, voto, traiettoria non influenzano punteggio/rotazione e non
compaiono qui. La conversione riga DB → evento è centralizzata in
`azioneScoutDaRiga()` (database_provider.dart), usata da ENTRAMBI i replay
(`ScoutScreen._statoSetReale` e `MatchSetRepository.calcolaStatoFinale`)
così restano sempre allineati.
- Firma: `StatoSet ricalcolaStato({required List<AzioneScout> azioni,
  required Squadra servizioIniziale, required Map<int,int> rotazioneIniziale,
  int? palleggiatoreInizialeId, Ruolo? ruoloCambiLiberoIniziale,
  int? liberoInizialeId, int? libero2InizialeId})`.
  Stato iniziale passato come parametro (non letto da DB): la funzione resta
  pura e testabile senza mock. I parametri dopo la rotazione sono opzionali
  (i chiamanti che vogliono solo il punteggio possono ometterli).
- Ordina le azioni per `ordine` prima di rigiocarle (resiliente a input non
  ordinato).
- Logica: `puntoNostro` mentre il servizio non era nostro → sideout, ruota
  (`_ruotata`, oraria) e passiamo al servizio; `puntoNostro` mentre servivamo
  già → solo punteggio, nessuna rotazione. `puntoAvversario` → passano loro al
  servizio (punteggio + cambio `squadraAlServizio`), ma **nessuna rotazione
  nostra** (è il loro sideout, e non tracciamo il loro roster). `nessuno` →
  no-op.
- **Cambio giocatore** (`AzioneScout.sostituzione`, classe
  `SostituzioneGiocatore`: esceId/entraId/nuovoPalleggiatoreId?/
  nuovoRuoloCambiLibero?): il subentrante prende ESATTAMENTE la posizione
  di rotazione dell'uscente — il cambio non altera mai la rotazione, solo
  chi occupa una posizione; gli override di configurazione (null =
  invariato) aggiornano `palleggiatoreId`/`ruoloCambiLibero` dello stato.
  **Cambio del libero (stessa riga evento, nessuna colonna in più)**: se
  `esceId` è il libero effettivo (L1 o L2, mai in rotazione), il replay
  aggiorna `liberoId`/`libero2Id` invece della rotazione — vincolo di
  dominio confermato: un libero si cambia SOLO con un altro libero (sia
  per infortunio sia per scelta tecnica), mai un ruolo diverso.
  **Guardie sui dati incoerenti (mai lanciare durante un replay)**: uscente
  non presente (né in rotazione né come libero) → no-op; subentrante GIÀ
  presente — in rotazione o come libero — (con esceId ≠ entraId) →
  no-op COMPLETO, override compresi (applicarlo duplicherebbe lo stesso
  giocatore su due posizioni → ValueKey duplicate in UI, bug reale
  riscontrato). Eccezione legittima: `esceId == entraId` è la riga "no-op"
  usata per una riconfigurazione senza cambi (porta solo gli override).
- `StatoSet` (risultato): punteggio nostro/avversario, `squadraAlServizio`,
  `rotazione` (Map posizione→giocatoreId), `palleggiatoreId`,
  `ruoloCambiLibero`, `liberoId` e `libero2Id` EFFETTIVI (seguono i
  cambi). `==`/`hashCode` ridefiniti per confrontare il contenuto della
  mappa nei test, non l'identità.
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
obbligare a creare/gestire la squadra avversaria. (NB: esiste comunque lo
**Scout avversario** leggero PER RUOLO — vedi sezione dedicata — che scrive
`ScoutActions` con `squadra: avversari`/`ruoloAvversario`, ma sempre senza
roster/giocatori.) Conseguenze sul modello:
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
battuta/attacco), traiettoriaMuroX/MuroY (double, nullable, schema v10 —
solo attacco, punto di tocco a muro se il drag ha incrociato la rete, vedi
TrajectoryScreen), puntiCasaAlMomento/puntiOspitiAlMomento (int, nullable —
snapshot opzionale/debug, non sostituisce il ricalcolo).

**Enum TipoAzione** (in `enums.dart`): `scout` (giocatore + fondamentale +
voto), `puntoManuale` (bottoni rapidi "+1 Noi"/"+1 Loro", nessun giocatore),
`erroreGenerico` (punto all'altra squadra per errore non dettagliato),
`cambioGiocatore` (sostituzione a set in corso — "cambio" e non
"sostituzione" perché quel termine è già usato per la meccanica del libero;
`giocatoreId` = chi entra, `esitoPunto = nessuno`, più le colonne dedicate
`giocatoreUscenteId`/`nuovoPalleggiatoreId`/`nuovoRuoloCambiLibero` (v11,
`@ReferenceName` sulle due FK verso Players) e `gruppoCambio` (v12) — vedi
la voce in Fase 3), `timeout` (timeout chiamato da una squadra, max 2 per
set per allenatore — `esitoPunto = nessuno`, nessun giocatore, nessuna
colonna/migrazione: no-op nel replay di `ricalcolaStato()`, serve solo al
conteggio per set, al banner e all'undo; ESCLUSO dall'ereditarietà del
`rallyId` in `_registraAzione` — ha esito `nessuno` ma non apre né continua
uno scambio — vedi "Bottoni timeout" in Interfaccia di scout).

**Enum EsitoPunto**: `nessuno` (azione interna allo scambio, non chiude il
punto), `puntoNostro`, `puntoAvversario`. Calcolato in automatico in base a
fondamentale+voto (`ScoutScreen._esitoVoto()`, IMPLEMENTATO): qualunque
fondamentale con voto `=` → `puntoAvversario`; solo battuta/attacco/muro con
voto `#` → `puntoNostro` (ace, schiacciata vincente, muro punto — ricezione/
alzata/difesa non vincono mai punti da sole, preparano solo la giocata
successiva). L'esito **non è modificabile** prima di confermare l'azione:
idea annotata nel modello originale ma **scartata** (2026-07-13, non verrà
implementata) — l'automatismo fondamentale+voto è sufficiente.

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

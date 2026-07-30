## Scout avversario (scout a due squadre — IMPLEMENTATO, live + report)

Scout LEGGERO della squadra avversaria in parallelo al nostro, senza roster né
numeri di maglia: 6 token placeholder grigi PER RUOLO (P/O/S1/S2/C1/C2) che
ruotano. Abilitato dal toggle `Impostazioni.scoutAvversariAbilitato` (default
ON). Assunzione: l'avversario gioca un 5-1 canonico SENZA libero (placeholder di
squadra ignota). Nessun dato aggregato nuovo: come per noi, punteggio, rotazione
e statistiche si DERIVANO dagli eventi.

### Modello dati / logica
- `MatchSets.palleggiatoreAvversarioSlot` (v14): slot 1-6 del loro palleggiatore
  a inizio set, scelto sul campo. Determina l'INTERA rotazione avversaria via
  `etichetteAvversarie(slot)` (`role_labels.dart`). `null` = scout avversario
  non attivo per il set.
- `ScoutActions.ruoloAvversario` (v15): ruolo dell'azione avversaria. Le azioni
  avversarie hanno `squadra: avversari`, `giocatoreId: null`, `ruoloAvversario`
  valorizzato. Registrate da `ScoutActionRepository.registraAzioneAvversaria(...)`.
- `ricalcolaStato()`: `StatoSet.palleggiatoreAvversarioSlot` + parametro
  `palleggiatoreAvversarioSlotIniziale`; l'avversario ruota sul SUO sideout
  (`puntoAvversario` mentre non serviva), helper `_slotRuotato` (slot 1→6, poi
  −1). Testato (ricalcola_stato_test).
- `MatchSetRepository.salvaPalleggiatoreAvversario(setId, slot)`.

### Selezione palleggiatore avversario (inizio set)
A ogni nuovo set, se il toggle è ON, `ScoutScreen` mostra
`_buildSelezionePAvversario` (scrim + 6 zone tappabili sulla metà campo opposta,
`_kOpponentZonePositions` = riflessione delle nostre zone: 1200-x, 600-y). Scelta
la zona del loro palleggiatore si salva lo slot e partono i token.

### Fase simmetrica dello scambio (`_FaseScambio {servizio, ricezione, libera}`)
Con scout avversari attivo lo scambio è SIMMETRICO (`_faseScambio`, derivato
dagli eventi): `servizio` (nessuna battuta) → `ricezione` (battuta fatta, no
ricezione) → `libera`. Chi batte/riceve dipende da `_squadraAlServizio`. Con
scout OFF resta il comportamento originale (solo la nostra battuta/ricezione).
`_fondamentaleGiudicatoRallyCorrente` è DERIVATO dallo stream (immune all'undo).

### Modello A: la DIFESA porta il punto
Ogni coppia offesa→difesa descrive lo stesso colpo, il punto si assegna UNA
volta (solo con scout avversari attivo; con OFF resta il diretto):
- offensiva (battuta/attacco) `#`/`+`/`-` → esito `nessuno` (segue la difesa);
  `=` → punto a chi DIFENDE (palla morta);
- difensiva (ricezione/difesa) `=` → punto a chi ATTACCA; altri → `nessuno`;
- muro: terminale di suo — `#` → punto a chi mura, `=` → punto a chi attacca.
Quindi ace = battuta `#` (nostra) + ricezione `=` (loro); kill avversario =
attacco `#` (loro) + difesa `=` (nostra). `_esitoVoto`/`_esitoVotoAvversario`.

### Posizioni TATTICHE avversarie (come le nostre, specchiate)
I token avversari stanno in posizione TATTICA per fase (non su zone fisse), così
la traiettoria parte dal token giusto: `_mappaAvversario` (ruolo→Offset campo
sinistro; sceglie `attackMapFor`/`defenseMapFor` per fase in base a `_faseScambio`
+ `_squadraAlServizio`, sempre `senzaLibero: true`) → `_mirrorAvversario` (1200-x,
600-y) → `_displayPosition` (cambio campo). Il battitore avversario esce dal campo
(X<0 nella mappa → mirror X>1200), tap-catcher allineato.

### Attenuazione PER SQUADRA e tappabilità per fase
`_nostriInAttesa`/`_avversariInAttesa` (derivati da `_faseScambio`, solo con
scout avversari attivo): la squadra "in attesa" si mostra attenuata (alpha
`_kAlphaTokenBloccato` 0.5), DISTINTA dalla tappabilità:
- fase battuta: chi batte piena/attiva ma SOLO il battitore accetta il tap; chi
  riceve attenuata + disabilitata;
- dopo la battuta: chi ha battuto attenuata; chi riceve abilitata, voto forzato
  = ricezione;
- fase libera: tutti pieni + abilitati, salvo il caso "dopo un `#`" (sotto).
Nei builder token `disabilitato` = `_nostriInAttesa`/`_avversariInAttesa`.

### Scorciatoie difensive (dopo un `#`)
Dopo un'offensiva `#` la squadra che ha attaccato è bloccata (tap ignorato) +
attenuata; agisce solo chi difende:
- ace (battuta `#`): tap sul ricevitore → ricezione `=` DIRETTA, senza pannello;
- kill (attacco `#`): tap sul difensore → pannello RISTRETTO
  (`_buildBottoneFondamentale` condiviso), solo Muro/Difesa in rosso → `=`
  diretto, Alzata/Attacco grigi disabilitati.
`_erroreDifensivoForzato`, `_difesaErroreForzata*`.

### Pannello e traiettorie avversari
Tap su un token avversario → `_buildPannelloAvversario` (header col RUOLO, poi
voto). In fase libera offre Attacco/Muro/Difesa; in ricezione forza Ricezione.
`_registraVotoAvversario` apre `TrajectoryScreen` per battuta/attacco (stesso
gate traiettorie+premium del nostro `_registraVoto`): `TrajectoryScreen.giocatore`
è nullable, si passa `etichettaAvversario` per il banner. Il tipo battuta/attacco
NON resta "armato" per l'avversario.

### Report avversario (MatchReportScreen, a video)
Blocco in coda (gate `_scoutDueSquadre`), dopo un separatore col nome squadra,
con selettori dedicati (Set + Ruolo, alias `kAliasRuoloAvversario`):
- Riepilogo fondamentali (riga Alzata nascosta);
- Traiettorie battute/attacco PER RUOLO (`TrajectoryReportScreen` parametrizzata
  con `squadra` — filtro Ruolo al posto di Giocatore, filtro Rotazione = slot P
  avversario);
- Distribuzione alzate per zona/rotazione
  (`MatchSetRepository.zonaTatticaPerAzioneAvversario` — slot P avversario che
  ruota sul loro sideout, `attackMapFor senzaLibero`, NIENTE mirror: la zona è
  tattica);
- Efficienza + Positività (`_efficienzaDatiScope`/`_positivitaDatiScope`
  generalizzati, stesse formule delle card nostre).
**Bug latente corretto qui**: riepilogo/efficienza/positività/traiettorie NOSTRE
non filtravano per squadra → con scout avversari includevano per errore le azioni
avversarie (aggiunto `squadra == nostra`).
**Export PDF avversario: NON ancora fatto** (rimandato).

### Heatmap ricezione/difesa (dove cadono le palle avversarie)
Heatmap dei punti d'arrivo **nel nostro campo** delle azioni AVVERSARIE:
battuta → "Heatmap ricezione", attacco → "Heatmap difesa". Aperta dai due
bottoni nella sezione **nostra** "Traiettorie" di `MatchReportScreen`
(`_apriHeatmap`, gate premium come le traiettorie). Serve a capire dove
l'avversario fa cadere di più.
- **Riuso di `TrajectoryReportScreen`** in "modalità heatmap" (param
  `modalitaHeatmap: true`, `squadra: avversari`) — NON una schermata separata.
  In questa modalità: titolo "Heatmap ricezione/difesa"; **frecce nascoste**
  (al painter `trajectories: []`); toggle fiamma nascosto (heatmap sempre ON);
  mini-tabella (ace/in-campo/errori) + tipi battuta invariati; header con
  filtri Set + Ruolo + **Rotazione P1..P6 = NOSTRA** formazione ricezione/difesa
  al momento dell'azione avversaria (`_computeRotazioni(perAvversari: true)`
  registra lo slot del nostro palleggiatore sulle azioni avversarie del
  fondamentale, anche per la battuta).
- **Dati**: funzioni pure in `logic/heatmap.dart` — `puntiArrivoAvversari`
  (tutti gli arrivi → **blob** additivi caldi) + `puntiArrivoAvversariPerfetti`
  (solo `voto == perfetto` → **marker** cerchietto bordo rosso senza fill: ace
  per la battuta, kill per l'attacco; contribuiscono anche ai blob). Stessa
  normalizzazione di `buildTrajData` (partenza a sx → arrivo nella metà destra =
  nostro campo).
- **Resa**: `CourtTrajectoriesView`/`MultiTrajectoryPainter`
  (`widgets/court_trajectories_view.dart`) — parametri `heatmapPunti`,
  `markerPunti`, `specchia` (rotazione 180° prospettiva nostra, corregge zona
  1 vs 5). La vecchia `HeatmapReportScreen`/`HeatmapCourtView` (MVP separato)
  sono state **rimosse**: la resa blob vive ora in `MultiTrajectoryPainter`.
- **Toggle sulle viste traiettorie**: nelle "Traiettorie battute/attacco"
  avversarie (modalità normale) resta un'icona fiamma che sovrappone i blob
  alle frecce; le frecce avversarie sono comunque sempre riflesse 180°
  (`specchia: _isVistaAvversaria`).
- **Export PDF heatmap: NON ancora fatto** (come il PDF avversario).

### Limiti / backlog
Nessuna statistica per singolo giocatore avversario (nessun roster); nessun
libero avversario, nessun numero di maglia; nessun modulo diverso dal 5-1
canonico; unit test di `zonaTatticaPerAzioneAvversario` non ancora scritto (come
l'originale `zonaTatticaPerAzione`).

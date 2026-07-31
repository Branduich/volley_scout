## Campionato: import calendario FIPAV + classifica (IMPLEMENTATO)

Import del calendario di campionato esportato dal sito FIPAV (`Gare.xls`), con
pagina **Campionato** (voce in `HomeScreen`, tra "Gestione partite" e
"Impostazioni") a due tab: **Calendario** e **Classifica**. Dal calendario
l'utente sceglie **quali gare** trasformare in partite di "Gestione partite",
già compilate — non è automatico, per scelta esplicita.

### Il formato del file (verificato, non ipotizzato)

**BIFF8 binario dentro un contenitore OLE2/CFB** (magic `D0CF11E0`): NON un
`.xlsx`, NON un HTML rinominato — la fixture reale è in
`docs/samples/GareNettunia.xls`. Dal 2026-07-31 si importa **anche `.xlsx`**
(vedi sotto), con la fixture `docs/samples/Calendario completo senza 14
giornata.xlsx`: girone COMPLETO (42 gare) con le ultime due giornate svuotate
per simulare le gare da giocare.
Un solo foglio, header in riga 0, 12 colonne, **tutte le celle come stringhe
condivise** (`LABELSST`): niente date come seriale Excel, niente formule.

```
Campionato | Gara N | Giornata | Data | Ora | SquadraCasa | SquadraOspite |
Risultato | Parziali | StatoDescrizione | Impianto | IndirizzoImpianto
```

Riga d'esempio: `UNDER 18 FEMMINILE GIRONE B | 386 | 1 | 12/10/2025 | 11:00 |
MASI VOLLEY PINK B | NETTUNIA | 3-0 | 26-24 25-15 25-12 | gara omologata |
Sc.Galilei 1 - CASALECCHIO DI RENO (BO) | Via Porrettana 97`

**L'export può essere filtrato per società**: la fixture contiene solo le 12
gare di NETTUNIA (l'URL interno al file ha `societaId=4719`; manca pure la
giornata 7, turno di riposo). In quel caso la classifica è **parziale** —
mancano gli scontri fra le altre squadre — e la UI lo segnala (vedi sotto).
Per la classifica completa va esportato il **girone intero**.

### `lib/data/xls_reader.dart` — perché scritto a mano

**Nessun package Dart legge l'.xls binario legacy**: `excel`, `excel_plus` e
`spreadsheet_decoder` gestiscono solo l'Open XML `.xlsx`. Il lettore qui è
volutamente **minimale** (non un lettore Excel generico): OLE2 (FAT + DIFAT +
mini-FAT, stream `Workbook`/`Book`) e il sottoinsieme BIFF8 che serve —
`BOF`, `BOUNDSHEET`, `SST`(+`CONTINUE`), `LABELSST`, `LABEL`, `NUMBER`, `RK`,
`MULRK`; tutto il resto è saltato. API unica: `leggiXls(Uint8List) ->
List<List<String>>` sulla PRIMA worksheet.

Due punti delicati, entrambi già gestiti:
- **`CONTINUE` nella SST**: la fixture non lo innesca (SST di 1370 byte), ma un
  girone intero supera gli 8224 byte per record e lo innesca di sicuro. Al
  confine fra record il `CONTINUE` riparte con un **proprio byte di flags** che
  ridichiara la codifica (compressa Latin-1 vs UTF-16) della parte residua: una
  stringa può cambiare codifica a metà. Per questo la lettura passa da
  `_SstCursor`, che conosce i confini dei blocchi, invece di concatenare i
  payload.
- **Numerici difensivi**: questo export non ne ha, ma un altro comitato
  potrebbe emettere "Gara N" come numero. `NUMBER`/`RK`/`MULRK` vengono
  decodificati e resi come stringa, così il parser a valle non cambia.

### `.xlsx` supportato (`xlsx_reader.dart` + `spreadsheet_reader.dart`)

Si importa anche l'Open XML, utile se il file viene ri-salvato da Excel/Google
Sheets. **`data/spreadsheet_reader.dart` è il punto unico di ingresso**
(`leggiFoglioCalcolo`): riconosce il formato dai **byte** (`D0CF11E0` → BIFF8,
`PK` → xlsx, `<` → HTML), non dall'estensione, così un file rinominato a mano
funziona lo stesso. È quello che chiama `CampionatoScreen`.

`leggiXlsx` (dipendenze `archive` + `xml`) legge solo `xl/sharedStrings.xml` e
la prima worksheet, risolta seguendo `workbook.xml` → `workbook.xml.rels` (il
nome `sheet1.xml` è solo una convenzione, resta il fallback). Gestisce shared
string (anche rich text spezzato in più `<t>`), `inlineStr`, `str`, booleani,
numerici, riferimenti oltre la colonna Z e celle in errore. Come per il `.xls`,
**le celle vuote non vengono registrate**: è ciò che rende innocue le **righe di
riempimento** di Google Sheets (la fixture xlsx ha 1000 `<row>` per 43 righe
utili — senza questo, il riepilogo di import direbbe "957 righe ignorate").

Le date restano **testo** anche qui (nessuna conversione da seriale Excel): se
un domani un file le scrivesse come numeri formattati servirebbe leggere
`xl/styles.xml`.

Errori con messaggio leggibile (`FormatException`, mostrata in un dialog):
magic `PK` → "è un .xlsx, esporta in Excel 97-2003"; `<` → "contiene HTML".

### Logica pura (testata, nessuna dipendenza da DB/UI)

- **`logic/fipav_calendario.dart`** — `parseGareFipav(righe)` → `GaraFipav`.
  L'header è mappato **per nome di colonna** (normalizzato), non per posizione:
  altri comitati potrebbero spostarle. Mancano le colonne chiave → eccezione che
  le elenca. Date `dd/MM/yyyy` + `HH:mm` parsate a mano (formato fisso: niente
  `intl`, la funzione resta pura). Nomi squadra **trimmati** — nel file c'è
  `MOLINVOLLEY ` con spazio finale, che altrimenti spaccherebbe il
  raggruppamento della classifica. Righe illeggibili contate in
  `righeScartate`, non fatte sparire in silenzio.
- **`logic/classifica.dart`** — `calcolaClassifica(gare)` con il punteggio
  FIPAV: **3-0/3-1 → 3 punti** al vincitore e 0 al perdente, **3-2 → 2 punti**
  al vincitore e **1 al perdente**. Ordinamento: punti → quoziente set →
  quoziente punti → nome. `squadraUnicaDelFiltro(gare)` rileva l'export
  filtrato per società (tutte le gare contengono la stessa squadra) e alimenta
  il banner "Classifica parziale".

### Modello dati (schema **v17**)

- **`Campionati`** (`@DataClassName('Campionato')`): id, nome (dalla colonna
  "Campionato"), `squadraPropria` (nome com'è scritto nel file — serve a
  decidere casa/trasferta), `teamId` (squadra locale abbinata, setNull),
  `dataImport`.
- **`Gare`** (`@DataClassName('GaraCampionato')`): id, campionatoId (cascade),
  garaNumero, giornata, dataOra, squadraCasa/Ospite, risultato, parziali,
  statoDescrizione, impianto, indirizzoImpianto, **`matchId`** (setNull) — la
  partita creata da questa gara.

La classifica **non è una tabella**: si ricalcola dalle gare a ogni build,
coerentemente col principio "stato derivato" già usato per punteggio e
rotazione (vedi Modello dati).

### `CampionatoRepository` (`providers/campionato_provider.dart`)

- **`importa(parsing)`** — il campionato è identificato dal **nome** letto nel
  file. Ri-importando un export più recente dello stesso girone le gare esistenti
  vengono **aggiornate** (risultati/parziali appena giocati) invece di essere
  duplicate, e **`matchId` non viene mai toccato**: il collegamento a una partita
  già creata sopravvive al ri-import. È il caso d'uso normale (si riscarica il
  file ogni settimana). Chiave d'identità: `garaNumero` se presente (numero
  federale, stabile), altrimenti data+squadre.
- **`impostaSquadraPropria(campionatoId, nome, teamId)`** — chiesta con un
  dialog subito dopo il primo import (con preselezione se un nome del file
  combacia case-insensitive con una `Team` locale). Senza, i bottoni "Crea
  partita" restano disabilitati: non si potrebbe decidere `inCasa`.
- **`creaPartitaDaGara(gara, campionato)`** — crea il `VolleyMatch` e scrive
  `matchId` sulla gara, in transazione. Mappatura:

| VolleyMatch | Valore |
|---|---|
| `nome` | `nomePartitaDaGara()`: `Gara N 386 G. 1 MASI VOLLEY PINK B - NETTUNIA` (casa sempre prima; i pezzi mancanti si omettono; troncato a 100 char, il limite della colonna) |
| `dataOra` | `gara.dataOra` |
| `inCasa` | `squadraCasa == campionato.squadraPropria` |
| `avversario` | l'altra squadra (`avversarioDiGara`) |
| `palestra` | `impianto, indirizzoImpianto` |
| `teamId` | `campionato.teamId` |
| `stato`/`setCorrente` | `configurazione` / `1` |

### `CampionatoScreen`

`kOrientamentoTutti` (consultazione, comoda anche in portrait). AppBar con
"Importa" (+`PremiumBadge`), due tab:
- **Calendario**: una card per gara con giornata/data/ora, `casa - ospite` (la
  propria in grassetto), impianto. A destra: risultato+parziali se giocata,
  bottone **"Crea partita"** se futura, spunta verde "Già in Gestione partite"
  se `matchId != null`.
- **Classifica**: `DataTable` (Pos, Squadra, G, V, P, Punti, Set, Q.set,
  Q.punti) con la propria riga evidenziata, dentro uno scroll orizzontale (in
  portrait è più larga dello schermo). Banner giallo se l'export è parziale.

### Premium

**Import premium, classifica libera** (deciso con l'utente): il bottone Importa
è sempre visibile come vetrina e da free apre `PaywallScreen` (stesso pattern di
`MatchesScreen._richiedePremium()`). "Crea partita" ripassa comunque dal gate
free "una sola partita" — in pratica irraggiungibile da free (l'import è già
gated), ma evita di lasciare una scorciatoia aperta.

### Backlog

- Export PDF della classifica.
- **`StatoDescrizione` per le gare future**: oggi la colonna è salvata ma non
  usata da nessuna logica — `giocata` deriva SOLO dal parsing di `Risultato`,
  quindi qualunque cosa la FIPAV ci scriva ("da disputare", vuoto, ...) non
  rompe niente. Da rivedere a inizio stagione, quando si vedrà il calendario
  pubblicato: se per le gare future comparisse un placeholder in `Risultato`
  tipo `0-0`, la gara verrebbe letta come giocata (il calcolo la scarterebbe
  comunque per la guardia `setCasa == setOspite`, ma in calendario perderebbe
  il bottone "Crea partita") — a quel punto conviene usare `StatoDescrizione`
  come discriminante.
- i18n delle stringhe di `CampionatoScreen` (restano in italiano come le altre
  schermate non ancora tradotte; la sola voce Home è già localizzata:
  `homeCampionato`).
- Scaricamento automatico dal sito FIPAV (serve login/sessione): oggi il file lo
  scarica l'utente.
- Nessun incrocio fra classifica importata e partite scoutate in app: la
  classifica è la foto dell'ultimo file importato.

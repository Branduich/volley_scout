# Formato del file di backup

File JSON unico prodotto da Volley Stratego. Serve a due cose insieme:
**copia di sicurezza** (tablet perso = stagione perduta, oggi) e **ponte verso
la dashboard stagionale** sul web. Piano generale in
[dati-stagionali.md](dati-stagionali.md).

Codice: [lib/data/backup_model.dart](../lib/data/backup_model.dart) (DTO + JSON,
puro, nessun import di drift — destinato a `packages/volley_stats`) e
[lib/data/backup_json.dart](../lib/data/backup_json.dart) (conversione da/verso
le righe drift, guardie di lettura). Test:
[test/data/backup_json_test.dart](../test/data/backup_json_test.dart).

## Struttura

```json
{
  "formato": "volley_stratego_backup",
  "formatoVersione": 1,
  "schemaDb": 19,
  "app": "1.0.0+11",
  "esportatoIl": "2026-08-18T17:11:02Z",
  "categorie":  [ { "nome": "Under 18", "ordine": 7 } ],
  "squadre":    [ { "uid": "…", "nome": "Nettunia", "categoria": "Under 18",
                    "coloreDivisa": 4280391771 } ],
  "giocatori":  [ { "uid": "…", "squadraUid": "…", "nome": "Anna",
                    "cognome": "Bianchi", "numero": 4, "ruolo": "schiacciatore",
                    "scadenzaCertificato": "2027-01-31T00:00:00.000" } ],
  "partite":    [ { "uid": "…", "nome": "…", "dataOra": "…", "inCasa": false,
                    "stato": "terminata", "setCorrente": 5,
                    "avversario": "Clai Imola", "squadraUid": "…",
                    "inizioAzioni": "2026-04-30T20:34:12.000",
                    "sets": [ { "numero": 1, "aperto": false,
                                "servizioIniziale": "avversari",
                                "correzionePuntiNostri": 0,
                                "correzionePuntiAvversari": 0,
                                "liberoUid": "…", "ruoloCambiLibero": "centrale",
                                "rotazioni": [ { "squadra": "nostra",
                                                 "posizione": 1,
                                                 "giocatoreUid": "…" } ],
                                "azioni": [ { "o": 1, "r": 1, "t": 12,
                                              "s": "nostra", "ti": "scout",
                                              "e": "nessuno", "g": "…",
                                              "f": "ricezione", "v": "positivo" } ] } ] } ],
  "campionati": [ { "nome": "…", "stagione": "2025/26", "dataImport": "…",
                    "squadraPropria": "NETTUNIA", "squadraUid": "…",
                    "gare": [ { "dataOra": "…", "squadraCasa": "…",
                                "squadraOspite": "…", "risultato": "3-1",
                                "partitaUid": "…" } ] } ]
}
```

`campionati` esiste solo per il ripristino: **la dashboard lo salta**, la
classifica è la foto di un file che l'utente ha già.

## Chiavi delle azioni

Le azioni sono il 95% del file, quindi hanno chiavi corte — `"fondamentale"`
scritto quindicimila volte costa 200 KB di sole chiavi. Altrove le chiavi sono
lunghe: le righe sono poche e leggere il file a occhio vale più dei byte.

| chiave | significato | note |
|---|---|---|
| `o` | ordine nel set | progressivo, è l'identità dell'azione insieme a set e partita |
| `r` | rallyId | raggruppa le azioni di uno scambio |
| `t` | secondi dalla **prima azione** della partita | **non** un orario assoluto; l'ancora è `inizioAzioni` sulla partita, vedi sotto |
| `s` | squadra | `nostra` / `avversari` |
| `ti` | tipo azione | `scout`, `puntoManuale`, `erroreGenerico`, `cambioGiocatore`, `timeout` |
| `e` | esito punto | `nessuno` / `puntoNostro` / `puntoAvversario` |
| `te` | tipo esecuzione | omesso quando è `nonSpecificato` (quasi sempre) |
| `g` | uid del giocatore | assente per punti manuali, errori generici, azioni avversarie |
| `f` | fondamentale | |
| `v` | voto | `perfetto`/`positivo`/`mezzoPunto`/`negativo`/`errore` |
| `x1` `y1` `x2` `y2` | traiettoria | normalizzate 0-1 sul campo doppio 1200×600 |
| `mx` `my` | tocco a muro | solo attacco, se il drag ha incrociato la rete |
| `pc` `po` | punteggio al momento | opzionale, di servizio |
| `gu` `np` `nr` `gc` | cambio giocatore | uscente, nuovo palleggiatore, nuovo ruolo cambi libero, gruppo |
| `ra` | ruolo avversario | `P`/`O`/`S1`/`S2`/`C1`/`C2` per le azioni avversarie |

**Le chiavi assenti valgono `null`**: è la forma compatta, e chi legge le tratta
come tali.

## Scelte non ovvie, con il motivo

**Gli enum si salvano per `.name`, mai per etichetta.** `"perfetto"`, non `"#"`
e non `"Perfect"`. Il simbolo è presentazione — è esattamente ciò che ha
costretto l'export CSV a inventarsi `'=` per non farsi valutare come formula da
Excel — e l'etichetta cambia con la lingua dell'app.

**`uid` invece degli `id`.** Gli `id` drift sono numeri progressivi *di quel
dispositivo*: due backup presi da tablet diversi userebbero gli stessi numeri
per righe diverse. Con gli uid il ripristino è idempotente, due file si possono
unire, e una giocatrice resta la stessa anche se cambia numero di maglia. La
chiave naturale `cognome|nome|numero` non basta: cade su rinomine e omonime.

**Le azioni non hanno `uid`.** Si importano a blocchi e la loro identità è
`(partita, set, ordine)`. L'`id` interno lo assegna chi legge, progressivo:
così le mappe indicizzate su `ScoutAction.id` (`idAttacchiSuRicezione`,
`zonaTatticaPerAzione`) funzionano senza toccare la logica esistente.

**`t` è un delta in secondi, non un timestamp — ancorato alla prima azione.**
Le durate dei set si calcolano per differenza, e il file diventa immune al fuso
orario del dispositivo che lo rilegge. L'ancora è `inizioAzioni` sulla partita
(l'istante della sua prima azione), **non** `dataOra`: quella è la data di
*calendario*, che per una partita creata dall'import FIPAV può distare settimane
dal momento in cui si è scoutato davvero. Con `dataOra` come ancora un file
reale conteneva `t: -2661654` — trenta giorni in negativo: valori esatti, che si
ricostruivano correttamente, ma illeggibili per chiunque aprisse il file. Ora il
primo tocco della partita è sempre `t = 0`, e l'orario assoluto di ogni azione
si riottiene con `inizioAzioni + t` (c'è un test). `inizioAzioni` è assente se
la partita non ha ancora nessuna azione.

**Coordinate a 4 decimali.** Sono normalizzate 0-1 su 1200×600: il quarto
decimale vale meno di un decimo di pixel, mentre un `double` scritto per intero
arriva a 17 cifre. Un test verifica che nel file non finiscano numeri più
precisi.

**JSON compatto, nessuna indentazione, nessuna compressione in v1.** Misura
reale: la partita demo (456 azioni, 5 set) pesa **72 KB**, cioè ~162 byte per
azione — il grosso sono l'uid del giocatore (32 caratteri) e i nomi degli enum.
Una stagione da venti partite sta attorno a **1,4 MB**, che è comodo da mandarsi
su WhatsApp e da tenere in IndexedDB. Se un domani servisse dimezzare, la leva è
sostituire gli uid con un indice nell'elenco giocatori — ma è un cambio
incompatibile, e a questi numeri non si giustifica.

## Versionamento

- **Aggiungere campi è additivo e NON alza `formatoVersione`**: chi legge ignora
  le chiavi che non conosce (c'è un test).
- **Un solo strappo consapevole, prima del rilascio** (2026-08-18): il
  significato di `t` è cambiato — da "scarto da `dataOra`" a "scarto da
  `inizioAzioni`" — **senza** alzare la versione. È un cambio incompatibile, ma
  il formato non era ancora stato rilasciato a nessuno: l'unico file v1 in giro
  era un export di prova. Alzare a v2 avrebbe lasciato per sempre un ramo di
  compatibilità per zero file reali. Un backup esportato prima di questa data va
  rifatto (i `t` verrebbero letti con l'ancora sbagliata: tutto il resto è
  corretto). Da qui in avanti vale la regola sopra, senza eccezioni.
- `formatoVersione` sale **solo** per cambi incompatibili.
- Un file con `formatoVersione` più recente di quella supportata viene
  **rifiutato con un messaggio esplicito**, mai letto a metà: leggerlo
  parzialmente produrrebbe dati silenziosamente sbagliati.
- Un valore di enum sconosciuto non fa cadere l'import (torna `null`, o
  `Ruolo.undefined` per il ruolo): è il caso di un file scritto da una versione
  che ha aggiunto una voce.

## Guardie in lettura

Il file lo pesca l'utente a mano da Download, quindi può facilmente essere
quello sbagliato. Ogni rifiuto dice *cosa* è stato aperto:

| caso | messaggio |
|---|---|
| primi byte `1f 8b` | "Il file è compresso (gzip): decomprimilo e riprova." |
| primi byte `50 4b` | "Questo è un archivio zip (o un file Excel), non un backup." |
| file vuoto | "Il file è vuoto." |
| non è testo UTF-8 | "Il file non è un testo leggibile…" |
| JSON non valido | "Il file non è un JSON valido: …" |
| manca `formato` | "Questo file non è un backup di Volley Stratego." |
| versione futura | "…creato con una versione più recente dell'app…" |

Un eventuale BOM UTF-8 in testa viene scartato prima di `jsonDecode`.

## Cosa dimostra il test

Non basta contare le azioni dopo il giro: il test rigioca le azioni **ri-parsate
dal JSON** con `ricalcolaStato()` e pretende i punteggi reali del referto della
partita demo (25-16, 15-25, 21-25, 25-16, 25-23). Se si perdesse per strada un
campo che governa il punteggio, il replay divergerebbe. Verifica inoltre che
tutti i riferimenti fra righe restino validi via uid, che i cinque voti
compaiano tutti, che battute e attacchi conservino la traiettoria, e ogni
guardia della tabella qui sopra.

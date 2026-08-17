# Importare un calendario da un foglio di calcolo personalizzato

Volley Stratego importa il calendario di un'intera stagione da un foglio di
calcolo: ogni gara diventa una riga che con un tocco si trasforma in una partita
già compilata — data, avversario, casa/trasferta e palestra. Le gare già giocate
alimentano anche la tab **Classifica**.

Se giochi in un campionato FIPAV non ti serve questa pagina: scarica il file
`Gare.xls` dal sito federale e importalo così com'è. Questa pagina serve a chi
il file se lo deve costruire — perché la propria federazione non lo esporta,
oppure lo esporta in un formato diverso. Il file si può preparare con Excel,
Google Fogli, LibreOffice o Numbers.

---

## 1. Il file

- **Formato**: `.xlsx` (Excel 2007 e successivi, Google Fogli, LibreOffice) o
  `.xls` (Excel 97-2003). Vanno bene entrambi.
- L'app riconosce il formato dal **contenuto**, non dal nome: un file rinominato
  a mano funziona lo stesso. Una pagina web salvata con estensione `.xls` — come
  fanno alcuni siti federali — viene rifiutata con un messaggio chiaro: aprila e
  risalvala come foglio di calcolo vero.
- **Si legge solo il primo foglio.** Il nome del foglio è indifferente, ed è
  ignorato tutto ciò che sta su un secondo foglio.
- **L'intestazione deve stare nella prima riga.** Niente titoli, loghi o righe
  vuote sopra: l'app legge la riga 1 come nomi delle colonne.
- I dati partono dalla riga 2, una gara per riga.
- Le righe vuote in coda sono ignorate (Google Fogli ne aggiunge a centinaia:
  nessun problema).

## 2. Le colonne

Copia questa intestazione nella riga 1:

```
Campionato | Gara N | Giornata | Data | Ora | SquadraCasa | SquadraOspite | Risultato | Parziali | StatoDescrizione | Impianto | IndirizzoImpianto
```

I nomi delle colonne sono **parole chiave**: è così che l'app riconosce ogni
colonna. Per il resto c'è massima libertà:

- **L'ordine non conta.** Le colonne si abbinano per nome, non per posizione.
- **Maiuscole e spaziatura non contano**: `SquadraCasa`, `squadra casa`,
  `SQUADRA_CASA` e `Squadra-Casa` sono equivalenti.
- **Le colonne in più sono ignorate**, quindi puoi tenere nel file i tuoi
  appunti.

| Colonna | Obbligatoria | Contenuto |
|---|---|---|
| `Campionato` | **sì** | Nome del campionato/girone, es. `UNDER 18 FEMMINILE GIRONE B`. Va scritto **uguale su tutte le righe**: diventa il nome del campionato nell'app. |
| `Data` | **sì** | Data della gara. Leggi [Date e orari](#3-date-e-orari): è la cosa che va storta più spesso. |
| `SquadraCasa` | **sì** | Squadra di casa. |
| `SquadraOspite` | **sì** | Squadra ospite. |
| `Gara N` | no, ma consigliata | Numero della gara, intero, unico nel file. Vedi [Ri-importare](#5-ri-importare-lo-stesso-campionato). |
| `Giornata` | no | Numero di giornata, intero. |
| `Ora` | no | Orario d'inizio. Se manca vale mezzanotte. |
| `Risultato` | no | Risultato finale **in set**, es. `3-1`. Lascialo vuoto per una gara non ancora giocata. |
| `Parziali` | no | Punteggi dei set, es. `25-17 20-25 25-14 25-6`. |
| `Impianto` | no | Nome della palestra, es. `Sc.Galilei`. |
| `IndirizzoImpianto` | no | Indirizzo della palestra, es. `Via Porrettana 97`. |
| `StatoDescrizione` | no | Stato della gara secondo la federazione, testo libero. Viene salvato, ma non entra in nessun calcolo. |

Se manca una delle quattro colonne obbligatorie l'import si ferma con un
messaggio che elenca quelle non trovate e mostra le colonne effettivamente
lette — comodo per scovare un errore di battitura.

Una riga senza squadra di casa, senza squadra ospite o con una data illeggibile
viene saltata e contata nel riepilogo dell'import ("N righe ignorate"): nessun
dato sparisce in silenzio.

## 3. Date e orari

**La strada più sicura: formatta la colonna `Data` come data vera** nel foglio
di calcolo (Formato → Numero → Data), e la colonna `Ora` come ora. L'app legge
il valore sottostante, quindi l'ordine giorno/mese non può essere frainteso.

Se preferisci il testo:

- **La data va scritta `gg/mm/aaaa`**, giorno per primo: `12/10/2027` significa
  **12 ottobre** 2027. Le cifre singole vanno bene (`5/2/2027`).
  > ⚠️ Il formato americano `mm/gg/aaaa` e l'ISO `aaaa-mm-gg` scritti come testo
  > **non** sono riconosciuti. Se le tue date sono in uno di quei formati,
  > converti la colonna in data vera: l'ambiguità sparisce del tutto.
- **L'orario va scritto su 24 ore**, `21:00` e non `9:00 PM`. Un `PM` finale
  viene ignorato invece che applicato, quindi `9:00 PM` finirebbe salvato come
  09:00.

## 4. Risultati e classifica

- Una gara conta come **giocata** appena `Risultato` contiene qualcosa tipo
  `3-1`. Qualunque altra cosa — vuoto, `-`, `da disputare` — conta come **non
  ancora giocata**, ed è ciò che fa comparire per quella gara il bottone **Crea
  partita** nella tab Calendario.
- `Parziali` serve solo al quoziente punti come criterio di parità. Puoi
  lasciarlo vuoto: punti e set restano corretti, si perde solo quel criterio.
- I nomi delle squadre si confrontano **esattamente** (a parte gli spazi iniziali
  e finali, che vengono tolti). Scrivi ogni squadra sempre allo stesso modo:
  `Volley Tower` e `VOLLEY TOWER` risulterebbero due squadre diverse in
  classifica.

> **La classifica usa il punteggio FIPAV/FIVB**, per ora fisso: **3 punti** per
> una vittoria 3-0 o 3-1, **2 punti** per una vittoria 3-2 e **1 punto** a chi
> perde 2-3, 0 per ogni altra sconfitta. Ordinamento: punti, gare vinte,
> quoziente set, quoziente punti, nome. Se la tua federazione usa un sistema
> diverso il calendario funziona lo stesso: solo i numeri della classifica non
> combaceranno con quelli ufficiali.

Se tutte le gare del file coinvolgono la stessa squadra — è ciò che si ottiene
quando un sito federale esporta "solo le gare della mia società" — l'app se ne
accorge e mostra l'avviso di **classifica parziale**, perché mancano gli scontri
diretti fra le altre squadre. Per una classifica completa serve il girone
intero.

L'etichetta di **stagione** (`2027/28`) si deduce dalla data più vecchia del
file: da luglio in poi si è nella stagione che comincia in quell'anno.

## 5. Ri-importare lo stesso campionato

Reimporta lo stesso file ogni volta che escono i risultati: le gare già presenti
vengono aggiornate al loro posto invece di essere duplicate, e una gara da cui
hai già creato una partita mantiene il collegamento.

Come si riconosce che è "la stessa gara":

- se c'è `Gara N`, da quel numero — **è il motivo per cui la colonna è
  consigliata**: la gara resta riconoscibile anche dopo un rinvio che ne cambia
  la data;
- altrimenti da data + squadra di casa + squadra ospite, quindi una gara
  rinviata rientra come gara nuova e la vecchia riga resta a calendario.

L'import non cancella mai delle gare. Se il file è cambiato molto, elimina il
campionato dal menu ⋮ e reimportalo: le partite già create restano in
**Gestione partite**.

Se esiste già un campionato con lo stesso nome, l'app chiede se aggiornarlo o
crearne uno nuovo: è così che due stagioni dello stesso girone possono
convivere.

## 6. Esempio minimo

Solo le quattro colonne obbligatorie, date come testo:

| Campionato | Data | SquadraCasa | SquadraOspite |
|---|---|---|---|
| UNDER 18 FEMMINILE GIRONE B | 12/10/2027 | PINK D | NETTUNO |
| UNDER 18 FEMMINILE GIRONE B | 17/10/2027 | NETTUNO | PS SPORT |

Una riga completa, come piace di più all'app:

| Campionato | Gara N | Giornata | Data | Ora | SquadraCasa | SquadraOspite | Risultato | Parziali | Impianto | IndirizzoImpianto |
|---|---|---|---|---|---|---|---|---|---|---|
| UNDER 18 FEMMINILE GIRONE B | 386 | 1 | 12/10/2027 | 11:00 | PINK D | NETTUNO | 3-0 | 26-24 25-15 25-12 | Sc.Galilei | Via Porrettana 97 |

## 7. Dopo l'import

L'app chiede **qual è la tua squadra**, scegliendola fra i nomi trovati nel
file. Da quella risposta dipendono casa/trasferta di ogni gara e quale delle due
è l'avversaria, quindi finché non la dai i bottoni **Crea partita** restano
disabilitati.

Ogni partita creata riceve: nome (`Gara N 386 G. 1 PINK D - NETTUNO`), data e
ora, casa/trasferta, avversario e palestra come `Impianto, IndirizzoImpianto` —
che dal form della partita si apre nell'app di mappe del telefono.

> L'import del calendario è una funzione **premium**. La consultazione della
> classifica no.

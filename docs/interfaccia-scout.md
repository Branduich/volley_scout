# L'interfaccia dello scout dal vivo

Come si registra una partita con Volley Stratego. Documento rivolto a **chi usa
l'app**: nessun dettaglio di codice, solo cosa si vede e cosa si tocca. Per il
funzionamento interno vedi `docs/context/scout-live.md`.

> Il documento descrive l'app **con le traiettorie sul campo attive**
> (Impostazioni → *Traiettorie sul campo*). Dove il comportamento cambia con
> quell'interruttore spento, è scritto.

---

## L'idea di fondo

Durante uno scambio non c'è tempo di leggere l'interfaccia. Perciò tutto è
costruito attorno a tre principi:

1. **I bottoni non si spostano.** Le stesse azioni stanno sempre nello stesso
   punto dello schermo, così il dito impara la strada e gli occhi restano sul
   campo.
2. **Niente si scrive finché la scelta non è completa.** Puoi cambiare idea
   quante volte vuoi: fino all'ultimo tocco non è stato registrato nulla.
3. **Ogni errore si annulla con un tocco.** L'undo è sempre lì, in alto a
   destra.

---

## Lo schermo

```
┌──────────────────────────────────────────────────────────────┐
│ ☰   ●●   − 12 +        Nettunia – Masi Volley      − 9 +  ●●  ↺ ↶ │
├──────────────────────────────────────────────────────────────┤
│ ✕ ✓   ⏱                                        ⏱      ✓ ✕     │
│                    7 – Rossi – Battuta  #                     │
│  ┌────┐   ┌─────────────────────────────────┐    ┌─────────┐  │
│  │mini│   │                                 │    │pulsan-  │  │
│  └────┘   │      campo (noi | loro)         │    │ tiera   │  │
│           │                                 │    └─────────┘  │
│           └─────────────────────────────────┘                 │
└──────────────────────────────────────────────────────────────┘
```

**In alto**: il menu, i due punteggi con i tasti `−`/`+` per correggerli a mano,
il nome della partita, i pallini dei timeout (grigi da chiamare, gialli usati) e
i due tasti di annullamento.

**Sotto**: da un lato *errore* e *punto* della tua squadra, dall'altro gli stessi
per gli avversari, e i due tasti timeout verso il centro. Tutto segue il **cambio
campo**: se inverti i lati, si invertono anche loro.

**Al centro**: il campo intero, la tua squadra da una parte e gli avversari
dall'altra. La mini-mappa in alto mostra la rotazione.

---

## Registrare un'azione

### Il caso normale: due tocchi

**Tocca la giocatrice, poi tocca la valutazione.** Si apre una pulsantiera a due
colonne: i fondamentali a sinistra, i voti a destra.

```
        7
      Rossi
  ┌────────┬────────┐
  │ Difesa │   #    │   #  perfetto
  │ Attacco│   +    │   +  positivo
  │ Muro   │   /    │   /  mezzo punto
  │ Alzata │   −    │   −  negativo
  │        │   =    │   =  errore
  └────────┴────────┘
```

Si tocca **una voce per colonna, in qualsiasi ordine**: prima il fondamentale e
poi il voto, o il contrario — l'azione parte da sé quando ci sono entrambi.
Finché manca una metà non è stato scritto niente, quindi se sbagli colonna basta
ri-toccare quella giusta: **non serve annullare**.

Il bordo bianco indica cosa hai scelto; le voci non scelte della stessa colonna
si attenuano solo dopo la prima scelta.

### Quando il fondamentale è già deciso

In **battuta** e in **ricezione** non c'è niente da scegliere: lo impone la fase
di gioco. La colonna di sinistra resta spenta e il fondamentale compare come
etichetta sotto il nome. Basta il voto: **un tocco**.

### Cambiare giocatrice al volo

Con la pulsantiera aperta, **tocca un'altra giocatrice**: la selezione passa a
lei e la scelta riparte da zero. Vale anche fra squadre diverse — se hai aperto
per un'avversaria puoi passare direttamente a una delle tue.

Per **annullare** senza registrare: tocca il campo, o un punto qualsiasi fuori
dalla pulsantiera.

---

## Le traiettorie

Battuta e attacco possono portare con sé il percorso della palla, che finisce
nei report e nelle mappe di calore.

### Si disegnano sul campo, prima del voto

**Trascina il dito sul campo**, dal punto di partenza a dove cade la palla. La
freccia resta disegnata finché non registri.

Tre scorciatoie che fanno risparmiare tocchi:

- **Trascinare da una giocatrice la seleziona.** Non serve toccarla prima: parti
  direttamente dal suo token e la pulsantiera si apre da sola.
- **In battuta puoi partire da tutta la linea di fondo**, non solo da dove è
  disegnato il battitore — perché il servizio si batte da qualsiasi punto. Il
  punto da cui parti viene registrato: se batti dall'angolo, il report lo sa.
- **In gioco aperto, disegnare significa "attacco".** Al rilascio il
  fondamentale si accende da sé su *Attacco*: resta solo il voto. Se avevi già
  scelto un altro fondamentale, il disegno ha la precedenza — se hai tracciato
  una traiettoria, quell'azione è un attacco.

> **Il voto chiude l'azione.** Se voti prima di aver disegnato, la traiettoria
> non viene registrata. L'ordine è: giocatrice → trascinamento → voto.

### Il tocco a muro

Su un attacco deviato dal muro: mentre trascini, **fermati un attimo sulla
rete**. Una riga gialla si accende a dirti che ci sei; lo snodo si fissa lì e la
freccia prosegue fino a dove cade davvero la palla.

### Con le traiettorie sul campo disattivate

Dopo il voto si apre una schermata dedicata col campo vuoto, dove si traccia la
traiettoria con un trascinamento. Lì ci sono anche i **tipi di battuta e di
attacco** (float, salto, pallonetto…), che sul campo dal vivo non sono ancora
indicabili. Il tasto indietro salta la traiettoria senza perdere l'azione.

---

## I tasti rapidi

Quando non serve il dettaglio, o l'azione non ha una protagonista:

| Tasto | Cosa registra |
|---|---|
| ✓ verde | punto alla squadra, senza giocatrice |
| ✕ rosso | errore della squadra, punto all'altra |
| ⏱ | timeout (due per set, i pallini in alto li contano) |

Su **errore avversario** una pressione prolungata apre i motivi: generico,
battuta, fallo di posizione, invasione.

---

## Annullare

| Tasto | Effetto |
|---|---|
| ↶ | annulla **l'ultima azione**, con conferma |
| ↺ | annulla **tutto lo scambio**, quando l'arbitro fa rigiocare |

Punteggio, rotazione e turno di servizio non sono memorizzati: si ricalcolano
dalle azioni. Per questo annullare rimette tutto a posto da solo, e riprendere
una partita interrotta la ritrova esattamente dov'era.

I cambi giocatrice **non** vengono annullati dal tasto dello scambio: avvengono a
palla ferma e non fanno parte dell'azione.

---

## Il menu

| Voce | A cosa serve |
|---|---|
| **Cambia campo** | inverte i lati a fine set; tutta l'interfaccia lo segue |
| **Sostituzione** | cambio giocatrice a set in corso |
| **Lavagna tattica** | schermo libero per disegnare uno schema |
| **Statistiche** | i numeri per giocatrice, anche a partita in corso |
| **Traiettorie battute / attacco** | le mappe, filtrabili per set e giocatrice |
| **Mostra numeri / ruoli** | cosa scrivere dentro i token |
| **Registro azioni** | la lista di quello che hai registrato, a lato del campo |
| **Fine** | chiude il set o la partita |

---

## Scoutare anche gli avversari

Se attivo (Impostazioni → *Scout avversari*), a inizio set ti viene chiesto di
indicare **dove si trova il palleggiatore avversario**: da lì l'app deduce tutta
la loro rotazione e la fa girare da sola.

Gli avversari compaiono come segnaposto grigi con il ruolo (P, O, S1, S2, C1,
C2) — niente numeri di maglia, nessuna rosa da inserire. Si toccano e si votano
esattamente come le tue giocatrici.

### La regola del punto

Ogni scambio si chiude una volta sola, e **lo chiude sempre chi difende**:

- una battuta vincente è un **ace** = battuta `#` tua **+** ricezione `=` loro;
- una schiacciata a terra è un **kill** = attacco `#` loro **+** difesa `=` tua.

Sembra un passaggio in più, ma è quello che rende confrontabili le due squadre.
E l'app lo rende quasi gratuito:

- dopo un **ace**, tocca il ricevitore: registra la ricezione sbagliata da solo;
- dopo un **kill**, tocca il difensore: restano accesi solo *Muro* e *Difesa* in
  rosso, e un tocco chiude il punto.

Finché il punto non è chiuso, in alto compare un promemoria —
**CONCLUDI RICEZIONE** o **CONCLUDI DIFESA** — e la squadra che ha già colpito
resta attenuata e non si tocca.

---

## Le impostazioni che cambiano il gioco

| Impostazione | Effetto |
|---|---|
| **Traiettorie durante lo scout** | senza, il voto registra subito e i report delle traiettorie restano vuoti |
| **Traiettorie sul campo** *(in prova)* | si disegna sul campo prima del voto, invece che nella schermata dedicata dopo |
| **Scout avversari** | segnaposto avversari e regola del punto qui sopra |

---

## In breve

| Vuoi | Fai |
|---|---|
| valutare un'azione | tocca la giocatrice, poi il fondamentale e il voto |
| valutare battuta o ricezione | tocca la giocatrice, poi il voto |
| registrare un attacco col percorso | trascina dall'attaccante a terra, poi il voto |
| registrare una battuta col percorso | trascina dalla linea di fondo, poi il voto |
| cambiare giocatrice | toccane un'altra, anche dell'altra squadra |
| chiudere senza registrare | tocca il campo |
| correggere | ↶ per l'ultima azione, ↺ per tutto lo scambio |

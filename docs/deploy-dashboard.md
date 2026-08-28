# Pubblicare la dashboard (passo 10)

Come mettere online `packages/volley_web` e collegarla al sito su Google Sites.
Scelte già prese, con il perché, in `docs/dati-stagionali.md` → "La vetrina".

**In breve**: Google Sites resta la faccia pubblica (è testo indicizzabile e
ospita già privacy e termini); la dashboard vive su **Cloudflare** (un Worker con
file statici), che dà un indirizzo con HTTPS gratis; dal Sites ci si arriva con un **link**, non con
un embed.

---

## 1. Costruire il pacchetto

Da `packages/volley_web`:

```
flutter build web --release
```

Esce in `build/web`. È **tutto lì dentro**: nient'altro va caricato.

Prima di pubblicare, i due controlli che costano dieci secondi e salvano un
pomeriggio:

```
grep -o '<base href="[^"]*">' build/web/index.html     # deve dire "/"
ls build/web/_headers build/web/robots.txt             # devono esserci
```

Un `--base-href` sbagliato dà una **pagina bianca senza errori**: il browser
scarica `index.html` e poi cerca il motore in un percorso che non esiste. Serve
`/` perché il sito sta nella radice del dominio; servirebbe `/nome-repo/` solo
su GitHub Pages, che abbiamo scartato.

## 2. Creare il progetto su Cloudflare

Una volta sola.

1. Account gratuito su `dash.cloudflare.com` (nessuna carta di credito).
2. Nella home, riquadro **"Ship something new"**: trascina la cartella
   `build/web` sul rettangolo tratteggiato *"Drop a folder, or a zip"*.
3. **Nome: `volley-stratego`.** Non è un dettaglio estetico: il nome decide
   l'indirizzo, e quell'indirizzo è scritto nei tag Open Graph di
   `web/index.html` — quelli che fanno l'anteprima quando il link finisce in
   WhatsApp. Cambiandolo, vanno cambiate anche `og:url` e `og:image`.
4. **Deploy**. Se chiede un "build command" o un framework, lascia vuoto: qui
   non c'è niente da costruire, i file sono già pronti.

**Cloudflare crea un Worker, non un progetto Pages** (le due cose sono state
unificate): l'indirizzo finisce in `.workers.dev` invece che in `.pages.dev`.
Cambia solo il nome — è lo stesso hosting statico con HTTPS gratuito, e
**`_headers` viene rispettato lo stesso** (verificato sul sito vero il
2026-08-28: `main.dart.js` risponde `no-cache` e `canvaskit/*`
`max-age=86400`).

Indirizzo attuale: **https://volley-stratego.branduich.workers.dev**

**Perché il caricamento diretto e non il collegamento a GitHub**: Cloudflare
costruirebbe da sé a ogni push, ma i suoi runner non hanno Flutter installato —
servirebbe uno script che se lo scarica ogni volta. Per un sito che si aggiorna
quando lo decidi tu, trascinare la cartella è più semplice e non ha niente da
rompersi. Si può cambiare idea dopo senza rifare nulla.

## 3. Verifiche dopo la prima pubblicazione

Da fare **sull'indirizzo vero**, non in locale: alcune cose (HTTPS, service
worker, installazione) in locale non si vedono.

- [ ] La pagina si apre e mostra la dashboard con i dati di esempio.
- [ ] **Carica un backup vero**, poi **F5**: i dati devono essere ancora lì
      (IndexedDB). Se spariscono, il browser sta bloccando lo storage.
- [ ] Chrome offre **"Installa"** (icona nella barra indirizzi). Installata, si
      apre in finestra propria, senza barra indirizzi, con l'icona giusta.
- [ ] Ripubblica una modifica visibile e ricarica: devi vedere **la versione
      nuova** senza svuotare la cache a mano. È ciò che verifica `_headers`.
- [ ] Incolla il link in una chat: l'anteprima deve mostrare titolo, descrizione
      e logo. Se mostra l'indirizzo nudo, `og:url`/`og:image` non combaciano con
      l'indirizzo vero (vedi punto 2.3).

## 4. Collegare il Google Sites

**Non si incorpora niente**: si aggiunge un pulsante che apre la dashboard.

I clic, sul sito che già ospita privacy e termini:

1. `sites.google.com` → apri il sito → si apre in modifica.
2. Scegli dove metterlo: la pagina iniziale va benissimo. Se preferisci una
   pagina dedicata, `Pagine` → `+` → chiamala **Statistiche**.
3. Pannello a destra → **Inserisci** → **Pulsante**.
4. Nome: **Apri la dashboard**. Link:
   `https://volley-stratego.branduich.workers.dev`
5. Sotto al pulsante, `Inserisci` → **Casella di testo** e incolla il testo qui
   sotto. Se hai schermate, `Inserisci` → **Immagine**: mettile con una
   didascalia, perché anche quella è testo che Google legge.
6. In alto a destra, **Pubblica**.

I link esterni su Google Sites si aprono già in una scheda nuova, quindi non
c'è nessuna opzione da cercare.

### Il testo da incollare

Senza formattazione: Google Sites NON interpreta il markdown, e gli asterischi
si vedrebbero tali e quali sulla pagina pubblicata. Titoletti e grassetti si
mettono dopo, con la barra degli strumenti del Sites.

Non è riempitivo: **è l'unica cosa indicizzabile di tutto il giro**. La
dashboard disegna su canvas, quindi per un motore di ricerca quella pagina è
vuota; le parole qui sotto sono scelte perché sono quelle che un allenatore
scrive davvero nella barra di ricerca.

---

Statistiche di stagione per la tua squadra di pallavolo

Volley Scout Stratego registra le azioni di una partita — battuta, ricezione,
attacco, muro, difesa — e ne ricava le statistiche. La dashboard qui sopra
prende tutte le partite di una stagione e risponde alla domanda che il referto
di una singola gara non può: *questa giocatrice sta migliorando?*

Vedi l'efficienza in attacco e la positività in ricezione di ogni giocatrice,
come cambiano nel tempo, e puoi filtrare per periodo, per set o per partite in
casa e in trasferta.

Come si usa

1. Nell'app, apri Impostazioni → Esporta backup e salva il file.
2. Apri la dashboard e trascina il file nella pagina.
3. I numeri diventano i tuoi. Tornando dallo stesso computer li ritrovi già
   caricati.

I tuoi dati restano tuoi. Il file non viene caricato da nessuna parte: la
dashboard lavora dentro al browser, e quello che vedi resta sul tuo computer.
Non serve registrarsi.

Senza l'app, la pagina mostra una stagione di esempio con nomi inventati: si può
guardare tutto senza avere niente da caricare.

---

## 5. Quando arriverà un dominio

Due record DNS su Cloudflare, la dashboard risponde su `dashboard.…`, e sul
Sites si cambia l'indirizzo del pulsante. Nel repo si aggiornano `og:url` e
`og:image`. Niente da riscrivere.

---

## Aggiornare il sito, dopo

```
cd packages/volley_web
flutter build web --release
```

poi **Workers & Pages → volley-stratego → Create deployment** e trascina di
nuovo `build/web`. Cloudflare tiene lo storico e permette di tornare a una
versione precedente con un clic.

Ricorda che i dati degli utenti stanno **nel loro browser**: pubblicare una
versione nuova non tocca niente di ciò che hanno caricato.

## Icone del sito

Si rigenerano dallo stesso logo dell'app:

```
cd packages/volley_web
dart run flutter_launcher_icons      # 192, 512 e favicon
dart run tool/icona_maskable.dart    # le maskable, con la zona sicura
```

Il secondo comando serve perché `flutter_launcher_icons`, per il web, scrive la
maskable identica all'icona normale — e installata verrebbe ritagliata sui
fianchi. Vedi il commento in cima allo script.

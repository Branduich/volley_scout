# TODO — Monetizzazione Strada A (nessun account, abbonamento via store)

> Roadmap operativa per la Strada A: dati 100% locali, NESSUN login, abbonamento
> gestito interamente da Google Play tramite RevenueCat. Il trial e il premium
> sono legati all'account Google del dispositivo, non a un account dell'app.
>
> Prerequisito: core dell'app funzionante (scout, statistiche, export).
> NB: quadro pratico, non consulenza legale.

> **STATO: PERCORSO CONCLUSO.** App pubblicata in **produzione** su Google Play
> il **2026-08-18** con la release `1.0.0+11`. Restano aperte solo le sezioni 6
> (regali) e 9 (misurazione della condivisione), che sono post-lancio per
> definizione. Il file resta come storico delle decisioni.

---

## 0. Decisioni preliminari (carta e penna, zero codice)

- [x] **Linea free/premium** — definire cosa resta gratis dopo il trial. Bozza:
      - FREE: scout completo, 1-2 squadre, statistiche di base.
      - PREMIUM: squadre illimitate, statistiche avanzate (per fase/rotazione,
        heatmap traiettorie), export PDF/CSV, doppio libero.
      - DECISO (2026-07-12): gate su export PDF/CSV, traiettorie (live
        silenzioso + menu/report con paywall) e UNA sola squadra / UNA sola
        partita (gate solo sulla CREAZIONE: dati esistenti sempre visibili,
        modificabili e cancellabili — si deve poter scendere a una squadra
        cancellando le altre). Il resto della linea si definisce dopo.
- [x] **Prezzo** — abbonamento annuale (riferimento competitor: ~30 EUR/anno).
      Ricordare commissioni store (15% sotto 1M USD/anno con il programma
      "small business", attivato, altrimenti 30%). Nota: il prezzo su Play è
      comprensivo di IVA — netto ≈ `prezzo × 0,697` per un acquirente italiano.
- [x] **Trial** — durata 15 giorni, gestito dallo store (Modo 1):
      configurato DENTRO il prodotto abbonamento. L'utente inserisce il metodo
      di pagamento all'inizio ma non viene addebitato durante la prova.
      Nota: niente trial "automatico all'installazione senza carta" — sarebbe
      il Modo 2, aggirabile senza account.

## 1. Account Google Play Developer

- [X] Registrazione Google Play Developer: 25 USD una tantum.
- [X] Completare la verifica identità (può richiedere qualche giorno).
- [x] Nota: per i nuovi account personali Google richiede un periodo di closed
      testing con un numero minimo di tester prima di poter pubblicare in
      produzione — quindi la sezione 5 (closed testing) non è opzionale,
      è parte del percorso obbligato. **Requisito soddisfatto**: accesso alla
      produzione ottenuto e app pubblicata.

## 2. Codice — freemium gate

- [x] Creare UN punto centrale di verità: provider Riverpod
      `statoPremiumProvider` (stato: `free / trial / premium`) —
      `lib/providers/premium_provider.dart`, per ora STUB (default premium,
      toggle debug "Simula utente free" in Impostazioni).
- [x] Piazzare i gate nel codice: ogni funzione premium controlla il provider
      prima di attivarsi (mai logica sparsa nelle schermate). Primo giro:
      export PDF e CSV in `MatchesScreen`.
- [x] Comportamento offline: in palestra senza rete lo scout e il premium
      funzionano — RevenueCat serve il `CustomerInfo` dalla propria cache e
      `_caricaIniziale()`/`_sincronizza()` falliscono in silenzio (try/catch),
      lasciando lo stato invariato invece di degradare a `free`.
- [x] Schermata **paywall** REALE (`lib/screens/premium/paywall_screen.dart`):
      vantaggi premium, un bottone per pacchetto col prezzo dello store,
      acquisto via `Purchases.purchase` e "Ripristina acquisti" (obbligatorio).
- [x] Schermata **About/Info** (pubblica, raggiungibile dalle impostazioni).
      Doppio scopo: requisito Google Play (il link alla privacy
      policy deve essere accessibile ANCHE dentro l'app, non solo nella scheda
      store) + supporto/regali. Contenuto:
      - nome app + versione (via `package_info_plus`);
      - link Privacy Policy e Terms of Use (via `url_launcher`) — FATTI,
        documenti Termly ospitati su Google Sites (vedi sezione 7);
      - email/contatto di supporto — FATTA: `volleystratego@gmail.com`;
      - link "Gestisci abbonamento" — deep link alle sottoscrizioni Play Store
        (`https://play.google.com/store/account/subscriptions`);
      - **app user ID di RevenueCat** (`await Purchases.appUserID`), sempre
        visibile con etichetta "ID supporto" e bottone Copia
        (`Clipboard.setData`) — serve per il supporto clienti e per i granted
        entitlements agli amici (sezione 6). FATTO.

## 3. Prodotto abbonamento su Play Console

- [x] Creare l'abbonamento in Play Console — Prodotti — Abbonamenti:
      prodotto `premium_annual`, base plan annuale auto-rinnovabile + offerta
      "new customer acquisition" con free trial di 15 giorni, entrambi ATTIVI.
- [x] Attendere la propagazione (fino a 24h prima che l'offerta sia visibile
      su dispositivo/emulatore). **Lezione**: più di un "non funziona" si è
      risolto da solo aspettando — prima di debuggare, aspettare e svuotare la
      cache del Play Store.

## 4. Integrazione RevenueCat

- [x] Creare progetto su RevenueCat, entitlement `premium` + offering
      `default`. Service account Google FATTO e valido. **Lezione**: se
      RevenueCat dice "Credentials need attention", il problema sono le
      **Autorizzazioni app vuote** per il service account su Play Console, non
      la chiave o il JSON.
- [x] Aggiungere il SDK Flutter: `purchases_flutter` (^8.0.0 → 8.11.0 →
      ^10.0.0, risolto a 10.9.0).
- [x] Configurare in RevenueCat: Entitlement `premium` + Offering `default`
      (l'app Google Play su RevenueCat va creata col package
      `it.branduich.volleystratego` per far comparire la SDK key `goog_...`).
- [x] Collegare lo stato RevenueCat a `statoPremiumProvider` (listener SDK;
      trial/premium = attivo; scaduto/assente = free).
- [x] Implementare "Ripristina acquisti" (PaywallScreen).
- [x] Gestire gli stati scadenza / rinnovo / rimborso: il listener aggiorna lo
      stato da sé, più un `AppLifecycleListener` che al `resume` risincronizza
      (serve agli acquisti fatti FUORI dall'app: codici promozionali riscattati
      dal Play Store, abbonamenti comprati su un altro dispositivo). Nessuna UI
      dedicata: decisione presa, il gate che si apre/chiude basta.
- [x] Test degli acquisti con **license testers**: catena verificata end-to-end
      sul device (2026-07-16) — Play → RevenueCat → entitlement `premium` →
      sblocco dei gate. **Lezione**: `ITEM_UNAVAILABLE` al tap su "Abbonati"
      significa che manca il license tester (Play Console → Impostazioni →
      Monetizzazione → Test licenza, RESPOND_NORMALLY).

## 5. Closed testing su Play Console (feedback amici + requisito Google)

- [x] Creare una release nella traccia **Closed testing** (build firmata,
      app bundle .aab).
- [x] Creare una lista tester via email (gli amici) e invitarli con il link
      di opt-in.
- [x] Aggiungere gli stessi amici come **license testers**
      (Play Console — Impostazioni — License testing): così provano l'intero
      flusso di abbonamento/trial senza addebiti reali.
- [x] Raccogliere feedback: il feedback dei tester chiusi resta privato,
      NON finisce nelle recensioni pubbliche.
- [x] Iterare sulle build finché il flusso scout — statistiche — export —
      paywall è solido.
- [x] Rispettare il periodo/numero minimo di tester richiesto da Google per
      gli account personali prima di richiedere l'accesso alla produzione.

## 6. Regali post-lancio (amici, promozioni)

- [ ] **Granted entitlements (RevenueCat)** — via dashboard, concedi il
      premium a un app user ID specifico per la durata che vuoi. Nessun codice,
      nessuna configurazione store, revocabile. La via consigliata per regalare
      il premium a singoli amici. (L'ID si recupera dalla schermata
      About della sezione 2, campo "ID supporto".)
- [ ] **Promo code Google Play** — da Play Console → Promotions. È la via per
      far provare la **produzione vera, col percorso d'acquisto reale, senza
      far pagare** (i license tester non servono: il sandbox si attiva solo se
      l'account è iscritto a una traccia di test, quindi su un'installazione di
      produzione pagherebbe davvero). Cosa sapere (verificato 2026-08-18):
      - per gli abbonamenti danno un **free trial da 3 a 90 giorni**, non
        l'abbonamento gratis; se il piano ha già un trial, quello del codice
        lo sostituisce;
      - **serve un metodo di pagamento** valido e alla fine **si rinnova a
        prezzo pieno** → far **disdire subito dopo il riscatto**: su Play la
        disdetta non toglie l'accesso, lo lascia fino a fine periodo;
      - fino a **10.000 codici monouso per trimestre per prodotto abbonamento**
        (il tetto di 500 riguarda i prodotti una tantum); la promozione può
        restare riscattabile fino a un anno;
      - i **codici monouso** si riscattano sia dal Play Store sia dalla
        finestra d'acquisto in-app; i **personalizzati** solo dall'app;
      - riscattabili anche da chi non avrebbe più diritto a un trial standard
        (es. ex abbonati), quindi a un tester si può dare un secondo codice.
      Il riscatto dal Play Store avviene FUORI dall'app: è coperto dal
      `syncPurchases()` al `resume` in `premium_provider.dart` (sezione 4).

## 7. GDPR / legale

- [x] **Privacy policy** — generata con **Termly** (non iubenda, come previsto
      in origine). Dichiara ciò che si raccoglie davvero:
      - acquisti in-app / dati di fatturazione (gestiti da Google);
      - RevenueCat (app user ID anonimo, "identificativi di installazione per
        la gestione degli abbonamenti e la prevenzione di abusi");
      - eventuale Firebase Analytics/Crashlytics se usati.
      Punto di forza da esplicitare: i dati di scout (squadre, giocatori,
      partite — spesso minori) restano LOCALI sul dispositivo.
- [x] URL pubblico della policy — **ospitata su Google Sites**:
      `https://sites.google.com/view/volleystratego/privacy-policy`.
- [x] Terms of Use (anch'essi Termly), stesso sito:
      `https://sites.google.com/view/volleystratego/terms-of-use`.
      Entrambi gli URL sono cablati in `about_screen.dart` (`_kUrl*`).
- [x] **Data Safety** compilata su Play Console (in italiano la voce si chiama
      **"Sicurezza dei dati"**, sotto Norme → Contenuti dell'app: è una scheda
      a sé, sorella di "Norme sulla privacy", non una sezione di quella).
      Da rileggere solo se cambiano la policy Termly o le dipendenze che
      raccolgono dati: con RevenueCat va dichiarata la **cronologia acquisti**
      (finalità "Funzionalità dell'app" e "Analisi"), mentre i dati di scout
      restano locali sul dispositivo e non sono né raccolti né condivisi.

## 8. Scheda store e lancio

- [x] Scheda Play Store: descrizione, screenshot (tablet landscape!), icona,
      categoria, URL privacy policy, email/URL di supporto.
- [x] Landing page semplice: il sito Google Sites
      `sites.google.com/view/volleystratego`, che ospita anche i documenti
      legali (sezione 7).
- [x] Promozione dalla traccia closed testing → **produzione (2026-08-18)**.

## 9. Post-lancio: misurare la condivisione (decidere se servirà mai la Strada B)

- [ ] Osservare per 2-3 mesi nella dashboard RevenueCat gli **alias** per
      customer abbonato (più app user ID anonimi sullo stesso acquisto =
      possibile condivisione dell'account store).
- [ ] Per statistiche aggregate: export/API di RevenueCat + script che conta
      gli alias per abbonamento.
- [ ] Attenzione ai falsi positivi: cambio telefono e reinstallazioni generano
      nuovi ID. Soglia interessante: 5+ alias con ripristini frequenti.
- [ ] Regola di decisione: maggioranza su 1-2 dispositivi — restare su
      Strada A. Quota significativa su molti dispositivi — valutare Strada B
      (account + limite dispositivi).

---

## Ordine consigliato

1. Finire il core (scout, statistiche, export) — priorità assoluta.
2. Sezione 0 (decisioni) + sezione 2 (gate + paywall nel codice).
3. Sezioni 1, 3, 4 (Play Console + RevenueCat).
4. Sezione 5 (closed testing con gli amici) — feedback + requisito Google.
5. Sezione 7 (documenti legali + Data Safety) — prima della pubblicazione.
6. Sezione 8 (scheda store + lancio).
7. Sezioni 6 e 9 (regali e monitoraggio) — post-lancio.

I punti 1-6 sono conclusi: l'app è in produzione dal 2026-08-18.

## Principio guida

Tenere fuori dal cloud tutto il possibile: nessun account, nessun backend,
dati di scout sempre locali. L'unica "identità" è l'account Google dello store
+ l'ID anonimo di RevenueCat. Superficie GDPR minima, sviluppo minimo.

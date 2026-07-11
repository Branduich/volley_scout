# TODO — Monetizzazione Strada A (nessun account, abbonamento via store)

> Roadmap operativa per la Strada A: dati 100% locali, NESSUN login, abbonamento
> gestito interamente da Google Play tramite RevenueCat. Il trial e il premium
> sono legati all'account Google del dispositivo, non a un account dell'app.
>
> Prerequisito: core dell'app funzionante (scout, statistiche, export).
> NB: quadro pratico, non consulenza legale.

---

## 0. Decisioni preliminari (carta e penna, zero codice)

- [ ] **Linea free/premium** — definire cosa resta gratis dopo il trial. Bozza:
      - FREE: scout completo, 1-2 squadre, statistiche di base.
      - PREMIUM: squadre illimitate, statistiche avanzate (per fase/rotazione,
        heatmap traiettorie), export PDF/CSV, doppio libero.
      - DECISO (primo giro, 2026-07-12): gate SOLO su export PDF/CSV;
        il resto della linea si definisce dopo.
- [ ] **Prezzo** — abbonamento annuale (riferimento competitor: ~30 EUR/anno).
      Ricordare commissioni store (15% sotto 1M USD/anno con il programma
      "small business", altrimenti 30%).
- [ ] **Trial** — durata 15 giorni, gestito dallo store (Modo 1):
      configurato DENTRO il prodotto abbonamento. L'utente inserisce il metodo
      di pagamento all'inizio ma non viene addebitato durante la prova.
      Nota: niente trial "automatico all'installazione senza carta" — sarebbe
      il Modo 2, aggirabile senza account.

## 1. Account Google Play Developer

- [X] Registrazione Google Play Developer: 25 USD una tantum.
- [X] Completare la verifica identità (può richiedere qualche giorno).
- [ ] Nota: per i nuovi account personali Google richiede un periodo di closed
      testing con un numero minimo di tester prima di poter pubblicare in
      produzione — quindi la sezione 5 (closed testing) non è opzionale,
      è parte del percorso obbligato. Verificare i requisiti correnti in
      Play Console.

## 2. Codice — freemium gate

- [x] Creare UN punto centrale di verità: provider Riverpod
      `statoPremiumProvider` (stato: `free / trial / premium`) —
      `lib/providers/premium_provider.dart`, per ora STUB (default premium,
      toggle debug "Simula utente free" in Impostazioni).
- [x] Piazzare i gate nel codice: ogni funzione premium controlla il provider
      prima di attivarsi (mai logica sparsa nelle schermate). Primo giro:
      export PDF e CSV in `MatchesScreen`.
- [ ] Comportamento offline: cache dell'ultimo stato noto, così in palestra
      senza rete lo scout e il premium funzionano (RevenueCat lo fa di default,
      verificare).
- [x] Schermata **paywall**: vantaggi premium + bottone abbonati + bottone
      "Ripristina acquisti" (obbligatorio) — per ora placeholder
      (`lib/screens/premium/paywall_screen.dart`), acquisto/ripristino da
      agganciare a RevenueCat.
- [x] Schermata **About/Info** (pubblica, raggiungibile dalle impostazioni).
      Doppio scopo: requisito Google Play (il link alla privacy
      policy deve essere accessibile ANCHE dentro l'app, non solo nella scheda
      store) + supporto/regali. Contenuto (placeholder dove il dato non esiste
      ancora):
      - nome app + versione (via `package_info_plus`);
      - link Privacy Policy e Terms of Use (URL iubenda, via `url_launcher`) —
        PLACEHOLDER finché non esistono gli URL;
      - email/contatto di supporto — PLACEHOLDER da definire;
      - link "Gestisci abbonamento" — deep link alle sottoscrizioni Play Store
        (`https://play.google.com/store/account/subscriptions`);
      - **app user ID di RevenueCat** (`await Purchases.appUserID`), sempre
        visibile con etichetta "ID supporto" e bottone Copia
        (`Clipboard.setData`) — serve per il supporto clienti e per i granted
        entitlements agli amici (sezione 6). Per ora "non disponibile".

## 3. Prodotto abbonamento su Play Console

- [ ] Creare l'abbonamento in Play Console — Prodotti — Abbonamenti:
      - base plan annuale, auto-rinnovabile;
      - offerta "new customer acquisition" con free trial di 15 giorni.
- [ ] Attendere la propagazione (fino a 24h prima che l'offerta sia visibile
      su dispositivo/emulatore).

## 4. Integrazione RevenueCat

- [ ] Creare progetto su RevenueCat, collegare l'app Google Play
      (service account credentials per l'API di Google).
- [ ] Aggiungere il SDK Flutter: `purchases_flutter`.
- [ ] Configurare in RevenueCat: Entitlement `premium` — Product (abbonamento)
      — Offering di default.
- [ ] Collegare lo stato RevenueCat a `statoPremiumProvider`
      (in trial = premium attivo; scaduto = free).
- [ ] Implementare "Ripristina acquisti".
- [ ] Gestire gli stati scadenza / rinnovo / rimborso esposti da RC.
- [ ] Test degli acquisti con **license testers** (sezione 5): per loro gli
      acquisti sono simulati, non addebitati.

## 5. Closed testing su Play Console (feedback amici + requisito Google)

- [ ] Creare una release nella traccia **Closed testing** (build firmata,
      app bundle .aab).
- [ ] Creare una lista tester via email (gli amici) e invitarli con il link
      di opt-in.
- [ ] Aggiungere gli stessi amici come **license testers**
      (Play Console — Impostazioni — License testing): così provano l'intero
      flusso di abbonamento/trial senza addebiti reali.
- [ ] Raccogliere feedback: il feedback dei tester chiusi resta privato,
      NON finisce nelle recensioni pubbliche.
- [ ] Iterare sulle build finché il flusso scout — statistiche — export —
      paywall è solido.
- [ ] Rispettare il periodo/numero minimo di tester richiesto da Google per
      gli account personali prima di richiedere l'accesso alla produzione.

## 6. Regali post-lancio (amici, promozioni)

- [ ] **Granted entitlements (RevenueCat)** — via dashboard, concedi il
      premium a un app user ID specifico per la durata che vuoi. Nessun codice,
      nessuna configurazione store, revocabile. La via consigliata per regalare
      il premium a singoli amici. (L'ID si recupera dalla schermata
      About della sezione 2, campo "ID supporto".)
- [ ] **Promo code Google Play** (opzionale, per campagne future) — da
      Play Console — Promotions. Limiti: per gli abbonamenti offrono solo un
      free trial (non l'abbonamento intero gratis), sono contingentati per
      trimestre, e RevenueCat non traccia quelli creati dalla sezione
      Promotions. Utili per distribuzioni "pubbliche" (tornei, società).

## 7. GDPR / legale

- [ ] **Privacy policy con iubenda** — prodotto: Privacy and Cookie Policy
      (piano base; NON servono Consent Database né Cookie Solution).
      Dichiarare solo ciò che si raccoglie davvero:
      - acquisti in-app / dati di fatturazione (gestiti da Google);
      - RevenueCat (app user ID anonimo, "identificativi di installazione per
        la gestione degli abbonamenti e la prevenzione di abusi");
      - eventuale Firebase Analytics/Crashlytics se usati.
      Punto di forza da esplicitare: i dati di scout (squadre, giocatori,
      partite — spesso minori) restano LOCALI sul dispositivo.
- [ ] URL pubblico della policy = link ospitato da iubenda (non serve un sito).
- [ ] Terms of Use (iubenda li genera).
- [ ] Compilare **Data Safety** su Play Console in modo coerente con la policy.

## 8. Scheda store e lancio

- [ ] Scheda Play Store: descrizione, screenshot (tablet landscape!), icona,
      categoria, URL privacy policy, email/URL di supporto.
- [ ] Landing page semplice (consigliata, non obbligatoria): una pagina con
      cos'è l'app, screenshot, prezzi, link store. Carrd/Framer o GitHub
      Pages/Netlify — poche ore.
- [ ] Promozione dalla traccia closed testing — produzione.

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
5. Sezione 7 (iubenda + Data Safety) — prima della pubblicazione.
6. Sezione 8 (scheda store + lancio).
7. Sezioni 6 e 9 (regali e monitoraggio) — post-lancio.

## Principio guida

Tenere fuori dal cloud tutto il possibile: nessun account, nessun backend,
dati di scout sempre locali. L'unica "identità" è l'account Google dello store
+ l'ID anonimo di RevenueCat. Superficie GDPR minima, sviluppo minimo.

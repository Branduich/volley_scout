# Riepilogo passi mancanti per andare live (Strada A)

> Aggiornato al 2026-07-12. Sintesi operativa; il dettaglio completo è in
> `docs/TODO_strada_A.md`.

L'app e il codice sono sostanzialmente pronti: quasi tutto ciò che manca è
lavoro nelle console (Play Console, RevenueCat, iubenda), non sviluppo.

---

## Già fatto (contesto)
- Core app completo: scout event-sourced, statistiche, report a video, PDF, CSV.
- Freemium gate centralizzato (`statoPremiumProvider`) collegato all'entitlement
  `premium` reale di RevenueCat; default = free; toggle "Simula premium" per
  debug/tester (flag `--dart-define=PREMIUM_OVERRIDE=true`).
- Paywall reale (offerings / purchase / restore), schermata About, squadra demo
  pre-caricata, package name definitivo `it.branduich.volleystratego`.
- Account Google Play Developer registrato + verifica identità completata.

---

## Percorso critico (in ordine)

### 1. Decisioni finali — carta e penna
- Confermare la linea free/premium definitiva (i gate principali sono già
  decisi e implementati).
- Fissare il **prezzo** dell'abbonamento annuale + iscrizione al programma
  "small business" di Google (commissione 15% invece del 30%).
- Confermare la durata del **trial** (15 giorni, gestito dallo store).

### 2. RevenueCat — service account Google
- Creare/collegare il **service account Google** su RevenueCat (necessario alla
  validazione server-side degli acquisti). È l'unico pezzo RevenueCat ancora
  aperto.

### 3. Prodotto abbonamento su Play Console
- Creare l'abbonamento annuale auto-rinnovabile + offerta "new customer" con
  free trial 15 giorni.
- Attendere la propagazione (fino a 24h prima che sia visibile su dispositivo).

### 4. Legale — iubenda + Data Safety
- Generare **Privacy Policy** e **Terms of Use** con iubenda. Dichiarare:
  acquisti in-app via Google, ID anonimo RevenueCat, eventuale Firebase; e
  sottolineare che i dati di scout (squadre, giocatori, partite — spesso minori)
  restano **LOCALI** sul dispositivo.
- Ottenere gli **URL pubblici** della policy (ospitati da iubenda).
- Compilare la sezione **Data Safety** su Play Console, coerente con la policy.

### 5. Codice — riempire i placeholder di About (dipende dal punto 4)
- In `lib/screens/settings/about_screen.dart`: inserire gli URL reali di
  Privacy/Terms (costanti `_kUrl*`) e l'**email di supporto**.
- (Verifica, non modifica) confermare che RevenueCat mantenga in cache l'ultimo
  stato premium offline, così lo scout in palestra senza rete funziona.
- Ricordare di incrementare `versionCode` (`+N`) in `pubspec.yaml` a ogni
  upload su Play.

### 6. Closed testing — obbligatorio per account personali
- Build firmata **.aab**, release in traccia **Closed testing**.
- Lista tester via email + aggiungerli come **license testers** (Play Console →
  Impostazioni → License testing): provano l'intero flusso abbonamento/trial
  senza addebiti reali.
- Iterare sulle build finché scout → statistiche → export → paywall è solido.
- Rispettare il numero minimo di tester / periodo richiesto da Google prima di
  poter richiedere l'accesso alla produzione.

### 7. Scheda store + lancio
- Scheda Play Store: descrizione, **screenshot tablet landscape**, icona,
  categoria, URL privacy policy, contatto di supporto.
- (Opzionale) landing page semplice (Carrd/Framer o GitHub Pages).
- Promozione dalla traccia closed testing → **produzione**.

---

## Dopo il lancio (non bloccanti)
- **Regali**: granted entitlements su RevenueCat per singoli amici (usa il campo
  "ID supporto" della schermata About); eventuali promo code Play per campagne.
- **Monitoraggio condivisione account**: osservare gli alias RevenueCat per
  decidere se in futuro servirà mai la Strada B (account + limite dispositivi).

---

## Cosa tocca davvero il codice
Quasi tutto il residuo è operativo. Unici interventi di codice:
1. `about_screen.dart` — URL Privacy/Terms + email supporto (quando esistono).
2. Verifica del comportamento offline di RevenueCat (probabile "nessuna
   modifica", solo test).
3. `pubspec.yaml` — bump `versionCode` a ogni upload.

Tutto il resto (service account, prodotto abbonamento, iubenda, Data Safety,
closed testing, scheda store) si fa nelle console Play / RevenueCat / iubenda.

---

## Comandi di build utili
- **APK per tester** (toggle "Simula premium" + "Modalità test" disponibili):
  ```
  flutter build apk --release --dart-define=PREMIUM_OVERRIDE=true
  ```
- **App bundle di produzione** (toggle nascosti, paywall attivo):
  ```
  flutter build appbundle --release
  ```
- Prima del closed testing reale: `flutter test` verde + prova manuale del
  flusso paywall con un license tester su una build `.aab` in traccia chiusa.

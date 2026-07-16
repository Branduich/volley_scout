# Riepilogo passi mancanti per andare live (Strada A)

> Aggiornato al 2026-07-16. Sintesi operativa; il dettaglio completo è in
> `docs/TODO_strada_A.md`.

Il codice è **pronto**. Tutto ciò che resta è operativo (Play Console) più
l'attesa obbligatoria del test chiuso: **12+ tester per 14 giorni consecutivi**,
che è il vero collo di bottiglia verso la produzione.

---

## Già fatto

### App e codice
- Core completo: scout event-sourced, statistiche, report a video, PDF, CSV.
- Freemium gate centralizzato (`statoPremiumProvider`) collegato all'entitlement
  `premium` reale di RevenueCat; default = free; toggle "Simula premium" e
  "Modalità test" visibili solo con `--dart-define=PREMIUM_OVERRIDE=true`.
- Paywall reale (offerings / purchase / restore), schermata About, squadra demo
  pre-caricata, package name definitivo `it.branduich.volleystratego`.
- Link legali e supporto completati in `about_screen.dart` (vedi sotto).

### Play Console
- Account developer registrato + verifica identità completata.
- App creata, dichiarazioni di contenuto completate (Data Safety, content
  rating IARC, dettagli di accesso, integrità app).
- Scheda store completa: descrizione, icona, feature graphic, screenshot.
- Profilo pagamenti configurato + iscrizione al programma **small business**
  (commissione **15%** invece del 30%).
- Abbonamento `premium_annual`, piano base `annual` **Attivo**, offerta con
  **trial 15 giorni** **Attiva**.
- **Test interni**: canale attivo, installazione verificata su device reale.
- **License tester** configurato (`branduich@gmail.com`, RESPOND_NORMALLY) —
  era la causa dell'errore `ITEM_UNAVAILABLE` al momento dell'acquisto.

### RevenueCat — VERIFICATO END-TO-END
- Service account Google collegato, credenziali valide (serviva il permesso
  **Autorizzazioni app** sul service account, inizialmente vuoto).
- Prodotto importato e pubblicato, entitlement `premium`, offering `default`.
- **Flusso di acquisto provato con successo sul device**: Play → RevenueCat →
  entitlement `premium` → sblocco dei gate nell'app. È il pezzo più fragile di
  tutta la catena ed è confermato funzionante.

### Legale
- **Privacy Policy** e **Termini di utilizzo** pubblicati su **Google Sites**
  (non iubenda — scelta finale):
  - https://sites.google.com/view/volleystratego/privacy-policy
  - https://sites.google.com/view/volleystratego/terms-of-use
  - Bozza dei termini conservata in `docs/termini_di_utilizzo.md`.
- Email di supporto: `volleystratego@gmail.com`.

---

## Percorso critico residuo

### 1. Test chiuso — IL COLLO DI BOTTIGLIA
- Caricare l'AAB **1.0.0 (4)** sulla traccia **Test chiusi - Alpha** (paesi e
  tester già selezionati). L'upload **fa partire il cronometro**.
- Servono **12+ tester attivi per 14 giorni consecutivi** (requisito Google per
  gli account personali). Aggiungerne altri dopo non azzera il conteggio, ma
  devono restare iscritti per tutto il periodo.
- Iterare sulle build finché scout → statistiche → export → paywall è solido.

### 2. Richiesta di accesso alla produzione
- Al termine dei 14 giorni: richiesta a Google + **revisione** (tempi variabili).
- Promozione della traccia closed testing → **produzione**.

---

## Note operative ricorrenti

- **Bump del `versionCode`** (`+N` in `pubspec.yaml`) a **ogni** upload, altrimenti
  Play rifiuta il bundle. Attuale: `1.0.0+4`.
- **Propagazione**: sia le installazioni dalle tracce di test sia le modifiche
  agli abbonamenti richiedono tempo (fino a qualche ora). Più di un falso
  allarme si è risolto da solo aspettando. In caso di dubbio: forza arresto /
  svuota cache del Play Store sul device.
- **Prezzo e IVA**: il prezzo su Play è **comprensivo di IVA**; Google incassa e
  versa l'IVA UE al posto tuo. Netto al developer ≈ `prezzo × 0,697` per un
  acquirente italiano (IVA 22% scorporata, poi 15% di commissione). L'IVA varia
  col paese dell'acquirente.

---

## Dopo il lancio (non bloccanti)
- **Regali**: granted entitlements su RevenueCat per singoli amici (usa il campo
  "ID supporto" della schermata About); eventuali promo code Play per campagne.
- **Monitoraggio condivisione account**: osservare gli alias RevenueCat per
  decidere se in futuro servirà mai la Strada B (account + limite dispositivi).
- **RTDN (Pub/Sub)**: opzionale, richiede il permesso IAM
  `roles/pubsub.admin` per il service account RevenueCat.
- **Aggiornamento plugin** (warning KGP in build): `package_info_plus` 9→10,
  `purchases_flutter` 8→10, `share_plus` 12→13. Non blocca oggi, ma versioni
  future di Flutter falliranno la build.
- Titolo visibile della pagina Termini su Google Sites = slug `terms-of-use`
  (cosmetico, rinominabile mantenendo l'URL).

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
  → `build\app\outputs\bundle\release\app-release.aab`
- Prima di ogni upload: `flutter test` verde.

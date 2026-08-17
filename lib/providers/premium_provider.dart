import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/revenuecat.dart';
import '../tutorial/tutorial_controller.dart';
import 'settings_provider.dart';

/// Stato premium dell'utente — UNICO punto di verità per il freemium gate
/// (Strada A, vedi docs/TODO_strada_A.md): ogni feature premium controlla
/// questo provider, mai logica sparsa nelle schermate.
///
/// Lo stato reale viene da RevenueCat (entitlement `premium`): `free` finché
/// non c'è un abbonamento attivo, `trial` durante la prova, `premium` da
/// abbonati. Aggiornato in tempo reale dal listener della SDK (acquisto,
/// rinnovo, scadenza, restore). In **debug** il toggle "Simula premium" in
/// `SettingsScreen` forza `premium` per sviluppare le feature senza un
/// acquisto reale (in release la chiave è ignorata).
enum StatoPremium { free, trial, premium }

extension StatoPremiumX on StatoPremium {
  /// Le feature premium sono attive sia in trial sia da abbonati.
  bool get attivo => this != StatoPremium.free;
}

/// Consente il toggle debug "Simula premium" anche in release, SOLO se la
/// build è compilata con `--dart-define=PREMIUM_OVERRIDE=true` (APK "per
/// tester", per provare le feature premium prima che il billing Play sia
/// pronto). La build di produzione (senza flag) resta gated.
const bool kPremiumOverrideConsentito = bool.fromEnvironment('PREMIUM_OVERRIDE');

/// Vero quando il toggle "Simula premium" deve essere disponibile: sempre in
/// debug, in release solo con il flag sopra.
bool get overridePremiumDisponibile => kDebugMode || kPremiumOverrideConsentito;

StatoPremium _daCustomerInfo(CustomerInfo info) {
  final ent = info.entitlements.active[kEntitlementPremium];
  if (ent == null) return StatoPremium.free;
  return ent.periodType == PeriodType.trial
      ? StatoPremium.trial
      : StatoPremium.premium;
}

class StatoPremiumNotifier extends Notifier<StatoPremium> {
  static const _kDebugForzaPremium = 'premium.debugForzaPremium';

  // Protegge dallo scrivere lo stato da una getCustomerInfo() ancora in volo
  // quando il provider è già stato smontato.
  bool _disposed = false;

  @override
  StatoPremium build() {
    // Da rimettere a false a ogni build: il notifier è lo STESSO oggetto tra
    // un rebuild e l'altro (Riverpod richiama build() sull'istanza esistente,
    // dopo aver eseguito gli onDispose del giro precedente). Senza questa
    // riga, dopo la prima invalidazione il flag restava true per sempre e sia
    // il listener di RevenueCat sia _caricaIniziale() smettevano di
    // aggiornare lo stato: un acquisto non sbloccava più niente, senza alcun
    // errore visibile. Il provider viene invalidato di suo dall'uso del
    // tutorial (vedi sotto) e dal toggle "Simula premium".
    _disposed = false;
    ref.onDispose(() => _disposed = true);

    // Durante il tutorial l'utente è premium a prescindere: la guida deve
    // poter MOSTRARE le funzioni a pagamento (traiettorie in primis), ed è
    // anche la vetrina migliore che ci sia. Nessun acquisto è possibile da
    // qui e la partita è finta, quindi non c'è nulla da proteggere. Sta qui e
    // non nelle schermate perché questo provider è l'unico punto di verità
    // del gate.
    if (ref.watch(tutorialControllerProvider).attivo) {
      return StatoPremium.premium;
    }

    // Toggle "Simula premium": forza il premium in debug (o in release con
    // il flag PREMIUM_OVERRIDE). In produzione la chiave viene ignorata.
    if (overridePremiumDisponibile &&
        (ref.watch(sharedPreferencesProvider).getBool(_kDebugForzaPremium) ??
            false)) {
      return StatoPremium.premium;
    }

    // Ascolta gli aggiornamenti di RevenueCat: aggiornano lo stato appena
    // cambia l'entitlement (acquisto/rinnovo/scadenza/restore).
    void listener(CustomerInfo info) {
      if (!_disposed) state = _daCustomerInfo(info);
    }

    try {
      Purchases.addCustomerInfoUpdateListener(listener);
      ref.onDispose(() => Purchases.removeCustomerInfoUpdateListener(listener));
    } catch (_) {
      // Purchases non configurato (piattaforma non supportata): resta free.
    }

    // Acquisti fatti FUORI dall'app: codice promozionale riscattato dal Play
    // Store (esce dall'app, riscatta, rientra) o abbonamento comprato su un
    // altro dispositivo. Il listener qui sopra scatta solo quando la SDK va a
    // rileggere di suo: senza un aggancio al ciclo di vita il gate resterebbe
    // chiuso finché l'utente non trova "Ripristina acquisti" nel paywall.
    // L'SDK Android interroga già gli acquisti al foreground, ma non è
    // garantito dal nostro codice — questo lo rende deterministico.
    final cicloVita = AppLifecycleListener(onResume: _sincronizza);
    ref.onDispose(cicloVita.dispose);

    _caricaIniziale();
    return StatoPremium.free; // finché non arriva l'info reale (cache RC)
  }

  Future<void> _caricaIniziale() async {
    try {
      final info = await Purchases.getCustomerInfo();
      if (!_disposed) state = _daCustomerInfo(info);
    } catch (_) {
      // Offline al primo avvio o SDK non pronta: resta free.
    }
  }

  /// Rimette in pari l'entitlement al ritorno in primo piano (vedi il commento
  /// in `build()`). Da `free` si forza `syncPurchases()`, che posta a
  /// RevenueCat un acquisto Play che la SDK non ha ancora registrato — è
  /// esattamente il caso del codice promozionale riscattato dal Play Store.
  /// Già sbloccati basta `getCustomerInfo()`: legge la cache, costa poco e
  /// intercetta comunque scadenze e rimborsi.
  Future<void> _sincronizza() async {
    if (_disposed) return;
    try {
      if (state == StatoPremium.free) await Purchases.syncPurchases();
      final info = await Purchases.getCustomerInfo();
      if (!_disposed) state = _daCustomerInfo(info);
    } catch (_) {
      // Offline o SDK non configurata: lo stato resta quello che è.
    }
  }

  /// Vero se il toggle debug "Simula premium" è attivo (solo debug).
  bool get debugForzaPremium =>
      ref.read(sharedPreferencesProvider).getBool(_kDebugForzaPremium) ?? false;

  Future<void> setDebugForzaPremium(bool value) async {
    await ref.read(sharedPreferencesProvider).setBool(_kDebugForzaPremium, value);
    ref.invalidateSelf();
  }
}

final statoPremiumProvider =
    NotifierProvider<StatoPremiumNotifier, StatoPremium>(
        StatoPremiumNotifier.new);

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/revenuecat.dart';
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

  // invalidateSelf() (dal toggle debug) crea una NUOVA istanza: il flag,
  // settato via onDispose della vecchia, evita che una getCustomerInfo()
  // ancora in volo scriva lo stato su un notifier già dismesso.
  bool _disposed = false;

  @override
  StatoPremium build() {
    ref.onDispose(() => _disposed = true);

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

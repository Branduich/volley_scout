import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_provider.dart';

/// Stato premium dell'utente — UNICO punto di verità per il freemium gate
/// (Strada A, vedi docs/TODO_strada_A.md): ogni feature premium controlla
/// questo provider, mai logica sparsa nelle schermate.
///
/// STUB in attesa di RevenueCat: il default è `premium` (l'app resta
/// completa per utente e tester — nessuna regressione finché non esiste il
/// billing vero); in debug il toggle "Simula utente free" delle
/// Impostazioni forza `free` per provare gate e paywall. Quando arriverà
/// RevenueCat, `build()` leggerà l'entitlement reale e il resto dell'app
/// non cambierà.
enum StatoPremium { free, trial, premium }

extension StatoPremiumX on StatoPremium {
  /// Le feature premium sono attive sia in trial sia da abbonati.
  bool get attivo => this != StatoPremium.free;
}

class StatoPremiumNotifier extends Notifier<StatoPremium> {
  static const _kSimulaFree = 'premium.simulaFree';

  @override
  StatoPremium build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    // La simulazione vale SOLO in debug: una release con la chiave rimasta
    // a true non deve mai declassare un utente reale.
    if (kDebugMode && (prefs.getBool(_kSimulaFree) ?? false)) {
      return StatoPremium.free;
    }
    return StatoPremium.premium;
  }

  /// Vero se la simulazione "utente free" è attiva (solo debug).
  bool get simulaFree =>
      ref.read(sharedPreferencesProvider).getBool(_kSimulaFree) ?? false;

  Future<void> setSimulaFree(bool value) async {
    await ref.read(sharedPreferencesProvider).setBool(_kSimulaFree, value);
    ref.invalidateSelf();
  }
}

final statoPremiumProvider =
    NotifierProvider<StatoPremiumNotifier, StatoPremium>(
        StatoPremiumNotifier.new);

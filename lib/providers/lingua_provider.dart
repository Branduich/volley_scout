import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_provider.dart';

/// Lingua dell'app: `null` = segue la lingua del dispositivo (tra quelle
/// supportate, fallback inglese); altrimenti una `Locale` forzata dall'utente
/// via Impostazioni. Persistita su shared_preferences (chiave `app.lingua`:
/// 'it'/'en', assente = sistema). Il valore è passato a `MaterialApp.locale`.
class LinguaNotifier extends Notifier<Locale?> {
  static const _key = 'app.lingua';

  @override
  Locale? build() {
    final code = ref.watch(sharedPreferencesProvider).getString(_key);
    if (code == null) return null; // sistema
    return Locale(code);
  }

  /// `null` = torna a seguire il sistema.
  Future<void> setLingua(Locale? locale) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (locale == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, locale.languageCode);
    }
    ref.invalidateSelf();
  }
}

final linguaProvider =
    NotifierProvider<LinguaNotifier, Locale?>(LinguaNotifier.new);

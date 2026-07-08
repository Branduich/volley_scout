import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Istanza di SharedPreferences caricata una volta in `main()` (prima di
/// `runApp`) e iniettata con override sul `ProviderScope` — così le
/// impostazioni si leggono in modo sincrono ovunque, senza FutureProvider.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
      'sharedPreferencesProvider va sovrascritto in main()');
});

/// Impostazioni dell'app (per ora solo scout). Immutabile: ogni modifica
/// passa da ImpostazioniNotifier, che persiste e riemette lo stato.
class Impostazioni {
  /// Se true (default), dopo il voto di battuta/attacco si apre
  /// TrajectoryScreen per disegnare la traiettoria; se false l'azione si
  /// registra subito con coordinate null (stesso percorso del "salta").
  /// In futuro candidata al gating premium.
  final bool traiettorieAbilitate;

  const Impostazioni({required this.traiettorieAbilitate});
}

class ImpostazioniNotifier extends Notifier<Impostazioni> {
  static const _kTraiettorie = 'scout.traiettorieAbilitate';

  @override
  Impostazioni build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return Impostazioni(
      traiettorieAbilitate: prefs.getBool(_kTraiettorie) ?? true,
    );
  }

  Future<void> setTraiettorieAbilitate(bool value) async {
    await ref.read(sharedPreferencesProvider).setBool(_kTraiettorie, value);
    state = Impostazioni(traiettorieAbilitate: value);
  }
}

final impostazioniProvider =
    NotifierProvider<ImpostazioniNotifier, Impostazioni>(
        ImpostazioniNotifier.new);

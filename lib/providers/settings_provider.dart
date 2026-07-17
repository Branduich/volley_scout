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

  /// Se true (**default ON**), abilita lo scout leggero della squadra
  /// avversaria (segnaposto per ruolo che ruotano sulla metà campo opposta,
  /// registrazione di attacchi/battute/muro avversari, prompt della posizione
  /// del palleggiatore avversario a inizio set). Se false, lo scout resta solo
  /// sulla nostra squadra come prima. Flag di gating della feature — vedi
  /// piano scout avversari.
  final bool scoutAvversariAbilitato;

  const Impostazioni({
    required this.traiettorieAbilitate,
    required this.scoutAvversariAbilitato,
  });
}

class ImpostazioniNotifier extends Notifier<Impostazioni> {
  static const _kTraiettorie = 'scout.traiettorieAbilitate';
  static const _kScoutAvversari = 'scout.scoutAvversariAbilitato';

  @override
  Impostazioni build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return Impostazioni(
      traiettorieAbilitate: prefs.getBool(_kTraiettorie) ?? true,
      scoutAvversariAbilitato: prefs.getBool(_kScoutAvversari) ?? true,
    );
  }

  Future<void> setTraiettorieAbilitate(bool value) async {
    await ref.read(sharedPreferencesProvider).setBool(_kTraiettorie, value);
    state = Impostazioni(
      traiettorieAbilitate: value,
      scoutAvversariAbilitato: state.scoutAvversariAbilitato,
    );
  }

  Future<void> setScoutAvversariAbilitato(bool value) async {
    await ref.read(sharedPreferencesProvider).setBool(_kScoutAvversari, value);
    state = Impostazioni(
      traiettorieAbilitate: state.traiettorieAbilitate,
      scoutAvversariAbilitato: value,
    );
  }
}

final impostazioniProvider =
    NotifierProvider<ImpostazioniNotifier, Impostazioni>(
        ImpostazioniNotifier.new);

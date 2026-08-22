import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/enums.dart';

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

  /// Se true (default), la voce "Tutorial" compare nel menu principale. Chi
  /// l'ha già fatto la nasconde da qui; il tutorial resta comunque avviabile
  /// dalle Impostazioni.
  final bool tutorialVisibile;

  /// Separatore di campo e decimale dell'export CSV (default `europeo`, il
  /// formato storico). Scelta esplicita e NON derivata dalla lingua dell'app:
  /// a decidere è il locale del computer su cui si apre il file — vedi
  /// `FormatoCsv`.
  final FormatoCsv formatoCsv;

  const Impostazioni({
    required this.traiettorieAbilitate,
    required this.scoutAvversariAbilitato,
    required this.tutorialVisibile,
    required this.formatoCsv,
  });

  Impostazioni copyWith({
    bool? traiettorieAbilitate,
    bool? scoutAvversariAbilitato,
    bool? tutorialVisibile,
    FormatoCsv? formatoCsv,
  }) {
    return Impostazioni(
      traiettorieAbilitate: traiettorieAbilitate ?? this.traiettorieAbilitate,
      scoutAvversariAbilitato:
          scoutAvversariAbilitato ?? this.scoutAvversariAbilitato,
      tutorialVisibile: tutorialVisibile ?? this.tutorialVisibile,
      formatoCsv: formatoCsv ?? this.formatoCsv,
    );
  }
}

class ImpostazioniNotifier extends Notifier<Impostazioni> {
  static const _kTraiettorie = 'scout.traiettorieAbilitate';
  static const _kScoutAvversari = 'scout.scoutAvversariAbilitato';
  static const _kTutorialVisibile = 'scout.tutorialVisibile';
  // NB: la chiave 'scout.traiettoriaBattutaInLine' non si legge più (il
  // disegno sul campo è l'unico modo dal 2026-08-22) e resta orfana nelle
  // preferenze di chi l'aveva provata. Innocua: shared_preferences non si
  // lamenta di una chiave che nessuno legge.
  static const _kFormatoCsv = 'export.formatoCsv';

  @override
  Impostazioni build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final formatoSalvato = prefs.getString(_kFormatoCsv);
    return Impostazioni(
      traiettorieAbilitate: prefs.getBool(_kTraiettorie) ?? true,
      scoutAvversariAbilitato: prefs.getBool(_kScoutAvversari) ?? true,
      tutorialVisibile: prefs.getBool(_kTutorialVisibile) ?? true,
      // Valore sconosciuto (chiave scritta da una versione futura) → default,
      // mai un'eccezione da byName().
      formatoCsv: FormatoCsv.values
              .where((f) => f.name == formatoSalvato)
              .firstOrNull ??
          FormatoCsv.europeo,
    );
  }

  Future<void> setTraiettorieAbilitate(bool value) async {
    await ref.read(sharedPreferencesProvider).setBool(_kTraiettorie, value);
    state = state.copyWith(traiettorieAbilitate: value);
  }

  Future<void> setScoutAvversariAbilitato(bool value) async {
    await ref.read(sharedPreferencesProvider).setBool(_kScoutAvversari, value);
    state = state.copyWith(scoutAvversariAbilitato: value);
  }

  Future<void> setTutorialVisibile(bool value) async {
    await ref.read(sharedPreferencesProvider).setBool(_kTutorialVisibile, value);
    state = state.copyWith(tutorialVisibile: value);
  }

  Future<void> setFormatoCsv(FormatoCsv value) async {
    await ref
        .read(sharedPreferencesProvider)
        .setString(_kFormatoCsv, value.name);
    state = state.copyWith(formatoCsv: value);
  }
}

final impostazioniProvider =
    NotifierProvider<ImpostazioniNotifier, Impostazioni>(
        ImpostazioniNotifier.new);

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_spacing.dart';
import 'tutorial_controller.dart';

/// Riquadro di spiegazione **non bloccante**, per le schermate dove l'azione
/// da insegnare non è premere un pulsante ma un gesto libero — oggi solo
/// `TrajectoryScreen`, dove si trascina il dito sul campo.
///
/// Niente velo e niente buco: lì non c'è un bersaglio da isolare, e uno scrim
/// intercetterebbe proprio il trascinamento da spiegare. Per questo la nota è
/// dentro un `IgnorePointer`.
///
/// Si mostra da sé leggendo il passo corrente: la schermata che la ospita non
/// deve sapere se il tutorial è in corso, le basta piazzarla nello Stack.
/// Il "niente" di [TutorialNota]: un `Positioned` a dimensione zero, **non** un
/// `SizedBox.shrink()`.
///
/// Bug reale: uno `Stack` con vincoli laschi si dimensiona sui figli NON
/// posizionati, quindi un semplice `SizedBox.shrink()` lo faceva collassare a
/// 0×0 e il campo delle traiettorie — che è un `Positioned(left: 0, right: 0)`
/// — spariva in tutte le partite normali. Nel tutorial non si vedeva, perché
/// lì la nota restituisce comunque un `Positioned`.
const Widget _assente =
    Positioned(left: 0, top: 0, width: 0, height: 0, child: SizedBox.shrink());

class TutorialNota extends ConsumerWidget {
  /// Distanza dal bordo superiore dell'area, calcolata da chi la ospita: la
  /// nota va SOTTO al campo (e sotto la riga dei chip), e solo quella
  /// schermata conosce la geometria del campo, che dipende dallo schermo.
  final double top;

  const TutorialNota({super.key, required this.top});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stato = ref.watch(tutorialControllerProvider);
    final testo = stato.attivo
        ? ref.read(tutorialControllerProvider.notifier).passo?.testoTraiettoria
        : null;
    if (testo == null) return _assente;

    final larghezza =
        (MediaQuery.sizeOf(context).width * 0.62).clamp(280.0, 620.0);

    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: Container(
            width: larghezza,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: const Color(0xF00D2738),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: Colors.white24),
            ),
            child: Text(
              testo,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    height: 1.35,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

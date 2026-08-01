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
class TutorialNota extends ConsumerWidget {
  /// Distanza dal bordo superiore dell'area, calcolata da chi la ospita: la
  /// nota va SOTTO al campo (e sotto la riga dei chip), e solo quella
  /// schermata conosce la geometria del campo, che dipende dallo schermo.
  final double top;

  const TutorialNota({super.key, required this.top});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stato = ref.watch(tutorialControllerProvider);
    if (!stato.attivo) return const SizedBox.shrink();
    final testo =
        ref.read(tutorialControllerProvider.notifier).passo?.testoTraiettoria;
    if (testo == null) return const SizedBox.shrink();

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

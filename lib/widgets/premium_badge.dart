import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/premium_provider.dart';
import '../theme/app_colors.dart';

/// Iconcina "premium" (medaglia ambra, stessa icona/colore del paywall) da
/// affiancare alle feature gated: visibile SOLO per un utente free — con
/// premium/trial attivo si riduce a niente, zero rumore per chi ha pagato.
/// Osserva `statoPremiumProvider`, quindi nei punti d'uso si piazza e basta
/// (niente `if` sparsi nelle schermate). Gap sinistro di 6px incorporato.
class PremiumBadge extends ConsumerWidget {
  const PremiumBadge({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(statoPremiumProvider).attivo) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Icon(
        Icons.workspace_premium,
        size: size,
        color: AppColors.brandAccent,
      ),
    );
  }
}

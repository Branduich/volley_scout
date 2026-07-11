import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/premium_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/premium_badge.dart';
import 'about_screen.dart';

/// Impostazioni dell'app (raggiunta dal bottone in fondo al menu di
/// HomeScreen). Per ora una sola sezione "Scout"; le voci future si
/// aggiungono qui.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final impostazioni = ref.watch(impostazioniProvider);
    final premiumAttivo = ref.watch(statoPremiumProvider).attivo;
    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text('Scout', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: SwitchListTile(
              secondary: const PremiumBadge(size: 24),
              title: const Text('Traiettorie durante lo scout'),
              subtitle: Text(premiumAttivo
                  ? 'Dopo il voto di battuta e attacco chiede di disegnare la '
                      'traiettoria. Disattivandola lo scout è più veloce, ma i '
                      'report delle traiettorie restano vuoti.'
                  : 'Funzione premium: le traiettorie sono disattivate.'),
              // Gate premium: per un utente free il toggle è spento e
              // bloccato (le traiettorie non si aprono comunque, vedi
              // ScoutScreen._registraVoto).
              value: premiumAttivo && impostazioni.traiettorieAbilitate,
              onChanged: premiumAttivo
                  ? (v) => ref
                      .read(impostazioniProvider.notifier)
                      .setTraiettorieAbilitate(v)
                  : null,
            ),
          ),
          // Solo in debug: simula un utente free per provare gate e paywall
          // (vedi premium_provider.dart — in release il toggle non esiste e
          // la chiave viene ignorata).
          if (kDebugMode) ...[
            const SizedBox(height: AppSpacing.lg),
            Text('Sviluppo', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Card(
              child: SwitchListTile(
                title: const Text('Simula utente free'),
                subtitle: const Text(
                    'Disattiva il premium per provare i gate e il paywall '
                    '(solo build di debug).'),
                value: !ref.watch(statoPremiumProvider).attivo,
                onChanged: (v) =>
                    ref.read(statoPremiumProvider.notifier).setSimulaFree(v),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Informazioni'),
              subtitle: const Text(
                  'Versione, privacy policy, supporto e abbonamento'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

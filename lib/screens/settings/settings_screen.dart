import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/settings_provider.dart';
import '../../theme/app_spacing.dart';

/// Impostazioni dell'app (raggiunta dal bottone in fondo al menu di
/// HomeScreen). Per ora una sola sezione "Scout"; le voci future si
/// aggiungono qui.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final impostazioni = ref.watch(impostazioniProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text('Scout', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: SwitchListTile(
              title: const Text('Traiettorie durante lo scout'),
              subtitle: const Text(
                  'Dopo il voto di battuta e attacco chiede di disegnare la '
                  'traiettoria. Disattivandola lo scout è più veloce, ma i '
                  'report delle traiettorie restano vuoti.'),
              value: impostazioni.traiettorieAbilitate,
              onChanged: (v) => ref
                  .read(impostazioniProvider.notifier)
                  .setTraiettorieAbilitate(v),
            ),
          ),
        ],
      ),
    );
  }
}

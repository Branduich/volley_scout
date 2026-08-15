import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/enum_l10n.dart';
import '../../models/enums.dart';
import '../../providers/lingua_provider.dart';
import '../../providers/premium_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_spacing.dart';
import '../../utils/orientamento.dart';
import '../../widgets/premium_badge.dart';
import 'about_screen.dart';

/// Impostazioni dell'app (raggiunta dal bottone in fondo al menu di
/// HomeScreen). Le voci future si aggiungono qui.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with OrientamentoSchermata<SettingsScreen> {
  // Lista semplice: comoda anche in portrait.
  @override
  List<DeviceOrientation> get orientamentiConsentiti => kOrientamentoTutti;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final impostazioni = ref.watch(impostazioniProvider);
    final premiumAttivo = ref.watch(statoPremiumProvider).attivo;
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(l.settingsSectionScout,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: SwitchListTile(
              // Ogni voce ha la sua icona nello slot `secondary` (allineamento
              // uniforme della lista), quindi il badge premium non può stare
              // lì: va in coda al titolo, dove si nasconde da sé quando
              // l'abbonamento è attivo.
              // Stessa icona dei bottoni "Traiettorie attacco" (drawer dello
              // scout e report): stessa feature, stesso segno.
              secondary: const Icon(Icons.trending_up),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: Text(l.settingsTrajectoriesTitle)),
                  const PremiumBadge(size: 20),
                ],
              ),
              subtitle: Text(premiumAttivo
                  ? l.settingsTrajectoriesSubtitle
                  : l.settingsTrajectoriesSubtitlePremium),
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
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.groups),
              title: Text(l.settingsOpponentScoutTitle),
              subtitle: Text(l.settingsOpponentScoutSubtitle),
              value: impostazioni.scoutAvversariAbilitato,
              onChanged: (v) => ref
                  .read(impostazioniProvider.notifier)
                  .setScoutAvversariAbilitato(v),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.school),
              title: Text(l.settingsTutorialTitle),
              subtitle: Text(l.settingsTutorialSubtitle),
              value: impostazioni.tutorialVisibile,
              onChanged: (v) => ref
                  .read(impostazioniProvider.notifier)
                  .setTutorialVisibile(v),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(l.settingsSectionExport,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: ListTile(
              leading: const Icon(Icons.table_view),
              title: Text(l.settingsCsvFormatoTitle),
              subtitle: Text(l.settingsCsvFormatoSubtitle),
              // Dropdown sotto al testo (non nel trailing): le due etichette
              // sono lunghe e affiancate al sottotitolo starebbero strette.
              trailing: DropdownButton<FormatoCsv>(
                value: impostazioni.formatoCsv,
                onChanged: (v) => v == null
                    ? null
                    : ref
                        .read(impostazioniProvider.notifier)
                        .setFormatoCsv(v),
                items: [
                  for (final f in FormatoCsv.values)
                    DropdownMenuItem(value: f, child: Text(formatoCsvLabel(f, l))),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildLinguaCard(context, ref, l),
          // Toggle "Simula premium": in debug sempre, in release solo con
          // --dart-define=PREMIUM_OVERRIDE=true (APK "per tester"). Nella
          // build di produzione non compare e la chiave viene ignorata
          // (vedi premium_provider.dart).
          if (overridePremiumDisponibile) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(l.settingsSectionDev,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Card(
              child: SwitchListTile(
                secondary: const Icon(Icons.workspace_premium),
                title: Text(l.settingsSimulatePremium),
                subtitle: Text(l.settingsSimulatePremiumSubtitle),
                value:
                    ref.watch(statoPremiumProvider.notifier).debugForzaPremium,
                onChanged: (v) => ref
                    .read(statoPremiumProvider.notifier)
                    .setDebugForzaPremium(v),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(l.settingsAbout),
              subtitle: Text(l.settingsAboutSubtitle),
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

  // Selezione lingua (dropdown compatta): Sistema / Italiano / English.
  // `null` = segue il dispositivo. Le lingue si mostrano col proprio
  // autonimo (non tradotto); "Predefinita del sistema" è localizzato.
  Widget _buildLinguaCard(
      BuildContext context, WidgetRef ref, AppLocalizations l) {
    final corrente = ref.watch(linguaProvider); // null = sistema
    final notifier = ref.read(linguaProvider.notifier);

    return Card(
      child: ListTile(
        leading: const Icon(Icons.language),
        title: Text(l.settingsSectionLanguage),
        trailing: DropdownButton<String>(
          value: corrente?.languageCode ?? 'system',
          onChanged: (v) => notifier.setLingua(
            v == null || v == 'system' ? null : Locale(v),
          ),
          items: [
            DropdownMenuItem(value: 'system', child: Text(l.languageSystem)),
            const DropdownMenuItem(value: 'it', child: Text('Italiano')),
            const DropdownMenuItem(value: 'en', child: Text('English')),
          ],
        ),
      ),
    );
  }
}

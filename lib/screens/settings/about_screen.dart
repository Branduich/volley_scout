import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_spacing.dart';

// Requisito Google Play: il link alla privacy policy deve essere
// raggiungibile ANCHE dentro l'app. PLACEHOLDER finché gli URL iubenda e
// l'email di supporto non esistono (vedi docs/TODO_strada_A.md, sezioni 2
// e 7) — quando ci sono, basta valorizzarli qui e le voci si abilitano.
const String? _kUrlPrivacyPolicy = null;
const String? _kUrlTermsOfUse = null;
const String? _kEmailSupporto = null;
const String _kUrlAbbonamenti =
    'https://play.google.com/store/account/subscriptions';

/// Schermata "Informazioni" (da SettingsScreen): versione app, link legali,
/// supporto, gestione abbonamento e ID supporto (l'app user ID di
/// RevenueCat quando ci sarà — serve per assistenza e granted entitlements,
/// vedi docs/TODO_strada_A.md sezione 6).
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _versione = '';

  // ID supporto: arriverà da `Purchases.appUserID` (RevenueCat). Finché è
  // null la riga mostra "non disponibile" e il bottone Copia è spento.
  final String? _idSupporto = null;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (!mounted) return;
      setState(() => _versione = '${info.version} (${info.buildNumber})');
    });
  }

  Future<void> _apri(String url) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossibile aprire il link')),
      );
    }
  }

  // Voce link: abilitata solo se l'URL esiste già, altrimenti grigia con
  // nota "in arrivo".
  Widget _vocelink({
    required IconData icona,
    required String titolo,
    required String? url,
  }) {
    final disponibile = url != null;
    return ListTile(
      leading: Icon(icona),
      title: Text(titolo),
      subtitle: disponibile ? null : const Text('In arrivo'),
      enabled: disponibile,
      trailing: disponibile ? const Icon(Icons.open_in_new, size: 20) : null,
      onTap: disponibile ? () => _apri(url) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Informazioni')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              ListTile(
                // Logo dell'app (stesso asset dell'header del PDF).
                leading: Image.asset(
                  'assets/icon/icon_foreground.png',
                  width: 64,
                  height: 64,
                ),
                title: const Text('Volley Stratego'),
                subtitle: Text(
                  _versione.isEmpty ? 'Versione…' : 'Versione $_versione',
                ),
              ),
              const Divider(),
              _vocelink(
                icona: Icons.privacy_tip_outlined,
                titolo: 'Privacy Policy',
                url: _kUrlPrivacyPolicy,
              ),
              _vocelink(
                icona: Icons.description_outlined,
                titolo: 'Termini di utilizzo',
                url: _kUrlTermsOfUse,
              ),
              ListTile(
                leading: const Icon(Icons.mail_outline),
                title: const Text('Supporto'),
                subtitle: Text(_kEmailSupporto ?? 'In arrivo'),
                enabled: _kEmailSupporto != null,
                onTap: _kEmailSupporto == null
                    ? null
                    : () => _apri('mailto:$_kEmailSupporto'),
              ),
              _vocelink(
                icona: Icons.subscriptions_outlined,
                titolo: 'Gestisci abbonamento',
                url: _kUrlAbbonamenti,
              ),
              const Divider(),
              // Sempre visibile (anche quando "non disponibile"): è il dato
              // da chiedere all'utente in caso di assistenza.
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('ID supporto'),
                subtitle: Text(_idSupporto ?? 'Non disponibile'),
                trailing: IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  tooltip: 'Copia',
                  onPressed: _idSupporto == null
                      ? null
                      : () {
                          Clipboard.setData(ClipboardData(text: _idSupporto));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('ID copiato')),
                          );
                        },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

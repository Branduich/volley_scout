import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_spacing.dart';

// Requisito Google Play: il link alla privacy policy deve essere
// raggiungibile ANCHE dentro l'app. Gli altri sono un extra (i termini non
// sono obbligatori; l'email di supporto lo è solo nella scheda dello store).
// I tipi restano nullable anche ora che sono valorizzati (il linter suggerisce
// il contrario): è `null` a spegnere la voce con la nota "In arrivo" in
// `_vocelink`, meccanismo da tenere per eventuali link futuri.
const String _kUrlPrivacyPolicy =
    'https://sites.google.com/view/volleystratego/privacy-policy';
// ignore: unnecessary_nullable_for_final_variable_declarations
const String? _kUrlTermsOfUse =
    'https://sites.google.com/view/volleystratego/terms-of-use';
// ignore: unnecessary_nullable_for_final_variable_declarations
const String? _kEmailSupporto = 'volleystratego@gmail.com';
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

  // ID supporto = app user ID di RevenueCat (serve per assistenza e per i
  // granted entitlements agli amici, vedi docs/TODO_strada_A.md sez. 6).
  // Null finché non arriva (o se la SDK non è configurata): la riga mostra
  // "non disponibile" e il bottone Copia è spento.
  String? _idSupporto;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (!mounted) return;
      setState(() => _versione = '${info.version} (${info.buildNumber})');
    });
    Purchases.appUserID.then((id) {
      if (!mounted) return;
      setState(() => _idSupporto = id);
    }).catchError((_) {
      // SDK non configurata (es. piattaforma non supportata): resta null.
    });
  }

  Future<void> _apri(String url) async {
    final l = AppLocalizations.of(context);
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.aboutLinkNonApribile)),
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
    final l = AppLocalizations.of(context);
    final disponibile = url != null;
    return ListTile(
      leading: Icon(icona),
      title: Text(titolo),
      subtitle: disponibile ? null : Text(l.aboutInArrivo),
      enabled: disponibile,
      trailing: disponibile ? const Icon(Icons.open_in_new, size: 20) : null,
      onTap: disponibile ? () => _apri(url) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      // Stessa voce che apre questa pagina in SettingsScreen: una chiave sola.
      appBar: AppBar(title: Text(l.settingsAbout)),
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
                // Nome del prodotto: non si traduce.
                title: const Text('Volley Stratego'),
                subtitle: Text(
                  _versione.isEmpty
                      ? l.aboutVersioneCaricamento
                      : l.aboutVersione(_versione),
                ),
              ),
              const Divider(),
              _vocelink(
                icona: Icons.privacy_tip_outlined,
                titolo: l.aboutPrivacy,
                url: _kUrlPrivacyPolicy,
              ),
              _vocelink(
                icona: Icons.description_outlined,
                titolo: l.aboutTermini,
                url: _kUrlTermsOfUse,
              ),
              ListTile(
                leading: const Icon(Icons.mail_outline),
                title: Text(l.aboutSupporto),
                subtitle: Text(_kEmailSupporto ?? l.aboutInArrivo),
                enabled: _kEmailSupporto != null,
                onTap: _kEmailSupporto == null
                    ? null
                    : () => _apri('mailto:$_kEmailSupporto'),
              ),
              _vocelink(
                icona: Icons.subscriptions_outlined,
                titolo: l.aboutGestisciAbbonamento,
                url: _kUrlAbbonamenti,
              ),
              const Divider(),
              // Sempre visibile (anche quando "non disponibile"): è il dato
              // da chiedere all'utente in caso di assistenza.
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: Text(l.aboutIdSupporto),
                subtitle: Text(_idSupporto ?? l.aboutNonDisponibile),
                trailing: IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  tooltip: l.aboutCopia,
                  onPressed: _idSupporto == null
                      ? null
                      : () {
                          Clipboard.setData(ClipboardData(text: _idSupporto!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l.aboutIdCopiato)),
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

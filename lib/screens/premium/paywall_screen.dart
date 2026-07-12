import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../config/revenuecat.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Paywall (Strada A, vedi docs/TODO_strada_A.md): mostrata quando un utente
/// free tocca una feature premium. Carica l'offering corrente da RevenueCat,
/// mostra i pacchetti col prezzo dello store e permette acquisto/ripristino.
/// Nota: offerte e acquisti reali funzionano solo con l'app su una traccia
/// Play + license testers; in un build locale `getOfferings` può tornare
/// vuota (nessun pacchetto mostrato, il resto della pagina resta).
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  static const _vantaggi = [
    (Icons.groups, 'Squadre e partite illimitate',
        'Crea tutte le squadre e le partite che vuoi (versione free: una '
            'squadra e una partita).'),
    (Icons.gesture, 'Traiettorie di battuta e attacco',
        'Disegnale durante lo scout e rivedile filtrate per set, giocatore '
            'e rotazione.'),
    (Icons.dashboard, 'Lavagna tattica',
        'Disponi i ruoli in campo e disegna gli schemi durante il timeout.'),
    (Icons.picture_as_pdf, 'Report PDF completo',
        'Statistiche, traiettorie e formazioni da condividere o stampare.'),
    (Icons.table_view, 'Export CSV delle azioni',
        'Tutte le azioni della partita, pronte per Excel o Google Sheets.'),
  ];

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  Offering? _offering;
  bool _caricamento = true;
  bool _occupato = false; // acquisto o ripristino in corso

  @override
  void initState() {
    super.initState();
    _caricaOfferte();
  }

  Future<void> _caricaOfferte() async {
    try {
      final offerings = await Purchases.getOfferings();
      final off = offerings.current ?? offerings.all[kOfferingDefault];
      if (!mounted) return;
      setState(() {
        _offering = off;
        _caricamento = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _caricamento = false); // offerte non disponibili
    }
  }

  void _messaggio(String testo) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(testo)));
  }

  Future<void> _acquista(Package package) async {
    setState(() => _occupato = true);
    try {
      final info = await Purchases.purchasePackage(package);
      // Lo statoPremiumProvider si aggiorna da solo (listener SDK): qui basta
      // confermare e chiudere il paywall se l'entitlement è attivo.
      if (info.entitlements.active.containsKey(kEntitlementPremium)) {
        _messaggio('Grazie! Premium attivo.');
        if (mounted) Navigator.pop(context);
      }
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code != PurchasesErrorCode.purchaseCancelledError) {
        _messaggio('Acquisto non riuscito. Riprova.');
      }
    } finally {
      if (mounted) setState(() => _occupato = false);
    }
  }

  Future<void> _ripristina() async {
    setState(() => _occupato = true);
    try {
      final info = await Purchases.restorePurchases();
      if (info.entitlements.active.containsKey(kEntitlementPremium)) {
        _messaggio('Abbonamento ripristinato.');
        if (mounted) Navigator.pop(context);
      } else {
        _messaggio('Nessun abbonamento da ripristinare.');
      }
    } catch (_) {
      _messaggio('Ripristino non riuscito. Riprova.');
    } finally {
      if (mounted) setState(() => _occupato = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pacchetti = _offering?.availablePackages ?? const <Package>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Volley Stratego Premium')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const Icon(Icons.workspace_premium,
                  size: 64, color: AppColors.brandAccent),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Sblocca tutte le funzioni',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final (icona, titolo, descrizione) in PaywallScreen._vantaggi)
                Card(
                  child: ListTile(
                    leading: Icon(icona, color: AppColors.brandPrimary),
                    title: Text(titolo),
                    subtitle: Text(descrizione),
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              if (_caricamento)
                const Center(child: CircularProgressIndicator())
              else if (pacchetti.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Text(
                    'Offerte non disponibili al momento.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                )
              else
                for (final package in pacchetti)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: FilledButton(
                      onPressed: _occupato ? null : () => _acquista(package),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.sm),
                        child: Text(
                          'Abbonati — ${package.storeProduct.priceString}',
                        ),
                      ),
                    ),
                  ),
              const SizedBox(height: AppSpacing.sm),
              // Obbligatorio per gli store: chi ha già l'abbonamento su un
              // altro dispositivo deve poterlo riattivare da qui.
              TextButton(
                onPressed: _occupato ? null : _ripristina,
                child: const Text('Ripristina acquisti'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

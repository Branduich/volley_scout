import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../config/revenuecat.dart';
import '../../l10n/app_localizations.dart';
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

  // Non più `const`: i testi arrivano dalle localizzazioni, quindi servono il
  // context. Le icone restano qui, sono l'unica parte non traducibile.
  static List<(IconData, String, String)> _vantaggi(AppLocalizations l) => [
        (
          Icons.groups,
          l.paywallVantaggioSquadreTitolo,
          l.paywallVantaggioSquadreTesto
        ),
        (
          Icons.gesture,
          l.paywallVantaggioTraiettorieTitolo,
          l.paywallVantaggioTraiettorieTesto
        ),
        (
          Icons.dashboard,
          l.paywallVantaggioLavagnaTitolo,
          l.paywallVantaggioLavagnaTesto
        ),
        (
          Icons.picture_as_pdf,
          l.paywallVantaggioPdfTitolo,
          l.paywallVantaggioPdfTesto
        ),
        (
          Icons.table_view,
          l.paywallVantaggioCsvTitolo,
          l.paywallVantaggioCsvTesto
        ),
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
    final l = AppLocalizations.of(context);
    setState(() => _occupato = true);
    try {
      // Da RevenueCat v10 l'acquisto passa da purchase(PurchaseParams) e
      // ritorna un PurchaseResult (non più CustomerInfo, e purchasePackage è
      // deprecata): l'entitlement si legge da result.customerInfo.
      final result = await Purchases.purchase(PurchaseParams.package(package));
      // Lo statoPremiumProvider si aggiorna da solo (listener SDK): qui basta
      // confermare e chiudere il paywall se l'entitlement è attivo.
      if (result.customerInfo.entitlements.active
          .containsKey(kEntitlementPremium)) {
        _messaggio(l.paywallGrazie);
        if (mounted) Navigator.pop(context);
      }
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code != PurchasesErrorCode.purchaseCancelledError) {
        _messaggio(l.paywallAcquistoFallito);
      }
    } finally {
      if (mounted) setState(() => _occupato = false);
    }
  }

  Future<void> _ripristina() async {
    final l = AppLocalizations.of(context);
    setState(() => _occupato = true);
    try {
      final info = await Purchases.restorePurchases();
      if (info.entitlements.active.containsKey(kEntitlementPremium)) {
        _messaggio(l.paywallRipristinato);
        if (mounted) Navigator.pop(context);
      } else {
        _messaggio(l.paywallNienteDaRipristinare);
      }
    } catch (_) {
      _messaggio(l.paywallRipristinoFallito);
    } finally {
      if (mounted) setState(() => _occupato = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
                l.paywallTitolo,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final (icona, titolo, descrizione)
                  in PaywallScreen._vantaggi(l))
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
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Text(
                    l.paywallOfferteNonDisponibili,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54),
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
                          l.paywallAbbonati(package.storeProduct.priceString),
                        ),
                      ),
                    ),
                  ),
              const SizedBox(height: AppSpacing.sm),
              // Obbligatorio per gli store: chi ha già l'abbonamento su un
              // altro dispositivo deve poterlo riattivare da qui.
              TextButton(
                onPressed: _occupato ? null : _ripristina,
                child: Text(l.paywallRipristina),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

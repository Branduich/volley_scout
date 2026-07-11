import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Paywall (Strada A, vedi docs/TODO_strada_A.md): mostrata quando un
/// utente free tocca una feature premium. PLACEHOLDER in attesa di
/// RevenueCat: "Abbonati" e "Ripristina acquisti" mostrano solo uno
/// SnackBar — qui andranno acquisto e restore veri. La lista dei vantaggi
/// si estende man mano che si gatta altro (per ora: export PDF/CSV).
class PaywallScreen extends StatelessWidget {
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

  void _nonDisponibile(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Disponibile prossimamente')),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              for (final (icona, titolo, descrizione) in _vantaggi)
                Card(
                  child: ListTile(
                    leading: Icon(icona, color: AppColors.brandPrimary),
                    title: Text(titolo),
                    subtitle: Text(descrizione),
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () => _nonDisponibile(context),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Text('Abbonati'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // Obbligatorio per gli store: chi ha già l'abbonamento su un
              // altro dispositivo deve poterlo riattivare da qui.
              TextButton(
                onPressed: () => _nonDisponibile(context),
                child: const Text('Ripristina acquisti'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

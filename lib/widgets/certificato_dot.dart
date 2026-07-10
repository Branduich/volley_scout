import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Colore del pallino di stato del certificato medico.
///
/// `null` se la scadenza non è impostata (nessun pallino); rosso se mancano
/// meno di 8 giorni (compreso un certificato già scaduto); giallo se ne
/// mancano meno di 30; verde altrimenti. Il confronto è per data pura
/// (mezzanotte), l'ora del giorno non conta. [oggi] è parametrizzabile solo
/// per i test.
Color? coloreScadenzaCertificato(DateTime? scadenza, {DateTime? oggi}) {
  if (scadenza == null) return null;
  final adesso = oggi ?? DateTime.now();
  final giorni = DateTime(scadenza.year, scadenza.month, scadenza.day)
      .difference(DateTime(adesso.year, adesso.month, adesso.day))
      .inDays;
  if (giorni < 8) return Colors.red;
  if (giorni < 30) return AppColors.warning;
  return AppColors.success;
}

/// Pallino 14×14 di stato del certificato medico, con gap destro di 8px.
/// Non occupa spazio se la scadenza non è impostata — si può mettere sempre
/// come primo figlio del trailing di una ListTile senza condizioni.
class CertificatoDot extends StatelessWidget {
  const CertificatoDot({super.key, required this.scadenza});

  final DateTime? scadenza;

  @override
  Widget build(BuildContext context) {
    final colore = coloreScadenzaCertificato(scadenza);
    if (colore == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(color: colore, shape: BoxShape.circle),
      ),
    );
  }
}

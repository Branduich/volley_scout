import 'package:flutter/material.dart';
import 'package:volley_stats/volley_stats.dart';

/// Una tessera della riga KPI: un numero grande con la sua etichetta.
class Kpi {
  const Kpi(this.etichetta, this.valore, {this.dettaglio});
  final String etichetta;
  final String valore;
  final String? dettaglio;
}

/// Formatta una percentuale che può non esistere: `—` quando non ci sono
/// azioni. Il package di logica torna `null` apposta, per non far passare
/// "nessun dato" per uno zero (vedi stat_fondamentali).
String pct(double? valore) =>
    valore == null ? '—' : '${valore.round()}%';

/// I KPI di squadra da un riepilogo di stagione. Sta qui e non nel guscio
/// perché è la stessa riga che servirà alla pagina dentro l'app.
List<Kpi> kpiDaRiepilogo(RiepilogoStagione r) => [
      Kpi('Partite', '${r.partite}',
          dettaglio: '${r.partiteVinte}V - ${r.partitePerse}P'),
      Kpi('Set', '${r.setVinti}-${r.setPersi}'),
      Kpi('Efficienza attacco', pct(r.efficienzaAttacco)),
      Kpi('Punti', '${r.punti}'),
      Kpi('Errori', '${r.errori}'),
      Kpi('Ace', pct(r.percentualeAce)),
      Kpi('Ricezione perfetta', pct(r.ricezionePerfetta)),
    ];

/// La riga KPI. Va a capo da sola quando lo spazio non basta: la dashboard si
/// guarda su schermo grande, ma deve reggere anche il tablet con cui si è
/// scoutato (vedi docs/dati-stagionali.md).
class KpiRiga extends StatelessWidget {
  const KpiRiga({super.key, required this.kpi});

  final List<Kpi> kpi;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [for (final k in kpi) _KpiCard(kpi: k)],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.kpi});

  final Kpi kpi;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Container(
      width: 170,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tema.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            kpi.etichetta.toUpperCase(),
            style: tema.textTheme.labelSmall?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(kpi.valore, style: tema.textTheme.headlineMedium),
          if (kpi.dettaglio != null) ...[
            const SizedBox(height: 2),
            Text(
              kpi.dettaglio!,
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

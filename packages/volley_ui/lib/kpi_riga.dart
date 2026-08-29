import 'package:flutter/material.dart';
import 'package:volley_stats/volley_stats.dart';

/// Una tessera della riga KPI: un numero grande con la sua etichetta.
///
/// Il [dettaglio] è la riga piccola sotto al numero — il bilancio delle
/// partite, la formula di una percentuale. È opzionale nel dato ma **non**
/// nel disegno: la card lo tiene comunque a posto (vedi [_KpiCard]).
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
///
/// **L'ordine è quello in cui un allenatore li chiede**, non quello in cui
/// erano pronti i calcoli: prima cosa è successo (partite, set), poi come
/// (punti ed errori, i due totali grezzi), poi le percentuali per fondamentale.
List<Kpi> kpiDaRiepilogo(RiepilogoStagione r) => [
      Kpi('Partite', '${r.partite}',
          dettaglio: '${r.partiteVinte}V - ${r.partitePerse}P'),
      Kpi('Set', '${r.setVinti}-${r.setPersi}'),
      Kpi('Punti', '${r.punti}'),
      Kpi('Errori', '${r.errori}'),
      Kpi('Ace', pct(r.percentualeAce)),
      // Le formule sono le stesse stringhe delle card del report nell'app
      // (`reportFormulaEfficienza`/`reportFormulaPositivita`), senza il
      // `× 100` che il segno di percentuale sopra dice già: due numeri con lo
      // stesso nome devono essere lo stesso numero, anche nella definizione.
      Kpi('Efficienza attacco', pct(r.efficienzaAttacco),
          dettaglio: '(# − =) / totale'),
      Kpi('Positività ricezione', pct(r.positivitaRicezione),
          dettaglio: '(# + +) / totale'),
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
      // Larga quanto serve all'etichetta più lunga (POSITIVITÀ RICEZIONE) su
      // una riga sola: se si accorcia, quella va a capo e la card cresce di
      // una riga rispetto alle altre — cioè il difetto che si è appena tolto.
      width: 190,
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(kpi.valore, style: tema.textTheme.headlineMedium),
          const SizedBox(height: 2),
          // La riga del dettaglio c'è SEMPRE, vuota quando non serve: è così
          // che le card restano tutte alte uguali senza imporre un'altezza in
          // pixel, che si sfascerebbe al primo cambio di font. Una stringa
          // vuota occupa comunque la sua riga di testo.
          Text(
            kpi.dettaglio ?? '',
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

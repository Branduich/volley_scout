import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:volley_stats/volley_stats.dart';

import 'menu_compatto.dart';

/// Quanto spazio prende la colonna delle percentuali a sinistra del grafico.
///
/// **La stessa costante serve alla striscia del volume**, che sta sotto e deve
/// cominciare esattamente dove comincia l'area disegnata: due valori scritti a
/// mano si disallineerebbero al primo ritocco.
const double _kAssiSinistra = 44;

/// I segmenti continui di una serie: le partite senza quel fondamentale
/// spezzano la linea invece di essere attraversate.
///
/// Sta fuori dal widget perché è logica: "non ha ricevuto in quella partita"
/// non deve diventare un tratto di linea che scende e risale, che a occhio si
/// legge come un calo di rendimento mai avvenuto.
List<List<({int indice, double valore})>> segmentiSerie(
  List<PuntoTendenza> punti,
) {
  final segmenti = <List<({int indice, double valore})>>[];
  var corrente = <({int indice, double valore})>[];
  for (var i = 0; i < punti.length; i++) {
    final v = punti[i].valore;
    if (v == null) {
      if (corrente.isNotEmpty) segmenti.add(corrente);
      corrente = [];
      continue;
    }
    corrente.add((indice: i, valore: v));
  }
  if (corrente.isNotEmpty) segmenti.add(corrente);
  return segmenti;
}

/// Il grafico di tendenza di una giocatrice: un punto per partita, la retta dei
/// minimi quadrati e la striscia del volume sotto.
///
/// **Non calcola niente**: riceve i punti già pronti da `serieTendenza` e due
/// callback per i selettori, come tutti i widget di questo package.
class GraficoTendenza extends StatelessWidget {
  const GraficoTendenza({
    super.key,
    required this.punti,
    required this.giocatrici,
    required this.giocatriceUid,
    required this.misura,
    required this.onGiocatrice,
    required this.onMisura,
  });

  final List<PuntoTendenza> punti;

  /// Le giocatrici fra cui scegliere, già ordinate da chi ospita il widget.
  final List<GiocatoreBackup> giocatrici;
  final String? giocatriceUid;
  final MisuraTendenza misura;
  final ValueChanged<String?> onGiocatrice;
  final ValueChanged<MisuraTendenza> onMisura;

  static String etichettaMisura(MisuraTendenza m) => switch (m) {
        MisuraTendenza.efficienzaAttacco => 'Attacco — efficienza',
        MisuraTendenza.efficienzaBattuta => 'Battuta — efficienza',
        MisuraTendenza.efficienzaMuro => 'Muro — efficienza',
        MisuraTendenza.positivitaRicezione => 'Ricezione — positività',
        MisuraTendenza.positivitaDifesa => 'Difesa — positività',
      };

  /// Come si legge una pendenza, in parole.
  ///
  /// Sotto mezzo punto percentuale a partita si dice **stabile**: su cinque
  /// partite è un movimento di due punti in tutto, che sta dentro il rumore di
  /// una partita giocata bene o male. Chiamarlo "in crescita" sarebbe leggere
  /// il caso come un progresso.
  static String descrizioneTendenza(double pendenza) {
    if (pendenza.abs() < 0.5) return 'Stabile';
    final segno = pendenza > 0 ? '+' : '−';
    final valore = pendenza.abs().toStringAsFixed(1).replaceAll('.', ',');
    return '${pendenza > 0 ? 'In crescita' : 'In calo'}: '
        '$segno$valore punti a partita';
  }

  static String _data(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}';

  static String _avversario(PartitaBackup p) {
    final a = (p.avversario ?? '').trim();
    return a.isEmpty ? p.nome : a;
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final conValore = [
      for (final p in punti)
        if (p.valore != null) p,
    ];
    final retta = rettaTendenza(punti);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            MenuCompatto<String?>(
              etichetta: 'Atleta',
              valore: giocatriceUid,
              larghezza: 250,
              voci: [
                for (final g in giocatrici)
                  DropdownMenuItem(
                    value: g.uid,
                    child: Text('${g.numero}  ${g.cognome}',
                        overflow: TextOverflow.ellipsis),
                  ),
              ],
              onCambia: onGiocatrice,
            ),
            MenuCompatto<MisuraTendenza>(
              etichetta: 'Misura',
              valore: misura,
              larghezza: 250,
              voci: [
                for (final m in MisuraTendenza.values)
                  DropdownMenuItem(value: m, child: Text(etichettaMisura(m))),
              ],
              onCambia: (v) => v == null ? null : onMisura(v),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (conValore.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(
              'Nessuna azione di questo fondamentale nel periodo.',
              style: tema.textTheme.titleMedium,
            ),
          )
        else ...[
          _RigaTendenza(retta: retta, punti: punti),
          const SizedBox(height: 12),
          SizedBox(height: 260, child: _grafico(context, retta)),
          const SizedBox(height: 8),
          _StrisciaVolume(punti: punti),
        ],
      ],
    );
  }

  Widget _grafico(
    BuildContext context,
    ({double intercetta, double pendenza})? retta,
  ) {
    final colori = Theme.of(context).colorScheme;
    final valori = [
      for (final p in punti)
        if (p.valore != null) p.valore!,
    ];
    // Un po' di aria sopra e sotto, ma senza uscire dal significato: una
    // percentuale non va oltre ±100.
    var minimo = valori.reduce((a, b) => a < b ? a : b);
    var massimo = valori.reduce((a, b) => a > b ? a : b);
    if (retta != null) {
      for (final x in [0, punti.length - 1]) {
        final y = retta.intercetta + retta.pendenza * x;
        if (y < minimo) minimo = y;
        if (y > massimo) massimo = y;
      }
    }
    final margine = ((massimo - minimo) * 0.15).clamp(5.0, 25.0);
    final minY = (minimo - margine).clamp(-100.0, 100.0);
    final maxY = (massimo + margine).clamp(-100.0, 100.0);

    return LineChart(
      LineChartData(
        minX: -0.3,
        maxX: punti.length - 0.7,
        minY: minY,
        maxY: maxY == minY ? minY + 1 : maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: colori.outlineVariant, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: _kAssiSinistra,
              getTitlesWidget: (valore, meta) => Text(
                '${valore.round()}%',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (valore, meta) {
                final i = valore.round();
                if (i < 0 || i >= punti.length || (valore - i).abs() > 0.01) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _data(punti[i].partita.dataOra),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (toccati) => [
              for (final t in toccati)
                // La retta non ha niente da raccontare punto per punto: il suo
                // messaggio è la frase sopra il grafico.
                if (t.barIndex >= _indiceRetta(retta))
                  null
                else
                  LineTooltipItem(
                    '${_data(punti[t.x.round()].partita.dataOra)} · '
                    '${_avversario(punti[t.x.round()].partita)}\n'
                    '${t.y.round()}%  '
                    '(${punti[t.x.round()].azioni} azioni)',
                    TextStyle(color: colori.onInverseSurface, fontSize: 12),
                  ),
            ],
          ),
        ),
        lineBarsData: [
          for (final segmento in segmentiSerie(punti))
            LineChartBarData(
              spots: [
                for (final p in segmento) FlSpot(p.indice.toDouble(), p.valore),
              ],
              isCurved: false,
              color: colori.primary,
              barWidth: 3,
              dotData: const FlDotData(show: true),
            ),
          if (retta != null)
            LineChartBarData(
              spots: [
                FlSpot(0, retta.intercetta),
                FlSpot(
                  punti.length - 1,
                  retta.intercetta + retta.pendenza * (punti.length - 1),
                ),
              ],
              isCurved: false,
              color: colori.tertiary,
              barWidth: 2,
              dashArray: const [6, 5],
              dotData: const FlDotData(show: false),
            ),
        ],
      ),
    );
  }

  /// Da quale barra in poi si sta guardando la retta e non più i dati.
  int _indiceRetta(({double intercetta, double pendenza})? retta) =>
      retta == null ? 1 << 30 : segmentiSerie(punti).length;
}

/// La frase sopra il grafico: cosa dice la retta, o perché non c'è.
class _RigaTendenza extends StatelessWidget {
  const _RigaTendenza({required this.retta, required this.punti});

  final ({double intercetta, double pendenza})? retta;
  final List<PuntoTendenza> punti;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    if (retta == null) {
      // Dire PERCHÉ manca, non solo che manca: chi legge deve sapere se gli
      // basta allargare il periodo o se quella giocatrice gioca troppo poco.
      return Row(
        children: [
          Icon(Icons.info_outline,
              size: 18, color: tema.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Tendenza non calcolata: servono almeno $kMinimoPuntiTendenza '
              'partite con almeno $kMinimoAzioniTendenza azioni ciascuna.',
              style: tema.textTheme.bodySmall
                  ?.copyWith(color: tema.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Container(
          width: 18,
          height: 3,
          color: tema.colorScheme.tertiary,
        ),
        const SizedBox(width: 8),
        // Flexible come nell'altro ramo: "In crescita: +20,0 punti a partita"
        // su un telefono in verticale non ci sta, e senza questo la riga
        // sbordava di una settantina di pixel. Lo si è visto solo quando la
        // stagione demo è passata da una partita a cinque — con una sola, la
        // tendenza non si calcola e questo ramo non veniva mai disegnato.
        Flexible(
          child: Text(
            GraficoTendenza.descrizioneTendenza(retta!.pendenza),
            style: tema.textTheme.titleSmall,
          ),
        ),
      ],
    );
  }
}

/// Quante azioni ci sono dietro ogni punto.
///
/// Senza, una percentuale su due palloni sembra grande quanto una su trenta —
/// ed è il modo più facile di leggere un grafico al contrario.
class _StrisciaVolume extends StatelessWidget {
  const _StrisciaVolume({required this.punti});

  final List<PuntoTendenza> punti;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final massimo =
        punti.fold<int>(0, (a, p) => p.azioni > a ? p.azioni : a);
    return Padding(
      // Stesso rientro dell'asse: le barrette stanno sotto i loro punti.
      padding: const EdgeInsets.only(left: _kAssiSinistra),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 34,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final p in punti)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('${p.azioni}',
                            style: tema.textTheme.labelSmall),
                        const SizedBox(height: 2),
                        Container(
                          height: massimo == 0
                              ? 1
                              : (p.azioni / massimo * 16).clamp(1, 16),
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: tema.colorScheme.secondary
                                .withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Azioni per partita',
            style: tema.textTheme.labelSmall
                ?.copyWith(color: tema.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

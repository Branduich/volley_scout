import 'package:flutter/material.dart';
import 'package:volley_stats/volley_stats.dart';

import 'calendario_periodo.dart';
import 'menu_compatto.dart';

/// La barra filtri, comune a tutte le viste della dashboard.
///
/// **Non filtra nulla**: costruisce un [Filtro] e lo consegna a chi la ospita,
/// che lo passa alle funzioni di `volley_stats`. È la stessa separazione per cui
/// "solo in casa, set 1" si verifica con un test invece che a occhio.
///
/// La **giocatrice non è qui**: è una *selezione* (di chi guardi la scheda), non
/// un filtro (quali dati entrano nei conti). Sta nella lista laterale.
class BarraFiltri extends StatelessWidget {
  const BarraFiltri({
    super.key,
    required this.filtro,
    required this.onCambia,
    this.squadre = const [],
    this.partite = const [],
  });

  final Filtro filtro;
  final ValueChanged<Filtro> onCambia;

  /// Il selettore squadra compare **solo con più di una squadra**: chi ne ha
  /// una sola non deve vedere un menu con una voce.
  final List<SquadraBackup> squadre;

  /// Tutte le partite del backup (non quelle già filtrate: servono a poter
  /// riallargare un periodo stretto). Servono al calendario del periodo
  /// personalizzato, che **colora i giorni in cui si è giocato**: gli altri
  /// restano scegliibili come sempre, ma così si vede da dove partire e dove
  /// finire invece di cercare a memoria in mesi tutti uguali.
  final List<PartitaBackup> partite;

  static String etichettaPeriodo(PeriodoPreset p) => switch (p) {
        PeriodoPreset.tuttaStagione => 'Tutta la stagione',
        PeriodoPreset.andata => 'Andata',
        PeriodoPreset.ritorno => 'Ritorno',
        PeriodoPreset.ultimeCinque => 'Ultime 5',
        PeriodoPreset.ultimoMese => 'Ultimo mese',
        PeriodoPreset.personalizzato => 'Personalizzato',
      };

  static String etichettaCampo(CampoPartita c) => switch (c) {
        CampoPartita.tutte => 'Casa e trasferta',
        CampoPartita.casa => 'Solo in casa',
        CampoPartita.trasferta => 'Solo in trasferta',
      };

  static String _data(DateTime d) =>
      '${_due(d.day)}/${_due(d.month)}/${d.year}';

  static String _due(int n) => n.toString().padLeft(2, '0');

  /// Apre il calendario e, se si conferma, consegna il periodo scelto.
  Future<void> _scegliPeriodo(
    BuildContext context,
    List<Giornata> giornate,
  ) async {
    final periodo = await mostraCalendarioPeriodo(
      context,
      giornate: giornate,
      da: filtro.da,
      a: filtro.a,
    );
    if (periodo == null) return;
    onCambia(filtro.copiaCon(
      periodo: PeriodoPreset.personalizzato,
      da: periodo.start,
      a: periodo.end,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final giornate = giornateDi(partite, squadraUid: filtro.squadraUid);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (squadre.length > 1)
          MenuCompatto<String?>(
            etichetta: 'Squadra',
            valore: filtro.squadraUid,
            voci: [
              const DropdownMenuItem(value: null, child: Text('Tutte')),
              for (final s in squadre)
                DropdownMenuItem(value: s.uid, child: Text(s.nome)),
            ],
            onCambia: (v) => onCambia(v == null
                ? filtro.copiaCon(azzeraSquadra: true)
                : filtro.copiaCon(squadraUid: v)),
          ),
        MenuCompatto<PeriodoPreset>(
          etichetta: 'Periodo',
          valore: filtro.periodo,
          voci: [
            for (final p in PeriodoPreset.values)
              DropdownMenuItem(value: p, child: Text(etichettaPeriodo(p))),
          ],
          onCambia: (v) {
            if (v == null) return;
            if (v == PeriodoPreset.personalizzato) {
              _scegliPeriodo(context, giornate);
              return;
            }
            // Cambiando preset l'intervallo si azzera: lasciarlo lì farebbe
            // riapparire date vecchie al prossimo "Personalizzato".
            onCambia(filtro.copiaCon(periodo: v, azzeraIntervallo: true));
          },
        ),
        if (filtro.periodo == PeriodoPreset.personalizzato)
          ActionChip(
            avatar: const Icon(Icons.date_range, size: 18),
            label: Text(filtro.da == null || filtro.a == null
                ? 'Scegli le date'
                : '${_data(filtro.da!)} – ${_data(filtro.a!)}'),
            onPressed: () => _scegliPeriodo(context, giornate),
          ),
        MenuCompatto<CampoPartita>(
          etichetta: 'Campo',
          valore: filtro.campo,
          voci: [
            for (final c in CampoPartita.values)
              DropdownMenuItem(value: c, child: Text(etichettaCampo(c))),
          ],
          onCambia: (v) => v == null ? null : onCambia(filtro.copiaCon(campo: v)),
        ),
        MenuCompatto<int?>(
          etichetta: 'Set',
          valore: filtro.set,
          voci: [
            const DropdownMenuItem(value: null, child: Text('Tutti')),
            for (var n = 1; n <= 5; n++)
              DropdownMenuItem(value: n, child: Text('Set $n')),
          ],
          onCambia: (v) => onCambia(v == null
              ? filtro.copiaCon(azzeraSet: true)
              : filtro.copiaCon(set: v)),
        ),
        if (filtro.attivo)
          TextButton.icon(
            onPressed: () => onCambia(Filtro(squadraUid: filtro.squadraUid)),
            icon: const Icon(Icons.filter_alt_off, size: 18),
            label: const Text('Azzera filtri'),
          ),
      ],
    );
  }
}


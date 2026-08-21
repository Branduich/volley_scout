import 'package:flutter/material.dart';
import 'package:volley_stats/volley_stats.dart';

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
  });

  final Filtro filtro;
  final ValueChanged<Filtro> onCambia;

  /// Il selettore squadra compare **solo con più di una squadra**: chi ne ha
  /// una sola non deve vedere un menu con una voce.
  final List<SquadraBackup> squadre;

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
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _scegliIntervallo(BuildContext context) async {
    final oggi = DateTime.now();
    final intervallo = await showDateRangePicker(
      context: context,
      firstDate: DateTime(oggi.year - 5),
      lastDate: DateTime(oggi.year + 1),
      initialDateRange: filtro.da != null && filtro.a != null
          ? DateTimeRange(start: filtro.da!, end: filtro.a!)
          : null,
    );
    if (intervallo == null) return;
    onCambia(filtro.copiaCon(
      periodo: PeriodoPreset.personalizzato,
      da: intervallo.start,
      a: intervallo.end,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (squadre.length > 1)
          _Menu<String?>(
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
        _Menu<PeriodoPreset>(
          etichetta: 'Periodo',
          valore: filtro.periodo,
          voci: [
            for (final p in PeriodoPreset.values)
              DropdownMenuItem(value: p, child: Text(etichettaPeriodo(p))),
          ],
          onCambia: (v) {
            if (v == null) return;
            if (v == PeriodoPreset.personalizzato) {
              _scegliIntervallo(context);
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
            onPressed: () => _scegliIntervallo(context),
          ),
        _Menu<CampoPartita>(
          etichetta: 'Campo',
          valore: filtro.campo,
          voci: [
            for (final c in CampoPartita.values)
              DropdownMenuItem(value: c, child: Text(etichettaCampo(c))),
          ],
          onCambia: (v) => v == null ? null : onCambia(filtro.copiaCon(campo: v)),
        ),
        _Menu<int?>(
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

class _Menu<T> extends StatelessWidget {
  const _Menu({
    required this.etichetta,
    required this.valore,
    required this.voci,
    required this.onCambia,
  });

  final String etichetta;
  final T valore;
  final List<DropdownMenuItem<T>> voci;
  final ValueChanged<T?> onCambia;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: DropdownButtonFormField<T>(
        initialValue: valore,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: etichetta,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: voci,
        onChanged: onCambia,
      ),
    );
  }
}

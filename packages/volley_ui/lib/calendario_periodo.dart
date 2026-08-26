/// Il calendario del periodo personalizzato: mesi in fila, **tutti i giorni
/// selezionabili**, e i giorni in cui si è giocato colorati.
///
/// È scritto a mano invece di usare `showDateRangePicker` per un motivo solo:
/// il picker di Flutter non espone nessun gancio per decorare una singola
/// casella (colora solo selezione, "oggi" e disabilitati). L'unico modo per
/// distinguere i giorni con partita sarebbe stato **disabilitare** gli altri —
/// che li nasconde invece di evidenziarli, e toglie libertà a chi sceglie.
library;

import 'package:flutter/material.dart';
import 'package:volley_stats/volley_stats.dart';

/// Il colore dei giorni con partita: l'ambra dell'app (`AppColors.brandAccent`),
/// ricopiata qui perché questo package non dipende dal tema dell'app.
const Color kColoreGiornoConPartita = Color(0xFFF59E0B);

const _kMesi = [
  'Gennaio',
  'Febbraio',
  'Marzo',
  'Aprile',
  'Maggio',
  'Giugno',
  'Luglio',
  'Agosto',
  'Settembre',
  'Ottobre',
  'Novembre',
  'Dicembre',
];

const _kGiorni = ['L', 'M', 'M', 'G', 'V', 'S', 'D'];

/// Il primo giorno di ogni mese fra due date, estremi compresi.
///
/// Serve a mostrare **tutti i mesi** della stagione, anche quelli vuoti: le
/// soste fanno parte del calendario, e saltarle renderebbe illeggibile la
/// distanza fra due partite.
List<DateTime> mesiTra(DateTime primo, DateTime ultimo) {
  final mesi = <DateTime>[];
  var m = DateTime(primo.year, primo.month);
  final fine = DateTime(ultimo.year, ultimo.month);
  while (!m.isAfter(fine)) {
    mesi.add(m);
    m = DateTime(m.year, m.month + 1);
  }
  return mesi;
}

/// Le caselle di una griglia mensile, da lunedì: `null` = casella vuota prima
/// del giorno 1.
List<DateTime?> caselleMese(DateTime mese) {
  final primo = DateTime(mese.year, mese.month);
  final quanti = DateTime(mese.year, mese.month + 1, 0).day;
  return [
    for (var i = 1; i < primo.weekday; i++) null,
    for (var g = 1; g <= quanti; g++) DateTime(mese.year, mese.month, g),
  ];
}

/// Dove cade un giorno rispetto al periodo che si sta scegliendo.
enum PosizioneGiorno {
  /// Fuori dal periodo.
  fuori,

  /// Dentro il periodo, ma non uno dei due estremi.
  dentro,

  /// Un estremo del periodo (inizio o fine).
  estremo,
}

/// Sta fuori dal widget perché è **logica, non disegno**: così "il 30 giugno è
/// dentro il periodo" si verifica con un test invece che guardando i colori.
///
/// Con la sola data di inizio (primo tocco, fine non ancora scelta) l'unico
/// giorno evidenziato è quell'estremo.
PosizioneGiorno posizioneGiorno(DateTime giorno, DateTime? da, DateTime? a) {
  if (da == null) return PosizioneGiorno.fuori;
  final g = soloGiorno(giorno);
  final inizio = soloGiorno(da);
  final fine = a == null ? inizio : soloGiorno(a);
  if (g == inizio || g == fine) return PosizioneGiorno.estremo;
  if (g.isAfter(inizio) && g.isBefore(fine)) return PosizioneGiorno.dentro;
  return PosizioneGiorno.fuori;
}

/// Apre il calendario e restituisce il periodo scelto, oppure `null` se si
/// annulla.
Future<DateTimeRange?> mostraCalendarioPeriodo(
  BuildContext context, {
  required List<Giornata> giornate,
  DateTime? da,
  DateTime? a,
}) {
  return showDialog<DateTimeRange>(
    context: context,
    builder: (_) => CalendarioPeriodo(giornate: giornate, da: da, a: a),
  );
}

class CalendarioPeriodo extends StatefulWidget {
  const CalendarioPeriodo({
    super.key,
    required this.giornate,
    this.da,
    this.a,
    this.oggi,
  });

  /// I giorni in cui si è giocato: sono quelli che si colorano.
  final List<Giornata> giornate;

  /// Il periodo già scelto, da riproporre.
  final DateTime? da, a;

  /// Iniettabile dai test: senza, "oggi" è oggi.
  final DateTime? oggi;

  @override
  State<CalendarioPeriodo> createState() => _CalendarioPeriodoState();
}

class _CalendarioPeriodoState extends State<CalendarioPeriodo> {
  DateTime? _da;
  DateTime? _a;

  @override
  void initState() {
    super.initState();
    _da = widget.da == null ? null : soloGiorno(widget.da!);
    _a = widget.a == null ? null : soloGiorno(widget.a!);
  }

  /// Un tocco per volta: il primo apre un periodo nuovo, il secondo lo chiude.
  /// Toccare un giorno prima dell'inizio ricomincia da lì invece di rifiutare
  /// il tocco — è quello che fa anche il calendario di Material, e chi sbaglia
  /// l'ordine non deve annullare e riaprire.
  void _tocca(DateTime giorno) {
    setState(() {
      if (_da == null || _a != null || giorno.isBefore(_da!)) {
        _da = giorno;
        _a = null;
      } else {
        _a = giorno;
      }
    });
  }

  Map<DateTime, Giornata> get _perGiorno => {
        for (final g in widget.giornate) g.giorno: g,
      };

  @override
  Widget build(BuildContext context) {
    final giornateDelGiorno = _perGiorno;
    final oggi = soloGiorno(widget.oggi ?? DateTime.now());
    final mesi = widget.giornate.isEmpty
        ? mesiTra(DateTime(oggi.year, oggi.month - 6), oggi)
        : mesiTra(widget.giornate.first.giorno, widget.giornate.last.giorno);

    return AlertDialog(
      title: const Text('Scegli il periodo'),
      content: SizedBox(
        width: 340,
        height: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _da == null
                  ? 'Tocca il primo e l\'ultimo giorno del periodo'
                  : '${_data(_da!)} – ${_a == null ? '…' : _data(_a!)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const _Legenda(),
            const Divider(),
            Row(
              children: [
                for (final g in _kGiorni)
                  Expanded(
                    child: Center(
                      child: Text(
                        g,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: ListView.builder(
                itemCount: mesi.length,
                itemBuilder: (context, i) => _Mese(
                  mese: mesi[i],
                  giornate: giornateDelGiorno,
                  oggi: oggi,
                  da: _da,
                  a: _a,
                  onTocca: _tocca,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          // Con il solo inizio scelto il periodo è quel giorno lì: chi vuole
          // una partita sola non deve toccarla due volte.
          onPressed: _da == null
              ? null
              : () => Navigator.of(context).pop(
                    DateTimeRange(start: _da!, end: _a ?? _da!),
                  ),
          child: const Text('Applica'),
        ),
      ],
    );
  }

  static String _data(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _Legenda extends StatelessWidget {
  const _Legenda();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: const BoxDecoration(
            color: kColoreGiornoConPartita,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'giorno con partita',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _Mese extends StatelessWidget {
  const _Mese({
    required this.mese,
    required this.giornate,
    required this.oggi,
    required this.da,
    required this.a,
    required this.onTocca,
  });

  final DateTime mese;
  final Map<DateTime, Giornata> giornate;
  final DateTime oggi;
  final DateTime? da, a;
  final ValueChanged<DateTime> onTocca;

  @override
  Widget build(BuildContext context) {
    final caselle = caselleMese(mese);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '${_kMesi[mese.month - 1]} ${mese.year}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final giorno in caselle)
              if (giorno == null)
                const SizedBox.shrink()
              else
                _Giorno(
                  giorno: giorno,
                  giornata: giornate[giorno],
                  oggi: oggi,
                  posizione: posizioneGiorno(giorno, da, a),
                  onTocca: onTocca,
                ),
          ],
        ),
      ],
    );
  }
}

class _Giorno extends StatelessWidget {
  const _Giorno({
    required this.giorno,
    required this.giornata,
    required this.oggi,
    required this.posizione,
    required this.onTocca,
  });

  final DateTime giorno;
  final Giornata? giornata;
  final DateTime oggi;
  final PosizioneGiorno posizione;
  final ValueChanged<DateTime> onTocca;

  @override
  Widget build(BuildContext context) {
    final colori = Theme.of(context).colorScheme;
    final conPartita = giornata != null;
    final estremo = posizione == PosizioneGiorno.estremo;

    // Un estremo che è anche giorno di partita resta ambra nel bordo: la
    // selezione non deve cancellare l'informazione per cui il calendario è
    // colorato.
    final sfondo = estremo
        ? colori.primary
        : conPartita
            ? kColoreGiornoConPartita
            : null;
    final testo = estremo
        ? colori.onPrimary
        : conPartita
            ? Colors.black87
            : colori.onSurface;

    final cella = Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: sfondo,
        shape: BoxShape.circle,
        border: estremo && conPartita
            ? Border.all(color: kColoreGiornoConPartita, width: 2)
            : giorno == oggi && !estremo
                ? Border.all(color: colori.outline)
                : null,
      ),
      alignment: Alignment.center,
      child: Text(
        '${giorno.day}',
        style: TextStyle(
          color: testo,
          fontWeight: conPartita || estremo ? FontWeight.bold : null,
        ),
      ),
    );

    return InkWell(
      key: ValueKey('giorno-${giorno.toIso8601String().substring(0, 10)}'),
      onTap: () => onTocca(giorno),
      customBorder: const CircleBorder(),
      child: Container(
        // La fascia del periodo sta SOTTO il cerchio: si vede che i giorni
        // sono contigui, e i giorni con partita restano riconoscibili dentro
        // la selezione.
        decoration: BoxDecoration(
          color: posizione == PosizioneGiorno.fuori
              ? null
              : colori.primaryContainer,
        ),
        child: giornata == null
            ? cella
            : Tooltip(message: _tooltip(giornata!), child: cella),
      ),
    );
  }

  static String _tooltip(Giornata g) => [
        for (final p in g.partite)
          (p.avversario ?? '').trim().isEmpty ? p.nome : p.avversario!.trim(),
      ].join(', ');
}

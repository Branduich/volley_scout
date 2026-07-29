import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../logic/heatmap.dart';
import '../../models/enums.dart';
import '../../providers/database_provider.dart';
import '../../widgets/heatmap_court_view.dart';

const _kBg = Color(0xFF143E59);
const _kTopBarBg = Color(0xFF0D2738);

/// Heatmap della NOSTRA ricezione/difesa = punti d'arrivo nel nostro campo
/// delle azioni AVVERSARIE (battuta → ricezione, attacco → difesa). Vista
/// dedicata (come le traiettorie), aperta dai bottoni del report. Filtro per
/// set. Il `fondamentale` è quello AVVERSARIO (battuta/attacco) su cui filtrare.
class HeatmapReportScreen extends ConsumerStatefulWidget {
  final VolleyMatch match;
  final Fondamentale fondamentale; // battuta (→ricezione) | attacco (→difesa)

  const HeatmapReportScreen({
    super.key,
    required this.match,
    required this.fondamentale,
  });

  String get _titolo => fondamentale == Fondamentale.battuta
      ? 'Heatmap ricezione'
      : 'Heatmap difesa';

  @override
  ConsumerState<HeatmapReportScreen> createState() =>
      _HeatmapReportScreenState();
}

class _HeatmapReportScreenState extends ConsumerState<HeatmapReportScreen> {
  List<MatchSet> _sets = [];
  Map<int, List<ScoutAction>> _azioniPerSet = {};
  bool _loading = true;
  MatchSet? _setFiltro; // null = partita intera

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    final setRepo = ref.read(matchSetRepositoryProvider);
    final actionRepo = ref.read(scoutActionRepositoryProvider);
    final sets = await setRepo.caricaSetsPartita(widget.match.id);
    final azioniPerSet = <int, List<ScoutAction>>{};
    for (final s in sets) {
      azioniPerSet[s.id] = await actionRepo.caricaAzioni(s.id);
    }
    if (!mounted) return;
    setState(() {
      _sets = sets;
      _azioniPerSet = azioniPerSet;
      _loading = false;
    });
  }

  Iterable<ScoutAction> get _azioni => _setFiltro == null
      ? _azioniPerSet.values.expand((e) => e)
      : (_azioniPerSet[_setFiltro!.id] ?? const <ScoutAction>[]);

  @override
  Widget build(BuildContext context) {
    final punti = puntiArrivoAvversari(_azioni, widget.fondamentale);
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kTopBarBg,
        foregroundColor: Colors.white,
        title: Text(widget._titolo),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      const Text('Set:',
                          style: TextStyle(color: Colors.white, fontSize: 14)),
                      const SizedBox(width: 12),
                      DropdownButton<MatchSet?>(
                        value: _setFiltro,
                        dropdownColor: const Color(0xFF1E293B),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14),
                        iconEnabledColor: Colors.white,
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('Partita intera')),
                          for (final s in _sets)
                            DropdownMenuItem(
                                value: s, child: Text('Set ${s.numero}')),
                        ],
                        onChanged: (v) => setState(() => _setFiltro = v),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: HeatmapCourtView(
                    punti: punti,
                    specchia: true, // riflessa dalla nostra parte
                    footer: Text(
                      punti.isEmpty
                          ? 'Nessuna palla registrata'
                          : '${punti.length} palle',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

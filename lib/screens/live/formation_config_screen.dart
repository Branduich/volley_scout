import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../models/enums.dart';
import '../../widgets/court_view.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/enum_l10n.dart';
import 'scout_screen.dart';

const _kBg = Color(0xFF0F172A);

/// Risultato della modalità conferma (vedi `modalitaConferma`): la scelta
/// di palleggiatore e coppia cambi-libero, restituita al chiamante con un
/// pop invece di navigare avanti verso ScoutScreen.
typedef ConfigurazioneFormazione = ({
  String palleggiatoreSlot,
  Ruolo? ruoloCambiLibero,
});

class FormationConfigScreen extends StatefulWidget {
  final VolleyMatch match;
  final Team team;
  final Map<String, Player> assignments;

  /// Preselezioni esplicite (usate dal flusso di sostituzione con i valori
  /// EFFETTIVI correnti del set): se null, initState ricade sullo scan per
  /// ruolo come a inizio partita.
  final String? palleggiatoreSlotIniziale;
  final Ruolo? ruoloCambiLiberoIniziale;

  /// Modalità conferma (flusso di sostituzione): il bottone diventa
  /// "Conferma" e fa `Navigator.pop` con un [ConfigurazioneFormazione]
  /// invece di push verso ScoutScreen. Il flusso di inizio partita resta
  /// invariato col default false.
  final bool modalitaConferma;

  const FormationConfigScreen({
    super.key,
    required this.match,
    required this.team,
    required this.assignments,
    this.palleggiatoreSlotIniziale,
    this.ruoloCambiLiberoIniziale,
    this.modalitaConferma = false,
  });

  @override
  State<FormationConfigScreen> createState() => _FormationConfigScreenState();
}

class _FormationConfigScreenState extends State<FormationConfigScreen> {
  SistemaGioco _sistema = SistemaGioco.palleggiatoreUnico;
  // Slot dei palleggiatori designati: 1 nel 5-1, 2 nel 6-2. Nel 6-2 il
  // palleggiatore di RIFERIMENTO (P1) passato allo scout è quello con lo slot
  // più basso (coerente con MatchSetRepository.caricaFormazione).
  final Set<String> _palleggiatoriSlots = {};
  final Set<String> _centraliSlots = {};

  bool get _is62 => _sistema == SistemaGioco.doppioPalleggiatore;
  int get _numPalleggiatori => _is62 ? 2 : 1;

  @override
  void initState() {
    super.initState();
    _preselezionaPalleggiatori();
    // Coppia cambi-libero: preseleziona i giocatori col ruolo della coppia
    // effettiva se fornito, altrimenti i centrali come a inizio partita.
    // Solo slot P1..P6 (assignments contiene anche L1/L2) e mai il
    // palleggiatore designato. Prima i match esatti, poi si completa fino
    // a 2 con gli universali (Ruolo.undefined): possono coprire il membro
    // mancante di qualunque coppia.
    final ruoloCoppia = widget.ruoloCambiLiberoIniziale ?? Ruolo.centrale;
    bool selezionabile(MapEntry<String, Player> entry) =>
        !_palleggiatoriSlots.contains(entry.key) && entry.key.startsWith('P');
    for (final entry in widget.assignments.entries) {
      if (entry.value.ruolo == ruoloCoppia &&
          selezionabile(entry) &&
          _centraliSlots.length < 2) {
        _centraliSlots.add(entry.key);
      }
    }
    if (ruoloCoppia != Ruolo.undefined) {
      for (final entry in widget.assignments.entries) {
        if (entry.value.ruolo == Ruolo.undefined &&
            selezionabile(entry) &&
            _centraliSlots.length < 2) {
          _centraliSlots.add(entry.key);
        }
      }
    }
  }

  // Preseleziona i palleggiatori (1 nel 5-1, 2 nel 6-2). Rieseguita al cambio
  // di sistema di gioco dal dropdown.
  void _preselezionaPalleggiatori() {
    _palleggiatoriSlots.clear();
    // Preselezione esplicita (flusso sostituzione, solo 5-1) ha priorità.
    if (!_is62 &&
        widget.palleggiatoreSlotIniziale != null &&
        widget.assignments.containsKey(widget.palleggiatoreSlotIniziale)) {
      _palleggiatoriSlots.add(widget.palleggiatoreSlotIniziale!);
      return;
    }
    final slotP = [
      for (final entry in widget.assignments.entries)
        if (entry.value.ruolo == Ruolo.palleggiatore &&
            entry.key.startsWith('P'))
          entry.key,
    ]..sort();
    _palleggiatoriSlots.addAll(slotP.take(_numPalleggiatori));
  }

  bool get _hasLibero =>
      widget.assignments.containsKey('L1') ||
      widget.assignments.containsKey('L2');

  // Nel 6-2 il libero è sempre sui centrali (nessuna scelta di coppia), quindi
  // basta designare i palleggiatori.
  bool get _canConfirm =>
      _palleggiatoriSlots.length == _numPalleggiatori &&
      (!_hasLibero || _is62 || _centraliSlots.length == 2);

  void _onPalleggiatoreSlotTap(String slot) {
    setState(() {
      if (_palleggiatoriSlots.contains(slot)) {
        _palleggiatoriSlots.remove(slot);
      } else if (_palleggiatoriSlots.length < _numPalleggiatori) {
        _palleggiatoriSlots.add(slot);
        _centraliSlots.remove(slot); // non può essere anche cambio-libero
      } else if (_numPalleggiatori == 1) {
        // 5-1: sposta la selezione singola sul nuovo slot.
        _palleggiatoriSlots
          ..clear()
          ..add(slot);
        _centraliSlots.remove(slot);
      }
      // 6-2 con 2 già selezionati: tap su un terzo ignorato (deseleziona prima).
    });
  }

  void _onCentraleSlotTap(String slot) {
    final player = widget.assignments[slot];
    if (player == null || _palleggiatoriSlots.contains(slot)) return;
    final ruolo = player.ruolo;
    if (ruolo != Ruolo.centrale &&
        ruolo != Ruolo.schiacciatore &&
        ruolo != Ruolo.undefined) {
      return;
    }

    setState(() {
      if (_centraliSlots.contains(slot)) {
        _centraliSlots.clear();
      } else {
        _centraliSlots.clear();
        if (ruolo == Ruolo.undefined) {
          // Per undefined: pairing posizionale (i due che si alternano in
          // seconda linea sono sempre 3 posizioni di distanza nel ring).
          const opposites = {
            'P1': 'P4',
            'P4': 'P1',
            'P2': 'P5',
            'P5': 'P2',
            'P3': 'P6',
            'P6': 'P3',
          };
          _centraliSlots.add(slot);
          final opp = opposites[slot];
          if (opp != null &&
              widget.assignments.containsKey(opp) &&
              !_palleggiatoriSlots.contains(opp)) {
            _centraliSlots.add(opp);
          }
        } else {
          for (final e in widget.assignments.entries) {
            if (e.value.ruolo == ruolo &&
                !_palleggiatoriSlots.contains(e.key)) {
              _centraliSlots.add(e.key);
            }
          }
        }
      }
    });
  }

  // Ruolo EFFETTIVO della coppia cambi-libero selezionata: sempre
  // centrale|schiacciatore, mai undefined ("Universale") — le mappe di
  // attacco/difesa in ScoutScreen conoscono solo le due coppie canoniche.
  // Coppia mista universale+reale → il ruolo del reale; coppia di due
  // universali → il ruolo NON coperto dai reali in campo (2 schiacciatori
  // reali presenti → gli universali fanno i centrali, e viceversa);
  // ambiguità → centrale, coerente col trattamento storico di undefined.
  Ruolo? _ruoloCoppiaEffettivo() {
    if (!_hasLibero || _centraliSlots.isEmpty) return null;
    for (final slot in _centraliSlots) {
      final ruolo = widget.assignments[slot]?.ruolo;
      if (ruolo == Ruolo.centrale || ruolo == Ruolo.schiacciatore) {
        return ruolo;
      }
    }
    var schiacciatoriReali = 0;
    var centraliReali = 0;
    for (final entry in widget.assignments.entries) {
      if (!entry.key.startsWith('P')) continue;
      if (entry.value.ruolo == Ruolo.schiacciatore) schiacciatoriReali++;
      if (entry.value.ruolo == Ruolo.centrale) centraliReali++;
    }
    if (schiacciatoriReali >= 2 && centraliReali < 2) return Ruolo.centrale;
    if (centraliReali >= 2 && schiacciatoriReali < 2) {
      return Ruolo.schiacciatore;
    }
    return Ruolo.centrale;
  }

  void _onAvanti() {
    // Riferimento (P1 nel 6-2): slot col numero più basso tra i palleggiatori
    // designati — coerente con MatchSetRepository.caricaFormazione.
    final palleggiatoreRiferimento =
        (_palleggiatoriSlots.toList()..sort()).first;
    // Nel 6-2 il libero è sempre sui centrali; nel 5-1 dipende dalla coppia
    // selezionata (o i due centrali o i due schiacciatori, vedi
    // _onCentraleSlotTap).
    final ruoloCambiLibero = _is62
        ? (_hasLibero ? Ruolo.centrale : null)
        : _ruoloCoppiaEffettivo();
    if (widget.modalitaConferma) {
      // Flusso sostituzione: la scelta torna al chiamante (che scriverà
      // gli eventi di cambio) — nessuna navigazione avanti.
      Navigator.pop<ConfigurazioneFormazione>(context, (
        palleggiatoreSlot: palleggiatoreRiferimento,
        ruoloCambiLibero: ruoloCambiLibero,
      ));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScoutScreen(
          match: widget.match,
          team: widget.team,
          palleggiatoreSlot: palleggiatoreRiferimento,
          assignments: widget.assignments,
          ruoloCambiLibero: ruoloCambiLibero,
          sistemaGioco: _sistema,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        foregroundColor: Colors.white,
        title: Text('Configurazione formazione – ${widget.team.nome}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton(
              onPressed: _canConfirm ? _onAvanti : null,
              child: Text(
                widget.modalitaConferma ? 'Conferma' : 'Inizia scout',
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sistema di gioco — nascosto nel flusso di sostituzione (il
            // sistema non si cambia a set in corso).
            if (!widget.modalitaConferma) ...[
              Row(
                children: [
                  const Text(
                    'Sistema di gioco:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<SistemaGioco>(
                    value: _sistema,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    iconEnabledColor: Colors.white,
                    underline: Container(height: 1, color: Colors.white38),
                    items: SistemaGioco.values
                        .map(
                          (s) => DropdownMenuItem(
                              value: s,
                              child: Text(sistemaGiocoLabel(
                                  s, AppLocalizations.of(context)))),
                        )
                        .toList(),
                    onChanged: (v) => setState(() {
                      _sistema = v!;
                      _preselezionaPalleggiatori();
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            _buildCampi(),
          ],
        ),
      ),
    );
  }

  // I due campi (palleggiatore + cambi libero) sempre AFFIANCATI, ma alla
  // stessa "taglia" del campo della schermata di formazione (LineupScreen):
  // lì un campo occupa ~1/3 della larghezza schermo, quindi qui punto a
  // ~33% per campo invece di riempire la larghezza (che li rendeva troppo
  // grandi). Su tablet la scala è ~1 (campi a piena dimensione). Un solo
  // campo (senza libero) usa la stessa taglia.
  Widget _buildCampi() {
    final campoPalleggiatore = LabeledCourt(
      title: _is62 ? 'Palleggiatori' : 'Palleggiatore',
      subtitle: _is62
          ? 'Conferma i due palleggiatori – ${_palleggiatoriSlots.length}/2 selezionati'
          : 'Conferma il palleggiatore',
      subtitleColor: _is62 && _palleggiatoriSlots.length == 2
          ? Colors.lightBlue
          : Colors.white54,
      child: CourtView(
        assignments: widget.assignments,
        selectedSlots: _palleggiatoriSlots,
        selectionColor: Colors.red,
        onSlotTap: _onPalleggiatoreSlotTap,
      ),
    );
    // Nel 6-2 il campo "cambi del libero" è nascosto: il libero è sempre sui
    // centrali, nessuna scelta.
    final campoLibero = (!_hasLibero || _is62)
        ? null
        : LabeledCourt(
            title: 'Cambi del libero',
            subtitle:
                'Conferma i due cambi del libero – ${_centraliSlots.length}/2 selezionati',
            subtitleColor:
                _centraliSlots.length == 2 ? Colors.lightBlue : Colors.white54,
            child: CourtView(
              assignments: widget.assignments,
              selectedSlots: _centraliSlots,
              selectionColor: Colors.red,
              disabledSlots: {
                ..._palleggiatoriSlots,
                for (final e in widget.assignments.entries)
                  if (e.value.ruolo != Ruolo.centrale &&
                      e.value.ruolo != Ruolo.schiacciatore &&
                      e.value.ruolo != Ruolo.undefined)
                    e.key,
              },
              onSlotTap: _onCentraleSlotTap,
            ),
          );

    // Taglia target di un campo = ~33% della larghezza schermo (come in
    // LineupScreen), mai oltre il nativo 460. Il FittedBox scala l'intera
    // riga (nativa: 460, o 460+24+460=944 con due campi) a questa larghezza.
    final w = MediaQuery.of(context).size.width;
    final scala = ((w * 0.33) / 460).clamp(0.0, 1.0);
    final larghezzaNativa = campoLibero != null ? 944.0 : 460.0;
    return Center(
      child: SizedBox(
        width: larghezzaNativa * scala,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              campoPalleggiatore,
              if (campoLibero != null) ...[
                const SizedBox(width: 24),
                campoLibero,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

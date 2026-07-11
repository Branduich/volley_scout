import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../models/enums.dart';
import '../../widgets/court_view.dart';
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
  String? _palleggiatoreSlot;
  final Set<String> _centraliSlots = {};

  @override
  void initState() {
    super.initState();
    // Palleggiatore: preselezione esplicita (flusso sostituzione, valore
    // effettivo del set) o scan per ruolo (inizio partita).
    if (widget.palleggiatoreSlotIniziale != null &&
        widget.assignments.containsKey(widget.palleggiatoreSlotIniziale)) {
      _palleggiatoreSlot = widget.palleggiatoreSlotIniziale;
    } else {
      for (final entry in widget.assignments.entries) {
        if (entry.value.ruolo == Ruolo.palleggiatore &&
            _palleggiatoreSlot == null) {
          _palleggiatoreSlot = entry.key;
        }
      }
    }
    // Coppia cambi-libero: preseleziona i giocatori col ruolo della coppia
    // effettiva se fornito, altrimenti i centrali come a inizio partita.
    // Solo slot P1..P6 (assignments contiene anche L1/L2) e mai il
    // palleggiatore designato. Prima i match esatti, poi si completa fino
    // a 2 con gli universali (Ruolo.undefined): possono coprire il membro
    // mancante di qualunque coppia.
    final ruoloCoppia = widget.ruoloCambiLiberoIniziale ?? Ruolo.centrale;
    bool selezionabile(MapEntry<String, Player> entry) =>
        entry.key != _palleggiatoreSlot && entry.key.startsWith('P');
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

  bool get _hasLibero =>
      widget.assignments.containsKey('L1') ||
      widget.assignments.containsKey('L2');

  bool get _canConfirm =>
      _palleggiatoreSlot != null && (!_hasLibero || _centraliSlots.length == 2);

  void _onPalleggiatoreSlotTap(String slot) {
    setState(() {
      if (_palleggiatoreSlot == slot) {
        _palleggiatoreSlot = null;
      } else {
        _palleggiatoreSlot = slot;
        _centraliSlots.remove(
          slot,
        ); // un giocatore non può essere anche centrale
      }
    });
  }

  void _onCentraleSlotTap(String slot) {
    final player = widget.assignments[slot];
    if (player == null || slot == _palleggiatoreSlot) return;
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
              opp != _palleggiatoreSlot) {
            _centraliSlots.add(opp);
          }
        } else {
          for (final e in widget.assignments.entries) {
            if (e.value.ruolo == ruolo && e.key != _palleggiatoreSlot) {
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
    // Il libero sostituisce o i due centrali o i due schiacciatori (mai una
    // combinazione, vedi _onCentraleSlotTap).
    final ruoloCambiLibero = _ruoloCoppiaEffettivo();
    if (widget.modalitaConferma) {
      // Flusso sostituzione: la scelta torna al chiamante (che scriverà
      // gli eventi di cambio) — nessuna navigazione avanti.
      Navigator.pop<ConfigurazioneFormazione>(context, (
        palleggiatoreSlot: _palleggiatoreSlot!,
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
          palleggiatoreSlot: _palleggiatoreSlot!,
          assignments: widget.assignments,
          ruoloCambiLibero: ruoloCambiLibero,
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
            // Sistema di gioco
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
                        (s) => DropdownMenuItem(value: s, child: Text(s.label)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _sistema = v!),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Due campi affiancati a dimensioni fisse (460×460 come
            // LineupScreen), centrati. FittedBox(scaleDown): su schermi
            // stretti (smartphone) il blocco si rimpicciolisce in
            // proporzione invece di scrollare in orizzontale (sostituisce
            // il vecchio pattern SingleChildScrollView + ConstrainedBox);
            // su tablet scala = 1, identico a prima.
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LabeledCourt(
                      title: 'Palleggiatore',
                      subtitle: 'Conferma il palleggiatore',
                      subtitleColor: Colors.white54,
                      child: CourtView(
                        assignments: widget.assignments,
                        selectedSlots: _palleggiatoreSlot != null
                            ? {_palleggiatoreSlot!}
                            : {},
                        selectionColor: Colors.red,
                        onSlotTap: _onPalleggiatoreSlotTap,
                      ),
                    ),
                    if (_hasLibero) ...[
                      const SizedBox(width: 24),
                      LabeledCourt(
                        title: 'Cambi del libero',
                        subtitle:
                            'Conferma i due cambi del libero – ${_centraliSlots.length}/2 selezionati',
                        subtitleColor: _centraliSlots.length == 2
                            ? Colors.lightBlue
                            : Colors.white54,
                        child: CourtView(
                          assignments: widget.assignments,
                          selectedSlots: _centraliSlots,
                          selectionColor: Colors.red,
                          disabledSlots: {
                            ?_palleggiatoreSlot,
                            for (final e in widget.assignments.entries)
                              if (e.value.ruolo != Ruolo.centrale &&
                                  e.value.ruolo != Ruolo.schiacciatore &&
                                  e.value.ruolo != Ruolo.undefined)
                                e.key,
                          },
                          onSlotTap: _onCentraleSlotTap,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

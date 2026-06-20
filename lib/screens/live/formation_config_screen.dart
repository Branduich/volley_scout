import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../models/enums.dart';
import 'scout_screen.dart';

const _kBg = Color(0xFF0F172A);
const _kCourtImage = 'assets/images/court_bg.png';

class FormationConfigScreen extends StatefulWidget {
  final VolleyMatch match;
  final Team team;
  final Map<String, Player> assignments;

  const FormationConfigScreen({
    super.key,
    required this.match,
    required this.team,
    required this.assignments,
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
    // Pre-seleziona il palleggiatore e i centrali in base al ruolo assegnato
    for (final entry in widget.assignments.entries) {
      if (entry.value.ruolo == Ruolo.palleggiatore &&
          _palleggiatoreSlot == null) {
        _palleggiatoreSlot = entry.key;
      }
    }
    for (final entry in widget.assignments.entries) {
      if (entry.value.ruolo == Ruolo.centrale && _centraliSlots.length < 2) {
        _centraliSlots.add(entry.key);
      }
    }
  }

  bool get _hasLibero =>
      widget.assignments.containsKey('L1') ||
      widget.assignments.containsKey('L2');

  bool get _canConfirm =>
      _palleggiatoreSlot != null &&
      (!_hasLibero || _centraliSlots.length == 2);

  void _onPalleggiatoreSlotTap(String slot) {
    setState(() {
      if (_palleggiatoreSlot == slot) {
        _palleggiatoreSlot = null;
      } else {
        _palleggiatoreSlot = slot;
        _centraliSlots.remove(slot); // un giocatore non può essere anche centrale
      }
    });
  }

  void _onCentraleSlotTap(String slot) {
    final player = widget.assignments[slot];
    if (player == null || slot == _palleggiatoreSlot) return;
    final ruolo = player.ruolo;
    if (ruolo != Ruolo.centrale && ruolo != Ruolo.schiacciatore) return;

    setState(() {
      if (_centraliSlots.contains(slot)) {
        // Tap sulla coppia già selezionata → deseleziona tutta la coppia
        _centraliSlots.clear();
      } else {
        // Tap su ruolo diverso → seleziona tutta la coppia di quel ruolo
        _centraliSlots.clear();
        for (final e in widget.assignments.entries) {
          if (e.value.ruolo == ruolo && e.key != _palleggiatoreSlot) {
            _centraliSlots.add(e.key);
          }
        }
      }
    });
  }

  void _onAvanti() {
    // Il libero sostituisce o i due centrali o i due schiacciatori (mai una
    // combinazione, vedi _onCentraleSlotTap): basta leggere il ruolo di uno
    // dei due slot selezionati per sapere quale coppia ScoutScreen dovrà
    // sostituire ad ogni rotazione.
    final ruoloCambiLibero = _hasLibero && _centraliSlots.isNotEmpty
        ? widget.assignments[_centraliSlots.first]?.ruolo
        : null;
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
              child: const Text('Inizia scout'),
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
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s.label),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _sistema = v!),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Due campi affiancati a dimensioni fisse (460×460 come LineupScreen).
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width - 48,
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LabeledCourt(
                        title: 'Palleggiatore',
                        subtitle: 'Conferma il palleggiatore',
                        subtitleColor: Colors.white54,
                        child: _CourtView(
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
                        _LabeledCourt(
                          title: 'Cambi del libero',
                          subtitle:
                              'Conferma i due cambi del libero – ${_centraliSlots.length}/2 selezionati',
                          subtitleColor: _centraliSlots.length == 2
                              ? Colors.lightBlue
                              : Colors.white54,
                          child: _CourtView(
                            assignments: widget.assignments,
                            selectedSlots: _centraliSlots,
                            selectionColor: const Color(0xFF00008A),
                            disabledSlots: {
                              ?_palleggiatoreSlot,
                              for (final e in widget.assignments.entries)
                                if (e.value.ruolo != Ruolo.centrale &&
                                    e.value.ruolo != Ruolo.schiacciatore)
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
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widget etichetta + campo ─────────────────────────────────────────────────

class _LabeledCourt extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color subtitleColor;
  final Widget child;

  const _LabeledCourt({
    required this.title,
    required this.subtitle,
    required this.subtitleColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: subtitleColor),
        ),
        const SizedBox(height: 6),
        SizedBox(width: 460, height: 460, child: child),
      ],
    );
  }
}

// ── Visualizzazione campo (read-only o interattivo) ──────────────────────────

class _CourtView extends StatelessWidget {
  final Map<String, Player> assignments;
  final Set<String> selectedSlots;
  final Set<String> disabledSlots;
  final Color selectionColor;
  final void Function(String slot)? onSlotTap;

  const _CourtView({
    required this.assignments,
    this.selectedSlots = const {},
    this.disabledSlots = const {},
    this.selectionColor = Colors.amber,
    this.onSlotTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white, width: 2),
        borderRadius: BorderRadius.circular(8),
        image: const DecorationImage(
          image: AssetImage(_kCourtImage),
          fit: BoxFit.fill,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Column(
          children: [
            // Fila frontale (lato rete): P4 | P3 | P2
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildSlot('P4')),
                  Expanded(child: _buildSlot('P3')),
                  Expanded(child: _buildSlot('P2')),
                ],
              ),
            ),
            // Fila posteriore: P5 | P6 | P1
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildSlot('P5')),
                  Expanded(child: _buildSlot('P6')),
                  Expanded(child: _buildSlot('P1')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlot(String slot) {
    final player = assignments[slot];
    final isSelected = selectedSlots.contains(slot);
    final isDisabled = disabledSlots.contains(slot);
    final canTap = onSlotTap != null && player != null && !isDisabled;

    final card = Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 104),
      decoration: BoxDecoration(
        color: isDisabled
            ? Colors.grey.shade300
            : (player == null ? Colors.lightBlueAccent : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(color: selectionColor, width: 3)
            : null,
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: selectionColor.withAlpha(100),
                  blurRadius: 6,
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
      child: player == null ? _slotLabel(slot) : _slotPlayer(player, isDisabled),
    );

    if (canTap) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSlotTap!(slot),
        child: card,
      );
    }
    return card;
  }

  Widget _slotLabel(String slot) {
    return Center(
      child: Text(
        slot,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _slotPlayer(Player player, bool dimmed) {
    final color = dimmed ? Colors.black38 : Colors.black87;
    final subColor = dimmed ? Colors.black26 : Colors.black54;
    const nameStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      height: 1.0,
    );
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            '${player.numero}',
            style: TextStyle(
              fontSize: 31,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Text(
              '${player.cognome} ${player.nome}',
              style: nameStyle.copyWith(color: subColor),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Text(
              player.ruolo.label,
              style: nameStyle.copyWith(
                  color: subColor, fontWeight: FontWeight.normal),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

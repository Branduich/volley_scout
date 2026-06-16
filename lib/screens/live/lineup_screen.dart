import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../providers/database_provider.dart';
import '../../theme/app_colors.dart';
import '../teams/player_form_screen.dart';
import 'scout_screen.dart';

const _kBg = Color(0xFF0F172A); // dark navy background
const _kCourtImage = 'assets/images/court_bg.png';

// Counter-clockwise selection order
const _kCourtOrder = ['P1', 'P2', 'P3', 'P4', 'P5', 'P6'];

class LineupScreen extends ConsumerStatefulWidget {
  final VolleyMatch match;
  final Team team;

  const LineupScreen({super.key, required this.match, required this.team});

  @override
  ConsumerState<LineupScreen> createState() => _LineupScreenState();
}

class _LineupScreenState extends ConsumerState<LineupScreen> {
  bool _doppiLibero = false;
  String _selectedSlot = 'P1';
  final Map<String, Player> _assignments = {};

  List<String> get _allSlots => [
        ..._kCourtOrder,
        'L1',
        if (_doppiLibero) 'L2',
      ];

  bool get _canConfirm =>
      _kCourtOrder.every((s) => _assignments.containsKey(s));

  void _onSlotTap(String slot) => setState(() => _selectedSlot = slot);

  void _onPlayerTap(Player player) {
    setState(() {
      // Tap on assigned player → deassign and move selection back to that slot
      String? existingSlot;
      for (final e in _assignments.entries) {
        if (e.value.id == player.id) {
          existingSlot = e.key;
          break;
        }
      }
      if (existingSlot != null) {
        _assignments.remove(existingSlot);
        _selectedSlot = existingSlot;
        return;
      }

      // Assign to currently selected slot
      _assignments[_selectedSlot] = player;
      _advanceToNextEmpty();
    });
  }

  void _removeFromSlot(String slot) {
    setState(() {
      _assignments.remove(slot);
      _selectedSlot = slot;
    });
  }

  void _advanceToNextEmpty() {
    final slots = _allSlots;
    final idx = slots.indexOf(_selectedSlot);
    if (idx == -1) return;
    for (var i = 1; i <= slots.length; i++) {
      final next = slots[(idx + i) % slots.length];
      if (!_assignments.containsKey(next)) {
        _selectedSlot = next;
        return;
      }
    }
    // All slots filled — keep current selection
  }

  void _onConferma() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScoutScreen(match: widget.match, team: widget.team),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playersAsync = ref.watch(playersStreamProvider(widget.team.id));

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        foregroundColor: Colors.white,
        title: Text(widget.team.nome.toUpperCase()),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton(
              onPressed: _canConfirm ? _onConferma : null,
              child: const Text('Conferma formazione'),
            ),
          ),
        ],
      ),
      body: playersAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (players) => Row(
          children: [
            Expanded(flex: 6, child: _buildCourtSection()),
            Expanded(flex: 4, child: _buildPlayerPanel(players)),
          ],
        ),
      ),
    );
  }

  // ── Left panel ──────────────────────────────────────────────────────────────

  Widget _buildCourtSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildDoppiLiberoCheckbox(),
          const SizedBox(height: 8),
          SizedBox(width: 460, height: 460, child: _buildCourtGrid()),
          const SizedBox(height: 14),
          _buildLiberoRow(),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildDoppiLiberoCheckbox() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: _doppiLibero,
          checkColor: _kBg,
          side: const BorderSide(color: Colors.white, width: 2),
          fillColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? Colors.white
                : Colors.transparent,
          ),
          onChanged: (v) => setState(() {
            _doppiLibero = v ?? false;
            if (!_doppiLibero) _assignments.remove('L2');
          }),
        ),
        const Text(
          'Doppio libero',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildCourtGrid() {
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
            // Front row (net side): P4 | P3 | P2
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
            // Back row: P5 | P6 | P1
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

  Widget _buildLiberoRow() {
    // Card libero stessa dimensione visiva delle P (112×112) con margine uniforme
    const slotSize = 136.0;
    const liberoMargin = EdgeInsets.all(12);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: slotSize,
          height: slotSize,
          child: _buildSlot('L1', margin: liberoMargin),
        ),
        if (_doppiLibero) ...[
          const SizedBox(width: 12),
          SizedBox(
            width: slotSize,
            height: slotSize,
            child: _buildSlot('L2', margin: liberoMargin),
          ),
        ],
      ],
    );
  }

  Widget _buildSlot(String slot,
      {EdgeInsets margin = const EdgeInsets.fromLTRB(20, 12, 20, 104)}) {
    final player = _assignments[slot];
    final isSelected = _selectedSlot == slot;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => _onSlotTap(slot),
            child: Container(
              margin: margin,
              decoration: BoxDecoration(
                color:
                    player == null ? Colors.lightBlueAccent : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? Colors.red : Colors.transparent,
                  width: 3,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.red.withAlpha(80),
                          blurRadius: 6,
                          spreadRadius: 1,
                        )
                      ]
                    : null,
              ),
              child: player == null ? _slotLabel(slot) : _slotPlayer(player),
            ),
          ),
        ),
        if (player != null)
          Positioned(
            top: margin.top - 10,
            right: margin.right - 10,
            child: GestureDetector(
              onTap: () => _removeFromSlot(slot),
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
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

  Widget _slotPlayer(Player player) {
    const nameRoleStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: Colors.black54,
    );
    const nameStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: Colors.black54,
      height: 1.1,
    );

    return Padding(
      padding: const EdgeInsets.all(4),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            '${player.numero}',
            style: const TextStyle(
              fontSize: 31,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Text(
              '${player.cognome} ${player.nome}',
              style: nameStyle,
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
              style: nameRoleStyle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Right panel ─────────────────────────────────────────────────────────────

  Widget _buildPlayerPanel(List<Player> players) {
    final assignedIds = _assignments.values.map((p) => p.id).toSet();

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Text('Giocatori',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PlayerFormScreen(teamId: widget.team.id),
                    ),
                  ),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Aggiungi'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: players.isEmpty
                ? const Center(
                    child: Text(
                      'Nessun giocatore.\nUsare "Aggiungi" per inserirne uno.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    itemCount: players.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final p = players[i];
                      final assigned = assignedIds.contains(p.id);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: assigned
                              ? Colors.grey.shade300
                              : AppColors.brandPrimary,
                          child: Text(
                            '${p.numero}',
                            style: TextStyle(
                              color:
                                  assigned ? Colors.grey : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        title: Text(
                          '${p.cognome} ${p.nome}',
                          style: TextStyle(
                            color: assigned ? Colors.grey : null,
                          ),
                        ),
                        subtitle: Text(
                          p.ruolo.label,
                          style: TextStyle(
                            color: assigned
                                ? Colors.grey.shade400
                                : null,
                          ),
                        ),
                        trailing: Icon(
                          assigned
                              ? Icons.check_circle_outline
                              : Icons.chevron_right,
                          color: assigned ? Colors.green : null,
                        ),
                        onTap: () => _onPlayerTap(p),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}


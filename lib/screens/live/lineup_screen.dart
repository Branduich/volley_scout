import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../providers/database_provider.dart';
import '../../theme/app_colors.dart';
import '../teams/player_form_screen.dart';
import 'scout_screen.dart';

const _kBg = Color(0xFF0F172A); // dark navy background
const _kField = Color(0xFF1D4ED8); // blue field interior

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
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDoppiLiberoCheckbox(),
          const SizedBox(height: 8),
          Expanded(child: _buildCourtGrid()),
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
        color: _kField,
        border: Border.all(color: Colors.white, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Column(
          children: [
            // Front row (net side): P4 | P3 | P2
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildSlot('P4')),
                  const _DashedVDivider(),
                  Expanded(child: _buildSlot('P3')),
                  const _DashedVDivider(),
                  Expanded(child: _buildSlot('P2')),
                ],
              ),
            ),
            Container(height: 2, color: Colors.white),
            // Back row: P5 | P6 | P1
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildSlot('P5')),
                  const _DashedVDivider(),
                  Expanded(child: _buildSlot('P6')),
                  const _DashedVDivider(),
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
    return Row(
      children: [
        SizedBox(width: 108, height: 108, child: _buildSlot('L1')),
        if (_doppiLibero) ...[
          const SizedBox(width: 12),
          SizedBox(width: 108, height: 108, child: _buildSlot('L2')),
        ],
      ],
    );
  }

  Widget _buildSlot(String slot) {
    final player = _assignments[slot];
    final isSelected = _selectedSlot == slot;

    return GestureDetector(
      onTap: () => _onSlotTap(slot),
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
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
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${player.numero}',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${player.cognome} ${player.nome}',
            style: const TextStyle(fontSize: 10, color: Colors.black54),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            player.ruolo.label,
            style: const TextStyle(fontSize: 9, color: Colors.black38),
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

// ── Helpers ───────────────────────────────────────────────────────────────────

class _DashedVDivider extends StatelessWidget {
  const _DashedVDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 2,
      child: CustomPaint(painter: _DashedLinePainter()),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xAAFFFFFF)
      ..strokeWidth = 1.5;
    const dash = 8.0;
    const gap = 6.0;
    var y = 0.0;
    while (y < size.height) {
      canvas.drawLine(Offset(0.5, y), Offset(0.5, y + dash), paint);
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) => false;
}

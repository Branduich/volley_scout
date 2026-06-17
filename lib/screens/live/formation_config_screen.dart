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

  void _onAvanti() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScoutScreen(match: widget.match, team: widget.team),
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
              onPressed: _onAvanti,
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
            // ConstrainedBox con minWidth = larghezza disponibile: Center centra
            // quando c'è spazio, lo scroll orizzontale gestisce l'overflow.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width - 48,
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 460,
                        height: 460,
                        child: _CourtView(assignments: widget.assignments),
                      ),
                      const SizedBox(width: 24),
                      SizedBox(
                        width: 460,
                        height: 460,
                        child: _CourtView(assignments: widget.assignments),
                      ),
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

// ── Visualizzazione campo read-only ─────────────────────────────────────────

class _CourtView extends StatelessWidget {
  final Map<String, Player> assignments;

  const _CourtView({required this.assignments});

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

  // Stessi margini di LineupScreen per card identiche
  Widget _buildSlot(String slot) {
    final player = assignments[slot];
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 104),
      decoration: BoxDecoration(
        color: player == null ? Colors.lightBlueAccent : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: player == null ? _slotLabel(slot) : _slotPlayer(player),
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
    const nameStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: Colors.black54,
      height: 1.0,
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
              style: nameStyle,
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

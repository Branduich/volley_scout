import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../models/enums.dart';
import '../../models/jersey_colors.dart';
import '../../providers/database_provider.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/certificato_dot.dart';
import '../teams/player_form_screen.dart';
import 'formation_config_screen.dart';

const _kBg = Color(0xFF0F172A); // dark navy background
const _kCourtImage = 'assets/images/court_bg.png';

// Colore invertito (canale per canale) rispetto al colore squadra, usato per
// il cerchio del libero — in pallavolo il libero indossa sempre una maglia
// di colore diverso dai compagni.
Color _invertedColor(Color color) => Color.from(
  alpha: color.a,
  red: 1.0 - color.r,
  green: 1.0 - color.g,
  blue: 1.0 - color.b,
);

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

  List<String> get _allSlots => [..._kCourtOrder, 'L1', if (_doppiLibero) 'L2'];

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
        builder: (_) => FormationConfigScreen(
          match: widget.match,
          team: widget.team,
          assignments: Map.from(_assignments),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playersAsync = ref.watch(playersStreamProvider(widget.team.id));
    // Su smartphone landscape (altezza bassa) il campo occupa troppo e
    // schiaccia la lista giocatori (nomi a capo su 3 righe): riduco il campo
    // e do più spazio al menu. Su tablet resta 6:4 come prima.
    final compact = MediaQuery.of(context).size.height < 500;
    final courtFlex = compact ? 5 : 6;
    final panelFlex = compact ? 5 : 4;

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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (players) => Row(
          children: [
            Expanded(flex: courtFlex, child: _buildCourtSection()),
            Expanded(flex: panelFlex, child: _buildPlayerPanel(players)),
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
          // Stessa dimensione del campo di FormationConfigScreen (460×460,
          // era 520×520) — su schermi più bassi il campo grande + la riga
          // del libero sotto non ci stavano (sbordava). Il libero va di
          // fianco a destra invece che sotto, così l'altezza totale resta
          // quella del solo campo.
          // FittedBox(scaleDown): su smartphone il blocco campo+libero
          // (~627dp di larghezza) si rimpicciolisce in proporzione per
          // stare nel pannello; su tablet scala = 1, nessuna differenza.
          // Stessa tecnica delle card formazione del report (i margini
          // interni fissi non reggono un SizedBox più piccolo, la scala
          // proporzionale sì — gesture comprese).
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              // .end (non .center): il libero si ancora in basso, così si
              // allinea con la riga di fondo del campo (P5-P6-P1 — la rete è
              // in alto, vedi _buildCourtGrid).
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(width: 460, height: 460, child: _buildCourtGrid()),
                const SizedBox(width: 14),
                _buildLiberoColumn(),
              ],
            ),
          ),
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

  Widget _buildLiberoColumn() {
    // Stessa dimensione esatta di una cella della griglia 3×2 del campo
    // (460/3 × 460/2) con lo stesso margine di default di _buildSlot —
    // card libero pixel-identica alle card P, non solo "circa" della
    // stessa misura.
    const cellWidth = 460 / 3;
    const cellHeight = 460 / 2;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          width: cellWidth,
          height: cellHeight,
          child: _buildSlot(
            'L1',
            phaseLabel: _doppiLibero ? 'Ricezione' : null,
          ),
        ),
        if (_doppiLibero) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: cellWidth,
            height: cellHeight,
            child: _buildSlot('L2', phaseLabel: 'Difesa'),
          ),
        ],
      ],
    );
  }

  Widget _buildSlot(
    String slot, {
    EdgeInsets margin = const EdgeInsets.fromLTRB(16, 12, 16, 108),
    String? phaseLabel,
  }) {
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
                color: player == null ? Colors.lightBlueAccent : Colors.white,
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
                        ),
                      ]
                    : null,
              ),
              child: player == null
                  ? _slotLabel(slot, phaseLabel: phaseLabel)
                  : _slotPlayer(player, phaseLabel: phaseLabel),
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
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  Widget _slotLabel(String slot, {String? phaseLabel}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          slot,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        if (phaseLabel != null)
          Text(
            phaseLabel,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
      ],
    );
  }

  Widget _slotPlayer(Player player, {String? phaseLabel}) {
    const nameRoleStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: Colors.black54,
    );
    const nameStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: Colors.black54,
      height: 1.1,
    );

    return Padding(
      padding: const EdgeInsets.all(4),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: const Alignment(0, 0.4),
            child: Text(
              '${player.numero}',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
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
              phaseLabel ?? player.ruolo.label,
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
    // Dimensioni delle card SCALATE con continuità sull'altezza schermo:
    // telefono (<=400dp) → compatto, tablet (>=760dp) → pieno di prima.
    final h = MediaQuery.of(context).size.height;
    final t = ((h - 400) / 360).clamp(0.0, 1.0);
    double sc(double telefono, double tablet) =>
        telefono + (tablet - telefono) * t;
    final avatarRadius = sc(15, 24);
    final numeroSize = sc(13, 20);
    final titleSize = sc(14, 20);
    final subtitleSize = sc(12, 16);
    final editIconSize = sc(18, 24);
    final trailingIconSize = sc(20, 28);
    final minTileHeight = sc(40, 64);
    final rowPaddingV = sc(2, 8);
    final dense = t < 0.5;

    return Container(
      color: _kBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Text(
                  'Giocatori',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: Colors.white),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlayerFormScreen(teamId: widget.team.id),
                    ),
                  ),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Aggiungi'),
                ),
              ],
            ),
          ),
          Expanded(
            child: players.isEmpty
                ? const Center(
                    child: Text(
                      'Nessun giocatore.\nUsare "Aggiungi" per inserirne uno.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    itemCount: players.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final p = players[i];
                      final assigned = assignedIds.contains(p.id);
                      final teamColor = Color(widget.team.coloreDivisa);
                      final baseColor = p.ruolo == Ruolo.libero
                          ? _invertedColor(teamColor)
                          : teamColor;
                      final cardColor = assigned
                          ? Colors.grey.shade300
                          : Colors.white;
                      final avatarColor = assigned
                          ? baseColor.withAlpha(120)
                          : baseColor;
                      final avatarTextColor = contrastingTextColor(baseColor);
                      return Material(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          dense: dense,
                          minTileHeight: minTileHeight,
                          minVerticalPadding: rowPaddingV,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: rowPaddingV,
                          ),
                          leading: CircleAvatar(
                            radius: avatarRadius,
                            backgroundColor: avatarColor,
                            child: Text(
                              '${p.numero}',
                              style: TextStyle(
                                color: assigned
                                    ? avatarTextColor.withAlpha(179)
                                    : avatarTextColor,
                                fontWeight: FontWeight.bold,
                                fontSize: numeroSize,
                              ),
                            ),
                          ),
                          title: Text(
                            '${p.cognome} ${p.nome}',
                            style: TextStyle(
                              fontSize: titleSize,
                              fontWeight: FontWeight.w600,
                              color: assigned ? Colors.grey : null,
                            ),
                          ),
                          subtitle: Text(
                            p.ruolo.label,
                            style: TextStyle(
                              fontSize: subtitleSize,
                              color: assigned ? Colors.grey.shade500 : null,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CertificatoDot(scadenza: p.scadenzaCertificato),
                              if (!assigned)
                                IconButton(
                                  icon: Icon(Icons.edit, size: editIconSize),
                                  tooltip: 'Modifica giocatore',
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PlayerFormScreen(
                                        teamId: widget.team.id,
                                        player: p,
                                      ),
                                    ),
                                  ),
                                ),
                              Icon(
                                assigned
                                    ? Icons.check_circle_outline
                                    : Icons.chevron_right,
                                size: trailingIconSize,
                                color: assigned ? Colors.green : null,
                              ),
                            ],
                          ),
                          onTap: () => _onPlayerTap(p),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

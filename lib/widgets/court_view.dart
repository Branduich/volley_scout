import 'package:flutter/material.dart';
import '../data/database.dart';

const _kCourtImage = 'assets/images/court_bg.png';

/// Etichetta (titolo + sottotitolo) sopra un campo 460×460 — estratta da
/// FormationConfigScreen per essere riusata da SostituzioneScreen.
class LabeledCourt extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color subtitleColor;
  final Widget child;

  const LabeledCourt({
    super.key,
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

/// Campo 3×2 con le card dei giocatori (slot P1..P6), read-only o
/// interattivo — estratto da FormationConfigScreen (dov'era `_CourtView`)
/// per essere riusato da SostituzioneScreen. Nessuna modifica funzionale:
/// assignments/selectedSlots/disabledSlots/onSlotTap come prima.
/// `slotBadges`: opzionale, badge "✕" a cavallo dell'angolo in alto a
/// destra degli slot indicati (usato da SostituzioneScreen per annullare un
/// cambio pending) — tap sul badge chiama `onBadgeTap`.
class CourtView extends StatelessWidget {
  final Map<String, Player> assignments;
  final Set<String> selectedSlots;
  final Set<String> disabledSlots;
  final Color selectionColor;
  final void Function(String slot)? onSlotTap;
  final Set<String> slotBadges;
  final void Function(String slot)? onBadgeTap;

  /// Contenuto personalizzato per slot: se presente per uno slot, la card
  /// mostra questo widget (sfondo bianco) invece della card giocatore/
  /// etichetta — la geometria (margini, posizione, dimensione) resta
  /// identica. Usato dalla distribuzione alzate per mostrare le percentuali
  /// con lo stesso layout delle card dei giocatori.
  final Map<String, Widget> slotContent;

  const CourtView({
    super.key,
    required this.assignments,
    this.selectedSlots = const {},
    this.disabledSlots = const {},
    this.selectionColor = Colors.amber,
    this.onSlotTap,
    this.slotBadges = const {},
    this.onBadgeTap,
    this.slotContent = const {},
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
    final override = slotContent[slot];
    final isSelected = selectedSlots.contains(slot);
    final isDisabled = disabledSlots.contains(slot);
    final canTap = onSlotTap != null && player != null && !isDisabled;
    const margin = EdgeInsets.fromLTRB(20, 12, 20, 104);

    final card = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: override != null
            ? Colors.white
            : (isDisabled
                ? Colors.grey.shade300
                : (player == null ? Colors.lightBlueAccent : Colors.white)),
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
      child: override ??
          (player == null ? _slotLabel(slot) : _slotPlayer(player, isDisabled)),
    );

    final tappableCard = canTap
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSlotTap!(slot),
            child: card,
          )
        : card;

    if (!slotBadges.contains(slot) || player == null) return tappableCard;

    // Badge "✕" a cavallo dell'angolo in alto a destra della card (vedi
    // convenzione n.8 in CLAUDE.md: figlio non-positioned di uno Stack
    // riceve vincoli loose — la card va in Positioned.fill).
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: tappableCard),
        Positioned(
          top: margin.top - 10,
          right: margin.right - 10,
          child: GestureDetector(
            onTap: onBadgeTap == null ? null : () => onBadgeTap!(slot),
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

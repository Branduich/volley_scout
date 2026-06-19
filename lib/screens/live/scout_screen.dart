import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../models/enums.dart';
import '../../theme/app_colors.dart';

const _kBg = Color(0xFF143E59);
const _kTopBarBg = Color(0xFF0D2738);
const _kCourtImage = 'assets/images/double_court_bg.png';
const _kSmallCourtImage = 'assets/images/small_court.png';

// Ancoraggio del badge di rotazione sul campo piccolo, per slot del
// palleggiatore. Il campo piccolo è ruotato di 90° in senso orario rispetto
// a LineupScreen: P1 basso-sx, P2 basso-dx, P3 centro-dx (lato rete),
// P4 alto-dx, P5 alto-sx, P6 centro-sx — in senso antiorario da P1.
const Map<String, Alignment> _kRotationBadgeAnchor = {
  'P1': Alignment.bottomLeft,
  'P2': Alignment.bottomRight,
  'P3': Alignment.centerRight,
  'P4': Alignment.topRight,
  'P5': Alignment.topLeft,
  'P6': Alignment.centerLeft,
};

// Posizioni di attacco dei 6 giocatori sul campo grande, in coordinate di
// riferimento rispetto all'immagine double_court_bg.png (1200×600 — ogni
// singolo campo è quindi un quadrato 600×600). Da estendere in futuro con le
// posizioni di ricezione.
const Map<String, Offset> _kAttackPositions = {
  'P1': Offset(200, 470),
  'P2': Offset(530, 470),
  'P3': Offset(530, 300),
  'P4': Offset(530, 130),
  'P5': Offset(200, 130),
  'P6': Offset(200, 300),
};

// Ordine antiorario degli slot sul campo grande (verificato sulle coordinate
// di _kAttackPositions), usato per calcolare la distanza dal palleggiatore.
const List<String> _kSlotOrder = ['P1', 'P2', 'P3', 'P4', 'P5', 'P6'];

// Etichette di ruolo per ogni slot, basate sul ruolo REALE del giocatore
// assegnato (non su un pattern fisso): il palleggiatore è sempre "P",
// l'opposto è sempre "O". Tra i due schiacciatori, quello più vicino al
// palleggiatore (in senso antiorario) è "S1", l'altro (diametralmente
// opposto, a 3 posizioni di distanza) è "S2" — stessa logica per i centrali
// ("C1"/"C2"). Permette anche formazioni dove un centrale, non uno
// schiacciatore, si trova subito dopo il palleggiatore.
Map<String, String> _roleLabelsFor(
    String palleggiatoreSlot, Map<String, Player> assignments) {
  final startIndex = _kSlotOrder.indexOf(palleggiatoreSlot);
  int distanceFromP(String slot) =>
      (_kSlotOrder.indexOf(slot) - startIndex + _kSlotOrder.length) %
      _kSlotOrder.length;

  final schiacciatori = <String>[];
  final centrali = <String>[];
  String? opposto;

  for (final slot in _kSlotOrder) {
    if (slot == palleggiatoreSlot) continue;
    switch (assignments[slot]?.ruolo) {
      case Ruolo.opposto:
        opposto = slot;
      case Ruolo.schiacciatore:
        schiacciatori.add(slot);
      case Ruolo.centrale:
        centrali.add(slot);
      default:
        break;
    }
  }
  schiacciatori.sort((a, b) => distanceFromP(a).compareTo(distanceFromP(b)));
  centrali.sort((a, b) => distanceFromP(a).compareTo(distanceFromP(b)));

  final labels = <String, String>{palleggiatoreSlot: 'P'};
  if (opposto != null) labels[opposto] = 'O';
  if (schiacciatori.isNotEmpty) labels[schiacciatori[0]] = 'S1';
  if (schiacciatori.length > 1) labels[schiacciatori[1]] = 'S2';
  if (centrali.isNotEmpty) labels[centrali[0]] = 'C1';
  if (centrali.length > 1) labels[centrali[1]] = 'C2';
  return labels;
}

class ScoutScreen extends StatelessWidget {
  final VolleyMatch match;
  final Team team;
  final String palleggiatoreSlot;
  final Map<String, Player> assignments;

  const ScoutScreen({
    super.key,
    required this.match,
    required this.team,
    required this.palleggiatoreSlot,
    required this.assignments,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          Container(
            height: 60,
            color: _kTopBarBg,
            child: Row(
              children: [
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Margine sinistro/destro del 15% dello schermo: il campo
                // occupa il restante 70% della larghezza, centrato.
                final courtWidth = constraints.maxWidth * 0.7;
                // Campo piccolo: 5% di margine da top e 3% da left
                // larghezza massima del 7% dello schermo (per mantenere proporzioni con il campo grande)
                final smallCourtSize = constraints.maxWidth * 0.07;
                return Stack(
                  children: [
                    Center(
                      child: SizedBox(
                        width: courtWidth,
                        child: AspectRatio(
                          aspectRatio: 1200 / 600,
                          child: LayoutBuilder(
                            builder: (context, courtConstraints) {
                              final cw = courtConstraints.maxWidth;
                              final ch = courtConstraints.maxHeight;
                              final roleLabels = _roleLabelsFor(
                                  palleggiatoreSlot, assignments);
                              return Stack(
                                children: [
                                  Image.asset(_kCourtImage,
                                      fit: BoxFit.contain),
                                  for (final entry
                                      in _kAttackPositions.entries)
                                    _buildPlayerToken(
                                        roleLabels[entry.key] ?? entry.key,
                                        entry.value,
                                        cw,
                                        ch),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: constraints.maxHeight * 0.05,
                      left: constraints.maxWidth * 0.03,
                      width: smallCourtSize,
                      height: smallCourtSize,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Stack(
                            children: [
                              Image.asset(_kSmallCourtImage,
                                  fit: BoxFit.contain),
                              _buildRotationBadge(smallCourtSize),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRotationBadge(double courtSize) {
    final anchor =
        _kRotationBadgeAnchor[palleggiatoreSlot] ?? Alignment.bottomLeft;
    final badgeWidth = courtSize * 0.5;
    final badgeHeight = courtSize / 3;
    return Align(
      alignment: anchor,
      child: SizedBox(
        width: badgeWidth,
        height: badgeHeight,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.darken(Color(team.coloreDivisa)),
            borderRadius: BorderRadius.circular(badgeHeight * 0.1),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Text(
            palleggiatoreSlot,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: badgeHeight * 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerToken(
      String label, Offset refPos, double cw, double ch) {
    // Raggio = un ventesimo del campo (singolo campo = quadrato 600×600 nello
    // spazio di riferimento, quindi un ventesimo equivale a ch/20).
    final radius = ch / 20;
    final cx = (refPos.dx / 1200) * cw;
    final cy = (refPos.dy / 600) * ch;
    return Positioned(
      left: cx - radius,
      top: cy - radius,
      width: radius * 2,
      height: radius * 2,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.darken(Color(team.coloreDivisa)),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(120),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: radius * 0.7,
          ),
        ),
      ),
    );
  }
}

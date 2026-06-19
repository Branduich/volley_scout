import 'package:flutter/material.dart';
import '../../data/database.dart';

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

class ScoutScreen extends StatelessWidget {
  final VolleyMatch match;
  final Team team;
  final String palleggiatoreSlot;

  const ScoutScreen({
    super.key,
    required this.match,
    required this.team,
    required this.palleggiatoreSlot,
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
                          child:
                              Image.asset(_kCourtImage, fit: BoxFit.contain),
                        ),
                      ),
                    ),
                    Positioned(
                      top: constraints.maxHeight * 0.05,
                      left: constraints.maxWidth * 0.03,
                      width: smallCourtSize,
                      height: smallCourtSize,
                      child: Stack(
                        children: [
                          Image.asset(_kSmallCourtImage, fit: BoxFit.contain),
                          _buildRotationBadge(smallCourtSize),
                        ],
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
            color: Color(team.coloreDivisa),
            borderRadius: BorderRadius.circular(badgeHeight * 0.1),
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
}

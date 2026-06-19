import 'package:flutter/material.dart';
import '../../data/database.dart';

const _kBg = Color(0xFF143E59);
const _kTopBarBg = Color(0xFF0D2738);
const _kCourtImage = 'assets/images/double_court_bg.png';

class ScoutScreen extends StatelessWidget {
  final VolleyMatch match;
  final Team team;

  const ScoutScreen({super.key, required this.match, required this.team});

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
                return Center(
                  child: SizedBox(
                    width: courtWidth,
                    child: AspectRatio(
                      aspectRatio: 1200 / 600,
                      child: Image.asset(_kCourtImage, fit: BoxFit.contain),
                    ),
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

import 'package:flutter/material.dart';
import '../../data/database.dart';

class ScoutScreen extends StatelessWidget {
  final VolleyMatch match;
  final Team team;

  const ScoutScreen({super.key, required this.match, required this.team});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(match.nome)),
      body: Center(
        child: Text(
          'Scout — ${match.nome}\nSquadra: ${team.nome}\n\n[da implementare]',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}

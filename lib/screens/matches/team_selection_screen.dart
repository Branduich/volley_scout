import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../providers/database_provider.dart';
import '../teams/team_form_screen.dart';
import '../live/lineup_screen.dart';

// Questa schermata si raggiunge SOLO quando il set corrente non ha ancora
// una formazione salvata (vedi MatchesScreen._avviaOnStart): la ripresa di
// un set già iniziato salta direttamente a ScoutScreen, senza passare di
// qui, perché a quel punto la squadra è già fissata dalla Rotation
// persistita — selezionarne un'altra qui creerebbe un'incoerenza.
class TeamSelectionScreen extends ConsumerWidget {
  final VolleyMatch match;
  const TeamSelectionScreen({super.key, required this.match});

  Future<void> _onTeamSelected(
      BuildContext context, WidgetRef ref, Team team) async {
    await ref.read(matchRepositoryProvider).updateMatch(
          match.copyWith(teamId: Value(team.id)),
        );
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LineupScreen(match: match, team: team),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamsAsync = ref.watch(teamsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          match.inCasa
              ? 'Seleziona la squadra di casa'
              : 'Seleziona la squadra in trasferta',
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TeamFormScreen()),
        ),
        icon: const Icon(Icons.group_add),
        label: const Text('Nuova squadra'),
      ),
      body: teamsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (teams) {
          if (teams.isEmpty) {
            return const Center(
              child: Text(
                'Nessuna squadra disponibile.\nPremi + per crearne una.',
                textAlign: TextAlign.center,
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: teams.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final team = teams[i];
              return _TeamSelectCard(
                team: team,
                isSelected: match.teamId == team.id,
                onTap: () => _onTeamSelected(context, ref, team),
              );
            },
          );
        },
      ),
    );
  }
}

class _TeamSelectCard extends StatelessWidget {
  final Team team;
  final bool isSelected;
  final VoidCallback onTap;

  const _TeamSelectCard({
    required this.team,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Color(team.coloreDivisa),
          radius: 20,
        ),
        title: Text(team.nome, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(team.categoria.label),
        trailing: FilledButton(
          onPressed: onTap,
          child: const Text('Seleziona'),
        ),
        onTap: onTap,
      ),
    );
  }
}

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../providers/database_provider.dart';
import '../../providers/premium_provider.dart';
import '../../widgets/premium_badge.dart';
import '../premium/paywall_screen.dart';
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
    // Importante passare avanti il match AGGIORNATO (con teamId impostato),
    // non il vecchio `match` del costruttore: Lineup/FormationConfig/
    // ScoutScreen/EndSetScreen lo passano semplicemente di mano in mano e,
    // più avanti, lo risalvano con `copyWith` (es. stato/setCorrente) — se
    // partissero dalla versione con teamId ancora null, ogni risalvataggio
    // lo sovrascriverebbe di nuovo a null (bug reale riscontrato: la
    // squadra scompariva dal report a fine partita).
    final aggiornato = match.copyWith(teamId: Value(team.id));
    await ref.read(matchRepositoryProvider).updateMatch(aggiornato);
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LineupScreen(match: aggiornato, team: team),
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
      // Stesso gate premium di TeamsScreen: da free una sola squadra — la
      // creazione al volo della seconda apre il paywall (badge sul FAB solo
      // quando il gate scatterebbe).
      floatingActionButton: Builder(builder: (context) {
        final giaUnaSquadra = teamsAsync.value?.isNotEmpty ?? false;
        return FloatingActionButton.extended(
          onPressed: () {
            if (giaUnaSquadra && !ref.read(statoPremiumProvider).attivo) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PaywallScreen()),
              );
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TeamFormScreen()),
            );
          },
          icon: const Icon(Icons.group_add),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Nuova squadra'),
              if (giaUnaSquadra) const PremiumBadge(),
            ],
          ),
        );
      }),
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

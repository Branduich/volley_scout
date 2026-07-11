import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/database_provider.dart';
import '../../providers/premium_provider.dart';
import '../../widgets/premium_badge.dart';
import '../premium/paywall_screen.dart';
import 'team_form_screen.dart';

class TeamsScreen extends ConsumerWidget {
  const TeamsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamsAsync = ref.watch(teamsStreamProvider);
    // Gate premium (vedi docs/TODO_strada_A.md): da free si può avere UNA
    // sola squadra — la creazione della seconda apre il paywall. Le squadre
    // esistenti restano tutte visibili/modificabili e si possono sempre
    // cancellare (per scendere a una). Il badge sul FAB compare solo quando
    // il gate scatterebbe (già una squadra + utente free).
    final giaUnaSquadra = teamsAsync.value?.isNotEmpty ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Setup squadre')),
      floatingActionButton: FloatingActionButton.extended(
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
        icon: const Icon(Icons.add),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Nuova squadra'),
            if (giaUnaSquadra) const PremiumBadge(),
          ],
        ),
      ),
      body: teamsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Errore: $err')),
        data: (teams) {
          if (teams.isEmpty) {
            return const Center(
              child: Text(
                'Nessuna squadra. Tocca "Nuova squadra" per iniziare.',
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: teams.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final team = teams[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(team.coloreDivisa),
                  ),
                  title: Text(team.nome),
                  subtitle: Text(team.categoria.label),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TeamFormScreen(team: team),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

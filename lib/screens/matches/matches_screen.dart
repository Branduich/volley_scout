import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../providers/database_provider.dart';
import '../../theme/app_colors.dart';
import 'match_form_screen.dart';

class MatchesScreen extends ConsumerWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(matchesStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Partite')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MatchFormScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Nuova partita'),
      ),
      body: matchesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (matches) {
          if (matches.isEmpty) {
            return const Center(
              child: Text(
                'Nessuna partita.\nPremi + per aggiungerne una.',
                textAlign: TextAlign.center,
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: matches.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _MatchCard(
              match: matches[i],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MatchFormScreen(match: matches[i]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final VolleyMatch match;
  final VoidCallback onTap;

  const _MatchCard({required this.match, required this.onTap});

  String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final dt = match.dataOra;
    final dateStr =
        '${_pad(dt.day)}/${_pad(dt.month)}/${dt.year}  ${_pad(dt.hour)}:${_pad(dt.minute)}';

    return Card(
      child: ListTile(
        leading: const Icon(Icons.sports_volleyball, size: 32),
        title: Text(
          match.nome,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text(
          match.palestra != null ? '$dateStr  •  ${match.palestra}' : dateStr,
        ),
        trailing: _CasaBadge(inCasa: match.inCasa),
        onTap: onTap,
      ),
    );
  }
}

class _CasaBadge extends StatelessWidget {
  final bool inCasa;
  const _CasaBadge({required this.inCasa});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: inCasa ? const Color(0xFFDCFCE7) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        inCasa ? 'Casa' : 'Trasferta',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: inCasa ? AppColors.success : AppColors.warning,
        ),
      ),
    );
  }
}

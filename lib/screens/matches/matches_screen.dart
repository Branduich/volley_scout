import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../data/demo_match_importer.dart';
import '../../models/enums.dart';
import '../../providers/database_provider.dart';
import '../../theme/app_colors.dart';
import '../live/scout_screen.dart';
import '../report/match_pdf_screen.dart';
import '../report/match_report_screen.dart';
import 'match_form_screen.dart';
import 'team_selection_screen.dart';

class MatchesScreen extends ConsumerWidget {
  const MatchesScreen({super.key});

  // "Inizia"/"Riprendi": se il set corrente ha già una formazione salvata
  // (ripresa di un set già iniziato, qualunque sia StatoPartita — vedi
  // CLAUDE.md) la squadra è già fissata dalla Rotation persistita, quindi
  // si salta dritti a ScoutScreen con la formazione ricostruita dal DB,
  // SENZA passare da TeamSelectionScreen (selezionarne un'altra qui
  // creerebbe un'incoerenza con i giocatori già salvati). Un set nuovo (mai
  // iniziato, incluso il primissimo della partita) non ha rotazione salvata
  // e teamId può essere ancora null: si passa dal flusso normale.
  Future<void> _avviaOContinua(
      BuildContext context, WidgetRef ref, VolleyMatch match) async {
    final teamId = match.teamId;
    if (teamId != null) {
      final setRepo = ref.read(matchSetRepositoryProvider);
      final setEsistente =
          await setRepo.caricaSet(match.id, match.setCorrente);
      final formazione = setEsistente == null
          ? null
          : await setRepo.caricaFormazione(setEsistente.id);
      if (formazione != null) {
        final team = await ref.read(teamRepositoryProvider).getTeam(teamId);
        if (team != null) {
          if (!context.mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ScoutScreen(
                match: match,
                team: team,
                palleggiatoreSlot: formazione.palleggiatoreSlot,
                assignments: formazione.assignments,
                ruoloCambiLibero: formazione.ruoloCambiLibero,
              ),
            ),
          );
          return;
        }
      }
    }
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TeamSelectionScreen(match: match)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(matchesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Partite'),
        actions: [
          // Solo in debug: importa la partita demo (Clai-Nettunia, 5 set)
          // per sviluppare/provare i report — vedi DemoMatchImporter.
          if (kDebugMode)
            IconButton(
              tooltip: 'Genera partita demo',
              icon: const Icon(Icons.science),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  final nome =
                      await DemoMatchImporter(ref.read(appDatabaseProvider))
                          .importa();
                  messenger.showSnackBar(
                      SnackBar(content: Text('Importata "$nome"')));
                } catch (e) {
                  messenger.showSnackBar(
                      SnackBar(content: Text('Import demo fallito: $e')));
                }
              },
            ),
        ],
      ),
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
          // Due sezioni separate: partite da iniziare/continuare (qualunque
          // stato tranne terminata) e partite terminate — vedi CLAUDE.md
          // sulla semantica di StatoPartita.
          final attive =
              matches.where((m) => m.stato != StatoPartita.terminata).toList();
          final terminate =
              matches.where((m) => m.stato == StatoPartita.terminata).toList();

          Widget buildCard(VolleyMatch match) => _MatchCard(
                match: match,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MatchFormScreen(match: match),
                  ),
                ),
                onStart: () => _avviaOContinua(context, ref, match),
                onOpenPdf: match.stato == StatoPartita.terminata
                    ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MatchPdfScreen(match: match),
                          ),
                        )
                    : null,
                onOpenReport: match.stato == StatoPartita.terminata
                    ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MatchReportScreen(match: match),
                          ),
                        )
                    : null,
              );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            children: [
              if (attive.isNotEmpty) ...[
                const _SectionHeader('Da iniziare / in corso'),
                for (final m in attive) ...[
                  buildCard(m),
                  const SizedBox(height: 8),
                ],
              ],
              if (terminate.isNotEmpty) ...[
                if (attive.isNotEmpty) const SizedBox(height: 8),
                const _SectionHeader('Terminate'),
                for (final m in terminate) ...[
                  buildCard(m),
                  const SizedBox(height: 8),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.black54,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final VolleyMatch match;
  final VoidCallback onTap;
  final VoidCallback onStart;
  // Non null solo per le partite terminate — apre MatchReportScreen.
  final VoidCallback? onOpenReport;
  // Non null solo per le partite terminate — apre MatchPdfScreen
  // (anteprima + condivisione del report PDF).
  final VoidCallback? onOpenPdf;

  const _MatchCard({
    required this.match,
    required this.onTap,
    required this.onStart,
    this.onOpenReport,
    this.onOpenPdf,
  });

  String _pad(int n) => n.toString().padLeft(2, '0');

  // Inizia (mai cominciata) / Continua (in corso o sospesa) / Riprendi
  // (terminata, vedi "MatchesScreen a due sezioni" in CLAUDE.md) — stesso
  // bottone/onStart per tutti e tre, solo label e icona cambiano.
  String _labelBottone() {
    switch (match.stato) {
      case StatoPartita.terminata:
        return 'Riprendi';
      case StatoPartita.configurazione:
        return 'Inizia';
      case StatoPartita.inCorso:
      case StatoPartita.sospesa:
        return 'Continua';
    }
  }

  IconData _iconaBottone() {
    switch (match.stato) {
      case StatoPartita.terminata:
        return Icons.replay;
      case StatoPartita.configurazione:
        return Icons.play_arrow;
      case StatoPartita.inCorso:
      case StatoPartita.sospesa:
        return Icons.play_circle_fill;
    }
  }

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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CasaBadge(inCasa: match.inCasa),
            const SizedBox(width: 12),
            if (onOpenPdf != null) ...[
              OutlinedButton.icon(
                onPressed: onOpenPdf,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('PDF'),
              ),
              const SizedBox(width: 8),
            ],
            if (onOpenReport != null) ...[
              OutlinedButton.icon(
                onPressed: onOpenReport,
                icon: const Icon(Icons.bar_chart),
                label: const Text('Report'),
              ),
              const SizedBox(width: 8),
            ],
            // Larghezza fissa (non solo "circa uguale"): altrimenti il
            // bottone si restringe per "Inizia" rispetto a "Continua"/
            // "Riprendi", più lunghe — stessa larghezza per tutte le label.
            SizedBox(
              width: 160,
              child: FilledButton.icon(
                onPressed: onStart,
                icon: Icon(_iconaBottone()),
                label: Text(_labelBottone()),
              ),
            ),
          ],
        ),
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

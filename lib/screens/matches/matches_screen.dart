import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../data/demo_match_importer.dart';
import '../../data/match_csv_exporter.dart';
import '../../l10n/app_localizations.dart';
import '../../models/enums.dart';
import '../../providers/database_provider.dart';
import '../../providers/premium_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/premium_badge.dart';
import '../live/scout_screen.dart';
import '../premium/paywall_screen.dart';
import '../report/match_pdf_screen.dart';
import '../report/match_report_screen.dart';
import 'match_form_screen.dart';
import 'team_selection_screen.dart';
import '../../utils/orientamento.dart';

class MatchesScreen extends ConsumerStatefulWidget {
  const MatchesScreen({super.key});

  @override
  ConsumerState<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends ConsumerState<MatchesScreen>
    with OrientamentoSchermata<MatchesScreen> {
  @override
  List<DeviceOrientation> get orientamentiConsentiti => kOrientamentoTutti;

  // "Inizia"/"Riprendi": se il set corrente ha già una formazione salvata
  // (ripresa di un set già iniziato, qualunque sia StatoPartita — vedi
  // CLAUDE.md) la squadra è già fissata dalla Rotation persistita, quindi
  // si salta dritti a ScoutScreen con la formazione ricostruita dal DB,
  // SENZA passare da TeamSelectionScreen (selezionarne un'altra qui
  // creerebbe un'incoerenza con i giocatori già salvati). Un set nuovo (mai
  // iniziato, incluso il primissimo della partita) non ha rotazione salvata
  // e teamId può essere ancora null: si passa dal flusso normale.
  Future<void> _avviaOContinua(
    BuildContext context,
    WidgetRef ref,
    VolleyMatch match,
  ) async {
    final teamId = match.teamId;
    if (teamId != null) {
      final setRepo = ref.read(matchSetRepositoryProvider);
      final setEsistente = await setRepo.caricaSet(match.id, match.setCorrente);
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
                sistemaGioco: formazione.sistemaGioco ??
                    SistemaGioco.palleggiatoreUnico,
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

  // Export CSV di tutte le azioni della partita (bottone "CSV", solo
  // partite terminate — futura feature premium). Caricamento one-shot con
  // lo stesso pattern di MatchPdfScreen: team (con fallback
  // inferisciSquadraDaRotazioni per le partite pre-fix del teamId), set,
  // azioni per set, roster per la join sui nomi. Poi delega a
  // condividiCsvPartita (lib/data/match_csv_exporter.dart).
  // Gate premium (vedi docs/TODO_strada_A.md): gli export PDF/CSV sono
  // feature premium — bottoni sempre visibili (vetrina), ma per un utente
  // free il tap apre il paywall invece dell'azione.
  bool _richiedePremium(BuildContext context, WidgetRef ref) {
    if (ref.read(statoPremiumProvider).attivo) return false;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PaywallScreen()),
    );
    return true;
  }

  Future<void> _esportaCsv(
    BuildContext context,
    WidgetRef ref,
    VolleyMatch match,
  ) async {
    if (_richiedePremium(context, ref)) return;
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    try {
      final teamRepo = ref.read(teamRepositoryProvider);
      final setRepo = ref.read(matchSetRepositoryProvider);
      final azioniRepo = ref.read(scoutActionRepositoryProvider);

      Team? team;
      if (match.teamId != null) {
        team = await teamRepo.getTeam(match.teamId!);
      }
      team ??= await setRepo.inferisciSquadraDaRotazioni(match.id);

      final sets = await setRepo.caricaSetsPartita(match.id);
      final azioniPerSet = <int, List<ScoutAction>>{
        for (final s in sets) s.id: await azioniRepo.caricaAzioni(s.id),
      };
      final players = team == null
          ? const <Player>[]
          : await teamRepo.getPlayersForTeam(team.id);

      await condividiCsvPartita(
        l: l,
        formato: ref.read(impostazioniProvider).formatoCsv,
        match: match,
        team: team,
        sets: sets,
        azioniPerSet: azioniPerSet,
        playerById: {for (final p in players) p.id: p},
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.partiteCsvFallito('$e'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final matchesAsync = ref.watch(matchesStreamProvider);
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.partiteTitolo),
        actions: [
          // Solo in debug: carica la stagione di esempio (5 partite) per
          // sviluppare e provare report e statistiche — vedi
          // DemoMatchImporter. SOSTITUISCE i dati del dispositivo, da cui la
          // conferma: è un ripristino di backup, non più un import che accoda.
          if (kDebugMode)
            IconButton(
              tooltip: l.partiteDemoTooltip,
              icon: const Icon(Icons.science),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final conferma = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(l.partiteDemoConfermaTitolo),
                    content: Text(l.partiteDemoConfermaTesto),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(l.comuneAnnulla),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(l.comuneConferma),
                      ),
                    ],
                  ),
                );
                if (conferma != true) return;
                try {
                  final esito = await DemoMatchImporter(
                    ref.read(appDatabaseProvider),
                  ).importa();
                  messenger.showSnackBar(
                    SnackBar(
                        content: Text(l.partiteDemoImportata(esito.partite))),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(l.partiteDemoFallito('$e'))),
                  );
                }
              },
            ),
        ],
      ),
      // Gate premium (vedi docs/TODO_strada_A.md): da free si può avere UNA
      // sola partita — la creazione della seconda apre il paywall. Le
      // partite esistenti restano visibili e scoutabili (i gate su
      // PDF/CSV/traiettorie valgono comunque). Badge sul FAB solo quando il
      // gate scatterebbe (già una partita + utente free).
      floatingActionButton: Builder(builder: (context) {
        final giaUnaPartita = matchesAsync.value?.isNotEmpty ?? false;
        return FloatingActionButton.extended(
          onPressed: () {
            if (giaUnaPartita && !ref.read(statoPremiumProvider).attivo) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PaywallScreen()),
              );
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MatchFormScreen()),
            );
          },
          icon: const Icon(Icons.add),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.partitaNuovaTitolo),
              if (giaUnaPartita) const PremiumBadge(),
            ],
          ),
        );
      }),
      body: matchesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l.comuneErrore('$e'))),
        data: (matches) {
          if (matches.isEmpty) {
            return Center(
              child: Text(l.partiteVuoto, textAlign: TextAlign.center),
            );
          }
          // Due sezioni separate: partite da iniziare/continuare (qualunque
          // stato tranne terminata) e partite terminate — vedi CLAUDE.md
          // sulla semantica di StatoPartita.
          // Le due sezioni vogliono ordini OPPOSTI, quindi entrambe ordinano
          // esplicitamente invece di ereditare il desc di watchMatches().
          // Da giocare: crescente, la partita più imminente in cima — è quella
          // che si cerca aprendo la lista.
          final attive = matches
              .where((m) => m.stato != StatoPartita.terminata)
              .toList()
            ..sort((a, b) => a.dataOra.compareTo(b.dataOra));
          // Terminate: decrescente, l'ultima giocata in cima (è quella di cui
          // si guarda il report). A parità di data l'ordine dal DB sarebbe
          // arbitrario, es. con più import demo.
          final terminate = matches
              .where((m) => m.stato == StatoPartita.terminata)
              .toList()
            ..sort((a, b) => b.dataOra.compareTo(a.dataOra));

          Widget buildCard(VolleyMatch match) => _MatchCard(
            match: match,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => MatchFormScreen(match: match)),
            ),
            onStart: () => _avviaOContinua(context, ref, match),
            onOpenPdf: match.stato == StatoPartita.terminata
                ? () {
                    if (_richiedePremium(context, ref)) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MatchPdfScreen(match: match),
                      ),
                    );
                  }
                : null,
            onExportCsv: match.stato == StatoPartita.terminata
                ? () => _esportaCsv(context, ref, match)
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
                _SectionHeader(l.partiteSezioneAttive),
                for (final m in attive) ...[
                  buildCard(m),
                  const SizedBox(height: 8),
                ],
              ],
              if (terminate.isNotEmpty) ...[
                if (attive.isNotEmpty) const SizedBox(height: 8),
                _SectionHeader(l.partiteSezioneTerminate),
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
  // Non null solo per le partite terminate — esporta tutte le azioni della
  // partita in CSV e apre lo share sheet (futura feature premium).
  final VoidCallback? onExportCsv;

  const _MatchCard({
    required this.match,
    required this.onTap,
    required this.onStart,
    this.onOpenReport,
    this.onOpenPdf,
    this.onExportCsv,
  });

  String _pad(int n) => n.toString().padLeft(2, '0');

  // Inizia (mai cominciata) / Continua (in corso o sospesa) / Riprendi
  // (terminata, vedi "MatchesScreen a due sezioni" in CLAUDE.md) — stesso
  // bottone/onStart per tutti e tre, solo label e icona cambiano.
  String _labelBottone(AppLocalizations l) {
    switch (match.stato) {
      case StatoPartita.terminata:
        return l.partiteRiprendi;
      case StatoPartita.configurazione:
        return l.partiteInizia;
      case StatoPartita.inCorso:
      case StatoPartita.sospesa:
        return l.partiteContinua;
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
    final l = AppLocalizations.of(context);
    final dt = match.dataOra;
    final dateStr =
        '${_pad(dt.day)}/${_pad(dt.month)}/${dt.year}  ${_pad(dt.hour)}:${_pad(dt.minute)}';

    final azioni = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CasaBadge(inCasa: match.inCasa),
        const SizedBox(width: 12),
        if (onExportCsv != null) ...[
          OutlinedButton.icon(
            onPressed: onExportCsv,
            icon: const Icon(Icons.table_view),
            label: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [Text('CSV'), PremiumBadge()],
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (onOpenPdf != null) ...[
          OutlinedButton.icon(
            onPressed: onOpenPdf,
            icon: const Icon(Icons.picture_as_pdf),
            label: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [Text('PDF'), PremiumBadge()],
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (onOpenReport != null) ...[
          OutlinedButton.icon(
            onPressed: onOpenReport,
            icon: const Icon(Icons.bar_chart),
            label: Text(l.partiteReport),
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
            label: Text(_labelBottone(l)),
          ),
        ),
      ],
    );

    final testata = ListTile(
      leading: const Icon(Icons.sports_volleyball, size: 32),
      title: Text(match.nome, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(
        match.palestra != null ? '$dateStr  •  ${match.palestra}' : dateStr,
      ),
      onTap: onTap,
    );

    return Card(
      child: LayoutBuilder(
        builder: (context, vincoli) {
          // Bottoni accanto al titolo solo se c'è larghezza per entrambi.
          // Sotto la soglia vanno su una riga propria: nel `trailing` del
          // ListTile chiederebbero più spazio di tutta la card, al titolo
          // resterebbe una larghezza NEGATIVA e la disposizione si
          // interromperebbe ("RenderBox was not laid out", riscontrato in
          // portrait su telefono). Il `FittedBox` non salva da solo: scala il
          // disegno, ma lo spazio lo pretende comunque.
          if (vincoli.maxWidth >= _kLarghezzaCardEstesa) {
            return ListTile(
              leading: testata.leading,
              title: testata.title,
              subtitle: testata.subtitle,
              trailing: FittedBox(fit: BoxFit.scaleDown, child: azioni),
              onTap: onTap,
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              testata,
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                // Qui il FittedBox ha una larghezza vera su cui lavorare:
                // rimpicciolisce la fila quanto basta (convenzione "supporto
                // smartphone", vedi CLAUDE.md).
                child: FittedBox(fit: BoxFit.scaleDown, child: azioni),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Sotto questa larghezza la fila di bottoni non sta accanto al titolo e passa
/// su una riga propria. Il valore tiene conto del caso peggiore — partita
/// terminata, quindi con CSV, PDF e Report tutti presenti (~600dp di bottoni)
/// più icona, margini e lo spazio minimo per il nome della partita.
const double _kLarghezzaCardEstesa = 860;

class _CasaBadge extends StatelessWidget {
  final bool inCasa;
  const _CasaBadge({required this.inCasa});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: inCasa ? const Color(0xFFDCFCE7) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        inCasa ? l.partiteCasa : l.partiteTrasferta,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: inCasa ? AppColors.success : AppColors.warning,
        ),
      ),
    );
  }
}

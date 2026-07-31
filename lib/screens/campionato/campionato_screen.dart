import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/spreadsheet_reader.dart';
import '../../logic/classifica.dart';
import '../../logic/fipav_calendario.dart';
import '../../providers/campionato_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/premium_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/orientamento.dart';
import '../../widgets/premium_badge.dart';
import '../premium/paywall_screen.dart';

/// Campionato: calendario importato dall'export FIPAV (`Gare.xls`) e
/// classifica calcolata da quelle gare. Da qui si scelgono le gare da
/// trasformare in partite vere in "Gestione partite" (non è automatico).
///
/// L'import è una feature **premium** (crea molte partite in un colpo, vedi
/// docs/TODO_strada_A.md); la consultazione di calendario e classifica è
/// libera.
class CampionatoScreen extends ConsumerStatefulWidget {
  const CampionatoScreen({super.key});

  @override
  ConsumerState<CampionatoScreen> createState() => _CampionatoScreenState();
}

/// Sfondo delle righe che riguardano la PROPRIA squadra — verde chiaro scelto
/// dall'utente. Usato sia dalle card del calendario sia dalla riga della
/// classifica: stesso significato, stesso colore (convenzione già seguita
/// altrove nell'app, vedi i colori voto/punto nello scout).
const Color _kSfondoMiaSquadra = Color(0xFFD2EFB2);

/// Esito della domanda "aggiorno o creo nuovo?". È un oggetto e non un
/// semplice `int?` perché servono TRE risposte distinte: aggiorna il
/// campionato N, creane uno nuovo (`campionatoId == null`), oppure annulla
/// (che è il `null` restituito da `showDialog`).
class _DestinazioneImport {
  const _DestinazioneImport(this.campionatoId);
  final int? campionatoId;
}

class _CampionatoScreenState extends ConsumerState<CampionatoScreen>
    with OrientamentoSchermata<CampionatoScreen> {
  // Schermata di consultazione/setup: comoda anche in portrait, la tabella
  // classifica ci sta bene (vedi convenzione n.2).
  @override
  List<DeviceOrientation> get orientamentiConsentiti => kOrientamentoTutti;

  int? _campionatoSelezionato;

  /// Squadra su cui è filtrata la lista dei campionati. `null` = tutte,
  /// [_kSenzaSquadra] = solo quelli a cui non è ancora stata assegnata una
  /// squadra (altrimenti, appena importati, sparirebbero da ogni filtro).
  int? _teamFiltro;
  static const int _kSenzaSquadra = -1;

  @override
  Widget build(BuildContext context) {
    final campionatiAsync = ref.watch(campionatiStreamProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Campionato'),
          actions: [
            TextButton.icon(
              onPressed: _importa,
              icon: const Icon(Icons.file_open),
              label: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [Text('Importa'), PremiumBadge()],
              ),
            ),
            Builder(builder: (context) {
              final campionati = campionatiAsync.value ?? const <Campionato>[];
              return PopupMenuButton<String>(
                enabled: campionati.isNotEmpty,
                onSelected: (v) {
                  if (v == 'elimina') {
                    final c = _campionatoCorrente(campionati);
                    if (c != null) _eliminaCampionato(c);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'elimina',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('Elimina campionato'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              );
            }),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.event_note), text: 'Calendario'),
              Tab(icon: Icon(Icons.leaderboard), text: 'Classifica'),
            ],
          ),
        ),
        body: campionatiAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Errore: $e')),
          data: (campionati) {
            if (campionati.isEmpty) return _statoVuoto();

            final visibili = _filtrati(campionati);
            final campionato = _campionatoCorrente(campionati);
            if (campionato == null) {
              // Il filtro non contiene più nulla (es. eliminato l'ultimo
              // campionato di quella squadra): si torna a "Tutte".
              return _filtroVuoto(campionati);
            }
            return Column(
              children: [
                if (_serveFiltroSquadra(campionati))
                  _selettoreSquadra(campionati),
                if (visibili.length > 1)
                  _selettoreCampionato(visibili, campionato),
                _intestazione(campionato),
                Expanded(
                  child: TabBarView(
                    children: [
                      _TabCalendario(campionato: campionato),
                      _TabClassifica(campionato: campionato),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _statoVuoto() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events_outlined, size: 64),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Nessun campionato importato',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Scarica dal sito FIPAV l\'esportazione delle gare in formato '
              'Excel (.xls o .xlsx) e importala qui: avrai il calendario con '
              'date, orari e palestre, la classifica aggiornata e potrai '
              'creare le partite da scoutare con un tocco.\n\n'
              'Esporta il girone INTERO (senza filtro società) se vuoi la '
              'classifica completa.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: _importa,
              icon: const Icon(Icons.file_open),
              label: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [Text('Importa file FIPAV'), PremiumBadge()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Filtro per squadra e selezione del campionato ------------------------

  /// I campionati visibili col filtro squadra corrente.
  List<Campionato> _filtrati(List<Campionato> campionati) {
    if (_teamFiltro == null) return campionati;
    if (_teamFiltro == _kSenzaSquadra) {
      return campionati.where((c) => c.teamId == null).toList();
    }
    return campionati.where((c) => c.teamId == _teamFiltro).toList();
  }

  /// Il campionato mostrato: quello selezionato se è ancora nel filtro,
  /// altrimenti il primo disponibile. `null` solo se il filtro è vuoto.
  Campionato? _campionatoCorrente(List<Campionato> campionati) {
    final visibili = _filtrati(campionati);
    if (visibili.isEmpty) return null;
    return visibili.firstWhere(
      (c) => c.id == _campionatoSelezionato,
      orElse: () => visibili.first,
    );
  }

  /// Il selettore di squadra ha senso solo se i campionati importati toccano
  /// più di un "gruppo": con una squadra sola sarebbe un dropdown a una voce.
  bool _serveFiltroSquadra(List<Campionato> campionati) {
    final gruppi = campionati.map((c) => c.teamId ?? _kSenzaSquadra).toSet();
    return gruppi.length > 1;
  }

  Widget _selettoreSquadra(List<Campionato> campionati) {
    final squadre = ref.watch(teamsStreamProvider).value ?? const <Team>[];
    final perId = {for (final t in squadre) t.id: t};
    // Solo le squadre che hanno almeno un campionato: le altre darebbero voci
    // che filtrano su lista vuota.
    final idUsati = campionati.map((c) => c.teamId ?? _kSenzaSquadra).toSet();

    String etichetta(int id) => id == _kSenzaSquadra
        ? 'Senza squadra'
        : (perId[id]?.nome ?? 'Squadra eliminata');

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      child: DropdownButtonFormField<int?>(
        initialValue: _teamFiltro,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Squadra'),
        items: [
          const DropdownMenuItem<int?>(value: null, child: Text('Tutte')),
          for (final id in idUsati)
            DropdownMenuItem<int?>(value: id, child: Text(etichetta(id))),
        ],
        onChanged: (v) => setState(() {
          _teamFiltro = v;
          _campionatoSelezionato = null; // ricalcolato sul nuovo filtro
        }),
      ),
    );
  }

  Widget _filtroVuoto(List<Campionato> campionati) {
    return Column(
      children: [
        _selettoreSquadra(campionati),
        const Spacer(),
        const Text('Nessun campionato per questa squadra.'),
        const SizedBox(height: AppSpacing.md),
        TextButton(
          onPressed: () => setState(() => _teamFiltro = null),
          child: const Text('Mostra tutti'),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _selettoreCampionato(
    List<Campionato> campionati,
    Campionato corrente,
  ) {
    // Due import dello stesso girone (stagione nuova) hanno lo stesso nome: in
    // quel caso l'etichetta porta anche la stagione, altrimenti sarebbero due
    // voci identiche e indistinguibili.
    final omonimi = <String, int>{};
    for (final c in campionati) {
      omonimi[c.nome] = (omonimi[c.nome] ?? 0) + 1;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      child: DropdownButtonFormField<int>(
        initialValue: corrente.id,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Campionato'),
        items: [
          for (final c in campionati)
            DropdownMenuItem(
              value: c.id,
              child: Text(
                (omonimi[c.nome] ?? 0) > 1 ? _nomeConStagione(c) : c.nome,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (v) => setState(() => _campionatoSelezionato = v),
      ),
    );
  }

  String _nomeConStagione(Campionato c) =>
      c.stagione == null ? c.nome : '${c.nome} — ${c.stagione}';

  // --- Eliminazione ---------------------------------------------------------

  Future<void> _eliminaCampionato(Campionato campionato) async {
    final repo = ref.read(campionatoRepositoryProvider);
    final gare = await repo.contaGare(campionato.id);
    if (!mounted) return;

    final conferma = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminare il campionato?'),
        content: Text(
          '${_nomeConStagione(campionato)}\n\n'
          'Spariscono il calendario e le sue $gare gare, e con loro la '
          'classifica.\n\n'
          'Le partite che hai già creato da queste gare RESTANO in Gestione '
          'partite, con tutti i dati di scout: se non ti servono più, '
          'eliminale da lì.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (conferma != true) return;

    await repo.eliminaCampionato(campionato.id);
    if (!mounted) return;
    setState(() {
      _campionatoSelezionato = null;
      _teamFiltro = null;
    });
  }

  /// Riga con il nome del campionato e la squadra propria (tappabile per
  /// cambiarla): senza quel dato non si può decidere casa/trasferta creando
  /// una partita, quindi va sempre in evidenza.
  Widget _intestazione(Campionato campionato) {
    final propria = campionato.squadraPropria;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _nomeConStagione(campionato),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          TextButton.icon(
            onPressed: () => _scegliSquadraPropria(campionato),
            icon: Icon(
              propria == null ? Icons.warning_amber : Icons.groups,
              color: propria == null ? AppColors.warning : null,
            ),
            label: Text(propria ?? 'Scegli la tua squadra'),
          ),
        ],
      ),
    );
  }

  // --- Import ---------------------------------------------------------------

  bool _richiedePremium() {
    if (ref.read(statoPremiumProvider).attivo) return false;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PaywallScreen()),
    );
    return true;
  }

  Future<void> _importa() async {
    if (_richiedePremium()) return;
    final messenger = ScaffoldMessenger.of(context);

    try {
      const gruppo = XTypeGroup(
        label: 'Excel',
        extensions: ['xls', 'xlsx'],
        mimeTypes: [
          'application/vnd.ms-excel',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ],
      );
      final file = await openFile(acceptedTypeGroups: const [gruppo]);
      if (file == null) return; // annullato

      final bytes = await file.readAsBytes();
      // Il formato si riconosce dai byte, non dall'estensione.
      final parsing = parseGareFipav(leggiFoglioCalcolo(bytes));

      final repo = ref.read(campionatoRepositoryProvider);
      final omonimi = await repo.campionatiConNome(repo.nomeCampionatoDi(parsing));
      if (!mounted) return;

      // Con un omonimo già a DB non si può decidere da soli: potrebbe essere il
      // ri-download settimanale (aggiorna) o la stagione nuova (crea).
      int? destinazione;
      if (omonimi.isNotEmpty) {
        final scelta = await _scegliDestinazioneImport(omonimi, parsing);
        if (scelta == null) return; // annullato
        destinazione = scelta.campionatoId;
      }

      final esito =
          await repo.importa(parsing, campionatoEsistenteId: destinazione);

      if (!mounted) return;
      setState(() {
        _campionatoSelezionato = esito.campionatoId;
        _teamFiltro = null; // il nuovo campionato dev'essere subito visibile
      });

      final pezzi = [
        if (esito.nuove > 0) '${esito.nuove} nuove',
        if (esito.aggiornate > 0) '${esito.aggiornate} aggiornate',
        if (esito.scartate > 0) '${esito.scartate} righe ignorate',
      ];
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            pezzi.isEmpty ? 'Nessuna gara importata' : 'Gare: ${pezzi.join(", ")}',
          ),
        ),
      );

      // Subito dopo il primo import serve sapere qual è la propria squadra:
      // senza, i bottoni "Crea partita" restano bloccati.
      final campionato = await ref
          .read(campionatoRepositoryProvider)
          .caricaCampionato(esito.campionatoId);
      if (campionato != null && campionato.squadraPropria == null && mounted) {
        await _scegliSquadraPropria(campionato);
      }
    } on FormatException catch (e) {
      if (!mounted) return;
      // Messaggio lungo e importante: dialog, non snackbar.
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Import non riuscito'),
          content: Text(e.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Ok'),
            ),
          ],
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Import fallito: $e')));
    }
  }

  /// Chiede se aggiornare un campionato omonimo già importato o crearne uno
  /// nuovo. Serve perché lo stesso file può significare due cose opposte: il
  /// ri-download settimanale del girone in corso, oppure il calendario della
  /// stagione nuova (stesso nome, gare tutte diverse). Ritorna `null` se
  /// l'utente annulla.
  Future<_DestinazioneImport?> _scegliDestinazioneImport(
    List<Campionato> omonimi,
    EsitoParsingFipav parsing,
  ) {
    final stagione = stagioneDaGare(parsing.gare);

    return showDialog<_DestinazioneImport>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Campionato già presente'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
            child: Text(
              'Hai già importato "${omonimi.first.nome}".\n'
              'Aggiorna quello esistente per registrare i risultati appena '
              'giocati, oppure creane uno nuovo se questo è il calendario di '
              'un\'altra stagione.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          for (final c in omonimi)
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.pop(dialogContext, _DestinazioneImport(c.id)),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.sync),
                title: const Text('Aggiorna quello esistente'),
                subtitle: Text([
                  if (c.stagione != null) 'stagione ${c.stagione}',
                  if (c.squadraPropria != null) c.squadraPropria!,
                ].join(' · ')),
              ),
            ),
          SimpleDialogOption(
            onPressed: () =>
                Navigator.pop(dialogContext, const _DestinazioneImport(null)),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.add),
              title: const Text('Crea un nuovo campionato'),
              subtitle: Text(
                stagione == null ? 'calendario separato' : 'stagione $stagione',
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Annulla'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Chiede quale delle squadre del file è la propria e a quale squadra locale
  /// corrisponde (per precompilare `teamId` sulle partite create).
  Future<void> _scegliSquadraPropria(Campionato campionato) async {
    final gare =
        await ref.read(campionatoRepositoryProvider).watchGare(campionato.id).first;
    final nomi = <String>{
      for (final g in gare) ...[g.squadraCasa, g.squadraOspite],
    }.toList()
      ..sort();
    if (nomi.isEmpty || !mounted) return;

    final squadre = await ref.read(teamRepositoryProvider).watchTeams().first;

    if (!mounted) return;
    var scelta = campionato.squadraPropria ?? _abbinamento(nomi, squadre)?.$1;
    var teamId = campionato.teamId ??
        (scelta == null ? null : _teamPerNome(scelta, squadre)?.id);

    final confermato = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('La tua squadra'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Serve a impostare casa/trasferta e l\'avversario quando '
                  'crei una partita dal calendario.',
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: scelta,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'Squadra nel calendario'),
                  items: [
                    for (final n in nomi)
                      DropdownMenuItem(value: n, child: Text(n)),
                  ],
                  onChanged: (v) => setDialogState(() {
                    scelta = v;
                    teamId = v == null ? null : _teamPerNome(v, squadre)?.id;
                  }),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<int?>(
                  initialValue: teamId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Squadra dell\'app (opzionale)',
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Nessuna'),
                    ),
                    for (final t in squadre)
                      DropdownMenuItem<int?>(value: t.id, child: Text(t.nome)),
                  ],
                  onChanged: (v) => setDialogState(() => teamId = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );

    if (confermato == true) {
      await ref
          .read(campionatoRepositoryProvider)
          .impostaSquadraPropria(campionato.id, scelta, teamId);
    }
  }

  /// Cerca un nome del calendario che combaci con una squadra locale
  /// (confronto case-insensitive), per preselezionare la scelta.
  (String, Team)? _abbinamento(List<String> nomi, List<Team> squadre) {
    for (final n in nomi) {
      final t = _teamPerNome(n, squadre);
      if (t != null) return (n, t);
    }
    return null;
  }

  Team? _teamPerNome(String nome, List<Team> squadre) {
    final cercato = nome.trim().toLowerCase();
    for (final t in squadre) {
      if (t.nome.trim().toLowerCase() == cercato) return t;
    }
    return null;
  }
}

// ===========================================================================
// Tab Calendario
// ===========================================================================

class _TabCalendario extends ConsumerWidget {
  const _TabCalendario({required this.campionato});

  final Campionato campionato;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gareAsync = ref.watch(gareStreamProvider(campionato.id));

    return gareAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Errore: $e')),
      data: (gare) {
        if (gare.isEmpty) {
          return const Center(child: Text('Nessuna gara in calendario.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          itemCount: gare.length,
          itemBuilder: (context, i) => _RigaGara(
            gara: gare[i],
            campionato: campionato,
          ),
        );
      },
    );
  }
}

class _RigaGara extends ConsumerWidget {
  const _RigaGara({required this.gara, required this.campionato});

  final GaraCampionato gara;
  final Campionato campionato;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propria = campionato.squadraPropria;
    final giocata = gara.risultato != null && gara.risultato!.trim().isNotEmpty;

    TextSpan nome(String s) => TextSpan(
          text: s,
          style: TextStyle(
            fontWeight: s == propria ? FontWeight.bold : FontWeight.normal,
          ),
        );

    // Le gare della propria squadra sono quelle che si cercano scorrendo il
    // calendario: sfondo azzurrino per trovarle a colpo d'occhio. Stesso
    // segnale della riga evidenziata in classifica (`_TabClassifica._riga`).
    final miaGara = propria != null &&
        (gara.squadraCasa == propria || gara.squadraOspite == propria);

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      color: miaGara ? _kSfondoMiaSquadra : null,
      child: ListTile(
        leading: SizedBox(
          width: 56,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (gara.giornata != null)
                Text('G. ${gara.giornata}',
                    style: Theme.of(context).textTheme.labelLarge),
              Text(_dataBreve(gara.dataOra)),
              Text(
                _ora(gara.dataOra),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        title: Text.rich(
          TextSpan(children: [
            nome(gara.squadraCasa),
            const TextSpan(text: ' - '),
            nome(gara.squadraOspite),
          ]),
        ),
        subtitle: gara.impianto == null
            ? null
            : Text(gara.impianto!, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: _trailing(context, ref, giocata),
      ),
    );
  }

  Widget _trailing(BuildContext context, WidgetRef ref, bool giocata) {
    if (gara.matchId != null) {
      return const Tooltip(
        message: 'Già in Gestione partite',
        child: Icon(Icons.check_circle, color: AppColors.success),
      );
    }
    if (giocata) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            gara.risultato!,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          // Parziali: erano in bodySmall (12), troppo piccoli per leggerli
          // scorrendo il calendario. Il riquadro si allarga di conseguenza,
          // altrimenti una gara a 5 set verrebbe troncata.
          if (gara.parziali != null)
            SizedBox(
              width: 230,
              child: Text(
                gara.parziali!,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodyLarge,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      );
    }
    return FilledButton.tonal(
      onPressed: campionato.squadraPropria == null
          ? null
          : () => _creaPartita(context, ref),
      child: const Text('Crea partita'),
    );
  }

  Future<void> _creaPartita(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);

    // Stesso gate free di MatchesScreen: da free si può avere UNA sola
    // partita. Qui in pratica non scatta (l'import è già premium), ma il
    // controllo evita di lasciare una scorciatoia aperta.
    if (!ref.read(statoPremiumProvider).attivo) {
      final esistenti =
          await ref.read(matchRepositoryProvider).watchMatches().first;
      if (esistenti.isNotEmpty) {
        if (!context.mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PaywallScreen()),
        );
        return;
      }
    }

    try {
      await ref
          .read(campionatoRepositoryProvider)
          .creaPartitaDaGara(gara, campionato);
      messenger.showSnackBar(
        SnackBar(content: Text('Creata "${nomePartitaDaGara(gara)}"')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Creazione partita fallita: $e')),
      );
    }
  }
}

String _dueCifre(int n) => n.toString().padLeft(2, '0');
String _dataBreve(DateTime d) => '${_dueCifre(d.day)}/${_dueCifre(d.month)}';
String _ora(DateTime d) => '${_dueCifre(d.hour)}:${_dueCifre(d.minute)}';

// ===========================================================================
// Tab Classifica
// ===========================================================================

class _TabClassifica extends ConsumerWidget {
  const _TabClassifica({required this.campionato});

  final Campionato campionato;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gareAsync = ref.watch(gareStreamProvider(campionato.id));

    return gareAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Errore: $e')),
      data: (righeDb) {
        final gare = righeDb.map(_versoGaraFipav).toList();
        final classifica = calcolaClassifica(gare);
        if (classifica.isEmpty) {
          return const Center(child: Text('Nessuna gara da cui calcolare.'));
        }
        final parziale = squadraUnicaDelFiltro(gare);

        return ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          children: [
            if (parziale != null) _bannerParziale(context, parziale),
            // La tabella può essere più larga dello schermo (specie in
            // portrait): scorre in orizzontale invece di sbordare.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 18,
                columns: const [
                  DataColumn(label: Text('#')),
                  DataColumn(label: Text('Squadra')),
                  DataColumn(label: Text('G'), numeric: true),
                  DataColumn(label: Text('V'), numeric: true),
                  DataColumn(label: Text('P'), numeric: true),
                  DataColumn(label: Text('Punti'), numeric: true),
                  // Set e punti in chiaro (vinti-persi / fatti-subiti) più il
                  // rispettivo quoziente: sono i due criteri che decidono a
                  // parità di punti, quindi vanno letti a colpo d'occhio.
                  DataColumn(label: Text('Set'), numeric: true),
                  DataColumn(label: Text('Q.set'), numeric: true),
                  DataColumn(label: Text('Punti f/s'), numeric: true),
                  DataColumn(label: Text('Q.punti'), numeric: true),
                ],
                rows: [
                  for (var i = 0; i < classifica.length; i++)
                    _riga(context, i + 1, classifica[i]),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  DataRow _riga(BuildContext context, int posizione, RigaClassifica r) {
    final propria = r.squadra == campionato.squadraPropria;
    final stile = propria
        ? const TextStyle(fontWeight: FontWeight.bold)
        : const TextStyle();
    return DataRow(
      color: propria
          ? const WidgetStatePropertyAll(_kSfondoMiaSquadra)
          : null,
      cells: [
        DataCell(Text('$posizione', style: stile)),
        DataCell(Text(r.squadra, style: stile)),
        DataCell(Text('${r.giocate}', style: stile)),
        DataCell(Text('${r.vinte}', style: stile)),
        DataCell(Text('${r.perse}', style: stile)),
        DataCell(Text('${r.punti}', style: stile)),
        DataCell(Text('${r.setVinti}-${r.setPersi}', style: stile)),
        DataCell(Text(_quoziente(r.quozienteSet), style: stile)),
        DataCell(Text('${r.puntiFatti}-${r.puntiSubiti}', style: stile)),
        DataCell(Text(_quoziente(r.quozientePunti), style: stile)),
      ],
    );
  }

  Widget _bannerParziale(BuildContext context, String squadra) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withAlpha(40),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Classifica parziale: il file importato contiene solo le partite '
              'di $squadra, quindi mancano gli scontri fra le altre squadre. '
              'Esporta dal sito FIPAV il girone completo (senza filtro '
              'società) per la classifica intera.',
            ),
          ),
        ],
      ),
    );
  }
}

String _quoziente(double v) => v >= 9999 ? '—' : v.toStringAsFixed(2);

/// Riga DB → gara della logica pura, così `calcolaClassifica` resta
/// indipendente da drift.
GaraFipav _versoGaraFipav(GaraCampionato g) => GaraFipav(
      campionato: '',
      dataOra: g.dataOra,
      squadraCasa: g.squadraCasa,
      squadraOspite: g.squadraOspite,
      garaNumero: g.garaNumero,
      giornata: g.giornata,
      risultato: g.risultato,
      parziali: g.parziali,
      statoDescrizione: g.statoDescrizione,
      impianto: g.impianto,
      indirizzoImpianto: g.indirizzoImpianto,
    );

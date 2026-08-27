import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/spreadsheet_reader.dart';
import '../../l10n/app_localizations.dart';
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
    final l = AppLocalizations.of(context);
    final campionatiAsync = ref.watch(campionatiStreamProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.campTitolo),
          actions: [
            TextButton.icon(
              onPressed: _importa,
              icon: const Icon(Icons.file_open),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [Text(l.campImporta), const PremiumBadge()],
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
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'elimina',
                    child: ListTile(
                      leading: const Icon(Icons.delete_outline),
                      title: Text(l.campEliminaVoce),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              );
            }),
          ],
          bottom: TabBar(
            tabs: [
              Tab(icon: const Icon(Icons.event_note), text: l.campTabCalendario),
              Tab(icon: const Icon(Icons.leaderboard), text: l.campTabClassifica),
            ],
          ),
        ),
        body: campionatiAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(l.comuneErrore('$e'))),
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
    final l = AppLocalizations.of(context);
    // Centrato quando c'è spazio, scorrevole quando non ce n'è: su telefono in
    // landscape il testo esplicativo non ci sta in altezza, e un `Center` da
    // solo non scorre — taglia. Stesso schema del menu di HomeScreen.
    return LayoutBuilder(
      builder: (context, vincoli) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: vincoli.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.emoji_events_outlined, size: 64),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l.campVuotoTitolo,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(l.campVuotoTesto, textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton.icon(
                    onPressed: _importa,
                    icon: const Icon(Icons.file_open),
                    // `Flexible` sul testo, non sul badge: su telefono il
                    // bottone concede all'etichetta meno della sua larghezza
                    // intrinseca, e un Text figlio rigido di una Row non può
                    // né restringersi né andare a capo — sfondava di 42px
                    // (preso da layout_dimensioni_test). Così va a capo e il
                    // badge resta sempre visibile.
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(child: Text(l.campImportaFile)),
                        const PremiumBadge(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Filtro per squadra e selezione del campionato ------------------------

  /// I "gruppi" squadra presenti fra i campionati importati: l'id della
  /// squadra, oppure [_kSenzaSquadra] per quelli non ancora assegnati.
  Set<int> _gruppiSquadra(List<Campionato> campionati) =>
      campionati.map((c) => c.teamId ?? _kSenzaSquadra).toSet();

  /// Il filtro **effettivo**: `_teamFiltro` vale solo finché quel gruppo
  /// esiste ancora, altrimenti si ricade su "Tutte".
  ///
  /// Serve perché il gruppo di un campionato **cambia sotto i piedi**:
  /// assegnandogli una squadra passa da "Senza squadra" a quella squadra, e se
  /// era l'ultimo del suo gruppo il filtro attivo resta orfano. Senza questa
  /// normalizzazione il dropdown andrebbe in assert ("exactly one item with
  /// value") e la lista resterebbe vuota per sempre. Si deriva a ogni build
  /// invece di correggere lo stato: `setState` durante il build non si può.
  int? _filtroEffettivo(List<Campionato> campionati) =>
      (_teamFiltro != null && _gruppiSquadra(campionati).contains(_teamFiltro))
          ? _teamFiltro
          : null;

  /// I campionati visibili col filtro squadra corrente.
  List<Campionato> _filtrati(List<Campionato> campionati) {
    final filtro = _filtroEffettivo(campionati);
    if (filtro == null) return campionati;
    if (filtro == _kSenzaSquadra) {
      return campionati.where((c) => c.teamId == null).toList();
    }
    return campionati.where((c) => c.teamId == filtro).toList();
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
  bool _serveFiltroSquadra(List<Campionato> campionati) =>
      _gruppiSquadra(campionati).length > 1;

  Widget _selettoreSquadra(List<Campionato> campionati) {
    final l = AppLocalizations.of(context);
    final squadre = ref.watch(teamsStreamProvider).value ?? const <Team>[];
    final perId = {for (final t in squadre) t.id: t};
    // Solo le squadre che hanno almeno un campionato: le altre darebbero voci
    // che filtrano su lista vuota.
    final idUsati = _gruppiSquadra(campionati);

    String etichetta(int id) => id == _kSenzaSquadra
        ? l.campSenzaSquadra
        : (perId[id]?.nome ?? l.campSquadraEliminata);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      child: DropdownButtonFormField<int?>(
        // Mai `_teamFiltro` grezzo: se punta a un gruppo sparito il dropdown
        // va in assert (vedi _filtroEffettivo).
        initialValue: _filtroEffettivo(campionati),
        isExpanded: true,
        decoration: InputDecoration(labelText: l.campFiltroSquadra),
        items: [
          DropdownMenuItem<int?>(value: null, child: Text(l.campTutte)),
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
    final l = AppLocalizations.of(context);
    return Column(
      children: [
        _selettoreSquadra(campionati),
        const Spacer(),
        Text(l.campNessunoPerSquadra),
        const SizedBox(height: AppSpacing.md),
        TextButton(
          onPressed: () => setState(() => _teamFiltro = null),
          child: Text(l.campMostraTutti),
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
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context).campTitolo,
        ),
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
    final l = AppLocalizations.of(context);

    final conferma = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(l.campEliminaTitolo),
        content: Text(
          l.campEliminaTesto(_nomeConStagione(campionato), gare),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.comuneAnnulla),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l.comuneElimina),
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
            label: Text(
              propria ?? AppLocalizations.of(context).campScegliSquadra,
            ),
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
    final l = AppLocalizations.of(context);

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
        if (esito.nuove > 0) l.campGareNuove(esito.nuove),
        if (esito.aggiornate > 0) l.campGareAggiornate(esito.aggiornate),
        if (esito.scartate > 0) l.campRigheIgnorate(esito.scartate),
      ];
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            pezzi.isEmpty
                ? l.campNessunaGaraImportata
                : l.campRiepilogoGare(pezzi.join(', ')),
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
          scrollable: true,
          title: Text(l.campImportNonRiuscitoTitolo),
          content: Text(e.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.comuneOk),
            ),
          ],
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.campImportFallito('$e'))),
      );
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
    final l = AppLocalizations.of(context);
    final stagione = stagioneDaGare(parsing.gare);

    return showDialog<_DestinazioneImport>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l.campGiaPresenteTitolo),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
            child: Text(
              l.campGiaPresenteTesto(omonimi.first.nome),
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
                title: Text(l.campAggiornaEsistente),
                subtitle: Text([
                  if (c.stagione != null) l.campStagione(c.stagione!),
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
              title: Text(l.campCreaNuovo),
              subtitle: Text(
                stagione == null
                    ? l.campCalendarioSeparato
                    : l.campStagione(stagione),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(l.comuneAnnulla),
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
    final l = AppLocalizations.of(context);
    // I valori salvati vanno RIVALIDATI contro le voci attuali, altrimenti il
    // dropdown va in assert. Succede su un campionato già importato: la
    // squadra propria può non essere più tra le squadre del calendario (nomi
    // cambiati dalla federazione, o ri-import di un girone diverso), e la
    // squadra locale abbinata può essere stata eliminata nel frattempo.
    final salvata = campionato.squadraPropria;
    var scelta = (salvata != null && nomi.contains(salvata))
        ? salvata
        : _abbinamento(nomi, squadre)?.$1;
    final idLocali = squadre.map((t) => t.id).toSet();
    var teamId = (campionato.teamId != null &&
            idLocali.contains(campionato.teamId))
        ? campionato.teamId
        : (scelta == null ? null : _teamPerNome(scelta, squadre)?.id);

    final confermato = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(l.campTuaSquadraTitolo),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.campTuaSquadraTesto),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: scelta,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l.campSquadraNelCalendario,
                  ),
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
                  decoration: InputDecoration(labelText: l.campSquadraApp),
                  items: [
                    DropdownMenuItem<int?>(
                      value: null,
                      child: Text(l.campNessuna),
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
              child: Text(l.comuneAnnulla),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l.comuneSalva),
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
    final l = AppLocalizations.of(context);
    final gareAsync = ref.watch(gareStreamProvider(campionato.id));

    return gareAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(l.comuneErrore('$e'))),
      data: (gare) {
        if (gare.isEmpty) {
          return Center(child: Text(l.campNessunaGara));
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
    final l = AppLocalizations.of(context);
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
                Text(l.campGiornata(gara.giornata!),
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
    final l = AppLocalizations.of(context);
    if (gara.matchId != null) {
      return Tooltip(
        message: l.campGiaInPartite,
        child: const Icon(Icons.check_circle, color: AppColors.success),
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
      child: Text(l.campCreaPartita),
    );
  }

  Future<void> _creaPartita(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);

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
        SnackBar(content: Text(l.campPartitaCreata(nomePartitaDaGara(gara)))),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.campCreazioneFallita('$e'))),
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
    final l = AppLocalizations.of(context);
    final gareAsync = ref.watch(gareStreamProvider(campionato.id));

    return gareAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(l.comuneErrore('$e'))),
      data: (righeDb) {
        final gare = righeDb.map(_versoGaraFipav).toList();
        final classifica = calcolaClassifica(gare);
        if (classifica.isEmpty) {
          return Center(child: Text(l.campNienteDaCalcolare));
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
                columns: [
                  const DataColumn(label: Text('#')),
                  DataColumn(label: Text(l.campFiltroSquadra)),
                  DataColumn(label: Text(l.campColGiocate), numeric: true),
                  DataColumn(label: Text(l.campColVinte), numeric: true),
                  DataColumn(label: Text(l.campColPerse), numeric: true),
                  DataColumn(label: Text(l.campColPunti), numeric: true),
                  // Set e punti in chiaro (vinti-persi / fatti-subiti) più il
                  // rispettivo quoziente: sono i due criteri che decidono a
                  // parità di punti, quindi vanno letti a colpo d'occhio.
                  DataColumn(label: Text(l.campColSet), numeric: true),
                  DataColumn(label: Text(l.campColQuozienteSet), numeric: true),
                  DataColumn(
                      label: Text(l.campColPuntiFattiSubiti), numeric: true),
                  DataColumn(
                      label: Text(l.campColQuozientePunti), numeric: true),
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
            child: Text(AppLocalizations.of(context).campBannerParziale(squadra)),
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

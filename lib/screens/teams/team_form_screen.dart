import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/enums.dart';
import '../../models/jersey_colors.dart';
import '../../data/database.dart';
import '../../providers/database_provider.dart';
import '../../widgets/certificato_dot.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/enum_l10n.dart';
import 'player_form_screen.dart';
import '../../utils/orientamento.dart';

// Colore invertito (canale per canale) rispetto al colore squadra, usato per
// l'avatar del libero — in pallavolo il libero indossa sempre una maglia di
// colore diverso dai compagni. Stessa logica duplicata in lineup_screen.dart
// e scout_screen.dart.
Color _invertedColor(Color color) => Color.from(
      alpha: color.a,
      red: 1.0 - color.r,
      green: 1.0 - color.g,
      blue: 1.0 - color.b,
    );

class TeamFormScreen extends ConsumerStatefulWidget {
  final Team? team; // null = nuova squadra, valorizzato = modifica
  const TeamFormScreen({super.key, this.team});

  @override
  ConsumerState<TeamFormScreen> createState() => _TeamFormScreenState();
}

class _TeamFormScreenState extends ConsumerState<TeamFormScreen> with OrientamentoSchermata<TeamFormScreen> {
  @override
  List<DeviceOrientation> get orientamentiConsentiti => kOrientamentoLandscape;

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomeController;
  // Nome della categoria (testo libero, scelto dalla lista Categorie). null =
  // non ancora scelta: per una nuova squadra si usa la prima categoria della
  // lista come default (vedi _categoriaEffettiva).
  String? _categoria;
  late int _coloreDivisa;

  bool get isEditing => widget.team != null;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.team?.nome ?? '');
    _categoria = widget.team?.categoria;
    _coloreDivisa =
        widget.team?.coloreDivisa ?? jerseyPalette.first.color.toARGB32();
  }

  // Categoria da salvare: quella scelta, o (nuova squadra) la prima della
  // lista. null solo se la lista è vuota (utente ha eliminato tutto).
  String? _categoriaEffettiva(List<CategorieData> categorie) =>
      _categoria ?? (categorie.isNotEmpty ? categorie.first.nome : null);

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final categorie = ref.read(categorieStreamProvider).value ?? [];
    final categoria = _categoriaEffettiva(categorie);
    if (categoria == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).squadraNessunaCategoriaSnack,
          ),
        ),
      );
      return;
    }
    final repo = ref.read(teamRepositoryProvider);

    if (isEditing) {
      await repo.updateTeam(
        widget.team!.copyWith(
          nome: _nomeController.text.trim(),
          categoria: categoria,
          coloreDivisa: _coloreDivisa,
        ),
      );
    } else {
      await repo.addTeam(
        TeamsCompanion.insert(
          nome: _nomeController.text.trim(),
          categoria: categoria,
          coloreDivisa: _coloreDivisa,
        ),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final conferma = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.squadraEliminaTitolo),
        content: Text(l.squadraEliminaTesto),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.comuneAnnulla),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.comuneElimina),
          ),
        ],
      ),
    );
    if (conferma == true) {
      await ref.read(teamRepositoryProvider).deleteTeam(widget.team!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  Widget _buildFormFields() {
    final l = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        TextFormField(
          controller: _nomeController,
          decoration: InputDecoration(
            labelText: l.squadraNome,
            border: const OutlineInputBorder(),
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? l.squadraNomeVuoto : null,
        ),
        const SizedBox(height: 16),
        _buildCategoriaField(),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          initialValue: _coloreDivisa,
          decoration: InputDecoration(
            labelText: l.squadraColore,
            border: const OutlineInputBorder(),
          ),
          items: [
            // Colore fuori palette (es. squadra demo importata, che ha un
            // verde custom): item dedicato col valore corrente, altrimenti
            // il Dropdown lancia perché initialValue non esiste tra gli
            // item ("There should be exactly one item with value"). Il
            // colore resta invariato finché non se ne sceglie un altro.
            if (!jerseyPalette
                .any((j) => j.color.toARGB32() == _coloreDivisa))
              DropdownMenuItem(
                value: _coloreDivisa,
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Color(_coloreDivisa),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black26),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(l.squadraColorePersonalizzato),
                  ],
                ),
              ),
            ...jerseyPalette.map(
              (j) => DropdownMenuItem(
                value: j.color.toARGB32(),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: j.color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black26),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(j.nome),
                  ],
                ),
              ),
            ),
          ],
          onChanged: (v) => setState(() => _coloreDivisa = v!),
        ),
      ],
    );
  }

  // Dropdown categoria letto dalla lista modificabile (stream). Se la squadra
  // ha una categoria "legacy" non più in lista (rinominata/eliminata dopo la
  // creazione), la mostro comunque come voce dedicata per non perderla — lo
  // stesso trucco del dropdown colore per un colore fuori palette.
  Widget _buildCategoriaField() {
    final l = AppLocalizations.of(context);
    final categorieAsync = ref.watch(categorieStreamProvider);
    return categorieAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Text(l.squadraErroreCategorie('$e')),
      data: (categorie) {
        final nomi = categorie.map((c) => c.nome).toList();
        final valore = _categoriaEffettiva(categorie);
        return DropdownButtonFormField<String>(
          initialValue: valore,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: l.squadraCategoria,
            border: const OutlineInputBorder(),
          ),
          items: [
            if (valore != null && !nomi.contains(valore))
              DropdownMenuItem(
                value: valore,
                child: Text(l.squadraCategoriaFuoriLista(valore)),
              ),
            ...nomi.map(
              (n) => DropdownMenuItem(value: n, child: Text(n)),
            ),
          ],
          onChanged: (v) => setState(() => _categoria = v),
          validator: (v) => v == null ? l.squadraNessunaCategoria : null,
        );
      },
    );
  }

  // Bottone di salvataggio, pinnato in fondo alla colonna sinistra (fuori
  // dallo scroll dei campi) così resta sempre visibile anche su schermi
  // bassi (smartphone landscape), dove prima finiva sotto la piega.
  Widget _buildSaveButton() {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save),
          label: Text(isEditing ? l.comuneSalvaModifiche : l.squadraCrea),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing
              ? AppLocalizations.of(context).squadraModificaTitolo
              : AppLocalizations.of(context).squadraNuovaTitolo,
        ),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (context, vincoli) {
            final form = Column(
              children: [
                Expanded(child: _buildFormFields()),
                _buildSaveButton(),
              ],
            );
            // Due colonne solo se ce n'è davvero lo spazio. La colonna del
            // form è larga 360 fisse: sotto questa soglia alla lista
            // giocatori resterebbero poche decine di pixel, e le sue righe
            // (nome + numero + azioni) si romperebbero come è successo alle
            // card delle partite. La schermata è dichiarata solo-landscape,
            // ma viene comunque costruita in portrait per qualche frame
            // mentre il dispositivo ruota: deve reggere anche lì.
            if (vincoli.maxWidth >= _kLarghezzaDueColonne) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 360, child: form),
                  if (isEditing) ...[
                    const VerticalDivider(width: 1),
                    Expanded(child: _PlayersSection(team: widget.team!)),
                  ],
                ],
              );
            }
            // Stretta: form sopra, giocatori sotto, ciascuno con la sua metà.
            if (!isEditing) return form;
            return Column(
              children: [
                Expanded(child: form),
                const Divider(height: 1),
                Expanded(child: _PlayersSection(team: widget.team!)),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Sotto questa larghezza form e lista giocatori si impilano invece di stare
/// affiancati: 360 fisse per il form più lo spazio minimo perché una riga
/// giocatore resti componibile.
const double _kLarghezzaDueColonne = 640;

class _PlayersSection extends ConsumerWidget {
  final Team team;
  const _PlayersSection({required this.team});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final playersAsync = ref.watch(playersStreamProvider(team.id));
    final jerseyColor = Color(team.coloreDivisa);
    // Dimensioni delle righe SCALATE con continuità in base all'altezza
    // schermo: telefono (<=400dp) → compatto, tablet (>=760dp) → pieno (le
    // dimensioni "da tablet" di prima), interpolazione lineare in mezzo. Su
    // tablet resta identico a prima, su smartphone le righe sono molto più
    // basse (avatar/font ridotti + minTileHeight/dense).
    final h = MediaQuery.of(context).size.height;
    final t = ((h - 400) / 360).clamp(0.0, 1.0);
    double sc(double telefono, double tablet) =>
        telefono + (tablet - telefono) * t;
    final avatarRadius = sc(14, 24);
    final numeroSize = sc(12, 20);
    final titleSize = sc(14, 20);
    final subtitleSize = sc(11.5, 16);
    final chevronSize = sc(18, 28);
    final rowPaddingV = sc(1, 8);
    final minTileHeight = sc(34, 64);
    final dense = t < 0.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Text(
                l.squadraGiocatori,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlayerFormScreen(teamId: team.id),
                  ),
                ),
                icon: const Icon(Icons.person_add),
                label: Text(l.squadraAggiungiGiocatore),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: playersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(l.comuneErrore('$e'))),
            data: (players) {
              if (players.isEmpty) {
                return Center(
                  child: Text(
                    l.squadraNessunGiocatore,
                    textAlign: TextAlign.center,
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: players.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final p = players[i];
                  final avatarColor = p.ruolo == Ruolo.libero
                      ? _invertedColor(jerseyColor)
                      : jerseyColor;
                  return ListTile(
                    dense: dense,
                    minTileHeight: minTileHeight,
                    minVerticalPadding: rowPaddingV,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 16, vertical: rowPaddingV),
                    leading: CircleAvatar(
                      radius: avatarRadius,
                      backgroundColor: avatarColor,
                      child: Text(
                        '${p.numero}',
                        style: TextStyle(
                          color: contrastingTextColor(avatarColor),
                          fontWeight: FontWeight.bold,
                          fontSize: numeroSize,
                        ),
                      ),
                    ),
                    title: Text(
                      '${p.cognome} ${p.nome}',
                      style: TextStyle(
                          fontSize: titleSize, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      ruoloLabel(p.ruolo, AppLocalizations.of(context)),
                      style: TextStyle(fontSize: subtitleSize),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CertificatoDot(scadenza: p.scadenzaCertificato),
                        Icon(Icons.chevron_right, size: chevronSize),
                      ],
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            PlayerFormScreen(teamId: team.id, player: p),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/database_provider.dart';
import '../../theme/app_spacing.dart';
import '../../utils/orientamento.dart';

/// Gestione della lista modificabile delle categorie di squadra
/// (aggiungi / rinomina / elimina / riordina). Raggiunta da "Setup squadre".
///
/// Le squadre salvano il NOME della categoria come testo, non un riferimento:
/// eliminare o rinominare una voce qui non rompe mai una squadra esistente.
/// La rinomina può, su richiesta, propagarsi alle squadre che usano il vecchio
/// nome (es. "Under 18" → "Under 19" a inizio stagione).
class CategorieScreen extends ConsumerStatefulWidget {
  const CategorieScreen({super.key});

  @override
  ConsumerState<CategorieScreen> createState() => _CategorieScreenState();
}

class _CategorieScreenState extends ConsumerState<CategorieScreen>
    with OrientamentoSchermata<CategorieScreen> {
  @override
  List<DeviceOrientation> get orientamentiConsentiti => kOrientamentoTutti;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final categorieAsync = ref.watch(categorieStreamProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.categorieTitolo)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _aggiungi(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l.categorieNuova),
      ),
      body: categorieAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l.comuneErrore('$e'))),
        data: (categorie) {
          if (categorie.isEmpty) {
            return Center(
              child: Text(
                l.categorieVuoto,
                textAlign: TextAlign.center,
              ),
            );
          }
          return ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            buildDefaultDragHandles: false,
            itemCount: categorie.length,
            // onReorderItem (non il deprecato onReorder): newIndex è già
            // l'indice finale nella lista dopo la rimozione, nessuna
            // normalizzazione manuale.
            onReorderItem: (oldIndex, newIndex) =>
                _riordina(ref, categorie, oldIndex, newIndex),
            itemBuilder: (context, i) {
              final cat = categorie[i];
              return Card(
                key: ValueKey(cat.id),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(cat.nome),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: l.comuneRinomina,
                        onPressed: () => _rinomina(context, ref, cat),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: l.comuneElimina,
                        onPressed: () => _elimina(context, ref, cat),
                      ),
                      ReorderableDragStartListener(
                        index: i,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.drag_handle),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _riordina(
    WidgetRef ref,
    List<CategorieData> categorie,
    int oldIndex,
    int newIndex,
  ) async {
    final ids = categorie.map((c) => c.id).toList();
    final id = ids.removeAt(oldIndex);
    ids.insert(newIndex, id);
    await ref.read(categoriaRepositoryProvider).riordina(ids);
  }

  Future<void> _aggiungi(BuildContext context, WidgetRef ref) async {
    final esistenti = ref.read(categorieStreamProvider).value ?? [];
    final nome = await _promptNome(
      context,
      titolo: AppLocalizations.of(context).categorieNuova,
      nomiVietatiLower: esistenti.map((c) => c.nome.toLowerCase()).toSet(),
    );
    if (nome == null) return;
    await ref.read(categoriaRepositoryProvider).aggiungiCategoria(nome);
  }

  Future<void> _rinomina(
    BuildContext context,
    WidgetRef ref,
    CategorieData cat,
  ) async {
    final esistenti = ref.read(categorieStreamProvider).value ?? [];
    final nuovo = await _promptNome(
      context,
      titolo: AppLocalizations.of(context).categorieRinominaTitolo,
      iniziale: cat.nome,
      // Il nome corrente non è un duplicato di se stesso.
      nomiVietatiLower: esistenti
          .where((c) => c.id != cat.id)
          .map((c) => c.nome.toLowerCase())
          .toSet(),
    );
    if (nuovo == null || nuovo == cat.nome) return;

    final repo = ref.read(categoriaRepositoryProvider);
    // Se qualche squadra usa il vecchio nome, chiedo se propagare la rinomina.
    final nSquadre = await repo.contaSquadreConCategoria(cat.nome);
    var aggiornaSquadre = false;
    if (nSquadre > 0) {
      if (!context.mounted) return;
      final scelta = await _chiediCascata(context, cat.nome, nuovo, nSquadre);
      if (scelta == null) return; // annullato
      aggiornaSquadre = scelta;
    }
    await repo.rinominaCategoria(
      id: cat.id,
      vecchioNome: cat.nome,
      nuovoNome: nuovo,
      aggiornaSquadre: aggiornaSquadre,
    );
  }

  Future<void> _elimina(
    BuildContext context,
    WidgetRef ref,
    CategorieData cat,
  ) async {
    final repo = ref.read(categoriaRepositoryProvider);
    final nSquadre = await repo.contaSquadreConCategoria(cat.nome);
    if (!context.mounted) return;
    final l = AppLocalizations.of(context);
    // Singolare/plurale gestiti dall'ICU dell'ARB, non concatenando pezzi di
    // frase in Dart: le due lingue accordano il verbo in modi diversi.
    final messaggio = nSquadre > 0
        ? l.categorieEliminaConSquadre(nSquadre, cat.nome)
        : l.categorieEliminaSenzaSquadre;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        scrollable: true,
        title: Text(l.categorieEliminaTitolo(cat.nome)),
        content: Text(messaggio),
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
    if (ok == true) await repo.eliminaCategoria(cat.id);
  }

  /// Dialog rinomina cascata: null = annulla, false = solo la lista,
  /// true = aggiorna anche le squadre.
  Future<bool?> _chiediCascata(
    BuildContext context,
    String vecchio,
    String nuovo,
    int nSquadre,
  ) {
    final l = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        scrollable: true,
        title: Text(l.categorieCascataTitolo),
        content: Text(l.categorieCascataTesto(nSquadre, vecchio, nuovo)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.comuneAnnulla),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.categorieSoloLista),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.categorieAggiornaSquadre(nSquadre)),
          ),
        ],
      ),
    );
  }

  /// Dialog con campo di testo per nome categoria. Ritorna il nome (trim) o
  /// null se annullato. Rifiuta vuoto e duplicati (case-insensitive).
  Future<String?> _promptNome(
    BuildContext context, {
    required String titolo,
    String iniziale = '',
    required Set<String> nomiVietatiLower,
  }) {
    final l = AppLocalizations.of(context);
    final controller = TextEditingController(text: iniziale);
    final formKey = GlobalKey<FormState>();

    void conferma(BuildContext ctx) {
      if (formKey.currentState!.validate()) {
        Navigator.pop(ctx, controller.text.trim());
      }
    }

    Widget campo(BuildContext ctx) => Form(
      key: formKey,
      child: TextFormField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: l.categorieNomeLabel,
          border: const OutlineInputBorder(),
        ),
        validator: (v) {
          final t = (v ?? '').trim();
          if (t.isEmpty) return l.categorieNomeVuoto;
          if (nomiVietatiLower.contains(t.toLowerCase())) {
            return l.categorieDuplicata;
          }
          return null;
        },
        onFieldSubmitted: (_) => conferma(ctx),
      ),
    );

    // Schermo BASSO = telefono in landscape: con la tastiera aperta restano
    // ~90dp di altezza utile. Lì un dialog centrato è inservibile — anche
    // rendendolo `scrollable` si riduce a una striscia in cui il campo di
    // testo non si vede più (visto sul device). Si usa allora il dialog A
    // TUTTO SCHERMO, che è il pattern Material per l'input su altezze
    // compatte: niente margini sprecati e i bottoni vivono nella barra in
    // alto, quindi restano visibili qualunque cosa faccia la tastiera.
    // Soglia sull'altezza TOTALE dello schermo (non su quella residua): non
    // dipende da quando la tastiera compare, così il dialog non cambia forma
    // sotto le dita.
    final schermoBasso = MediaQuery.of(context).size.height < 500;
    if (schermoBasso) {
      return showDialog<String>(
        context: context,
        builder: (ctx) => Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                tooltip: l.comuneAnnulla,
                onPressed: () => Navigator.pop(ctx),
              ),
              title: Text(titolo),
              actions: [
                TextButton(
                  onPressed: () => conferma(ctx),
                  child: Text(l.comuneSalva),
                ),
              ],
            ),
            // Scrollabile: con la tastiera aperta il body scende sotto i
            // 40dp e senza scroll il campo + l'errore di validazione
            // sfonderebbero di nuovo.
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: campo(ctx),
            ),
          ),
        ),
      );
    }

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text(titolo),
        content: campo(ctx),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.comuneAnnulla),
          ),
          FilledButton(
            onPressed: () => conferma(ctx),
            child: Text(l.comuneSalva),
          ),
        ],
      ),
    );
  }
}

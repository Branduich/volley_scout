import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers/database_provider.dart';

/// Gestione della lista modificabile delle categorie di squadra
/// (aggiungi / rinomina / elimina / riordina). Raggiunta da "Setup squadre".
///
/// Le squadre salvano il NOME della categoria come testo, non un riferimento:
/// eliminare o rinominare una voce qui non rompe mai una squadra esistente.
/// La rinomina può, su richiesta, propagarsi alle squadre che usano il vecchio
/// nome (es. "Under 18" → "Under 19" a inizio stagione).
class CategorieScreen extends ConsumerWidget {
  const CategorieScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categorieAsync = ref.watch(categorieStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Categorie')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _aggiungi(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nuova categoria'),
      ),
      body: categorieAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (categorie) {
          if (categorie.isEmpty) {
            return const Center(
              child: Text(
                'Nessuna categoria.\nTocca "Nuova categoria" per aggiungerne una.',
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
                        tooltip: 'Rinomina',
                        onPressed: () => _rinomina(context, ref, cat),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Elimina',
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
      titolo: 'Nuova categoria',
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
      titolo: 'Rinomina categoria',
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
    final messaggio = nSquadre > 0
        ? '$nSquadre ${nSquadre == 1 ? 'squadra usa' : 'squadre usano'} '
            '"${cat.nome}". ${nSquadre == 1 ? 'Resterà marcata' : 'Resteranno '
            'marcate'} "${cat.nome}", ma la voce sparirà dalla lista.'
        : 'La categoria verrà rimossa dalla lista.';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Eliminare "${cat.nome}"?'),
        content: Text(messaggio),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Elimina'),
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
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Aggiornare le squadre?'),
        content: Text(
          '$nSquadre ${nSquadre == 1 ? 'squadra è marcata' : 'squadre sono '
              'marcate'} "$vecchio". '
          'Vuoi aggiornarle a "$nuovo" o rinominare solo la voce in lista?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Solo la lista'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Aggiorna ($nSquadre)'),
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
    final controller = TextEditingController(text: iniziale);
    final formKey = GlobalKey<FormState>();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(titolo),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nome categoria',
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              final t = (v ?? '').trim();
              if (t.isEmpty) return 'Inserisci un nome';
              if (nomiVietatiLower.contains(t.toLowerCase())) {
                return 'Categoria già presente';
              }
              return null;
            },
            onFieldSubmitted: (_) {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, controller.text.trim());
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }
}

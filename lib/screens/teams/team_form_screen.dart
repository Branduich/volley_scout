import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/enums.dart';
import '../../models/jersey_colors.dart';
import '../../data/database.dart';
import '../../providers/database_provider.dart';

class TeamFormScreen extends ConsumerStatefulWidget {
  final Team? team; // null = nuova squadra, valorizzato = modifica
  const TeamFormScreen({super.key, this.team});

  @override
  ConsumerState<TeamFormScreen> createState() => _TeamFormScreenState();
}

class _TeamFormScreenState extends ConsumerState<TeamFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomeController;
  late Categoria _categoria;
  late int _coloreDivisa;

  bool get isEditing => widget.team != null;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.team?.nome ?? '');
    _categoria = widget.team?.categoria ?? Categoria.under14;
    _coloreDivisa =
        widget.team?.coloreDivisa ?? jerseyPalette.first.color.value;
  }

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = ref.read(teamRepositoryProvider);

    if (isEditing) {
      await repo.updateTeam(
        widget.team!.copyWith(
          nome: _nomeController.text.trim(),
          categoria: _categoria,
          coloreDivisa: _coloreDivisa,
        ),
      );
    } else {
      await repo.addTeam(
        TeamsCompanion.insert(
          nome: _nomeController.text.trim(),
          categoria: _categoria,
          coloreDivisa: _coloreDivisa,
        ),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminare la squadra?'),
        content: const Text('Verranno eliminati anche tutti i suoi giocatori.'),
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
    if (conferma == true) {
      await ref.read(teamRepositoryProvider).deleteTeam(widget.team!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Modifica squadra' : 'Nuova squadra'),
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
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: _nomeController,
              decoration: const InputDecoration(
                labelText: 'Nome squadra',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Inserisci un nome' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Categoria>(
              initialValue: _categoria,
              decoration: const InputDecoration(
                labelText: 'Categoria',
                border: OutlineInputBorder(),
              ),
              items: Categoria.values
                  .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                  .toList(),
              onChanged: (v) => setState(() => _categoria = v!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _coloreDivisa,
              decoration: const InputDecoration(
                labelText: 'Colore divisa',
                border: OutlineInputBorder(),
              ),
              items: jerseyPalette
                  .map(
                    (j) => DropdownMenuItem(
                      value: j.color.value,
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
                  )
                  .toList(),
              onChanged: (v) => setState(() => _coloreDivisa = v!),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: Text(isEditing ? 'Salva modifiche' : 'Crea squadra'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/enums.dart';
import '../../models/jersey_colors.dart';
import '../../data/database.dart';
import '../../providers/database_provider.dart';
import 'player_form_screen.dart';

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
        widget.team?.coloreDivisa ?? jerseyPalette.first.color.toARGB32();
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

  Widget _buildFormFields() {
    return ListView(
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
    );
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 360,
              child: _buildFormFields(),
            ),
            if (isEditing) ...[
              const VerticalDivider(width: 1),
              Expanded(
                child: _PlayersSection(team: widget.team!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlayersSection extends ConsumerWidget {
  final Team team;
  const _PlayersSection({required this.team});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playersAsync = ref.watch(playersStreamProvider(team.id));
    final jerseyColor = Color(team.coloreDivisa);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Text(
                'Giocatori',
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
                label: const Text('Aggiungi'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: playersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Errore: $e')),
            data: (players) {
              if (players.isEmpty) {
                return const Center(
                  child: Text(
                    'Nessun giocatore.\nPremi "Aggiungi" per inserirne uno.',
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
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: avatarColor,
                      child: Text(
                        '${p.numero}',
                        style: TextStyle(
                          color: contrastingTextColor(avatarColor),
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    title: Text(
                      '${p.cognome} ${p.nome}',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      p.ruolo.label,
                      style: const TextStyle(fontSize: 16),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 28),
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

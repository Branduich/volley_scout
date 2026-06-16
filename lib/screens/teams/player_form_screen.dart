import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/enums.dart';
import '../../data/database.dart';
import '../../providers/database_provider.dart';

class PlayerFormScreen extends ConsumerStatefulWidget {
  final int teamId;
  final Player? player;
  const PlayerFormScreen({super.key, required this.teamId, this.player});

  @override
  ConsumerState<PlayerFormScreen> createState() => _PlayerFormScreenState();
}

class _PlayerFormScreenState extends ConsumerState<PlayerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomeController;
  late TextEditingController _cognomeController;
  late TextEditingController _numeroController;
  late Ruolo _ruolo;
  DateTime? _scadenzaCertificato;

  bool get isEditing => widget.player != null;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.player?.nome ?? '');
    _cognomeController =
        TextEditingController(text: widget.player?.cognome ?? '');
    _numeroController = TextEditingController(
        text: widget.player != null ? '${widget.player!.numero}' : '');
    _ruolo = widget.player?.ruolo ?? Ruolo.undefined;
    _scadenzaCertificato = widget.player?.scadenzaCertificato;
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _cognomeController.dispose();
    _numeroController.dispose();
    super.dispose();
  }

  Future<void> _pickScadenzaCertificato() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scadenzaCertificato ?? DateTime.now(),
      firstDate: DateTime(2015),
      lastDate: DateTime(2050),
    );
    if (picked != null) setState(() => _scadenzaCertificato = picked);
  }

  String _formatDate(DateTime dt) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(dt.day)}/${pad(dt.month)}/${dt.year}';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = ref.read(teamRepositoryProvider);
    final numero = int.parse(_numeroController.text.trim());
    final scadenzaValue = Value(_scadenzaCertificato);

    if (isEditing) {
      await repo.updatePlayer(widget.player!.copyWith(
        nome: _nomeController.text.trim(),
        cognome: _cognomeController.text.trim(),
        numero: numero,
        ruolo: _ruolo,
        scadenzaCertificato: scadenzaValue,
      ));
    } else {
      await repo.addPlayer(PlayersCompanion.insert(
        teamId: widget.teamId,
        nome: _nomeController.text.trim(),
        cognome: _cognomeController.text.trim(),
        numero: numero,
        ruolo: _ruolo,
        scadenzaCertificato: scadenzaValue,
      ));
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminare il giocatore?'),
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
      await ref.read(teamRepositoryProvider).deletePlayer(widget.player!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Modifica giocatore' : 'Nuovo giocatore'),
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
        child: Center(
          child: SizedBox(
            width: 520,
            child: ListView(
              padding: const EdgeInsets.all(32),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _cognomeController,
                        decoration: const InputDecoration(
                          labelText: 'Cognome',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Inserisci il cognome'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _nomeController,
                        decoration: const InputDecoration(
                          labelText: 'Nome',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Inserisci il nome'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 96,
                      child: TextFormField(
                        controller: _numeroController,
                        decoration: const InputDecoration(
                          labelText: 'N°',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Richiesto';
                          }
                          final n = int.tryParse(v.trim());
                          if (n == null || n < 0 || n > 99) return '0–99';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<Ruolo>(
                  initialValue: _ruolo,
                  decoration: const InputDecoration(
                    labelText: 'Ruolo',
                    border: OutlineInputBorder(),
                  ),
                  items: Ruolo.values
                      .map((r) =>
                          DropdownMenuItem(value: r, child: Text(r.label)))
                      .toList(),
                  onChanged: (v) => setState(() => _ruolo = v!),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickScadenzaCertificato,
                        icon: const Icon(Icons.event_busy),
                        label: Text(
                          _scadenzaCertificato == null
                              ? 'Scadenza certificato medico'
                              : 'Certificato valido fino al '
                                  '${_formatDate(_scadenzaCertificato!)}',
                        ),
                      ),
                    ),
                    if (_scadenzaCertificato != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Rimuovi scadenza',
                        onPressed: () =>
                            setState(() => _scadenzaCertificato = null),
                      ),
                  ],
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: Text(
                      isEditing ? 'Salva modifiche' : 'Aggiungi giocatore'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

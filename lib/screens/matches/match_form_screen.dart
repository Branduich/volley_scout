import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../models/enums.dart';
import '../../providers/database_provider.dart';

class MatchFormScreen extends ConsumerStatefulWidget {
  final VolleyMatch? match;
  const MatchFormScreen({super.key, this.match});

  @override
  ConsumerState<MatchFormScreen> createState() => _MatchFormScreenState();
}

class _MatchFormScreenState extends ConsumerState<MatchFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomeController;
  late TextEditingController _avversarioController;
  late TextEditingController _palestraController;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late bool _inCasa;

  bool get isEditing => widget.match != null;

  @override
  void initState() {
    super.initState();
    final m = widget.match;
    _nomeController = TextEditingController(text: m?.nome ?? '');
    _avversarioController = TextEditingController(text: m?.avversario ?? '');
    _palestraController = TextEditingController(text: m?.palestra ?? '');
    final dt = m?.dataOra ?? DateTime.now();
    _selectedDate = DateTime(dt.year, dt.month, dt.day);
    _selectedTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
    _inCasa = m?.inCasa ?? true;
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _avversarioController.dispose();
    _palestraController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  String _formatDate(DateTime dt) =>
      '${_pad(dt.day)}/${_pad(dt.month)}/${dt.year}';
  String _formatTime(TimeOfDay t) => '${_pad(t.hour)}:${_pad(t.minute)}';
  String _pad(int n) => n.toString().padLeft(2, '0');

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = ref.read(matchRepositoryProvider);
    final dataOra = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    final palestraTrimmed = _palestraController.text.trim();
    final palestraValue = Value(
      palestraTrimmed.isEmpty ? null : palestraTrimmed,
    );
    final avversarioTrimmed = _avversarioController.text.trim();
    final avversarioValue = Value(
      avversarioTrimmed.isEmpty ? null : avversarioTrimmed,
    );

    if (isEditing) {
      await repo.updateMatch(
        widget.match!.copyWith(
          nome: _nomeController.text.trim(),
          dataOra: dataOra,
          inCasa: _inCasa,
          palestra: palestraValue,
          avversario: avversarioValue,
        ),
      );
    } else {
      await repo.addMatch(
        VolleyMatchesCompanion.insert(
          nome: _nomeController.text.trim(),
          dataOra: dataOra,
          inCasa: _inCasa,
          palestra: palestraValue,
          avversario: avversarioValue,
          stato: StatoPartita.configurazione,
          setCorrente: 1,
        ),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminare la partita?'),
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
      await ref.read(matchRepositoryProvider).deleteMatch(widget.match!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Modifica partita' : 'Nuova partita'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      // SingleChildScrollView a TUTTA larghezza (non più ListView dentro un
      // SizedBox centrato): così il gesto di scroll prende su tutto lo
      // schermo, non solo sulla colonna centrale da 520. Il contenuto resta
      // centrato e largo max 520 (Center + SizedBox interni).
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Center(
            child: SizedBox(
              width: 520,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nomeController,
                      decoration: const InputDecoration(
                        labelText: 'Nome partita',
                        border: OutlineInputBorder(),
                        hintText: 'es. Amichevole vs Verona',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Inserisci un nome'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickDate,
                            icon: const Icon(Icons.calendar_today),
                            label: Text(_formatDate(_selectedDate)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickTime,
                            icon: const Icon(Icons.access_time),
                            label: Text(_formatTime(_selectedTime)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _avversarioController,
                      decoration: const InputDecoration(
                        labelText: 'Squadra avversaria',
                        border: OutlineInputBorder(),
                        hintText: 'opzionale',
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('In casa'),
                      subtitle: Text(
                        _inCasa ? 'Partita casalinga' : 'In trasferta',
                      ),
                      value: _inCasa,
                      onChanged: (v) => setState(() => _inCasa = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _palestraController,
                      decoration: const InputDecoration(
                        labelText: 'Palestra / struttura',
                        border: OutlineInputBorder(),
                        hintText: 'opzionale',
                      ),
                    ),
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save),
                      label: Text(
                        isEditing ? 'Salva modifiche' : 'Crea partita',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

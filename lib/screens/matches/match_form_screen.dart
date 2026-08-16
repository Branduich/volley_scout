import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../l10n/app_localizations.dart';
import '../../logic/indirizzo_mappa.dart';
import '../../models/enums.dart';
import '../../providers/database_provider.dart';
import '../../utils/mappe.dart';
import '../../utils/orientamento.dart';

class MatchFormScreen extends ConsumerStatefulWidget {
  final VolleyMatch? match;
  const MatchFormScreen({super.key, this.match});

  @override
  ConsumerState<MatchFormScreen> createState() => _MatchFormScreenState();
}

class _MatchFormScreenState extends ConsumerState<MatchFormScreen> with OrientamentoSchermata<MatchFormScreen> {
  @override
  List<DeviceOrientation> get orientamentiConsentiti => kOrientamentoTutti;

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

  /// Apre l'indirizzo della palestra nell'app di mappe. Serve sia a farsi
  /// portare in trasferta, sia a verificare al volo un indirizzo appena
  /// scritto a mano.
  Future<void> _apriInMappe() async {
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    final aperta = await apriInMappe(
      queryMappaDaPalestra(_palestraController.text),
    );
    if (!aperta) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.mappaNessunaApp)),
      );
    }
  }

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
    final l = AppLocalizations.of(context);
    final conferma = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        scrollable: true,
        title: Text(l.partitaEliminaTitolo),
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
      await ref.read(matchRepositoryProvider).deleteMatch(widget.match!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? l.partitaModificaTitolo : l.partitaNuovaTitolo,
        ),
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
                      decoration: InputDecoration(
                        labelText: l.partitaNome,
                        border: const OutlineInputBorder(),
                        hintText: l.partitaNomeHint,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? l.partitaNomeVuoto
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
                      decoration: InputDecoration(
                        labelText: l.partitaAvversario,
                        border: const OutlineInputBorder(),
                        hintText: l.comuneOpzionale,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: Text(l.partitaInCasa),
                      subtitle: Text(
                        _inCasa ? l.partitaCasalinga : l.partitaInTrasferta,
                      ),
                      value: _inCasa,
                      onChanged: (v) => setState(() => _inCasa = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _palestraController,
                      // Ridisegna a ogni carattere: serve solo ad accendere o
                      // spegnere l'icona qui accanto (il controller da solo
                      // non fa ripartire il build).
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: l.partitaPalestra,
                        border: const OutlineInputBorder(),
                        hintText: l.comuneOpzionale,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.map_outlined),
                          tooltip: l.mappaApri,
                          onPressed:
                              _palestraController.text.trim().isEmpty
                                  ? null
                                  : _apriInMappe,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save),
                      label: Text(
                        isEditing ? l.comuneSalvaModifiche : l.partitaCrea,
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

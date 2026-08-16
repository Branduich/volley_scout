import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/enums.dart';
import '../../data/database.dart';
import '../../providers/database_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/enum_l10n.dart';
import '../../utils/orientamento.dart';

class PlayerFormScreen extends ConsumerStatefulWidget {
  final int teamId;
  final Player? player;
  const PlayerFormScreen({super.key, required this.teamId, this.player});

  @override
  ConsumerState<PlayerFormScreen> createState() => _PlayerFormScreenState();
}

class _PlayerFormScreenState extends ConsumerState<PlayerFormScreen> with OrientamentoSchermata<PlayerFormScreen> {
  @override
  List<DeviceOrientation> get orientamentiConsentiti => kOrientamentoTutti;

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomeController;
  late TextEditingController _cognomeController;
  late TextEditingController _numeroController;
  late Ruolo _ruolo;
  DateTime? _scadenzaCertificato;

  bool get isEditing => widget.player != null;

  /// Il compagno che ha già il numero attualmente digitato, se c'è: alimenta
  /// il messaggio esteso sotto la riga dei campi.
  Player? _duplicatoCorrente(List<Player> compagni) {
    final n = int.tryParse(_numeroController.text.trim());
    return n == null ? null : _giocatoreConNumero(n, compagni);
  }

  /// Il compagno di squadra che porta già il numero [numero], se c'è.
  /// Esclude sempre il giocatore in modifica: il suo numero non è un
  /// duplicato di se stesso.
  Player? _giocatoreConNumero(int numero, List<Player> compagni) {
    for (final p in compagni) {
      if (p.id != widget.player?.id && p.numero == numero) return p;
    }
    return null;
  }

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

    // Ricontrollo sul DB prima di scrivere: il validatore inline lavora sullo
    // stream, che al primo frame può non essere ancora arrivato (e nel
    // frattempo il roster può essere cambiato da un'altra schermata).
    final duplicato =
        _giocatoreConNumero(numero, await repo.getPlayersForTeam(widget.teamId));
    if (duplicato != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)
                .giocatoreNumeroDuplicato(duplicato.cognome),
          ),
        ),
      );
      return;
    }

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
    final l = AppLocalizations.of(context);
    final conferma = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        scrollable: true,
        title: Text(l.giocatoreEliminaTitolo),
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
      await ref.read(teamRepositoryProvider).deletePlayer(widget.player!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Roster della squadra: serve a segnalare subito un numero di maglia già
    // preso, mentre lo si digita.
    final l = AppLocalizations.of(context);
    final compagni =
        ref.watch(playersStreamProvider(widget.teamId)).value ?? const <Player>[];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? l.giocatoreModificaTitolo : l.giocatoreNuovoTitolo,
        ),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      // ListView a TUTTA larghezza (il contenuto è centrato dentro): così lo
      // scroll si aggancia ovunque sullo schermo, non solo sulla colonna
      // larga 520 — su tablet il resto della pagina è area morta.
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(32),
          children: [
            Center(
              child: SizedBox(
                width: 520,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _cognomeController,
                        // Su un giocatore NUOVO il campo è vuoto e il primo
                        // gesto è sempre scrivere qui: tastiera già aperta.
                        // In modifica no: si arriva per cambiare un campo
                        // preciso, e la tastiera coprirebbe il resto.
                        autofocus: !isEditing,
                        decoration: InputDecoration(
                          labelText: l.giocatoreCognome,
                          border: const OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? l.giocatoreCognomeVuoto
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _nomeController,
                        decoration: InputDecoration(
                          labelText: l.giocatoreNome,
                          border: const OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? l.giocatoreNomeVuoto
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 96,
                      child: TextFormField(
                        controller: _numeroController,
                        decoration: InputDecoration(
                          labelText: l.giocatoreNumero,
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        // Il campo è largo 96: qui ci sta solo un messaggio
                        // brevissimo, il dettaglio (con il cognome di chi ha
                        // quel numero) va nella riga sotto, a tutta larghezza.
                        onChanged: (_) => setState(() {}),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return l.comuneRichiesto;
                          }
                          final n = int.tryParse(v.trim());
                          if (n == null || n < 0 || n > 99) return '0–99';
                          if (_giocatoreConNumero(n, compagni) != null) {
                            return l.giocatoreNumeroOccupato;
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                if (_duplicatoCorrente(compagni) case final duplicato?)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            size: 18,
                            color: Theme.of(context).colorScheme.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l.giocatoreNumeroDuplicato(duplicato.cognome),
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                DropdownButtonFormField<Ruolo>(
                  initialValue: _ruolo,
                  decoration: InputDecoration(
                    labelText: l.giocatoreRuolo,
                    border: const OutlineInputBorder(),
                  ),
                  items: Ruolo.values
                      .map((r) => DropdownMenuItem(
                          value: r, child: Text(ruoloLabel(r, l))))
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
                              ? l.giocatoreScadenzaCertificato
                              : l.giocatoreCertificatoValido(
                                  _formatDate(_scadenzaCertificato!)),
                        ),
                      ),
                    ),
                    if (_scadenzaCertificato != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: l.giocatoreRimuoviScadenza,
                        onPressed: () =>
                            setState(() => _scadenzaCertificato = null),
                      ),
                  ],
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: Text(isEditing
                      ? l.comuneSalvaModifiche
                      : l.giocatoreAggiungi),
                ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

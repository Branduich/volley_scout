import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../models/enums.dart';
import '../../models/jersey_colors.dart';
import '../../widgets/court_view.dart';
import 'formation_config_screen.dart';

const _kBg = Color(0xFF0F172A);

/// Risultato del flusso di sostituzione, tornato a `ScoutScreen` che
/// calcola il diff posizione-per-posizione e scrive una riga
/// `registraSostituzione` per ogni cambio (vedi piano).
typedef RisultatoSostituzione = ({
  Map<String, Player> seiFinali,
  String palleggiatoreSlot,
  Ruolo? ruoloCambiLibero,
});

/// Schermata "Sostituzioni" (voce drawer di ScoutScreen): replica
/// l'esperienza di inizio partita — campo con card a sinistra (rotazione
/// CORRENTE del set, non la formazione iniziale), lista panchina a destra.
/// Permette N cambi in una visita (stato pending, solo in memoria): tap
/// card = chi esce, tap panchina = chi entra al suo posto; badge ✕ =
/// annulla quel cambio pending. "Avanti" apre FormationConfigScreen in
/// modalità conferma (sempre, precompilata coi valori effettivi — nessun
/// rilevamento automatico), poi torna a ScoutScreen col risultato. Back a
/// metà flusso = nessun evento scritto.
class SostituzioneScreen extends StatefulWidget {
  final VolleyMatch match;
  final Team team;

  /// I 6 in campo ADESSO (slot P1..P6 → Player, dalla rotazione corrente
  /// derivata dagli eventi — non la formazione iniziale del set).
  final Map<String, Player> seiCorrenti;

  /// Panchina: roster − 6 in campo − liberi (il libero non entra mai con
  /// un cambio, ha la sua meccanica).
  final List<Player> panchina;

  /// L1/L2 correnti (solo per far comparire il campo "Cambi del libero"
  /// nella configurazione, come a inizio partita).
  final Map<String, Player> liberi;

  /// Valori EFFETTIVI correnti del set, per precompilare la configurazione.
  final String palleggiatoreSlotCorrente;
  final Ruolo? ruoloCambiLiberoCorrente;

  const SostituzioneScreen({
    super.key,
    required this.match,
    required this.team,
    required this.seiCorrenti,
    required this.panchina,
    required this.liberi,
    required this.palleggiatoreSlotCorrente,
    required this.ruoloCambiLiberoCorrente,
  });

  @override
  State<SostituzioneScreen> createState() => _SostituzioneScreenState();
}

class _SostituzioneScreenState extends State<SostituzioneScreen> {
  late final Map<String, Player> _pending = Map.of(widget.seiCorrenti);
  String? _selectedSlot;

  /// Slot con un cambio pending (giocatore diverso da quello di partenza).
  Set<String> get _slotCambiati => {
        for (final e in _pending.entries)
          if (widget.seiCorrenti[e.key]?.id != e.value.id) e.key,
      };

  /// Panchina visibile: candidati (panchina originale + eventuali usciti
  /// nei cambi pending) meno chi è attualmente nei 6 pending. Gli USCITI
  /// pending restano visibili ma disabilitati (grigi, non tappabili): chi
  /// esce con un cambio non può rientrare in un'altra posizione — per
  /// riaverlo in campo si annulla il suo cambio col badge ✕.
  List<({Player player, bool disabilitato})> get _panchinaVisibile {
    final inCampo = {for (final p in _pending.values) p.id};
    final idsOriginali = {for (final p in widget.seiCorrenti.values) p.id};
    final candidati = <int, Player>{
      for (final p in widget.panchina) p.id: p,
      for (final p in widget.seiCorrenti.values) p.id: p,
    };
    final visibili = [
      for (final p in candidati.values)
        if (!inCampo.contains(p.id))
          (player: p, disabilitato: idsOriginali.contains(p.id)),
    ]..sort((a, b) => a.player.numero.compareTo(b.player.numero));
    return visibili;
  }

  void _onSlotTap(String slot) {
    setState(() {
      _selectedSlot = _selectedSlot == slot ? null : slot;
    });
  }

  void _annullaCambio(String slot) {
    final originale = widget.seiCorrenti[slot];
    if (originale == null) return;
    // Il titolare originale potrebbe nel frattempo essere rientrato in
    // un'ALTRA posizione (gli usciti pending ricompaiono in panchina):
    // rimetterlo anche qui lo duplicherebbe in campo — bloccare, l'utente
    // deve prima annullare l'altro cambio.
    final giaInCampoAltrove = _pending.entries
        .any((e) => e.key != slot && e.value.id == originale.id);
    if (giaInCampoAltrove) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '${originale.cognome} è già in campo in un\'altra posizione: '
            'annulla prima quel cambio'),
        duration: const Duration(seconds: 3),
      ));
      return;
    }
    setState(() {
      _pending[slot] = originale;
      _selectedSlot = null;
    });
  }

  void _onPanchinaTap(Player player) {
    final slot = _selectedSlot;
    if (slot == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Seleziona prima chi esce (tap sulla card in campo)'),
        duration: Duration(seconds: 2),
      ));
      return;
    }
    setState(() {
      _pending[slot] = player;
      _selectedSlot = null;
    });
  }

  Future<void> _onAvanti() async {
    // Configurazione SEMPRE mostrata (nessun rilevamento automatico),
    // precompilata coi valori effettivi correnti. Se il palleggiatore
    // designato è stato sostituito, la preselezione cade sul suo slot —
    // cioè su chi è entrato al suo posto (default sensato per il cambio
    // ruolo-su-ruolo; per il doppio cambio l'utente tocca un'altra card).
    final risultato =
        await Navigator.push<ConfigurazioneFormazione>(
      context,
      MaterialPageRoute(
        builder: (_) => FormationConfigScreen(
          match: widget.match,
          team: widget.team,
          assignments: {..._pending, ...widget.liberi},
          palleggiatoreSlotIniziale: widget.palleggiatoreSlotCorrente,
          ruoloCambiLiberoIniziale: widget.ruoloCambiLiberoCorrente,
          modalitaConferma: true,
        ),
      ),
    );
    if (risultato == null || !mounted) return; // back: si resta qui
    Navigator.pop<RisultatoSostituzione>(context, (
      seiFinali: Map.of(_pending),
      palleggiatoreSlot: risultato.palleggiatoreSlot,
      ruoloCambiLibero: risultato.ruoloCambiLibero,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cambi = _slotCambiati.length;
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        foregroundColor: Colors.white,
        title: const Text('Sostituzioni'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton(
              onPressed: _onAvanti,
              child: const Text('Avanti'),
            ),
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sinistra: campo con la rotazione corrente + cambi pending.
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 16),
              child: Center(
                child: LabeledCourt(
                  title: 'In campo',
                  subtitle: cambi == 0
                      ? 'Tocca chi esce, poi chi entra dalla panchina'
                      : '$cambi cambi${cambi == 1 ? "o" : ""} da confermare',
                  subtitleColor:
                      cambi == 0 ? Colors.white54 : Colors.lightBlue,
                  child: CourtView(
                    assignments: _pending,
                    selectedSlots: _selectedSlot != null
                        ? {_selectedSlot!}
                        : const {},
                    selectionColor: Colors.red,
                    onSlotTap: _onSlotTap,
                    slotBadges: _slotCambiati,
                    onBadgeTap: _annullaCambio,
                  ),
                ),
              ),
            ),
          ),
          // Destra: panchina.
          SizedBox(
            width: 320,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(8, 12, 16, 8),
                  child: Text(
                    'Panchina',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(8, 0, 16, 16),
                    children: [
                      if (_panchinaVisibile.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Nessun giocatore disponibile',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ),
                      for (final voce in _panchinaVisibile) ...[
                        _buildPanchinaTile(voce.player, voce.disabilitato),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanchinaTile(Player p, bool disabilitato) {
    final teamColor = Color(widget.team.coloreDivisa);
    // Stessa convenzione di LineupScreen per i non disponibili: card
    // grigia, avatar col colore squadra a opacità ridotta, non tappabile.
    final avatarColor =
        disabilitato ? teamColor.withAlpha(120) : teamColor;
    return Material(
      color: disabilitato ? Colors.grey.shade300 : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        enabled: !disabilitato,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: avatarColor,
          child: Text(
            '${p.numero}',
            style: TextStyle(
              color: contrastingTextColor(teamColor),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          '${p.cognome} ${p.nome}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(p.ruolo.label, style: const TextStyle(fontSize: 16)),
        onTap: disabilitato ? null : () => _onPanchinaTap(p),
      ),
    );
  }
}

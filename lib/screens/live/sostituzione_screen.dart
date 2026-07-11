import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../models/enums.dart';
import '../../models/jersey_colors.dart';
import '../../widgets/court_view.dart';
import 'formation_config_screen.dart';

const _kBg = Color(0xFF0F172A);

// Colore invertito (canale per canale) rispetto al colore squadra, usato
// per i liberi — in pallavolo il libero indossa sempre una maglia di
// colore diverso dai compagni. Stessa funzione duplicata in
// lineup_screen.dart/scout_screen.dart (pattern deliberato, vedi CLAUDE.md).
Color _invertedColor(Color color) => Color.from(
  alpha: color.a,
  red: 1.0 - color.r,
  green: 1.0 - color.g,
  blue: 1.0 - color.b,
);

/// Risultato del flusso di sostituzione, tornato a `ScoutScreen` che
/// calcola il diff posizione-per-posizione (P1..P6 e L1/L2) e scrive una
/// riga `registraSostituzione` per ogni cambio (vedi piano).
typedef RisultatoSostituzione = ({
  Map<String, Player> seiFinali,
  Map<String, Player> liberiFinali,
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

  /// Panchina: roster − 6 in campo − liberi correnti. Include anche i
  /// giocatori con ruolo libero: un libero si può cambiare, ma SOLO al
  /// posto di un altro libero (vincolo di dominio — la panchina si
  /// abilita/disabilita per ruolo in base alla card selezionata).
  final List<Player> panchina;

  /// L1/L2 EFFETTIVI correnti: card selezionabili come "chi esce" accanto
  /// al campo, e passati alla configurazione come a inizio partita.
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
  late final Map<String, Player> _pendingLiberi = Map.of(widget.liberi);
  // Slot P1..P6 oppure chiave libero L1/L2 selezionata come "chi esce".
  String? _selectedSlot;

  bool get _selezioneLibero => _selectedSlot?.startsWith('L') ?? false;

  /// Slot con un cambio pending (giocatore diverso da quello di partenza).
  Set<String> get _slotCambiati => {
    for (final e in _pending.entries)
      if (widget.seiCorrenti[e.key]?.id != e.value.id) e.key,
  };

  /// Chiavi libero con un cambio pending.
  Set<String> get _liberiCambiati => {
    for (final e in _pendingLiberi.entries)
      if (widget.liberi[e.key]?.id != e.value.id) e.key,
  };

  /// Panchina visibile: candidati (panchina originale + eventuali usciti
  /// nei cambi pending, titolari e liberi) meno chi è attualmente nei
  /// pending. Disabilitati (grigi, non tappabili): gli USCITI pending (chi
  /// esce non può rientrare in un'altra posizione — si annulla il suo
  /// cambio col badge ✕) e, quando una card è selezionata, i ruoli
  /// incompatibili (un libero entra SOLO per un altro libero, e viceversa).
  List<({Player player, bool disabilitato})> get _panchinaVisibile {
    final inCampo = {
      for (final p in _pending.values) p.id,
      for (final p in _pendingLiberi.values) p.id,
    };
    final idsOriginali = {
      for (final p in widget.seiCorrenti.values) p.id,
      for (final p in widget.liberi.values) p.id,
    };
    final candidati = <int, Player>{
      for (final p in widget.panchina) p.id: p,
      for (final p in widget.seiCorrenti.values) p.id: p,
      for (final p in widget.liberi.values) p.id: p,
    };
    bool ruoloIncompatibile(Player p) {
      if (_selectedSlot == null) return false;
      final isLibero = p.ruolo == Ruolo.libero;
      return _selezioneLibero ? !isLibero : isLibero;
    }

    final visibili = [
      for (final p in candidati.values)
        if (!inCampo.contains(p.id))
          (
            player: p,
            disabilitato: idsOriginali.contains(p.id) || ruoloIncompatibile(p),
          ),
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
    final giaInCampoAltrove = _pending.entries.any(
      (e) => e.key != slot && e.value.id == originale.id,
    );
    if (giaInCampoAltrove) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${originale.cognome} è già in campo in un\'altra posizione: '
            'annulla prima quel cambio',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }
    setState(() {
      _pending[slot] = originale;
      _selectedSlot = null;
    });
  }

  void _annullaCambioLibero(String key) {
    final originale = widget.liberi[key];
    if (originale == null) return;
    setState(() {
      _pendingLiberi[key] = originale;
      _selectedSlot = null;
    });
  }

  void _onPanchinaTap(Player player) {
    final slot = _selectedSlot;
    if (slot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleziona prima chi esce (tap sulla card in campo)'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() {
      // Guardia ridondante (le tile incompatibili sono già disabilitate):
      // un libero entra solo per un libero, e viceversa.
      if (_selezioneLibero) {
        if (player.ruolo == Ruolo.libero) _pendingLiberi[slot] = player;
      } else {
        if (player.ruolo != Ruolo.libero) _pending[slot] = player;
      }
      _selectedSlot = null;
    });
  }

  Future<void> _onAvanti() async {
    // Configurazione SEMPRE mostrata (nessun rilevamento automatico),
    // precompilata coi valori effettivi correnti. Se il palleggiatore
    // designato è stato sostituito, la preselezione cade sul suo slot —
    // cioè su chi è entrato al suo posto (default sensato per il cambio
    // ruolo-su-ruolo; per il doppio cambio l'utente tocca un'altra card).
    final risultato = await Navigator.push<ConfigurazioneFormazione>(
      context,
      MaterialPageRoute(
        builder: (_) => FormationConfigScreen(
          match: widget.match,
          team: widget.team,
          assignments: {..._pending, ..._pendingLiberi},
          palleggiatoreSlotIniziale: widget.palleggiatoreSlotCorrente,
          ruoloCambiLiberoIniziale: widget.ruoloCambiLiberoCorrente,
          modalitaConferma: true,
        ),
      ),
    );
    if (risultato == null || !mounted) return; // back: si resta qui
    Navigator.pop<RisultatoSostituzione>(context, (
      seiFinali: Map.of(_pending),
      liberiFinali: Map.of(_pendingLiberi),
      palleggiatoreSlot: risultato.palleggiatoreSlot,
      ruoloCambiLibero: risultato.ruoloCambiLibero,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cambi = _slotCambiati.length + _liberiCambiati.length;
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
          // Sinistra: campo con la rotazione corrente + cambi pending, e
          // di fianco le card dei liberi (come in LineupScreen: il libero
          // non ha uno slot di rotazione, sta fuori dal campo).
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 16),
              child: Center(
                // FittedBox(scaleDown): su smartphone il blocco campo+liberi
                // si rimpicciolisce in proporzione per stare nel pannello
                // (stessa tecnica di LineupScreen/FormationConfigScreen);
                // su tablet scala = 1, nessuna differenza.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    // .end: le card libero si allineano al fondo del campo
                    // (stessa scelta di LineupScreen).
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      LabeledCourt(
                        title: 'In campo',
                        subtitle: cambi == 0
                            ? 'Tocca chi esce, poi chi entra dalla panchina'
                            : '$cambi cambi${cambi == 1 ? "o" : ""} '
                                  'da confermare',
                        subtitleColor: cambi == 0
                            ? Colors.white54
                            : Colors.lightBlue,
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
                      if (_pendingLiberi.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final key in const ['L1', 'L2'])
                              if (_pendingLiberi[key] != null) ...[
                                _buildLiberoCard(key),
                                const SizedBox(height: 10),
                              ],
                          ],
                        ),
                      ],
                    ],
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

  // Card del libero accanto al campo (stile analogo alle card slot di
  // CourtView, in scala ridotta): tap = seleziona come "chi esce" (solo un
  // altro libero potrà entrare — vedi _panchinaVisibile); badge ✕ se ha un
  // cambio pending.
  Widget _buildLiberoCard(String key) {
    final player = _pendingLiberi[key]!;
    final isSelected = _selectedSlot == key;
    final cambiato = _liberiCambiati.contains(key);

    final card = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onSlotTap(key),
      child: Container(
        width: 112,
        height: 112,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: Colors.red, width: 3) : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.red.withAlpha(80),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '${player.numero}',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Text(
                '${player.cognome} ${player.nome}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.0,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Text(
                key,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );

    if (!cambiato) return card;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        card,
        Positioned(
          top: -8,
          right: -8,
          child: GestureDetector(
            onTap: () => _annullaCambioLibero(key),
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPanchinaTile(Player p, bool disabilitato) {
    final teamColor = Color(widget.team.coloreDivisa);
    // Libero col colore invertito (maglia diversa), come nella lista di
    // LineupScreen. Stessa convenzione per i non disponibili: card grigia,
    // avatar a opacità ridotta, non tappabile.
    final baseColor = p.ruolo == Ruolo.libero
        ? _invertedColor(teamColor)
        : teamColor;
    final avatarColor = disabilitato ? baseColor.withAlpha(120) : baseColor;
    return Material(
      color: disabilitato ? Colors.grey.shade300 : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        enabled: !disabilitato,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: avatarColor,
          child: Text(
            '${p.numero}',
            style: TextStyle(
              color: contrastingTextColor(baseColor),
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

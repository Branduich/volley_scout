import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../models/enums.dart';
import '../../models/jersey_colors.dart';
import '../../widgets/court_view.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/enum_l10n.dart';
import 'formation_config_screen.dart';
import '../../utils/orientamento.dart';

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
  // Slot P1..P6 -> ruolo che chi entra assume in campo, solo dove è diverso
  // dal suo anagrafico (dialog "Gioca da" in _onPanchinaTap).
  Map<String, Ruolo> ruoliInCampo,
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

  /// Sistema di gioco del set: passato alla riconferma così in 6-2 mostra 2
  /// palleggiatori e nasconde i cambi libero (come a inizio partita).
  final SistemaGioco sistemaGioco;

  /// Ruolo ANAGRAFICO per id (dal roster): chi è in campo può avere un ruolo
  /// in campo diverso (copia in `seiCorrenti`), e se esce e rientra altrove
  /// nella stessa visita il confronto del dialog "Gioca da" va fatto col suo
  /// ruolo vero.
  final Map<int, Ruolo> ruoliAnagrafici;

  const SostituzioneScreen({
    super.key,
    required this.match,
    required this.team,
    required this.seiCorrenti,
    required this.panchina,
    required this.liberi,
    required this.palleggiatoreSlotCorrente,
    required this.ruoloCambiLiberoCorrente,
    required this.sistemaGioco,
    this.ruoliAnagrafici = const {},
  });

  @override
  State<SostituzioneScreen> createState() => _SostituzioneScreenState();
}

class _SostituzioneScreenState extends State<SostituzioneScreen> with OrientamentoSchermata<SostituzioneScreen> {
  @override
  List<DeviceOrientation> get orientamentiConsentiti => kOrientamentoLandscape;

  late final Map<String, Player> _pending = Map.of(widget.seiCorrenti);
  late final Map<String, Player> _pendingLiberi = Map.of(widget.liberi);
  // Ruolo in campo scelto per chi entra, per slot — solo se diverso dal suo
  // anagrafico. In `_pending` c'è già la copia col ruolo sostituito, così
  // card e riconferma della formazione lo vedono; questa mappa serve a
  // scriverlo sull'evento di cambio.
  final Map<String, Ruolo> _ruoliInCampoPending = {};
  // Slot P1..P6 oppure chiave libero L1/L2 selezionata come "chi esce".
  String? _selectedSlot;

  bool get _selezioneLibero => _selectedSlot?.startsWith('L') ?? false;

  /// Slot con un cambio pending (giocatore diverso da quello di partenza).
  Set<String> get _slotCambiati => {
    for (final e in _pending.entries)
      if (widget.seiCorrenti[e.key]?.id != e.value.id) e.key,
  };

  /// Chiavi libero con un cambio pending: sostituito, aggiunto (posto vuoto
  /// a inizio visita) o tolto (c'era e ora manca).
  Set<String> get _liberiCambiati => {
    for (final e in _pendingLiberi.entries)
      if (widget.liberi[e.key]?.id != e.value.id) e.key,
    for (final k in widget.liberi.keys)
      if (_pendingLiberi[k] == null) k,
  };

  /// Toglie il libero [key] senza sostituto: si continua senza, con la
  /// giocatrice che sostituiva. Ammesso dal regolamento. È la ✕ sulla card
  /// di un libero non ancora toccato in questa visita.
  void _togliLibero(String key) {
    setState(() {
      _pendingLiberi.remove(key);
      if (_selectedSlot == key) _selectedSlot = null;
    });
  }

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
      _ruoliInCampoPending.remove(slot);
      _selectedSlot = null;
    });
  }

  void _annullaCambioLibero(String key) {
    final originale = widget.liberi[key];
    setState(() {
      if (originale != null) {
        _pendingLiberi[key] = originale;
      } else {
        // Era un INGRESSO (a inizio set quel posto era vuoto): si toglie.
        // Tolto L1, va via anche un L2 aggiunto nella stessa visita — senza
        // L1 il replay lo metterebbe al primo posto, cioè lo promuoverebbe.
        _pendingLiberi.remove(key);
        if (key == 'L1' && widget.liberi['L2'] == null) {
          _pendingLiberi.remove('L2');
        }
      }
      _selectedSlot = null;
    });
  }

  Future<void> _onPanchinaTap(Player candidato) async {
    final anagrafico = widget.ruoliAnagrafici[candidato.id];
    final player = (anagrafico == null || anagrafico == candidato.ruolo)
        ? candidato
        : candidato.copyWith(ruolo: anagrafico);
    final slot = _selectedSlot;
    if (slot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).sostSelezionaUscente),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    // Guardia ridondante (le tile incompatibili sono già disabilitate): un
    // libero entra solo per un libero, e viceversa.
    if (_selezioneLibero) {
      if (player.ruolo != Ruolo.libero) return;
      setState(() {
        _pendingLiberi[slot] = player;
        _selectedSlot = null;
      });
      return;
    }
    if (player.ruolo == Ruolo.libero) return;

    final ruolo = await _chiediRuoloInCampo(player, widget.seiCorrenti[slot]);
    if (ruolo == null || !mounted) return; // dialog chiuso: niente cambio
    setState(() {
      if (ruolo == player.ruolo) {
        _pending[slot] = player;
        _ruoliInCampoPending.remove(slot);
      } else {
        _pending[slot] = player.copyWith(ruolo: ruolo);
        _ruoliInCampoPending[slot] = ruolo;
      }
      _selectedSlot = null;
    });
  }

  /// Con che ruolo gioca chi entra. Si chiede SOLO se il suo ruolo è diverso
  /// da quello di chi esce — caso tipico: una schiacciatrice entrata per un
  /// centrale infortunato, che in campo fa il centrale. Nei cambi ruolo-su-
  /// ruolo nessun dialog. Il ruolo di chi esce è quello EFFETTIVO
  /// (`seiCorrenti` porta già le copie), così anche i cambi a catena tornano.
  /// L'Universale non chiede: riempie da solo l'etichetta mancante (vedi
  /// roleLabelsFor). Ritorna null se il dialog viene chiuso senza scegliere.
  Future<Ruolo?> _chiediRuoloInCampo(Player entra, Player? esce) async {
    if (esce == null ||
        entra.ruolo == esce.ruolo ||
        entra.ruolo == Ruolo.undefined ||
        esce.ruolo == Ruolo.undefined) {
      return entra.ruolo;
    }
    final l = AppLocalizations.of(context);
    return showDialog<Ruolo>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l.sostGiocaDaTitolo(
          '${entra.numero} ${entra.cognome}',
          '${esce.numero} ${esce.cognome}',
        )),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(l.sostGiocaDaDomanda),
          ),
          // Prima e in evidenza il ruolo di chi esce: è il motivo per cui il
          // dialog esiste (il subentrante ne prende il posto tattico).
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, esce.ruolo),
            child: Text(
              ruoloLabel(esce.ruolo, l),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, entra.ruolo),
            child: Text(
              l.lineupRuoloAnagrafico(ruoloLabel(entra.ruolo, l)),
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
    );
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
          sistemaGiocoIniziale: widget.sistemaGioco,
        ),
      ),
    );
    if (risultato == null || !mounted) return; // back: si resta qui
    Navigator.pop<RisultatoSostituzione>(context, (
      seiFinali: Map.of(_pending),
      liberiFinali: Map.of(_pendingLiberi),
      palleggiatoreSlot: risultato.palleggiatoreSlot,
      ruoloCambiLibero: risultato.ruoloCambiLibero,
      ruoliInCampo: Map.of(_ruoliInCampoPending),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cambi = _slotCambiati.length + _liberiCambiati.length;
    // Stessa impaginazione responsive di LineupScreen: su smartphone
    // (altezza bassa) il campo si restringe (flex 5:5) e la panchina prende
    // più spazio; su tablet 6:4 come prima. La panchina non è più a
    // larghezza fissa 320 ma flessibile.
    final compact = MediaQuery.of(context).size.height < 500;
    final courtFlex = compact ? 5 : 6;
    final panelFlex = compact ? 5 : 4;
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        foregroundColor: Colors.white,
        title: Text(l.sostTitolo),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton(
              onPressed: _onAvanti,
              child: Text(l.sostAvanti),
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
            flex: courtFlex,
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
                        title: l.sostInCampo,
                        subtitle: cambi == 0
                            ? l.sostIstruzioni
                            : l.sostCambiDaConfermare(cambi),
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
                      if (_pendingLiberi.isNotEmpty ||
                          widget.liberi.isNotEmpty ||
                          _slotLiberoDaAggiungere != null) ...[
                        const SizedBox(width: 10),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final key in const ['L1', 'L2'])
                              if (_pendingLiberi[key] != null) ...[
                                _buildLiberoCard(key),
                                const SizedBox(height: 10),
                              ] else if (widget.liberi[key] != null) ...[
                                _buildLiberoTolto(key),
                                const SizedBox(height: 10),
                              ] else if (key == _slotLiberoDaAggiungere) ...[
                                _buildLiberoVuoto(key),
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
          Expanded(
            flex: panelFlex,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
                  child: Text(
                    l.sostPanchina,
                    style: const TextStyle(
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
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            l.sostNessunGiocatore,
                            style: const TextStyle(color: Colors.white54),
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

  // Posto libero per far ENTRARE un libero che a inizio set non c'era (il
  // regolamento lo ammette): prima L1, poi L2 — il replay riempie i posti in
  // quell'ordine. Solo se in panchina c'è davvero un libero da far entrare,
  // altrimenti la card sarebbe un vicolo cieco.
  String? get _slotLiberoDaAggiungere {
    final inUso = {for (final p in _pendingLiberi.values) p.id};
    final disponibile = widget.panchina
        .any((p) => p.ruolo == Ruolo.libero && !inUso.contains(p.id));
    if (!disponibile) return null;
    // Un posto che a inizio visita era occupato e ora è vuoto è un libero
    // TOLTO (mostrato come tale, con la ↺ per rimetterlo): non lo si offre
    // anche come "aggiungi". Per mettere un altro libero al suo posto c'è
    // già il cambio libero-per-libero.
    bool occupato(String k) =>
        _pendingLiberi[k] != null || widget.liberi[k] != null;
    if (!occupato('L1')) return 'L1';
    if (!occupato('L2')) return 'L2';
    return null;
  }

  // Card di un libero TOLTO in questa visita: grigia, "Tolto", con la ↺ che
  // lo rimette (vedi _annullaCambioLibero). Non una ✕: lì vorrebbe dire
  // l'opposto di quello che vuol dire sulla card del libero in campo.
  Widget _buildLiberoTolto(String key) {
    final player = widget.liberi[key]!;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 112,
          height: 112,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.grey.shade400,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${player.numero}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black45,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              Text(
                AppLocalizations.of(context).sostLiberoTolto,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
              Text(
                key,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
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
              child: const Icon(Icons.undo, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  // Card vuota "Aggiungi libero": stessa misura di _buildLiberoCard, sfondo
  // azzurro come gli slot vuoti di LineupScreen. Tap = la seleziona, poi un
  // libero dalla panchina la riempie (stesso percorso di un cambio).
  Widget _buildLiberoVuoto(String key) {
    final isSelected = _selectedSlot == key;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onSlotTap(key),
      child: Container(
        width: 112,
        height: 112,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.lightBlueAccent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: Colors.red, width: 3) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, size: 32, color: Colors.black87),
            Text(
              AppLocalizations.of(context).sostAggiungiLibero,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            Text(
              key,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Card del libero accanto al campo (stile analogo alle card slot di
  // CourtView, in scala ridotta): tap = seleziona come "chi esce" (solo un
  // altro libero potrà entrare — vedi _panchinaVisibile); badge ✕ sempre,
  // vedi sotto cosa fa.
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

    // La ✕ c'è SEMPRE: su un libero non toccato in questa visita lo toglie
    // (si gioca senza), su uno cambiato o appena aggiunto annulla il cambio
    // — come la ✕ sulle card del campo e su quelle di LineupScreen.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        card,
        Positioned(
          top: -8,
          right: -8,
          child: GestureDetector(
            onTap: cambiato
                ? () => _annullaCambioLibero(key)
                : () => _togliLibero(key),
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
    // Dimensioni scalate con l'altezza schermo, IDENTICHE alla lista di
    // LineupScreen: compatte su smartphone, piene su tablet (>=760dp).
    final t = ((MediaQuery.of(context).size.height - 400) / 360)
        .clamp(0.0, 1.0);
    double sc(double telefono, double tablet) =>
        telefono + (tablet - telefono) * t;
    return Material(
      color: disabilitato ? Colors.grey.shade300 : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        enabled: !disabilitato,
        dense: t < 0.5,
        minTileHeight: sc(40, 64),
        minVerticalPadding: sc(2, 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: sc(2, 4)),
        leading: CircleAvatar(
          radius: sc(15, 24),
          backgroundColor: avatarColor,
          child: Text(
            '${p.numero}',
            style: TextStyle(
              color: contrastingTextColor(baseColor),
              fontSize: sc(13, 20),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          '${p.cognome} ${p.nome}',
          style: TextStyle(fontSize: sc(14, 20), fontWeight: FontWeight.bold),
        ),
        subtitle: Text(ruoloLabel(p.ruolo, AppLocalizations.of(context)),
            style: TextStyle(fontSize: sc(12, 16))),
        onTap: disabilitato ? null : () => _onPanchinaTap(p),
      ),
    );
  }
}

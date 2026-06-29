import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../models/enums.dart';
import '../../theme/app_colors.dart';
import '../../theme/court_style.dart';

const _kCourtImage = 'assets/images/double_court_bg.png';

// Stesso sfondo/barra superiore di ScoutScreen, duplicati qui per coerenza
// visiva tra le due schermate (vedi scout_screen.dart).
const _kBg = Color(0xFF143E59);
const _kTopBarBg = Color(0xFF0D2738);

// Stessa dimensione/posizionamento del campo in ScoutScreen (58% della
// larghezza disponibile, ancorato in alto con margine fisso 16px — non
// centrato verticalmente) per coerenza visiva tra le due schermate, vedi
// scout_screen.dart.
const double _kCourtWidthFraction = 0.58;
const double _kCourtTopMargin = 16.0;

// Tocco a muro (solo attacco): quanto vicino alla rete (px) per considerarsi
// "a rete", e per quanto tempo bisogna restare in quella fascia prima che
// scatti il tocco — un attraversamento veloce (un attacco normale che passa
// sopra la rete) non deve attivarlo, solo una sosta deliberata.
const double _kToleranzaRete = 24.0;
const Duration _kSoffermamentoRete = Duration(milliseconds: 400);

/// Coordinate normalizzate (0.0-1.0) di una traiettoria, rispetto al campo
/// intero (rete a x=0.5) — stesso spazio di riferimento usato altrove in
/// ScoutScreen per le posizioni dei token. `x1`/`y1`/`x2`/`y2`/`muroX`/
/// `muroY` sono `null` quando si è saltata la traiettoria (back senza
/// disegnare) — il record torna comunque sempre non-null, perché porta
/// anche `tipoBattuta`/`tipoAttacco` (vedi sotto). `muroX`/`muroY` inoltre
/// solo per attacco, `null` se il drag non ha incrociato la rete (nessun
/// tocco a muro simulato) — vedi _TrajectoryScreenState._onPanUpdate.
typedef Traiettoria = ({
  double? x1,
  double? y1,
  double? x2,
  double? y2,
  double? muroX,
  double? muroY,
  TipoBattuta tipoBattuta,
  TipoAttacco tipoAttacco,
});

/// Schermata dedicata per registrare la traiettoria di una battuta/attacco
/// (Fase 3) — campo vuoto, drag dal punto di partenza a quello di arrivo.
/// Mostra anche la scelta del tipo di esecuzione (riga di chip sotto al
/// campo, spostata qui da ScoutScreen per sgombrare il pannello voto) — tipo
/// battuta per la battuta, tipo attacco per l'attacco, mai entrambi.
/// Nessun bottone "Salta"/"Conferma": il back chiude la schermata senza
/// traiettoria (ma porta comunque il tipo scelto, se cambiato — vedi
/// `Traiettoria`), il rilascio del drag la conferma subito
/// (`Navigator.pop(context, risultato)`).
class TrajectoryScreen extends StatefulWidget {
  // Giocatore/fondamentale/voto dell'azione in corso (non ancora
  // registrata — vedi ScoutScreen._registraVoto), solo per mostrare lo
  // stesso banner di ScoutScreen mentre si imposta la traiettoria.
  final Player giocatore;
  final Fondamentale fondamentale;
  final Voto voto;
  // Valore "armato" attuale in ScoutScreen (vedi _tipoBattutaSelezionato
  // là) — null se fondamentale != battuta (chip non mostrate). Il risultato
  // della navigazione riporta il valore finale, eventualmente cambiato.
  // Il tipo attacco non ha un equivalente "iniziale": non resta mai
  // "armato" tra un attacco e l'altro (vedi CLAUDE.md), parte sempre da
  // nonSpecificato.
  final TipoBattuta? tipoBattutaIniziale;

  const TrajectoryScreen({
    super.key,
    required this.giocatore,
    required this.fondamentale,
    required this.voto,
    this.tipoBattutaIniziale,
  });

  @override
  State<TrajectoryScreen> createState() => _TrajectoryScreenState();
}

class _TrajectoryScreenState extends State<TrajectoryScreen> {
  Offset? _inizio;
  // Punto (fisso, una volta rilevato) in cui il drag si è soffermato sulla
  // rete — solo per attacco, simula un tocco a muro che cambia direzione.
  // Una volta impostato non si azzera più finché non riparte un nuovo drag.
  Offset? _puntoMuro;
  Offset? _attuale;

  // Tipo di battuta scelto qui (riga di chip sotto al campo) — inizializzato
  // dal valore "armato" passato da ScoutScreen, riportato indietro nel
  // risultato della navigazione (vedi Traiettoria). Mostrato solo se
  // fondamentale == battuta.
  late TipoBattuta _tipoBattuta;
  bool get _mostraTipoBattuta => widget.fondamentale == Fondamentale.battuta;

  @override
  void initState() {
    super.initState();
    _tipoBattuta = widget.tipoBattutaIniziale ?? TipoBattuta.nonSpecificato;
  }

  void _toggleTipoBattuta(TipoBattuta tipo) {
    setState(() {
      _tipoBattuta = _tipoBattuta == tipo ? TipoBattuta.nonSpecificato : tipo;
    });
  }

  // Tipo di attacco scelto qui (riga di chip sotto al campo) — a differenza
  // della battuta non resta mai "armato" tra un attacco e l'altro (varia
  // spesso colpo su colpo, anche per lo stesso giocatore): parte sempre da
  // nonSpecificato, nessun valore iniziale da ScoutScreen.
  TipoAttacco _tipoAttacco = TipoAttacco.nonSpecificato;
  bool get _mostraTipoAttacco => widget.fondamentale == Fondamentale.attacco;

  void _toggleTipoAttacco(TipoAttacco tipo) {
    setState(() {
      _tipoAttacco = _tipoAttacco == tipo ? TipoAttacco.nonSpecificato : tipo;
    });
  }

  // true mentre il dito è dentro la fascia di tolleranza attorno alla rete
  // (vedi _kToleranzaRete) — usato solo per sapere quando far partire/
  // annullare il timer di soffermamento, non per il disegno.
  bool _inZonaRete = false;
  Timer? _timerMuro;

  bool get _muroConsentito => widget.fondamentale == Fondamentale.attacco;

  @override
  void dispose() {
    _timerMuro?.cancel();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    _timerMuro?.cancel();
    setState(() {
      _inizio = details.localPosition;
      _puntoMuro = null;
      _attuale = details.localPosition;
      _inZonaRete = false;
    });
  }

  // Non basta attraversare la rete: bisogna restare nella fascia di
  // tolleranza attorno a x=xNet per _kSoffermamentoRete prima che scatti il
  // tocco a muro — un passaggio veloce (un attacco normale che la
  // attraversa) non lo attiva. Il dwell-time non può basarsi solo sugli
  // eventi di onPanUpdate (che non arrivano se il dito resta fermo): si usa
  // un Timer avviato all'ingresso nella fascia e annullato se se ne esce
  // prima che scada. Solo per attacco — per la battuta attraversare la
  // rete è normale, non un tocco a muro.
  void _onPanUpdate(DragUpdateDetails details, double xNet) {
    final nuovo = details.localPosition;
    if (_muroConsentito && _puntoMuro == null) {
      final dentroFascia = (nuovo.dx - xNet).abs() <= _kToleranzaRete;
      if (dentroFascia && !_inZonaRete) {
        _inZonaRete = true;
        _timerMuro = Timer(_kSoffermamentoRete, () {
          if (!mounted || _puntoMuro != null) return;
          setState(() {
            _puntoMuro = Offset(xNet, _attuale?.dy ?? nuovo.dy);
          });
        });
      } else if (!dentroFascia && _inZonaRete) {
        _inZonaRete = false;
        _timerMuro?.cancel();
      }
    }
    setState(() => _attuale = nuovo);
  }

  // `inizio`/`attuale`/`puntoMuro` sono in coordinate assolute dello Stack
  // esterno (vedi build) — qui si convertono in normalizzate rispetto al
  // RIQUADRO del campo (courtLeft/courtTop/courtWidth/courtHeight), non
  // rispetto allo schermo intero. Risultato volutamente **non clampato**:
  // un drag iniziato fuori dal campo (es. il battitore dietro la linea di
  // fondo) produce coordinate <0 o >1, esattamente come
  // ScoutScreen._kBattutaP1Position rappresenta il battitore con X
  // negativa.
  void _onPanEnd(DragEndDetails details, double courtLeft, double courtTop,
      double courtWidth, double courtHeight) {
    _timerMuro?.cancel();
    final inizio = _inizio;
    final fine = _attuale;
    if (inizio == null || fine == null) return;
    final muro = _puntoMuro;
    final risultato = (
      x1: (inizio.dx - courtLeft) / courtWidth,
      y1: (inizio.dy - courtTop) / courtHeight,
      x2: (fine.dx - courtLeft) / courtWidth,
      y2: (fine.dy - courtTop) / courtHeight,
      muroX: muro == null ? null : (muro.dx - courtLeft) / courtWidth,
      muroY: muro == null ? null : (muro.dy - courtTop) / courtHeight,
      tipoBattuta: _tipoBattuta,
      tipoAttacco: _tipoAttacco,
    );
    Navigator.pop(context, risultato);
  }

  // Back: salta la traiettoria (coordinate tutte null) ma porta comunque
  // il tipo scelto qui (battuta o attacco), se cambiato — altrimenti
  // andrebbe perso (vedi ScoutScreen._registraVoto).
  void _onBack() {
    Navigator.pop<Traiettoria>(context, (
      x1: null,
      y1: null,
      x2: null,
      y2: null,
      muroX: null,
      muroY: null,
      tipoBattuta: _tipoBattuta,
      tipoAttacco: _tipoAttacco,
    ));
  }

  // Stesso testo/stile/colore di ScoutScreen._descrizioneAzione per il caso
  // TipoAzione.scout (qui l'azione non è ancora un ScoutAction salvato,
  // quindi si formatta direttamente da giocatore/fondamentale/voto).
  Widget _buildBanner() {
    final testo =
        '${widget.giocatore.numero} - ${widget.giocatore.cognome} - ${widget.fondamentale.label}';
    final voto = widget.voto.simbolo;
    final colore = CourtStyle.votoColor(widget.voto);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: colore,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            testo,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              height: 1.0,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            voto,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  // Riga unica con le 4 chip del tipo di battuta (opzionale — vedi
  // _tipoBattuta): tap = seleziona (tap di nuovo sulla stessa = deseleziona,
  // torna a nonSpecificato). Non blocca il flusso: ignorarla e disegnare/
  // saltare la traiettoria registra "nonSpecificato" come sempre.
  Widget _buildRigaTipoBattuta() {
    const tipi = [
      TipoBattuta.dalBasso,
      TipoBattuta.float,
      TipoBattuta.salto,
      TipoBattuta.saltoFloat,
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final tipo in tipi) ...[
          _buildTipoChip(
            label: tipo.label,
            selezionato: _tipoBattuta == tipo,
            onTap: () => _toggleTipoBattuta(tipo),
          ),
          if (tipo != tipi.last) const SizedBox(width: 6),
        ],
      ],
    );
  }

  // Riga unica con le 3 chip del tipo di attacco (opzionale — vedi
  // _tipoAttacco), stessa meccanica/stile della riga battuta.
  Widget _buildRigaTipoAttacco() {
    const tipi = [
      TipoAttacco.forte,
      TipoAttacco.piazzata,
      TipoAttacco.pallonetto,
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final tipo in tipi) ...[
          _buildTipoChip(
            label: tipo.label,
            selezionato: _tipoAttacco == tipo,
            onTap: () => _toggleTipoAttacco(tipo),
          ),
          if (tipo != tipi.last) const SizedBox(width: 6),
        ],
      ],
    );
  }

  // Stesso stile/stato di selezione della chip in ScoutScreen
  // (_buildTipoChip lì, duplicata qui — stesso pattern di altre piccole
  // utility condivise tra le due schermate).
  Widget _buildTipoChip({
    required String label,
    required bool selezionato,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 92,
        height: 52,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: selezionato ? AppColors.brandAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selezionato ? AppColors.brandAccent : Colors.white38,
            width: selezionato ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          // Stessa barra superiore (colore/altezza/stile titolo) di
          // ScoutScreen — qui solo back (niente menu/undo/punteggio, non
          // pertinenti su questa schermata), stesso ancoraggio in basso del
          // titolo.
          Container(
            height: 60,
            color: _kTopBarBg,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                const Positioned(
                  left: 56,
                  right: 56,
                  bottom: 4,
                  child: Text(
                    'Imposta traiettoria',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: _onBack,
                  ),
                ),
              ],
            ),
          ),
          // Spazio equivalente alla riga dei bottoni rapidi di ScoutScreen
          // (Padding verticale 8 + bottoni 44 + 8 = 60px), assente qui —
          // senza questo spacer banner e campo risulterebbero più in alto
          // che in ScoutScreen, a parità di margine interno del campo.
          const SizedBox(height: 60),
          // Stesso banner di ScoutScreen (_buildBannerUltimaAzione), qui
          // sull'azione in corso (non ancora registrata) invece che
          // sull'ultima già salvata — stessa altezza fissa 36 per non far
          // saltare il campo sottostante.
          SizedBox(
            height: 36,
            child: Center(child: _buildBanner()),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, screenConstraints) {
                final courtWidth =
                    screenConstraints.maxWidth * _kCourtWidthFraction;
                final courtHeight = courtWidth / 2; // aspect ratio 1200/600
                final courtLeft =
                    (screenConstraints.maxWidth - courtWidth) / 2;
                const courtTop = _kCourtTopMargin;
                final xNet = courtLeft + courtWidth / 2;
                // GestureDetector sullo Stack ESTERNO (coordinate assolute
                // di questa area, non del solo riquadro campo): un drag che
                // parte fuori dal campo viene comunque catturato — stessa
                // tecnica di ScoutScreen._buildBattitoreTapCatcher per il
                // battitore fuori campo in battuta.
                return GestureDetector(
                  // Senza `opaque`, il default (deferToChild) cattura il
                  // gesto solo se un figlio occupa quel punto — fuori dal
                  // riquadro del campo non c'è nessun figlio lì, quindi un
                  // drag non potrebbe mai INIZIARE da fuori (avrebbe potuto
                  // solo continuare, una volta già agganciato altrove).
                  behavior: HitTestBehavior.opaque,
                  onPanStart: _onPanStart,
                  onPanUpdate: (details) => _onPanUpdate(details, xNet),
                  onPanEnd: (details) => _onPanEnd(
                      details, courtLeft, courtTop, courtWidth, courtHeight),
                  child: Stack(
                    children: [
                      Positioned(
                        top: courtTop,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: SizedBox(
                            width: courtWidth,
                            child: AspectRatio(
                              aspectRatio: 1200 / 600,
                              child:
                                  Image.asset(_kCourtImage, fit: BoxFit.contain),
                            ),
                          ),
                        ),
                      ),
                      // Feedback visivo: appena il dito entra nella fascia
                      // di tolleranza attorno alla rete, una linea gialla
                      // la evidenzia — sparisce se se ne esce prima dei
                      // _kSoffermamentoRete, o appena il tocco scatta (da
                      // lì in poi lo snodo della freccia parla da sé).
                      if (_inZonaRete && _puntoMuro == null)
                        Positioned(
                          left: xNet - 5,
                          top: courtTop,
                          child: Container(
                            width: 10,
                            height: courtHeight,
                            color: Colors.yellow,
                          ),
                        ),
                      if (_inizio != null && _attuale != null)
                        CustomPaint(
                          size: screenConstraints.biggest,
                          painter: _FrecciaTraiettoriaPainter(
                              _inizio!, _attuale!, _puntoMuro),
                        ),
                      // Tipo battuta/attacco: riga orizzontale subito sotto
                      // al campo (spostata qui da ScoutScreen) — mai
                      // entrambe insieme (mostraTipoBattuta/mostraTipoAttacco
                      // sono mutuamente esclusive, dipendono dallo stesso
                      // widget.fondamentale).
                      if (_mostraTipoBattuta || _mostraTipoAttacco)
                        Positioned(
                          top: courtTop + courtHeight + 24,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: _mostraTipoBattuta
                                ? _buildRigaTipoBattuta()
                                : _buildRigaTipoAttacco(),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FrecciaTraiettoriaPainter extends CustomPainter {
  final Offset inizio;
  final Offset fine;
  // Punto di tocco a muro (solo attacco) — se non null, la freccia si
  // disegna a due segmenti (inizio→muro, muro→fine) con uno snodo lì,
  // invece di una linea unica dritta.
  final Offset? puntoMuro;

  _FrecciaTraiettoriaPainter(this.inizio, this.fine, this.puntoMuro);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = CourtStyle.trajectoryArrow
      ..strokeWidth = CourtStyle.trajectoryWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final muro = puntoMuro;
    if (muro != null) {
      canvas.drawLine(inizio, muro, paint);
      canvas.drawLine(muro, fine, paint);
      final muroPaint = Paint()..color = CourtStyle.trajectoryArrow;
      canvas.drawCircle(muro, 5, muroPaint);
    } else {
      canvas.drawLine(inizio, fine, paint);
    }

    // Punta della freccia: due segmenti corti angolati rispetto alla
    // direzione dell'ULTIMO segmento (muro→fine se c'è stato un tocco a
    // muro, altrimenti inizio→fine), ancorati al punto di arrivo.
    final direzione = fine - (muro ?? inizio);
    if (direzione.distance < 1) return;
    final angolo = direzione.direction;
    const lunghezzaPunta = 16.0;
    const apertura = 0.45; // radianti
    final p1 = fine -
        Offset(
          lunghezzaPunta * math.cos(angolo - apertura),
          lunghezzaPunta * math.sin(angolo - apertura),
        );
    final p2 = fine -
        Offset(
          lunghezzaPunta * math.cos(angolo + apertura),
          lunghezzaPunta * math.sin(angolo + apertura),
        );
    canvas.drawLine(fine, p1, paint);
    canvas.drawLine(fine, p2, paint);

    final puntoPaint = Paint()..color = CourtStyle.trajectoryArrow;
    canvas.drawCircle(inizio, 5, puntoPaint);
  }

  @override
  bool shouldRepaint(covariant _FrecciaTraiettoriaPainter oldDelegate) =>
      oldDelegate.inizio != inizio ||
      oldDelegate.fine != fine ||
      oldDelegate.puntoMuro != puntoMuro;
}

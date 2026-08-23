import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../providers/database_provider.dart';
import '../theme/app_spacing.dart';
import 'tutorial_controller.dart';
import 'tutorial_scrim.dart';

/// Il velo del tutorial, montato come **fratello** dello `Scaffold` di
/// `ScoutScreen` (non nel suo body): così copre anche il drawer aperto, e
/// sparisce da solo quando si naviga a una schermata figlia (TrajectoryScreen,
/// EndSetScreen) senza bisogno di gestirne il ciclo di vita.
class TutorialOverlay extends ConsumerStatefulWidget {
  /// Set corrente, per osservare il log delle azioni. `null` finché la
  /// schermata non l'ha caricato (in tutorial è già a DB, quindi è questione
  /// di un frame).
  final int? setId;

  const TutorialOverlay({super.key, required this.setId});

  @override
  ConsumerState<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends ConsumerState<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  Rect? _rectBersaglio;
  // Avviato in initState, NON come `late final`: quello è lazy e, non essendo
  // il ticker letto da nessuna parte se non in dispose, non partirebbe mai —
  // il velo resterebbe pieno, senza buco.
  Ticker? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  /// Insegue la geometria dei target frame per frame. Sembra grezzo ma è la
  /// soluzione che costa meno: copre gratis rotazione della squadra
  /// (AnimatedPositioned, 500ms), apertura del drawer, comparsa del pannello
  /// voto e cambi di orientamento, senza un solo hook di layout dentro
  /// `ScoutScreen`. Gira solo durante il tutorial.
  void _tick(Duration _) {
    if (!mounted) return;
    final controller = ref.read(tutorialControllerProvider.notifier);
    final passo = controller.passo;

    var rect = controller.registro.rectOf(passo?.bersaglio);
    // Bersaglio secondario: un solo buco che li contiene entrambi.
    final secondo = controller.registro.rectOf(passo?.bersaglioSecondario);
    if (rect != null && secondo != null) rect = rect.expandToInclude(secondo);
    if (_diverso(rect, _rectBersaglio)) {
      setState(() => _rectBersaglio = rect);
    }

    // "Il passo è finito quando compare quest'altro elemento": è così che si
    // riconosce l'apertura del pannello voto senza che ScoutScreen esponga il
    // proprio stato interno.
    final atteso = passo?.avanzaSuComparsaDi;
    if (atteso != null && controller.registro.rectOf(atteso) != null) {
      controller.rectComparso(atteso);
    }
  }

  static bool _diverso(Rect? a, Rect? b) {
    if ((a == null) != (b == null)) return true;
    if (a == null || b == null) return false;
    return (a.left - b.left).abs() > 0.5 ||
        (a.top - b.top).abs() > 0.5 ||
        (a.width - b.width).abs() > 0.5 ||
        (a.height - b.height).abs() > 0.5;
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  void _esci() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final stato = ref.watch(tutorialControllerProvider);
    final controller = ref.read(tutorialControllerProvider.notifier);

    // Fine della sequenza: si esce dallo scout, il launcher pensa a cancellare
    // la partita di prova.
    ref.listen(tutorialControllerProvider, (prima, dopo) {
      if (dopo.completato && !(prima?.completato ?? false)) _esci();
    });

    // Azioni realmente scritte a DB: l'unica sorgente affidabile per dire "ha
    // fatto quello che gli ho chiesto" — e l'unica che intercetta anche un
    // undo (il log si accorcia).
    final setId = widget.setId;
    if (setId != null) {
      ref.listen(scoutAzioniStreamProvider(setId), (_, dopo) {
        final log = dopo.value;
        if (log != null) controller.logAggiornato(log);
      });
    }

    final passo = controller.passo;
    if (!stato.attivo || passo == null) return const SizedBox.shrink();

    // Campo libero: né velo né card — coprirebbero entrambi la traiettoria da
    // tracciare. L'istruzione la mostra ScoutScreen nella fascia centrale
    // della riga dei bottoni rapidi (vedi PassoTutorial.campoLibero).
    if (passo.campoLibero) return const SizedBox.shrink();

    return Stack(
      fit: StackFit.expand,
      children: [
        TutorialScrim(buco: _rectBersaglio),
        _cardPasso(passo),
      ],
    );
  }

  /// La card di spiegazione, nella fascia libera accanto al buco.
  ///
  /// Di default sceglie tra SOPRA e SOTTO (la card è più larga che alta, quindi
  /// di lato ci sta male). Il passo può però imporre un lato con
  /// [PassoTutorial.lato]: serve quando il bersaglio fa parte di un gruppo da
  /// non coprire — sul pulsante di un voto, una card sopra o sotto nasconde
  /// gli altri quattro della colonna.
  Widget _cardPasso(PassoTutorial passo) {
    const gap = AppSpacing.lg; // distacco dal buco
    const bordo = AppSpacing.md; // margine dai bordi schermo
    final schermo = MediaQuery.sizeOf(context);
    final buco = _rectBersaglio;

    // Larghezza preferita, senza mai eccedere la fascia in cui va messa.
    //
    // Due misure, non una: quando la card sta in una fascia ORIZZONTALE (sopra
    // o sotto al buco, o al centro senza buco) la larghezza disponibile è
    // tutto lo schermo, e restare al 42% la faceva stretta e alta — su
    // telefono il testo non ci stava e veniva tagliato in fondo. Larga, lo
    // stesso testo occupa meno righe e la fascia lo contiene.
    // Di LATO invece la fascia è davvero stretta, e il `min` qui sotto la
    // riduce comunque: lì la misura piccola resta quella giusta.
    double larghezzaIn(double fascia, {bool fasciaOrizzontale = false}) =>
        math.min(
          fasciaOrizzontale
              ? (schermo.width * 0.62).clamp(300.0, 620.0)
              : (schermo.width * 0.42).clamp(280.0, 460.0),
          math.max(200.0, fascia),
        );

    final altezzaPiena = schermo.height - bordo * 2;
    if (buco == null) {
      return Center(
        child: _card(
            passo,
            larghezzaIn(schermo.width - bordo * 2, fasciaOrizzontale: true),
            altezzaPiena),
      );
    }

    final sopra = buco.top - gap - bordo;
    final sotto = schermo.height - buco.bottom - gap - bordo;
    final sinistra = buco.left - gap - bordo;
    final destra = schermo.width - buco.right - gap - bordo;

    // Sotto questa soglia una card non ci sta: titolo, testo e bottone
    // vogliono almeno tanto spazio.
    const altezzaMinima = 200.0;

    final aSinistra = switch (passo.lato) {
      LatoCard.sinistra => true,
      LatoCard.destra => false,
      // In automatico si passa di lato solo quando in verticale non c'è
      // davvero posto: capita con i bersagli alti quanto lo schermo, come il
      // registro delle azioni.
      LatoCard.automatico when math.max(sopra, sotto) < altezzaMinima &&
              math.max(sinistra, destra) > math.max(sopra, sotto) =>
        sinistra >= destra,
      _ => null,
    };
    if (aSinistra != null) {
      final fascia = aSinistra ? sinistra : destra;
      return Positioned(
        left: aSinistra ? bordo : buco.right + gap,
        right: aSinistra ? schermo.width - buco.left + gap : bordo,
        top: bordo,
        bottom: bordo,
        child: Align(child: _card(passo, larghezzaIn(fascia), altezzaPiena)),
      );
    }

    final inBasso = switch (passo.lato) {
      LatoCard.sopra => false,
      LatoCard.sotto => true,
      _ => sotto >= sopra,
    };
    return Positioned(
      left: bordo,
      right: bordo,
      top: inBasso ? buco.bottom + gap : null,
      bottom: inBasso ? null : schermo.height - buco.top + gap,
      child: Align(
        child: _card(
            passo,
            larghezzaIn(schermo.width - bordo * 2, fasciaOrizzontale: true),
            inBasso ? sotto : sopra),
      ),
    );
  }

  Widget _card(PassoTutorial passo, double larghezza, double altezzaMax) =>
      _CardTutorial(
        passo: passo,
        larghezza: larghezza,
        altezzaMax: math.max(altezzaMax, 120),
        onAvanti: ref.read(tutorialControllerProvider.notifier).avantiManuale,
        onEsci: _esci,
      );
}

/// Pulsante che apre un indirizzo fuori dall'app (la guida sul web, il client
/// di posta). Se il dispositivo non sa gestirlo lo dice, invece di non fare
/// nulla — stesso comportamento di `AboutScreen`.
class _BottoneLink extends StatelessWidget {
  final IconData icona;
  final String etichetta;
  final Uri uri;

  const _BottoneLink({
    required this.icona,
    required this.etichetta,
    required this.uri,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        final l = AppLocalizations.of(context);
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!ok) {
          messenger.showSnackBar(
            SnackBar(content: Text(l.tutorialLinkNonApribile('$uri'))),
          );
        }
      },
      icon: Icon(icona, size: 18),
      label: Text(etichetta),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white38),
      ),
    );
  }
}

class _CardTutorial extends StatelessWidget {
  final PassoTutorial passo;
  final double larghezza;

  /// Spazio verticale disponibile: oltre questo il testo scorre invece di
  /// sbordare (le spiegazioni lunghe — la legenda dei voti — non ci stanno
  /// tutte su uno schermo basso in landscape).
  final double altezzaMax;
  final VoidCallback onAvanti;
  final VoidCallback onEsci;

  const _CardTutorial({
    required this.passo,
    required this.larghezza,
    required this.altezzaMax,
    required this.onAvanti,
    required this.onEsci,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: const Color(0xFF0D2738),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      elevation: 8,
      child: Container(
        width: larghezza,
        constraints: BoxConstraints(maxHeight: altezzaMax),
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    passo.titolo ?? '',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: Colors.white),
                  ),
                ),
                IconButton(
                  onPressed: onEsci,
                  icon: const Icon(Icons.close, color: Colors.white70),
                  tooltip: AppLocalizations.of(context).tutorialEsci,
                ),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: Text(
                  passo.testo,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    height: 1.35,
                  ),
                ),
              ),
            ),
            if (passo.url != null || passo.mail != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  if (passo.url != null)
                    _BottoneLink(
                      icona: Icons.open_in_new,
                      etichetta: AppLocalizations.of(context).tutorialApriGuida,
                      uri: Uri.parse(passo.url!),
                    ),
                  if (passo.mail != null)
                    _BottoneLink(
                      icona: Icons.mail_outline,
                      etichetta: AppLocalizations.of(context).tutorialScrivici,
                      uri: Uri(scheme: 'mailto', path: passo.mail!),
                    ),
                ],
              ),
            ],
            if (passo.avanzaConBottone) ...[
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: onAvanti,
                  child: Text(
                    passo.etichettaBottone ??
                        AppLocalizations.of(context).tutorialAvanti,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

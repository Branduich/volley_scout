import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

// Ri-esportato così le schermate che usano il mixin possono annotare il tipo
// del getter `orientamentiConsentiti` con il solo import di questo file.
export 'package:flutter/services.dart' show DeviceOrientation;

/// Gestione dell'orientamento **per-schermata**. L'app è nata solo-landscape
/// (imposto in `main.dart`), ma alcune schermate di setup (squadre/partite)
/// sono più comode anche in portrait. Invece di un lock globale (manifest o
/// `main`), ogni schermata dichiara gli orientamenti che accetta e li applica
/// entrando; il [orientamentoRouteObserver] li **ri-applica** quando la
/// schermata torna in primo piano (una route sopra viene chiusa), così un
/// eventuale orientamento impostato da una schermata figlia non "resta
/// appiccicato" tornando indietro.
///
/// Uso: `class _X extends State<X> with OrientamentoSchermata<X>` e override di
/// [orientamentiConsentiti] (es. [kOrientamentoLandscape] per il campo,
/// [kOrientamentoTutti] per il setup). Le schermate che non usano il mixin
/// restano sull'ultimo orientamento impostato (default di avvio: landscape).

/// Landscape (entrambi i versi) — schermate col campo e tutto ciò che è
/// disegnato a misura fissa per l'orizzontale.
const List<DeviceOrientation> kOrientamentoLandscape = [
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
];

/// Tutti gli orientamenti (portrait + landscape) — schermate di setup che
/// reflowano bene anche in verticale.
const List<DeviceOrientation> kOrientamentoTutti = DeviceOrientation.values;

/// Da registrare in `MaterialApp(navigatorObservers: [orientamentoRouteObserver])`.
/// Notifica il mixin quando la sua route torna visibile (`didPopNext`).
final RouteObserver<PageRoute<dynamic>> orientamentoRouteObserver =
    RouteObserver<PageRoute<dynamic>>();

mixin OrientamentoSchermata<T extends StatefulWidget> on State<T>
    implements RouteAware {
  /// Gli orientamenti che questa schermata accetta.
  List<DeviceOrientation> get orientamentiConsentiti;

  /// Schermata a **schermo intero**: barre di sistema nascoste, con ritorno
  /// temporaneo allo swipe dal bordo (`immersiveSticky`). Di default lo sono
  /// tutte le schermate solo-landscape, cioè quelle costruite attorno al campo.
  ///
  /// Serve perché `targetSdk` 35+ impone l'edge-to-edge: il sistema non
  /// rimpicciolisce più la finestra e l'app disegna SOTTO le barre. Su un
  /// telefono con navigazione a 3 pulsanti la barra finiva sopra il campo.
  /// Scartato `SafeArea`, che risolverebbe togliendo però ~48dp proprio dove
  /// lo spazio è più prezioso: nascondere le barre ne fa guadagnare invece di
  /// perderne.
  bool get schermoIntero =>
      listEquals(orientamentiConsentiti, kOrientamentoLandscape);

  void _applica() {
    SystemChrome.setPreferredOrientations(orientamentiConsentiti);
    // Ripristinato a `edgeToEdge` dalle schermate normali: senza, uscendo da
    // una schermata a schermo intero le barre resterebbero nascoste.
    SystemChrome.setEnabledSystemUIMode(
      schermoIntero ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
    // Ri-applico dopo il primo frame: una transizione portrait→landscape
    // richiesta MENTRE la route sta entrando (push da una schermata che
    // permetteva il portrait) a volte non attecchisce — la route uscente è
    // ancora attiva e "vince". A route insediata la richiesta va a segno.
    // (Su alcuni emulatori senza questo la schermata campo restava in portrait.)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) SystemChrome.setPreferredOrientations(orientamentiConsentiti);
    });
  }

  @override
  void initState() {
    super.initState();
    _applica();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      orientamentoRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    orientamentoRouteObserver.unsubscribe(this);
    super.dispose();
  }

  // Ri-applica l'orientamento quando questa schermata torna in primo piano
  // (una route figlia è stata chiusa) — la schermata sopra potrebbe averne
  // impostato uno diverso.
  @override
  void didPopNext() => _applica();

  @override
  void didPush() {}

  @override
  void didPop() {}

  @override
  void didPushNext() {}
}

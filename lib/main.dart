import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kDebugMode, TargetPlatform, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/revenuecat.dart';
import 'data/default_categorie_seeder.dart';
import 'data/default_team_seeder.dart';
import 'l10n/app_localizations.dart';
import 'providers/database_provider.dart';
import 'providers/lingua_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/campionato/campionato_screen.dart';
import 'screens/matches/matches_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/teams/teams_screen.dart';
import 'theme/app_theme.dart';
import 'tutorial/avvia_tutorial.dart';
import 'tutorial/tutorial_sandbox.dart';
import 'utils/orientamento.dart';
import 'widgets/debug_paint_toggle.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // SharedPreferences caricato PRIMA di runApp e iniettato con override:
  // le impostazioni si leggono in modo sincrono ovunque (vedi
  // settings_provider.dart).
  final prefs = await SharedPreferences.getInstance();
  // Orientamento di avvio: seguo il device (Home accetta il portrait). Le
  // singole schermate lo restringono via mixin (vedi utils/orientamento.dart):
  // setup/impostazioni/home = tutti, campo/report = solo landscape.
  await SystemChrome.setPreferredOrientations(kOrientamentoTutti);
  // RevenueCat: configura la SDK prima di runApp (solo Android per ora — la
  // key è quella Android; iOS avrà la sua). try/catch: un fallimento non
  // deve bloccare l'avvio — lo statoPremiumProvider resta free finché la SDK
  // non risponde. Gli acquisti/offerte reali funzionano solo con l'app su
  // una traccia Play + license testers (vedi docs/TODO_strada_A.md).
  if (defaultTargetPlatform == TargetPlatform.android) {
    try {
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.info);
      await Purchases.configure(PurchasesConfiguration(kRevenueCatAndroidKey));
    } catch (e) {
      debugPrint('RevenueCat: configure fallita: $e');
    }
  }
  // Container condiviso: lo stesso AppDatabase serve sia al seeding della
  // squadra di default (prima di runApp) sia all'app. Uso
  // UncontrolledProviderScope per non crearne un secondo.
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  // Le categorie di default vanno seminate PRIMA della squadra: il roster
  // demo usa una categoria che deve già esistere in lista.
  final db = container.read(appDatabaseProvider);
  await seedDefaultCategorieSeNecessario(db, prefs);
  await seedDefaultTeamSeNecessario(db, prefs);
  // Rete di sicurezza: la partita di prova del tutorial si cancella all'uscita
  // dal tutorial stesso, ma se l'app viene chiusa a metà resterebbe a DB. Qui
  // sparisce prima che l'utente possa vederla nelle liste.
  await TutorialSandbox.pulisci(db, prefs);

  runApp(UncontrolledProviderScope(
    container: container,
    child: const VolleyScoutApp(),
  ));
}

class VolleyScoutApp extends ConsumerWidget {
  const VolleyScoutApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // locale: null = segue il dispositivo (tra le supportedLocales, fallback
    // inglese); altrimenti la lingua forzata da Impostazioni.
    final locale = ref.watch(linguaProvider);
    return MaterialApp(
      title: 'Volley Stratego',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: locale,
      // Osserva le route per ri-applicare l'orientamento quando una schermata
      // torna in primo piano (vedi utils/orientamento.dart).
      navigatorObservers: [orientamentoRouteObserver],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Su smartphone (schermo basso) rimpicciolisco l'AppBar di TUTTE le
      // schermate — altezza barra + font del titolo — per dare più spazio
      // verticale al contenuto. Fatto qui (MaterialApp.builder) così vale
      // globalmente senza toccare ogni schermata; su tablet resta invariato.
      // Riduco `textTheme.titleLarge` (il default M3 del titolo AppBar) e NON
      // `appBarTheme.titleTextStyle`: così il `foregroundColor` continua a
      // essere applicato al titolo anche sulle AppBar scure a testo bianco
      // (LineupScreen/FormationConfig/Sostituzione) — vedi app_bar.dart:983.
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        // Margine per le barre di sistema, per TUTTE le schermate. Con
        // l'edge-to-edge imposto da Android 15 (vedi convenzione 2) la
        // finestra non viene più rimpicciolita dal sistema: senza questo, il
        // contenuto in fondo — l'ultima voce di un menu, un bottone — finisce
        // dietro alla barra di navigazione, e in landscape dietro a quella
        // laterale. `top: false` perché la barra di stato la gestisce già
        // l'AppBar da sé. Sulle schermate a schermo intero gli inset sono
        // zero, quindi lì non cambia nulla.
        child = SafeArea(top: false, child: child);
        final theme = Theme.of(context);
        if (MediaQuery.of(context).size.height >= 500) return child;
        return Theme(
          data: theme.copyWith(
            appBarTheme: theme.appBarTheme.copyWith(toolbarHeight: 46),
            textTheme: theme.textTheme.copyWith(
              titleLarge: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
            ),
            // FilledButton compatti: senza, i bottoni nelle `actions`
            // dell'AppBar (Avanti/Conferma/Inizia scout) restano ~50px
            // (padding + tap-target minimo 48) e vengono tagliati nella barra
            // da 46. shrinkWrap permette al bottone di scendere sotto i 48px.
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          child: child,
        );
      },
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with OrientamentoSchermata<HomeScreen> {
  // Layout responsive: 2 colonne in landscape, immagine sopra + bottoni sotto
  // in portrait — così è comoda in entrambi gli orientamenti (vedi build).
  @override
  List<DeviceOrientation> get orientamentiConsentiti => kOrientamentoTutti;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Area principale: immagine brand a tutto riquadro finché non si decide
    // quali dati mostrare qui. BoxFit.cover riempie l'area ritagliando i bordi:
    // il logo resta centrato sia su tablet sia su telefono.
    final immagine = Image.asset(
      'assets/images/main_image.png',
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
    // Blocco dei bottoni: i principali centrati (Spacer simmetrici),
    // "Impostazioni" staccata in fondo.
    //
    // Deve starci TUTTO senza scorrere, anche su telefono: i bottoni si
    // accorciano quanto basta per entrare nell'altezza disponibile, mai sotto
    // i 44dp (il minimo per un bersaglio da toccare) e mai sopra i 64 di
    // partenza — su tablet, dove lo spazio avanza, restano quindi identici a
    // prima. Se nemmeno a 44 ci stanno (schermo minuscolo) la colonna torna a
    // scorrere invece di sbordare: il giro ConstrainedBox(minHeight) +
    // IntrinsicHeight serve a non perdere gli Spacer, che dentro a uno scroll
    // non avrebbero un'altezza su cui distribuirsi.
    final tutorialVisibile = ref.watch(impostazioniProvider).tutorialVisibile;
    final bottoni = LayoutBuilder(
      builder: (context, vincoli) {
        final quanti = tutorialVisibile ? 5 : 4;
        // Altezza dei bottoni con margini e distacchi dati. I distacchi fissi
        // sono `quanti - 2`: l'ultimo bottone è staccato dal gruppo dalla
        // separazione, non da un SizedBox.
        double altezzaCon(double padding, double distanza, double separazione) =>
            (vincoli.maxHeight -
                padding * 2 -
                (quanti - 2) * distanza -
                separazione) /
            quanti;

        // Si stringono PRIMA gli spazi e solo dopo i bottoni: perdere margine
        // non si nota, bottoni bassi sì (e sono da centrare col dito).
        var padding = 24.0;
        var distanza = 16.0; // fra i bottoni del gruppo centrale
        // Distacco MINIMO di "Impostazioni" dal gruppo. Gli Spacer da soli non
        // bastano: quando lo spazio avanzato è poco se lo dividono in due e i
        // due bottoni finiscono appiccicati.
        var separazione = 24.0;
        if (altezzaCon(padding, distanza, separazione) < 64) {
          padding = 12.0;
          distanza = 8.0;
          separazione = 14.0;
        }
        final altezza =
            altezzaCon(padding, distanza, separazione).clamp(44.0, 64.0);
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: vincoli.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  children: [
                    const Spacer(),
                    _MenuButton(
                      icon: Icons.groups,
                      label: l.homeTeamsSetup,
                      altezza: altezza,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TeamsScreen()),
                      ),
                    ),
                    SizedBox(height: distanza),
                    _MenuButton(
                      icon: Icons.event_note,
                      label: l.homeMatches,
                      altezza: altezza,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          settings: const RouteSettings(name: '/matches'),
                          builder: (_) => const MatchesScreen(),
                        ),
                      ),
                    ),
                    SizedBox(height: distanza),
                    _MenuButton(
                      icon: Icons.emoji_events,
                      label: l.homeCampionato,
                      altezza: altezza,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CampionatoScreen()),
                      ),
                    ),
                    // Nascondibile da Impostazioni: chi ha già imparato non se
                    // la ritrova per sempre nel menu.
                    if (tutorialVisibile) ...[
                      SizedBox(height: distanza),
                      _MenuButton(
                        icon: Icons.school,
                        label: l.homeTutorial,
                        altezza: altezza,
                        onTap: () => avviaTutorial(context, ref),
                      ),
                    ],
                    const Spacer(),
                    SizedBox(height: separazione),
                    _MenuButton(
                      icon: Icons.settings,
                      label: l.homeSettings,
                      altezza: altezza,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Volley Stratego'),
        actions: const [DebugPaintToggle()],
      ),
      body: OrientationBuilder(
        builder: (context, orientation) {
          // Landscape: immagine a sinistra (2/3), bottoni a destra (1/3) — il
          // menu ha comunque tutta l'altezza dello schermo.
          // Portrait: metà e metà. Un terzo non basta più da quando le voci
          // sono cinque, e sarebbe l'immagine a guadagnarci uno spazio che non
          // le serve: è decorativa, il menu no.
          final orizzontale = orientation == Orientation.landscape;
          final children = [
            Expanded(flex: 2, child: immagine),
            Expanded(flex: orizzontale ? 1 : 2, child: bottoni),
          ];
          return orientation == Orientation.landscape
              ? Row(children: children)
              : Column(children: children);
        },
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Calcolata da chi lo ospita per far entrare tutto il menu senza scorrere
  /// (vedi HomeScreen): 64 quando lo spazio c'è, meno su schermo piccolo.
  final double altezza;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.altezza = 64,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: altezza,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontSize: 16)),
        // Sotto i 48dp il tap-target di Material impedirebbe al bottone di
        // rimpicciolirsi davvero: senza shrinkWrap resterebbe alto 48.
        style: FilledButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

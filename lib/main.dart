import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kDebugMode, TargetPlatform, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/revenuecat.dart';
import 'data/default_team_seeder.dart';
import 'l10n/app_localizations.dart';
import 'providers/database_provider.dart';
import 'providers/lingua_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/matches/matches_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/teams/teams_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/debug_paint_toggle.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // SharedPreferences caricato PRIMA di runApp e iniettato con override:
  // le impostazioni si leggono in modo sincrono ovunque (vedi
  // settings_provider.dart).
  final prefs = await SharedPreferences.getInstance();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
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
  await seedDefaultTeamSeNecessario(container.read(appDatabaseProvider), prefs);

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
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Volley Stratego'),
        actions: const [DebugPaintToggle()],
      ),
      body: Row(
        children: [
          // Area principale: immagine brand a tutto riquadro finché non si
          // decide quali dati mostrare qui. BoxFit.cover riempie l'area (2/3
          // della larghezza landscape × altezza piena) ritagliando i bordi:
          // il logo resta centrato sia su tablet (quasi quadrato) sia su
          // telefono (largo).
          Expanded(
            flex: 2,
            child: Image.asset(
              'assets/images/main_image.png',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          // Colonna dei tre bottoni
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Spacer simmetrici: i due bottoni principali restano
                  // centrati, "Impostazioni" sta in fondo, staccata.
                  const Spacer(),
                  _MenuButton(
                    icon: Icons.groups,
                    label: l.homeTeamsSetup,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TeamsScreen()),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _MenuButton(
                    icon: Icons.event_note,
                    label: l.homeMatches,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        settings: const RouteSettings(name: '/matches'),
                        builder: (_) => const MatchesScreen(),
                      ),
                    ),
                  ),
                  const Spacer(),
                  _MenuButton(
                    icon: Icons.settings,
                    label: l.homeSettings,
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
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}

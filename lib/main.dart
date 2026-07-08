import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  runApp(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const VolleyScoutApp(),
  ));
}

class VolleyScoutApp extends StatelessWidget {
  const VolleyScoutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Volley Stratego',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Volley Stratego'),
        actions: const [DebugPaintToggle()],
      ),
      body: Row(
        children: [
          // Area principale vuota (per ora)
          Expanded(
            flex: 2,
            child: Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Center(
                child: Text(
                  'Area principale',
                  style: TextStyle(fontSize: 18, color: Colors.black54),
                ),
              ),
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
                    label: 'Setup squadre',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TeamsScreen()),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _MenuButton(
                    icon: Icons.event_note,
                    label: 'Gestione partite',
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
                    label: 'Impostazioni',
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

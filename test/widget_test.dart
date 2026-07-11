import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volley_scout/main.dart';
import 'package:volley_scout/providers/settings_provider.dart';

void main() {
  testWidgets('Home screen is rendered', (WidgetTester tester) async {
    // VolleyScoutApp legge linguaProvider (→ sharedPreferencesProvider):
    // serve il ProviderScope con l'override. 'app.lingua'='it' forza la
    // lingua italiana, così le stringhe localizzate corrispondono.
    SharedPreferences.setMockInitialValues({'app.lingua': 'it'});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const VolleyScoutApp(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Volley Stratego'), findsOneWidget);
    expect(find.text('Setup squadre'), findsOneWidget);
  });
}

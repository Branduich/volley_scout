// Tocchi persi nello scout (segnalazione dal campo, 2026-11-15).
//
// Un tocco su un giocatore col dito che scivola un po' — normale a velocità di
// partita — finiva in una zona morta: il riconoscitore del tap di Flutter lo
// annulla oltre 18 px (kTouchSlop), il nostro trascinamento partiva solo oltre
// la soglia della traiettoria (~30 px su tablet). In mezzo non succedeva
// niente. Ora tocco e trascinamento li decide un'unica soglia nostra (vedi
// _tokenConTrascinamento in scout_screen.dart).
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volley_scout/data/database.dart';
import 'package:volley_scout/l10n/app_localizations.dart';
import 'package:volley_scout/models/enums.dart';
import 'package:volley_scout/providers/database_provider.dart';
import 'package:volley_scout/providers/settings_provider.dart';
import 'package:volley_scout/screens/live/scout_screen.dart';
import 'package:volley_scout/theme/app_theme.dart';
import 'package:volley_scout/tutorial/tutorial_sandbox.dart';

import '../layout_dimensioni_test.dart' show caricaFontApp;

/// Monta lo scout sulla partita di prova del tutorial, su un tablet in
/// orizzontale: lì la soglia della traiettoria è la più alta (~30 px), quindi
/// la zona morta era la più larga.
Future<void> _montaScout(WidgetTester tester) async {
  tester.view.physicalSize = const Size(2560, 1600);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({'app.lingua': 'it'});
  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabase.perTest(NativeDatabase.memory());
  addTearDown(db.close);

  final dati = await TutorialSandbox.semina(
    db,
    prefs,
    lookupAppLocalizations(const Locale('it')),
  );
  final f = (await MatchSetRepository(db).caricaFormazione(dati.setId))!;

  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      appDatabaseProvider.overrideWithValue(db),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ScoutScreen(
        match: dati.match,
        team: dati.team,
        palleggiatoreSlot: f.palleggiatoreSlot,
        assignments: f.assignments,
        ruoloCambiLibero: f.ruoloCambiLibero,
        sistemaGioco: f.sistemaGioco ?? SistemaGioco.palleggiatoreUnico,
      ),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _smonta(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

/// Il pannello voto è aperto se si vede la colonna dei voti: il `#` compare
/// solo lì.
Finder get _pannelloAperto => find.text('#');

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await caricaFontApp();
  });

  testWidgets('un tocco col dito che scivola di 22 px apre il pannello',
      (tester) async {
    try {
      await _montaScout(tester);
      expect(_pannelloAperto, findsNothing);

      // Anna Bianchi, numero 4: è al servizio (vedi TutorialSandbox). 22 px
      // è oltre i 18 di Flutter e sotto la soglia della traiettoria.
      final centro = tester.getCenter(find.text('4'));
      final gesto = await tester.startGesture(centro);
      await tester.pump(const Duration(milliseconds: 30));
      await gesto.moveBy(const Offset(22, 0));
      await tester.pump(const Duration(milliseconds: 30));
      await gesto.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(_pannelloAperto, findsWidgets);
    } finally {
      await _smonta(tester);
    }
  });

  testWidgets('un tocco fermo apre il pannello come prima', (tester) async {
    try {
      await _montaScout(tester);

      await tester.tap(find.text('4'), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(_pannelloAperto, findsWidgets);
    } finally {
      await _smonta(tester);
    }
  });
}

// Navigazione di fine set / fine partita.
//
// Il bug che protegge: "Prossimo Set" faceva un push sopra le schermate del
// set appena chiuso, che restavano vive nello stack. A fine partita di cinque
// set c'erano cinque catene Lineup/Config/Scout/Fine da smontare, e ogni
// ScoutScreen si ricostruiva a ogni frame del ritorno delle barre di sistema:
// l'app sembrava congelata per secondi (segnalazione dal campo, 2026-10).
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
import 'package:volley_scout/screens/live/end_set_screen.dart';
import 'package:volley_scout/screens/live/lineup_screen.dart';
import 'package:volley_scout/screens/live/scout_screen.dart';
import 'package:volley_scout/screens/matches/matches_screen.dart';
import 'package:volley_scout/theme/app_theme.dart';
import 'package:volley_scout/tutorial/tutorial_sandbox.dart';
import 'package:volley_scout/utils/orientamento.dart';

/// Monta lo stack reale MatchesScreen -> ScoutScreen -> EndSetScreen sulla
/// partita di prova del tutorial e restituisce il database.
Future<AppDatabase> _montaFineSet(WidgetTester tester) async {
  tester.view.physicalSize = const Size(2400, 1080);
  tester.view.devicePixelRatio = 2.625;
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

  final navKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      appDatabaseProvider.overrideWithValue(db),
    ],
    child: MaterialApp(
      navigatorKey: navKey,
      theme: AppTheme.light,
      locale: const Locale('it'),
      navigatorObservers: [orientamentoRouteObserver],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(),
    ),
  ));

  // Il primo frame di una route nuova la tiene fuori scena (misura per gli
  // Hero) e l'animazione d'ingresso parte da quello successivo: un solo
  // `pump` con durata lascerebbe la schermata ancora offstage.
  Future<void> entra() async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  navKey.currentState!.push(MaterialPageRoute(
    settings: const RouteSettings(name: '/matches'),
    builder: (_) => const MatchesScreen(),
  ));
  await entra();
  navKey.currentState!.push(MaterialPageRoute(
    builder: (_) => ScoutScreen(
      match: dati.match,
      team: dati.team,
      palleggiatoreSlot: f.palleggiatoreSlot,
      assignments: f.assignments,
      ruoloCambiLibero: f.ruoloCambiLibero,
      sistemaGioco: f.sistemaGioco ?? SistemaGioco.palleggiatoreUnico,
    ),
  ));
  await entra();
  navKey.currentState!.push(MaterialPageRoute(
    builder: (_) => EndSetScreen(match: dati.match, team: dati.team),
  ));
  await entra();
  return db;
}

/// Tocca [bottone] di EndSetScreen e conferma il dialog.
Future<void> _toccaEConferma(WidgetTester tester, String bottone) async {
  await tester.tap(find.text(bottone));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(find.text('Conferma'));
  // L'UPDATE della partita è una vera scrittura su SQLite: va lasciata
  // completare fuori dall'orologio finto.
  await tester.runAsync(() => Future<void>.delayed(
        const Duration(milliseconds: 50),
      ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// Smontaggio dentro il test: vedi `verificaLayout` in
/// layout_dimensioni_test.dart per il perché (timer pendente di drift).
Future<void> _smonta(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

void main() {
  // try/finally: se un'asserzione fallisce PRIMA dello smontaggio, il timer
  // pendente di drift appende il processo per minuti invece di far fallire
  // il test in fretta.
  testWidgets('"Prossimo Set" rimuove le schermate del set chiuso',
      (tester) async {
    try {
      await _montaFineSet(tester);

      await _toccaEConferma(tester, 'Prossimo Set');

      expect(find.byType(LineupScreen), findsOneWidget);
      // `skipOffstage: false` conta anche le route coperte: è proprio lì che
      // restavano le schermate del set precedente.
      expect(find.byType(ScoutScreen, skipOffstage: false), findsNothing);
      expect(find.byType(EndSetScreen, skipOffstage: false), findsNothing);
      expect(find.byType(MatchesScreen, skipOffstage: false), findsOneWidget);
    } finally {
      await _smonta(tester);
    }
  });

  testWidgets('"Fine Partita" torna alla lista e chiude la partita',
      (tester) async {
    try {
      final db = await _montaFineSet(tester);

      await _toccaEConferma(tester, 'Fine Partita');

      expect(find.byType(MatchesScreen), findsOneWidget);
      expect(find.byType(ScoutScreen, skipOffstage: false), findsNothing);
      final partite = await tester.runAsync(
        () => db.select(db.volleyMatches).get(),
      );
      expect(partite!.single.stato, StatoPartita.terminata);
    } finally {
      await _smonta(tester);
    }
  });
}

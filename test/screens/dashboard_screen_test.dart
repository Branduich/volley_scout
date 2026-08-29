import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volley_scout/data/database.dart';
import 'package:volley_scout/data/demo_match_importer.dart';
import 'package:volley_scout/l10n/app_localizations.dart';
import 'package:volley_scout/providers/database_provider.dart';
import 'package:volley_scout/providers/settings_provider.dart';
import 'package:volley_scout/screens/dashboard/dashboard_screen.dart';
import 'package:volley_ui/pagina_squadra.dart';

/// La dashboard dentro l'app (passo 9b). La promessa da difendere è una sola:
/// **gli stessi numeri della pagina web**, presi dal database invece che da un
/// file. Se questi test si rompono, o i dati non arrivano o la pagina non è più
/// quella condivisa.
void main() {
  Future<void> seminaDemo(AppDatabase db) => DemoMatchImporter(db)
      .importaDaJson(File('packages/volley_stats/assets/backup_demo.json').readAsStringSync());

  Future<ProviderContainer> contenitore(AppDatabase db) async {
    SharedPreferences.setMockInitialValues({'app.lingua': 'it'});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      appDatabaseProvider.overrideWithValue(db),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  Future<void> monta(WidgetTester tester, AppDatabase db) async {
    tester.view.physicalSize = const Size(2560, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({'app.lingua': 'it'});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
      ],
      child: MaterialApp(
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const DashboardScreen(),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// Smontaggio esplicito con una durata: allo smontaggio drift programma un
  /// Timer di durata zero e, se l'albero si chiude da solo a fine test, quel
  /// timer resta pendente e il framework fallisce con "A Timer is still
  /// pending" — vedi la stessa nota in layout_dimensioni_test.
  Future<void> smonta(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  group('il backup costruito dal database', () {
    test('contiene le stesse righe che stanno nel database', () async {
      // È il punto in cui l'app e la dashboard web si allineano: se questa
      // traduzione perdesse qualcosa, i numeri in app e quelli del file
      // esportato divergerebbero senza che nessuno se ne accorga.
      final db = AppDatabase.perTest(NativeDatabase.memory());
      addTearDown(db.close);
      await seminaDemo(db);
      final c = await contenitore(db);

      final backup = await c.read(backupInMemoriaProvider.future);

      expect(backup.partite, hasLength(5));
      expect(backup.giocatori, isNotEmpty);
      final azioniNelBackup = backup.partite
          .expand((p) => p.sets)
          .expand((s) => s.azioni)
          .length;
      final azioniNelDb = (await db.select(db.scoutActions).get()).length;
      expect(azioniNelBackup, azioniNelDb);
    });

    test('su un database vuoto non esplode, esce vuoto', () async {
      final db = AppDatabase.perTest(NativeDatabase.memory());
      addTearDown(db.close);
      final c = await contenitore(db);

      final backup = await c.read(backupInMemoriaProvider.future);

      expect(backup.partite, isEmpty);
    });
  });

  group('la schermata', () {
    testWidgets('senza partite spiega perché è vuota', (tester) async {
      // Una dashboard di soli trattini sembra rotta: va detto che manca il
      // presupposto, non lasciato indovinare.
      final db = AppDatabase.perTest(NativeDatabase.memory());
      addTearDown(db.close);

      await monta(tester, db);

      expect(find.textContaining('Nessuna partita registrata'), findsOneWidget);
      expect(find.text('Giocatrici'), findsNothing);
      await smonta(tester);
    });

    testWidgets('con una partita mostra i numeri di stagione', (tester) async {
      final db = AppDatabase.perTest(NativeDatabase.memory());
      addTearDown(db.close);
      await seminaDemo(db);

      await monta(tester, db);

      expect(find.text('Atleti'), findsOneWidget);
      expect(find.text('Tendenza'), findsOneWidget);
      expect(find.text('Periodo'), findsOneWidget);
      await smonta(tester);
    });

    testWidgets('non mostra il banner della sorgente', (tester) async {
      // Dentro l'app non c'è nessun file da dichiarare né dati di esempio da
      // segnalare: quel banner parlerebbe di cose che non riguardano chi legge.
      final db = AppDatabase.perTest(NativeDatabase.memory());
      addTearDown(db.close);
      await seminaDemo(db);

      await monta(tester, db);

      expect(find.byType(BannerSorgente), findsNothing);
      await smonta(tester);
    });
  });
}

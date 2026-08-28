// Rete di sicurezza sui layout dipendenti dalla larghezza.
//
// L'app nasce per tablet in orizzontale, e più volte una misura fissa pensata
// per quello spazio ha rotto la stessa schermata su telefono — a volte solo
// per il frame in cui viene costruita in verticale, prima che il dispositivo
// finisca di ruotare. Sintomi tipici: `A RenderFlex overflowed` e
// `RenderBox was not laid out`.
//
// Questi test montano le schermate a dimensioni fisse e falliscono se il
// framework segnala un problema di disposizione: `tester.takeException()`
// restituisce proprio quelle eccezioni. Non verificano l'estetica — per
// quella serve l'occhio su un dispositivo — ma impediscono le regressioni.
//
// Per aggiungere una schermata basta una nuova `group` che chiami
// `verificaLayout` per ciascuna dimensione.
//
// Due trappole risolte (2026-08-18), da non reintrodurre: i font veri vanno
// caricati (`caricaFontApp`, altrimenti si misura Ahem) e l'albero va smontato
// dentro il test (vedi la fine di `verificaLayout`, altrimenti drift lascia un
// timer pendente e NESSUN test che legge dal DB può passare).
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volley_scout/data/database.dart';
import 'package:volley_scout/l10n/app_localizations.dart';
import 'package:volley_scout/main.dart';
import 'package:volley_scout/models/enums.dart';
import 'package:volley_scout/providers/database_provider.dart';
import 'package:volley_scout/providers/settings_provider.dart';
import 'package:volley_scout/data/demo_match_importer.dart';
import 'package:volley_scout/screens/campionato/campionato_screen.dart';
import 'package:volley_scout/screens/dashboard/dashboard_screen.dart';
import 'package:volley_scout/screens/live/scout_screen.dart';
import 'package:volley_scout/screens/matches/matches_screen.dart';
import 'package:volley_scout/screens/teams/team_form_screen.dart';
import 'package:volley_scout/theme/app_theme.dart';
import 'package:volley_scout/theme/app_typography.dart';
import 'package:volley_scout/tutorial/tutorial_sandbox.dart';

/// Dimensioni in pixel fisici, con la densità del dispositivo corrispondente.
/// Il telefono è un Pixel 7 (411×914 logici), il tablet un 10" (800×1280).
const _telefonoVerticale = Size(1080, 2400);
const _telefonoOrizzontale = Size(2400, 1080);
const _tabletOrizzontale = Size(2560, 1600);
const _densitaTelefono = 2.625;
const _densitaTablet = 2.0;

typedef CostruisciSchermata = Future<Widget> Function(AppDatabase db);

/// Carica i quattro pesi di Barlow nel motore di test.
///
/// **Obbligatorio in un test che misura larghezze**: senza, i widget test
/// disegnano col font di prova del framework (Ahem), dove ogni carattere
/// occupa un quadrato pieno pari al corpo. "Importa file FIPAV" misura così
/// 292 pixel invece dei ~150 di Barlow, e un bottone che nell'app sta comodo
/// sfora di 42 pixel — falso allarme reale, capitato prima di caricare i font.
/// Vale anche il contrario: con testi larghi il doppio, un layout troppo
/// stretto potrebbe non emergere mai dove Ahem lo fa già scattare altrove.
Future<void> caricaFontApp() async {
  final loader = FontLoader(AppTypography.fontFamily);
  for (final peso in const ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final file = File('assets/fonts/Barlow/Barlow-$peso.ttf');
    loader.addFont(file.readAsBytes().then(ByteData.sublistView));
  }
  await loader.load();
}

/// Interazione da compiere a schermata montata, per verificare anche i layout
/// che compaiono solo dopo un tocco (la pulsantiera del pannello voto).
typedef DopoIlMontaggio = Future<void> Function(WidgetTester tester);

/// Monta [schermata] a [dimensioni] e pretende che nessuna eccezione di
/// layout venga segnalata.
Future<void> verificaLayout(
  WidgetTester tester, {
  required Size dimensioni,
  required double densita,
  required CostruisciSchermata schermata,
  DopoIlMontaggio? dopoIlMontaggio,
}) async {
  tester.view.physicalSize = dimensioni;
  tester.view.devicePixelRatio = densita;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({'app.lingua': 'it'});
  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabase.perTest(NativeDatabase.memory());
  addTearDown(db.close);

  final widget = await schermata(db);

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
      home: widget,
    ),
  ));

  // Niente pumpAndSettle: alcune schermate hanno animazioni che non si
  // fermano mai (il lampeggio del punteggio) e attenderne la quiete
  // bloccherebbe il test. Qualche frame basta a far avvenire il layout, le
  // letture dagli stream e le animazioni di ingresso.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));

  // L'eccezione va raccolta PRIMA di interagire: se il montaggio ha già
  // sbagliato il layout, il tocco successivo fallirebbe con un errore
  // diverso e più difficile da leggere.
  expect(tester.takeException(), isNull);

  if (dopoIlMontaggio != null) {
    await dopoIlMontaggio(tester);
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
  }

  // Smontaggio ESPLICITO prima di concludere, altrimenti nessun test che
  // legge dal database può passare. Chiudendo l'albero, riverpod chiude i
  // StreamProvider e drift annulla le query in ascolto
  // (StreamQueryStore.markAsClosed), che si ripulisce con un Timer di durata
  // zero. Se lo smontaggio avviene da solo a fine test — cioè dopo l'ultimo
  // pump — quel timer non scade mai e il framework fallisce con "A Timer is
  // still pending", mascherando il vero esito del test.
  await tester.pumpWidget(const SizedBox.shrink());
  // La durata NON è decorativa: `pump()` senza argomento svuota solo le
  // microtask e non fa avanzare l'orologio finto (`elapse` è chiamato solo
  // `if (duration != null)`, flutter_test/binding.dart), quindi un Timer di
  // durata zero non scadrebbe mai.
  await tester.pump(const Duration(milliseconds: 1));

  expect(tester.takeException(), isNull);
}

/// Le tre dimensioni di riferimento, per non ripeterle in ogni gruppo.
void perOgniDimensione(
  String nome,
  CostruisciSchermata schermata, {
  DopoIlMontaggio? dopoIlMontaggio,
}) {
  group(nome, () {
    testWidgets('telefono in verticale', (tester) async {
      await verificaLayout(tester,
          dimensioni: _telefonoVerticale,
          densita: _densitaTelefono,
          schermata: schermata,
          dopoIlMontaggio: dopoIlMontaggio);
    });
    testWidgets('telefono in orizzontale', (tester) async {
      await verificaLayout(tester,
          dimensioni: _telefonoOrizzontale,
          densita: _densitaTelefono,
          schermata: schermata,
          dopoIlMontaggio: dopoIlMontaggio);
    });
    testWidgets('tablet in orizzontale', (tester) async {
      await verificaLayout(tester,
          dimensioni: _tabletOrizzontale,
          densita: _densitaTablet,
          schermata: schermata,
          dopoIlMontaggio: dopoIlMontaggio);
    });
  });
}

Future<int> _creaSquadra(AppDatabase db) => db.into(db.teams).insert(
      TeamsCompanion.insert(
        nome: 'Nettunia',
        categoria: 'Under 18',
        coloreDivisa: 0xFF1E3A8A,
      ),
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await caricaFontApp();
  });

  // Menu principale: cinque voci da 64dp non entrano in un terzo di schermo.
  perOgniDimensione('HomeScreen', (db) async => const HomeScreen());

  // Stato vuoto: il testo esplicativo è più alto dello spazio in orizzontale.
  perOgniDimensione('CampionatoScreen senza campionati',
      (db) async => const CampionatoScreen());

  // Caso peggiore della lista partite: una partita TERMINATA, che mostra
  // anche CSV, PDF e Report — la fila di bottoni più larga possibile.
  perOgniDimensione('MatchesScreen con partita terminata', (db) async {
    final teamId = await _creaSquadra(db);
    await db.into(db.volleyMatches).insert(VolleyMatchesCompanion.insert(
          nome: 'Gara 386 G. 1 MASI VOLLEY PINK B - NETTUNIA',
          dataOra: DateTime(2026, 10, 12, 11),
          inCasa: false,
          palestra: const Value('Sc. Galilei 1 - Casalecchio di Reno (BO)'),
          teamId: Value(teamId),
          stato: StatoPartita.terminata,
          setCorrente: 3,
        ));
    return const MatchesScreen();
  });

  // Modifica squadra: form da 360 fisse accanto alla lista giocatori.
  perOgniDimensione('TeamFormScreen in modifica', (db) async {
    final teamId = await _creaSquadra(db);
    for (var i = 1; i <= 6; i++) {
      await db.into(db.players).insert(PlayersCompanion.insert(
            teamId: teamId,
            nome: 'Giocatrice',
            cognome: 'Numero $i',
            numero: i,
            ruolo: Ruolo.schiacciatore,
          ));
    }
    final team = await (db.select(db.teams)..where((t) => t.id.equals(teamId)))
        .getSingle();
    return TeamFormScreen(team: team);
  });

  // Dashboard di stagione: il tabellone ha una colonna per fondamentale e
  // scorre in orizzontale, ma tutto il resto (KPI, filtri, grafico) deve
  // stare in larghezza da solo. Serve una partita VERA: senza azioni il
  // tabellone sarebbe vuoto e il test non proverebbe niente.
  perOgniDimensione('DashboardScreen con una partita', (db) async {
    await DemoMatchImporter(db)
        .importaDaJson(File('packages/volley_stats/assets/backup_demo.json').readAsStringSync());
    return const DashboardScreen();
  });

  // Scout live: la riga dei bottoni rapidi è la parte più larga dell'app.
  // Lo scenario è quello della partita di prova del tutorial, che è già una
  // formazione completa e coerente (set creato, rotazione, libero).
  perOgniDimensione(
    'ScoutScreen',
    _scoutScreenDiProva,
  );

  // Stessa schermata col PANNELLO VOTO aperto: la pulsantiera è alta cinque
  // righe da 64 e larga due colonne, ed è la parte che su telefono deve
  // rimpicciolirsi (FittedBox) invece di sbordare. Il set è appena iniziato e
  // tocca a noi servire, quindi l'unico giocatore tappabile è quello in P1 —
  // Anna Bianchi, numero 4 (vedi TutorialSandbox).
  perOgniDimensione(
    'ScoutScreen col pannello voto aperto',
    _scoutScreenDiProva,
    dopoIlMontaggio: (tester) async {
      await tester.tap(find.text('4'));
      await tester.pump();
    },
  );
}

Future<Widget> _scoutScreenDiProva(AppDatabase db) async {
  final prefs = await SharedPreferences.getInstance();
  final dati = await TutorialSandbox.semina(
    db,
    prefs,
    lookupAppLocalizations(const Locale('it')),
  );
  final formazione = await MatchSetRepository(db).caricaFormazione(dati.setId);
  return ScoutScreen(
    match: dati.match,
    team: dati.team,
    palleggiatoreSlot: formazione!.palleggiatoreSlot,
    assignments: formazione.assignments,
    ruoloCambiLibero: formazione.ruoloCambiLibero,
    sistemaGioco: formazione.sistemaGioco ?? SistemaGioco.palleggiatoreUnico,
  );
}

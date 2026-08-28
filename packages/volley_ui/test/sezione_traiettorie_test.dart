import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volley_stats/volley_stats.dart';
import 'package:volley_ui/campo_traiettorie.dart';
import 'package:volley_ui/sezione_traiettorie.dart';

/// La sezione non calcola: riceve i tiri e li disegna. Qui si verifica quello
/// che decide lei — cosa mostra quando non c'è niente, cosa scrive sotto al
/// campo, e cosa esce dai tre comandi.
void main() {
  _alpha();

  TiroScout tiro({
    Voto voto = Voto.positivo,
    double x1 = 0.1,
    double x2 = 0.8,
  }) =>
      TiroScout(
        squadra: Squadra.nostra,
        tipo: TipoAzione.scout,
        fondamentale: Fondamentale.battuta,
        voto: voto,
        x1: x1,
        y1: 0.3,
        x2: x2,
        y2: 0.6,
      );

  const rosa = [
    GiocatoreBackup(
      uid: 'g1',
      squadraUid: 's1',
      nome: 'Anna',
      cognome: 'Cobalto',
      numero: 7,
      ruolo: Ruolo.schiacciatore,
    ),
  ];

  Future<void> monta(
    WidgetTester tester, {
    required List<TiroScout> tiri,
    bool heatmap = false,
    ValueChanged<Fondamentale>? onFondamentale,
    ValueChanged<String?>? onGiocatrice,
    ValueChanged<bool>? onHeatmap,
  }) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SezioneTraiettorie(
            tiri: tiri,
            fondamentale: Fondamentale.battuta,
            giocatrici: rosa,
            giocatriceUid: null,
            heatmap: heatmap,
            onFondamentale: onFondamentale ?? (_) {},
            onGiocatrice: onGiocatrice ?? (_) {},
            onHeatmap: onHeatmap ?? (_) {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('senza tiri lo dice invece di mostrare un campo vuoto',
      (tester) async {
    await monta(tester, tiri: const []);

    expect(find.textContaining('Nessuna traiettoria registrata'), findsOneWidget);
    expect(find.byType(CourtTrajectoriesView), findsNothing);
  });

  testWidgets('sotto al campo scrive quanti colpi, vincenti ed errori',
      (tester) async {
    // Con venti frecce sovrapposte il conteggio a occhio non si fa.
    await monta(tester, tiri: [
      tiro(voto: Voto.perfetto),
      tiro(voto: Voto.errore),
      tiro(),
      tiro(),
    ]);

    expect(find.text('4 colpi · 1 vincenti · 1 errori'), findsOneWidget);
    expect(find.byType(CourtTrajectoriesView), findsOneWidget);
  });

  testWidgets('con la heatmap accesa le frecce lasciano il posto ai punti',
      (tester) async {
    // Sovrapposte, le macchie coprirebbero le frecce e si leggerebbe peggio di
    // entrambe le viste separate.
    await monta(tester, heatmap: true, tiri: [tiro(), tiro()]);

    final campo = tester.widget<CourtTrajectoriesView>(
        find.byType(CourtTrajectoriesView));

    expect(campo.trajectories, isEmpty);
    expect(campo.heatmapPunti, hasLength(2));
  });

  testWidgets('senza heatmap si disegnano le frecce e nessun punto',
      (tester) async {
    await monta(tester, tiri: [tiro(), tiro()]);

    final campo = tester.widget<CourtTrajectoriesView>(
        find.byType(CourtTrajectoriesView));

    expect(campo.trajectories, hasLength(2));
    expect(campo.heatmapPunti, isEmpty);
  });

  testWidgets('i tre comandi consegnano la scelta a chi ospita', (tester) async {
    Fondamentale? fondamentale;
    String? giocatrice;
    bool? heat;
    await monta(
      tester,
      tiri: [tiro()],
      onFondamentale: (f) => fondamentale = f,
      onGiocatrice: (g) => giocatrice = g,
      onHeatmap: (h) => heat = h,
    );

    await tester.tap(find.text('Battuta').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Attacco').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tutte').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('7  Cobalto').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Zone di caduta'));
    await tester.pumpAndSettle();

    expect(fondamentale, Fondamentale.attacco);
    expect(giocatrice, 'g1');
    expect(heat, isTrue);
  });
}

/// L'intensità dei blob della heatmap. Sta in un test perché è il parametro
/// che decide se la mappa dice qualcosa o è una macchia gialla: con l'additivo
/// e un'opacità fissa, quattrocento tiri saturavano l'intera metà campo.
void _alpha() {
  group('quanto inchiostro mette un punto della heatmap', () {
    test('pochi punti restano ben visibili', () {
      expect(alphaBlobHeatmap(1), 110);
      expect(alphaBlobHeatmap(12), 110);
    });

    test('più punti ci sono, meno pesa ciascuno', () {
      expect(alphaBlobHeatmap(60), lessThan(alphaBlobHeatmap(20)));
      expect(alphaBlobHeatmap(400), lessThan(alphaBlobHeatmap(60)));
    });

    test('una stagione intera non satura, ma si vede ancora', () {
      // 383 battute: era il caso che veniva tutto giallo.
      final a = alphaBlobHeatmap(383);
      expect(a, greaterThanOrEqualTo(8));
      expect(a, lessThan(20));
    });

    test('nessun punto, nessun inchiostro', () {
      expect(alphaBlobHeatmap(0), 0);
    });
  });
}

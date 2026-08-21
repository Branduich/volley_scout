import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volley_stats/volley_stats.dart';
import 'package:volley_ui/barra_filtri.dart';

/// La barra non filtra: costruisce un [Filtro] e lo consegna. Questi test
/// verificano proprio quello — cosa esce da `onCambia` — perché è l'unico
/// contratto che ha con il resto della dashboard.
void main() {
  Future<void> monta(
    WidgetTester tester, {
    Filtro filtro = const Filtro(),
    List<SquadraBackup> squadre = const [],
    required ValueChanged<Filtro> onCambia,
  }) async {
    tester.view.physicalSize = const Size(1600, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BarraFiltri(
            filtro: filtro, squadre: squadre, onCambia: onCambia),
      ),
    ));
  }

  testWidgets('scegliere un periodo consegna il filtro aggiornato',
      (tester) async {
    Filtro? uscito;
    await monta(tester, onCambia: (f) => uscito = f);

    await tester.tap(find.text('Tutta la stagione'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ritorno').last);
    await tester.pumpAndSettle();

    expect(uscito?.periodo, PeriodoPreset.ritorno);
  });

  testWidgets('il selettore squadra compare solo con più di una squadra',
      (tester) async {
    const una = SquadraBackup(
        uid: 's1', nome: 'Nettunia', categoria: 'U18', coloreDivisa: 0);
    const altra = SquadraBackup(
        uid: 's2', nome: 'Seconda', categoria: 'U16', coloreDivisa: 0);

    await monta(tester, squadre: const [una], onCambia: (_) {});
    expect(find.text('Squadra'), findsNothing);

    await monta(tester, squadre: const [una, altra], onCambia: (_) {});
    expect(find.text('Squadra'), findsOneWidget);
  });

  testWidgets('"Azzera filtri" compare solo a filtri attivi e non tocca la '
      'squadra', (tester) async {
    Filtro? uscito;
    await monta(tester, onCambia: (_) {});
    expect(find.text('Azzera filtri'), findsNothing);

    await monta(
      tester,
      filtro: const Filtro(set: 2, squadraUid: 's1'),
      onCambia: (f) => uscito = f,
    );
    expect(find.text('Azzera filtri'), findsOneWidget);

    await tester.tap(find.text('Azzera filtri'));
    await tester.pumpAndSettle();

    // La squadra NON è un filtro: azzerando si torna a "tutta la stagione"
    // ma si resta sulla squadra che si stava guardando.
    expect(uscito?.set, isNull);
    expect(uscito?.squadraUid, 's1');
    expect(uscito?.attivo, isFalse);
  });
}

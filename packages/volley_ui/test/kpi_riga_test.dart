import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volley_ui/kpi_riga.dart';

void main() {
  testWidgets('le card sono tutte alte uguali, con o senza dettaglio',
      (tester) async {
    // È il motivo per cui la riga del dettaglio si disegna anche quando è
    // vuota: senza, le tessere senza sottopancia venivano più basse e la riga
    // sembrava sfilacciata — un difetto che nessun test avrebbe visto.
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: KpiRiga(kpi: [
          Kpi('Partite', '5', dettaglio: '3V - 2P'),
          Kpi('Set', '11-7'),
          Kpi('Punti', '202'),
          Kpi('Efficienza attacco', '12%', dettaglio: '(# − =) / totale'),
        ]),
      ),
    ));

    final altezze = <double>{
      for (final e in find.byType(Container).evaluate())
        (e.renderObject! as RenderBox).size.height,
    };
    expect(altezze, hasLength(1), reason: 'altezze diverse: $altezze');
  });

  testWidgets('una percentuale che non esiste è un trattino, non uno zero',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: KpiRiga(kpi: [Kpi('Ace', pct(null))])),
    ));

    expect(find.text('—'), findsOneWidget);
    expect(find.text('0%'), findsNothing);
  });
}

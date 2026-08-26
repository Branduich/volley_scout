import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volley_stats/volley_stats.dart';
import 'package:volley_ui/grafico_tendenza.dart';

/// Il grafico non calcola niente: riceve i punti e li disegna. Qui si verifica
/// quello che DECIDE lui — dove spezzare la linea, cosa scrivere sopra e cosa
/// esce dai due selettori.
void main() {
  PartitaBackup partita(String uid, DateTime data, {String? avversario}) =>
      PartitaBackup(
        uid: uid,
        nome: uid,
        dataOra: data,
        inCasa: true,
        stato: StatoPartita.terminata,
        setCorrente: 3,
        avversario: avversario,
        squadraUid: 's1',
      );

  PuntoTendenza punto(int giorno, double? valore, int azioni) => (
        partita: partita('p$giorno', DateTime(2026, 10, giorno),
            avversario: 'Squadra $giorno'),
        valore: valore,
        azioni: azioni,
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
    GiocatoreBackup(
      uid: 'g2',
      squadraUid: 's1',
      nome: 'Bea',
      cognome: 'Indaco',
      numero: 9,
      ruolo: Ruolo.centrale,
    ),
  ];

  Future<void> monta(
    WidgetTester tester, {
    required List<PuntoTendenza> punti,
    ValueChanged<String?>? onGiocatrice,
    ValueChanged<MisuraTendenza>? onMisura,
  }) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: GraficoTendenza(
            punti: punti,
            giocatrici: rosa,
            giocatriceUid: 'g1',
            misura: MisuraTendenza.efficienzaAttacco,
            onGiocatrice: onGiocatrice ?? (_) {},
            onMisura: onMisura ?? (_) {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  group('dove si spezza la linea', () {
    test('una serie piena è un segmento solo', () {
      final segmenti = segmentiSerie(
          [punto(5, 10, 8), punto(12, 20, 9), punto(19, 30, 7)]);

      expect(segmenti, hasLength(1));
      expect(segmenti.single.map((p) => p.indice), [0, 1, 2]);
    });

    test('una partita senza quel fondamentale spezza la linea', () {
      // Tirare una riga sopra il buco farebbe leggere un calo (o una crescita)
      // fra due partite in cui non è successo niente.
      final segmenti = segmentiSerie(
          [punto(5, 10, 8), punto(12, null, 0), punto(19, 30, 7)]);

      expect(segmenti, hasLength(2));
      expect(segmenti.first.single.indice, 0);
      // L'indice del secondo segmento resta 2: i punti non scivolano indietro,
      // altrimenti sull'asse le partite si avvicinerebbero fra loro.
      expect(segmenti.last.single.indice, 2);
    });

    test('una serie tutta vuota non ha segmenti', () {
      expect(segmentiSerie([punto(5, null, 0), punto(12, null, 0)]), isEmpty);
    });
  });

  group('come si legge una pendenza', () {
    test('sotto mezzo punto a partita è stabile', () {
      // Su cinque partite sono due punti in tutto: è rumore, non progresso.
      expect(GraficoTendenza.descrizioneTendenza(0.4), 'Stabile');
      expect(GraficoTendenza.descrizioneTendenza(-0.4), 'Stabile');
    });

    test('sopra la soglia si dice il verso e di quanto', () {
      expect(GraficoTendenza.descrizioneTendenza(2.35),
          'In crescita: +2,4 punti a partita');
      expect(GraficoTendenza.descrizioneTendenza(-6),
          'In calo: −6,0 punti a partita');
    });
  });

  group('a video', () {
    testWidgets('con cinque partite buone la tendenza c\'è', (tester) async {
      await monta(tester, punti: [
        for (var i = 0; i < 5; i++) punto(5 + 7 * i, -20 + 20.0 * i, 10),
      ]);

      expect(find.text('In crescita: +20,0 punti a partita'), findsOneWidget);
    });

    testWidgets('con quattro partite si dice perché la tendenza manca',
        (tester) async {
      // Non basta nasconderla: chi legge deve sapere se gli conviene allargare
      // il periodo o se quella giocatrice ha giocato troppo poco.
      await monta(tester, punti: [
        for (var i = 0; i < 4; i++) punto(5 + 7 * i, -20 + 20.0 * i, 10),
      ]);

      expect(find.textContaining('Tendenza non calcolata'), findsOneWidget);
    });

    testWidgets('senza nessuna azione lo dice invece di disegnare il vuoto',
        (tester) async {
      await monta(tester,
          punti: [punto(5, null, 0), punto(12, null, 0)]);

      expect(
          find.text('Nessuna azione di questo fondamentale nel periodo.'),
          findsOneWidget);
      expect(find.textContaining('Azioni per partita'), findsNothing);
    });

    testWidgets('la striscia mostra quante azioni ci sono dietro ogni punto',
        (tester) async {
      // È il pezzo che impedisce di leggere un 100% su due palloni come un
      // grande attacco.
      await monta(tester, punti: [
        punto(5, 50, 12),
        punto(12, 100, 2),
        punto(19, 40, 15),
        punto(26, 45, 11),
        punto(31, 55, 13),
      ]);

      expect(find.text('Azioni per partita'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('i selettori consegnano la scelta a chi ospita il grafico',
        (tester) async {
      String? giocatrice;
      MisuraTendenza? misura;
      await monta(
        tester,
        punti: [for (var i = 0; i < 5; i++) punto(5 + 7 * i, 20, 10)],
        onGiocatrice: (v) => giocatrice = v,
        onMisura: (v) => misura = v,
      );

      await tester.tap(find.text('7  Cobalto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('9  Indaco').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Attacco — efficienza'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ricezione — positività').last);
      await tester.pumpAndSettle();

      expect(giocatrice, 'g2');
      expect(misura, MisuraTendenza.positivitaRicezione);
    });
  });
}

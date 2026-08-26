import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volley_stats/volley_stats.dart';
import 'package:volley_ui/calendario_periodo.dart';

/// Il calendario esiste per una cosa sola: far vedere **in che giorno si è
/// giocato** mentre si sceglie un periodo, lasciando scegliibili anche tutti
/// gli altri giorni. Questi test difendono esattamente quelle due cose.
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

  // Due partite nello STESSO mese: il calendario ci sta tutto senza scorrere,
  // e i test non finiscono a dipendere dallo scroll invece che dal colore.
  final stagione = giornateDi([
    partita('a', DateTime(2026, 10, 12, 20, 30), avversario: 'Masi Pink'),
    partita('b', DateTime(2026, 10, 24, 20, 30), avversario: 'Idea Volley'),
  ]);

  Finder cella(String iso) => find.byKey(ValueKey('giorno-$iso'));

  Future<void> tocca(WidgetTester tester, String iso) async {
    await tester.tap(cella(iso));
    await tester.pumpAndSettle();
  }

  /// Il cerchietto ambra di un giorno con partita, dentro la sua casella.
  Finder cerchioPartita(String iso) => find.descendant(
        of: cella(iso),
        matching: find.byWidgetPredicate((w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == kColoreGiornoConPartita),
      );

  /// Apre il calendario e restituisce la scatola in cui finirà il periodo
  /// scelto: si legge DOPO aver toccato "Applica" o "Annulla", perché il valore
  /// arriva alla chiusura del dialogo.
  Future<List<DateTimeRange?>> apri(
    WidgetTester tester, {
    List<Giornata>? giornate,
    DateTime? da,
    DateTime? a,
  }) async {
    final scelto = <DateTimeRange?>[];
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => scelto.add(await mostraCalendarioPeriodo(
              context,
              giornate: giornate ?? stagione,
              da: da,
              a: a,
            )),
            child: const Text('apri'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();
    return scelto;
  }

  group('quali mesi e quali caselle', () {
    test('ci sono tutti i mesi della stagione, soste comprese', () {
      // Saltare i mesi vuoti renderebbe illeggibile la distanza fra due
      // partite: la sosta di dicembre è un'informazione, non un buco.
      final mesi = mesiTra(DateTime(2026, 10, 12), DateTime(2027, 1, 18));

      expect(mesi, [
        DateTime(2026, 10),
        DateTime(2026, 11),
        DateTime(2026, 12),
        DateTime(2027, 1),
      ]);
    });

    test('un mese solo quando si è giocato in un giorno solo', () {
      expect(mesiTra(DateTime(2026, 10, 12), DateTime(2026, 10, 12)),
          [DateTime(2026, 10)]);
    });

    test('la griglia parte da lunedì, con le caselle vuote davanti', () {
      // Il 1° novembre 2026 è una domenica: sei caselle vuote prima.
      final caselle = caselleMese(DateTime(2026, 11));

      expect(caselle.take(6), everyElement(isNull));
      expect(caselle[6], DateTime(2026, 11, 1));
      expect(caselle.length, 6 + 30);
    });
  });

  group('dove cade un giorno rispetto al periodo', () {
    final da = DateTime(2026, 10, 12);
    final a = DateTime(2026, 11, 23);

    test('gli estremi sono estremi, e sono inclusi', () {
      expect(posizioneGiorno(da, da, a), PosizioneGiorno.estremo);
      expect(posizioneGiorno(a, da, a), PosizioneGiorno.estremo);
    });

    test('in mezzo si sta dentro, fuori si sta fuori', () {
      expect(posizioneGiorno(DateTime(2026, 10, 30), da, a),
          PosizioneGiorno.dentro);
      expect(posizioneGiorno(DateTime(2026, 11, 24), da, a),
          PosizioneGiorno.fuori);
      expect(posizioneGiorno(DateTime(2026, 10, 11), da, a),
          PosizioneGiorno.fuori);
    });

    test('col solo inizio scelto si evidenzia quel giorno soltanto', () {
      // È lo stato fra il primo e il secondo tocco.
      expect(posizioneGiorno(da, da, null), PosizioneGiorno.estremo);
      expect(posizioneGiorno(DateTime(2026, 10, 30), da, null),
          PosizioneGiorno.fuori);
    });

    test('senza periodo nessun giorno è evidenziato', () {
      expect(posizioneGiorno(da, null, null), PosizioneGiorno.fuori);
    });

    test('l\'ora della partita non sposta il giorno', () {
      // Le partite hanno un'ora, il calendario no.
      expect(
        posizioneGiorno(DateTime(2026, 10, 12), DateTime(2026, 10, 12, 20, 30),
            DateTime(2026, 11, 23, 18, 0)),
        PosizioneGiorno.estremo,
      );
    });
  });

  group('il calendario a video', () {
    testWidgets('il giorno con partita è colorato, quello senza no',
        (tester) async {
      await apri(tester);

      expect(cerchioPartita('2026-10-12'), findsOneWidget);
      expect(cerchioPartita('2026-10-24'), findsOneWidget);
      // Il giorno prima della partita resta una casella normale.
      expect(cerchioPartita('2026-10-11'), findsNothing);
    });

    testWidgets('anche un giorno SENZA partita si può scegliere',
        (tester) async {
      // È il punto della funzione: il calendario colora, non vincola. Chi
      // sceglie non deve indovinare quali caselle sono ammesse.
      final scelto = await apri(tester);

      await tocca(tester, '2026-10-01');
      await tocca(tester, '2026-10-31');
      await tester.tap(find.text('Applica'));
      await tester.pumpAndSettle();

      expect(scelto.single?.start, DateTime(2026, 10, 1));
      expect(scelto.single?.end, DateTime(2026, 10, 31));
    });

    testWidgets('un tocco solo vale un giorno solo', (tester) async {
      // Chi vuole guardare una partita sola non deve toccarla due volte.
      final scelto = await apri(tester);

      await tocca(tester, '2026-10-12');
      await tester.tap(find.text('Applica'));
      await tester.pumpAndSettle();

      expect(scelto.single?.start, DateTime(2026, 10, 12));
      expect(scelto.single?.end, DateTime(2026, 10, 12));
    });

    testWidgets('toccare un giorno prima dell\'inizio ricomincia da lì',
        (tester) async {
      // Chi sbaglia l'ordine non deve annullare e riaprire.
      final scelto = await apri(tester);

      await tocca(tester, '2026-10-24');
      await tocca(tester, '2026-10-12');
      await tocca(tester, '2026-10-24');
      await tester.tap(find.text('Applica'));
      await tester.pumpAndSettle();

      expect(scelto.single?.start, DateTime(2026, 10, 12));
      expect(scelto.single?.end, DateTime(2026, 10, 24));
    });

    testWidgets('"Annulla" non consegna niente', (tester) async {
      final scelto = await apri(tester);

      await tocca(tester, '2026-10-01');
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();

      expect(scelto, [null]);
    });

    testWidgets('il periodo già scelto si ritrova aperto', (tester) async {
      await apri(tester, da: DateTime(2026, 10, 12), a: DateTime(2026, 10, 24));

      expect(find.text('12/10/2026 – 24/10/2026'), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volley_stats/volley_stats.dart';
import 'package:volley_ui/tabellone_stagionale.dart';

GiocatoreBackup _g(int numero, String cognome) => GiocatoreBackup(
      uid: 'g$numero',
      squadraUid: 's1',
      nome: 'Nome',
      cognome: cognome,
      numero: numero,
      ruolo: Ruolo.schiacciatore,
    );

/// Costruisce i contatori a mano: qui interessa il comportamento della
/// tabella, non il calcolo (che è testato in volley_stats).
StatGiocatore _stat(int numero, String cognome,
    {int attacchi = 0, int perfetti = 0, int errori = 0}) {
  final s = StatGiocatore(_g(numero, cognome));
  if (attacchi > 0) {
    s.attacco[Voto.perfetto] = perfetti;
    s.attacco[Voto.errore] = errori;
    final resto = attacchi - perfetti - errori;
    if (resto > 0) s.attacco[Voto.positivo] = resto;
  }
  return s;
}

/// Il tabellone per fondamentale è largo (la vista Attacco ha quindici
/// colonne): sugli 800 pixel di default metà colonne cadono fuori schermo e un
/// tap le mancherebbe **in silenzio**, lasciando la tabella com'era.
void _finestraLarga(WidgetTester tester) {
  tester.view.physicalSize = const Size(2400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _monta(WidgetTester tester, List<StatGiocatore> stats) =>
    tester.pumpWidget(
      MaterialApp(home: Scaffold(body: TabelloneStagionale(stats: stats))),
    );

/// Trova le intestazioni dipinte con [colore]: il riquadro colorato è un
/// `Container` con quello sfondo.
bool Function(Widget) _tinta(Color colore) => (widget) =>
    widget is Container &&
    widget.decoration is BoxDecoration &&
    (widget.decoration! as BoxDecoration).color == colore;

Future<void> _vista(WidgetTester tester, String etichetta) async {
  await tester.tap(find.widgetWithText(ChoiceChip, etichetta));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mostra una riga per atleta, ordinata per numero',
      (tester) async {
    _finestraLarga(tester);
    await _monta(tester, [
      _stat(7, 'Bianchi', attacchi: 10, perfetti: 5, errori: 1),
      _stat(4, 'Ricci', attacchi: 10, perfetti: 2, errori: 4),
    ]);

    expect(find.text('Ricci Nome'), findsOneWidget);
    expect(find.text('Bianchi Nome'), findsOneWidget);
    // Il riepilogo mostra i punti d'attacco, non l'efficienza: quella sta
    // nella vista Attacco (test sotto).
    expect(find.text('Punti att.'), findsOneWidget);
    expect(find.text('Eff.%'), findsNothing);
  });

  testWidgets('scegliendo un fondamentale cambiano le colonne',
      (tester) async {
    // Il senso del filtro: la vista Attacco è la fetta della mega tabella del
    // PDF, sotto-blocchi "su ricezione" e "su difesa" compresi.
    _finestraLarga(tester);
    await _monta(tester, [
      _stat(7, 'Bianchi', attacchi: 10, perfetti: 5, errori: 1),
      _stat(4, 'Ricci', attacchi: 10, perfetti: 2, errori: 4),
    ]);

    await _vista(tester, 'Attacco');

    expect(find.text('Murati'), findsOneWidget);
    expect(find.text('Su ric.'), findsOneWidget);
    expect(find.text('Su dif.'), findsOneWidget);
    // 5 perfetti - 1 errore su 10 = 40%; 2 - 4 su 10 = -20%.
    expect(find.text('40%'), findsOneWidget);
    expect(find.text('-20%'), findsOneWidget);
  });

  testWidgets('chi non ha azioni di quel fondamentale: 0 e celle vuote',
      (tester) async {
    // Deciso con l'utente: la riga resta (si vede a colpo d'occhio chi non
    // riceve mai) ma non si riempie di zeri e trattini che sembrano dati.
    _finestraLarga(tester);
    await _monta(tester, [_stat(1, 'Senzattacchi')]);

    await _vista(tester, 'Attacco');

    // I tre totali dei blocchi (attacco, su ricezione, su difesa) dicono 0…
    expect(find.text('0'), findsNWidgets(3));
    // …e tutto il resto della riga è vuoto, `—` compreso: una percentuale che
    // non esiste qui non si scrive proprio.
    expect(find.text('—'), findsNothing);
    expect(find.text(''), findsWidgets);
  });

  testWidgets('chi non ha azioni resta in fondo in ENTRAMBI i versi',
      (tester) async {
    // È il difetto classico delle tabelle ordinabili: la cella è vuota ma
    // l'ordinamento la tratta come zero, e chi non ha mai attaccato finisce in
    // mezzo a chi attacca male.
    _finestraLarga(tester);
    await _monta(tester, [
      _stat(1, 'Senzattacchi'),
      _stat(2, 'Scarsa', attacchi: 10, perfetti: 0, errori: 5),
      _stat(3, 'Brava', attacchi: 10, perfetti: 8, errori: 0),
    ]);

    await _vista(tester, 'Attacco');

    Future<void> ordinaPerEfficienza() async {
      await tester.tap(find.text('Eff.%'));
      await tester.pumpAndSettle();
    }

    /// L'ordine VISIVO, non quello dell'albero dei widget: si legge la
    /// posizione verticale di ogni cella col cognome.
    List<String> cognomiInOrdine() {
      final celle = find.descendant(
        of: find.byType(DataTable),
        matching: find.textContaining('Nome'),
      );
      final righe = [
        for (final elemento in celle.evaluate())
          (
            testo: (elemento.widget as Text).data!,
            y: tester.getTopLeft(find.byWidget(elemento.widget)).dy,
          ),
      ]..sort((a, b) => a.y.compareTo(b.y));
      return [for (final r in righe) r.testo];
    }

    await ordinaPerEfficienza(); // crescente
    expect(cognomiInOrdine().last, contains('Senzattacchi'));

    await ordinaPerEfficienza(); // decrescente
    expect(cognomiInOrdine().last, contains('Senzattacchi'));
  });

  testWidgets('le intestazioni portano i colori dei gruppi del PDF',
      (tester) async {
    // La tinta appartiene alla COLONNA, non alla riga di intestazione: nella
    // vista Attacco i gruppi sono tre e devono distinguersi fra loro, cosa che
    // una fascia unica non potrebbe fare.
    _finestraLarga(tester);
    await _monta(tester, [_stat(7, 'Bianchi')]);

    Finder tinte(Color c) => find.byWidgetPredicate(_tinta(c));

    // Riepilogo: il colore dice da quale gruppo viene ogni colonna.
    // #, Atleta e Azioni stanno insieme nel blocco d'identità.
    expect(tinte(kColoreGruppoIdentita), findsNWidgets(3));
    expect(tinte(kColoreGruppoBattuta), findsNWidgets(2)); // Battute, Ace
    expect(tinte(kColoreGruppoAttacco), findsNWidgets(2)); // Attacchi, Punti a.
    expect(tinte(kColoreGruppoRicezione), findsNWidgets(2)); // Ricezioni, Pos.
    expect(tinte(kColoreGruppoPuntiErrori), findsNWidgets(2)); // Punti, Errori

    await _vista(tester, 'Battuta');
    // Battute, Ace, Errori, Eff.% — non # né Atleta, che restano neutre.
    expect(tinte(kColoreGruppoBattuta), findsNWidgets(4));

    await _vista(tester, 'Attacco');
    // Il blocco principale ha cinque colonne (Murati compreso); i due
    // sotto-blocchi quattro ciascuno, nella tinta più chiara della stessa
    // famiglia.
    expect(tinte(kColoreGruppoAttacco), findsNWidgets(5));
    expect(tinte(kColoreGruppoAttaccoDettaglio), findsNWidgets(8));
  });

  testWidgets('le righe si alternano per farsi seguire con l\'occhio',
      (tester) async {
    // Tinge le righe PARI contando da uno, come il PDF: la prima resta sul
    // fondo della tabella. Se si invertisse, la riga in cima sembrerebbe
    // selezionata.
    _finestraLarga(tester);
    await _monta(tester, [
      _stat(1, 'Prima'),
      _stat(2, 'Seconda'),
      _stat(3, 'Terza'),
    ]);

    final righe = tester.widget<DataTable>(find.byType(DataTable)).rows;
    expect(righe, hasLength(3));
    expect(righe[0].color, isNull);
    expect(righe[1].color, isNotNull);
    expect(righe[2].color, isNull);
  });

  testWidgets('cambiando vista l\'ordinamento riparte dal numero',
      (tester) async {
    // Le colonne sono altre: un indice tenuto da prima punterebbe a una
    // colonna che non c'entra niente, o fuori dalla lista.
    _finestraLarga(tester);
    await _monta(tester, [
      _stat(1, 'Senzattacchi'),
      _stat(3, 'Brava', attacchi: 10, perfetti: 8),
    ]);

    await _vista(tester, 'Attacco');
    await tester.tap(find.text('Attacchi'));
    await tester.pumpAndSettle();
    await _vista(tester, 'Ricezione');

    final tabella = tester.widget<DataTable>(find.byType(DataTable));
    expect(tabella.sortColumnIndex, 0);
    expect(tabella.sortAscending, isTrue);
  });
}

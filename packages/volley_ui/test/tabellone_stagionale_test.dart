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

void main() {
  testWidgets('mostra una riga per giocatrice, ordinata per numero',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TabelloneStagionale(stats: [
          _stat(7, 'Bianchi', attacchi: 10, perfetti: 5, errori: 1),
          _stat(4, 'Ricci', attacchi: 10, perfetti: 2, errori: 4),
        ]),
      ),
    ));

    expect(find.text('Ricci Nome'), findsOneWidget);
    expect(find.text('Bianchi Nome'), findsOneWidget);
    // 5 perfetti - 1 errore su 10 = 40%; 2 - 4 su 10 = -20%.
    expect(find.text('40%'), findsOneWidget);
    expect(find.text('-20%'), findsOneWidget);
  });

  testWidgets('chi non ha azioni resta in fondo in ENTRAMBI i versi',
      (tester) async {
    // È il difetto classico delle tabelle ordinabili: la cella mostra `—` ma
    // l'ordinamento la tratta come zero, e chi non ha mai attaccato finisce in
    // mezzo a chi attacca male.
    //
    // Finestra larga: il tabellone scorre in orizzontale, e sugli 800 pixel di
    // default la colonna "Eff. att." cade fuori schermo — il tap la mancherebbe
    // in silenzio, lasciando la tabella ordinata per numero di maglia.
    tester.view.physicalSize = const Size(2000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TabelloneStagionale(stats: [
          _stat(1, 'Senzattacchi'),
          _stat(2, 'Scarsa', attacchi: 10, perfetti: 0, errori: 5),
          _stat(3, 'Brava', attacchi: 10, perfetti: 8, errori: 0),
        ]),
      ),
    ));

    Future<void> ordinaPerEfficienza() async {
      await tester.tap(find.text('Eff. att.'));
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
}

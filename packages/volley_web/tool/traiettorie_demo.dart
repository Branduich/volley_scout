// Aggiunge traiettorie SINTETICHE alla stagione dimostrativa della vetrina.
//
//   dart run tool/traiettorie_demo.dart          # scrive assets/backup_demo.json
//   dart run tool/traiettorie_demo.dart --prova  # stampa e basta, non scrive
//
// **Perché esistono dati inventati.** Le partite della demo vengono dagli
// `.xlsx` di "Volleyball Scout", che registra voti e giocatrici ma NON le
// coordinate. Senza queste, la vista traiettorie della vetrina mostrerebbe un
// campo vuoto proprio a chi arriva per capire cosa sa fare l'app. I nomi della
// demo sono già inventati (colori); qui lo diventano anche i punti d'arrivo.
// Deciso con l'utente il 2026-08-28, alternativa scartata: scoutare a mano un
// set vero.
//
// **Non sono numeri a caso.** Ogni tiro è coerente con il voto che l'azione ha
// già: un ace cade dentro, un errore finisce fuori o in rete, un attacco
// murato torna nella metà di chi ha attaccato con il tocco a muro registrato.
// Le percentuali del tabellone non cambiano di una virgola — le coordinate non
// entrano in nessun conteggio — ma il campo e le statistiche raccontano la
// stessa partita invece di contraddirsi.
//
// **Seed fisso**: rigenerare dà lo stesso file. Un demo che cambia a ogni
// esecuzione produce diff illeggibili e schermate che non corrispondono più.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

const _percorso = '../volley_stats/assets/backup_demo.json';

/// Cambiandolo cambia tutta la stagione: tienilo fisso.
const _seed = 20260828;

/// Le coordinate del formato hanno al massimo 4 decimali (c'è un test che lo
/// pretende): più cifre sono rumore, un campo è largo 9 metri.
double _arr(double v) => double.parse(v.toStringAsFixed(4));

void main(List<String> argomenti) {
  final prova = argomenti.contains('--prova');
  final file = File(_percorso);
  if (!file.existsSync()) {
    stderr.writeln('Non trovo $_percorso: lancialo da packages/volley_web.');
    exit(1);
  }

  final radice = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final caso = Random(_seed);
  var toccate = 0;

  for (final partita in (radice['partite'] as List).cast<Map<String, dynamic>>()) {
    for (final set in (partita['sets'] as List).cast<Map<String, dynamic>>()) {
      for (final a in (set['azioni'] as List).cast<Map<String, dynamic>>()) {
        final fondamentale = a['f'];
        if (fondamentale != 'battuta' && fondamentale != 'attacco') continue;
        // Solo le azioni giudicate: un'azione senza voto non è un tiro.
        final voto = a['v'] as String?;
        if (voto == null) continue;
        // Chi ha GIÀ le coordinate non si tocca. Le 197 della gara del 30
        // aprile sono VERE — travasate dal vecchio demo dell'app, che le
        // aveva registrate durante lo scout, prima che quel file venisse
        // cancellato (lo script del travaso vive nella storia di git).
        // Sovrascriverle con numeri inventati sarebbe una perdita secca, e
        // silenziosa: il file continuerebbe a sembrare a posto.
        if (a['x1'] != null) continue;

        final nostra = a['s'] != 'avversari';
        final tiro = _tiro(
          caso: caso,
          battuta: fondamentale == 'battuta',
          voto: voto,
          nostra: nostra,
        );
        a['x1'] = _arr(tiro.x1);
        a['y1'] = _arr(tiro.y1);
        a['x2'] = _arr(tiro.x2);
        a['y2'] = _arr(tiro.y2);
        if (tiro.mx != null) {
          a['mx'] = _arr(tiro.mx!);
          a['my'] = _arr(tiro.my!);
        } else {
          a.remove('mx');
          a.remove('my');
        }
        toccate++;
      }
    }
  }

  stdout.writeln('traiettorie scritte su $toccate azioni');
  if (prova) {
    stdout.writeln('(--prova: file non modificato)');
    return;
  }
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(radice));
  stdout.writeln('scritto $_percorso');
}

typedef _Tiro = ({double x1, double y1, double x2, double y2, double? mx, double? my});

/// Un tiro plausibile per quel voto.
///
/// Lo spazio è il campo DOPPIO normalizzato 0-1 con la rete a `x = 0.5`, come
/// nel resto dell'app. Chi gioca a sinistra tira verso destra; per gli
/// avversari è specchiato — la normalizzazione a video li rimette nel verso
/// giusto, ma il dato salvato resta quello vero.
_Tiro _tiro({
  required Random caso,
  required bool battuta,
  required String voto,
  required bool nostra,
}) {
  double fra(double a, double b) => a + caso.nextDouble() * (b - a);

  // Partenza. La battuta si batte da DIETRO la linea di fondo, che
  // nell'immagine del campo sta esattamente a `x = 0` (misurato sui pixel:
  // fondo 0, tre metri 0,333, rete 0,5, tre metri 0,667, fondo 1). Il
  // battitore ha quindi x NEGATIVA, fuori dal rettangolo — come nello scout
  // live, dove il suo token sta a −70 su 1200, cioè −0,058. C'è spazio per
  // disegnarlo: il campo occupa il 58% della larghezza ed è centrato.
  // L'attacco invece parte da ridosso della rete, fra i tre metri e la rete.
  final xPartenza = battuta ? fra(-0.06, -0.015) : fra(0.36, 0.47);
  final yPartenza = battuta ? fra(0.15, 0.85) : fra(0.10, 0.90);

  double xArrivo, yArrivo;
  double? mx, my;

  switch (voto) {
    // Ace e attacchi vincenti: dentro, e lontano da dove ci si aspetta la
    // palla — angoli profondi o la parallela stretta.
    case 'perfetto':
      xArrivo = caso.nextBool() ? fra(0.82, 0.96) : fra(0.56, 0.68);
      yArrivo = caso.nextBool() ? fra(0.04, 0.22) : fra(0.78, 0.96);

    // Errori: la palla non è mai nel campo avversario. Tre modi di sbagliare,
    // con i pesi che hanno in partita: lunga, in rete, fuori di lato.
    case 'errore':
      final come = caso.nextInt(10);
      if (come < 5) {
        xArrivo = fra(1.0, 1.06); // lunga, oltre il fondo
        yArrivo = fra(0.1, 0.9);
      } else if (come < 8) {
        xArrivo = fra(0.48, 0.52); // in rete
        yArrivo = fra(0.1, 0.9);
      } else {
        xArrivo = fra(0.6, 0.95); // fuori di lato
        yArrivo = caso.nextBool() ? fra(-0.05, 0.0) : fra(1.0, 1.05);
      }
      // Un attacco su tre lo prende il muro: la palla torna indietro, e il
      // punto di tocco sulla rete viene registrato. È la condizione che
      // `attaccoMurato` riconosce (partenza e arrivo dalla stessa parte).
      if (!battuta && caso.nextInt(3) == 0) {
        mx = 0.5;
        my = fra(0.2, 0.8);
        xArrivo = fra(0.15, 0.45);
        yArrivo = fra(0.1, 0.9);
      }

    // Tutto il resto: palla dentro, distribuita sul campo.
    default:
      xArrivo = fra(0.56, 0.95);
      yArrivo = fra(0.06, 0.94);
  }

  if (nostra) {
    return (x1: xPartenza, y1: yPartenza, x2: xArrivo, y2: yArrivo, mx: mx, my: my);
  }
  // Specchiatura attorno al centro del campo doppio: gli avversari tirano da
  // destra verso sinistra.
  return (
    x1: 1 - xPartenza,
    y1: 1 - yPartenza,
    x2: 1 - xArrivo,
    y2: 1 - yArrivo,
    mx: mx == null ? null : 1 - mx,
    my: my == null ? null : 1 - my,
  );
}

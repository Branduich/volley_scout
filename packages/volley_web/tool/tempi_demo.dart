// Dà un orario alle azioni della stagione dimostrativa.
//
//   dart run tool/tempi_demo.dart [--prova]
//
// **Perché servono.** Gli `.xlsx` di "Volleyball Scout" registrano l'ordine
// delle azioni ma non quando sono avvenute, quindi nel file tutte le azioni
// hanno `t = 0`: nel report la durata di ogni set risulta zero, e il formato
// non è esercitato nel punto in cui ancora i tempi alla prima azione.
//
// **Non è un'invenzione nuova.** Il vecchio importatore del demo faceva già
// esattamente questo, ma di nascosto: scriveva `dataOra + un secondo per
// azione` mentre caricava. Meglio che il dato inventato stia nel file, dove si
// vede, che dentro al codice, dove non lo sa nessuno. Qui in più i tempi sono
// PLAUSIBILI: un secondo per azione dava set da un minuto e mezzo.
//
// Il ritmo è deterministico (nessun caso): rigenerare dà lo stesso file.
import 'dart:convert';
import 'dart:io';

const _percorso = '../volley_stats/assets/backup_demo.json';

/// Quanto passa fra un'azione e la successiva. Uno scambio più il tempo morto
/// prima del servizio: un set da una novantina di azioni viene lungo circa
/// venticinque minuti, che è la durata vera di un set di pallavolo.
const _secondiPerAzione = 17;

/// L'intervallo fra un set e il successivo.
const _secondiFraSet = 180;

void main(List<String> argomenti) {
  final prova = argomenti.contains('--prova');
  final file = File(_percorso);
  final radice = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

  var toccate = 0;
  for (final partita
      in (radice['partite'] as List).cast<Map<String, dynamic>>()) {
    // Il tempo riparte da zero a ogni partita: `t` è il delta dalla PRIMA
    // azione di quella gara, non un orologio assoluto.
    var t = 0;
    for (final set in (partita['sets'] as List).cast<Map<String, dynamic>>()) {
      final azioni = (set['azioni'] as List).cast<Map<String, dynamic>>();
      for (final a in azioni) {
        a['t'] = t;
        t += _secondiPerAzione;
        toccate++;
      }
      t += _secondiFraSet;
    }
  }

  stdout.writeln('orari scritti su $toccate azioni');
  if (prova) {
    stdout.writeln('(--prova: file non modificato)');
    return;
  }
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(radice));
  stdout.writeln('scritto $_percorso');
}

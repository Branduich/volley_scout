// Confronta la struttura e le distribuzioni di più .xlsx di scout, per capire
// se una stranezza (es. zero ricezioni perfette) è una proprietà del formato o
// una caratteristica vera di quella partita.
//
//   dart run tool/analizza_partite.dart <cartella con gli .xlsx, ricorsiva>
import 'dart:io';

import 'package:volley_scout/data/xlsx_reader.dart';

void main(List<String> argomenti) {
  if (argomenti.isEmpty) {
    stderr.writeln('Uso: dart run tool/analizza_partite.dart <cartella>');
    exitCode = 2;
    return;
  }

  final file = Directory(argomenti.first)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith('.xlsx'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final intestazioni = <String, List<String>>{};

  for (final f in file) {
    final nome = f.path.split(RegExp(r'[\\/]')).last;
    final griglia = leggiXlsx(f.readAsBytesSync());
    stdout.writeln('\n=== $nome  (${griglia.length} righe) ===');
    if (griglia.isNotEmpty) stdout.writeln('riga 0: ${griglia.first.join(" | ")}');
    if (griglia.length < 2) continue;

    final testata = griglia[1].map((c) => c.trim()).toList();
    intestazioni[nome] = testata;
    stdout.writeln('colonne: ${testata.join(" | ")}');

    final iTipo = testata.indexOf('Tipo');
    final iVoto = testata.indexOf('Voto');
    final iSet = testata.indexOf('Numero Set');
    final iCognome = testata.indexOf('Cognome');
    if (iTipo < 0 || iVoto < 0) {
      stdout.writeln('!! colonne Tipo/Voto assenti');
      continue;
    }

    final perTipo = <String, Map<String, int>>{};
    final atlete = <String>{};
    final sets = <String>{};
    for (var r = 2; r < griglia.length; r++) {
      final riga = griglia[r];
      String cella(int i) =>
          i >= 0 && i < riga.length ? riga[i].trim() : '';
      final tipo = cella(iTipo);
      if (tipo.isEmpty) continue;
      final voto = cella(iVoto);
      (perTipo[tipo] ??= {})[voto.isEmpty ? '(vuoto)' : voto] =
          ((perTipo[tipo] ?? const {})[voto.isEmpty ? '(vuoto)' : voto] ?? 0) + 1;
      if (iCognome >= 0 && cella(iCognome).isNotEmpty) {
        atlete.add(cella(iCognome));
      }
      if (iSet >= 0 && cella(iSet).isNotEmpty) sets.add(cella(iSet));
    }

    stdout.writeln('set: ${(sets.toList()..sort()).join(",")}   '
        'atlete: ${atlete.length}');
    final tipi = perTipo.keys.toList()..sort();
    for (final t in tipi) {
      final voti = perTipo[t]!;
      final totale = voti.values.fold<int>(0, (a, b) => a + b);
      final dettaglio = (voti.keys.toList()..sort())
          .map((v) => '$v=${voti[v]}')
          .join(' ');
      stdout.writeln('  ${t.padRight(30)} tot $totale   $dettaglio');
    }
    stdout.writeln('  atlete: ${(atlete.toList()..sort()).join(", ")}');
  }

  // La domanda che conta: le colonne sono le stesse in tutti i file? Se sì, un
  // solo convertitore li macina tutti.
  final diverse = intestazioni.values
      .map((c) => c.join('|'))
      .toSet();
  stdout.writeln('\n=== intestazioni distinte: ${diverse.length} ===');
  for (final d in diverse) {
    stdout.writeln('  $d');
  }
}

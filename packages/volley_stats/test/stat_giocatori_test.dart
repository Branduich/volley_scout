import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:volley_stats/backup_model.dart';
import 'package:volley_stats/enums.dart';
import 'package:volley_stats/riepilogo_stagione.dart';
import 'package:volley_stats/stat_fondamentali.dart';
import 'package:volley_stats/stat_giocatori.dart';

File _fixture(String nome) {
  for (final percorso in [
    'test/fixtures/$nome',
    'packages/volley_stats/test/fixtures/$nome',
  ]) {
    final file = File(percorso);
    if (file.existsSync()) return file;
  }
  throw StateError('fixture "$nome" non trovata da ${Directory.current.path}');
}

/// Il tabellone stagionale deve dare gli stessi numeri della mega tabella del
/// PDF: due tabelle con le stesse intestazioni che non coincidono farebbero
/// perdere fiducia in entrambe. Qui si controlla la coerenza interna — i
/// totali per giocatrice devono ricomporre gli aggregati di squadra, che sono
/// calcolati da un'altra funzione ancora.
void main() {
  late BackupCompleto backup;

  setUpAll(() {
    backup = BackupCompleto.fromJson(
      jsonDecode(_fixture('backup_v1.json').readAsStringSync())
          as Map<String, Object?>,
    );
  });

  test('una riga per giocatrice che ha giocato, ordinate per numero', () {
    final stats = statGiocatori(backup);

    expect(stats, isNotEmpty);
    expect(stats.every((s) => !s.vuota), isTrue);
    final numeri = stats.map((s) => s.giocatore.numero).toList();
    expect(numeri, orderedEquals([...numeri]..sort()));
  });

  test('i totali per giocatrice ricompongono gli aggregati di squadra', () {
    final stats = statGiocatori(backup);
    final squadra = riepilogoStagione(backup);

    // Stessa fonte, due strade diverse: se divergono, una delle due sbaglia.
    expect(stats.fold(0, (s, g) => s + g.puntiTotali), squadra.punti);
    expect(stats.fold(0, (s, g) => s + g.erroriTotali), squadra.errori);
    expect(stats.fold(0, (s, g) => s + g.azioni), squadra.azioni);
  });

  test('attacco su ricezione + attacco su difesa = attacchi totali', () {
    // È una partizione binaria: ogni attacco cade in uno dei due, mai in
    // entrambi, mai in nessuno.
    for (final s in statGiocatori(backup)) {
      expect(
        totaleVoti(s.attaccoSuRicezione) + totaleVoti(s.attaccoSuDifesa),
        totaleVoti(s.attacco),
        reason: 'giocatrice ${s.giocatore.numero}',
      );
    }
  });

  test('i murati sono un sottoinsieme degli attacchi sbagliati', () {
    for (final s in statGiocatori(backup)) {
      expect(s.murati, lessThanOrEqualTo(conteggioVoto(s.attacco, Voto.errore)),
          reason: 'giocatrice ${s.giocatore.numero}');
    }
  });

  test('filtrando una squadra inesistente non resta nessuna riga', () {
    expect(statGiocatori(backup, squadraUid: 'inesistente'), isEmpty);
  });
}

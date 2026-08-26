import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:volley_stats/backup_model.dart';
import 'package:volley_stats/enums.dart';
import 'package:volley_stats/ricalcola_stato.dart';

/// Il backup che la dashboard mostra a chi arriva senza l'app: è la vetrina, e
/// deve reggere due promesse diverse — che i numeri siano veri e che i nomi non
/// lo siano. Si rigenera con:
///
///   dart run tool/converti_stagione.dart `<cartella partite>`
///
/// I test girano dalla radice del repo o dal package a seconda di come si
/// invoca `flutter test`, da cui le due strade.
File _asset() {
  for (final p in [
    'packages/volley_web/assets/backup_demo.json',
    'assets/backup_demo.json',
  ]) {
    final f = File(p);
    if (f.existsSync()) return f;
  }
  throw StateError('backup_demo.json non trovato');
}

BackupCompleto _demo() => BackupCompleto.fromJson(
    jsonDecode(_asset().readAsStringSync()) as Map<String, Object?>);

void main() {
  test('si legge con lo stesso codice che legge i file dell\'app', () {
    // Se questo fallisce dopo un cambio di formato, la vetrina è rotta: è il
    // motivo per cui il convertitore sta nel repo e non solo il suo risultato.
    final backup = _demo();
    expect(backup.formatoVersione, kFormatoVersioneBackup);
    expect(backup.squadre, hasLength(1));
    expect(backup.giocatori, hasLength(13));
    expect(backup.partite, hasLength(5));
  });

  test('nessun nome vero è sopravvissuto all\'anonimizzazione', () {
    // La rete più importante del file: i cognomi sono di ragazze minorenni e
    // questa cartella finisce pubblicata. Una rigenerazione distratta non deve
    // poterli riportare dentro senza che nessuno se ne accorga.
    const veri = [
      'Ravaglia', 'Treccioni', 'Mohamed', 'Zannoli', 'Sartini', 'Fergacich',
      'Affuso', 'Camprini', 'Guerrini', 'Roncarati', 'Millo', 'Corradi',
      'Cerrè', 'Nettunia', 'Clai', 'Imola', 'Casalecchio', 'Mamolo', 'Vtb',
    ];
    final testo = _asset().readAsStringSync();
    for (final nome in veri) {
      expect(testo.contains(nome), isFalse, reason: '"$nome" è nel file demo');
    }
  });

  test('i punteggi si ricostruiscono rigiocando le azioni', () {
    // La stessa prova che fa il convertitore, ripetuta qui sul file committato:
    // garantisce che a rompersi sia il test e non la pagina, se una modifica al
    // formato o al replay cambia i risultati.
    final backup = _demo();
    final vinti = <int>[];

    for (final partita in backup.partite) {
      var setVinti = 0;
      for (final set in partita.sets) {
        final stato = ricalcolaStato(
          azioni: [
            for (final a in set.azioni)
              AzioneScout(ordine: a.ordine, esitoPunto: a.esitoPunto),
          ],
          servizioIniziale: set.squadraServizioIniziale,
          rotazioneIniziale: const {},
        );
        final nostri = stato.punteggioNostro + set.correzionePuntiNostri;
        final loro = stato.punteggioAvversario + set.correzionePuntiAvversari;

        // Un set di pallavolo finisce a 25 (o oltre, ai vantaggi), tranne il
        // quinto che finisce a 15. Se il replay producesse numeri qualsiasi,
        // qui si vedrebbe.
        final massimo = nostri > loro ? nostri : loro;
        expect(massimo, greaterThanOrEqualTo(15),
            reason: '${partita.nome} set ${set.numero}: $nostri-$loro');
        expect((nostri - loro).abs(), greaterThanOrEqualTo(2),
            reason: '${partita.nome} set ${set.numero}: $nostri-$loro');
        if (nostri > loro) setVinti++;
      }
      vinti.add(setVinti);
    }

    // Una stagione con dentro una storia: né tutte vinte né tutte perse,
    // altrimenti i grafici della vetrina sarebbero una riga piatta.
    expect(vinti.where((v) => v >= 3).length, greaterThan(0));
    expect(vinti.where((v) => v < 3).length, greaterThan(0));
  });

  test('ci sono partite in casa e in trasferta', () {
    // È ciò che rende esercitabile il filtro "Campo" della barra: con una sola
    // partita non si poteva verificare.
    final partite = _demo().partite;
    expect(partite.where((p) => p.inCasa), isNotEmpty);
    expect(partite.where((p) => !p.inCasa), isNotEmpty);
  });

  test('le azioni portano la giocatrice, ed è una della rosa', () {
    // Un uid che non corrisponde a nessuna atleta farebbe sparire le sue azioni
    // dal tabellone senza errori: il totale di squadra e la somma delle righe
    // non tornerebbero più.
    final backup = _demo();
    final noti = backup.giocatori.map((g) => g.uid).toSet();
    var conGiocatrice = 0;

    for (final partita in backup.partite) {
      for (final set in partita.sets) {
        for (final a in set.azioni) {
          if (a.tipo != TipoAzione.scout) continue;
          expect(a.giocatoreUid, isNotNull, reason: 'azione ${a.ordine}');
          expect(noti, contains(a.giocatoreUid));
          conGiocatrice++;
        }
      }
    }
    expect(conGiocatrice, greaterThan(1000));
  });
}

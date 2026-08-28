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
    'packages/volley_stats/assets/backup_demo.json',
    '../volley_stats/assets/backup_demo.json',
  ]) {
    final f = File(p);
    if (f.existsSync()) return f;
  }
  throw StateError('backup_demo.json non trovato');
}

BackupCompleto _demo() => BackupCompleto.fromJson(
    jsonDecode(_asset().readAsStringSync()) as Map<String, Object?>);

void main() {
  _rotazioni();

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

  group('le traiettorie sintetiche', () {
    // Sono inventate (i file di partenza non avevano coordinate) ma NON a caso:
    // le genera `tool/traiettorie_demo.dart` coerenti col voto già registrato.
    // Questi test sono ciò che impedisce a una rigenerazione distratta di
    // lasciare la vetrina con un campo vuoto, o di far cadere dentro gli errori.
    Iterable<AzioneBackup> tiri() sync* {
      for (final p in _demo().partite) {
        for (final s in p.sets) {
          for (final a in s.azioni) {
            final f = a.fondamentale;
            if (a.voto == null) continue;
            if (f == Fondamentale.battuta || f == Fondamentale.attacco) yield a;
          }
        }
      }
    }

    test('ogni battuta e ogni attacco giudicati ne hanno una', () {
      final tutti = tiri().toList();

      expect(tutti, hasLength(715));
      for (final a in tutti) {
        expect(a.traiettoriaX1, isNotNull, reason: 'azione ${a.ordine}');
        expect(a.traiettoriaY1, isNotNull);
        expect(a.traiettoriaX2, isNotNull);
        expect(a.traiettoriaY2, isNotNull);
      }
    });

    test('stanno nello spazio del campo, con lo sconfino degli errori', () {
      // 0-1 è il campo doppio; un errore può uscire, ma di poco: coordinate
      // lontanissime disegnerebbero frecce che escono dal riquadro.
      for (final a in tiri()) {
        for (final c in [
          a.traiettoriaX1!,
          a.traiettoriaY1!,
          a.traiettoriaX2!,
          a.traiettoriaY2!,
        ]) {
          expect(c, inInclusiveRange(-0.1, 1.1), reason: 'azione ${a.ordine}');
        }
      }
    });

    test('quello che il voto dice vincente cade DENTRO', () {
      // È la promessa che rende accettabile un dato inventato: il disegno e la
      // statistica raccontano la stessa partita. Un ace che atterra fuori dal
      // campo smentirebbe la tabella che gli sta accanto.
      for (final a in tiri().where((a) => a.voto == Voto.perfetto)) {
        final x = a.traiettoriaX2!;
        final y = a.traiettoriaY2!;
        // Metà avversaria: dipende da chi tira, quindi si guarda il verso.
        final versoDestra = a.traiettoriaX1! < 0.5;
        expect(versoDestra ? x > 0.5 : x < 0.5, isTrue,
            reason: 'azione ${a.ordine}: vincente nella propria metà');
        expect(x, inInclusiveRange(0.0, 1.0), reason: 'azione ${a.ordine}');
        expect(y, inInclusiveRange(0.0, 1.0), reason: 'azione ${a.ordine}');
      }
    });

    test('gli attacchi murati tornano indietro col tocco a rete', () {
      final murati = tiri()
          .where((a) => a.traiettoriaMuroX != null)
          .toList();

      expect(murati, isNotEmpty);
      for (final a in murati) {
        expect(a.fondamentale, Fondamentale.attacco);
        expect(a.voto, Voto.errore);
        expect(a.traiettoriaMuroY, isNotNull);
        // Partenza e arrivo dalla stessa parte della rete: è la condizione con
        // cui `attaccoMurato` li riconosce.
        expect((a.traiettoriaX1! < 0.5) == (a.traiettoriaX2! < 0.5), isTrue,
            reason: 'azione ${a.ordine}');
      }
    });
  });
}

/// Le rotazioni iniziali. Il controllo veniva da `test/logic/demo_match_test`,
/// cancellato col vecchio formato del demo (passo 13): l'invariante però resta
/// valido e vale la pena non perderlo. Un set con la rotazione incompleta non
/// si può ricostruire — la formazione di partenza sparirebbe dal report senza
/// nessun errore.
void _rotazioni() {
  test('almeno una partita ha le formazioni di partenza complete', () {
    // Le rotazioni vengono dallo scout dal vivo: gli `.xlsx` di partenza non
    // le hanno, quindi quattro partite su cinque ne sono prive e non possono
    // averle. Quella del 30 aprile invece sì, travasata dal vecchio demo
    // dell'app: è ciò che permette di provare in-app la formazione di
    // partenza nel report e la ripresa di un set. Se sparisse, il demo
    // smetterebbe di servire a quello senza che nessuno se ne accorga.
    var setConRotazione = 0;
    for (final p in _demo().partite) {
      for (final s in p.sets) {
        final nostre =
            s.rotazioni.where((r) => r.squadra == Squadra.nostra).toList();
        if (nostre.isEmpty) continue;
        // Dove c'è, dev'essere completa: sei posizioni, sei giocatrici
        // diverse. Una rotazione a metà è peggio di nessuna.
        expect(nostre, hasLength(6),
            reason: '${p.nome} set ${s.numero}: rotazione incompleta');
        expect(nostre.map((r) => r.posizione).toSet(), hasLength(6),
            reason: '${p.nome} set ${s.numero}: posizione ripetuta');
        expect(nostre.map((r) => r.giocatoreUid).toSet(), hasLength(6),
            reason: '${p.nome} set ${s.numero}: giocatrice ripetuta');
        setConRotazione++;
      }
    }
    expect(setConRotazione, 5);
  });
}

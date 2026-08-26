import 'package:flutter_test/flutter_test.dart';
import 'package:volley_stats/backup_model.dart';
import 'package:volley_stats/enums.dart';
import 'package:volley_stats/filtro.dart';
import 'package:volley_stats/stat_fondamentali.dart';
import 'package:volley_stats/stat_giocatori.dart';
import 'package:volley_stats/tendenza.dart';

/// La tendenza è la risposta alla domanda per cui la dashboard esiste — *questa
/// giocatrice sta migliorando?* — e una risposta sbagliata qui non si vede: il
/// grafico disegna comunque una riga convincente. Da cui questi test.
void main() {
  const uid = 'g1';

  AzioneBackup attacco(int ordine, Voto voto) => AzioneBackup(
        rallyId: ordine,
        ordine: ordine,
        secondiDaInizioPartita: ordine * 30,
        squadra: Squadra.nostra,
        tipo: TipoAzione.scout,
        fondamentale: Fondamentale.attacco,
        voto: voto,
        esitoPunto: voto == Voto.perfetto
            ? EsitoPunto.puntoNostro
            : voto == Voto.errore
                ? EsitoPunto.puntoAvversario
                : EsitoPunto.nessuno,
        giocatoreUid: uid,
      );

  /// Una partita in cui la giocatrice attacca [perfetti] volte bene, [errori]
  /// volte male e [neutri] volte così così.
  PartitaBackup partita(
    String nome,
    DateTime data, {
    int perfetti = 0,
    int errori = 0,
    int neutri = 0,
  }) {
    var ordine = 0;
    return PartitaBackup(
      uid: nome,
      nome: nome,
      dataOra: data,
      inCasa: true,
      stato: StatoPartita.terminata,
      setCorrente: 1,
      squadraUid: 's1',
      sets: [
        SetBackup(
          numero: 1,
          aperto: false,
          squadraServizioIniziale: Squadra.nostra,
          azioni: [
            for (var i = 0; i < perfetti; i++)
              attacco(ordine++, Voto.perfetto),
            for (var i = 0; i < errori; i++) attacco(ordine++, Voto.errore),
            for (var i = 0; i < neutri; i++) attacco(ordine++, Voto.positivo),
          ],
        ),
      ],
    );
  }

  BackupCompleto backupCon(List<PartitaBackup> partite) => BackupCompleto(
        formatoVersione: kFormatoVersioneBackup,
        schemaDb: 19,
        app: 'test',
        esportatoIl: DateTime(2026, 8, 26),
        squadre: const [
          SquadraBackup(
              uid: 's1', nome: 'Nettunia', categoria: 'U18', coloreDivisa: 0),
        ],
        giocatori: const [
          GiocatoreBackup(
            uid: uid,
            squadraUid: 's1',
            nome: 'Anna',
            cognome: 'Cobalto',
            numero: 7,
            ruolo: Ruolo.schiacciatore,
          ),
        ],
        partite: partite,
      );

  /// Cinque partite in cui migliora davvero: da −20% a +60% di efficienza.
  BackupCompleto stagioneInCrescita() => backupCon([
        for (var i = 0; i < 5; i++)
          partita(
            'p$i',
            DateTime(2026, 10, 5 + 7 * i),
            // 10 attacchi ogni volta: 1 perfetto in più e 1 errore in meno.
            perfetti: 2 + i,
            errori: 4 - i,
            neutri: 4,
          ),
      ]);

  group('la serie', () {
    test('un punto per partita, in ordine cronologico', () {
      final serie = serieTendenza(
        stagioneInCrescita(),
        giocatoreUid: uid,
        misura: MisuraTendenza.efficienzaAttacco,
      );

      expect(serie, hasLength(5));
      expect([for (final p in serie) p.partita.uid],
          ['p0', 'p1', 'p2', 'p3', 'p4']);
      // (perfetti − errori) / 10 × 100: −20, 0, +20, +40, +60.
      expect([for (final p in serie) p.valore], [-20, 0, 20, 40, 60]);
      expect([for (final p in serie) p.azioni], everyElement(10));
    });

    test('i numeri sono quelli del tabellone, non un secondo calcolo', () {
      // Se questo test si rompe, il grafico sta dicendo numeri diversi dalla
      // tabella che gli sta sopra — cioè la ragione per cui l'allenatore
      // smette di fidarsi di entrambi.
      final backup = stagioneInCrescita();
      final serie = serieTendenza(backup,
          giocatoreUid: uid, misura: MisuraTendenza.efficienzaAttacco);
      final tabellone = statGiocatori(backup).single;

      final azioniSerie =
          serie.fold<int>(0, (a, p) => a + p.azioni);
      expect(azioniSerie, totaleVoti(tabellone.attacco));
    });

    test('una partita senza quel fondamentale vale null, non zero', () {
      // "Non ha attaccato" non è "ha attaccato malissimo": a zero il punto
      // farebbe crollare la linea per una partita in cui non è successo nulla.
      final backup = backupCon([
        partita('con', DateTime(2026, 10, 5), perfetti: 3, neutri: 2),
        partita('senza', DateTime(2026, 10, 12)),
      ]);

      final serie = serieTendenza(backup,
          giocatoreUid: uid, misura: MisuraTendenza.efficienzaAttacco);

      expect(serie[1].valore, isNull);
      expect(serie[1].azioni, 0);
    });

    test('segue il filtro come il resto della dashboard', () {
      final serie = serieTendenza(
        stagioneInCrescita(),
        giocatoreUid: uid,
        misura: MisuraTendenza.efficienzaAttacco,
        filtro: const Filtro(periodo: PeriodoPreset.ultimeCinque),
      );
      expect(serie, hasLength(5));

      final ultimaSettimana = serieTendenza(
        stagioneInCrescita(),
        giocatoreUid: uid,
        misura: MisuraTendenza.efficienzaAttacco,
        filtro: Filtro(
          periodo: PeriodoPreset.personalizzato,
          da: DateTime(2026, 10, 26),
          a: DateTime(2026, 11, 2),
        ),
      );
      expect([for (final p in ultimaSettimana) p.partita.uid], ['p3', 'p4']);
    });

    test('di una giocatrice che non esiste non esce niente di rotto', () {
      final serie = serieTendenza(stagioneInCrescita(),
          giocatoreUid: 'sconosciuta',
          misura: MisuraTendenza.efficienzaAttacco);

      expect(serie, hasLength(5));
      expect([for (final p in serie) p.valore], everyElement(isNull));
    });
  });

  group('la retta', () {
    List<PuntoTendenza> serie(BackupCompleto b) => serieTendenza(b,
        giocatoreUid: uid, misura: MisuraTendenza.efficienzaAttacco);

    test('su una crescita regolare la pendenza è quella vera', () {
      // +20 punti a partita, esatti: se la formula sbaglia, si vede qui.
      final retta = rettaTendenza(serie(stagioneInCrescita()));

      expect(retta, isNotNull);
      expect(retta!.pendenza, closeTo(20, 0.001));
      expect(retta.intercetta, closeTo(-20, 0.001));
    });

    test('cinque partite bastano, quattro no', () {
      // Soglia decisa con l'utente: cinque è anche il preset "Ultime 5".
      final cinque = serie(stagioneInCrescita());

      expect(rettaTendenza(cinque), isNotNull);
      expect(rettaTendenza(cinque.take(4).toList()), isNull);
    });

    test('una partita con pochissime azioni non tira la retta', () {
      // Un attacco solo vale ±100% e, su cinque punti, deciderebbe da sola la
      // pendenza. Il punto resta nel grafico, ma fuori dal calcolo.
      final quasiTutte = backupCon([
        for (var i = 0; i < 4; i++)
          partita('p$i', DateTime(2026, 10, 5 + 7 * i),
              perfetti: 5, neutri: 5),
        // Un solo attacco, perfetto: 100%.
        partita('p4', DateTime(2026, 11, 2), perfetti: 1),
      ]);

      // Restano 4 punti buoni: sotto la soglia, quindi niente retta.
      expect(rettaTendenza(serie(quasiTutte)), isNull);
      // Abbassando la soglia dei punti, quello da un'azione resta comunque
      // escluso: la pendenza è piatta, non impennata.
      final retta = rettaTendenza(serie(quasiTutte), minimoPunti: 4);
      expect(retta!.pendenza, closeTo(0, 0.001));
    });

    test('i buchi non avvicinano le partite fra loro', () {
      // La x resta l'indice nella serie: se saltando un punto gli altri
      // "scivolassero" indietro, la pendenza cambierebbe senza motivo.
      final conBuco = backupCon([
        partita('p0', DateTime(2026, 10, 5), perfetti: 2, errori: 4, neutri: 4),
        partita('vuota', DateTime(2026, 10, 12)),
        partita('p2', DateTime(2026, 10, 19), perfetti: 4, errori: 2, neutri: 4),
        partita('p3', DateTime(2026, 10, 26), perfetti: 5, errori: 1, neutri: 4),
        partita('p4', DateTime(2026, 11, 2), perfetti: 6, errori: 0, neutri: 4),
        partita('p5', DateTime(2026, 11, 9), perfetti: 7, errori: 0, neutri: 3),
      ]);

      final retta = rettaTendenza(serie(conBuco), minimoPunti: 5);

      // −20, (buco), +20, +40, +60, +70 sugli indici 0,2,3,4,5.
      expect(retta, isNotNull);
      expect(retta!.pendenza, closeTo(18.5, 0.1));
    });

    test('senza nessun punto valido non si inventa una tendenza', () {
      expect(rettaTendenza(const []), isNull);
    });
  });
}

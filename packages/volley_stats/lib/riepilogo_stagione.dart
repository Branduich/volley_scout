/// Aggregati di squadra su **più partite** — la riga KPI della dashboard.
///
/// Sta qui e non nella dashboard perché è logica, non disegno: si testa senza
/// browser, e un domani la stessa funzione può alimentare una pagina dentro
/// l'app (passo 9b del piano in docs/dati-stagionali.md).
///
/// Le definizioni **non sono nuove**: ricalcano quelle già usate dai report
/// dell'app, perché due numeri con lo stesso nome che non coincidono sono
/// peggio di un numero mancante.
library;

import 'backup_model.dart';
import 'enums.dart';
import 'ricalcola_stato.dart';
import 'stat_fondamentali.dart';

/// I numeri della riga KPI. Le percentuali sono `null` quando non ci sono
/// azioni: `—`, non zero (vedi stat_fondamentali).
class RiepilogoStagione {
  const RiepilogoStagione({
    required this.partite,
    required this.partiteVinte,
    required this.setVinti,
    required this.setPersi,
    required this.punti,
    required this.errori,
    required this.azioni,
    this.efficienzaAttacco,
    this.percentualeAce,
    this.ricezionePerfetta,
  });

  final int partite;
  final int partiteVinte;
  final int setVinti;
  final int setPersi;

  /// Punti fatti: battute, attacchi e muri con voto `#` — stessa definizione di
  /// `puntiTotali` nella mega tabella del PDF.
  final int punti;

  /// Errori commessi: voto `=` su qualunque fondamentale — come `erroriTotali`.
  final int errori;

  /// Su quante azioni votate è costruito tutto: senza questo numero una
  /// percentuale non si sa se vale qualcosa (vedi docs/dati-stagionali.md).
  final int azioni;

  final double? efficienzaAttacco;
  final double? percentualeAce;
  final double? ricezionePerfetta;

  int get partitePerse => partite - partiteVinte;
}

/// Calcola la riga KPI sulle partite del backup.
///
/// [squadraUid] filtra le partite di una squadra; con `null` le prende tutte
/// (un allenatore con due squadre vedrà i selettori, ma il primo pixel no).
RiepilogoStagione riepilogoStagione(
  BackupCompleto backup, {
  String? squadraUid,
}) {
  final partite = [
    for (final p in backup.partite)
      if (squadraUid == null || p.squadraUid == squadraUid) p,
  ];

  var partiteVinte = 0, setVinti = 0, setPersi = 0;
  var punti = 0, errori = 0, azioni = 0;
  final attacco = <Voto, int>{};
  final battuta = <Voto, int>{};
  final ricezione = <Voto, int>{};

  for (final partita in partite) {
    var vintiQui = 0, persiQui = 0;

    for (final set in partita.sets) {
      // Il punteggio si RIGIOCA dagli eventi con la stessa funzione dell'app
      // (principio "stato derivato"), invece di fidarsi di un totale salvato.
      final stato = ricalcolaStato(
        azioni: [
          for (final a in set.azioni)
            AzioneScout(ordine: a.ordine, esitoPunto: a.esitoPunto),
        ],
        servizioIniziale: set.squadraServizioIniziale,
        rotazioneIniziale: {
          for (final r in set.rotazioni) r.posizione: r.giocatoreUid.hashCode,
        },
      );
      // Le correzioni manuali del punteggio non sono eventi (vedi Modello
      // dati): si sommano dopo, come fa il report.
      final nostri = stato.punteggioNostro + set.correzionePuntiNostri;
      final loro = stato.punteggioAvversario + set.correzionePuntiAvversari;
      // Un set ancora in parità non si conta per nessuno.
      if (nostri > loro) {
        vintiQui++;
      } else if (loro > nostri) {
        persiQui++;
      }

      for (final a in set.azioni) {
        if (a.tipo != TipoAzione.scout) continue;
        if (a.squadra != Squadra.nostra) continue;
        final voto = a.voto;
        if (voto == null) continue;
        azioni++;
        switch (a.fondamentale) {
          case Fondamentale.attacco:
            attacco[voto] = (attacco[voto] ?? 0) + 1;
          case Fondamentale.battuta:
            battuta[voto] = (battuta[voto] ?? 0) + 1;
          case Fondamentale.ricezione:
            ricezione[voto] = (ricezione[voto] ?? 0) + 1;
          default:
            break;
        }
        // punti = # su battuta/attacco/muro (gli unici che chiudono il punto);
        // errori = = su qualunque fondamentale.
        if (voto == Voto.perfetto &&
            (a.fondamentale == Fondamentale.battuta ||
                a.fondamentale == Fondamentale.attacco ||
                a.fondamentale == Fondamentale.muro)) {
          punti++;
        }
        if (voto == Voto.errore) errori++;
      }
    }

    setVinti += vintiQui;
    setPersi += persiQui;
    if (vintiQui > persiQui) partiteVinte++;
  }

  return RiepilogoStagione(
    partite: partite.length,
    partiteVinte: partiteVinte,
    setVinti: setVinti,
    setPersi: setPersi,
    punti: punti,
    errori: errori,
    azioni: azioni,
    efficienzaAttacco: efficienzaDaVoti(attacco),
    // Ace = battute `#` sul totale delle battute.
    percentualeAce: percentuale(
        conteggioVoto(battuta, Voto.perfetto), totaleVoti(battuta)),
    // Ricezione perfetta: solo `#`, non `#`+`+` (quella è la positività).
    ricezionePerfetta: percentuale(
        conteggioVoto(ricezione, Voto.perfetto), totaleVoti(ricezione)),
  );
}

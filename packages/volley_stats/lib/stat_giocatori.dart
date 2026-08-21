/// Statistiche per giocatrice aggregate su **più partite** — il tabellone
/// stagionale della dashboard (passo 7 del piano in docs/dati-stagionali.md).
///
/// Le definizioni ricalcano `_calcolaStatGiocatori` della mega tabella del PDF,
/// riga per riga: due tabelle con le stesse intestazioni devono dare gli stessi
/// numeri, altrimenti l'allenatore smette di fidarsi di entrambe.
library;

import 'backup_model.dart';
import 'enums.dart';
import 'stat_fondamentali.dart';

/// I contatori di una giocatrice: una mappa voto→conteggio per gruppo di
/// colonne, come nel foglio di riferimento del PDF.
class StatGiocatore {
  StatGiocatore(this.giocatore);

  final GiocatoreBackup giocatore;

  final battuta = <Voto, int>{};
  final attacco = <Voto, int>{};

  /// Partizione binaria di [attacco]: un attacco è "su ricezione" se nello
  /// stesso scambio l'ultima azione difensiva è stata una ricezione, altrimenti
  /// è "su difesa" (compresi gli attacchi senza nulla prima).
  final attaccoSuRicezione = <Voto, int>{};
  final attaccoSuDifesa = <Voto, int>{};

  final ricezione = <Voto, int>{};
  final difesa = <Voto, int>{};
  final muro = <Voto, int>{};

  /// Attacchi finiti su un muro avversario (vedi [attaccoMurato]).
  int murati = 0;

  bool get vuota =>
      battuta.isEmpty &&
      attacco.isEmpty &&
      ricezione.isEmpty &&
      difesa.isEmpty &&
      muro.isEmpty;

  /// Punti: `#` nei fondamentali che chiudono il punto. L'alzata non ha un
  /// gruppo, come nel PDF.
  int get puntiTotali =>
      conteggioVoto(battuta, Voto.perfetto) +
      conteggioVoto(attacco, Voto.perfetto) +
      conteggioVoto(muro, Voto.perfetto);

  int get erroriTotali =>
      conteggioVoto(battuta, Voto.errore) +
      conteggioVoto(attacco, Voto.errore) +
      conteggioVoto(ricezione, Voto.errore) +
      conteggioVoto(difesa, Voto.errore) +
      conteggioVoto(muro, Voto.errore);

  /// Quante azioni votate ha in tutto: è il denominatore che dice se le sue
  /// percentuali valgono qualcosa.
  int get azioni =>
      totaleVoti(battuta) +
      totaleVoti(attacco) +
      totaleVoti(ricezione) +
      totaleVoti(difesa) +
      totaleVoti(muro);

  double? get efficienzaAttacco => efficienzaDaVoti(attacco);
  double? get efficienzaBattuta => efficienzaDaVoti(battuta);
  double? get positivitaRicezione => positivitaDaVoti(ricezione);
  double? get positivitaDifesa => positivitaDaVoti(difesa);
}

/// Un attacco finito su un muro avversario: voto `=` con il punto di tocco a
/// muro registrato e la palla rimasta **nella nostra metà** (partenza e arrivo
/// dallo stesso lato della rete). Stessa regola di `attaccoMurato` nell'app.
bool attaccoMurato(AzioneBackup a) {
  if (a.tipo != TipoAzione.scout ||
      a.fondamentale != Fondamentale.attacco ||
      a.voto != Voto.errore) {
    return false;
  }
  final x1 = a.traiettoriaX1;
  final x2 = a.traiettoriaX2;
  if (x1 == null || x2 == null) return false;
  if (a.traiettoriaMuroX == null || a.traiettoriaMuroY == null) return false;
  return (x1 < 0.5) == (x2 < 0.5);
}

/// I contatori di tutte le giocatrici sulle partite del backup, ordinati per
/// numero di maglia (chi non ha azioni non compare).
///
/// [squadraUid] limita a una squadra; con `null` prende tutte le partite.
List<StatGiocatore> statGiocatori(
  BackupCompleto backup, {
  String? squadraUid,
}) {
  final perUid = {
    for (final g in backup.giocatori)
      if (squadraUid == null || g.squadraUid == squadraUid)
        g.uid: StatGiocatore(g),
  };

  for (final partita in backup.partite) {
    if (squadraUid != null && partita.squadraUid != squadraUid) continue;

    for (final set in partita.sets) {
      // La classificazione dell'attacco (su ricezione o su difesa) si decide
      // scorrendo lo scambio: si ricorda l'ultima azione difensiva del rally.
      // Nell'app serviva un Set di id perché le righe drift ne hanno uno; qui
      // le azioni sono già in ordine e si decide sul posto — stesso risultato,
      // senza bisogno di un'identità che il file non porta.
      int? rallyCorrente;
      Fondamentale? ultimaDifensiva;

      for (final a in set.azioni) {
        if (a.tipo != TipoAzione.scout) continue;
        final voto = a.voto;
        final fondamentale = a.fondamentale;
        if (voto == null || fondamentale == null) continue;

        if (a.rallyId != rallyCorrente) {
          rallyCorrente = a.rallyId;
          ultimaDifensiva = null;
        }
        // Il tracciamento vale per TUTTO lo scambio, anche per le azioni
        // avversarie: è la sequenza di gioco a definire cosa precede l'attacco.
        switch (fondamentale) {
          case Fondamentale.ricezione:
            ultimaDifensiva = Fondamentale.ricezione;
          case Fondamentale.difesa:
            ultimaDifensiva = Fondamentale.difesa;
          default:
            break;
        }

        if (a.squadra != Squadra.nostra) continue;
        final stat = perUid[a.giocatoreUid];
        if (stat == null) continue;

        void inc(Map<Voto, int> c) => c[voto] = (c[voto] ?? 0) + 1;
        switch (fondamentale) {
          case Fondamentale.battuta:
            inc(stat.battuta);
          case Fondamentale.attacco:
            inc(stat.attacco);
            inc(ultimaDifensiva == Fondamentale.ricezione
                ? stat.attaccoSuRicezione
                : stat.attaccoSuDifesa);
            if (attaccoMurato(a)) stat.murati++;
          case Fondamentale.ricezione:
            inc(stat.ricezione);
          case Fondamentale.difesa:
            inc(stat.difesa);
          case Fondamentale.muro:
            inc(stat.muro);
          default:
            break; // alzata: nessun gruppo, come nel PDF
        }
      }
    }
  }

  return perUid.values.where((s) => !s.vuota).toList()
    ..sort((a, b) => a.giocatore.numero.compareTo(b.giocatore.numero));
}

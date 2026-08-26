/// La tendenza di una giocatrice nel tempo: un punto per partita, più la retta
/// che dice se sta salendo o scendendo (passo 9 del piano in
/// docs/dati-stagionali.md).
///
/// È la domanda per cui la dashboard esiste — *questa giocatrice sta
/// migliorando?* — e il report per singola partita non può rispondere.
///
/// Le formule NON si rifanno qui: i punti escono da `statGiocatoriDaPartite`,
/// cioè dagli stessi contatori del tabellone stagionale e della mega tabella
/// del PDF. Due grafici che dicono numeri diversi dalla tabella accanto sono
/// peggio di nessun grafico.
library;

import 'backup_model.dart';
import 'filtro.dart';
import 'stat_fondamentali.dart';
import 'stat_giocatori.dart';

/// Quale numero si segue nel tempo.
///
/// Efficienza dove il fondamentale porta punti (attacco, battuta, muro),
/// positività dove prepara soltanto (ricezione, difesa) — la stessa distinzione
/// delle card del report.
enum MisuraTendenza {
  efficienzaAttacco,
  efficienzaBattuta,
  efficienzaMuro,
  positivitaRicezione,
  positivitaDifesa,
}

/// Il valore della misura per una giocatrice, con il **volume** che gli dà peso.
///
/// `valore` è `null` quando in quella partita non ha fatto nessuna azione di
/// quel fondamentale: "non ha ricevuto" non è "ha ricevuto male", e i due casi
/// non devono finire nello stesso punto a zero.
({double? valore, int azioni}) misuraDi(StatGiocatore s, MisuraTendenza m) =>
    switch (m) {
      MisuraTendenza.efficienzaAttacco => (
          valore: s.efficienzaAttacco,
          azioni: totaleVoti(s.attacco),
        ),
      MisuraTendenza.efficienzaBattuta => (
          valore: s.efficienzaBattuta,
          azioni: totaleVoti(s.battuta),
        ),
      MisuraTendenza.efficienzaMuro => (
          valore: efficienzaDaVoti(s.muro),
          azioni: totaleVoti(s.muro),
        ),
      MisuraTendenza.positivitaRicezione => (
          valore: s.positivitaRicezione,
          azioni: totaleVoti(s.ricezione),
        ),
      MisuraTendenza.positivitaDifesa => (
          valore: s.positivitaDifesa,
          azioni: totaleVoti(s.difesa),
        ),
    };

/// Un punto del grafico: una partita.
typedef PuntoTendenza = ({
  PartitaBackup partita,
  double? valore,
  int azioni,
});

/// Sotto questo numero di azioni un punto **non entra nella retta**.
///
/// Una partita con un attacco solo vale 100% o −100% e, con cinque punti in
/// tutto, da sola deciderebbe la pendenza. Il punto resta disegnato (è un dato
/// vero, e la striscia del volume dice quanto pesa), ma non tira la retta.
const int kMinimoAzioniTendenza = 3;

/// Quanti punti servono perché una retta di tendenza voglia dire qualcosa.
///
/// Cinque è una soglia bassa, scelta con l'utente: è anche il numero di partite
/// del preset "Ultime 5", quindi il filtro più usato non lascia mai il grafico
/// senza tendenza. Con due o tre punti la retta passerebbe *esattamente* per i
/// dati e sembrerebbe una certezza invece che un'impressione.
const int kMinimoPuntiTendenza = 5;

/// La serie della giocatrice, una misura per partita, in ordine cronologico.
///
/// Le partite sono quelle che passano il [filtro], come nel resto della
/// dashboard: cambiare "solo in casa" cambia anche il grafico.
List<PuntoTendenza> serieTendenza(
  BackupCompleto backup, {
  required String giocatoreUid,
  required MisuraTendenza misura,
  Filtro filtro = const Filtro(),
}) {
  final punti = <PuntoTendenza>[];
  for (final selezione in partiteFiltrate(backup, filtro)) {
    final stat = statGiocatoriDaPartite(backup, [selezione])
        .where((s) => s.giocatore.uid == giocatoreUid)
        .firstOrNull;
    final m = stat == null
        ? (valore: null, azioni: 0)
        : misuraDi(stat, misura);
    punti.add((
      partita: selezione.partita,
      valore: m.valore,
      azioni: m.azioni,
    ));
  }
  return punti;
}

/// La retta dei minimi quadrati sui punti che contano, oppure `null` se sono
/// troppo pochi per dire qualcosa.
///
/// **La x è l'indice della partita, non la data**: un allenatore ragiona per
/// partite giocate ("è cresciuta nelle ultime tre"), e con le date una sosta di
/// Natale schiaccerebbe metà stagione in un angolo del grafico.
({double intercetta, double pendenza})? rettaTendenza(
  List<PuntoTendenza> punti, {
  int minimoPunti = kMinimoPuntiTendenza,
  int minimoAzioni = kMinimoAzioniTendenza,
}) {
  // L'indice resta quello nella serie: saltare i punti scartati li
  // "avvicinerebbe" fra loro, cambiando la pendenza senza dirlo.
  final usati = <({int x, double y})>[];
  for (var i = 0; i < punti.length; i++) {
    final v = punti[i].valore;
    if (v == null || punti[i].azioni < minimoAzioni) continue;
    usati.add((x: i, y: v));
  }
  if (usati.length < minimoPunti) return null;

  final n = usati.length;
  final sommaX = usati.fold<double>(0, (a, p) => a + p.x);
  final sommaY = usati.fold<double>(0, (a, p) => a + p.y);
  final sommaXY = usati.fold<double>(0, (a, p) => a + p.x * p.y);
  final sommaXX = usati.fold<double>(0, (a, p) => a + p.x * p.x);

  final denominatore = n * sommaXX - sommaX * sommaX;
  // Tutti i punti sulla stessa ascissa: impossibile con indici distinti, ma
  // una divisione per zero non si lascia mai in piedi per fiducia.
  if (denominatore == 0) return null;

  final pendenza = (n * sommaXY - sommaX * sommaY) / denominatore;
  final intercetta = (sommaY - pendenza * sommaX) / n;
  return (intercetta: intercetta, pendenza: pendenza);
}

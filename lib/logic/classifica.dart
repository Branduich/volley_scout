/// Calcolo della classifica di campionato dalle gare importate. Funzione
/// **pura** (nessun DB, nessuna UI), sullo stile di `ricalcolaStato()`.
///
/// **Attenzione alla completezza dei dati**: l'export FIPAV può essere
/// filtrato per società, e in quel caso contiene solo le gare di UNA squadra.
/// Il calcolo resta matematicamente corretto su ciò che riceve, ma la
/// classifica è parziale — è la UI a segnalarlo (vedi [squadraUnicaDelFiltro]).
library;

import 'fipav_calendario.dart';

/// Riga di classifica di una squadra.
class RigaClassifica {
  const RigaClassifica({
    required this.squadra,
    required this.giocate,
    required this.vinte,
    required this.perse,
    required this.punti,
    required this.setVinti,
    required this.setPersi,
    required this.puntiFatti,
    required this.puntiSubiti,
  });

  final String squadra;
  final int giocate;
  final int vinte;
  final int perse;

  /// Punti di classifica secondo il regolamento FIPAV (3/2/1/0, vedi
  /// [calcolaClassifica]).
  final int punti;

  final int setVinti;
  final int setPersi;

  /// Punti realizzati/subiti nei singoli set (dai parziali). Restano a 0 se il
  /// file non riporta i parziali: in quel caso il quoziente punti non è un
  /// criterio utilizzabile, ma punti e set restano corretti.
  final int puntiFatti;
  final int puntiSubiti;

  /// Rapporto set vinti/persi. Con zero set persi si usa un valore molto alto
  /// invece di infinito, così l'ordinamento resta totale e confrontabile.
  double get quozienteSet =>
      setPersi == 0 ? (setVinti == 0 ? 0 : 9999) : setVinti / setPersi;

  double get quozientePunti => puntiSubiti == 0
      ? (puntiFatti == 0 ? 0 : 9999)
      : puntiFatti / puntiSubiti;
}

/// Accumulatore interno, mutabile durante lo scorrimento delle gare.
class _Acc {
  _Acc(this.squadra);
  final String squadra;
  int giocate = 0;
  int vinte = 0;
  int perse = 0;
  int punti = 0;
  int setVinti = 0;
  int setPersi = 0;
  int puntiFatti = 0;
  int puntiSubiti = 0;

  RigaClassifica toRiga() => RigaClassifica(
        squadra: squadra,
        giocate: giocate,
        vinte: vinte,
        perse: perse,
        punti: punti,
        setVinti: setVinti,
        setPersi: setPersi,
        puntiFatti: puntiFatti,
        puntiSubiti: puntiSubiti,
      );
}

/// Punti di classifica assegnati al vincitore e al perdente di una gara,
/// secondo il regolamento FIPAV: **3-0 e 3-1 → 3 punti** al vincitore e 0 al
/// perdente; **3-2 → 2 punti** al vincitore e **1** al perdente (il set
/// decisivo "vale" un punto anche a chi lo perde).
(int vincitore, int perdente) puntiGara(int setVincitore, int setPerdente) {
  if (setPerdente >= 2) return (2, 1);
  return (3, 0);
}

/// Costruisce la classifica dalle gare **giocate**. Le squadre compaiono tutte
/// (anche quelle senza gare giocate, se presenti a calendario) così la tabella
/// riflette il girone e non solo chi ha già giocato.
///
/// Ordinamento (regolamento FIPAV): punti, **gare vinte**, quoziente set,
/// quoziente punti, poi nome.
List<RigaClassifica> calcolaClassifica(Iterable<GaraFipav> gare) {
  final acc = <String, _Acc>{};
  _Acc perSquadra(String nome) => acc.putIfAbsent(nome, () => _Acc(nome));

  for (final g in gare) {
    final casa = perSquadra(g.squadraCasa);
    final ospite = perSquadra(g.squadraOspite);

    final setCasa = g.setCasa;
    final setOspite = g.setOspite;
    if (setCasa == null || setOspite == null) continue; // non ancora giocata
    if (setCasa == setOspite) continue; // impossibile a pallavolo: dato sporco

    casa.giocate++;
    ospite.giocate++;
    casa.setVinti += setCasa;
    casa.setPersi += setOspite;
    ospite.setVinti += setOspite;
    ospite.setPersi += setCasa;

    for (final (pCasa, pOspite) in g.parzialiParsed) {
      casa.puntiFatti += pCasa;
      casa.puntiSubiti += pOspite;
      ospite.puntiFatti += pOspite;
      ospite.puntiSubiti += pCasa;
    }

    final vinceCasa = setCasa > setOspite;
    final vincitore = vinceCasa ? casa : ospite;
    final perdente = vinceCasa ? ospite : casa;
    final (pV, pP) = puntiGara(
      vinceCasa ? setCasa : setOspite,
      vinceCasa ? setOspite : setCasa,
    );
    vincitore.vinte++;
    vincitore.punti += pV;
    perdente.perse++;
    perdente.punti += pP;
  }

  final righe = acc.values.map((a) => a.toRiga()).toList()
    ..sort((a, b) {
      final p = b.punti.compareTo(a.punti);
      if (p != 0) return p;
      // Regolamento FIPAV/FIVB: a parità di punti conta prima il NUMERO DI
      // GARE VINTE, poi i quozienti. Non è ridondante con i punti: due
      // squadre a pari punti possono avere vittorie diverse (chi vince molti
      // 3-2 fa 2 punti a gara, chi vince 3-0 ne fa 3).
      final v = b.vinte.compareTo(a.vinte);
      if (v != 0) return v;
      final qs = b.quozienteSet.compareTo(a.quozienteSet);
      if (qs != 0) return qs;
      final qp = b.quozientePunti.compareTo(a.quozientePunti);
      if (qp != 0) return qp;
      return a.squadra.compareTo(b.squadra);
    });
  return righe;
}

/// `true` se tutte le gare passate coinvolgono la stessa squadra: è il segno
/// che l'export è filtrato per società e la classifica risultante è parziale
/// (mancano gli scontri diretti fra le altre squadre). Ritorna il nome di
/// quella squadra, `null` se i dati sembrano completi.
String? squadraUnicaDelFiltro(Iterable<GaraFipav> gare) {
  final lista = gare.toList();
  if (lista.length < 2) return null;
  Set<String>? comuni;
  for (final g in lista) {
    final s = {g.squadraCasa, g.squadraOspite};
    comuni = comuni == null ? s : comuni.intersection(s);
    if (comuni.isEmpty) return null;
  }
  return comuni!.length == 1 ? comuni.first : null;
}

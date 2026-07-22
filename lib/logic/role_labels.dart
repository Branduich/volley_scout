import '../data/database.dart';
import '../models/enums.dart';

/// Ordine antiorario degli slot sul campo (stesso di `_kSlotOrder` in
/// scout_screen.dart), usato per la distanza dal palleggiatore.
const List<String> kSlotOrder = ['P1', 'P2', 'P3', 'P4', 'P5', 'P6'];

/// Etichette di ruolo (P/O/S1/S2/C1/C2) per ogni slot, basate sul ruolo
/// REALE del giocatore assegnato (non su un pattern fisso): il
/// palleggiatore designato è sempre "P", l'opposto è sempre "O". Tra i due
/// schiacciatori, quello più vicino al palleggiatore (in senso antiorario)
/// è "S1", l'altro (diametralmente opposto, a 3 posizioni) è "S2" — stessa
/// logica per i centrali ("C1"/"C2").
///
/// **Universale (Ruolo.undefined) = completamento**: può giocare al posto
/// di qualsiasi ruolo tranne il libero, quindi NON ha un'etichetta fissa —
/// riempie le etichette MANCANTI nella composizione canonica
/// {O, S1, S2, C1, C2}. Per le coppie si preferisce l'universale che sta a
/// 3 posizioni (opposto nel ring) dal compagno di coppia esistente; per la
/// 'O' quello opposto al palleggiatore. Dopo una sostituzione, l'etichetta
/// mancante è esattamente quella di chi è uscito: l'universale ne eredita
/// il ruolo tattico. Universali in eccesso restano senza etichetta
/// (fallback su posizione a griglia in ScoutScreen, mai un crash).
///
/// Estratta da scout_screen.dart in un file di logica pura (nessuna
/// dipendenza da UI) per poterla testare — vedi
/// test/logic/role_labels_test.dart.
Map<String, String> roleLabelsFor(
    String palleggiatoreSlot, Map<String, Player> assignments) {
  final startIndex = kSlotOrder.indexOf(palleggiatoreSlot);
  int distanceFromP(String slot) =>
      (kSlotOrder.indexOf(slot) - startIndex + kSlotOrder.length) %
      kSlotOrder.length;
  String ringOpposite(String slot) =>
      kSlotOrder[(kSlotOrder.indexOf(slot) + 3) % kSlotOrder.length];

  final schiacciatori = <String>[];
  final centrali = <String>[];
  final universali = <String>[];
  // Palleggiatori NON designati (doppio cambio: un secondo palleggiatore in
  // campo al posto di un altro ruolo) — raccolti a parte e assegnati DOPO
  // il ciclo, così non rubano la 'O' all'opposto vero se compaiono prima
  // di lui nell'ordine degli slot.
  final palleggiatoriExtra = <String>[];
  String? opposto;

  for (final slot in kSlotOrder) {
    if (slot == palleggiatoreSlot) continue;
    switch (assignments[slot]?.ruolo) {
      case Ruolo.opposto:
        opposto = slot;
      case Ruolo.schiacciatore:
        schiacciatori.add(slot);
      case Ruolo.centrale:
        centrali.add(slot);
      case Ruolo.undefined:
        universali.add(slot);
      case Ruolo.palleggiatore:
        palleggiatoriExtra.add(slot);
      default:
        break;
    }
  }
  // Euristica per il palleggiatore extra: gioca da opposto se la 'O' è
  // libera (il caso reale del doppio cambio: P entra per O), altrimenti
  // conta come schiacciatore — degradazione accettabile, mai senza label.
  for (final slot in palleggiatoriExtra) {
    if (opposto == null) {
      opposto = slot;
    } else {
      schiacciatori.add(slot);
    }
  }
  schiacciatori.sort((a, b) => distanceFromP(a).compareTo(distanceFromP(b)));
  centrali.sort((a, b) => distanceFromP(a).compareTo(distanceFromP(b)));
  universali.sort((a, b) => distanceFromP(a).compareTo(distanceFromP(b)));

  // Completamento: gli universali riempiono le etichette mancanti.
  // `vicinoA` = lo slot il cui opposto nel ring è il candidato preferito
  // (il compagno di coppia sta sempre a 3 posizioni di distanza).
  String? prendiUniversale({String? vicinoA}) {
    if (universali.isEmpty) return null;
    if (vicinoA != null) {
      final preferito = ringOpposite(vicinoA);
      if (universali.remove(preferito)) return preferito;
    }
    return universali.removeAt(0);
  }

  // L'opposto è canonicamente a 3 posizioni dal palleggiatore.
  opposto ??= prendiUniversale(vicinoA: palleggiatoreSlot);
  if (schiacciatori.length == 1) {
    final u = prendiUniversale(vicinoA: schiacciatori[0]);
    if (u != null) schiacciatori.add(u);
  } else if (schiacciatori.isEmpty) {
    for (var i = 0; i < 2; i++) {
      final u = prendiUniversale();
      if (u != null) schiacciatori.add(u);
    }
    schiacciatori
        .sort((a, b) => distanceFromP(a).compareTo(distanceFromP(b)));
  }
  if (centrali.length == 1) {
    final u = prendiUniversale(vicinoA: centrali[0]);
    if (u != null) centrali.add(u);
  } else if (centrali.isEmpty) {
    for (var i = 0; i < 2; i++) {
      final u = prendiUniversale();
      if (u != null) centrali.add(u);
    }
    centrali.sort((a, b) => distanceFromP(a).compareTo(distanceFromP(b)));
  }

  final labels = <String, String>{palleggiatoreSlot: 'P'};
  if (opposto != null) labels[opposto] = 'O';
  if (schiacciatori.isNotEmpty) labels[schiacciatori[0]] = 'S1';
  if (schiacciatori.length > 1) labels[schiacciatori[1]] = 'S2';
  if (centrali.isNotEmpty) labels[centrali[0]] = 'C1';
  if (centrali.length > 1) labels[centrali[1]] = 'C2';
  return labels;
}

/// Ordine canonico dei ruoli in un 5-1, partendo dal palleggiatore e girando
/// nel verso della rotazione (offset 0 = P, poi S1, C1, O, S2, C2): l'opposto
/// è diagonale al palleggiatore (3 posizioni), le coppie S1/S2 e C1/C2 sono
/// opposte tra loro. Disposizione standard "schiacciatore-centrale-opposto".
const List<String> _kRuoliCanonici51 = ['P', 'S1', 'C1', 'O', 'S2', 'C2'];

/// Etichette di ruolo placeholder per la squadra AVVERSARIA, derivate dal solo
/// slot (1-6) del loro palleggiatore in un 5-1 canonico (`_kRuoliCanonici51`).
/// Non avendo il loro roster si assume la disposizione standard: da qui i 6
/// token placeholder che ruotano sulla metà campo opposta. Ritorna
/// zona (1-6) -> etichetta. Pura e testabile (vedi role_labels_test.dart).
Map<int, String> etichetteAvversarie(int palleggiatoreSlot) => {
      for (var zona = 1; zona <= 6; zona++)
        zona: _kRuoliCanonici51[(zona - palleggiatoreSlot + 6) % 6],
    };

/// Alias leggibile del codice ruolo avversario (P/O/S1/S2/C1/C2) per i
/// selettori del report — il valore salvato/filtrato resta il codice.
const Map<String, String> kAliasRuoloAvversario = {
  'P': 'Palleggiatore',
  'O': 'Opposto',
  'S1': 'Schiacciatore 1',
  'S2': 'Schiacciatore 2',
  'C1': 'Centrale 1',
  'C2': 'Centrale 2',
};

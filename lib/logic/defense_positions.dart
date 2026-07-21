/// Posizioni di RICEZIONE (battuta avversaria) per rotazione (chiave esterna =
/// slot del palleggiatore, 'P1'..'P6') e RUOLO (stessi codici di
/// `roleLabelsFor`: P, O, S1, S2, C1, C2, più 'Libero') — estratte da
/// `scout_screen.dart` (dov'erano costanti private usate da `_activeDefenseMap`)
/// per poter essere riusate anche dalla formazione di ricezione AVVERSARIA
/// (mirror) e, in prospettiva, dal configuratore posizioni.
///
/// Coordinate nello spazio di riferimento 1200×600 di `double_court_bg.png`,
/// campo sinistro (rete a x=600). Caso "libero sui centrali": il libero
/// sostituisce il centrale di seconda linea, che quindi non compare per quella
/// rotazione (solo il centrale a rete resta). Caso "libero sugli schiacciatori":
/// entrambi i centrali restano, il libero sostituisce lo schiacciatore di
/// seconda linea. La variante "senza libero" unisce le due tabelle e scarta
/// 'Libero' — vedi `defensePositionsComplete`.
library;

import 'dart:ui' show Offset;

const Map<String, Map<String, Offset>> kDefensePositionsCentrali = {
  'P1': {
    'S1': Offset(240, 482),
    'Libero': Offset(166, 300),
    'P': Offset(206, 560),
    'S2': Offset(240, 114),
    'C1': Offset(540, 324),
    'O': Offset(444, 50),
  },
  'P2': {
    'P': Offset(552, 356),
    'C1': Offset(498, 50),
    'Libero': Offset(240, 482),
    'S1': Offset(240, 114),
    'S2': Offset(166, 296),
    'O': Offset(60, 266),
  },
  'P3': {
    'P': Offset(552, 356),
    'C2': Offset(470, 384),
    'O': Offset(84, 416),
    'S1': Offset(240, 114),
    'S2': Offset(240, 482),
    'Libero': Offset(166, 296),
  },
  'P4': {
    'P': Offset(552, 50),
    'C2': Offset(460, 76),
    'O': Offset(180, 550),
    'S1': Offset(166, 296),
    'S2': Offset(240, 114),
    'Libero': Offset(240, 482),
  },
  'P5': {
    'P': Offset(518, 254),
    'C2': Offset(552, 50),
    'S1': Offset(166, 296),
    'S2': Offset(240, 114),
    'Libero': Offset(240, 482),
    'O': Offset(438, 542),
  },
  'P6': {
    'O': Offset(552, 274),
    'S2': Offset(240, 114),
    'S1': Offset(240, 482),
    'Libero': Offset(166, 296),
    'P': Offset(470, 314),
    'C1': Offset(438, 542),
  },
};

const Map<String, Map<String, Offset>> kDefensePositionsSchiacciatori = {
  'P1': {
    'S1': Offset(240, 482),
    'O': Offset(444, 50),
    'C1': Offset(540, 324),
    'P': Offset(206, 560),
    'Libero': Offset(240, 114),
    'C2': Offset(166, 300),
  },
  'P2': {
    'P': Offset(552, 356),
    'O': Offset(60, 266),
    'C1': Offset(498, 50),
    'S1': Offset(240, 114),
    'Libero': Offset(166, 296),
    'C2': Offset(240, 482),
  },
  'P3': {
    'P': Offset(552, 356),
    'C2': Offset(470, 384),
    'O': Offset(84, 416),
    'S1': Offset(240, 114),
    'Libero': Offset(240, 482),
    'C1': Offset(166, 296),
  },
  'P4': {
    'P': Offset(552, 50),
    'C2': Offset(460, 76),
    'O': Offset(180, 550),
    'S2': Offset(240, 114),
    'Libero': Offset(166, 296),
    'C1': Offset(240, 482),
  },
  'P5': {
    'P': Offset(518, 254),
    'C2': Offset(552, 50),
    'S2': Offset(240, 114),
    'O': Offset(438, 542),
    'Libero': Offset(166, 296),
    'C1': Offset(240, 482),
  },
  'P6': {
    'O': Offset(552, 274),
    'P': Offset(470, 314),
    'C1': Offset(438, 542),
    'S2': Offset(240, 114),
    'Libero': Offset(240, 482),
    'C2': Offset(166, 296),
  },
};

/// Stessa "forma" difensiva delle due tabelle, ma per formazioni SENZA libero:
/// nessun ruolo va sostituito, servono le posizioni REALI di tutti e 6 i ruoli.
/// Le due tabelle con libero ne contengono al più 5 (un ruolo è 'Libero' al
/// posto del sostituito), ma INSIEME si completano: il ruolo mancante in una è
/// presente nell'altra (dove la coppia sostituita è l'opposta). Unendole e
/// scartando 'Libero' si ottengono i 6 ruoli reali — i ruoli condivisi hanno le
/// stesse coordinate in entrambe (verificato). Null se la fusione non copre
/// tutti e 6 i ruoli (dato incoerente).
Map<String, Offset>? defensePositionsComplete(String slot) {
  final centrali = kDefensePositionsCentrali[slot];
  final schiacciatori = kDefensePositionsSchiacciatori[slot];
  if (centrali == null || schiacciatori == null) return null;
  final merged = {...centrali, ...schiacciatori}..remove('Libero');
  const ruoliCompleti = {'P', 'O', 'S1', 'S2', 'C1', 'C2'};
  return ruoliCompleti.every(merged.containsKey) ? merged : null;
}

/// Tabella ruolo→posizione di ricezione per rotazione/variante libero — parte
/// PURA di selezione (le guardie di fase "stiamo ricevendo / ricezione non
/// ancora giudicata" restano nel chiamante, vedi `ScoutScreen._activeDefenseMap`).
/// "senza libero" → posizioni complete dei 6 ruoli; altrimenti tabella centrali
/// o schiacciatori con il controllo di completezza (P, O, Libero, coppia fissa
/// completa, coppia sostituita con UN solo elemento presente). Null se i dati
/// della rotazione sono incompleti.
Map<String, Offset>? defenseMapFor({
  required String rotazione,
  required bool senzaLibero,
  required bool liberoSuSchiacciatori,
}) {
  if (senzaLibero) return defensePositionsComplete(rotazione);
  final tabella = liberoSuSchiacciatori
      ? kDefensePositionsSchiacciatori
      : kDefensePositionsCentrali;
  final coppiaSostituita =
      liberoSuSchiacciatori ? const ['S1', 'S2'] : const ['C1', 'C2'];
  final coppiaFissa =
      liberoSuSchiacciatori ? const ['C1', 'C2'] : const ['S1', 'S2'];
  final map = tabella[rotazione];
  if (map == null) return null;
  final unaSolaSostituita =
      map.containsKey(coppiaSostituita[0]) != map.containsKey(coppiaSostituita[1]);
  final completa = map.containsKey('P') &&
      map.containsKey('O') &&
      map.containsKey('Libero') &&
      coppiaFissa.every(map.containsKey) &&
      unaSolaSostituita;
  return completa ? map : null;
}

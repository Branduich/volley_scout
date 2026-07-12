/// Posizioni TATTICHE di attacco per rotazione (chiave esterna = slot del
/// palleggiatore, 'P1'..'P6'), RUOLO (stessi codici di `roleLabelsFor`:
/// P, O, S1, S2, C1, C2, più 'Libero') e FASE — estratte da
/// `scout_screen.dart` (dov'erano costanti private usate per disegnare i
/// token) per essere riusate dal report PDF: la "posizione di attacco" di
/// un giocatore è la zona in cui queste tabelle lo schierano al momento
/// dell'azione, non la sua zona di rotazione.
///
/// Coordinate nello spazio di riferimento 1200×600 di
/// `double_court_bg.png`, campo sinistro (rete a x=600). Le fasi
/// Dopo_Battuta e Dopo_Ricezione NON sempre coincidono (dipende dalla
/// rotazione). L'eccezione "il libero non può servire" è implicita nei
/// dati: quando il giocatore che il libero sostituirebbe deve servire, in
/// Battuta e Dopo_Battuta compare lui stesso invece di 'Libero'.
library;

import 'dart:ui' show Offset;

/// Fase dello scambio a cui appartiene una posizione di attacco.
enum FaseAttacco { battuta, dopoBattuta, dopoRicezione }

const Map<String, Map<String, Offset>> kAttackBattutaCentrali = {
  'P1': {
    'P': Offset(-60, 470),
    'S1': Offset(530, 470),
    'C1': Offset(530, 300),
    'O': Offset(530, 130),
    'S2': Offset(200, 130),
    'Libero': Offset(200, 300),
  },
  'P2': {
    'C2': Offset(-60, 470),
    'P': Offset(530, 470),
    'S1': Offset(530, 300),
    'C1': Offset(530, 130),
    'O': Offset(200, 130),
    'S2': Offset(200, 300),
  },
  'P3': {
    'S2': Offset(-60, 470),
    'C2': Offset(530, 470),
    'P': Offset(530, 300),
    'S1': Offset(530, 130),
    'Libero': Offset(200, 130),
    'O': Offset(200, 300),
  },
  'P4': {
    'O': Offset(-60, 470),
    'S2': Offset(530, 470),
    'C2': Offset(530, 300),
    'P': Offset(530, 130),
    'S1': Offset(200, 130),
    'Libero': Offset(200, 300),
  },
  'P5': {
    'C1': Offset(-60, 470),
    'O': Offset(530, 470),
    'S2': Offset(530, 300),
    'C2': Offset(530, 130),
    'P': Offset(200, 130),
    'S1': Offset(200, 300),
  },
  'P6': {
    'S1': Offset(-60, 470),
    'C1': Offset(530, 470),
    'O': Offset(530, 300),
    'S2': Offset(530, 130),
    'Libero': Offset(200, 130),
    'P': Offset(200, 300),
  },
};

const Map<String, Map<String, Offset>> kAttackDopoBattutaCentrali = {
  'P1': {
    'P': Offset(200, 470),
    'O': Offset(530, 470),
    'C1': Offset(530, 300),
    'S1': Offset(530, 130),
    'Libero': Offset(200, 130),
    'S2': Offset(200, 300),
  },
  'P2': {
    // P e O invertiti tra loro rispetto alla versione iniziale (bug: dopo
    // battuta in P2 il palleggiatore va a rete a destra, l'opposto in
    // seconda linea a sinistra — coerente con Dopo_Ricezione P2).
    'P': Offset(530, 470),
    'O': Offset(200, 470),
    'C1': Offset(530, 300),
    'S1': Offset(530, 130),
    'C2': Offset(200, 130),
    'S2': Offset(200, 300),
  },
  'P3': {
    'O': Offset(200, 470),
    'P': Offset(530, 470),
    'C2': Offset(530, 300),
    'S1': Offset(530, 130),
    'Libero': Offset(200, 130),
    'S2': Offset(200, 300),
  },
  'P4': {
    'O': Offset(200, 470),
    'P': Offset(530, 470),
    'C2': Offset(530, 300),
    'S2': Offset(530, 130),
    'Libero': Offset(200, 130),
    'S1': Offset(200, 300),
  },
  'P5': {
    'P': Offset(200, 470),
    'O': Offset(530, 470),
    'C2': Offset(530, 300),
    'S2': Offset(530, 130),
    'C1': Offset(200, 130),
    'S1': Offset(200, 300),
  },
  'P6': {
    'P': Offset(200, 470),
    'O': Offset(530, 470),
    'C1': Offset(530, 300),
    'S2': Offset(530, 130),
    'Libero': Offset(200, 130),
    'S1': Offset(200, 300),
  },
};

// Coincide con kAttackDopoBattutaCentrali per P3, P4 e P6 (confermato dallo
// sviluppatore) ma differisce per P1, P2 e P5: dopo aver ricevuto la
// squadra si schiera diversamente rispetto a dopo aver servito.
const Map<String, Map<String, Offset>> kAttackDopoRicezioneCentrali = {
  'P1': {
    'P': Offset(200, 470),
    'S1': Offset(530, 470),
    'C1': Offset(530, 300),
    'O': Offset(530, 130),
    'Libero': Offset(200, 130),
    'S2': Offset(200, 300),
  },
  'P2': {
    'O': Offset(200, 470),
    'P': Offset(530, 470),
    'C1': Offset(530, 300),
    'S1': Offset(530, 130),
    'Libero': Offset(200, 130),
    'S2': Offset(200, 300),
  },
  'P3': {
    'O': Offset(200, 470),
    'P': Offset(530, 470),
    'C2': Offset(530, 300),
    'S1': Offset(530, 130),
    'Libero': Offset(200, 130),
    'S2': Offset(200, 300),
  },
  'P4': {
    'O': Offset(200, 470),
    'P': Offset(530, 470),
    'C2': Offset(530, 300),
    'S2': Offset(530, 130),
    'Libero': Offset(200, 130),
    'S1': Offset(200, 300),
  },
  'P5': {
    'P': Offset(200, 470),
    'O': Offset(530, 470),
    'C2': Offset(530, 300),
    'S2': Offset(530, 130),
    'Libero': Offset(200, 130),
    'S1': Offset(200, 300),
  },
  'P6': {
    'P': Offset(200, 470),
    'O': Offset(530, 470),
    'C1': Offset(530, 300),
    'S2': Offset(530, 130),
    'Libero': Offset(200, 130),
    'S1': Offset(200, 300),
  },
};

// Equivalenti per il caso "libero sugli schiacciatori" (entrambi i
// centrali restano in campo, il libero sostituisce lo schiacciatore di
// seconda linea). P3 e P6 non hanno 'Libero' in Battuta e Dopo_Battuta:
// in quelle rotazioni lo schiacciatore che il libero sostituirebbe è
// proprio quello che serve — eccezione "il libero non può servire"
// (stesso pattern di P2 nelle tabelle centrali, dove serve C2): per tutto
// quel turno di servizio il libero resta fuori. In Dopo_Ricezione tutte
// e 6 le rotazioni hanno 'Libero'.
const Map<String, Map<String, Offset>> kAttackBattutaSchiacciatori = {
  'P1': {
    'P': Offset(-60, 470),
    'S1': Offset(530, 470),
    'C1': Offset(530, 300),
    'O': Offset(530, 130),
    'Libero': Offset(200, 130),
    'C2': Offset(200, 300),
  },
  'P2': {
    'C2': Offset(-60, 470),
    'P': Offset(530, 470),
    'S1': Offset(530, 300),
    'C1': Offset(530, 130),
    'O': Offset(200, 130),
    'Libero': Offset(200, 300),
  },
  'P3': {
    'S2': Offset(-60, 470),
    'C2': Offset(530, 470),
    'P': Offset(530, 300),
    'S1': Offset(530, 130),
    'C1': Offset(200, 130),
    'O': Offset(200, 300),
  },
  'P4': {
    'O': Offset(-60, 470),
    'S2': Offset(530, 470),
    'C2': Offset(530, 300),
    'P': Offset(530, 130),
    'Libero': Offset(200, 130),
    'C1': Offset(200, 300),
  },
  'P5': {
    'C1': Offset(-60, 470),
    'O': Offset(530, 470),
    'S2': Offset(530, 300),
    'C2': Offset(530, 130),
    'P': Offset(200, 130),
    'Libero': Offset(200, 300),
  },
  'P6': {
    'S1': Offset(-60, 470),
    'C1': Offset(530, 470),
    'O': Offset(530, 300),
    'S2': Offset(530, 130),
    'C2': Offset(200, 130),
    'P': Offset(200, 300),
  },
};

const Map<String, Map<String, Offset>> kAttackDopoBattutaSchiacciatori = {
  'P1': {
    'P': Offset(200, 470),
    'O': Offset(530, 470),
    'C1': Offset(530, 300),
    'S1': Offset(530, 130),
    'C2': Offset(200, 130),
    'Libero': Offset(200, 300),
  },
  'P2': {
    // P e O invertiti tra loro (stesso bug/fix della variante centrali).
    'P': Offset(530, 470),
    'O': Offset(200, 470),
    'C1': Offset(530, 300),
    'S1': Offset(530, 130),
    'C2': Offset(200, 130),
    'Libero': Offset(200, 300),
  },
  'P3': {
    'O': Offset(200, 470),
    'P': Offset(530, 470),
    'C2': Offset(530, 300),
    'S1': Offset(530, 130),
    'C1': Offset(200, 130),
    'S2': Offset(200, 300),
  },
  'P4': {
    'O': Offset(200, 470),
    'P': Offset(530, 470),
    'C2': Offset(530, 300),
    'S2': Offset(530, 130),
    'C1': Offset(200, 130),
    'Libero': Offset(200, 300),
  },
  'P5': {
    'P': Offset(200, 470),
    'O': Offset(530, 470),
    'C2': Offset(530, 300),
    'S2': Offset(530, 130),
    'C1': Offset(200, 130),
    'Libero': Offset(200, 300),
  },
  'P6': {
    'P': Offset(200, 470),
    'O': Offset(530, 470),
    'C1': Offset(530, 300),
    'S2': Offset(530, 130),
    'C2': Offset(200, 130),
    'S1': Offset(200, 300),
  },
};

const Map<String, Map<String, Offset>> kAttackDopoRicezioneSchiacciatori = {
  'P1': {
    'P': Offset(200, 470),
    'S1': Offset(530, 470),
    'C1': Offset(530, 300),
    'O': Offset(530, 130),
    'C2': Offset(200, 130),
    'Libero': Offset(200, 300),
  },
  'P2': {
    'O': Offset(200, 470),
    'P': Offset(530, 470),
    'C1': Offset(530, 300),
    'S1': Offset(530, 130),
    'C2': Offset(200, 130),
    'Libero': Offset(200, 300),
  },
  'P3': {
    'O': Offset(200, 470),
    'P': Offset(530, 470),
    'C2': Offset(530, 300),
    'S1': Offset(530, 130),
    'C1': Offset(200, 130),
    'Libero': Offset(200, 300),
  },
  'P4': {
    'O': Offset(200, 470),
    'P': Offset(530, 470),
    'C2': Offset(530, 300),
    'S2': Offset(530, 130),
    'C1': Offset(200, 130),
    'Libero': Offset(200, 300),
  },
  'P5': {
    'P': Offset(200, 470),
    'O': Offset(530, 470),
    'C2': Offset(530, 300),
    'S2': Offset(530, 130),
    'C1': Offset(200, 130),
    'Libero': Offset(200, 300),
  },
  'P6': {
    'P': Offset(200, 470),
    'O': Offset(530, 470),
    'C1': Offset(530, 300),
    'S2': Offset(530, 130),
    'C2': Offset(200, 130),
    'Libero': Offset(200, 300),
  },
};

/// Per rotazione, quale centrale verrebbe sostituito dal libero (l'altro è
/// sempre quello "fisso" già presente nelle tabelle) — usata per derivare
/// le tabelle "senza libero" dalle tabelle "libero sui centrali" senza
/// duplicare i dati: senza libero quel centrale gioca semplicemente lui
/// stesso, nella stessa posizione tattica.
const Map<String, String> kRuoloSostituitoCentrali = {
  'P1': 'C2',
  'P2': 'C2',
  'P3': 'C1',
  'P4': 'C1',
  'P5': 'C1',
  'P6': 'C2',
};

/// Deriva la tabella "senza libero" da una delle tabelle centrali:
/// sostituisce la chiave 'Libero' (se presente — durante l'eccezione del
/// servizio non c'è, la tabella è già completa) con il centrale reale di
/// [kRuoloSostituitoCentrali], stessa Offset.
Map<String, Offset>? attackSenzaLiberoDaCentrali(
    Map<String, Map<String, Offset>> tabellaCentrali, String slot) {
  final mappa = tabellaCentrali[slot];
  if (mappa == null) return null;
  final posizioneLibero = mappa['Libero'];
  if (posizioneLibero == null) return mappa; // già completa
  final ruoloSostituito = kRuoloSostituitoCentrali[slot]!;
  return {...mappa, ruoloSostituito: posizioneLibero}..remove('Libero');
}

/// Tabella ruolo→posizione per rotazione/fase/variante libero — la stessa
/// selezione di `ScoutScreen._activeAttackMap`, in forma pura: "senza
/// libero" derivata dalle tabelle centrali, altrimenti tabella centrali o
/// schiacciatori in base alla coppia sostituita.
Map<String, Offset>? attackMapFor({
  required String rotazione,
  required FaseAttacco fase,
  required bool senzaLibero,
  required bool liberoSuSchiacciatori,
}) {
  final (centrali, schiacciatori) = switch (fase) {
    FaseAttacco.battuta =>
      (kAttackBattutaCentrali, kAttackBattutaSchiacciatori),
    FaseAttacco.dopoBattuta =>
      (kAttackDopoBattutaCentrali, kAttackDopoBattutaSchiacciatori),
    FaseAttacco.dopoRicezione =>
      (kAttackDopoRicezioneCentrali, kAttackDopoRicezioneSchiacciatori),
  };
  if (senzaLibero) return attackSenzaLiberoDaCentrali(centrali, rotazione);
  return liberoSuSchiacciatori
      ? schiacciatori[rotazione]
      : centrali[rotazione];
}

/// Zona del campo (1-6) di una posizione tattica nello spazio di
/// riferimento 1200×600, campo sinistro: prima linea (oltre la linea dei
/// 3m, x > 400) zone 4/3/2 dall'alto in basso, seconda linea zone 5/6/1.
/// Il battitore fuori campo (x negativa) ricade in zona 1.
int zonaDaPosizione(Offset pos) {
  final primaLinea = pos.dx > 400;
  if (pos.dy < 200) return primaLinea ? 4 : 5;
  if (pos.dy < 400) return primaLinea ? 3 : 6;
  return primaLinea ? 2 : 1;
}

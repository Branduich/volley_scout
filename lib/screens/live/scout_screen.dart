import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../logic/ricalcola_stato.dart';
import '../../models/enums.dart';
import '../../models/jersey_colors.dart';
import '../../providers/database_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/court_style.dart';
import '../report/player_stats_screen.dart';
import '../report/trajectory_report_screen.dart';
import 'end_set_screen.dart';
import 'sostituzione_screen.dart';
import 'trajectory_screen.dart';

const _kBg = Color(0xFF143E59);
const _kTopBarBg = Color(0xFF0D2738);
const _kCourtImage = 'assets/images/double_court_bg.png';
const _kSmallCourtImage = 'assets/images/small_court.png';

// Margine fisso tra il bordo superiore dell'area di gioco (sotto banner/
// bottoni rapidi) e il campo grande — il campo non è più centrato
// verticalmente nello spazio rimanente, ma ancorato in alto a questa
// distanza. Stesso valore usato per calcolare `courtTop` in
// _buildLiberoSwapTokens/_buildBattitoreTapCatcher (Stack esterno,
// coordinate schermo assolute): deve restare identico a quello passato a
// `Positioned(top: ...)` nel campo vero, altrimenti libero/battitore fuori
// campo si disallineano dal campo disegnato.
const double _kCourtTopMargin = 16.0;

// Colore invertito (canale per canale) rispetto al colore squadra, usato per
// il cerchio del libero — in pallavolo il libero indossa sempre una maglia
// di colore diverso dai compagni. Stessa logica di lineup_screen.dart.
Color _invertedColor(Color color) => Color.from(
      alpha: color.a,
      red: 1.0 - color.r,
      green: 1.0 - color.g,
      blue: 1.0 - color.b,
    );

// Ancoraggio del badge di rotazione sul campo piccolo, per slot del
// palleggiatore. Il campo piccolo è ruotato di 90° in senso orario rispetto
// a LineupScreen: P1 basso-sx, P2 basso-dx, P3 centro-dx (lato rete),
// P4 alto-dx, P5 alto-sx, P6 centro-sx — in senso antiorario da P1.
const Map<String, Alignment> _kRotationBadgeAnchor = {
  'P1': Alignment.bottomLeft,
  'P2': Alignment.bottomRight,
  'P3': Alignment.centerRight,
  'P4': Alignment.topRight,
  'P5': Alignment.topLeft,
  'P6': Alignment.centerLeft,
};

// Posizioni di attacco dei 6 giocatori sul campo grande, in coordinate di
// riferimento rispetto all'immagine double_court_bg.png (1200×600 — ogni
// singolo campo è quindi un quadrato 600×600). Da estendere in futuro con le
// posizioni di ricezione (quando l'avversario è al servizio).
const Map<String, Offset> _kAttackPositions = {
  'P1': Offset(200, 470),
  'P2': Offset(530, 470),
  'P3': Offset(530, 300),
  'P4': Offset(530, 130),
  'P5': Offset(200, 130),
  'P6': Offset(200, 300),
};

// Quando battiamo noi, chi è in P1 esce dal campo per servire: X = -70,
// cioè il bordo del campo (x=0, la linea di fondo) meno 70 (era -60 con
// token più piccoli, vedi _kTokenSizeScale — aumentato per mantenere lo
// stesso margine visivo di distacco dal campo) — non l'X della posizione di
// attacco meno 70. Il battitore deve stare FUORI dal campo (X negativa), non
// semplicemente più indietro ma ancora dentro. Stessa Y della posizione di
// attacco. Passa comunque per _displayPosition(), quindi si specchia
// correttamente anche ripartendo da destra.
const Offset _kBattutaP1Position = Offset(-70, 470);

// Fattore di scala applicato al raggio "base" (ch/20) di tutti i token
// giocatore — token su campo (_buildPlayerToken), libero attivo/inattivo
// e battitore fuori campo (_swapTokenRadius, stesso Stack esterno, tutti
// via _buildLiberoSwapTokens). Le tre formule derivano tutte dallo
// stesso raggio "base" e vanno scalate insieme, altrimenti i token
// finiscono disallineati in dimensione tra Stack interno ed esterno.
// Aumentato da 1.0 dopo test su tablet fisico (token troppo piccoli).
const double _kTokenSizeScale = 1.4;

// Posizioni di attacco per RUOLO e FASE (non solo per zona fissa come
// _kAttackPositions): "Battuta" (chi sta per servire, fuori campo con X
// negativa — il ruolo che serve varia per rotazione) e "DopoBattuta"/
// "DopoRicezione" (palla in gioco, ognuna con la propria "forma" tattica —
// NON sempre coincidenti tra loro, a differenza delle posizioni di
// ricezione). Solo variante "libero sui centrali" per ora (le altre due
// varianti ricadono sulla vecchia logica generica — vedi _attackPosition).
// L'eccezione "il libero non può servire" è già implicita nei dati: quando
// il centrale di seconda linea sta per servire, compare lui stesso (es.
// 'C2') invece di 'Libero'.
const Map<String, Map<String, Offset>> _kAttackBattutaCentrali = {
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

const Map<String, Map<String, Offset>> _kAttackDopoBattutaCentrali = {
  'P1': {
    'P': Offset(200, 470),
    'O': Offset(530, 470),
    'C1': Offset(530, 300),
    'S1': Offset(530, 130),
    'Libero': Offset(200, 130),
    'S2': Offset(200, 300),
  },
  'P2': {
    'P': Offset(200, 470),
    'O': Offset(530, 470),
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

// Coincide con _kAttackDopoBattutaCentrali per P3, P4 e P6 (confermato dallo
// sviluppatore) ma differisce per P1, P2 e P5: dopo aver ricevuto la
// squadra si schiera diversamente rispetto a dopo aver servito.
const Map<String, Map<String, Offset>> _kAttackDopoRicezioneCentrali = {
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

// Equivalenti di _kAttackBattutaCentrali/_kAttackDopoBattutaCentrali/
// _kAttackDopoRicezioneCentrali per il caso "libero sugli schiacciatori"
// (qui sono entrambi i centrali a restare in campo, il libero sostituisce
// lo schiacciatore di seconda linea). P3 e P6 non hanno 'Libero' in Battuta
// e Dopo_Battuta: in quelle due rotazioni lo schiacciatore che il libero
// sostituirebbe è proprio quello che deve servire in quel turno — eccezione
// "il libero non può servire" (stesso pattern già presente in
// _kAttackBattutaCentrali/_kAttackDopoBattutaCentrali per la rotazione P2,
// dove serve C2): per tutta la durata di quel turno di servizio il libero
// resta fuori, non solo per l'istante della battuta. Non si attiva più in
// Dopo_Ricezione (lì non serviamo noi, nessun problema a far entrare il
// libero) — tutte le 6 rotazioni hanno 'Libero' in quella tabella.
const Map<String, Map<String, Offset>> _kAttackBattutaSchiacciatori = {
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

const Map<String, Map<String, Offset>> _kAttackDopoBattutaSchiacciatori = {
  'P1': {
    'P': Offset(200, 470),
    'O': Offset(530, 470),
    'C1': Offset(530, 300),
    'S1': Offset(530, 130),
    'C2': Offset(200, 130),
    'Libero': Offset(200, 300),
  },
  'P2': {
    'P': Offset(200, 470),
    'O': Offset(530, 470),
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

const Map<String, Map<String, Offset>> _kAttackDopoRicezioneSchiacciatori = {
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

// Per rotazione, quale centrale verrebbe sostituito dal libero (l'altro è
// sempre quello "fisso" già presente nelle tabelle sopra) — usata per
// derivare le tabelle "senza libero" dalle tabelle "libero sui centrali"
// senza duplicare i dati: in campo senza libero quel centrale gioca
// semplicemente lui stesso, nella stessa posizione tattica che avrebbe
// occupato il libero.
const Map<String, String> _kRuoloSostituitoCentrali = {
  'P1': 'C2',
  'P2': 'C2',
  'P3': 'C1',
  'P4': 'C1',
  'P5': 'C1',
  'P6': 'C2',
};

// Deriva la tabella "senza libero" da una delle tabelle centrali sopra:
// sostituisce la chiave 'Libero' (se presente — durante l'eccezione del
// servizio non c'è, la tabella è già completa) con il centrale reale di
// _kRuoloSostituitoCentrali, stessa Offset.
Map<String, Offset>? _kAttackSenzaLiberoDaCentrali(
    Map<String, Map<String, Offset>> tabellaCentrali, String slot) {
  final mappa = tabellaCentrali[slot];
  if (mappa == null) return null;
  final posizioneLibero = mappa['Libero'];
  if (posizioneLibero == null) return mappa; // già completa
  final ruoloSostituito = _kRuoloSostituitoCentrali[slot]!;
  return {...mappa, ruoloSostituito: posizioneLibero}..remove('Libero');
}

// Posizioni di ricezione (battuta avversaria), per rotazione (chiave = slot
// del palleggiatore, come _currentSlot) e per RUOLO (non per slot fisso —
// stessi codici di _roleLabelsFor: P, O, S1, S2, C1, C2). Caso "libero sui
// centrali": il libero sostituisce il centrale di seconda linea, che quindi
// non compare in questa mappa per quella rotazione (solo il centrale a
// rete, che resta in campo, è presente). Tutte e 6 le rotazioni sono
// complete — vedi _activeDefenseMap per il controllo di completezza.
const Map<String, Map<String, Offset>> _kDefensePositionsCentrali = {
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

// Stesso formato di _kDefensePositionsCentrali, per il caso "libero sugli
// schiacciatori": qui sono entrambi i centrali a restare in campo, mentre il
// libero sostituisce lo schiacciatore di seconda linea (uno solo tra S1/S2
// compare per rotazione).
const Map<String, Map<String, Offset>> _kDefensePositionsSchiacciatori = {
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

// Stessa "forma" difensiva delle due tabelle sopra, ma per formazioni SENZA
// libero: nessun ruolo va sostituito, quindi servono le posizioni REALI di
// tutti e 6 i ruoli (P, O, S1, S2, C1, C2). Le due tabelle con libero non ne
// contengono mai più di 5 (un ruolo è sempre "Libero" al posto del
// sostituito) — ma insieme si completano: il ruolo mancante in una tabella
// (quello sostituito dal libero in quella coppia) è presente nell'altra
// (dove la coppia sostituita è l'opposta). Unendo le due e scartando la
// chiave "Libero" si ottengono le posizioni reali di tutti i 6 ruoli, per
// ogni rotazione — verificato che i ruoli condivisi tra le due tabelle
// (P, O e il centrale/schiacciatore "fisso" di ciascuna coppia) abbiano le
// stesse coordinate in entrambe.
Map<String, Offset>? _kDefensePositionsComplete(String slot) {
  final centrali = _kDefensePositionsCentrali[slot];
  final schiacciatori = _kDefensePositionsSchiacciatori[slot];
  if (centrali == null || schiacciatori == null) return null;
  final merged = {...centrali, ...schiacciatori}..remove('Libero');
  const ruoliCompleti = {'P', 'O', 'S1', 'S2', 'C1', 'C2'};
  return ruoliCompleti.every(merged.containsKey) ? merged : null;
}

// Ordine antiorario degli slot sul campo grande (verificato sulle coordinate
// di _kAttackPositions), usato per calcolare la distanza dal palleggiatore.
const List<String> _kSlotOrder = ['P1', 'P2', 'P3', 'P4', 'P5', 'P6'];

// Modulo che gestisce correttamente anche valori negativi (a differenza di
// `%` in Dart, che mantiene il segno dell'operando).
int _mod(int a, int n) => ((a % n) + n) % n;

// Etichette di ruolo per ogni slot, basate sul ruolo REALE del giocatore
// assegnato (non su un pattern fisso): il palleggiatore è sempre "P",
// l'opposto è sempre "O". Tra i due schiacciatori, quello più vicino al
// palleggiatore (in senso antiorario) è "S1", l'altro (diametralmente
// opposto, a 3 posizioni di distanza) è "S2" — stessa logica per i centrali
// ("C1"/"C2"). Permette anche formazioni dove un centrale, non uno
// schiacciatore, si trova subito dopo il palleggiatore.
Map<String, String> _roleLabelsFor(
    String palleggiatoreSlot, Map<String, Player> assignments) {
  final startIndex = _kSlotOrder.indexOf(palleggiatoreSlot);
  int distanceFromP(String slot) =>
      (_kSlotOrder.indexOf(slot) - startIndex + _kSlotOrder.length) %
      _kSlotOrder.length;

  final schiacciatori = <String>[];
  final centrali = <String>[];
  // Palleggiatori NON designati (doppio cambio: un secondo palleggiatore in
  // campo al posto di un altro ruolo) — raccolti a parte e assegnati DOPO
  // il ciclo, così non rubano la 'O' all'opposto vero se compaiono prima
  // di lui nell'ordine degli slot.
  final palleggiatoriExtra = <String>[];
  String? opposto;

  for (final slot in _kSlotOrder) {
    if (slot == palleggiatoreSlot) continue;
    switch (assignments[slot]?.ruolo) {
      case Ruolo.opposto:
        opposto = slot;
      case Ruolo.schiacciatore:
        schiacciatori.add(slot);
      case Ruolo.centrale:
      case Ruolo.undefined:
        centrali.add(slot);
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

  final labels = <String, String>{palleggiatoreSlot: 'P'};
  if (opposto != null) labels[opposto] = 'O';
  if (schiacciatori.isNotEmpty) labels[schiacciatori[0]] = 'S1';
  if (schiacciatori.length > 1) labels[schiacciatori[1]] = 'S2';
  if (centrali.isNotEmpty) labels[centrali[0]] = 'C1';
  if (centrali.length > 1) labels[centrali[1]] = 'C2';
  return labels;
}

// Esagono con angoli arrotondati, inscritto nel quadrato `size` (stesso
// raggio centro-vertice dei token circolari, per coerenza di ingombro).
// Usato per distinguere il palleggiatore, ruolo chiave della formazione.
Path _roundedHexagonPath(Size size, double cornerRadius) {
  final center = Offset(size.width / 2, size.height / 2);
  final radius = size.shortestSide / 2 - 1;
  const sides = 6;
  final points = List.generate(sides, (i) {
    final angle = -math.pi / 2 + i * (2 * math.pi / sides);
    return center + Offset(math.cos(angle), math.sin(angle)) * radius;
  });

  final path = Path();
  for (var i = 0; i < sides; i++) {
    final prev = points[(i - 1 + sides) % sides];
    final curr = points[i];
    final next = points[(i + 1) % sides];

    final toPrev = prev - curr;
    final toNext = next - curr;
    final start = curr + toPrev / toPrev.distance * cornerRadius;
    final end = curr + toNext / toNext.distance * cornerRadius;

    if (i == 0) {
      path.moveTo(start.dx, start.dy);
    } else {
      path.lineTo(start.dx, start.dy);
    }
    path.quadraticBezierTo(curr.dx, curr.dy, end.dx, end.dy);
  }
  path.close();
  return path;
}

class _RoundedHexagonPainter extends CustomPainter {
  final Color color;
  const _RoundedHexagonPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = _roundedHexagonPath(size, size.shortestSide * 0.08);
    canvas.drawShadow(path, Colors.black, 3, false);
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _RoundedHexagonPainter oldDelegate) =>
      oldDelegate.color != color;
}

class ScoutScreen extends ConsumerStatefulWidget {
  final VolleyMatch match;
  final Team team;
  final String palleggiatoreSlot;
  final Map<String, Player> assignments;
  // Quale coppia di ruoli sostituisce il libero (deciso in
  // FormationConfigScreen: o i due centrali o i due schiacciatori, mai una
  // combinazione). Null se non c'è libero in formazione.
  final Ruolo? ruoloCambiLibero;

  const ScoutScreen({
    super.key,
    required this.match,
    required this.team,
    required this.palleggiatoreSlot,
    required this.assignments,
    this.ruoloCambiLibero,
  });

  @override
  ConsumerState<ScoutScreen> createState() => _ScoutScreenState();
}

class _ScoutScreenState extends ConsumerState<ScoutScreen> {
  // Set corrente: creato (con relativa rotazione iniziale) non appena si
  // risponde al dialog "Chi serve per primo?" — vedi _chiediServizioIniziale.
  MatchSet? _setCorrente;

  // Rotazione di partenza (posizione 1-6 -> id giocatore), letta dalla
  // formazione confermata — stesso parsing di
  // MatchSetRepository.salvaRotazioneIniziale, ma calcolato qui in memoria:
  // serve a ricalcolaStato() come stato iniziale, non a un'altra lettura DB.
  Map<int, int> get _rotazioneInizialeMap {
    final map = <int, int>{};
    for (final entry in widget.assignments.entries) {
      final pos = int.tryParse(entry.key.replaceFirst('P', ''));
      if (pos != null && pos >= 1 && pos <= 6) {
        map[pos] = entry.value.id;
      }
    }
    return map;
  }

  // Stato reale del set (punteggio, chi serve, rotazione), derivato dagli
  // eventi ScoutAction persistiti — null finché il set non è ancora iniziato
  // (dialog "Chi serve per primo?" non ancora risposto). Punto centrale del
  // principio event-sourcing: niente di tutto questo è salvato come stato
  // mutabile, si ricalcola sempre dalla sequenza di azioni.
  StatoSet? get _statoSetReale {
    final set = _setCorrente;
    if (set == null) return null;
    final azioniAsync = ref.watch(scoutAzioniStreamProvider(set.id));
    final righe = azioniAsync.value ?? const <ScoutAction>[];
    final azioni = [for (final r in righe) azioneScoutDaRiga(r)];
    return ricalcolaStato(
      azioni: azioni,
      servizioIniziale: set.squadraServizioIniziale,
      rotazioneIniziale: _rotazioneInizialeMap,
      palleggiatoreInizialeId:
          widget.assignments[widget.palleggiatoreSlot]?.id,
      ruoloCambiLiberoIniziale: widget.ruoloCambiLibero,
    );
  }

  // Roster completo della squadra (id -> Player), per risolvere i
  // giocatoreId della rotazione derivata: dopo un cambio giocatore la
  // rotazione può contenere id NON presenti in widget.assignments (il
  // subentrante partiva dalla panchina). Lo stream del roster è fuso SOPRA
  // widget.assignments: il fallback copre i primi frame prima che lo stream
  // emetta (evita token vuoti alla ripresa).
  Map<int, Player> get _rosterById {
    final map = {for (final p in widget.assignments.values) p.id: p};
    final roster =
        ref.watch(playersStreamProvider(widget.team.id)).value;
    if (roster != null) {
      for (final p in roster) {
        map[p.id] = p;
      }
    }
    return map;
  }

  // Coppia cambi-libero effettiva: può cambiare a set in corso con un
  // cambio giocatore (override nel medesimo evento) — widget.ruoloCambiLibero
  // resta il valore INIZIALE del set (usato da _iniziaSet per persisterlo).
  // In modalità test non ci sono eventi reali: vale il valore iniziale.
  Ruolo? get _ruoloCambiLiberoEffettivo => _testModeEnabled
      ? widget.ruoloCambiLibero
      : (_statoSetReale?.ruoloCambiLibero ?? widget.ruoloCambiLibero);

  // Ultima azione registrata nel set (stessa riga che alimenterà in futuro
  // le statistiche/report — vedi Modello dati), per il banner "ultima
  // azione" sopra al campo. Null se il set non è iniziato o non ha ancora
  // azioni. Resta lì finché non ne arriva una successiva (nessun timer di
  // sparizione, nemmeno per punto/errore — vedi "Interfaccia di scout").
  ScoutAction? get _ultimaAzione {
    final set = _setCorrente;
    if (set == null) return null;
    final azioniAsync = ref.watch(scoutAzioniStreamProvider(set.id));
    final righe = azioniAsync.value;
    if (righe == null || righe.isEmpty) return null;
    return righe.last; // watchAzioni ordina per `ordine` crescente
  }

  // Chi è al servizio ora. Fuori dalla modalità test, deriva dallo stato
  // reale (ricalcolaStato sugli eventi persistiti); prima che il set inizi
  // ricade su null. In modalità test, ignora tutto questo e usa
  // _testServizio (vedi sotto).
  Squadra? get _squadraAlServizio => _testModeEnabled
      ? _testServizio
      : (_statoSetReale?.squadraAlServizio ??
          _setCorrente?.squadraServizioIniziale);

  // True se siamo nella sotto-fase "dopo" dello scambio corrente (palla in
  // gioco, voto già dato) — in modalità test deriva da _testDopo (ciclato a
  // mano da _testAvanza), altrimenti da _fondamentaleGiudicatoRallyCorrente
  // (derivato dagli eventi reali). Unifica i due casi per
  // _refPositionFor/_activeAttackMap/_activeDefenseMap.
  bool get _faseDopo =>
      _testModeEnabled ? _testDopo : _fondamentaleGiudicatoRallyCorrente;

  // Chiave del libero attivo (in campo o diretto verso il campo). Segue la
  // convenzione automatica (L1 in ricezione, L2 in servizio) finché non c'è
  // un override manuale da _liberoOverride.
  String get _liberoAttivoKey {
    if (widget.assignments['L2'] == null) return 'L1';
    if (_liberoOverride != null) return _liberoOverride!;
    return _squadraAlServizio == Squadra.avversari ? 'L1' : 'L2';
  }

  // Chiave del libero inattivo (in panchina fissa, tappabile). Null se non
  // c'è doppio libero.
  String? get _liberoInattivoKey {
    if (widget.assignments['L2'] == null) return null;
    return _liberoAttivoKey == 'L1' ? 'L2' : 'L1';
  }

  // --- Modalità test (solo per provare a video tutte le combinazioni
  // rotazione × chi serve, senza dover passare dal flusso reale di gioco) ---
  bool _testModeEnabled = false;
  Squadra _testServizio = Squadra.nostra;
  // Sotto-fase "dopo" (palla in gioco, voto già dato) all'interno di
  // _testServizio — vedi _testAvanza per le 4 combinazioni cicliche.
  bool _testDopo = false;

  void _toggleTestMode(bool value) {
    setState(() {
      _testModeEnabled = value;
      if (value) {
        _rotationSteps = 0;
        _testServizio = Squadra.nostra;
        _testDopo = false;
      }
    });
  }

  // Avanza di un passo tra le 4 fasi vere dello scambio, nello stesso ordine
  // del gioco reale: Battuta → Dopo_Battuta → Ricezione → Dopo_Ricezione →
  // Battuta della rotazione successiva (P1→P6→P5→P4→P3→P2→P1...).
  void _testAvanza() {
    setState(() {
      if (_testServizio == Squadra.nostra && !_testDopo) {
        _testDopo = true; // Battuta -> Dopo_Battuta
      } else if (_testServizio == Squadra.nostra && _testDopo) {
        _testServizio = Squadra.avversari;
        _testDopo = false; // Dopo_Battuta -> Ricezione
      } else if (_testServizio == Squadra.avversari && !_testDopo) {
        _testDopo = true; // Ricezione -> Dopo_Ricezione
      } else {
        _testServizio = Squadra.nostra;
        _testDopo = false;
        _rotationSteps--; // Dopo_Ricezione -> Battuta rotazione successiva
      }
    });
  }

  // Posizione di riferimento (1200×600) per uno slot: quella di attacco,
  // tranne per P1 quando battiamo noi E la battuta di questo scambio non è
  // ancora stata giudicata (vedi _faseDopo) — una volta dato il voto, il
  // battitore si riporta in campo nella sua posizione normale, perché la
  // palla è in gioco. In modalità test segue _testDopo (vedi _testAvanza)
  // invece che i voti reali.
  Offset _refPositionFor(String slot) {
    final inBattuta = _squadraAlServizio == Squadra.nostra && !_faseDopo;
    if (slot == 'P1' && inBattuta) {
      return _kBattutaP1Position;
    }
    return _kAttackPositions[slot]!;
  }

  // Tabella di attacco attiva per rotazione/RUOLO nella fase corrente
  // (Battuta/DopoBattuta/DopoRicezione). Tre varianti coperte: "libero sui
  // centrali" e "libero sugli schiacciatori" (dati diretti, vedi
  // _kAttackBattutaCentrali/_kAttackBattutaSchiacciatori e tabelle gemelle)
  // e "senza libero" (derivata al volo dalle tabelle centrali, vedi
  // _kAttackSenzaLiberoDaCentrali — il centrale altrimenti sostituito gioca
  // semplicemente lui stesso; vale per qualunque variante perché senza
  // libero non c'è alcuna sostituzione da scegliere). Null durante la
  // ricezione in corso (gestita da _activeDefenseMap): in quel caso si
  // ricade su _refPositionFor (logica generica per zona fissa, non per
  // ruolo) — vedi _attackPosition.
  Map<String, Offset>? get _activeAttackMap {
    final senzaLibero = !widget.assignments.containsKey('L1');
    final usaSchiacciatori =
        !senzaLibero && _ruoloCambiLiberoEffettivo == Ruolo.schiacciatore;
    final rotazione = _currentSlot;
    Map<String, Offset>? risolvi(
      Map<String, Map<String, Offset>> tabellaCentrali,
      Map<String, Map<String, Offset>> tabellaSchiacciatori,
    ) {
      if (senzaLibero) {
        return _kAttackSenzaLiberoDaCentrali(tabellaCentrali, rotazione);
      }
      return usaSchiacciatori
          ? tabellaSchiacciatori[rotazione]
          : tabellaCentrali[rotazione];
    }

    if (_squadraAlServizio == Squadra.nostra) {
      return !_faseDopo
          ? risolvi(_kAttackBattutaCentrali, _kAttackBattutaSchiacciatori)
          : risolvi(_kAttackDopoBattutaCentrali,
              _kAttackDopoBattutaSchiacciatori);
    }
    if (_squadraAlServizio == Squadra.avversari && _faseDopo) {
      return risolvi(
          _kAttackDopoRicezioneCentrali, _kAttackDopoRicezioneSchiacciatori);
    }
    return null;
  }

  // Posizione di riferimento per il giocatore nello slot (rotazione
  // corrente) indicato, in fase di attacco: usa la tabella per ruolo
  // (_activeAttackMap) se disponibile per questa variante/fase/ruolo,
  // altrimenti ricade su _refPositionFor (zona fissa, non per ruolo) — il
  // fallback resta finché non ci sono le tabelle delle altre varianti
  // libero.
  Offset _attackPosition(String slot, Map<String, String> roleLabels) {
    final mappa = _activeAttackMap;
    final ruolo = roleLabels[slot];
    if (mappa != null && ruolo != null && mappa.containsKey(ruolo)) {
      return mappa[ruolo]!;
    }
    return _refPositionFor(slot);
  }

  // Giocatore + fondamentale per cui è aperto il pannello di voto — null =
  // pannello chiuso. `fondamentale` è null quando il giocatore è stato
  // toccato in fase "libera" (dopo battuta/ricezione già giudicate): in quel
  // caso il pannello mostra prima la scelta tra Alzata/Attacco/Muro/Difesa
  // (vedi _sceglieFondamentale), altrimenti è già forzato da
  // _fondamentaleForzato (battuta/ricezione). Tap sul giocatore (vedi
  // _tapHandlerPerGiocatore) lo apre; la selezione di un voto (_registraVoto)
  // lo richiude.
  ({Player giocatore, Fondamentale? fondamentale})? _votoInCorso;

  // True dopo che il fondamentale giudicabile dello scambio corrente
  // (battuta se serviamo noi, ricezione se servono loro) è stato giudicato
  // con un voto non terminale (palla ancora in gioco, niente punto). Si
  // resetta a false a ogni nuova azione che chiude lo scambio (punto/errore,
  // anche dai bottoni rapidi) — vedi _registraAzioneRapida/_registraVoto.
  bool _fondamentaleGiudicatoRallyCorrente = false;

  // Tappabile in questa fase di gioco, a prescindere dal fondamentale: prima
  // che battuta/ricezione siano state giudicate, solo il giocatore coinvolto
  // in quell'azione (slot=='P1' se battiamo noi — il battitore; chiunque se
  // servono loro — la ricezione, libero compreso passando slot=null). Dopo
  // quel voto (palla in gioco, _fondamentaleGiudicatoRallyCorrente),
  // chiunque è tappabile: il fondamentale (Alzata/Attacco/Muro/Difesa) si
  // scegli nel pannello, vedi _sceglieFondamentale.
  bool _giocatoreTappabile(String? slot) {
    final servizio = _squadraAlServizio;
    if (servizio == Squadra.nostra) {
      return _fondamentaleGiudicatoRallyCorrente || slot == 'P1';
    }
    return servizio == Squadra.avversari;
  }

  // Fondamentale forzato dalla fase di gioco (battuta se battiamo noi,
  // ricezione se servono loro), o null se va scelto nel pannello tra
  // Alzata/Attacco/Muro/Difesa — quest'ultimo solo dopo che battuta o
  // ricezione sono già state giudicate in questo scambio.
  Fondamentale? _fondamentaleForzato() {
    if (_fondamentaleGiudicatoRallyCorrente) return null;
    return _squadraAlServizio == Squadra.nostra
        ? Fondamentale.battuta
        : Fondamentale.ricezione;
  }

  // Tap-target per il voto di un giocatore: fuori dalla modalità test, col
  // set già iniziato e questo slot tappabile nella fase corrente (vedi
  // _giocatoreTappabile). `slot` è null per il libero (nessuno slot P1-P6
  // proprio).
  VoidCallback? _tapHandlerPerGiocatore(Player player, {String? slot}) {
    if (_testModeEnabled) return null;
    if (_setCorrente == null) return null;
    if (!_giocatoreTappabile(slot)) return null;
    final forzato = _fondamentaleForzato();
    return () => setState(() {
      _votoInCorso = (giocatore: player, fondamentale: forzato);
      // Il tipo di battuta selezionato resta "armato" da una battuta
      // all'altra dello stesso giocatore (spesso batte sempre nello stesso
      // modo); cambia battitore → si azzera, non si assume che batta uguale.
      if (forzato == Fondamentale.battuta &&
          _giocatoreTipoBattutaArmato != player.id) {
        _tipoBattutaSelezionato = TipoBattuta.nonSpecificato;
        _giocatoreTipoBattutaArmato = player.id;
      }
    });
  }

  // Sceglie il fondamentale (Alzata/Attacco/Muro/Difesa) per il giocatore già
  // selezionato in fase "libera" (_votoInCorso.fondamentale == null) — tap su
  // uno dei 4 bottoni del pannello, vedi _buildSceltaFondamentale.
  void _sceglieFondamentale(Fondamentale fondamentale) {
    final inCorso = _votoInCorso;
    if (inCorso == null) return;
    setState(() {
      _votoInCorso = (giocatore: inCorso.giocatore, fondamentale: fondamentale);
    });
  }

  // Tipo di battuta opzionale, scelto su TrajectoryScreen (riga di chip
  // orizzontale sotto al campo, non più nel pannello voto qui) — passato
  // come valore iniziale alla navigazione e riletto dal risultato al
  // ritorno (vedi _registraVoto). nonSpecificato di default, non bloccante
  // per il flusso veloce. Vedi _tapHandlerPerGiocatore per quando si azzera.
  TipoBattuta _tipoBattutaSelezionato = TipoBattuta.nonSpecificato;
  int? _giocatoreTipoBattutaArmato;

  // Esito automatico del voto, generale per tutti i fondamentali: qualunque
  // fondamentale con voto "errore" → punto avversario (battuta in rete/
  // fuori, ricezione non tenuta, attacco murato/fuori, muro sbagliato, ecc.).
  // Solo battuta/attacco/muro hanno anche un punto immediato su "perfetto"
  // (ace, schiacciata vincente, muro punto) — ricezione/alzata/difesa non
  // vincono mai punti da sole, preparano solo la giocata successiva.
  EsitoPunto _esitoVoto(Fondamentale fondamentale, Voto voto) {
    if (voto == Voto.errore) return EsitoPunto.puntoAvversario;
    const direttoSePerfetto = {
      Fondamentale.battuta,
      Fondamentale.attacco,
      Fondamentale.muro,
    };
    if (direttoSePerfetto.contains(fondamentale) && voto == Voto.perfetto) {
      return EsitoPunto.puntoNostro;
    }
    return EsitoPunto.nessuno;
  }

  Future<void> _registraVoto(Voto voto) async {
    final set = _setCorrente;
    final inCorso = _votoInCorso;
    final fondamentale = inCorso?.fondamentale;
    if (set == null || inCorso == null || fondamentale == null) return;
    final esito = _esitoVoto(fondamentale, voto);

    // Solo battuta/attacco chiedono la traiettoria — schermata dedicata,
    // niente bottoni "salta"/"conferma": il back la salta (registra
    // comunque un risultato, solo senza coordinate — vedi TrajectoryScreen),
    // il rilascio del drag la conferma subito. Per la battuta,
    // TrajectoryScreen mostra anche la scelta del tipo (sotto al campo,
    // spostata qui dal pannello voto): si passa il valore "armato" attuale
    // come iniziale e si rilegge quello (eventualmente cambiato) dal
    // risultato, per restare "armato" anche tra una traiettoria e l'altra.
    Traiettoria? traiettoria;
    if (fondamentale.richiedeTraiettoria) {
      traiettoria = await Navigator.push<Traiettoria>(
        context,
        MaterialPageRoute(
          builder: (_) => TrajectoryScreen(
            giocatore: inCorso.giocatore,
            fondamentale: fondamentale,
            voto: voto,
            tipoBattutaIniziale: fondamentale == Fondamentale.battuta
                ? _tipoBattutaSelezionato
                : null,
          ),
        ),
      );
      if (!mounted) return;
      if (fondamentale == Fondamentale.battuta && traiettoria != null) {
        _tipoBattutaSelezionato = traiettoria.tipoBattuta;
      }
    }

    final tipoEsecuzione = switch (fondamentale) {
      Fondamentale.battuta => _tipoBattutaSelezionato.name,
      Fondamentale.attacco =>
        (traiettoria?.tipoAttacco ?? TipoAttacco.nonSpecificato).name,
      _ => 'nonSpecificato',
    };

    await ref.read(scoutActionRepositoryProvider).registraAzioneScout(
          setId: set.id,
          squadra: Squadra.nostra,
          giocatoreId: inCorso.giocatore.id,
          fondamentale: fondamentale,
          voto: voto,
          esitoPunto: esito,
          tipoEsecuzione: tipoEsecuzione,
          traiettoriaX1: traiettoria?.x1,
          traiettoriaY1: traiettoria?.y1,
          traiettoriaX2: traiettoria?.x2,
          traiettoriaY2: traiettoria?.y2,
          traiettoriaMuroX: traiettoria?.muroX,
          traiettoriaMuroY: traiettoria?.muroY,
        );
    if (!mounted) return;
    setState(() {
      _votoInCorso = null;
      _fondamentaleGiudicatoRallyCorrente = esito == EsitoPunto.nessuno;
      // I tipi selezionati NON si azzerano qui: restano "armati" se lo
      // stesso giocatore ripete la stessa azione (vedi
      // _tapHandlerPerGiocatore/_sceglieFondamentale).
    });
  }

  // Mappa di ricezione attiva per la rotazione corrente, solo se: stiamo
  // ricevendo (batte l'avversario), la ricezione di questo scambio non è
  // ancora stata giudicata (una volta giudicata con un voto non terminale,
  // la palla è in gioco verso l'attacco: i giocatori si spostano in
  // posizione di gioco, stessa logica del battitore dopo la battuta — vedi
  // _faseDopo), e i dati di quella rotazione sono completi. Senza libero in
  // formazione: stessa "forma" difensiva ma con le posizioni REALI di tutti
  // i 6 ruoli, nessuna sostituzione (vedi _kDefensePositionsComplete). Con
  // libero: la tabella e la coppia sostituita dipendono da
  // _ruoloCambiLiberoEffettivo — se centrali, deve restare un solo C1/C2
  // (l'altro è il libero) e S1/S2 entrambi presenti; se schiacciatori, il
  // contrario. In modalità test segue _testDopo (vedi _testAvanza) invece
  // dei voti reali.
  Map<String, Offset>? get _activeDefenseMap {
    if (_squadraAlServizio != Squadra.avversari) return null;
    if (_faseDopo) return null;
    if (!widget.assignments.containsKey('L1')) {
      return _kDefensePositionsComplete(_currentSlot);
    }
    final ruolo = _ruoloCambiLiberoEffettivo;
    final Map<String, Map<String, Offset>> tabella;
    final List<String> coppiaSostituita;
    final List<String> coppiaFissa;
    if (ruolo == Ruolo.centrale || ruolo == Ruolo.undefined) {
      tabella = _kDefensePositionsCentrali;
      coppiaSostituita = const ['C1', 'C2'];
      coppiaFissa = const ['S1', 'S2'];
    } else if (ruolo == Ruolo.schiacciatore) {
      tabella = _kDefensePositionsSchiacciatori;
      coppiaSostituita = const ['S1', 'S2'];
      coppiaFissa = const ['C1', 'C2'];
    } else {
      return null;
    }
    final map = tabella[_currentSlot];
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _avviaOCaricaSet());
  }

  // Punto di ingresso unico per l'avvio dello schermo: provo a caricare il
  // set numero `match.setCorrente`. Se esiste già (ripresa di una partita
  // in corso, O di una partita già `terminata` che si vuole correggere —
  // vedi sotto) lo riprendo senza richiedere di nuovo "chi serve per
  // primo". Se non esiste ancora — sia il primissimo set della partita
  // (stato ancora `configurazione`), sia un nuovo set dopo "Prossimo Set"
  // in `EndSetScreen` (stato già `inCorso`, ma `setCorrente` è stato
  // incrementato a monte e quel set non è stato ancora creato) — lo
  // richiedo e lo creo: stessa logica per entrambi i casi, non serve più
  // distinguerli guardando `stato`.
  Future<void> _avviaOCaricaSet() async {
    final setRepo = ref.read(matchSetRepositoryProvider);
    final esistente =
        await setRepo.caricaSet(widget.match.id, widget.match.setCorrente);
    if (!mounted) return;
    if (esistente != null) {
      // Riprendere lo scout (anche da MatchesScreen → "Riprendi" su una
      // partita già `terminata`, es. per correggere un'azione) significa
      // che si torna a scoutare attivamente: `terminata` deve sempre voler
      // dire "scout non in corso ora", quindi torna `inCorso` — solo "Fine
      // Partita" la riporta a `terminata`.
      if (widget.match.stato != StatoPartita.inCorso) {
        await ref.read(matchRepositoryProvider).updateMatch(
              widget.match.copyWith(stato: StatoPartita.inCorso),
            );
      }
      if (!mounted) return;
      setState(() => _setCorrente = esistente);
    } else {
      await _chiediServizioIniziale();
    }
  }

  Future<void> _chiediServizioIniziale() async {
    final avversario = widget.match.avversario?.trim();
    final nomeAvversario =
        (avversario != null && avversario.isNotEmpty) ? avversario : 'Avversari';

    final scelta = await showDialog<Squadra>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Chi serve per primo?'),
        content: const Text(
            'Indica quale squadra è al servizio per iniziare il set.'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context, Squadra.nostra),
            child: Text(widget.team.nome),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, Squadra.avversari),
            child: Text(nomeAvversario),
          ),
        ],
      ),
    );
    if (scelta == null || !mounted) return;
    await _iniziaSet(scelta);
  }

  Future<void> _iniziaSet(Squadra servizioIniziale) async {
    final matchRepo = ref.read(matchRepositoryProvider);
    final setRepo = ref.read(matchSetRepositoryProvider);

    // `setCorrente` non si tocca qui: è già quello giusto, impostato alla
    // creazione della partita (1) o incrementato da EndSetScreen prima di
    // arrivare a questa schermata ("Prossimo Set").
    await matchRepo.updateMatch(
      widget.match.copyWith(stato: StatoPartita.inCorso),
    );
    final set = await setRepo.creaSet(
        widget.match.id, widget.match.setCorrente, servizioIniziale);
    await setRepo.salvaRotazioneIniziale(set.id, widget.assignments,
        ruoloCambiLibero: widget.ruoloCambiLibero);

    if (!mounted) return;
    setState(() => _setCorrente = set);
  }

  // Numero di rotazioni applicate da inizio set — usato SOLO in modalità
  // test (positivo = avanti, P1→P2; negativo = indietro, P1→P6) per simulare
  // tutte le combinazioni senza eventi reali. Fuori dalla modalità test la
  // rotazione vera viene da _statoSetReale (derivata dagli eventi).
  int _rotationSteps = 0;

  String get _currentSlot {
    final stato = _testModeEnabled ? null : _statoSetReale;
    if (stato != null) {
      // Il palleggiatore designato EFFETTIVO viene dallo stato derivato
      // (può cambiare con un cambio giocatore, override nell'evento) — il
      // fallback su widget copre solo stato senza palleggiatoreId.
      final palleggiatoreId = stato.palleggiatoreId ??
          widget.assignments[widget.palleggiatoreSlot]?.id;
      for (final entry in stato.rotazione.entries) {
        if (entry.value == palleggiatoreId) return 'P${entry.key}';
      }
    }
    final originalIndex = _kSlotOrder.indexOf(widget.palleggiatoreSlot);
    return _kSlotOrder[_mod(originalIndex + _rotationSteps, _kSlotOrder.length)];
  }

  // Mappa slot -> giocatore aggiornata in base alla rotazione corrente.
  Map<String, Player> get _currentAssignments {
    final stato = _testModeEnabled ? null : _statoSetReale;
    if (stato != null) {
      // _rosterById (non widget.assignments): dopo un cambio giocatore la
      // rotazione può contenere il subentrante, che partiva dalla panchina.
      final idToPlayer = _rosterById;
      final result = <String, Player>{};
      for (final entry in stato.rotazione.entries) {
        final player = idToPlayer[entry.value];
        if (player != null) result['P${entry.key}'] = player;
      }
      if (result.length == 6) return result;
    }
    final n = _kSlotOrder.length;
    final result = <String, Player>{};
    for (var j = 0; j < n; j++) {
      final originalSlot = _kSlotOrder[_mod(j - _rotationSteps, n)];
      final player = widget.assignments[originalSlot];
      if (player != null) result[_kSlotOrder[j]] = player;
    }
    return result;
  }

  void _rotateBackward() => setState(() => _rotationSteps--);

  void _rotateForward() => setState(() => _rotationSteps++);

  // Quando la squadra ataca dal campo di destra, le posizioni vanno
  // riflesse rispetto al centro dell'immagine doppia (rotazione di 180°,
  // non un semplice mirror orizzontale): chi era in basso a sinistra finisce
  // in alto a destra. Coordinate di riferimento 1200×600.
  bool _isRightSide = false;

  // null = convenzione automatica (L1 in ricezione, L2 in servizio);
  // 'L1' o 'L2' = libero bloccato per il resto del set (tap manuale).
  // Si resetta automaticamente al set successivo (nuova istanza ScoutScreen).
  String? _liberoOverride;

  void _toggleSide() => setState(() => _isRightSide = !_isRightSide);

  Offset _displayPosition(Offset refPos) => _isRightSide
      ? Offset(1200 - refPos.dx, 600 - refPos.dy)
      : refPos;

  // "Nome nostro - Nome avversario" di default: il nome della squadra di cui
  // si fa lo scout va sempre sul lato dove sono disegnati i suoi giocatori
  // (non dipende da casa/trasferta, solo dal cambio campo).
  String get _matchTitle {
    final nostro = widget.team.nome;
    final avversarioRaw = widget.match.avversario?.trim();
    final avversario =
        (avversarioRaw != null && avversarioRaw.isNotEmpty)
            ? avversarioRaw
            : 'AVVERSARI';
    final nostroASinistra = !_isRightSide;
    return nostroASinistra
        ? '$nostro - $avversario'
        : '$avversario - $nostro';
  }

  // Di default i token mostrano il numero di maglia; disattivando il toggle
  // mostrano il ruolo.
  bool _showJerseyNumbers = true;

  // Log azioni di debug (toggle nel drawer): pannello scrollabile ancorato
  // al bordo destro con tutte le ScoutAction del SET CORRENTE, più recente
  // in alto, aggiornato in tempo reale dallo stesso stream di
  // _statoSetReale. Nascosto mentre il pannello voto è aperto (occupa la
  // stessa zona dello schermo).
  bool _showActionLog = false;

  // Punteggio del set in corso, derivato da _statoSetReale (eventi reali) +
  // l'eventuale correzione manuale persistita su MatchSet (vedi
  // _correggiPunteggio — override diretto del valore mostrato, NON loggato
  // come ScoutAction: fine set/match sono già decisioni manuali, non serve
  // restare fedeli al log eventi per il punteggio). Segue lo stesso
  // criterio del titolo: il punteggio "nostro" è sempre mostrato sul lato
  // dove sono disegnati i nostri giocatori (a sinistra di default, a
  // destra col cambio campo).
  int get _punteggioNostro =>
      (_statoSetReale?.punteggioNostro ?? 0) +
      (_setCorrente?.correzionePuntiNostri ?? 0);
  int get _punteggioAvversario =>
      (_statoSetReale?.punteggioAvversario ?? 0) +
      (_setCorrente?.correzionePuntiAvversari ?? 0);

  // Bottoni rapidi (+1 Noi/+1 Loro/Errore nostro/Errore avversario):
  // percorso alternativo ai 3 tocchi, registrano subito un ScoutAction.
  // Disabilitati prima dell'inizio del set e durante la modalità test (per
  // non sporcare i dati reali del set con azioni di prova). Stessa
  // condizione usata per i bottoni di correzione punteggio (_correggiPunteggio).
  bool get _bottoniRapidiAttivi => _setCorrente != null && !_testModeEnabled;

  // Override manuale del punteggio (bottoni +/- accanto al numero): somma
  // il delta alla correzione già persistita su MatchSet (mai loggato come
  // ScoutAction, vedi sopra) e aggiorna `_setCorrente` localmente — non
  // c'è uno stream da osservare per questi due campi, quindi va fatto a
  // mano (a differenza di punteggio/rotazione "veri", derivati da
  // _statoSetReale che osserva scoutAzioniStreamProvider).
  Future<void> _correggiPunteggio(Squadra squadra, int delta) async {
    final set = _setCorrente;
    if (set == null) return;
    final aggiornato =
        await ref.read(matchSetRepositoryProvider).correggiPunteggio(
              set.id,
              deltaNostro: squadra == Squadra.nostra ? delta : 0,
              deltaAvversario: squadra == Squadra.avversari ? delta : 0,
            );
    if (!mounted) return;
    setState(() => _setCorrente = aggiornato);
  }

  Future<void> _registraAzioneRapida(
      Squadra squadra, TipoAzione tipo, EsitoPunto esito,
      {String tipoEsecuzione = 'nonSpecificato'}) async {
    final set = _setCorrente;
    if (set == null) return;
    await ref.read(scoutActionRepositoryProvider).registraAzioneRapida(
          setId: set.id,
          squadra: squadra,
          tipo: tipo,
          esitoPunto: esito,
          tipoEsecuzione: tipoEsecuzione,
        );
    if (!mounted) return;
    setState(() {
      _fondamentaleGiudicatoRallyCorrente = esito == EsitoPunto.nessuno;
      // Un bottone rapido chiude comunque lo scambio: il pannello voto,
      // se ancora aperto, non avrebbe più senso (l'esito è già stato
      // deciso per un'altra via).
      _votoInCorso = null;
    });
  }

  // Undo: attivo solo col set iniziato, fuori dalla modalità test (che non
  // scrive azioni reali) e con almeno un'azione da annullare.
  bool get _puoAnnullare =>
      !_testModeEnabled && _setCorrente != null && _ultimaAzione != null;

  // Dialog di conferma prima dell'undo vero e proprio (irreversibile: una
  // volta eliminata l'azione non c'è un "redo") — mostra una descrizione
  // dell'azione che verrebbe eliminata, riusando _descrizioneAzione (stesso
  // testo/voto del banner ultima azione).
  Future<void> _confermaAnnullaUltimaAzione() async {
    final azione = _ultimaAzione;
    if (azione == null) return;
    final descrizione = _descrizioneAzione(azione);
    var testoAzione = descrizione.voto == null
        ? descrizione.testo
        : '${descrizione.testo} ${descrizione.voto}';
    // Un blocco di cambi (es. doppio cambio) si annulla per intero:
    // avvisare se l'undo eliminerà più di una riga.
    final gruppo = azione.gruppoCambio;
    if (azione.tipo == TipoAzione.cambioGiocatore &&
        gruppo != null &&
        _setCorrente != null) {
      final n = await ref
          .read(scoutActionRepositoryProvider)
          .contaGruppoCambio(_setCorrente!.id, gruppo);
      if (n > 1) {
        testoAzione = '$testoAzione\n(verranno annullati tutti '
            'i $n cambi confermati insieme)';
      }
      if (!mounted) return;
    }
    final confermato = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Annullare l\'ultima azione?',
          style: TextStyle(fontSize: 14),
        ),
        content: Text(
          testoAzione,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Conferma'),
          ),
        ],
      ),
    );
    if (confermato == true) await _annullaUltimaAzione();
  }

  // Elimina l'azione con `ordine` massimo nel set (vedi
  // ScoutActionRepository.annullaUltimaAzione) — punteggio/servizio/
  // rotazione si ricalcolano da soli perché _statoSetReale osserva lo stesso
  // stream. `_fondamentaleGiudicatoRallyCorrente` non è derivato dallo
  // stream (vedi sopra) e va invece aggiornato a mano in base alla nuova
  // ultima azione rimasta nel set, altrimenti resterebbe quello dell'azione
  // appena annullata.
  Future<void> _annullaUltimaAzione() async {
    final set = _setCorrente;
    if (set == null) return;
    final repo = ref.read(scoutActionRepositoryProvider);
    await repo.annullaUltimaAzione(set.id);
    if (!mounted) return;
    final nuovaUltima = await repo.ultimaAzione(set.id);
    if (!mounted) return;
    setState(() {
      _votoInCorso = null;
      // Solo un VOTO non terminale (tipo scout) significa "palla in gioco":
      // un cambio giocatore ha anch'esso esito `nessuno`, ma non giudica
      // alcun fondamentale — senza il check sul tipo, l'undo fino a una
      // riga cambio segnerebbe erroneamente la fase libera.
      _fondamentaleGiudicatoRallyCorrente = nuovaUltima != null &&
          nuovaUltima.tipo == TipoAzione.scout &&
          nuovaUltima.esitoPunto == EsitoPunto.nessuno;
    });
  }

  // --- Sostituzione (cambio giocatore) ---
  //
  // Flusso dalla voce "Sostituzione" del drawer: push di SostituzioneScreen
  // (campo con la rotazione CORRENTE + panchina, N cambi pending in una
  // visita — replica l'esperienza di inizio partita) → FormationConfigScreen
  // in modalità conferma (SEMPRE mostrata, precompilata coi valori
  // effettivi: nessun rilevamento automatico) → al ritorno, diff posizione
  // per posizione e UNA riga registraSostituzione per ogni cambio (gli
  // override di configurazione sull'ultima). Back a metà flusso = nessuna
  // riga scritta.
  Future<void> _avviaSostituzione() async {
    final set = _setCorrente;
    if (set == null || _testModeEnabled) return;

    final currentAssignments = _currentAssignments;
    final seiCorrenti = <String, Player>{
      for (final slot in _kSlotOrder)
        if (currentAssignments[slot] != null)
          slot: currentAssignments[slot]!,
    };
    if (seiCorrenti.length != 6) return; // dato incoerente, niente cambio
    final palleggiatoreSlotCorrente = _currentSlot;

    // Panchina: roster meno i 6 in campo, meno i liberi (L1/L2 e chiunque
    // abbia ruolo libero: il libero non entra mai con un cambio).
    final liberi = <String, Player>{
      if (widget.assignments['L1'] != null) 'L1': widget.assignments['L1']!,
      if (widget.assignments['L2'] != null) 'L2': widget.assignments['L2']!,
    };
    final idsInCampo = {for (final p in seiCorrenti.values) p.id};
    final idsLiberi = {for (final p in liberi.values) p.id};
    final panchina = [
      for (final p in _rosterById.values)
        if (!idsInCampo.contains(p.id) &&
            !idsLiberi.contains(p.id) &&
            p.ruolo != Ruolo.libero)
          p,
    ];

    final risultato = await Navigator.push<RisultatoSostituzione>(
      context,
      MaterialPageRoute(
        builder: (_) => SostituzioneScreen(
          match: widget.match,
          team: widget.team,
          seiCorrenti: seiCorrenti,
          panchina: panchina,
          liberi: liberi,
          palleggiatoreSlotCorrente: palleggiatoreSlotCorrente,
          ruoloCambiLiberoCorrente: _ruoloCambiLiberoEffettivo,
        ),
      ),
    );
    if (risultato == null || !mounted) return;

    // Difesa in profondità: mai scrivere eventi che metterebbero lo stesso
    // giocatore in due posizioni (dati corrotti, ValueKey duplicate in UI).
    final idsFinali = {for (final p in risultato.seiFinali.values) p.id};
    if (idsFinali.length != risultato.seiFinali.length) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Sostituzione non valida: un giocatore comparirebbe due '
              'volte in campo')));
      return;
    }

    // Diff posizione per posizione: originale ≠ finale → un cambio.
    final cambi = <({int esceId, int entraId})>[];
    for (final slot in _kSlotOrder) {
      final originale = seiCorrenti[slot];
      final finale = risultato.seiFinali[slot];
      if (originale != null &&
          finale != null &&
          originale.id != finale.id) {
        cambi.add((esceId: originale.id, entraId: finale.id));
      }
    }

    // Override di configurazione: solo se diversi dai valori effettivi
    // correnti (null = invariato, la riga evento resta minimale).
    final setterIdCorrente = _statoSetReale?.palleggiatoreId ??
        widget.assignments[widget.palleggiatoreSlot]?.id;
    final nuovoPalleggiatore =
        risultato.seiFinali[risultato.palleggiatoreSlot];
    final overridePalleggiatore =
        (nuovoPalleggiatore != null && nuovoPalleggiatore.id != setterIdCorrente)
            ? nuovoPalleggiatore.id
            : null;
    final ruoloCambiCorrente = _ruoloCambiLiberoEffettivo;
    final overrideRuoloCambi =
        risultato.ruoloCambiLibero != ruoloCambiCorrente
            ? risultato.ruoloCambiLibero
            : null;

    if (cambi.isEmpty &&
        overridePalleggiatore == null &&
        overrideRuoloCambi == null) {
      return; // niente da registrare
    }

    final repo = ref.read(scoutActionRepositoryProvider);
    // Tutte le righe di questo blocco condividono lo stesso gruppoCambio:
    // l'undo le elimina insieme (annullare solo metà di un doppio cambio
    // non ha senso pallavolistico). Un timestamp è unico a sufficienza tra
    // blocchi diversi dello stesso set.
    final gruppoCambio = DateTime.now().millisecondsSinceEpoch;
    if (cambi.isEmpty) {
      // Solo riconfigurazione (nessun cambio di giocatori): una riga
      // no-op con esceId == entraId che porta solo gli override —
      // ricalcolaStato la rigioca senza toccare la rotazione.
      final ancoraId = nuovoPalleggiatore?.id ?? seiCorrenti['P1']!.id;
      await repo.registraSostituzione(
        setId: set.id,
        entraId: ancoraId,
        esceId: ancoraId,
        nuovoPalleggiatoreId: overridePalleggiatore,
        nuovoRuoloCambiLibero: overrideRuoloCambi,
        gruppoCambio: gruppoCambio,
      );
    } else {
      for (var i = 0; i < cambi.length; i++) {
        final ultimo = i == cambi.length - 1;
        await repo.registraSostituzione(
          setId: set.id,
          entraId: cambi[i].entraId,
          esceId: cambi[i].esceId,
          // Gli override viaggiano sull'ULTIMA riga: applicati quando
          // tutti i cambi del blocco sono già in campo.
          nuovoPalleggiatoreId: ultimo ? overridePalleggiatore : null,
          nuovoRuoloCambiLibero: ultimo ? overrideRuoloCambi : null,
          gruppoCambio: gruppoCambio,
        );
      }
    }
    if (!mounted) return;
    // Palla morta: un eventuale pannello voto aperto non ha più senso.
    // _fondamentaleGiudicatoRallyCorrente NON si tocca: il cambio non
    // chiude lo scambio (si può sostituire tra un punto e l'altro senza
    // alterare la fase di gioco).
    setState(() => _votoInCorso = null);
  }

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _kBg,
      drawer: _buildUtilityDrawer(),
      floatingActionButton: _testModeEnabled
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF00008A),
              onPressed: _testAvanza,
              icon: const Icon(Icons.skip_next),
              label: Text(
                '$_currentSlot '
                '${_testServizio == Squadra.nostra ? "battuta" : "ricezione"}'
                '${_testDopo ? " (dopo)" : ""}',
              ),
            )
          : null,
      body: Column(
        children: [
          Container(
            height: 80,
            color: _kTopBarBg,
            child: LayoutBuilder(
              builder: (context, headerConstraints) {
                const scoreControlWidth = 116.0;
                final leftScoreLeft =
                    headerConstraints.maxWidth * 0.25 - scoreControlWidth / 2;
                final rightScoreLeft =
                    headerConstraints.maxWidth * 0.75 - scoreControlWidth / 2;
                return Stack(
                  children: [
                    Positioned(
                      left: 56,
                      right: 56,
                      bottom: 4,
                      child: Text(
                        _matchTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Positioned(
                      left: leftScoreLeft,
                      width: scoreControlWidth,
                      bottom: 4,
                      child: _isRightSide
                          ? _buildScoreDisplay(
                              _punteggioAvversario, Squadra.avversari)
                          : _buildScoreDisplay(
                              _punteggioNostro, Squadra.nostra),
                    ),
                    Positioned(
                      left: rightScoreLeft,
                      width: scoreControlWidth,
                      bottom: 4,
                      child: _isRightSide
                          ? _buildScoreDisplay(
                              _punteggioNostro, Squadra.nostra)
                          : _buildScoreDisplay(
                              _punteggioAvversario, Squadra.avversari),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.menu, color: Colors.white),
                            onPressed: () =>
                                _scaffoldKey.currentState?.openDrawer(),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.undo, color: Colors.white),
                            onPressed:
                                _puoAnnullare
                                    ? _confermaAnnullaUltimaAzione
                                    : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _isRightSide
                  ? [_buildBottoniAvversario(), _buildBottoniNostri()]
                  : [_buildBottoniNostri(), _buildBottoniAvversario()],
            ),
          ),
          // Altezza fissa (anche senza azioni) per non far "saltare" il
          // campo sottostante quando il banner appare/scompare — 36 invece
          // di 32 per lasciare spazio al simbolo del voto, più grande del
          // resto della riga (vedi _buildBannerUltimaAzione).
          SizedBox(
            height: 36,
            child: Center(child: _buildBannerUltimaAzione()),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Margine sinistro/destro del 21% dello schermo: il campo
                // occupa il restante 58% della larghezza, centrato.
                final courtWidth = constraints.maxWidth * 0.58;
                // Campo piccolo: 5% di margine da top e 3% da left
                // larghezza massima del 7% dello schermo (per mantenere proporzioni con il campo grande)
                final smallCourtSize = constraints.maxWidth * 0.07;
                // Mini-map e bottoni di rotazione seguono il lato del campo:
                // a sinistra di default, speculari a destra quando si cambia
                // campo (stesso margine del 3%).
                final horizontalMargin = constraints.maxWidth * 0.03;
                final minimapLeft = _isRightSide
                    ? constraints.maxWidth - smallCourtSize - horizontalMargin
                    : horizontalMargin;
                return Stack(
                  children: [
                    Positioned(
                      top: _kCourtTopMargin,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: SizedBox(
                          width: courtWidth,
                          child: AspectRatio(
                            aspectRatio: 1200 / 600,
                            child: LayoutBuilder(
                              builder: (context, courtConstraints) {
                                final cw = courtConstraints.maxWidth;
                                final ch = courtConstraints.maxHeight;
                                return Stack(
                                  // Il battitore in P1 esce dal campo (X
                                  // negativa, vedi _kBattutaP1Position): senza
                                  // Clip.none lo Stack lo taglierebbe via
                                  // (default Clip.hardEdge) invece di
                                  // disegnarlo comunque sopra.
                                  clipBehavior: Clip.none,
                                  children: [
                                    Image.asset(_kCourtImage,
                                        fit: BoxFit.contain),
                                    ..._buildCourtTokens(cw, ch),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: constraints.maxHeight * 0.05,
                      left: minimapLeft,
                      width: smallCourtSize,
                      height: smallCourtSize,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Stack(
                            children: [
                              Transform.rotate(
                                angle: _isRightSide ? math.pi : 0,
                                child: Image.asset(_kSmallCourtImage,
                                    fit: BoxFit.contain),
                              ),
                              _buildRotationBadge(smallCourtSize),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Bottoni di rotazione manuale: utili solo in modalità
                    // test (la rotazione reale segue gli eventi via
                    // _statoSetReale, non più un contatore manuale).
                    if (_testModeEnabled)
                      Positioned(
                        top: constraints.maxHeight * 0.05 + smallCourtSize + 8,
                        left: minimapLeft,
                        width: smallCourtSize,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildRotationButton(
                                Icons.rotate_right, _rotateBackward, smallCourtSize),
                            _buildRotationButton(
                                Icons.rotate_left, _rotateForward, smallCourtSize),
                          ],
                        ),
                      ),
                    ..._buildLiberoSwapTokens(constraints, courtWidth),
                    ..._buildBattitoreTapCatcher(constraints, courtWidth),
                    ..._buildActionLog(),
                    ..._buildPannelloVoto(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Pannello laterale per i bottoni "di utilità" usati raramente (es.
  // cambio campo), per non affollare l'area sopra il campo grande.
  Widget _buildUtilityDrawer() {
    return Drawer(
      backgroundColor: _kBg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Utilità',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            ListTile(
              leading: const Icon(Icons.swap_horiz, color: Colors.white),
              title: const Text('Cambia campo',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                _toggleSide();
                _scaffoldKey.currentState?.closeDrawer();
              },
            ),
            // Sostituzione (cambio giocatore) — stessa condizione dei
            // bottoni rapidi: set iniziato e fuori dalla modalità test (il
            // cambio scrive un evento reale).
            ListTile(
              enabled: _bottoniRapidiAttivi,
              leading: Icon(Icons.swap_vert,
                  color:
                      _bottoniRapidiAttivi ? Colors.white : Colors.white38),
              title: Text('Sostituzione',
                  style: TextStyle(
                      color: _bottoniRapidiAttivi
                          ? Colors.white
                          : Colors.white38)),
              onTap: () {
                _scaffoldKey.currentState?.closeDrawer();
                _avviaSostituzione();
              },
            ),
            SwitchListTile(
              value: _showJerseyNumbers,
              onChanged: (v) => setState(() => _showJerseyNumbers = v),
              title: Text(
                  _showJerseyNumbers ? 'Mostra ruoli' : 'Mostra numeri',
                  style: const TextStyle(color: Colors.white)),
              activeThumbColor: Colors.white,
              activeTrackColor: const Color(0xFF00008A),
              inactiveThumbColor: Colors.white70,
              inactiveTrackColor: Colors.white24,
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart, color: Colors.white),
              title: const Text('Statistiche',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                _scaffoldKey.currentState?.closeDrawer();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlayerStatsScreen(
                        match: widget.match, team: widget.team),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_forward, color: Colors.white),
              title: const Text('Traiettorie battute',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                _scaffoldKey.currentState?.closeDrawer();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TrajectoryReportScreen(
                      match: widget.match,
                      team: widget.team,
                      fondamentale: Fondamentale.battuta,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.trending_up, color: Colors.white),
              title: const Text('Traiettorie attacco',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                _scaffoldKey.currentState?.closeDrawer();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TrajectoryReportScreen(
                      match: widget.match,
                      team: widget.team,
                      fondamentale: Fondamentale.attacco,
                    ),
                  ),
                );
              },
            ),
            const Divider(color: Colors.white24, height: 1),
            SwitchListTile(
              value: _testModeEnabled,
              onChanged: _toggleTestMode,
              title: const Text('Modalità test',
                  style: TextStyle(color: Colors.white)),
              subtitle: const Text(
                'Bottone per scorrere rotazione × chi serve',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              activeThumbColor: Colors.white,
              activeTrackColor: const Color(0xFF00008A),
              inactiveThumbColor: Colors.white70,
              inactiveTrackColor: Colors.white24,
            ),
            SwitchListTile(
              value: _showActionLog,
              onChanged: (v) => setState(() => _showActionLog = v),
              title: const Text('Log azioni (debug)',
                  style: TextStyle(color: Colors.white)),
              subtitle: const Text(
                'Lista delle azioni del set corrente',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              activeThumbColor: Colors.white,
              activeTrackColor: const Color(0xFF00008A),
              inactiveThumbColor: Colors.white70,
              inactiveTrackColor: Colors.white24,
            ),
            const Divider(color: Colors.white24, height: 1),
            ListTile(
              leading: const Icon(Icons.flag, color: Colors.white),
              title: const Text('Fine', style: TextStyle(color: Colors.white)),
              // A differenza di "Indietro" qui si fa un push, non un pop:
              // niente local history entry da gestire, basta chiudere il
              // drawer per pulizia visiva prima di navigare.
              onTap: () {
                _scaffoldKey.currentState?.closeDrawer();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        EndSetScreen(match: widget.match, team: widget.team),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_back, color: Colors.white),
              title: const Text('Indietro',
                  style: TextStyle(color: Colors.white)),
              // Il Drawer registra una "local history entry" sulla route:
              // mentre è aperto, Navigator.pop(context) chiude SOLO il
              // drawer (consuma quella entry) invece di tornare alla
              // schermata precedente. Si cattura il Navigator prima di
              // chiudere il drawer esplicitamente, poi si fa il pop vero
              // sul Navigator catturato.
              onTap: () {
                final navigator = Navigator.of(context);
                _scaffoldKey.currentState?.closeDrawer();
                navigator.pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRotationBadge(double courtSize) {
    final baseAnchor =
        _kRotationBadgeAnchor[_currentSlot] ?? Alignment.bottomLeft;
    // La mini-map è ruotata di 180° sul campo destro: l'ancoraggio del badge
    // segue la stessa rotazione (negare entrambe le componenti), mentre il
    // testo resta dritto e leggibile.
    final anchor = _isRightSide
        ? Alignment(-baseAnchor.x, -baseAnchor.y)
        : baseAnchor;
    final badgeWidth = courtSize * 0.5;
    final badgeHeight = courtSize / 3;
    return Align(
      alignment: anchor,
      child: SizedBox(
        width: badgeWidth,
        height: badgeHeight,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Color(widget.team.coloreDivisa),
            borderRadius: BorderRadius.circular(badgeHeight * 0.1),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Text(
            _currentSlot,
            style: TextStyle(
              color: contrastingTextColor(Color(widget.team.coloreDivisa)),
              fontWeight: FontWeight.bold,
              fontSize: badgeHeight * 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Player? _playerPerId(int? id) {
    if (id == null) return null;
    // _rosterById (non widget.assignments): un subentrato da cambio
    // giocatore parte dalla panchina, non è nella formazione iniziale.
    return _rosterById[id];
  }

  // Pannello di debug col log delle azioni del SET CORRENTE (vedi
  // _showActionLog): una riga per ScoutAction — "ordine·rally  descrizione
  // voto" (stesso testo/colori di _descrizioneAzione) — più recente in
  // alto. Vive nello Stack esterno, ancorato al bordo destro; nascosto
  // quando il pannello voto è aperto (stessa zona).
  List<Widget> _buildActionLog() {
    if (!_showActionLog || _votoInCorso != null) return const [];
    final set = _setCorrente;
    if (set == null) return const [];
    final righe =
        ref.watch(scoutAzioniStreamProvider(set.id)).value ??
            const <ScoutAction>[];
    // Punteggio parziale dopo ogni azione che chiude un rally (esito non
    // "nessuno"): replay leggero dei soli esiti, in ordine. Non include le
    // correzioni manuali del punteggio (vivono su MatchSet, non nel log).
    final parziali = <int, String>{}; // ScoutAction.id -> "n–a"
    var nostro = 0, avversario = 0;
    for (final r in righe) {
      switch (r.esitoPunto) {
        case EsitoPunto.puntoNostro:
          nostro++;
        case EsitoPunto.puntoAvversario:
          avversario++;
        case EsitoPunto.nessuno:
          continue;
      }
      parziali[r.id] = '$nostro–$avversario';
    }
    return [
      Positioned(
        top: 8,
        bottom: 8,
        right: 8,
        width: 240,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _kTopBarBg.withAlpha(235),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: righe.isEmpty
              ? const Center(
                  child: Text(
                    'Nessuna azione',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                )
              : ListView.builder(
                  itemCount: righe.length,
                  itemBuilder: (context, i) {
                    final a = righe[righe.length - 1 - i]; // recente in alto
                    final desc = _descrizioneAzione(a);
                    // Il blu brand del "Cambio" è illeggibile sul fondo
                    // scuro del pannello: solo qui si schiarisce.
                    final coloreTesto = desc.colore == AppColors.brandPrimary
                        ? Colors.lightBlueAccent
                        : desc.colore;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(
                            text: '${a.ordine}·r${a.rallyId}  ',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 13),
                          ),
                          TextSpan(
                            text: desc.testo,
                            style: TextStyle(
                              // Per punto/errore/cambio (voto assente) il
                              // colore semantico va sul testo; per i voti
                              // resta sul solo simbolo, più leggibile.
                              color: desc.voto == null
                                  ? coloreTesto
                                  : Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          if (desc.voto != null)
                            TextSpan(
                              text: '  ${desc.voto}',
                              style: TextStyle(
                                color: coloreTesto,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          if (parziali[a.id] != null)
                            TextSpan(
                              text: '  ${parziali[a.id]}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ),
    ];
  }

  // Testo + colore per il banner "ultima azione". Azione di scout (voto su
  // un fondamentale): "Numero - Cognome - Fondamentale | Voto" — separatore
  // finale "|" invece di "-" perché il simbolo del voto può essere lui
  // stesso "-" (negativo): con due trattini di seguito si confondeva con un
  // separatore. Colorato come il voto stesso. Bottoni rapidi (punto/errore,
  // nessun giocatore): solo l'etichetta, verde per i punti (stesso
  // AppColors.success del voto "perfetto" — un punto generico è più vicino
  // a "perfetto" che a "positivo") e rosso per gli errori — stessi colori
  // dei bottoni che li generano (vedi _buildQuickActionButton).
  ({String testo, String? voto, Color colore}) _descrizioneAzione(
      ScoutAction azione) {
    final player = _playerPerId(azione.giocatoreId);
    final fondamentale = azione.fondamentale;
    final voto = azione.voto;
    if (azione.tipo == TipoAzione.scout &&
        player != null &&
        fondamentale != null &&
        voto != null) {
      return (
        testo: '${player.numero} - ${player.cognome} - ${fondamentale.label}',
        voto: voto.simbolo,
        colore: CourtStyle.votoColor(voto),
      );
    }
    // Cambio giocatore: giocatoreId = chi entra, giocatoreUscenteId = chi
    // esce. Colore neutro (nessun punto per nessuno). Se un giocatore è
    // stato eliminato dopo il cambio (FK setNull), si mostra "?" — la riga
    // resta comunque leggibile.
    if (azione.tipo == TipoAzione.cambioGiocatore) {
      final esce = _playerPerId(azione.giocatoreUscenteId);
      String etichetta(Player? p) =>
          p == null ? '?' : '${p.numero} ${p.cognome}';
      return (
        testo: 'Cambio: esce ${etichetta(esce)}, entra ${etichetta(player)}',
        voto: null,
        colore: AppColors.brandPrimary,
      );
    }
    // Per la nostra squadra si usa il nome reale (es. "Punto Nettunia")
    // invece del generico "nostro" — stesso testo sia nel banner ultima
    // azione sia nel dialog di conferma undo (entrambi riusano questa
    // funzione). Per l'avversario resta "avversario": il nome può non
    // essere impostato (vedi _matchTitle), quindi non c'è un equivalente
    // sempre disponibile.
    final squadraLabel =
        azione.squadra == Squadra.nostra ? widget.team.nome : 'avversario';
    final isPunto = azione.tipo == TipoAzione.puntoManuale;
    var testo = '${isPunto ? "Punto" : "Errore"} $squadraLabel';
    // Motivo dell'errore (scelto con la pressione prolungata sul bottone
    // "Errore avversario", salvato in tipoEsecuzione — vedi MotivoErrore):
    // aggiunto in coda, es. "Errore avversario - Battuta". `generico` (il
    // tap veloce) non si mostra, non aggiunge informazione.
    if (azione.tipo == TipoAzione.erroreGenerico) {
      final motivo = MotivoErrore.values
          .where((m) => m.name == azione.tipoEsecuzione)
          .firstOrNull;
      if (motivo != null && motivo != MotivoErrore.generico) {
        testo = '$testo - ${motivo.label}';
      }
    }
    return (
      testo: testo,
      voto: null,
      colore: isPunto ? AppColors.success : Colors.red,
    );
  }

  Widget? _buildBannerUltimaAzione() {
    final azione = _ultimaAzione;
    if (azione == null) return null;
    final descrizione = _descrizioneAzione(azione);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: descrizione.colore,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            descrizione.testo,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              height: 1.0,
            ),
          ),
          if (descrizione.voto != null) ...[
            const SizedBox(width: 10),
            Text(
              descrizione.voto!,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
                height: 1.0,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Punteggio + bottoni di correzione manuale (+/-) — override diretto del
  // valore mostrato (vedi _correggiPunteggio), non loggato come ScoutAction.
  // Disabilitati con le stesse condizioni dei bottoni rapidi
  // (_bottoniRapidiAttivi); "-" disabilitato anche a punteggio già a 0 (un
  // punteggio reale non scende mai sotto zero).
  Widget _buildScoreDisplay(int score, Squadra squadra) {
    final attivo = _bottoniRapidiAttivi;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildScoreAdjustButton(
          Icons.remove,
          attivo && score > 0
              ? () => _correggiPunteggio(squadra, -1)
              : null,
        ),
        SizedBox(
          width: 32,
          child: Text(
            '$score',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
        _buildScoreAdjustButton(
          Icons.add,
          attivo ? () => _correggiPunteggio(squadra, 1) : null,
        ),
      ],
    );
  }

  Widget _buildScoreAdjustButton(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(onTap != null ? 30 : 10),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          icon,
          color: onTap != null ? Colors.white : Colors.white38,
          size: 16,
        ),
      ),
    );
  }

  // Riga "Errore nostro" (rosso, X) + "Punto nostro" (verde, check — stesso
  // colore del voto "perfetto", non blu: un punto generico è semanticamente
  // più vicino a "perfetto" che a "positivo").
  Widget _buildBottoniNostri() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildQuickActionButton(
          icon: Icons.close,
          color: Colors.red,
          onTap: _bottoniRapidiAttivi
              ? () => _registraAzioneRapida(Squadra.nostra,
                  TipoAzione.erroreGenerico, EsitoPunto.puntoAvversario)
              : null,
        ),
        const SizedBox(width: 8),
        _buildQuickActionButton(
          icon: Icons.check,
          color: AppColors.success,
          onTap: _bottoniRapidiAttivi
              ? () => _registraAzioneRapida(Squadra.nostra,
                  TipoAzione.puntoManuale, EsitoPunto.puntoNostro)
              : null,
        ),
      ],
    );
  }

  // Speculare a _buildBottoniNostri: "Punto avversario" (verde, check) +
  // "Errore avversario" (rosso, X) — ordine invertito per simmetria visiva.
  Widget _buildBottoniAvversario() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildQuickActionButton(
          icon: Icons.check,
          color: AppColors.success,
          onTap: _bottoniRapidiAttivi
              ? () => _registraAzioneRapida(Squadra.avversari,
                  TipoAzione.puntoManuale, EsitoPunto.puntoAvversario)
              : null,
        ),
        const SizedBox(width: 8),
        _buildQuickActionButton(
          icon: Icons.close,
          color: Colors.red,
          onTap: _bottoniRapidiAttivi
              ? () => _registraAzioneRapida(Squadra.avversari,
                  TipoAzione.erroreGenerico, EsitoPunto.puntoNostro,
                  tipoEsecuzione: MotivoErrore.generico.name)
              : null,
          // Pressione prolungata: scegli il motivo dell'errore (Battuta/
          // Fallo di posizione/Invasione) invece del default "Generico"
          // del tap singolo — vedi MotivoErrore in enums.dart. Se va bene,
          // si può estendere lo stesso meccanismo ad altri bottoni rapidi.
          onLongPressStart: _bottoniRapidiAttivi
              ? (details) => _scegliMotivoErroreAvversario(details.globalPosition)
              : null,
        ),
      ],
    );
  }

  Future<void> _scegliMotivoErroreAvversario(Offset posizione) async {
    final scelto = await showMenu<MotivoErrore>(
      context: context,
      position: RelativeRect.fromLTRB(
          posizione.dx, posizione.dy, posizione.dx, posizione.dy),
      items: [
        for (final motivo in MotivoErrore.values)
          PopupMenuItem(value: motivo, child: Text(motivo.label)),
      ],
    );
    if (scelto == null) return;
    _registraAzioneRapida(Squadra.avversari, TipoAzione.erroreGenerico,
        EsitoPunto.puntoNostro,
        tipoEsecuzione: scelto.name);
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
    void Function(LongPressStartDetails)? onLongPressStart,
  }) {
    final abilitato = onTap != null;
    return GestureDetector(
      onTap: onTap,
      onLongPressStart: onLongPressStart,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: abilitato ? color : color.withAlpha(80),
          borderRadius: BorderRadius.circular(10),
          boxShadow: abilitato
              ? [
                  BoxShadow(
                    color: Colors.black.withAlpha(120),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  // Bottoni di scelta del fondamentale (Alzata/Attacco/Muro/Difesa), mostrati
  // nel pannello voto quando _votoInCorso.fondamentale è ancora null (fase
  // "libera", dopo che battuta/ricezione sono già state giudicate in questo
  // scambio) — vedi _sceglieFondamentale.
  Widget _buildSceltaFondamentale() {
    const opzioni = [
      Fondamentale.alzata,
      Fondamentale.attacco,
      Fondamentale.muro,
      Fondamentale.difesa,
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final f in opzioni) ...[
          _buildFondamentaleButton(f),
          if (f != opzioni.last) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildFondamentaleButton(Fondamentale fondamentale) {
    return GestureDetector(
      onTap: () => _sceglieFondamentale(fondamentale),
      child: Container(
        width: 150,
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.brandPrimary,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(120),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          fondamentale.label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  // Pannello voto: si apre toccando un giocatore tappabile (battitore in
  // battuta, qualunque ricevitore in ricezione — vedi
  // _tapHandlerPerGiocatore), ancorato al bordo destro dello schermo, 5
  // bottoni verticali (uno per Voto, stesso ordine dell'enum: # + / - =).
  // Per la battuta, anche la griglia opzionale del tipo (vedi sopra).
  // Niente traiettoria per ora.
  // Ritorna [] se il pannello è chiuso. Quando aperto: uno sfondo
  // trasparente a tutto schermo (tap fuori dal pannello → annulla, vedi
  // sotto) + il pannello stesso.
  List<Widget> _buildPannelloVoto() {
    final inCorso = _votoInCorso;
    if (inCorso == null) return const [];
    final player = inCorso.giocatore;

    return [
      // Tap fuori dal pannello = annulla. Lo Stack ferma la ricerca del
      // tocco al primo figlio che lo "reclama" (vedi GestureDetector del
      // pannello sotto, che lo assorbe con un onTap no-op): quindi un tap
      // sul pannello non arriva mai qui, solo un tap altrove sullo schermo.
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _votoInCorso = null),
        ),
      ),
      Positioned(
        right: 16,
        top: 12,
        bottom: 16,
        child: Align(
          alignment: Alignment.topCenter,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {}, // assorbe il tap, non deve propagarsi allo sfondo
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: _kTopBarBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 100,
                    child: Column(
                      children: [
                        Text(
                          '${player.numero}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                        Text(
                          player.cognome,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (inCorso.fondamentale == null) ...[
                    const SizedBox(height: 4),
                    _buildSceltaFondamentale(),
                  ] else ...[
                    Text(
                      inCorso.fondamentale!.label,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    for (final voto in Voto.values) ...[
                      GestureDetector(
                        onTap: () => _registraVoto(voto),
                        child: Container(
                          width: 100,
                          height: 64,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: CourtStyle.votoColor(voto),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(120),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            voto.simbolo,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 28,
                            ),
                          ),
                        ),
                      ),
                      if (voto != Voto.values.last) const SizedBox(height: 12),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildRotationButton(
      IconData icon, VoidCallback onTap, double smallCourtSize) {
    final buttonSize = smallCourtSize * 0.45;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          color: const Color(0xFF00008A),
          borderRadius: BorderRadius.circular(buttonSize * 0.25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(120),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: buttonSize * 0.55),
      ),
    );
  }

  // Slot occupato dal giocatore di SECONDA LINEA (P5, P6 o P1) che il libero
  // sostituisce — la coppia è quella scelta in FormationConfigScreen
  // (`_ruoloCambiLiberoEffettivo`: centrali o schiacciatori, mai una
  // combinazione). I due della coppia sono sempre opposti nella rotazione (3
  // posizioni di distanza), quindi ce n'è sempre esattamente uno in seconda
  // linea. Null se non c'è libero in formazione, o se per qualche motivo
  // nessuno dei due ruoli della coppia è assegnato (formazione incompleta).
  String? _slotCentraleSecondaLinea(Map<String, String> roleLabels) {
    final ruolo = _ruoloCambiLiberoEffettivo;
    if (ruolo == null) return null;
    final etichette = (ruolo == Ruolo.centrale || ruolo == Ruolo.undefined)
        ? const {'C1', 'C2'}
        : const {'S1', 'S2'};
    const secondaLinea = {'P5', 'P6', 'P1'};
    for (final entry in roleLabels.entries) {
      if (secondaLinea.contains(entry.key) &&
          etichette.contains(entry.value)) {
        return entry.key;
      }
    }
    return null;
  }

  // Costruisce i token dei giocatori sul campo grande, ESCLUSO lo slot della
  // coppia cambi-libero (`_slotCentraleSecondaLinea`): libero e relativo
  // sostituito vivono nello Stack esterno (vedi _buildLiberoSwapTokens),
  // perché devono potersi animare anche verso/da la panchina ancorata allo
  // schermo, fuori dai confini di questo campo. In ricezione (mappa di
  // difesa attiva per la rotazione corrente): itera per RUOLO sulla mappa di
  // difesa. Altrimenti: itera per giocatore sulle posizioni di attacco.
  List<Widget> _buildCourtTokens(double cw, double ch) {
    final currentAssignments = _currentAssignments;
    final roleLabels = _roleLabelsFor(_currentSlot, currentAssignments);
    final defenseMap = _activeDefenseMap;
    final slotCentrale = _slotCentraleSecondaLinea(roleLabels);

    if (defenseMap == null) {
      return [
        for (final entry in currentAssignments.entries)
          if (entry.key != slotCentrale)
            _buildPlayerToken(
                roleLabels[entry.key] ?? entry.key,
                entry.value,
                _displayPosition(_attackPosition(entry.key, roleLabels)),
                cw,
                ch,
                onTap: _tapHandlerPerGiocatore(entry.value, slot: entry.key)),
      ];
    }

    final slotPerRuolo = {
      for (final e in roleLabels.entries) e.value: e.key,
    };
    final tokens = <Widget>[];
    for (final entry in defenseMap.entries) {
      if (entry.key == 'Libero') continue; // gestito nello Stack esterno
      final slot = slotPerRuolo[entry.key];
      final player = slot == null ? null : currentAssignments[slot];
      if (player != null) {
        tokens.add(_buildPlayerToken(
            entry.key, player, _displayPosition(entry.value), cw, ch,
            onTap: _tapHandlerPerGiocatore(player, slot: slot)));
      }
    }
    return tokens;
  }

  // Libero e relativo sostituito (centrale/schiacciatore di seconda linea):
  // chi è "in campo" e chi è "in panchina" si scambiano a ogni rotazione, e
  // la panchina deve restare ancorata ai bordi reali dello schermo (non al
  // riquadro del campo, che è centrato con margini) — quindi entrambi vivono
  // in QUESTO Stack esterno (coordinate schermo assolute), non in quello
  // interno del campo grande. Stessa key (player.id) sia in campo sia in
  // panchina: AnimatedPositioned anima il movimento in entrambi i casi.
  List<Widget> _buildLiberoSwapTokens(BoxConstraints constraints, double courtWidth) {
    final liberoKey = _liberoAttivoKey;
    final libero = widget.assignments[liberoKey];
    if (libero == null) return const [];

    final radius = _swapTokenRadius(courtWidth);
    final bench0 = _benchScreenPos(constraints, radius);
    final bench1 = _bench1ScreenPos(constraints, radius);

    // Libero inattivo (slot 1): sempre in panchina fissa, tappabile.
    // Usa ValueKey(player.id) come tutti i token: Flutter può così animare
    // il movimento quando attivo e inattivo si scambiano (stesso key, nuova
    // posizione → AnimatedPositioned interpola fluidamente tra le due).
    final inattivoKey = _liberoInattivoKey;
    final inattivo = inattivoKey != null ? widget.assignments[inattivoKey] : null;
    final bench1Token = inattivo != null
        ? _buildAbsoluteToken(inattivoKey!, inattivo, bench1, radius,
            isLibero: true,
            onTap: () => setState(() => _liberoOverride = inattivoKey))
        : null;

    final currentAssignments = _currentAssignments;
    final roleLabels = _roleLabelsFor(_currentSlot, currentAssignments);
    final slotCentrale = _slotCentraleSecondaLinea(roleLabels);
    if (slotCentrale == null) {
      // Nessuna coppia di cambio derivabile (formazione incompleta): il
      // libero attivo resta in panchina (slot 0).
      return [
        _buildAbsoluteToken(liberoKey, libero, bench0, radius, isLibero: true),
        ?bench1Token,
      ];
    }
    final giocatoreCoppia = currentAssignments[slotCentrale];
    if (giocatoreCoppia == null) {
      return [?bench1Token];
    }

    final defenseMap = _activeDefenseMap;
    // L'eccezione del servizio (libero in panchina) vale SOLO quando stiamo
    // per servire noi e il sostituito è in P1 — non quando `defenseMap` è
    // null per un altro motivo (es. ricezione già giudicata, fase di
    // attacco: il libero deve restare in campo anche se il sostituito è
    // rotato in P1, perché in quella fase P1 non significa "deve servire").
    final stiamoServendo = _squadraAlServizio == Squadra.nostra;
    final sostituzioneAttiva = !(stiamoServendo && slotCentrale == 'P1');
    final courtHeight = courtWidth / 2;
    final courtLeft = (constraints.maxWidth - courtWidth) / 2;
    final courtTop = _kCourtTopMargin;
    Offset toScreen(Offset ref) => Offset(
          courtLeft + (ref.dx / 1200) * courtWidth,
          courtTop + (ref.dy / 600) * courtHeight,
        );

    if (sostituzioneAttiva) {
      // In ricezione il libero ha una sua posizione dedicata (mappa di
      // difesa); in battuta prende esattamente il posto del sostituito. È
      // in campo → tappabile (solo in ricezione, vedi _fondamentaleTappabile
      // con slot=null: il libero non ha uno slot P1-P6 proprio).
      final liberoRef = defenseMap != null
          ? defenseMap['Libero']!
          : (_activeAttackMap?['Libero'] ?? _refPositionFor(slotCentrale));
      return [
        _buildAbsoluteToken(liberoKey, libero,
            toScreen(_displayPosition(liberoRef)), radius,
            isLibero: true, onTap: _tapHandlerPerGiocatore(libero)),
        // Il sostituito è in panchina (slot 0): non tappabile.
        _buildAbsoluteToken(roleLabels[slotCentrale] ?? slotCentrale,
            giocatoreCoppia, bench0, radius),
        ?bench1Token,
      ];
    }
    // Eccezione del servizio (P1): il sostituito resta in campo (tappabile:
    // è il battitore in battuta, un ricevitore normale in ricezione), il
    // libero attivo va in panchina (slot 0, non tappabile).
    return [
      _buildAbsoluteToken(
          roleLabels[slotCentrale] ?? slotCentrale,
          giocatoreCoppia,
          toScreen(_displayPosition(_attackPosition(slotCentrale, roleLabels))),
          radius,
          onTap: _tapHandlerPerGiocatore(giocatoreCoppia, slot: slotCentrale)),
      _buildAbsoluteToken(liberoKey, libero, bench0, radius, isLibero: true),
      ?bench1Token,
    ];
  }

  // Area di tap per il battitore quando è fuori dal campo (X negativa, vedi
  // _kBattutaP1Position): il token resta visibile lì grazie a Clip.none
  // sullo Stack interno, ma quella zona è fuori dai limiti di hit-test del
  // SizedBox/AspectRatio che racchiude il campo (Clip.none evita solo il
  // clip del DISEGNO, non quello del tocco) — quindi un GestureDetector
  // dentro lo Stack interno lì non riceverebbe mai il tap. Stessa soluzione
  // già usata per libero/panchina: un overlay nello Stack esterno
  // (coordinate schermo assolute, sempre dentro i suoi limiti), sovrapposto
  // esattamente al token visibile. Solo quando battiamo noi: in ricezione
  // P1 è una posizione normale in campo, già tappabile dal proprio token
  // (qui sarebbe solo un overlay ridondante) — stesso motivo una volta che
  // la battuta è già stata giudicata in questo scambio (_faseDopo): il
  // battitore è rientrato in posizione di attacco, di nuovo coperto dal
  // proprio token normale.
  List<Widget> _buildBattitoreTapCatcher(
      BoxConstraints constraints, double courtWidth) {
    if (_squadraAlServizio != Squadra.nostra) return const [];
    if (_faseDopo) return const [];
    final player = _currentAssignments['P1'];
    if (player == null) return const [];
    final onTap = _tapHandlerPerGiocatore(player, slot: 'P1');
    if (onTap == null) return const [];

    final roleLabels = _roleLabelsFor(_currentSlot, _currentAssignments);
    final radius = _swapTokenRadius(courtWidth);
    final tokenRadius = _currentSlot == 'P1' ? radius * 1.1 : radius;
    final courtHeight = courtWidth / 2;
    final courtLeft = (constraints.maxWidth - courtWidth) / 2;
    final courtTop = _kCourtTopMargin;
    final refPos = _displayPosition(_attackPosition('P1', roleLabels));
    final cx = courtLeft + (refPos.dx / 1200) * courtWidth;
    final cy = courtTop + (refPos.dy / 600) * courtHeight;

    return [
      Positioned(
        left: cx - tokenRadius,
        top: cy - tokenRadius,
        width: tokenRadius * 2,
        height: tokenRadius * 2,
        child: GestureDetector(onTap: onTap),
      ),
    ];
  }

  // Raggio in pixel reali (non in unità di riferimento): un ventesimo del
  // campo, dove "il campo" è l'altezza renderizzata (courtWidth/2), stessa
  // proporzione di _buildPlayerToken (ch/20).
  double _swapTokenRadius(double courtWidth) =>
      (courtWidth / 2) / 20 * _kTokenSizeScale;

  // Stessa posizione/dimensione della vecchia card fissa ad angolo: margine
  // 3% dai bordi reali dello schermo, ancorata in basso (a destra col cambio
  // campo) — non al riquadro del campo, che è centrato con margini propri.
  // Ritorna il CENTRO del token (usato da _buildAbsoluteToken con top/left).
  Offset _benchScreenPos(BoxConstraints constraints, double radius) {
    final margin = constraints.maxWidth * 0.03;
    final size = radius * 2;
    final left =
        _isRightSide ? constraints.maxWidth - size - margin : margin;
    final top = constraints.maxHeight - margin - size;
    return Offset(left + radius, top + radius);
  }

  // Centro del secondo slot in panchina (libero inattivo), affiancato al
  // primo. Su lato sinistro: slot 1 è a destra di slot 0; su lato destro: a
  // sinistra — stessa logica del lato per mini-map e bottoni di rotazione.
  Offset _bench1ScreenPos(BoxConstraints constraints, double radius) {
    final bench0 = _benchScreenPos(constraints, radius);
    final step = (radius * 2 + 8.0) * (_isRightSide ? -1.0 : 1.0);
    return Offset(bench0.dx + step, bench0.dy);
  }

  // Token "assoluto": stesso stile di _buildPlayerToken (cerchio, colore
  // invertito per il libero) ma posizionato in pixel di SCHERMO già
  // calcolati (non da scalare da uno spazio di riferimento) — necessario
  // perché questo Stack esterno copre sia l'area del campo sia l'area
  // "panchina" ancorata ai bordi schermo.
  Widget _buildAbsoluteToken(
      String roleLabel, Player player, Offset center, double radius,
      {bool isLibero = false, VoidCallback? onTap}) {
    final fillColor = isLibero
        ? _invertedColor(Color(widget.team.coloreDivisa))
        : Color(widget.team.coloreDivisa);
    final label = _showJerseyNumbers ? '${player.numero}' : roleLabel;
    final tokenVisual = Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fillColor,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(120),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: contrastingTextColor(fillColor),
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.7,
        ),
      ),
    );
    return AnimatedPositioned(
      key: ValueKey(player.id),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      left: center.dx - radius,
      top: center.dy - radius,
      width: radius * 2,
      height: radius * 2,
      child: onTap == null
          ? tokenVisual
          : GestureDetector(onTap: onTap, child: tokenVisual),
    );
  }

  Widget _buildPlayerToken(
      String roleLabel, Player player, Offset refPos, double cw, double ch,
      {VoidCallback? onTap}) {
    // Raggio = un ventesimo del campo (singolo campo = quadrato 600×600 nello
    // spazio di riferimento, quindi un ventesimo equivale a ch/20), scalato
    // da _kTokenSizeScale.
    final radius = ch / 20 * _kTokenSizeScale;
    final cx = (refPos.dx / 1200) * cw;
    final cy = (refPos.dy / 600) * ch;
    final fillColor = Color(widget.team.coloreDivisa);
    final isPalleggiatore = roleLabel == 'P';
    final label = _showJerseyNumbers ? '${player.numero}' : roleLabel;
    // L'esagono del palleggiatore è il 10% più grande dei token circolari.
    final tokenRadius = isPalleggiatore ? radius * 1.1 : radius;

    final text = Text(
      label,
      style: TextStyle(
        color: contrastingTextColor(fillColor),
        fontWeight: FontWeight.bold,
        fontSize: radius * 0.7,
      ),
    );

    final tokenVisual = isPalleggiatore
        ? CustomPaint(
            painter: _RoundedHexagonPainter(fillColor),
            child: Center(child: text),
          )
        : Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fillColor,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(120),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: text,
          );

    // Key = identità del giocatore (non lo slot): così, quando la rotazione
    // sposta tutti i giocatori, AnimatedPositioned anima ciascun token dalla
    // vecchia alla nuova posizione invece di "teletrasportarlo".
    return AnimatedPositioned(
      key: ValueKey(player.id),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      left: cx - tokenRadius,
      top: cy - tokenRadius,
      width: tokenRadius * 2,
      height: tokenRadius * 2,
      child: onTap == null
          ? tokenVisual
          : GestureDetector(onTap: onTap, child: tokenVisual),
    );
  }

}

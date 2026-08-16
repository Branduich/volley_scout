import 'package:flutter/widgets.dart';

import '../models/enums.dart';

/// Elementi di `ScoutScreen` che il tutorial può evidenziare (il "buco" nello
/// scrim) e/o osservare per far avanzare un passo.
///
/// Aggiungere un valore qui NON basta: il widget corrispondente va avvolto in
/// `_anchor(TutorialTarget.xxx, ...)` dentro `scout_screen.dart`, altrimenti
/// `RegistroTarget.rectOf` torna sempre `null` (l'overlay mostra il testo con
/// lo scrim pieno, senza buco).
///
/// I bottoni dei due pannelli (voti e fondamentali) sono già mappati tutti,
/// così un passo nuovo su uno di essi non richiede modifiche a `ScoutScreen`:
/// vedi `targetVoto...` / `targetFondamentale...` in fondo al file.
enum TutorialTarget {
  /// Gruppo −/punteggio/+ della nostra squadra, nella barra superiore.
  barraPunteggio,

  /// I due pallini di stato dei timeout (nostri), nella barra superiore.
  timeoutDots,

  /// Bottone timeout della nostra squadra.
  bottoneTimeoutNostro,

  /// Freccia "annulla ultima azione", nella barra superiore.
  bottoneUndo,

  /// L'intero gruppo dei nostri bottoni rapidi (errore + punto + timeout).
  bottoniRapidiNostri,

  /// Il solo bottone "punto nostro" (spunta verde).
  puntoNostro,

  /// Token del battitore quando siamo al servizio (fuori dal campo).
  tokenBattitore,

  /// Il nostro libero, quando è in campo.
  tokenLibero,

  /// Il nostro giocatore che attacca, nei passi sull'attacco.
  tokenNostroAttaccante,

  /// Segnaposto avversario che riceve, nei passi sulla ricezione.
  tokenAvversarioRicezione,

  /// Segnaposto avversario che attacca, nei passi sull'attacco.
  tokenAvversarioAttacco,

  /// Segnaposto avversario che difende, nei passi sulla difesa.
  tokenAvversarioDifesa,

  /// Il nostro pannello voto, aperto. Usato soprattutto come segnale di
  /// avanzamento: "il passo è finito quando il pannello compare".
  pannelloVoto,

  /// Il pannello voto degli avversari, aperto.
  pannelloAvversario,

  /// Il registro delle azioni registrate, quando è attivo.
  logAzioni,

  /// La mini-mappa della rotazione, in alto sul lato del campo.
  minimappa,

  /// I due bottoni di correzione della rotazione, sotto la mini-mappa.
  bottoniCorrezioneRotazione,

  /// Hamburger che apre il drawer di utilità.
  bottoneMenu,

  /// Il drawer di utilità aperto.
  drawer,

  /// La voce "Cambia campo" dentro il drawer. È l'unica voce evidenziata a
  /// sé: serve al passo che CHIUDE il menu, perché il suo `onTap` chiama
  /// `closeDrawer()`. Chiudere il drawer prima della card finale non è
  /// estetica — con il drawer aperto il "Termina" (che fa `Navigator.pop`)
  /// consumerebbe la local history entry del Drawer e chiuderebbe quello
  /// invece di uscire dal tutorial (stesso trabocchetto della voce
  /// "Indietro", vedi scout-live.md).
  voceCambiaCampo,

  // --- Bottoni dei voti, nostro pannello (vedi targetVotoNostro) ---------
  votoNostroPerfetto,
  votoNostroPositivo,
  votoNostroMezzoPunto,
  votoNostroNegativo,
  votoNostroErrore,

  // --- Bottoni dei voti, pannello avversario (vedi targetVotoAvversario) -
  votoAvvPerfetto,
  votoAvvPositivo,
  votoAvvMezzoPunto,
  votoAvvNegativo,
  votoAvvErrore,

  // --- Scelta del fondamentale, nostro pannello (fase libera) ------------
  fondNostroAlzata,
  fondNostroAttacco,
  fondNostroMuro,
  fondNostroDifesa,

  // --- Scelta del fondamentale, pannello avversario ----------------------
  fondAvvAttacco,
  fondAvvMuro,
  fondAvvDifesa,
}

/// Ruolo avversario evidenziato da ciascun target "segnaposto". Codici
/// interni, non le etichette a video, che sono localizzate (`C2` in italiano,
/// `MB2` in inglese). Cambiare qui basta a spostare il tutorial su un altro
/// ruolo, senza toccare `ScoutScreen`.
/// Col loro palleggiatore in zona 1 la rotazione canonica dà `S1` in zona 2 e
/// `S2` in zona 5 (vedi `etichetteAvversarie`).
const Map<TutorialTarget, String> kRuoliAvversariTutorial = {
  TutorialTarget.tokenAvversarioRicezione: 'C2',
  TutorialTarget.tokenAvversarioAttacco: 'S1',
  TutorialTarget.tokenAvversarioDifesa: 'S2',
};

/// Come sopra, per i NOSTRI giocatori in campo. Si aggancia al ruolo e non
/// allo slot così il bersaglio segue il giocatore anche dopo una rotazione.
/// Nella formazione della sandbox `S2` parte in zona 4.
const Map<TutorialTarget, String> kRuoliNostriTutorial = {
  TutorialTarget.tokenNostroAttaccante: 'S2',
};

/// Il target del segnaposto avversario con questo ruolo, se ce n'è uno.
TutorialTarget? targetRuoloAvversario(String roleLabel) =>
    _targetPerRuolo(kRuoliAvversariTutorial, roleLabel);

/// Il target del nostro giocatore con questo ruolo, se ce n'è uno.
TutorialTarget? targetRuoloNostro(String roleLabel) =>
    _targetPerRuolo(kRuoliNostriTutorial, roleLabel);

TutorialTarget? _targetPerRuolo(
    Map<TutorialTarget, String> mappa, String roleLabel) {
  for (final e in mappa.entries) {
    if (e.value == roleLabel) return e.key;
  }
  return null;
}

TutorialTarget targetVotoNostro(Voto voto) => switch (voto) {
      Voto.perfetto => TutorialTarget.votoNostroPerfetto,
      Voto.positivo => TutorialTarget.votoNostroPositivo,
      Voto.mezzoPunto => TutorialTarget.votoNostroMezzoPunto,
      Voto.negativo => TutorialTarget.votoNostroNegativo,
      Voto.errore => TutorialTarget.votoNostroErrore,
    };

TutorialTarget targetVotoAvversario(Voto voto) => switch (voto) {
      Voto.perfetto => TutorialTarget.votoAvvPerfetto,
      Voto.positivo => TutorialTarget.votoAvvPositivo,
      Voto.mezzoPunto => TutorialTarget.votoAvvMezzoPunto,
      Voto.negativo => TutorialTarget.votoAvvNegativo,
      Voto.errore => TutorialTarget.votoAvvErrore,
    };

/// Solo i quattro fondamentali offerti dal nostro pannello in fase libera:
/// battuta e ricezione non passano da lì (le impone la fase).
TutorialTarget? targetFondamentaleNostro(Fondamentale f) => switch (f) {
      Fondamentale.alzata => TutorialTarget.fondNostroAlzata,
      Fondamentale.attacco => TutorialTarget.fondNostroAttacco,
      Fondamentale.muro => TutorialTarget.fondNostroMuro,
      Fondamentale.difesa => TutorialTarget.fondNostroDifesa,
      _ => null,
    };

/// Il pannello avversario offre solo Attacco/Muro/Difesa.
TutorialTarget? targetFondamentaleAvversario(Fondamentale f) => switch (f) {
      Fondamentale.attacco => TutorialTarget.fondAvvAttacco,
      Fondamentale.muro => TutorialTarget.fondAvvMuro,
      Fondamentale.difesa => TutorialTarget.fondAvvDifesa,
      _ => null,
    };

/// Mappa `TutorialTarget -> GlobalKey`, popolata al volo da `_anchor()` in
/// `ScoutScreen` e interrogata dall'overlay per sapere DOVE bucare lo scrim.
///
/// Vive nel `TutorialController` (una sola istanza per sessione di tutorial):
/// le `GlobalKey` devono essere stabili tra un rebuild e l'altro, quindi non
/// vanno mai ricreate dentro un `build()`.
class RegistroTarget {
  final Map<TutorialTarget, GlobalKey> _keys = {};

  GlobalKey keyFor(TutorialTarget target) =>
      _keys.putIfAbsent(target, GlobalKey.new);

  /// Rettangolo del target in **coordinate globali** (schermo), o `null` se il
  /// widget non è montato in questo frame — caso normale e previsto: il
  /// pannello voto esiste solo quando è aperto, il token del battitore solo
  /// quando serviamo noi.
  ///
  /// Il rettangolo si ottiene trasformando quello locale con la matrice fino
  /// alla radice, non come `localToGlobal(Offset.zero) & size`: quest'ultimo
  /// prende l'origine giusta ma la dimensione **prima** di eventuali scale.
  /// I pannelli voto stanno dentro un `FittedBox(scaleDown)` e su schermo
  /// basso sono rimpiccioliti: il buco risultava più grande dei pulsanti e
  /// sbordava.
  Rect? rectOf(TutorialTarget? target) {
    if (target == null) return null;
    final render = _keys[target]?.currentContext?.findRenderObject();
    if (render is! RenderBox || !render.attached || !render.hasSize) {
      return null;
    }
    return MatrixUtils.transformRect(
      render.getTransformTo(null),
      Offset.zero & render.size,
    );
  }

  /// Da chiamare all'avvio di una sessione: due `ScoutScreen(tutorial: true)`
  /// vive insieme collidono sulle stesse GlobalKey.
  void clear() => _keys.clear();
}

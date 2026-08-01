import 'package:flutter/widgets.dart';

/// Elementi di `ScoutScreen` che il tutorial può evidenziare (il "buco" nello
/// scrim) e/o osservare per far avanzare un passo.
///
/// Aggiungere un valore qui NON basta: il widget corrispondente va avvolto in
/// `_anchor(TutorialTarget.xxx, ...)` dentro `scout_screen.dart`, altrimenti
/// `RegistroTarget.rectOf` torna sempre `null` (l'overlay mostra il testo con
/// lo scrim pieno, senza buco).
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

  /// Il pannello voto aperto (card a destra). Usato soprattutto come segnale
  /// di avanzamento: "il passo è finito quando il pannello compare".
  pannelloVoto,

  /// Bottone del voto `+` (positivo) dentro il pannello voto.
  votoPositivo,

  /// Bottone "Attacco" nella scelta del fondamentale (fase libera).
  fondamentaleAttacco,

  /// Hamburger che apre il drawer di utilità.
  bottoneMenu,

  /// Il drawer di utilità aperto.
  drawer,
}

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
  Rect? rectOf(TutorialTarget? target) {
    if (target == null) return null;
    final render = _keys[target]?.currentContext?.findRenderObject();
    if (render is! RenderBox || !render.attached || !render.hasSize) {
      return null;
    }
    return render.localToGlobal(Offset.zero) & render.size;
  }

  /// Da chiamare all'avvio di una sessione: due `ScoutScreen(tutorial: true)`
  /// vive insieme collidono sulle stesse GlobalKey.
  void clear() => _keys.clear();
}

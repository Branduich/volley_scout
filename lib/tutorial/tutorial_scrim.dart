import 'package:flutter/material.dart';

/// Margine attorno al buco: **stesso valore in `paint` e in `hitTestSelf`**,
/// altrimenti l'area tappabile non coincide con quella disegnata. Generoso
/// apposta: i token del campo si muovono con `AnimatedPositioned` (500ms) e
/// l'inseguimento del rect ha un frame di ritardo.
const double kPaddingBuco = 8.0;

/// Velo scuro a tutto schermo con un ritaglio arrotondato attorno al target:
/// **assorbe tutti i tap tranne quelli dentro al buco**, che passano al widget
/// vero sottostante.
///
/// È il meccanismo che permette al tutorial di guidare l'utente senza sparpaglia-
/// re `if (tutorial)` negli handler di `ScoutScreen`: la schermata sotto resta
/// esattamente com'è, è lo scrim a decidere cosa è premibile in questo passo.
///
/// Funziona perché `RenderBox.hitTest` aggiunge il box al risultato solo se
/// `hitTestSelf` torna `true`: in quel caso `RenderStack.defaultHitTestChildren`
/// si ferma qui e nessun figlio sottostante riceve l'evento (stesso meccanismo
/// di `AbsorbPointer`); se torna `false` la ricerca prosegue verso lo `Scaffold`.
class TutorialScrim extends LeafRenderObjectWidget {
  /// Rettangolo del buco in coordinate **globali** (schermo). `null` = nessun
  /// buco: lo scrim copre e blocca tutto (passi puramente informativi).
  final Rect? buco;
  final double raggio;
  final Color colore;

  const TutorialScrim({
    super.key,
    required this.buco,
    this.raggio = 12,
    // ~45% di nero: abbastanza da mettere in risalto il buco, abbastanza poco
    // da continuare a leggere campo e punteggio sotto.
    this.colore = const Color(0x73000000),
  });

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderTutorialScrim(buco, raggio, colore);

  @override
  void updateRenderObject(
      BuildContext context, covariant RenderTutorialScrim renderObject) {
    renderObject
      ..buco = buco
      ..raggio = raggio
      ..colore = colore;
  }
}

class RenderTutorialScrim extends RenderBox {
  RenderTutorialScrim(this._buco, this._raggio, this._colore);

  Rect? _buco;
  double _raggio;
  Color _colore;

  set buco(Rect? value) {
    if (value == _buco) return;
    _buco = value;
    markNeedsPaint();
  }

  set raggio(double value) {
    if (value == _raggio) return;
    _raggio = value;
    markNeedsPaint();
  }

  set colore(Color value) {
    if (value == _colore) return;
    _colore = value;
    markNeedsPaint();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  /// Il buco arriva in coordinate globali: qui serve relativo a questo box.
  Rect? get _bucoLocale {
    final buco = _buco;
    if (buco == null) return null;
    return buco.shift(-localToGlobal(Offset.zero)).inflate(kPaddingBuco);
  }

  // true = "il tap è mio", cioè assorbito. Dentro al buco torno false così
  // l'evento scende al widget reale sotto.
  @override
  bool hitTestSelf(Offset position) {
    final buco = _bucoLocale;
    return buco == null || !buco.contains(position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final pieno = Path()..addRect(offset & size);
    final buco = _bucoLocale?.shift(offset);

    if (buco == null) {
      canvas.drawPath(pieno, Paint()..color = _colore);
      return;
    }

    final rrect = RRect.fromRectAndRadius(buco, Radius.circular(_raggio));
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        pieno,
        Path()..addRRect(rrect),
      ),
      Paint()..color = _colore,
    );
    // Contorno chiaro: dice all'utente "è questo, premilo".
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white,
    );
  }
}

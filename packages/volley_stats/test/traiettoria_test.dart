import 'package:flutter_test/flutter_test.dart';
import 'package:volley_stats/enums.dart';
import 'package:volley_stats/tiro_scout.dart';
import 'package:volley_stats/traiettoria.dart';

/// `normalizzaTiro` non era testabile finché viveva dentro un file di widget
/// (`court_trajectories_view.dart`) ed era riscritta una seconda volta nel PDF.
/// Estratta nel package, questi test valgono per entrambi i disegni — e per la
/// futura dashboard web.
TiroScout _tiro({
  double? x1 = 0.1,
  double? y1 = 0.2,
  double? x2 = 0.8,
  double? y2 = 0.9,
  double? muroX,
  double? muroY,
  String tipoEsecuzione = 'nonSpecificato',
  Voto voto = Voto.positivo,
}) =>
    TiroScout(
      squadra: Squadra.nostra,
      tipo: TipoAzione.scout,
      fondamentale: Fondamentale.attacco,
      voto: voto,
      tipoEsecuzione: tipoEsecuzione,
      x1: x1,
      y1: y1,
      x2: x2,
      y2: y2,
      muroX: muroX,
      muroY: muroY,
    );

void main() {
  test('una traiettoria che parte da sinistra resta com\'è', () {
    final t = normalizzaTiro(_tiro())!;

    expect(t.x1, 0.1);
    expect(t.y1, 0.2);
    expect(t.x2, 0.8);
    expect(t.y2, 0.9);
  });

  test('chi parte da destra viene ribaltato attorno al centro', () {
    // È ciò che permette di confrontare a colpo d'occhio traiettorie battute
    // dai due lati del campo: dopo la normalizzazione partono tutte da sinistra.
    final t = normalizzaTiro(_tiro(x1: 0.9, y1: 0.8, x2: 0.2, y2: 0.1))!;

    expect(t.x1, closeTo(0.1, 1e-9));
    expect(t.y1, closeTo(0.2, 1e-9));
    expect(t.x2, closeTo(0.8, 1e-9));
    expect(t.y2, closeTo(0.9, 1e-9));
  });

  test('il tocco a muro si ribalta insieme al resto', () {
    // Se restasse fermo, lo snodo della freccia finirebbe dall'altra parte
    // della rete rispetto alla traiettoria.
    final t = normalizzaTiro(
        _tiro(x1: 0.9, y1: 0.8, x2: 0.2, y2: 0.1, muroX: 0.5, muroY: 0.3))!;

    expect(t.muroX, closeTo(0.5, 1e-9));
    expect(t.muroY, closeTo(0.7, 1e-9));
  });

  test('senza ribaltamento il muro non si tocca', () {
    final t = normalizzaTiro(_tiro(muroX: 0.5, muroY: 0.3))!;

    expect(t.muroX, 0.5);
    expect(t.muroY, 0.3);
  });

  test('coordinate incomplete: niente traiettoria', () {
    // La stragrande maggioranza delle azioni non ha traiettoria (alzate,
    // difese, muri): devono essere scartate, non disegnate a caso.
    expect(normalizzaTiro(_tiro(x2: null)), isNull);
    expect(normalizzaTiro(_tiro(y1: null)), isNull);
    expect(normalizzaTiro(_tiro(x1: null, y1: null, x2: null, y2: null)),
        isNull);
  });

  test('il pallonetto si riconosce dal tipo di esecuzione', () {
    expect(normalizzaTiro(_tiro())!.isPallonetto, isFalse);
    expect(
      normalizzaTiro(_tiro(tipoEsecuzione: TipoAttacco.pallonetto.name))!
          .isPallonetto,
      isTrue,
    );
  });

  test('il voto viaggia con la traiettoria, il colore no', () {
    // Il package non decide i colori: a video sono Color, nel PDF PdfColor,
    // sul web saranno un'altra palette ancora.
    expect(normalizzaTiro(_tiro(voto: Voto.perfetto))!.voto, Voto.perfetto);
    expect(normalizzaTiro(_tiro(voto: Voto.errore))!.voto, Voto.errore);
  });
}

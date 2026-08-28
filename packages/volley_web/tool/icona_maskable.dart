// Genera le icone **maskable** del sito: il logo rimpicciolito e centrato su
// fondo bianco.
//
//   dart run tool/icona_maskable.dart
//
// Perché a mano e non con flutter_launcher_icons: quel tool, per il web, scrive
// la maskable identica all'icona normale (stessi byte). Ma una maskable viene
// ritagliata dal sistema con una maschera propria — su Android un cerchio — e
// garantita è solo la "zona sicura", un cerchio dell'80% del lato. Il nostro
// logo riempie quasi tutta la tela: installata, perderebbe i fianchi del
// pallone e gli angoli della base.
//
// Qui il logo sta dentro il [_fattore] del lato, quindi resta intero sotto
// qualunque maschera. Sorgente: la versione TRASPARENTE del logo, così il fondo
// bianco è uniforme e non si vedono due bianchi diversi.
import 'dart:io';

import 'package:image/image.dart';

/// Quanto del lato occupa il logo. 0,66 sta comodamente dentro la zona sicura
/// (0,80) lasciando un margine anche alle maschere più aggressive.
const double _fattore = 0.66;

const _sorgente = '../../assets/icon/icon_foreground.png';

void main() {
  final originale = decodePng(File(_sorgente).readAsBytesSync());
  if (originale == null) {
    stderr.writeln('Non riesco a leggere $_sorgente');
    exit(1);
  }

  for (final lato in const [192, 512]) {
    final logo = copyResize(
      originale,
      width: (lato * _fattore).round(),
      height: (lato * _fattore).round(),
      interpolation: Interpolation.cubic,
    );
    final tela = Image(width: lato, height: lato, numChannels: 4)
      ..clear(ColorRgba8(255, 255, 255, 255));
    compositeImage(
      tela,
      logo,
      dstX: ((lato - logo.width) / 2).round(),
      dstY: ((lato - logo.height) / 2).round(),
    );
    final fuori = File('web/icons/Icon-maskable-$lato.png');
    fuori.writeAsBytesSync(encodePng(tela));
    stdout.writeln('scritta ${fuori.path} (${lato}x$lato, logo al '
        '${(_fattore * 100).round()}%)');
  }
}

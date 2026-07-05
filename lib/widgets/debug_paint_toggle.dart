import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show debugPaintSizeEnabled;

/// Bottone (solo `kDebugMode`) che alterna `debugPaintSizeEnabled`, il flag
/// GLOBALE di Flutter che disegna i bordi di ogni render box (celle, padding,
/// baseline del testo). Essendo globale, una volta acceso da qualunque
/// schermata TUTTE le pagine mostrano i bordi finché non lo si rispegne.
/// Usato in Home (interruttore globale, persistente attraverso la
/// navigazione) e nell'AppBar del Report (check veloce lì): le due icone
/// restano sempre coerenti perché leggono lo stesso flag. In release non
/// disegna nulla (`SizedBox.shrink`).
class DebugPaintToggle extends StatefulWidget {
  const DebugPaintToggle({super.key});

  @override
  State<DebugPaintToggle> createState() => _DebugPaintToggleState();
}

class _DebugPaintToggleState extends State<DebugPaintToggle> {
  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Debug: bordi di layout',
      icon: Icon(debugPaintSizeEnabled ? Icons.grid_on : Icons.grid_off),
      onPressed: () {
        debugPaintSizeEnabled = !debugPaintSizeEnabled;
        // Il flag è letto a ogni paint: cambiarlo non basta, serve
        // ridisegnare l'intero albero (lo stesso meccanismo dell'hot
        // reload). setState aggiorna subito l'icona di questo bottone.
        setState(() {});
        WidgetsBinding.instance.reassembleApplication();
      },
    );
  }
}

/// Il campo con le traiettorie vive in `packages/volley_ui` (passo 12): lo
/// disegnano identico l'app e la dashboard web, e due copie divergerebbero.
///
/// Qui resta l'unico pezzo che è dell'app: la conversione da **riga drift** a
/// tipo neutro. Il package non conosce il database — è la stessa separazione
/// per cui `TiroScout` esiste.
library;

import 'package:volley_stats/tiro_scout.dart';
import 'package:volley_ui/campo_traiettorie.dart';

import '../data/database.dart';
import '../logic/heatmap.dart' show tiroDaRiga;

export 'package:volley_ui/campo_traiettorie.dart';

/// Converte una [ScoutAction] con traiettoria in [TrajData]. Presuppone che le
/// quattro coordinate `traiettoria*` siano non-null (filtrare prima con il
/// controllo su X1/Y1/X2/Y2).
TrajData buildTrajData(ScoutAction a) => trajDataDaTiro(tiroDaRiga(a));

/// Il tiro neutro di una riga, per chi deve passarlo al package.
TiroScout tiroDaScoutAction(ScoutAction a) => tiroDaRiga(a);

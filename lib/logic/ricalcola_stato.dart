/// Vive in `packages/volley_stats` (passo 5.2 del piano in
/// docs/dati-stagionali.md): è una funzione pura sugli eventi di uno set —
/// niente DB, niente UI — e la dashboard web ricalcolerà i punteggi con lo
/// stesso codice che gira nell'app. Ri-esportazione per non toccare i call-site.
library;

export 'package:volley_stats/ricalcola_stato.dart';

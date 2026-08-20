/// I DTO del backup vivono in `packages/volley_stats` (passo 5.1 del piano in
/// docs/dati-stagionali.md): sono puri per costruzione — nessun drift, nessun
/// riverpod — e la dashboard web li userà così come sono.
///
/// Ri-esportazione, per non toccare i call-site nell'app. La conversione da e
/// verso le righe drift resta invece in `backup_json.dart`, che è codice
/// dell'app e lì deve restare.
library;

export 'package:volley_stats/backup_model.dart';

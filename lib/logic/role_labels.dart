/// Adapter verso `packages/volley_stats/lib/role_labels.dart` (passo 5.3 del
/// piano in docs/dati-stagionali.md).
///
/// Nel package la funzione prende una mappa **slot → Ruolo**, perché è tutto
/// ciò che legge davvero e perché `Player` è una riga drift, che sul web non
/// esiste. Qui restano wrapper con la **firma di prima**, così i call-site
/// (`scout_screen`, `formation_config_screen`, `database_provider`, i report)
/// non cambiano di una riga: si sposta il file, non i suoi quaranta usi.
library;

import 'package:volley_stats/role_labels.dart' as stats;

import '../data/database.dart';
import '../models/enums.dart';

export 'package:volley_stats/role_labels.dart'
    show kSlotOrder, etichetteAvversarie;

Map<String, Ruolo> _ruoliPerSlot(Map<String, Player> assignments) => {
      for (final e in assignments.entries) e.key: e.value.ruolo,
    };

/// Vedi `stats.roleLabelsFor`: qui cambia solo il tipo in ingresso.
Map<String, String> roleLabelsFor(
        String palleggiatoreSlot, Map<String, Player> assignments) =>
    stats.roleLabelsFor(palleggiatoreSlot, _ruoliPerSlot(assignments));

/// Vedi `stats.roleLabelsFor62`: qui cambia solo il tipo in ingresso.
Map<String, String> roleLabelsFor62(
        String riferimentoSlot, Map<String, Player> assignments) =>
    stats.roleLabelsFor62(riferimentoSlot, _ruoliPerSlot(assignments));

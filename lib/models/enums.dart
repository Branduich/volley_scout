/// Gli enum del dominio vivono in `packages/volley_stats` (passo 5 del piano in
/// docs/dati-stagionali.md): sono Dart puro e servono identici all'app e alla
/// dashboard web.
///
/// Questo file resta come **ri-esportazione**: i ~45 file che fanno
/// `import '../models/enums.dart'` continuano a funzionare senza modifiche.
/// È la tecnica che rende economico spostare il codice condiviso — si sposta il
/// file, non i suoi quaranta call-site.
library;

export 'package:volley_stats/enums.dart';

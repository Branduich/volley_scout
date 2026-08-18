import 'dart:math';

/// Identificatore stabile di una riga, indipendente dall'`id` autoincrement
/// del database locale.
///
/// Serve al backup/ripristino e alla dashboard stagionale: gli `id` drift sono
/// numeri progressivi **di questo device**, quindi due export presi da tablet
/// diversi userebbero gli stessi numeri per righe diverse, e reimportare un
/// backup non sarebbe idempotente. L'alternativa "chiave naturale"
/// (`cognome|nome|numero`) fallisce su rinomine, omonime e cambi di maglia.
///
/// Formato: 32 caratteri esadecimali minuscoli (16 byte casuali) — lo stesso
/// che produce `lower(hex(randomblob(16)))` in SQLite, usato dalla migrazione
/// v19 per riempire le righe già esistenti. Nessuna dipendenza nuova: il
/// package `uuid` non aggiungerebbe nulla, qui non serve la struttura di uno
/// UUID (versione, varianti), solo unicità.
///
/// `Random.secure()` invece di `Random()`: non è una questione di segretezza ma
/// di collisioni — un generatore seminato sull'orologio, su due dispositivi
/// avviati insieme, può produrre la stessa sequenza.
String nuovoUid() {
  final rnd = Random.secure();
  final buffer = StringBuffer();
  for (var i = 0; i < 16; i++) {
    buffer.write(rnd.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volley_scout/theme/app_colors.dart';
import 'package:volley_scout/widgets/certificato_dot.dart';

void main() {
  // Data fissa per test deterministici (l'ora non deve contare).
  final oggi = DateTime(2026, 7, 10, 15, 30);

  Color? colore(DateTime? scadenza) =>
      coloreScadenzaCertificato(scadenza, oggi: oggi);

  group('coloreScadenzaCertificato', () {
    test('nessuna scadenza -> nessun pallino', () {
      expect(colore(null), isNull);
    });

    test('già scaduto -> rosso', () {
      expect(colore(DateTime(2026, 6, 1)), Colors.red);
      expect(colore(DateTime(2026, 7, 9)), Colors.red);
    });

    test('scade oggi -> rosso', () {
      expect(colore(DateTime(2026, 7, 10)), Colors.red);
    });

    test('meno di 8 giorni -> rosso (7 giorni è l\'ultimo rosso)', () {
      expect(colore(DateTime(2026, 7, 17)), Colors.red);
    });

    test('8 giorni esatti -> giallo', () {
      expect(colore(DateTime(2026, 7, 18)), AppColors.warning);
    });

    test('meno di 30 giorni -> giallo (29 giorni è l\'ultimo giallo)', () {
      expect(colore(DateTime(2026, 8, 8)), AppColors.warning);
    });

    test('30 giorni esatti -> verde', () {
      expect(colore(DateTime(2026, 8, 9)), AppColors.success);
    });

    test('scadenza lontana -> verde', () {
      expect(colore(DateTime(2027, 1, 1)), AppColors.success);
    });

    test('l\'ora del giorno non conta (confronto per data pura)', () {
      // Scadenza a mezzanotte di domani+7: mancano 8 giorni pieni -> giallo,
      // anche se "oggi" ha un orario pomeridiano.
      expect(
        coloreScadenzaCertificato(DateTime(2026, 7, 18, 0, 0),
            oggi: DateTime(2026, 7, 10, 23, 59)),
        AppColors.warning,
      );
    });
  });
}

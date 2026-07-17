import 'package:shared_preferences/shared_preferences.dart';

import '../models/enums.dart';
import 'database.dart';

// Categorie di default seminate alla PRIMA apertura (schema v13): la lista
// parte dai valori storici dell'enum Categoria, poi l'utente la personalizza
// in CategorieScreen (aggiungi/rinomina/elimina/riordina). L'enum resta solo
// come sorgente di questi default — le squadre salvano il NOME della categoria
// come testo, non un riferimento all'enum (vedi database.dart).
//
// Seed UNA VOLTA SOLA (flag persistito): se l'utente svuota o riduce la lista,
// non ricompare al riavvio. La condizione "tabella vuota" copre sia
// l'installazione pulita (onCreate) sia l'aggiornamento da <v13 (la migrazione
// crea la tabella vuota, il seeder la riempie).
const String _kSeededKey = 'db.defaultCategorieSeeded';

Future<void> seedDefaultCategorieSeNecessario(
    AppDatabase db, SharedPreferences prefs) async {
  if (prefs.getBool(_kSeededKey) ?? false) return;
  final esistenti = await db.select(db.categorie).get();
  if (esistenti.isEmpty) {
    await db.batch((b) {
      for (var i = 0; i < Categoria.values.length; i++) {
        b.insert(
          db.categorie,
          CategorieCompanion.insert(
            nome: Categoria.values[i].label,
            ordine: i,
          ),
        );
      }
    });
  }
  await prefs.setBool(_kSeededKey, true);
}

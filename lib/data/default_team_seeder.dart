import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/enums.dart';
import 'database.dart';

// Squadra di default pre-caricata al PRIMO avvio, così i tester non devono
// crearne una da zero (vedi docs/TODO_strada_A.md — fase closed testing).
// Seed UNA VOLTA SOLA: un flag persistito evita che ricompaia se il tester
// la cancella o la modifica. Squadra editabile/eliminabile come le altre.
// Nota: conta come "la partita/squadra gratis" del gate free — un tester
// free che vuole la SUA squadra cancella prima questa (il gate consente
// sempre di scendere a una).
const String _kSeededKey = 'db.defaultTeamSeeded';

/// Se non già fatto, inserisce la squadra "Volley Star" col suo roster.
/// Idempotente: al secondo avvio (flag settato) non fa nulla; se il DB ha
/// già squadre (es. aggiornamento da una versione pre-seeding) salta
/// l'inserimento ma segna il flag, per non toccare i dati esistenti.
Future<void> seedDefaultTeamSeNecessario(
    AppDatabase db, SharedPreferences prefs) async {
  if (prefs.getBool(_kSeededKey) ?? false) return;
  final esistenti = await db.select(db.teams).get();
  if (esistenti.isEmpty) {
    await _seed(db);
  }
  await prefs.setBool(_kSeededKey, true);
}

Future<void> _seed(AppDatabase db) async {
  final teamId = await db.into(db.teams).insert(
        TeamsCompanion.insert(
          // Categoria ora è testo libero (nome della categoria): deve
          // combaciare con una voce seminata da default_categorie_seeder.
          nome: 'Volley Star',
          categoria: Categoria.primaDivisione.label,
          coloreDivisa: 0xFFD32F2F, // rosso (jerseyPalette "Rosso")
        ),
      );

  final now = DateTime.now();
  // Qualche scadenza certificato per far vedere anche i pallini di stato
  // (rosso <8gg, giallo <30, verde altrimenti). Relative all'installazione.
  DateTime? cert(int? giorni) =>
      giorni == null ? null : now.add(Duration(days: giorni));

  // (numero, cognome, nome, ruolo, giorniAllaScadenzaCertificato)
  // Roster bilanciato: 2 P, 2 O, 3 S, 3 C, 2 L — nomi "a tema" per sdrammatizzare.
  const giocatori = <(int, String, String, Ruolo, int?)>[
    (1, 'Alzabene', 'Tore', Ruolo.palleggiatore, 300), // verde
    (6, 'Manidoro', 'Marco', Ruolo.palleggiatore, null),
    (4, 'Bomber', 'Bruno', Ruolo.opposto, 5), // rosso
    (10, 'Martello', 'Diego', Ruolo.opposto, null),
    (7, 'Bordata', 'Ivan', Ruolo.schiacciatore, null),
    (8, 'Schiaccia', 'Luca', Ruolo.schiacciatore, null),
    (11, 'Pipe', 'Max', Ruolo.schiacciatore, null),
    (3, 'Muraglia', 'Furio', Ruolo.centrale, 20), // giallo
    (5, 'Primotempo', 'Nino', Ruolo.centrale, null),
    (9, 'Blocco', 'Gino', Ruolo.centrale, null),
    (2, 'Rasoterra', 'Remo', Ruolo.libero, null),
    (12, 'Salvatutto', 'Sandro', Ruolo.libero, null),
  ];

  for (final (numero, cognome, nome, ruolo, giorniCert) in giocatori) {
    await db.into(db.players).insert(
          PlayersCompanion.insert(
            teamId: teamId,
            nome: nome,
            cognome: cognome,
            numero: numero,
            ruolo: ruolo,
            scadenzaCertificato: Value(cert(giorniCert)),
          ),
        );
  }
}

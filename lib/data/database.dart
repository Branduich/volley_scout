import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/enums.dart';

part 'database.g.dart';

// --- Convertitori enum <-> testo nel DB ---
class CategoriaConverter extends TypeConverter<Categoria, String> {
  const CategoriaConverter();
  @override
  Categoria fromSql(String fromDb) => Categoria.values.byName(fromDb);
  @override
  String toSql(Categoria value) => value.name;
}

class RuoloConverter extends TypeConverter<Ruolo, String> {
  const RuoloConverter();
  @override
  Ruolo fromSql(String fromDb) => Ruolo.values.byName(fromDb);
  @override
  String toSql(Ruolo value) => value.name;
}

class StatoPartitaConverter extends TypeConverter<StatoPartita, String> {
  const StatoPartitaConverter();
  @override
  StatoPartita fromSql(String fromDb) => StatoPartita.values.byName(fromDb);
  @override
  String toSql(StatoPartita value) => value.name;
}

class SquadraConverter extends TypeConverter<Squadra, String> {
  const SquadraConverter();
  @override
  Squadra fromSql(String fromDb) => Squadra.values.byName(fromDb);
  @override
  String toSql(Squadra value) => value.name;
}

class TipoAzioneConverter extends TypeConverter<TipoAzione, String> {
  const TipoAzioneConverter();
  @override
  TipoAzione fromSql(String fromDb) => TipoAzione.values.byName(fromDb);
  @override
  String toSql(TipoAzione value) => value.name;
}

class FondamentaleConverter extends TypeConverter<Fondamentale, String> {
  const FondamentaleConverter();
  @override
  Fondamentale fromSql(String fromDb) => Fondamentale.values.byName(fromDb);
  @override
  String toSql(Fondamentale value) => value.name;
}

class VotoConverter extends TypeConverter<Voto, String> {
  const VotoConverter();
  @override
  Voto fromSql(String fromDb) => Voto.values.byName(fromDb);
  @override
  String toSql(Voto value) => value.name;
}

class EsitoPuntoConverter extends TypeConverter<EsitoPunto, String> {
  const EsitoPuntoConverter();
  @override
  EsitoPunto fromSql(String fromDb) => EsitoPunto.values.byName(fromDb);
  @override
  String toSql(EsitoPunto value) => value.name;
}

// --- Tabelle ---
class Teams extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nome => text().withLength(min: 1, max: 100)();
  TextColumn get categoria => text().map(const CategoriaConverter())();
  IntColumn get coloreDivisa => integer()(); // valore ARGB del colore
}

class Players extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get teamId =>
      integer().references(Teams, #id, onDelete: KeyAction.cascade)();
  TextColumn get nome => text().withLength(min: 1, max: 50)();
  TextColumn get cognome => text().withLength(min: 1, max: 50)();
  IntColumn get numero => integer()();
  TextColumn get ruolo => text().map(const RuoloConverter())();
  DateTimeColumn get scadenzaCertificato => dateTime().nullable()();
}

@DataClassName('VolleyMatch')
class VolleyMatches extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nome => text().withLength(min: 1, max: 100)();
  DateTimeColumn get dataOra => dateTime()();
  BoolColumn get inCasa => boolean()();
  TextColumn get palestra => text().nullable()();
  TextColumn get avversario => text().nullable()();
  IntColumn get teamId => integer()
      .nullable()
      .references(Teams, #id, onDelete: KeyAction.setNull)();
  RealColumn get lat => real().nullable()();
  RealColumn get lon => real().nullable()();
  TextColumn get stato => text().map(const StatoPartitaConverter())();
  IntColumn get setCorrente => integer()();
}

class MatchSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get matchId =>
      integer().references(VolleyMatches, #id, onDelete: KeyAction.cascade)();
  IntColumn get numero => integer()();
  BoolColumn get aperto => boolean().withDefault(const Constant(true))();
  // Chi serve per primo in questo set — input necessario a ricalcolaStato(),
  // non derivabile dagli eventi (scelto fuori dal gioco).
  TextColumn get squadraServizioIniziale =>
      text().map(const SquadraConverter())();
  // Libero(i) e coppia sostituita nella formazione iniziale di questo set
  // (null se non c'è libero) — non hanno una posizione di rotazione, quindi
  // non sono in Rotations. Persistiti per poter ricostruire
  // assignments/palleggiatoreSlot/ruoloCambiLibero quando si riprende lo
  // scout di un set già iniziato, bypassando LineupScreen/
  // FormationConfigScreen — vedi MatchSetRepository.caricaFormazione().
  @ReferenceName('matchSetsComeLibero1')
  IntColumn get liberoId => integer()
      .nullable()
      .references(Players, #id, onDelete: KeyAction.setNull)();
  @ReferenceName('matchSetsComeLibero2')
  IntColumn get libero2Id => integer()
      .nullable()
      .references(Players, #id, onDelete: KeyAction.setNull)();
  TextColumn get ruoloCambiLibero =>
      text().nullable().map(const RuoloConverter())();
  // Override manuale del punteggio (per errori di scout/segnapunti — vale
  // la situazione reale in campo): si somma al punteggio calcolato da
  // ricalcolaStato() per ottenere il valore mostrato in UI, NON è loggato
  // come ScoutAction (decisione esplicita: fine set/match sono già
  // decisioni manuali, non serve restare fedeli al log eventi per il
  // punteggio). Vedi ScoutScreen._correggiPunteggio().
  IntColumn get correzionePuntiNostri =>
      integer().withDefault(const Constant(0))();
  IntColumn get correzionePuntiAvversari =>
      integer().withDefault(const Constant(0))();
}

class Rotations extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get setId =>
      integer().references(MatchSets, #id, onDelete: KeyAction.cascade)();
  TextColumn get squadra => text().map(const SquadraConverter())();
  IntColumn get posizione => integer()(); // 1-6, 1 = battitore
  IntColumn get giocatoreId =>
      integer().references(Players, #id, onDelete: KeyAction.cascade)();
}

class ScoutActions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get setId =>
      integer().references(MatchSets, #id, onDelete: KeyAction.cascade)();
  IntColumn get rallyId => integer()(); // raggruppa le azioni di uno scambio
  IntColumn get ordine => integer()(); // progressivo nel set, per undo
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get squadra => text().map(const SquadraConverter())();
  TextColumn get tipo => text().map(const TipoAzioneConverter())();
  IntColumn get giocatoreId => integer()
      .nullable()
      .references(Players, #id, onDelete: KeyAction.setNull)();
  TextColumn get fondamentale =>
      text().nullable().map(const FondamentaleConverter())();
  TextColumn get voto => text().nullable().map(const VotoConverter())();
  // Colonna "polimorfica": .name di TipoAttacco o TipoBattuta in base a
  // fondamentale — coerenza garantita dall'interfaccia, non dallo schema.
  TextColumn get tipoEsecuzione =>
      text().withDefault(const Constant('nonSpecificato'))();
  TextColumn get esitoPunto => text().map(const EsitoPuntoConverter())();
  RealColumn get traiettoriaX1 => real().nullable()();
  RealColumn get traiettoriaY1 => real().nullable()();
  RealColumn get traiettoriaX2 => real().nullable()();
  RealColumn get traiettoriaY2 => real().nullable()();
  // Punto di tocco a muro (solo attacco, opzionale — null se la traiettoria
  // non ha incrociato la rete durante il drag) — vedi TrajectoryScreen.
  RealColumn get traiettoriaMuroX => real().nullable()();
  RealColumn get traiettoriaMuroY => real().nullable()();
  IntColumn get puntiCasaAlMomento => integer().nullable()();
  IntColumn get puntiOspitiAlMomento => integer().nullable()();
}

// --- Database ---
@DriftDatabase(tables: [
  Teams,
  Players,
  VolleyMatches,
  MatchSets,
  Rotations,
  ScoutActions,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 10;

  // Le ALTER TABLE/CREATE TABLE in onUpgrade NON sono atomiche (un fallimento
  // a metà migrazione lascia i passi precedenti già committati, ma senza che
  // schemaVersion salga): ogni passo qui sotto controlla quindi se è già
  // stato applicato prima di rieseguirlo, così un retry dopo un fallimento
  // parziale converge sempre, invece di rompersi su "duplicate column".
  Future<bool> _hasColumn(String table, String column) async {
    final righe = await customSelect('PRAGMA table_info($table)').get();
    return righe.any((r) => r.data['name'] == column);
  }

  Future<bool> _hasTable(String table) async {
    final righe = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      variables: [Variable.withString(table)],
    ).get();
    return righe.isNotEmpty;
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2 && !await _hasTable('volley_matches')) {
            await m.createTable(volleyMatches);
          }
          if (from < 3) {
            if (!await _hasColumn('volley_matches', 'lat')) {
              await customStatement(
                  'ALTER TABLE volley_matches ADD COLUMN lat REAL');
            }
            if (!await _hasColumn('volley_matches', 'lon')) {
              await customStatement(
                  'ALTER TABLE volley_matches ADD COLUMN lon REAL');
            }
          }
          if (from < 4 &&
              !await _hasColumn('players', 'scadenza_certificato')) {
            await customStatement(
                'ALTER TABLE players ADD COLUMN scadenza_certificato INTEGER');
          }
          if (from < 5 && !await _hasColumn('volley_matches', 'avversario')) {
            await customStatement(
                'ALTER TABLE volley_matches ADD COLUMN avversario TEXT');
          }
          if (from < 6) {
            if (!await _hasColumn('volley_matches', 'stato')) {
              await customStatement(
                  "ALTER TABLE volley_matches ADD COLUMN stato TEXT NOT NULL "
                  "DEFAULT 'configurazione'");
            }
            if (!await _hasColumn('volley_matches', 'set_corrente')) {
              await customStatement(
                  'ALTER TABLE volley_matches ADD COLUMN set_corrente '
                  'INTEGER NOT NULL DEFAULT 1');
            }
            if (!await _hasTable('match_sets')) {
              await m.createTable(matchSets);
            }
            if (!await _hasTable('rotations')) {
              await m.createTable(rotations);
            }
            if (!await _hasTable('scout_actions')) {
              await m.createTable(scoutActions);
            }
          }
          if (from < 7 &&
              !await _hasColumn('match_sets', 'squadra_servizio_iniziale')) {
            await customStatement(
                'ALTER TABLE match_sets ADD COLUMN '
                "squadra_servizio_iniziale TEXT NOT NULL DEFAULT 'nostra'");
          }
          if (from < 8) {
            if (!await _hasColumn('match_sets', 'libero_id')) {
              await customStatement('ALTER TABLE match_sets ADD COLUMN '
                  'libero_id INTEGER REFERENCES players (id)');
            }
            if (!await _hasColumn('match_sets', 'libero2_id')) {
              await customStatement('ALTER TABLE match_sets ADD COLUMN '
                  'libero2_id INTEGER REFERENCES players (id)');
            }
            if (!await _hasColumn('match_sets', 'ruolo_cambi_libero')) {
              await customStatement(
                  'ALTER TABLE match_sets ADD COLUMN ruolo_cambi_libero TEXT');
            }
          }
          if (from < 9) {
            if (!await _hasColumn('match_sets', 'correzione_punti_nostri')) {
              await customStatement(
                  'ALTER TABLE match_sets ADD COLUMN correzione_punti_nostri '
                  'INTEGER NOT NULL DEFAULT 0');
            }
            if (!await _hasColumn('match_sets', 'correzione_punti_avversari')) {
              await customStatement(
                  'ALTER TABLE match_sets ADD COLUMN '
                  'correzione_punti_avversari INTEGER NOT NULL DEFAULT 0');
            }
          }
          if (from < 10) {
            if (!await _hasColumn('scout_actions', 'traiettoria_muro_x')) {
              await customStatement('ALTER TABLE scout_actions ADD COLUMN '
                  'traiettoria_muro_x REAL');
            }
            if (!await _hasColumn('scout_actions', 'traiettoria_muro_y')) {
              await customStatement('ALTER TABLE scout_actions ADD COLUMN '
                  'traiettoria_muro_y REAL');
            }
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'volley_scout.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
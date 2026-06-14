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
}

// --- Database ---
@DriftDatabase(tables: [Teams, Players])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          // Abilita le foreign key (necessario per il cascade delete)
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
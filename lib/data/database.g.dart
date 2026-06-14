// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $TeamsTable extends Teams with TableInfo<$TeamsTable, Team> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TeamsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nomeMeta = const VerificationMeta('nome');
  @override
  late final GeneratedColumn<String> nome = GeneratedColumn<String>(
    'nome',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Categoria, String> categoria =
      GeneratedColumn<String>(
        'categoria',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Categoria>($TeamsTable.$convertercategoria);
  static const VerificationMeta _coloreDivisaMeta = const VerificationMeta(
    'coloreDivisa',
  );
  @override
  late final GeneratedColumn<int> coloreDivisa = GeneratedColumn<int>(
    'colore_divisa',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, nome, categoria, coloreDivisa];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'teams';
  @override
  VerificationContext validateIntegrity(
    Insertable<Team> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('nome')) {
      context.handle(
        _nomeMeta,
        nome.isAcceptableOrUnknown(data['nome']!, _nomeMeta),
      );
    } else if (isInserting) {
      context.missing(_nomeMeta);
    }
    if (data.containsKey('colore_divisa')) {
      context.handle(
        _coloreDivisaMeta,
        coloreDivisa.isAcceptableOrUnknown(
          data['colore_divisa']!,
          _coloreDivisaMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_coloreDivisaMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Team map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Team(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      nome: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nome'],
      )!,
      categoria: $TeamsTable.$convertercategoria.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}categoria'],
        )!,
      ),
      coloreDivisa: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}colore_divisa'],
      )!,
    );
  }

  @override
  $TeamsTable createAlias(String alias) {
    return $TeamsTable(attachedDatabase, alias);
  }

  static TypeConverter<Categoria, String> $convertercategoria =
      const CategoriaConverter();
}

class Team extends DataClass implements Insertable<Team> {
  final int id;
  final String nome;
  final Categoria categoria;
  final int coloreDivisa;
  const Team({
    required this.id,
    required this.nome,
    required this.categoria,
    required this.coloreDivisa,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['nome'] = Variable<String>(nome);
    {
      map['categoria'] = Variable<String>(
        $TeamsTable.$convertercategoria.toSql(categoria),
      );
    }
    map['colore_divisa'] = Variable<int>(coloreDivisa);
    return map;
  }

  TeamsCompanion toCompanion(bool nullToAbsent) {
    return TeamsCompanion(
      id: Value(id),
      nome: Value(nome),
      categoria: Value(categoria),
      coloreDivisa: Value(coloreDivisa),
    );
  }

  factory Team.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Team(
      id: serializer.fromJson<int>(json['id']),
      nome: serializer.fromJson<String>(json['nome']),
      categoria: serializer.fromJson<Categoria>(json['categoria']),
      coloreDivisa: serializer.fromJson<int>(json['coloreDivisa']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'nome': serializer.toJson<String>(nome),
      'categoria': serializer.toJson<Categoria>(categoria),
      'coloreDivisa': serializer.toJson<int>(coloreDivisa),
    };
  }

  Team copyWith({
    int? id,
    String? nome,
    Categoria? categoria,
    int? coloreDivisa,
  }) => Team(
    id: id ?? this.id,
    nome: nome ?? this.nome,
    categoria: categoria ?? this.categoria,
    coloreDivisa: coloreDivisa ?? this.coloreDivisa,
  );
  Team copyWithCompanion(TeamsCompanion data) {
    return Team(
      id: data.id.present ? data.id.value : this.id,
      nome: data.nome.present ? data.nome.value : this.nome,
      categoria: data.categoria.present ? data.categoria.value : this.categoria,
      coloreDivisa: data.coloreDivisa.present
          ? data.coloreDivisa.value
          : this.coloreDivisa,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Team(')
          ..write('id: $id, ')
          ..write('nome: $nome, ')
          ..write('categoria: $categoria, ')
          ..write('coloreDivisa: $coloreDivisa')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, nome, categoria, coloreDivisa);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Team &&
          other.id == this.id &&
          other.nome == this.nome &&
          other.categoria == this.categoria &&
          other.coloreDivisa == this.coloreDivisa);
}

class TeamsCompanion extends UpdateCompanion<Team> {
  final Value<int> id;
  final Value<String> nome;
  final Value<Categoria> categoria;
  final Value<int> coloreDivisa;
  const TeamsCompanion({
    this.id = const Value.absent(),
    this.nome = const Value.absent(),
    this.categoria = const Value.absent(),
    this.coloreDivisa = const Value.absent(),
  });
  TeamsCompanion.insert({
    this.id = const Value.absent(),
    required String nome,
    required Categoria categoria,
    required int coloreDivisa,
  }) : nome = Value(nome),
       categoria = Value(categoria),
       coloreDivisa = Value(coloreDivisa);
  static Insertable<Team> custom({
    Expression<int>? id,
    Expression<String>? nome,
    Expression<String>? categoria,
    Expression<int>? coloreDivisa,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nome != null) 'nome': nome,
      if (categoria != null) 'categoria': categoria,
      if (coloreDivisa != null) 'colore_divisa': coloreDivisa,
    });
  }

  TeamsCompanion copyWith({
    Value<int>? id,
    Value<String>? nome,
    Value<Categoria>? categoria,
    Value<int>? coloreDivisa,
  }) {
    return TeamsCompanion(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      categoria: categoria ?? this.categoria,
      coloreDivisa: coloreDivisa ?? this.coloreDivisa,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (nome.present) {
      map['nome'] = Variable<String>(nome.value);
    }
    if (categoria.present) {
      map['categoria'] = Variable<String>(
        $TeamsTable.$convertercategoria.toSql(categoria.value),
      );
    }
    if (coloreDivisa.present) {
      map['colore_divisa'] = Variable<int>(coloreDivisa.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TeamsCompanion(')
          ..write('id: $id, ')
          ..write('nome: $nome, ')
          ..write('categoria: $categoria, ')
          ..write('coloreDivisa: $coloreDivisa')
          ..write(')'))
        .toString();
  }
}

class $PlayersTable extends Players with TableInfo<$PlayersTable, Player> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlayersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _teamIdMeta = const VerificationMeta('teamId');
  @override
  late final GeneratedColumn<int> teamId = GeneratedColumn<int>(
    'team_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES teams (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nomeMeta = const VerificationMeta('nome');
  @override
  late final GeneratedColumn<String> nome = GeneratedColumn<String>(
    'nome',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 50,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cognomeMeta = const VerificationMeta(
    'cognome',
  );
  @override
  late final GeneratedColumn<String> cognome = GeneratedColumn<String>(
    'cognome',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 50,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _numeroMeta = const VerificationMeta('numero');
  @override
  late final GeneratedColumn<int> numero = GeneratedColumn<int>(
    'numero',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Ruolo, String> ruolo =
      GeneratedColumn<String>(
        'ruolo',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Ruolo>($PlayersTable.$converterruolo);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    teamId,
    nome,
    cognome,
    numero,
    ruolo,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'players';
  @override
  VerificationContext validateIntegrity(
    Insertable<Player> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('team_id')) {
      context.handle(
        _teamIdMeta,
        teamId.isAcceptableOrUnknown(data['team_id']!, _teamIdMeta),
      );
    } else if (isInserting) {
      context.missing(_teamIdMeta);
    }
    if (data.containsKey('nome')) {
      context.handle(
        _nomeMeta,
        nome.isAcceptableOrUnknown(data['nome']!, _nomeMeta),
      );
    } else if (isInserting) {
      context.missing(_nomeMeta);
    }
    if (data.containsKey('cognome')) {
      context.handle(
        _cognomeMeta,
        cognome.isAcceptableOrUnknown(data['cognome']!, _cognomeMeta),
      );
    } else if (isInserting) {
      context.missing(_cognomeMeta);
    }
    if (data.containsKey('numero')) {
      context.handle(
        _numeroMeta,
        numero.isAcceptableOrUnknown(data['numero']!, _numeroMeta),
      );
    } else if (isInserting) {
      context.missing(_numeroMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Player map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Player(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      teamId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}team_id'],
      )!,
      nome: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nome'],
      )!,
      cognome: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cognome'],
      )!,
      numero: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}numero'],
      )!,
      ruolo: $PlayersTable.$converterruolo.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}ruolo'],
        )!,
      ),
    );
  }

  @override
  $PlayersTable createAlias(String alias) {
    return $PlayersTable(attachedDatabase, alias);
  }

  static TypeConverter<Ruolo, String> $converterruolo = const RuoloConverter();
}

class Player extends DataClass implements Insertable<Player> {
  final int id;
  final int teamId;
  final String nome;
  final String cognome;
  final int numero;
  final Ruolo ruolo;
  const Player({
    required this.id,
    required this.teamId,
    required this.nome,
    required this.cognome,
    required this.numero,
    required this.ruolo,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['team_id'] = Variable<int>(teamId);
    map['nome'] = Variable<String>(nome);
    map['cognome'] = Variable<String>(cognome);
    map['numero'] = Variable<int>(numero);
    {
      map['ruolo'] = Variable<String>(
        $PlayersTable.$converterruolo.toSql(ruolo),
      );
    }
    return map;
  }

  PlayersCompanion toCompanion(bool nullToAbsent) {
    return PlayersCompanion(
      id: Value(id),
      teamId: Value(teamId),
      nome: Value(nome),
      cognome: Value(cognome),
      numero: Value(numero),
      ruolo: Value(ruolo),
    );
  }

  factory Player.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Player(
      id: serializer.fromJson<int>(json['id']),
      teamId: serializer.fromJson<int>(json['teamId']),
      nome: serializer.fromJson<String>(json['nome']),
      cognome: serializer.fromJson<String>(json['cognome']),
      numero: serializer.fromJson<int>(json['numero']),
      ruolo: serializer.fromJson<Ruolo>(json['ruolo']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'teamId': serializer.toJson<int>(teamId),
      'nome': serializer.toJson<String>(nome),
      'cognome': serializer.toJson<String>(cognome),
      'numero': serializer.toJson<int>(numero),
      'ruolo': serializer.toJson<Ruolo>(ruolo),
    };
  }

  Player copyWith({
    int? id,
    int? teamId,
    String? nome,
    String? cognome,
    int? numero,
    Ruolo? ruolo,
  }) => Player(
    id: id ?? this.id,
    teamId: teamId ?? this.teamId,
    nome: nome ?? this.nome,
    cognome: cognome ?? this.cognome,
    numero: numero ?? this.numero,
    ruolo: ruolo ?? this.ruolo,
  );
  Player copyWithCompanion(PlayersCompanion data) {
    return Player(
      id: data.id.present ? data.id.value : this.id,
      teamId: data.teamId.present ? data.teamId.value : this.teamId,
      nome: data.nome.present ? data.nome.value : this.nome,
      cognome: data.cognome.present ? data.cognome.value : this.cognome,
      numero: data.numero.present ? data.numero.value : this.numero,
      ruolo: data.ruolo.present ? data.ruolo.value : this.ruolo,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Player(')
          ..write('id: $id, ')
          ..write('teamId: $teamId, ')
          ..write('nome: $nome, ')
          ..write('cognome: $cognome, ')
          ..write('numero: $numero, ')
          ..write('ruolo: $ruolo')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, teamId, nome, cognome, numero, ruolo);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Player &&
          other.id == this.id &&
          other.teamId == this.teamId &&
          other.nome == this.nome &&
          other.cognome == this.cognome &&
          other.numero == this.numero &&
          other.ruolo == this.ruolo);
}

class PlayersCompanion extends UpdateCompanion<Player> {
  final Value<int> id;
  final Value<int> teamId;
  final Value<String> nome;
  final Value<String> cognome;
  final Value<int> numero;
  final Value<Ruolo> ruolo;
  const PlayersCompanion({
    this.id = const Value.absent(),
    this.teamId = const Value.absent(),
    this.nome = const Value.absent(),
    this.cognome = const Value.absent(),
    this.numero = const Value.absent(),
    this.ruolo = const Value.absent(),
  });
  PlayersCompanion.insert({
    this.id = const Value.absent(),
    required int teamId,
    required String nome,
    required String cognome,
    required int numero,
    required Ruolo ruolo,
  }) : teamId = Value(teamId),
       nome = Value(nome),
       cognome = Value(cognome),
       numero = Value(numero),
       ruolo = Value(ruolo);
  static Insertable<Player> custom({
    Expression<int>? id,
    Expression<int>? teamId,
    Expression<String>? nome,
    Expression<String>? cognome,
    Expression<int>? numero,
    Expression<String>? ruolo,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (teamId != null) 'team_id': teamId,
      if (nome != null) 'nome': nome,
      if (cognome != null) 'cognome': cognome,
      if (numero != null) 'numero': numero,
      if (ruolo != null) 'ruolo': ruolo,
    });
  }

  PlayersCompanion copyWith({
    Value<int>? id,
    Value<int>? teamId,
    Value<String>? nome,
    Value<String>? cognome,
    Value<int>? numero,
    Value<Ruolo>? ruolo,
  }) {
    return PlayersCompanion(
      id: id ?? this.id,
      teamId: teamId ?? this.teamId,
      nome: nome ?? this.nome,
      cognome: cognome ?? this.cognome,
      numero: numero ?? this.numero,
      ruolo: ruolo ?? this.ruolo,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (teamId.present) {
      map['team_id'] = Variable<int>(teamId.value);
    }
    if (nome.present) {
      map['nome'] = Variable<String>(nome.value);
    }
    if (cognome.present) {
      map['cognome'] = Variable<String>(cognome.value);
    }
    if (numero.present) {
      map['numero'] = Variable<int>(numero.value);
    }
    if (ruolo.present) {
      map['ruolo'] = Variable<String>(
        $PlayersTable.$converterruolo.toSql(ruolo.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlayersCompanion(')
          ..write('id: $id, ')
          ..write('teamId: $teamId, ')
          ..write('nome: $nome, ')
          ..write('cognome: $cognome, ')
          ..write('numero: $numero, ')
          ..write('ruolo: $ruolo')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TeamsTable teams = $TeamsTable(this);
  late final $PlayersTable players = $PlayersTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [teams, players];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'teams',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('players', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$TeamsTableCreateCompanionBuilder =
    TeamsCompanion Function({
      Value<int> id,
      required String nome,
      required Categoria categoria,
      required int coloreDivisa,
    });
typedef $$TeamsTableUpdateCompanionBuilder =
    TeamsCompanion Function({
      Value<int> id,
      Value<String> nome,
      Value<Categoria> categoria,
      Value<int> coloreDivisa,
    });

final class $$TeamsTableReferences
    extends BaseReferences<_$AppDatabase, $TeamsTable, Team> {
  $$TeamsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PlayersTable, List<Player>> _playersRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.players,
    aliasName: 'teams__id__players__team_id',
  );

  $$PlayersTableProcessedTableManager get playersRefs {
    final manager = $$PlayersTableTableManager(
      $_db,
      $_db.players,
    ).filter((f) => f.teamId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_playersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TeamsTableFilterComposer extends Composer<_$AppDatabase, $TeamsTable> {
  $$TeamsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nome => $composableBuilder(
    column: $table.nome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Categoria, Categoria, String> get categoria =>
      $composableBuilder(
        column: $table.categoria,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get coloreDivisa => $composableBuilder(
    column: $table.coloreDivisa,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> playersRefs(
    Expression<bool> Function($$PlayersTableFilterComposer f) f,
  ) {
    final $$PlayersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.teamId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableFilterComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TeamsTableOrderingComposer
    extends Composer<_$AppDatabase, $TeamsTable> {
  $$TeamsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nome => $composableBuilder(
    column: $table.nome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoria => $composableBuilder(
    column: $table.categoria,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get coloreDivisa => $composableBuilder(
    column: $table.coloreDivisa,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TeamsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TeamsTable> {
  $$TeamsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nome =>
      $composableBuilder(column: $table.nome, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Categoria, String> get categoria =>
      $composableBuilder(column: $table.categoria, builder: (column) => column);

  GeneratedColumn<int> get coloreDivisa => $composableBuilder(
    column: $table.coloreDivisa,
    builder: (column) => column,
  );

  Expression<T> playersRefs<T extends Object>(
    Expression<T> Function($$PlayersTableAnnotationComposer a) f,
  ) {
    final $$PlayersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.teamId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableAnnotationComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TeamsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TeamsTable,
          Team,
          $$TeamsTableFilterComposer,
          $$TeamsTableOrderingComposer,
          $$TeamsTableAnnotationComposer,
          $$TeamsTableCreateCompanionBuilder,
          $$TeamsTableUpdateCompanionBuilder,
          (Team, $$TeamsTableReferences),
          Team,
          PrefetchHooks Function({bool playersRefs})
        > {
  $$TeamsTableTableManager(_$AppDatabase db, $TeamsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TeamsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TeamsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TeamsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> nome = const Value.absent(),
                Value<Categoria> categoria = const Value.absent(),
                Value<int> coloreDivisa = const Value.absent(),
              }) => TeamsCompanion(
                id: id,
                nome: nome,
                categoria: categoria,
                coloreDivisa: coloreDivisa,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String nome,
                required Categoria categoria,
                required int coloreDivisa,
              }) => TeamsCompanion.insert(
                id: id,
                nome: nome,
                categoria: categoria,
                coloreDivisa: coloreDivisa,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TeamsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({playersRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (playersRefs) db.players],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (playersRefs)
                    await $_getPrefetchedData<Team, $TeamsTable, Player>(
                      currentTable: table,
                      referencedTable: $$TeamsTableReferences._playersRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$TeamsTableReferences(db, table, p0).playersRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.teamId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TeamsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TeamsTable,
      Team,
      $$TeamsTableFilterComposer,
      $$TeamsTableOrderingComposer,
      $$TeamsTableAnnotationComposer,
      $$TeamsTableCreateCompanionBuilder,
      $$TeamsTableUpdateCompanionBuilder,
      (Team, $$TeamsTableReferences),
      Team,
      PrefetchHooks Function({bool playersRefs})
    >;
typedef $$PlayersTableCreateCompanionBuilder =
    PlayersCompanion Function({
      Value<int> id,
      required int teamId,
      required String nome,
      required String cognome,
      required int numero,
      required Ruolo ruolo,
    });
typedef $$PlayersTableUpdateCompanionBuilder =
    PlayersCompanion Function({
      Value<int> id,
      Value<int> teamId,
      Value<String> nome,
      Value<String> cognome,
      Value<int> numero,
      Value<Ruolo> ruolo,
    });

final class $$PlayersTableReferences
    extends BaseReferences<_$AppDatabase, $PlayersTable, Player> {
  $$PlayersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TeamsTable _teamIdTable(_$AppDatabase db) =>
      db.teams.createAlias('players__team_id__teams__id');

  $$TeamsTableProcessedTableManager get teamId {
    final $_column = $_itemColumn<int>('team_id')!;

    final manager = $$TeamsTableTableManager(
      $_db,
      $_db.teams,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_teamIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PlayersTableFilterComposer
    extends Composer<_$AppDatabase, $PlayersTable> {
  $$PlayersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nome => $composableBuilder(
    column: $table.nome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cognome => $composableBuilder(
    column: $table.cognome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get numero => $composableBuilder(
    column: $table.numero,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Ruolo, Ruolo, String> get ruolo =>
      $composableBuilder(
        column: $table.ruolo,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$TeamsTableFilterComposer get teamId {
    final $$TeamsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.teamId,
      referencedTable: $db.teams,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TeamsTableFilterComposer(
            $db: $db,
            $table: $db.teams,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlayersTableOrderingComposer
    extends Composer<_$AppDatabase, $PlayersTable> {
  $$PlayersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nome => $composableBuilder(
    column: $table.nome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cognome => $composableBuilder(
    column: $table.cognome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get numero => $composableBuilder(
    column: $table.numero,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ruolo => $composableBuilder(
    column: $table.ruolo,
    builder: (column) => ColumnOrderings(column),
  );

  $$TeamsTableOrderingComposer get teamId {
    final $$TeamsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.teamId,
      referencedTable: $db.teams,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TeamsTableOrderingComposer(
            $db: $db,
            $table: $db.teams,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlayersTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlayersTable> {
  $$PlayersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nome =>
      $composableBuilder(column: $table.nome, builder: (column) => column);

  GeneratedColumn<String> get cognome =>
      $composableBuilder(column: $table.cognome, builder: (column) => column);

  GeneratedColumn<int> get numero =>
      $composableBuilder(column: $table.numero, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Ruolo, String> get ruolo =>
      $composableBuilder(column: $table.ruolo, builder: (column) => column);

  $$TeamsTableAnnotationComposer get teamId {
    final $$TeamsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.teamId,
      referencedTable: $db.teams,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TeamsTableAnnotationComposer(
            $db: $db,
            $table: $db.teams,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlayersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlayersTable,
          Player,
          $$PlayersTableFilterComposer,
          $$PlayersTableOrderingComposer,
          $$PlayersTableAnnotationComposer,
          $$PlayersTableCreateCompanionBuilder,
          $$PlayersTableUpdateCompanionBuilder,
          (Player, $$PlayersTableReferences),
          Player,
          PrefetchHooks Function({bool teamId})
        > {
  $$PlayersTableTableManager(_$AppDatabase db, $PlayersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlayersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlayersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlayersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> teamId = const Value.absent(),
                Value<String> nome = const Value.absent(),
                Value<String> cognome = const Value.absent(),
                Value<int> numero = const Value.absent(),
                Value<Ruolo> ruolo = const Value.absent(),
              }) => PlayersCompanion(
                id: id,
                teamId: teamId,
                nome: nome,
                cognome: cognome,
                numero: numero,
                ruolo: ruolo,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int teamId,
                required String nome,
                required String cognome,
                required int numero,
                required Ruolo ruolo,
              }) => PlayersCompanion.insert(
                id: id,
                teamId: teamId,
                nome: nome,
                cognome: cognome,
                numero: numero,
                ruolo: ruolo,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PlayersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({teamId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (teamId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.teamId,
                                referencedTable: $$PlayersTableReferences
                                    ._teamIdTable(db),
                                referencedColumn: $$PlayersTableReferences
                                    ._teamIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PlayersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlayersTable,
      Player,
      $$PlayersTableFilterComposer,
      $$PlayersTableOrderingComposer,
      $$PlayersTableAnnotationComposer,
      $$PlayersTableCreateCompanionBuilder,
      $$PlayersTableUpdateCompanionBuilder,
      (Player, $$PlayersTableReferences),
      Player,
      PrefetchHooks Function({bool teamId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TeamsTableTableManager get teams =>
      $$TeamsTableTableManager(_db, _db.teams);
  $$PlayersTableTableManager get players =>
      $$PlayersTableTableManager(_db, _db.players);
}

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

class $VolleyMatchesTable extends VolleyMatches
    with TableInfo<$VolleyMatchesTable, VolleyMatch> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VolleyMatchesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _dataOraMeta = const VerificationMeta(
    'dataOra',
  );
  @override
  late final GeneratedColumn<DateTime> dataOra = GeneratedColumn<DateTime>(
    'data_ora',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _inCasaMeta = const VerificationMeta('inCasa');
  @override
  late final GeneratedColumn<bool> inCasa = GeneratedColumn<bool>(
    'in_casa',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("in_casa" IN (0, 1))',
    ),
  );
  static const VerificationMeta _palestraMeta = const VerificationMeta(
    'palestra',
  );
  @override
  late final GeneratedColumn<String> palestra = GeneratedColumn<String>(
    'palestra',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _teamIdMeta = const VerificationMeta('teamId');
  @override
  late final GeneratedColumn<int> teamId = GeneratedColumn<int>(
    'team_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES teams (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
    'lat',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lonMeta = const VerificationMeta('lon');
  @override
  late final GeneratedColumn<double> lon = GeneratedColumn<double>(
    'lon',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    nome,
    dataOra,
    inCasa,
    palestra,
    teamId,
    lat,
    lon,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'volley_matches';
  @override
  VerificationContext validateIntegrity(
    Insertable<VolleyMatch> instance, {
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
    if (data.containsKey('data_ora')) {
      context.handle(
        _dataOraMeta,
        dataOra.isAcceptableOrUnknown(data['data_ora']!, _dataOraMeta),
      );
    } else if (isInserting) {
      context.missing(_dataOraMeta);
    }
    if (data.containsKey('in_casa')) {
      context.handle(
        _inCasaMeta,
        inCasa.isAcceptableOrUnknown(data['in_casa']!, _inCasaMeta),
      );
    } else if (isInserting) {
      context.missing(_inCasaMeta);
    }
    if (data.containsKey('palestra')) {
      context.handle(
        _palestraMeta,
        palestra.isAcceptableOrUnknown(data['palestra']!, _palestraMeta),
      );
    }
    if (data.containsKey('team_id')) {
      context.handle(
        _teamIdMeta,
        teamId.isAcceptableOrUnknown(data['team_id']!, _teamIdMeta),
      );
    }
    if (data.containsKey('lat')) {
      context.handle(
        _latMeta,
        lat.isAcceptableOrUnknown(data['lat']!, _latMeta),
      );
    }
    if (data.containsKey('lon')) {
      context.handle(
        _lonMeta,
        lon.isAcceptableOrUnknown(data['lon']!, _lonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VolleyMatch map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VolleyMatch(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      nome: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nome'],
      )!,
      dataOra: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}data_ora'],
      )!,
      inCasa: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}in_casa'],
      )!,
      palestra: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}palestra'],
      ),
      teamId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}team_id'],
      ),
      lat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lat'],
      ),
      lon: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lon'],
      ),
    );
  }

  @override
  $VolleyMatchesTable createAlias(String alias) {
    return $VolleyMatchesTable(attachedDatabase, alias);
  }
}

class VolleyMatch extends DataClass implements Insertable<VolleyMatch> {
  final int id;
  final String nome;
  final DateTime dataOra;
  final bool inCasa;
  final String? palestra;
  final int? teamId;
  final double? lat;
  final double? lon;
  const VolleyMatch({
    required this.id,
    required this.nome,
    required this.dataOra,
    required this.inCasa,
    this.palestra,
    this.teamId,
    this.lat,
    this.lon,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['nome'] = Variable<String>(nome);
    map['data_ora'] = Variable<DateTime>(dataOra);
    map['in_casa'] = Variable<bool>(inCasa);
    if (!nullToAbsent || palestra != null) {
      map['palestra'] = Variable<String>(palestra);
    }
    if (!nullToAbsent || teamId != null) {
      map['team_id'] = Variable<int>(teamId);
    }
    if (!nullToAbsent || lat != null) {
      map['lat'] = Variable<double>(lat);
    }
    if (!nullToAbsent || lon != null) {
      map['lon'] = Variable<double>(lon);
    }
    return map;
  }

  VolleyMatchesCompanion toCompanion(bool nullToAbsent) {
    return VolleyMatchesCompanion(
      id: Value(id),
      nome: Value(nome),
      dataOra: Value(dataOra),
      inCasa: Value(inCasa),
      palestra: palestra == null && nullToAbsent
          ? const Value.absent()
          : Value(palestra),
      teamId: teamId == null && nullToAbsent
          ? const Value.absent()
          : Value(teamId),
      lat: lat == null && nullToAbsent ? const Value.absent() : Value(lat),
      lon: lon == null && nullToAbsent ? const Value.absent() : Value(lon),
    );
  }

  factory VolleyMatch.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VolleyMatch(
      id: serializer.fromJson<int>(json['id']),
      nome: serializer.fromJson<String>(json['nome']),
      dataOra: serializer.fromJson<DateTime>(json['dataOra']),
      inCasa: serializer.fromJson<bool>(json['inCasa']),
      palestra: serializer.fromJson<String?>(json['palestra']),
      teamId: serializer.fromJson<int?>(json['teamId']),
      lat: serializer.fromJson<double?>(json['lat']),
      lon: serializer.fromJson<double?>(json['lon']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'nome': serializer.toJson<String>(nome),
      'dataOra': serializer.toJson<DateTime>(dataOra),
      'inCasa': serializer.toJson<bool>(inCasa),
      'palestra': serializer.toJson<String?>(palestra),
      'teamId': serializer.toJson<int?>(teamId),
      'lat': serializer.toJson<double?>(lat),
      'lon': serializer.toJson<double?>(lon),
    };
  }

  VolleyMatch copyWith({
    int? id,
    String? nome,
    DateTime? dataOra,
    bool? inCasa,
    Value<String?> palestra = const Value.absent(),
    Value<int?> teamId = const Value.absent(),
    Value<double?> lat = const Value.absent(),
    Value<double?> lon = const Value.absent(),
  }) => VolleyMatch(
    id: id ?? this.id,
    nome: nome ?? this.nome,
    dataOra: dataOra ?? this.dataOra,
    inCasa: inCasa ?? this.inCasa,
    palestra: palestra.present ? palestra.value : this.palestra,
    teamId: teamId.present ? teamId.value : this.teamId,
    lat: lat.present ? lat.value : this.lat,
    lon: lon.present ? lon.value : this.lon,
  );
  VolleyMatch copyWithCompanion(VolleyMatchesCompanion data) {
    return VolleyMatch(
      id: data.id.present ? data.id.value : this.id,
      nome: data.nome.present ? data.nome.value : this.nome,
      dataOra: data.dataOra.present ? data.dataOra.value : this.dataOra,
      inCasa: data.inCasa.present ? data.inCasa.value : this.inCasa,
      palestra: data.palestra.present ? data.palestra.value : this.palestra,
      teamId: data.teamId.present ? data.teamId.value : this.teamId,
      lat: data.lat.present ? data.lat.value : this.lat,
      lon: data.lon.present ? data.lon.value : this.lon,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VolleyMatch(')
          ..write('id: $id, ')
          ..write('nome: $nome, ')
          ..write('dataOra: $dataOra, ')
          ..write('inCasa: $inCasa, ')
          ..write('palestra: $palestra, ')
          ..write('teamId: $teamId, ')
          ..write('lat: $lat, ')
          ..write('lon: $lon')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, nome, dataOra, inCasa, palestra, teamId, lat, lon);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VolleyMatch &&
          other.id == this.id &&
          other.nome == this.nome &&
          other.dataOra == this.dataOra &&
          other.inCasa == this.inCasa &&
          other.palestra == this.palestra &&
          other.teamId == this.teamId &&
          other.lat == this.lat &&
          other.lon == this.lon);
}

class VolleyMatchesCompanion extends UpdateCompanion<VolleyMatch> {
  final Value<int> id;
  final Value<String> nome;
  final Value<DateTime> dataOra;
  final Value<bool> inCasa;
  final Value<String?> palestra;
  final Value<int?> teamId;
  final Value<double?> lat;
  final Value<double?> lon;
  const VolleyMatchesCompanion({
    this.id = const Value.absent(),
    this.nome = const Value.absent(),
    this.dataOra = const Value.absent(),
    this.inCasa = const Value.absent(),
    this.palestra = const Value.absent(),
    this.teamId = const Value.absent(),
    this.lat = const Value.absent(),
    this.lon = const Value.absent(),
  });
  VolleyMatchesCompanion.insert({
    this.id = const Value.absent(),
    required String nome,
    required DateTime dataOra,
    required bool inCasa,
    this.palestra = const Value.absent(),
    this.teamId = const Value.absent(),
    this.lat = const Value.absent(),
    this.lon = const Value.absent(),
  }) : nome = Value(nome),
       dataOra = Value(dataOra),
       inCasa = Value(inCasa);
  static Insertable<VolleyMatch> custom({
    Expression<int>? id,
    Expression<String>? nome,
    Expression<DateTime>? dataOra,
    Expression<bool>? inCasa,
    Expression<String>? palestra,
    Expression<int>? teamId,
    Expression<double>? lat,
    Expression<double>? lon,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nome != null) 'nome': nome,
      if (dataOra != null) 'data_ora': dataOra,
      if (inCasa != null) 'in_casa': inCasa,
      if (palestra != null) 'palestra': palestra,
      if (teamId != null) 'team_id': teamId,
      if (lat != null) 'lat': lat,
      if (lon != null) 'lon': lon,
    });
  }

  VolleyMatchesCompanion copyWith({
    Value<int>? id,
    Value<String>? nome,
    Value<DateTime>? dataOra,
    Value<bool>? inCasa,
    Value<String?>? palestra,
    Value<int?>? teamId,
    Value<double?>? lat,
    Value<double?>? lon,
  }) {
    return VolleyMatchesCompanion(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      dataOra: dataOra ?? this.dataOra,
      inCasa: inCasa ?? this.inCasa,
      palestra: palestra ?? this.palestra,
      teamId: teamId ?? this.teamId,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
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
    if (dataOra.present) {
      map['data_ora'] = Variable<DateTime>(dataOra.value);
    }
    if (inCasa.present) {
      map['in_casa'] = Variable<bool>(inCasa.value);
    }
    if (palestra.present) {
      map['palestra'] = Variable<String>(palestra.value);
    }
    if (teamId.present) {
      map['team_id'] = Variable<int>(teamId.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lon.present) {
      map['lon'] = Variable<double>(lon.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VolleyMatchesCompanion(')
          ..write('id: $id, ')
          ..write('nome: $nome, ')
          ..write('dataOra: $dataOra, ')
          ..write('inCasa: $inCasa, ')
          ..write('palestra: $palestra, ')
          ..write('teamId: $teamId, ')
          ..write('lat: $lat, ')
          ..write('lon: $lon')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TeamsTable teams = $TeamsTable(this);
  late final $PlayersTable players = $PlayersTable(this);
  late final $VolleyMatchesTable volleyMatches = $VolleyMatchesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    teams,
    players,
    volleyMatches,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'teams',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('players', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'teams',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('volley_matches', kind: UpdateKind.update)],
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

  static MultiTypedResultKey<$VolleyMatchesTable, List<VolleyMatch>>
  _volleyMatchesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.volleyMatches,
    aliasName: 'teams__id__volley_matches__team_id',
  );

  $$VolleyMatchesTableProcessedTableManager get volleyMatchesRefs {
    final manager = $$VolleyMatchesTableTableManager(
      $_db,
      $_db.volleyMatches,
    ).filter((f) => f.teamId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_volleyMatchesRefsTable($_db));
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

  Expression<bool> volleyMatchesRefs(
    Expression<bool> Function($$VolleyMatchesTableFilterComposer f) f,
  ) {
    final $$VolleyMatchesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.volleyMatches,
      getReferencedColumn: (t) => t.teamId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VolleyMatchesTableFilterComposer(
            $db: $db,
            $table: $db.volleyMatches,
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

  Expression<T> volleyMatchesRefs<T extends Object>(
    Expression<T> Function($$VolleyMatchesTableAnnotationComposer a) f,
  ) {
    final $$VolleyMatchesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.volleyMatches,
      getReferencedColumn: (t) => t.teamId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VolleyMatchesTableAnnotationComposer(
            $db: $db,
            $table: $db.volleyMatches,
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
          PrefetchHooks Function({bool playersRefs, bool volleyMatchesRefs})
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
          prefetchHooksCallback:
              ({playersRefs = false, volleyMatchesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (playersRefs) db.players,
                    if (volleyMatchesRefs) db.volleyMatches,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (playersRefs)
                        await $_getPrefetchedData<Team, $TeamsTable, Player>(
                          currentTable: table,
                          referencedTable: $$TeamsTableReferences
                              ._playersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TeamsTableReferences(db, table, p0).playersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.teamId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (volleyMatchesRefs)
                        await $_getPrefetchedData<
                          Team,
                          $TeamsTable,
                          VolleyMatch
                        >(
                          currentTable: table,
                          referencedTable: $$TeamsTableReferences
                              ._volleyMatchesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TeamsTableReferences(
                                db,
                                table,
                                p0,
                              ).volleyMatchesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.teamId == item.id,
                              ),
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
      PrefetchHooks Function({bool playersRefs, bool volleyMatchesRefs})
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
typedef $$VolleyMatchesTableCreateCompanionBuilder =
    VolleyMatchesCompanion Function({
      Value<int> id,
      required String nome,
      required DateTime dataOra,
      required bool inCasa,
      Value<String?> palestra,
      Value<int?> teamId,
      Value<double?> lat,
      Value<double?> lon,
    });
typedef $$VolleyMatchesTableUpdateCompanionBuilder =
    VolleyMatchesCompanion Function({
      Value<int> id,
      Value<String> nome,
      Value<DateTime> dataOra,
      Value<bool> inCasa,
      Value<String?> palestra,
      Value<int?> teamId,
      Value<double?> lat,
      Value<double?> lon,
    });

final class $$VolleyMatchesTableReferences
    extends BaseReferences<_$AppDatabase, $VolleyMatchesTable, VolleyMatch> {
  $$VolleyMatchesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TeamsTable _teamIdTable(_$AppDatabase db) =>
      db.teams.createAlias('volley_matches__team_id__teams__id');

  $$TeamsTableProcessedTableManager? get teamId {
    final $_column = $_itemColumn<int>('team_id');
    if ($_column == null) return null;
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

class $$VolleyMatchesTableFilterComposer
    extends Composer<_$AppDatabase, $VolleyMatchesTable> {
  $$VolleyMatchesTableFilterComposer({
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

  ColumnFilters<DateTime> get dataOra => $composableBuilder(
    column: $table.dataOra,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get inCasa => $composableBuilder(
    column: $table.inCasa,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get palestra => $composableBuilder(
    column: $table.palestra,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lon => $composableBuilder(
    column: $table.lon,
    builder: (column) => ColumnFilters(column),
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

class $$VolleyMatchesTableOrderingComposer
    extends Composer<_$AppDatabase, $VolleyMatchesTable> {
  $$VolleyMatchesTableOrderingComposer({
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

  ColumnOrderings<DateTime> get dataOra => $composableBuilder(
    column: $table.dataOra,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get inCasa => $composableBuilder(
    column: $table.inCasa,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get palestra => $composableBuilder(
    column: $table.palestra,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lon => $composableBuilder(
    column: $table.lon,
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

class $$VolleyMatchesTableAnnotationComposer
    extends Composer<_$AppDatabase, $VolleyMatchesTable> {
  $$VolleyMatchesTableAnnotationComposer({
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

  GeneratedColumn<DateTime> get dataOra =>
      $composableBuilder(column: $table.dataOra, builder: (column) => column);

  GeneratedColumn<bool> get inCasa =>
      $composableBuilder(column: $table.inCasa, builder: (column) => column);

  GeneratedColumn<String> get palestra =>
      $composableBuilder(column: $table.palestra, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lon =>
      $composableBuilder(column: $table.lon, builder: (column) => column);

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

class $$VolleyMatchesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VolleyMatchesTable,
          VolleyMatch,
          $$VolleyMatchesTableFilterComposer,
          $$VolleyMatchesTableOrderingComposer,
          $$VolleyMatchesTableAnnotationComposer,
          $$VolleyMatchesTableCreateCompanionBuilder,
          $$VolleyMatchesTableUpdateCompanionBuilder,
          (VolleyMatch, $$VolleyMatchesTableReferences),
          VolleyMatch,
          PrefetchHooks Function({bool teamId})
        > {
  $$VolleyMatchesTableTableManager(_$AppDatabase db, $VolleyMatchesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VolleyMatchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VolleyMatchesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VolleyMatchesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> nome = const Value.absent(),
                Value<DateTime> dataOra = const Value.absent(),
                Value<bool> inCasa = const Value.absent(),
                Value<String?> palestra = const Value.absent(),
                Value<int?> teamId = const Value.absent(),
                Value<double?> lat = const Value.absent(),
                Value<double?> lon = const Value.absent(),
              }) => VolleyMatchesCompanion(
                id: id,
                nome: nome,
                dataOra: dataOra,
                inCasa: inCasa,
                palestra: palestra,
                teamId: teamId,
                lat: lat,
                lon: lon,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String nome,
                required DateTime dataOra,
                required bool inCasa,
                Value<String?> palestra = const Value.absent(),
                Value<int?> teamId = const Value.absent(),
                Value<double?> lat = const Value.absent(),
                Value<double?> lon = const Value.absent(),
              }) => VolleyMatchesCompanion.insert(
                id: id,
                nome: nome,
                dataOra: dataOra,
                inCasa: inCasa,
                palestra: palestra,
                teamId: teamId,
                lat: lat,
                lon: lon,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$VolleyMatchesTableReferences(db, table, e),
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
                                referencedTable: $$VolleyMatchesTableReferences
                                    ._teamIdTable(db),
                                referencedColumn: $$VolleyMatchesTableReferences
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

typedef $$VolleyMatchesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VolleyMatchesTable,
      VolleyMatch,
      $$VolleyMatchesTableFilterComposer,
      $$VolleyMatchesTableOrderingComposer,
      $$VolleyMatchesTableAnnotationComposer,
      $$VolleyMatchesTableCreateCompanionBuilder,
      $$VolleyMatchesTableUpdateCompanionBuilder,
      (VolleyMatch, $$VolleyMatchesTableReferences),
      VolleyMatch,
      PrefetchHooks Function({bool teamId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TeamsTableTableManager get teams =>
      $$TeamsTableTableManager(_db, _db.teams);
  $$PlayersTableTableManager get players =>
      $$PlayersTableTableManager(_db, _db.players);
  $$VolleyMatchesTableTableManager get volleyMatches =>
      $$VolleyMatchesTableTableManager(_db, _db.volleyMatches);
}

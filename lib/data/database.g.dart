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
  static const VerificationMeta _scadenzaCertificatoMeta =
      const VerificationMeta('scadenzaCertificato');
  @override
  late final GeneratedColumn<DateTime> scadenzaCertificato =
      GeneratedColumn<DateTime>(
        'scadenza_certificato',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    teamId,
    nome,
    cognome,
    numero,
    ruolo,
    scadenzaCertificato,
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
    if (data.containsKey('scadenza_certificato')) {
      context.handle(
        _scadenzaCertificatoMeta,
        scadenzaCertificato.isAcceptableOrUnknown(
          data['scadenza_certificato']!,
          _scadenzaCertificatoMeta,
        ),
      );
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
      scadenzaCertificato: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scadenza_certificato'],
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
  final DateTime? scadenzaCertificato;
  const Player({
    required this.id,
    required this.teamId,
    required this.nome,
    required this.cognome,
    required this.numero,
    required this.ruolo,
    this.scadenzaCertificato,
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
    if (!nullToAbsent || scadenzaCertificato != null) {
      map['scadenza_certificato'] = Variable<DateTime>(scadenzaCertificato);
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
      scadenzaCertificato: scadenzaCertificato == null && nullToAbsent
          ? const Value.absent()
          : Value(scadenzaCertificato),
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
      scadenzaCertificato: serializer.fromJson<DateTime?>(
        json['scadenzaCertificato'],
      ),
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
      'scadenzaCertificato': serializer.toJson<DateTime?>(scadenzaCertificato),
    };
  }

  Player copyWith({
    int? id,
    int? teamId,
    String? nome,
    String? cognome,
    int? numero,
    Ruolo? ruolo,
    Value<DateTime?> scadenzaCertificato = const Value.absent(),
  }) => Player(
    id: id ?? this.id,
    teamId: teamId ?? this.teamId,
    nome: nome ?? this.nome,
    cognome: cognome ?? this.cognome,
    numero: numero ?? this.numero,
    ruolo: ruolo ?? this.ruolo,
    scadenzaCertificato: scadenzaCertificato.present
        ? scadenzaCertificato.value
        : this.scadenzaCertificato,
  );
  Player copyWithCompanion(PlayersCompanion data) {
    return Player(
      id: data.id.present ? data.id.value : this.id,
      teamId: data.teamId.present ? data.teamId.value : this.teamId,
      nome: data.nome.present ? data.nome.value : this.nome,
      cognome: data.cognome.present ? data.cognome.value : this.cognome,
      numero: data.numero.present ? data.numero.value : this.numero,
      ruolo: data.ruolo.present ? data.ruolo.value : this.ruolo,
      scadenzaCertificato: data.scadenzaCertificato.present
          ? data.scadenzaCertificato.value
          : this.scadenzaCertificato,
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
          ..write('ruolo: $ruolo, ')
          ..write('scadenzaCertificato: $scadenzaCertificato')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    teamId,
    nome,
    cognome,
    numero,
    ruolo,
    scadenzaCertificato,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Player &&
          other.id == this.id &&
          other.teamId == this.teamId &&
          other.nome == this.nome &&
          other.cognome == this.cognome &&
          other.numero == this.numero &&
          other.ruolo == this.ruolo &&
          other.scadenzaCertificato == this.scadenzaCertificato);
}

class PlayersCompanion extends UpdateCompanion<Player> {
  final Value<int> id;
  final Value<int> teamId;
  final Value<String> nome;
  final Value<String> cognome;
  final Value<int> numero;
  final Value<Ruolo> ruolo;
  final Value<DateTime?> scadenzaCertificato;
  const PlayersCompanion({
    this.id = const Value.absent(),
    this.teamId = const Value.absent(),
    this.nome = const Value.absent(),
    this.cognome = const Value.absent(),
    this.numero = const Value.absent(),
    this.ruolo = const Value.absent(),
    this.scadenzaCertificato = const Value.absent(),
  });
  PlayersCompanion.insert({
    this.id = const Value.absent(),
    required int teamId,
    required String nome,
    required String cognome,
    required int numero,
    required Ruolo ruolo,
    this.scadenzaCertificato = const Value.absent(),
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
    Expression<DateTime>? scadenzaCertificato,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (teamId != null) 'team_id': teamId,
      if (nome != null) 'nome': nome,
      if (cognome != null) 'cognome': cognome,
      if (numero != null) 'numero': numero,
      if (ruolo != null) 'ruolo': ruolo,
      if (scadenzaCertificato != null)
        'scadenza_certificato': scadenzaCertificato,
    });
  }

  PlayersCompanion copyWith({
    Value<int>? id,
    Value<int>? teamId,
    Value<String>? nome,
    Value<String>? cognome,
    Value<int>? numero,
    Value<Ruolo>? ruolo,
    Value<DateTime?>? scadenzaCertificato,
  }) {
    return PlayersCompanion(
      id: id ?? this.id,
      teamId: teamId ?? this.teamId,
      nome: nome ?? this.nome,
      cognome: cognome ?? this.cognome,
      numero: numero ?? this.numero,
      ruolo: ruolo ?? this.ruolo,
      scadenzaCertificato: scadenzaCertificato ?? this.scadenzaCertificato,
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
    if (scadenzaCertificato.present) {
      map['scadenza_certificato'] = Variable<DateTime>(
        scadenzaCertificato.value,
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
          ..write('ruolo: $ruolo, ')
          ..write('scadenzaCertificato: $scadenzaCertificato')
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
  static const VerificationMeta _avversarioMeta = const VerificationMeta(
    'avversario',
  );
  @override
  late final GeneratedColumn<String> avversario = GeneratedColumn<String>(
    'avversario',
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
  late final GeneratedColumnWithTypeConverter<StatoPartita, String> stato =
      GeneratedColumn<String>(
        'stato',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<StatoPartita>($VolleyMatchesTable.$converterstato);
  static const VerificationMeta _setCorrenteMeta = const VerificationMeta(
    'setCorrente',
  );
  @override
  late final GeneratedColumn<int> setCorrente = GeneratedColumn<int>(
    'set_corrente',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    nome,
    dataOra,
    inCasa,
    palestra,
    avversario,
    teamId,
    lat,
    lon,
    stato,
    setCorrente,
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
    if (data.containsKey('avversario')) {
      context.handle(
        _avversarioMeta,
        avversario.isAcceptableOrUnknown(data['avversario']!, _avversarioMeta),
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
    if (data.containsKey('set_corrente')) {
      context.handle(
        _setCorrenteMeta,
        setCorrente.isAcceptableOrUnknown(
          data['set_corrente']!,
          _setCorrenteMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_setCorrenteMeta);
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
      avversario: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avversario'],
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
      stato: $VolleyMatchesTable.$converterstato.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}stato'],
        )!,
      ),
      setCorrente: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}set_corrente'],
      )!,
    );
  }

  @override
  $VolleyMatchesTable createAlias(String alias) {
    return $VolleyMatchesTable(attachedDatabase, alias);
  }

  static TypeConverter<StatoPartita, String> $converterstato =
      const StatoPartitaConverter();
}

class VolleyMatch extends DataClass implements Insertable<VolleyMatch> {
  final int id;
  final String nome;
  final DateTime dataOra;
  final bool inCasa;
  final String? palestra;
  final String? avversario;
  final int? teamId;
  final double? lat;
  final double? lon;
  final StatoPartita stato;
  final int setCorrente;
  const VolleyMatch({
    required this.id,
    required this.nome,
    required this.dataOra,
    required this.inCasa,
    this.palestra,
    this.avversario,
    this.teamId,
    this.lat,
    this.lon,
    required this.stato,
    required this.setCorrente,
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
    if (!nullToAbsent || avversario != null) {
      map['avversario'] = Variable<String>(avversario);
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
    {
      map['stato'] = Variable<String>(
        $VolleyMatchesTable.$converterstato.toSql(stato),
      );
    }
    map['set_corrente'] = Variable<int>(setCorrente);
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
      avversario: avversario == null && nullToAbsent
          ? const Value.absent()
          : Value(avversario),
      teamId: teamId == null && nullToAbsent
          ? const Value.absent()
          : Value(teamId),
      lat: lat == null && nullToAbsent ? const Value.absent() : Value(lat),
      lon: lon == null && nullToAbsent ? const Value.absent() : Value(lon),
      stato: Value(stato),
      setCorrente: Value(setCorrente),
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
      avversario: serializer.fromJson<String?>(json['avversario']),
      teamId: serializer.fromJson<int?>(json['teamId']),
      lat: serializer.fromJson<double?>(json['lat']),
      lon: serializer.fromJson<double?>(json['lon']),
      stato: serializer.fromJson<StatoPartita>(json['stato']),
      setCorrente: serializer.fromJson<int>(json['setCorrente']),
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
      'avversario': serializer.toJson<String?>(avversario),
      'teamId': serializer.toJson<int?>(teamId),
      'lat': serializer.toJson<double?>(lat),
      'lon': serializer.toJson<double?>(lon),
      'stato': serializer.toJson<StatoPartita>(stato),
      'setCorrente': serializer.toJson<int>(setCorrente),
    };
  }

  VolleyMatch copyWith({
    int? id,
    String? nome,
    DateTime? dataOra,
    bool? inCasa,
    Value<String?> palestra = const Value.absent(),
    Value<String?> avversario = const Value.absent(),
    Value<int?> teamId = const Value.absent(),
    Value<double?> lat = const Value.absent(),
    Value<double?> lon = const Value.absent(),
    StatoPartita? stato,
    int? setCorrente,
  }) => VolleyMatch(
    id: id ?? this.id,
    nome: nome ?? this.nome,
    dataOra: dataOra ?? this.dataOra,
    inCasa: inCasa ?? this.inCasa,
    palestra: palestra.present ? palestra.value : this.palestra,
    avversario: avversario.present ? avversario.value : this.avversario,
    teamId: teamId.present ? teamId.value : this.teamId,
    lat: lat.present ? lat.value : this.lat,
    lon: lon.present ? lon.value : this.lon,
    stato: stato ?? this.stato,
    setCorrente: setCorrente ?? this.setCorrente,
  );
  VolleyMatch copyWithCompanion(VolleyMatchesCompanion data) {
    return VolleyMatch(
      id: data.id.present ? data.id.value : this.id,
      nome: data.nome.present ? data.nome.value : this.nome,
      dataOra: data.dataOra.present ? data.dataOra.value : this.dataOra,
      inCasa: data.inCasa.present ? data.inCasa.value : this.inCasa,
      palestra: data.palestra.present ? data.palestra.value : this.palestra,
      avversario: data.avversario.present
          ? data.avversario.value
          : this.avversario,
      teamId: data.teamId.present ? data.teamId.value : this.teamId,
      lat: data.lat.present ? data.lat.value : this.lat,
      lon: data.lon.present ? data.lon.value : this.lon,
      stato: data.stato.present ? data.stato.value : this.stato,
      setCorrente: data.setCorrente.present
          ? data.setCorrente.value
          : this.setCorrente,
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
          ..write('avversario: $avversario, ')
          ..write('teamId: $teamId, ')
          ..write('lat: $lat, ')
          ..write('lon: $lon, ')
          ..write('stato: $stato, ')
          ..write('setCorrente: $setCorrente')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    nome,
    dataOra,
    inCasa,
    palestra,
    avversario,
    teamId,
    lat,
    lon,
    stato,
    setCorrente,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VolleyMatch &&
          other.id == this.id &&
          other.nome == this.nome &&
          other.dataOra == this.dataOra &&
          other.inCasa == this.inCasa &&
          other.palestra == this.palestra &&
          other.avversario == this.avversario &&
          other.teamId == this.teamId &&
          other.lat == this.lat &&
          other.lon == this.lon &&
          other.stato == this.stato &&
          other.setCorrente == this.setCorrente);
}

class VolleyMatchesCompanion extends UpdateCompanion<VolleyMatch> {
  final Value<int> id;
  final Value<String> nome;
  final Value<DateTime> dataOra;
  final Value<bool> inCasa;
  final Value<String?> palestra;
  final Value<String?> avversario;
  final Value<int?> teamId;
  final Value<double?> lat;
  final Value<double?> lon;
  final Value<StatoPartita> stato;
  final Value<int> setCorrente;
  const VolleyMatchesCompanion({
    this.id = const Value.absent(),
    this.nome = const Value.absent(),
    this.dataOra = const Value.absent(),
    this.inCasa = const Value.absent(),
    this.palestra = const Value.absent(),
    this.avversario = const Value.absent(),
    this.teamId = const Value.absent(),
    this.lat = const Value.absent(),
    this.lon = const Value.absent(),
    this.stato = const Value.absent(),
    this.setCorrente = const Value.absent(),
  });
  VolleyMatchesCompanion.insert({
    this.id = const Value.absent(),
    required String nome,
    required DateTime dataOra,
    required bool inCasa,
    this.palestra = const Value.absent(),
    this.avversario = const Value.absent(),
    this.teamId = const Value.absent(),
    this.lat = const Value.absent(),
    this.lon = const Value.absent(),
    required StatoPartita stato,
    required int setCorrente,
  }) : nome = Value(nome),
       dataOra = Value(dataOra),
       inCasa = Value(inCasa),
       stato = Value(stato),
       setCorrente = Value(setCorrente);
  static Insertable<VolleyMatch> custom({
    Expression<int>? id,
    Expression<String>? nome,
    Expression<DateTime>? dataOra,
    Expression<bool>? inCasa,
    Expression<String>? palestra,
    Expression<String>? avversario,
    Expression<int>? teamId,
    Expression<double>? lat,
    Expression<double>? lon,
    Expression<String>? stato,
    Expression<int>? setCorrente,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nome != null) 'nome': nome,
      if (dataOra != null) 'data_ora': dataOra,
      if (inCasa != null) 'in_casa': inCasa,
      if (palestra != null) 'palestra': palestra,
      if (avversario != null) 'avversario': avversario,
      if (teamId != null) 'team_id': teamId,
      if (lat != null) 'lat': lat,
      if (lon != null) 'lon': lon,
      if (stato != null) 'stato': stato,
      if (setCorrente != null) 'set_corrente': setCorrente,
    });
  }

  VolleyMatchesCompanion copyWith({
    Value<int>? id,
    Value<String>? nome,
    Value<DateTime>? dataOra,
    Value<bool>? inCasa,
    Value<String?>? palestra,
    Value<String?>? avversario,
    Value<int?>? teamId,
    Value<double?>? lat,
    Value<double?>? lon,
    Value<StatoPartita>? stato,
    Value<int>? setCorrente,
  }) {
    return VolleyMatchesCompanion(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      dataOra: dataOra ?? this.dataOra,
      inCasa: inCasa ?? this.inCasa,
      palestra: palestra ?? this.palestra,
      avversario: avversario ?? this.avversario,
      teamId: teamId ?? this.teamId,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      stato: stato ?? this.stato,
      setCorrente: setCorrente ?? this.setCorrente,
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
    if (avversario.present) {
      map['avversario'] = Variable<String>(avversario.value);
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
    if (stato.present) {
      map['stato'] = Variable<String>(
        $VolleyMatchesTable.$converterstato.toSql(stato.value),
      );
    }
    if (setCorrente.present) {
      map['set_corrente'] = Variable<int>(setCorrente.value);
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
          ..write('avversario: $avversario, ')
          ..write('teamId: $teamId, ')
          ..write('lat: $lat, ')
          ..write('lon: $lon, ')
          ..write('stato: $stato, ')
          ..write('setCorrente: $setCorrente')
          ..write(')'))
        .toString();
  }
}

class $MatchSetsTable extends MatchSets
    with TableInfo<$MatchSetsTable, MatchSet> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MatchSetsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _matchIdMeta = const VerificationMeta(
    'matchId',
  );
  @override
  late final GeneratedColumn<int> matchId = GeneratedColumn<int>(
    'match_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES volley_matches (id) ON DELETE CASCADE',
    ),
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
  static const VerificationMeta _apertoMeta = const VerificationMeta('aperto');
  @override
  late final GeneratedColumn<bool> aperto = GeneratedColumn<bool>(
    'aperto',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("aperto" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [id, matchId, numero, aperto];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'match_sets';
  @override
  VerificationContext validateIntegrity(
    Insertable<MatchSet> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('match_id')) {
      context.handle(
        _matchIdMeta,
        matchId.isAcceptableOrUnknown(data['match_id']!, _matchIdMeta),
      );
    } else if (isInserting) {
      context.missing(_matchIdMeta);
    }
    if (data.containsKey('numero')) {
      context.handle(
        _numeroMeta,
        numero.isAcceptableOrUnknown(data['numero']!, _numeroMeta),
      );
    } else if (isInserting) {
      context.missing(_numeroMeta);
    }
    if (data.containsKey('aperto')) {
      context.handle(
        _apertoMeta,
        aperto.isAcceptableOrUnknown(data['aperto']!, _apertoMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MatchSet map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MatchSet(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      matchId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}match_id'],
      )!,
      numero: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}numero'],
      )!,
      aperto: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}aperto'],
      )!,
    );
  }

  @override
  $MatchSetsTable createAlias(String alias) {
    return $MatchSetsTable(attachedDatabase, alias);
  }
}

class MatchSet extends DataClass implements Insertable<MatchSet> {
  final int id;
  final int matchId;
  final int numero;
  final bool aperto;
  const MatchSet({
    required this.id,
    required this.matchId,
    required this.numero,
    required this.aperto,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['match_id'] = Variable<int>(matchId);
    map['numero'] = Variable<int>(numero);
    map['aperto'] = Variable<bool>(aperto);
    return map;
  }

  MatchSetsCompanion toCompanion(bool nullToAbsent) {
    return MatchSetsCompanion(
      id: Value(id),
      matchId: Value(matchId),
      numero: Value(numero),
      aperto: Value(aperto),
    );
  }

  factory MatchSet.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MatchSet(
      id: serializer.fromJson<int>(json['id']),
      matchId: serializer.fromJson<int>(json['matchId']),
      numero: serializer.fromJson<int>(json['numero']),
      aperto: serializer.fromJson<bool>(json['aperto']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'matchId': serializer.toJson<int>(matchId),
      'numero': serializer.toJson<int>(numero),
      'aperto': serializer.toJson<bool>(aperto),
    };
  }

  MatchSet copyWith({int? id, int? matchId, int? numero, bool? aperto}) =>
      MatchSet(
        id: id ?? this.id,
        matchId: matchId ?? this.matchId,
        numero: numero ?? this.numero,
        aperto: aperto ?? this.aperto,
      );
  MatchSet copyWithCompanion(MatchSetsCompanion data) {
    return MatchSet(
      id: data.id.present ? data.id.value : this.id,
      matchId: data.matchId.present ? data.matchId.value : this.matchId,
      numero: data.numero.present ? data.numero.value : this.numero,
      aperto: data.aperto.present ? data.aperto.value : this.aperto,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MatchSet(')
          ..write('id: $id, ')
          ..write('matchId: $matchId, ')
          ..write('numero: $numero, ')
          ..write('aperto: $aperto')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, matchId, numero, aperto);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MatchSet &&
          other.id == this.id &&
          other.matchId == this.matchId &&
          other.numero == this.numero &&
          other.aperto == this.aperto);
}

class MatchSetsCompanion extends UpdateCompanion<MatchSet> {
  final Value<int> id;
  final Value<int> matchId;
  final Value<int> numero;
  final Value<bool> aperto;
  const MatchSetsCompanion({
    this.id = const Value.absent(),
    this.matchId = const Value.absent(),
    this.numero = const Value.absent(),
    this.aperto = const Value.absent(),
  });
  MatchSetsCompanion.insert({
    this.id = const Value.absent(),
    required int matchId,
    required int numero,
    this.aperto = const Value.absent(),
  }) : matchId = Value(matchId),
       numero = Value(numero);
  static Insertable<MatchSet> custom({
    Expression<int>? id,
    Expression<int>? matchId,
    Expression<int>? numero,
    Expression<bool>? aperto,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (matchId != null) 'match_id': matchId,
      if (numero != null) 'numero': numero,
      if (aperto != null) 'aperto': aperto,
    });
  }

  MatchSetsCompanion copyWith({
    Value<int>? id,
    Value<int>? matchId,
    Value<int>? numero,
    Value<bool>? aperto,
  }) {
    return MatchSetsCompanion(
      id: id ?? this.id,
      matchId: matchId ?? this.matchId,
      numero: numero ?? this.numero,
      aperto: aperto ?? this.aperto,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (matchId.present) {
      map['match_id'] = Variable<int>(matchId.value);
    }
    if (numero.present) {
      map['numero'] = Variable<int>(numero.value);
    }
    if (aperto.present) {
      map['aperto'] = Variable<bool>(aperto.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MatchSetsCompanion(')
          ..write('id: $id, ')
          ..write('matchId: $matchId, ')
          ..write('numero: $numero, ')
          ..write('aperto: $aperto')
          ..write(')'))
        .toString();
  }
}

class $RotationsTable extends Rotations
    with TableInfo<$RotationsTable, Rotation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RotationsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _setIdMeta = const VerificationMeta('setId');
  @override
  late final GeneratedColumn<int> setId = GeneratedColumn<int>(
    'set_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES match_sets (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<Squadra, String> squadra =
      GeneratedColumn<String>(
        'squadra',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Squadra>($RotationsTable.$convertersquadra);
  static const VerificationMeta _posizioneMeta = const VerificationMeta(
    'posizione',
  );
  @override
  late final GeneratedColumn<int> posizione = GeneratedColumn<int>(
    'posizione',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _giocatoreIdMeta = const VerificationMeta(
    'giocatoreId',
  );
  @override
  late final GeneratedColumn<int> giocatoreId = GeneratedColumn<int>(
    'giocatore_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES players (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    setId,
    squadra,
    posizione,
    giocatoreId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rotations';
  @override
  VerificationContext validateIntegrity(
    Insertable<Rotation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('set_id')) {
      context.handle(
        _setIdMeta,
        setId.isAcceptableOrUnknown(data['set_id']!, _setIdMeta),
      );
    } else if (isInserting) {
      context.missing(_setIdMeta);
    }
    if (data.containsKey('posizione')) {
      context.handle(
        _posizioneMeta,
        posizione.isAcceptableOrUnknown(data['posizione']!, _posizioneMeta),
      );
    } else if (isInserting) {
      context.missing(_posizioneMeta);
    }
    if (data.containsKey('giocatore_id')) {
      context.handle(
        _giocatoreIdMeta,
        giocatoreId.isAcceptableOrUnknown(
          data['giocatore_id']!,
          _giocatoreIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_giocatoreIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Rotation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Rotation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      setId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}set_id'],
      )!,
      squadra: $RotationsTable.$convertersquadra.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}squadra'],
        )!,
      ),
      posizione: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}posizione'],
      )!,
      giocatoreId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}giocatore_id'],
      )!,
    );
  }

  @override
  $RotationsTable createAlias(String alias) {
    return $RotationsTable(attachedDatabase, alias);
  }

  static TypeConverter<Squadra, String> $convertersquadra =
      const SquadraConverter();
}

class Rotation extends DataClass implements Insertable<Rotation> {
  final int id;
  final int setId;
  final Squadra squadra;
  final int posizione;
  final int giocatoreId;
  const Rotation({
    required this.id,
    required this.setId,
    required this.squadra,
    required this.posizione,
    required this.giocatoreId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['set_id'] = Variable<int>(setId);
    {
      map['squadra'] = Variable<String>(
        $RotationsTable.$convertersquadra.toSql(squadra),
      );
    }
    map['posizione'] = Variable<int>(posizione);
    map['giocatore_id'] = Variable<int>(giocatoreId);
    return map;
  }

  RotationsCompanion toCompanion(bool nullToAbsent) {
    return RotationsCompanion(
      id: Value(id),
      setId: Value(setId),
      squadra: Value(squadra),
      posizione: Value(posizione),
      giocatoreId: Value(giocatoreId),
    );
  }

  factory Rotation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Rotation(
      id: serializer.fromJson<int>(json['id']),
      setId: serializer.fromJson<int>(json['setId']),
      squadra: serializer.fromJson<Squadra>(json['squadra']),
      posizione: serializer.fromJson<int>(json['posizione']),
      giocatoreId: serializer.fromJson<int>(json['giocatoreId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'setId': serializer.toJson<int>(setId),
      'squadra': serializer.toJson<Squadra>(squadra),
      'posizione': serializer.toJson<int>(posizione),
      'giocatoreId': serializer.toJson<int>(giocatoreId),
    };
  }

  Rotation copyWith({
    int? id,
    int? setId,
    Squadra? squadra,
    int? posizione,
    int? giocatoreId,
  }) => Rotation(
    id: id ?? this.id,
    setId: setId ?? this.setId,
    squadra: squadra ?? this.squadra,
    posizione: posizione ?? this.posizione,
    giocatoreId: giocatoreId ?? this.giocatoreId,
  );
  Rotation copyWithCompanion(RotationsCompanion data) {
    return Rotation(
      id: data.id.present ? data.id.value : this.id,
      setId: data.setId.present ? data.setId.value : this.setId,
      squadra: data.squadra.present ? data.squadra.value : this.squadra,
      posizione: data.posizione.present ? data.posizione.value : this.posizione,
      giocatoreId: data.giocatoreId.present
          ? data.giocatoreId.value
          : this.giocatoreId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Rotation(')
          ..write('id: $id, ')
          ..write('setId: $setId, ')
          ..write('squadra: $squadra, ')
          ..write('posizione: $posizione, ')
          ..write('giocatoreId: $giocatoreId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, setId, squadra, posizione, giocatoreId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Rotation &&
          other.id == this.id &&
          other.setId == this.setId &&
          other.squadra == this.squadra &&
          other.posizione == this.posizione &&
          other.giocatoreId == this.giocatoreId);
}

class RotationsCompanion extends UpdateCompanion<Rotation> {
  final Value<int> id;
  final Value<int> setId;
  final Value<Squadra> squadra;
  final Value<int> posizione;
  final Value<int> giocatoreId;
  const RotationsCompanion({
    this.id = const Value.absent(),
    this.setId = const Value.absent(),
    this.squadra = const Value.absent(),
    this.posizione = const Value.absent(),
    this.giocatoreId = const Value.absent(),
  });
  RotationsCompanion.insert({
    this.id = const Value.absent(),
    required int setId,
    required Squadra squadra,
    required int posizione,
    required int giocatoreId,
  }) : setId = Value(setId),
       squadra = Value(squadra),
       posizione = Value(posizione),
       giocatoreId = Value(giocatoreId);
  static Insertable<Rotation> custom({
    Expression<int>? id,
    Expression<int>? setId,
    Expression<String>? squadra,
    Expression<int>? posizione,
    Expression<int>? giocatoreId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (setId != null) 'set_id': setId,
      if (squadra != null) 'squadra': squadra,
      if (posizione != null) 'posizione': posizione,
      if (giocatoreId != null) 'giocatore_id': giocatoreId,
    });
  }

  RotationsCompanion copyWith({
    Value<int>? id,
    Value<int>? setId,
    Value<Squadra>? squadra,
    Value<int>? posizione,
    Value<int>? giocatoreId,
  }) {
    return RotationsCompanion(
      id: id ?? this.id,
      setId: setId ?? this.setId,
      squadra: squadra ?? this.squadra,
      posizione: posizione ?? this.posizione,
      giocatoreId: giocatoreId ?? this.giocatoreId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (setId.present) {
      map['set_id'] = Variable<int>(setId.value);
    }
    if (squadra.present) {
      map['squadra'] = Variable<String>(
        $RotationsTable.$convertersquadra.toSql(squadra.value),
      );
    }
    if (posizione.present) {
      map['posizione'] = Variable<int>(posizione.value);
    }
    if (giocatoreId.present) {
      map['giocatore_id'] = Variable<int>(giocatoreId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RotationsCompanion(')
          ..write('id: $id, ')
          ..write('setId: $setId, ')
          ..write('squadra: $squadra, ')
          ..write('posizione: $posizione, ')
          ..write('giocatoreId: $giocatoreId')
          ..write(')'))
        .toString();
  }
}

class $ScoutActionsTable extends ScoutActions
    with TableInfo<$ScoutActionsTable, ScoutAction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScoutActionsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _setIdMeta = const VerificationMeta('setId');
  @override
  late final GeneratedColumn<int> setId = GeneratedColumn<int>(
    'set_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES match_sets (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _rallyIdMeta = const VerificationMeta(
    'rallyId',
  );
  @override
  late final GeneratedColumn<int> rallyId = GeneratedColumn<int>(
    'rally_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ordineMeta = const VerificationMeta('ordine');
  @override
  late final GeneratedColumn<int> ordine = GeneratedColumn<int>(
    'ordine',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Squadra, String> squadra =
      GeneratedColumn<String>(
        'squadra',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Squadra>($ScoutActionsTable.$convertersquadra);
  @override
  late final GeneratedColumnWithTypeConverter<TipoAzione, String> tipo =
      GeneratedColumn<String>(
        'tipo',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<TipoAzione>($ScoutActionsTable.$convertertipo);
  static const VerificationMeta _giocatoreIdMeta = const VerificationMeta(
    'giocatoreId',
  );
  @override
  late final GeneratedColumn<int> giocatoreId = GeneratedColumn<int>(
    'giocatore_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES players (id) ON DELETE SET NULL',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<Fondamentale?, String>
  fondamentale = GeneratedColumn<String>(
    'fondamentale',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<Fondamentale?>($ScoutActionsTable.$converterfondamentalen);
  @override
  late final GeneratedColumnWithTypeConverter<Voto?, String> voto =
      GeneratedColumn<String>(
        'voto',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<Voto?>($ScoutActionsTable.$convertervoton);
  static const VerificationMeta _tipoEsecuzioneMeta = const VerificationMeta(
    'tipoEsecuzione',
  );
  @override
  late final GeneratedColumn<String> tipoEsecuzione = GeneratedColumn<String>(
    'tipo_esecuzione',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('nonSpecificato'),
  );
  @override
  late final GeneratedColumnWithTypeConverter<EsitoPunto, String> esitoPunto =
      GeneratedColumn<String>(
        'esito_punto',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<EsitoPunto>($ScoutActionsTable.$converteresitoPunto);
  static const VerificationMeta _traiettoriaX1Meta = const VerificationMeta(
    'traiettoriaX1',
  );
  @override
  late final GeneratedColumn<double> traiettoriaX1 = GeneratedColumn<double>(
    'traiettoria_x1',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _traiettoriaY1Meta = const VerificationMeta(
    'traiettoriaY1',
  );
  @override
  late final GeneratedColumn<double> traiettoriaY1 = GeneratedColumn<double>(
    'traiettoria_y1',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _traiettoriaX2Meta = const VerificationMeta(
    'traiettoriaX2',
  );
  @override
  late final GeneratedColumn<double> traiettoriaX2 = GeneratedColumn<double>(
    'traiettoria_x2',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _traiettoriaY2Meta = const VerificationMeta(
    'traiettoriaY2',
  );
  @override
  late final GeneratedColumn<double> traiettoriaY2 = GeneratedColumn<double>(
    'traiettoria_y2',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _puntiCasaAlMomentoMeta =
      const VerificationMeta('puntiCasaAlMomento');
  @override
  late final GeneratedColumn<int> puntiCasaAlMomento = GeneratedColumn<int>(
    'punti_casa_al_momento',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _puntiOspitiAlMomentoMeta =
      const VerificationMeta('puntiOspitiAlMomento');
  @override
  late final GeneratedColumn<int> puntiOspitiAlMomento = GeneratedColumn<int>(
    'punti_ospiti_al_momento',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    setId,
    rallyId,
    ordine,
    timestamp,
    squadra,
    tipo,
    giocatoreId,
    fondamentale,
    voto,
    tipoEsecuzione,
    esitoPunto,
    traiettoriaX1,
    traiettoriaY1,
    traiettoriaX2,
    traiettoriaY2,
    puntiCasaAlMomento,
    puntiOspitiAlMomento,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scout_actions';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScoutAction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('set_id')) {
      context.handle(
        _setIdMeta,
        setId.isAcceptableOrUnknown(data['set_id']!, _setIdMeta),
      );
    } else if (isInserting) {
      context.missing(_setIdMeta);
    }
    if (data.containsKey('rally_id')) {
      context.handle(
        _rallyIdMeta,
        rallyId.isAcceptableOrUnknown(data['rally_id']!, _rallyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_rallyIdMeta);
    }
    if (data.containsKey('ordine')) {
      context.handle(
        _ordineMeta,
        ordine.isAcceptableOrUnknown(data['ordine']!, _ordineMeta),
      );
    } else if (isInserting) {
      context.missing(_ordineMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('giocatore_id')) {
      context.handle(
        _giocatoreIdMeta,
        giocatoreId.isAcceptableOrUnknown(
          data['giocatore_id']!,
          _giocatoreIdMeta,
        ),
      );
    }
    if (data.containsKey('tipo_esecuzione')) {
      context.handle(
        _tipoEsecuzioneMeta,
        tipoEsecuzione.isAcceptableOrUnknown(
          data['tipo_esecuzione']!,
          _tipoEsecuzioneMeta,
        ),
      );
    }
    if (data.containsKey('traiettoria_x1')) {
      context.handle(
        _traiettoriaX1Meta,
        traiettoriaX1.isAcceptableOrUnknown(
          data['traiettoria_x1']!,
          _traiettoriaX1Meta,
        ),
      );
    }
    if (data.containsKey('traiettoria_y1')) {
      context.handle(
        _traiettoriaY1Meta,
        traiettoriaY1.isAcceptableOrUnknown(
          data['traiettoria_y1']!,
          _traiettoriaY1Meta,
        ),
      );
    }
    if (data.containsKey('traiettoria_x2')) {
      context.handle(
        _traiettoriaX2Meta,
        traiettoriaX2.isAcceptableOrUnknown(
          data['traiettoria_x2']!,
          _traiettoriaX2Meta,
        ),
      );
    }
    if (data.containsKey('traiettoria_y2')) {
      context.handle(
        _traiettoriaY2Meta,
        traiettoriaY2.isAcceptableOrUnknown(
          data['traiettoria_y2']!,
          _traiettoriaY2Meta,
        ),
      );
    }
    if (data.containsKey('punti_casa_al_momento')) {
      context.handle(
        _puntiCasaAlMomentoMeta,
        puntiCasaAlMomento.isAcceptableOrUnknown(
          data['punti_casa_al_momento']!,
          _puntiCasaAlMomentoMeta,
        ),
      );
    }
    if (data.containsKey('punti_ospiti_al_momento')) {
      context.handle(
        _puntiOspitiAlMomentoMeta,
        puntiOspitiAlMomento.isAcceptableOrUnknown(
          data['punti_ospiti_al_momento']!,
          _puntiOspitiAlMomentoMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ScoutAction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScoutAction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      setId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}set_id'],
      )!,
      rallyId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rally_id'],
      )!,
      ordine: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ordine'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      squadra: $ScoutActionsTable.$convertersquadra.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}squadra'],
        )!,
      ),
      tipo: $ScoutActionsTable.$convertertipo.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}tipo'],
        )!,
      ),
      giocatoreId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}giocatore_id'],
      ),
      fondamentale: $ScoutActionsTable.$converterfondamentalen.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}fondamentale'],
        ),
      ),
      voto: $ScoutActionsTable.$convertervoton.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}voto'],
        ),
      ),
      tipoEsecuzione: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tipo_esecuzione'],
      )!,
      esitoPunto: $ScoutActionsTable.$converteresitoPunto.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}esito_punto'],
        )!,
      ),
      traiettoriaX1: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}traiettoria_x1'],
      ),
      traiettoriaY1: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}traiettoria_y1'],
      ),
      traiettoriaX2: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}traiettoria_x2'],
      ),
      traiettoriaY2: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}traiettoria_y2'],
      ),
      puntiCasaAlMomento: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}punti_casa_al_momento'],
      ),
      puntiOspitiAlMomento: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}punti_ospiti_al_momento'],
      ),
    );
  }

  @override
  $ScoutActionsTable createAlias(String alias) {
    return $ScoutActionsTable(attachedDatabase, alias);
  }

  static TypeConverter<Squadra, String> $convertersquadra =
      const SquadraConverter();
  static TypeConverter<TipoAzione, String> $convertertipo =
      const TipoAzioneConverter();
  static TypeConverter<Fondamentale, String> $converterfondamentale =
      const FondamentaleConverter();
  static TypeConverter<Fondamentale?, String?> $converterfondamentalen =
      NullAwareTypeConverter.wrap($converterfondamentale);
  static TypeConverter<Voto, String> $convertervoto = const VotoConverter();
  static TypeConverter<Voto?, String?> $convertervoton =
      NullAwareTypeConverter.wrap($convertervoto);
  static TypeConverter<EsitoPunto, String> $converteresitoPunto =
      const EsitoPuntoConverter();
}

class ScoutAction extends DataClass implements Insertable<ScoutAction> {
  final int id;
  final int setId;
  final int rallyId;
  final int ordine;
  final DateTime timestamp;
  final Squadra squadra;
  final TipoAzione tipo;
  final int? giocatoreId;
  final Fondamentale? fondamentale;
  final Voto? voto;
  final String tipoEsecuzione;
  final EsitoPunto esitoPunto;
  final double? traiettoriaX1;
  final double? traiettoriaY1;
  final double? traiettoriaX2;
  final double? traiettoriaY2;
  final int? puntiCasaAlMomento;
  final int? puntiOspitiAlMomento;
  const ScoutAction({
    required this.id,
    required this.setId,
    required this.rallyId,
    required this.ordine,
    required this.timestamp,
    required this.squadra,
    required this.tipo,
    this.giocatoreId,
    this.fondamentale,
    this.voto,
    required this.tipoEsecuzione,
    required this.esitoPunto,
    this.traiettoriaX1,
    this.traiettoriaY1,
    this.traiettoriaX2,
    this.traiettoriaY2,
    this.puntiCasaAlMomento,
    this.puntiOspitiAlMomento,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['set_id'] = Variable<int>(setId);
    map['rally_id'] = Variable<int>(rallyId);
    map['ordine'] = Variable<int>(ordine);
    map['timestamp'] = Variable<DateTime>(timestamp);
    {
      map['squadra'] = Variable<String>(
        $ScoutActionsTable.$convertersquadra.toSql(squadra),
      );
    }
    {
      map['tipo'] = Variable<String>(
        $ScoutActionsTable.$convertertipo.toSql(tipo),
      );
    }
    if (!nullToAbsent || giocatoreId != null) {
      map['giocatore_id'] = Variable<int>(giocatoreId);
    }
    if (!nullToAbsent || fondamentale != null) {
      map['fondamentale'] = Variable<String>(
        $ScoutActionsTable.$converterfondamentalen.toSql(fondamentale),
      );
    }
    if (!nullToAbsent || voto != null) {
      map['voto'] = Variable<String>(
        $ScoutActionsTable.$convertervoton.toSql(voto),
      );
    }
    map['tipo_esecuzione'] = Variable<String>(tipoEsecuzione);
    {
      map['esito_punto'] = Variable<String>(
        $ScoutActionsTable.$converteresitoPunto.toSql(esitoPunto),
      );
    }
    if (!nullToAbsent || traiettoriaX1 != null) {
      map['traiettoria_x1'] = Variable<double>(traiettoriaX1);
    }
    if (!nullToAbsent || traiettoriaY1 != null) {
      map['traiettoria_y1'] = Variable<double>(traiettoriaY1);
    }
    if (!nullToAbsent || traiettoriaX2 != null) {
      map['traiettoria_x2'] = Variable<double>(traiettoriaX2);
    }
    if (!nullToAbsent || traiettoriaY2 != null) {
      map['traiettoria_y2'] = Variable<double>(traiettoriaY2);
    }
    if (!nullToAbsent || puntiCasaAlMomento != null) {
      map['punti_casa_al_momento'] = Variable<int>(puntiCasaAlMomento);
    }
    if (!nullToAbsent || puntiOspitiAlMomento != null) {
      map['punti_ospiti_al_momento'] = Variable<int>(puntiOspitiAlMomento);
    }
    return map;
  }

  ScoutActionsCompanion toCompanion(bool nullToAbsent) {
    return ScoutActionsCompanion(
      id: Value(id),
      setId: Value(setId),
      rallyId: Value(rallyId),
      ordine: Value(ordine),
      timestamp: Value(timestamp),
      squadra: Value(squadra),
      tipo: Value(tipo),
      giocatoreId: giocatoreId == null && nullToAbsent
          ? const Value.absent()
          : Value(giocatoreId),
      fondamentale: fondamentale == null && nullToAbsent
          ? const Value.absent()
          : Value(fondamentale),
      voto: voto == null && nullToAbsent ? const Value.absent() : Value(voto),
      tipoEsecuzione: Value(tipoEsecuzione),
      esitoPunto: Value(esitoPunto),
      traiettoriaX1: traiettoriaX1 == null && nullToAbsent
          ? const Value.absent()
          : Value(traiettoriaX1),
      traiettoriaY1: traiettoriaY1 == null && nullToAbsent
          ? const Value.absent()
          : Value(traiettoriaY1),
      traiettoriaX2: traiettoriaX2 == null && nullToAbsent
          ? const Value.absent()
          : Value(traiettoriaX2),
      traiettoriaY2: traiettoriaY2 == null && nullToAbsent
          ? const Value.absent()
          : Value(traiettoriaY2),
      puntiCasaAlMomento: puntiCasaAlMomento == null && nullToAbsent
          ? const Value.absent()
          : Value(puntiCasaAlMomento),
      puntiOspitiAlMomento: puntiOspitiAlMomento == null && nullToAbsent
          ? const Value.absent()
          : Value(puntiOspitiAlMomento),
    );
  }

  factory ScoutAction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScoutAction(
      id: serializer.fromJson<int>(json['id']),
      setId: serializer.fromJson<int>(json['setId']),
      rallyId: serializer.fromJson<int>(json['rallyId']),
      ordine: serializer.fromJson<int>(json['ordine']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      squadra: serializer.fromJson<Squadra>(json['squadra']),
      tipo: serializer.fromJson<TipoAzione>(json['tipo']),
      giocatoreId: serializer.fromJson<int?>(json['giocatoreId']),
      fondamentale: serializer.fromJson<Fondamentale?>(json['fondamentale']),
      voto: serializer.fromJson<Voto?>(json['voto']),
      tipoEsecuzione: serializer.fromJson<String>(json['tipoEsecuzione']),
      esitoPunto: serializer.fromJson<EsitoPunto>(json['esitoPunto']),
      traiettoriaX1: serializer.fromJson<double?>(json['traiettoriaX1']),
      traiettoriaY1: serializer.fromJson<double?>(json['traiettoriaY1']),
      traiettoriaX2: serializer.fromJson<double?>(json['traiettoriaX2']),
      traiettoriaY2: serializer.fromJson<double?>(json['traiettoriaY2']),
      puntiCasaAlMomento: serializer.fromJson<int?>(json['puntiCasaAlMomento']),
      puntiOspitiAlMomento: serializer.fromJson<int?>(
        json['puntiOspitiAlMomento'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'setId': serializer.toJson<int>(setId),
      'rallyId': serializer.toJson<int>(rallyId),
      'ordine': serializer.toJson<int>(ordine),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'squadra': serializer.toJson<Squadra>(squadra),
      'tipo': serializer.toJson<TipoAzione>(tipo),
      'giocatoreId': serializer.toJson<int?>(giocatoreId),
      'fondamentale': serializer.toJson<Fondamentale?>(fondamentale),
      'voto': serializer.toJson<Voto?>(voto),
      'tipoEsecuzione': serializer.toJson<String>(tipoEsecuzione),
      'esitoPunto': serializer.toJson<EsitoPunto>(esitoPunto),
      'traiettoriaX1': serializer.toJson<double?>(traiettoriaX1),
      'traiettoriaY1': serializer.toJson<double?>(traiettoriaY1),
      'traiettoriaX2': serializer.toJson<double?>(traiettoriaX2),
      'traiettoriaY2': serializer.toJson<double?>(traiettoriaY2),
      'puntiCasaAlMomento': serializer.toJson<int?>(puntiCasaAlMomento),
      'puntiOspitiAlMomento': serializer.toJson<int?>(puntiOspitiAlMomento),
    };
  }

  ScoutAction copyWith({
    int? id,
    int? setId,
    int? rallyId,
    int? ordine,
    DateTime? timestamp,
    Squadra? squadra,
    TipoAzione? tipo,
    Value<int?> giocatoreId = const Value.absent(),
    Value<Fondamentale?> fondamentale = const Value.absent(),
    Value<Voto?> voto = const Value.absent(),
    String? tipoEsecuzione,
    EsitoPunto? esitoPunto,
    Value<double?> traiettoriaX1 = const Value.absent(),
    Value<double?> traiettoriaY1 = const Value.absent(),
    Value<double?> traiettoriaX2 = const Value.absent(),
    Value<double?> traiettoriaY2 = const Value.absent(),
    Value<int?> puntiCasaAlMomento = const Value.absent(),
    Value<int?> puntiOspitiAlMomento = const Value.absent(),
  }) => ScoutAction(
    id: id ?? this.id,
    setId: setId ?? this.setId,
    rallyId: rallyId ?? this.rallyId,
    ordine: ordine ?? this.ordine,
    timestamp: timestamp ?? this.timestamp,
    squadra: squadra ?? this.squadra,
    tipo: tipo ?? this.tipo,
    giocatoreId: giocatoreId.present ? giocatoreId.value : this.giocatoreId,
    fondamentale: fondamentale.present ? fondamentale.value : this.fondamentale,
    voto: voto.present ? voto.value : this.voto,
    tipoEsecuzione: tipoEsecuzione ?? this.tipoEsecuzione,
    esitoPunto: esitoPunto ?? this.esitoPunto,
    traiettoriaX1: traiettoriaX1.present
        ? traiettoriaX1.value
        : this.traiettoriaX1,
    traiettoriaY1: traiettoriaY1.present
        ? traiettoriaY1.value
        : this.traiettoriaY1,
    traiettoriaX2: traiettoriaX2.present
        ? traiettoriaX2.value
        : this.traiettoriaX2,
    traiettoriaY2: traiettoriaY2.present
        ? traiettoriaY2.value
        : this.traiettoriaY2,
    puntiCasaAlMomento: puntiCasaAlMomento.present
        ? puntiCasaAlMomento.value
        : this.puntiCasaAlMomento,
    puntiOspitiAlMomento: puntiOspitiAlMomento.present
        ? puntiOspitiAlMomento.value
        : this.puntiOspitiAlMomento,
  );
  ScoutAction copyWithCompanion(ScoutActionsCompanion data) {
    return ScoutAction(
      id: data.id.present ? data.id.value : this.id,
      setId: data.setId.present ? data.setId.value : this.setId,
      rallyId: data.rallyId.present ? data.rallyId.value : this.rallyId,
      ordine: data.ordine.present ? data.ordine.value : this.ordine,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      squadra: data.squadra.present ? data.squadra.value : this.squadra,
      tipo: data.tipo.present ? data.tipo.value : this.tipo,
      giocatoreId: data.giocatoreId.present
          ? data.giocatoreId.value
          : this.giocatoreId,
      fondamentale: data.fondamentale.present
          ? data.fondamentale.value
          : this.fondamentale,
      voto: data.voto.present ? data.voto.value : this.voto,
      tipoEsecuzione: data.tipoEsecuzione.present
          ? data.tipoEsecuzione.value
          : this.tipoEsecuzione,
      esitoPunto: data.esitoPunto.present
          ? data.esitoPunto.value
          : this.esitoPunto,
      traiettoriaX1: data.traiettoriaX1.present
          ? data.traiettoriaX1.value
          : this.traiettoriaX1,
      traiettoriaY1: data.traiettoriaY1.present
          ? data.traiettoriaY1.value
          : this.traiettoriaY1,
      traiettoriaX2: data.traiettoriaX2.present
          ? data.traiettoriaX2.value
          : this.traiettoriaX2,
      traiettoriaY2: data.traiettoriaY2.present
          ? data.traiettoriaY2.value
          : this.traiettoriaY2,
      puntiCasaAlMomento: data.puntiCasaAlMomento.present
          ? data.puntiCasaAlMomento.value
          : this.puntiCasaAlMomento,
      puntiOspitiAlMomento: data.puntiOspitiAlMomento.present
          ? data.puntiOspitiAlMomento.value
          : this.puntiOspitiAlMomento,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScoutAction(')
          ..write('id: $id, ')
          ..write('setId: $setId, ')
          ..write('rallyId: $rallyId, ')
          ..write('ordine: $ordine, ')
          ..write('timestamp: $timestamp, ')
          ..write('squadra: $squadra, ')
          ..write('tipo: $tipo, ')
          ..write('giocatoreId: $giocatoreId, ')
          ..write('fondamentale: $fondamentale, ')
          ..write('voto: $voto, ')
          ..write('tipoEsecuzione: $tipoEsecuzione, ')
          ..write('esitoPunto: $esitoPunto, ')
          ..write('traiettoriaX1: $traiettoriaX1, ')
          ..write('traiettoriaY1: $traiettoriaY1, ')
          ..write('traiettoriaX2: $traiettoriaX2, ')
          ..write('traiettoriaY2: $traiettoriaY2, ')
          ..write('puntiCasaAlMomento: $puntiCasaAlMomento, ')
          ..write('puntiOspitiAlMomento: $puntiOspitiAlMomento')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    setId,
    rallyId,
    ordine,
    timestamp,
    squadra,
    tipo,
    giocatoreId,
    fondamentale,
    voto,
    tipoEsecuzione,
    esitoPunto,
    traiettoriaX1,
    traiettoriaY1,
    traiettoriaX2,
    traiettoriaY2,
    puntiCasaAlMomento,
    puntiOspitiAlMomento,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScoutAction &&
          other.id == this.id &&
          other.setId == this.setId &&
          other.rallyId == this.rallyId &&
          other.ordine == this.ordine &&
          other.timestamp == this.timestamp &&
          other.squadra == this.squadra &&
          other.tipo == this.tipo &&
          other.giocatoreId == this.giocatoreId &&
          other.fondamentale == this.fondamentale &&
          other.voto == this.voto &&
          other.tipoEsecuzione == this.tipoEsecuzione &&
          other.esitoPunto == this.esitoPunto &&
          other.traiettoriaX1 == this.traiettoriaX1 &&
          other.traiettoriaY1 == this.traiettoriaY1 &&
          other.traiettoriaX2 == this.traiettoriaX2 &&
          other.traiettoriaY2 == this.traiettoriaY2 &&
          other.puntiCasaAlMomento == this.puntiCasaAlMomento &&
          other.puntiOspitiAlMomento == this.puntiOspitiAlMomento);
}

class ScoutActionsCompanion extends UpdateCompanion<ScoutAction> {
  final Value<int> id;
  final Value<int> setId;
  final Value<int> rallyId;
  final Value<int> ordine;
  final Value<DateTime> timestamp;
  final Value<Squadra> squadra;
  final Value<TipoAzione> tipo;
  final Value<int?> giocatoreId;
  final Value<Fondamentale?> fondamentale;
  final Value<Voto?> voto;
  final Value<String> tipoEsecuzione;
  final Value<EsitoPunto> esitoPunto;
  final Value<double?> traiettoriaX1;
  final Value<double?> traiettoriaY1;
  final Value<double?> traiettoriaX2;
  final Value<double?> traiettoriaY2;
  final Value<int?> puntiCasaAlMomento;
  final Value<int?> puntiOspitiAlMomento;
  const ScoutActionsCompanion({
    this.id = const Value.absent(),
    this.setId = const Value.absent(),
    this.rallyId = const Value.absent(),
    this.ordine = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.squadra = const Value.absent(),
    this.tipo = const Value.absent(),
    this.giocatoreId = const Value.absent(),
    this.fondamentale = const Value.absent(),
    this.voto = const Value.absent(),
    this.tipoEsecuzione = const Value.absent(),
    this.esitoPunto = const Value.absent(),
    this.traiettoriaX1 = const Value.absent(),
    this.traiettoriaY1 = const Value.absent(),
    this.traiettoriaX2 = const Value.absent(),
    this.traiettoriaY2 = const Value.absent(),
    this.puntiCasaAlMomento = const Value.absent(),
    this.puntiOspitiAlMomento = const Value.absent(),
  });
  ScoutActionsCompanion.insert({
    this.id = const Value.absent(),
    required int setId,
    required int rallyId,
    required int ordine,
    required DateTime timestamp,
    required Squadra squadra,
    required TipoAzione tipo,
    this.giocatoreId = const Value.absent(),
    this.fondamentale = const Value.absent(),
    this.voto = const Value.absent(),
    this.tipoEsecuzione = const Value.absent(),
    required EsitoPunto esitoPunto,
    this.traiettoriaX1 = const Value.absent(),
    this.traiettoriaY1 = const Value.absent(),
    this.traiettoriaX2 = const Value.absent(),
    this.traiettoriaY2 = const Value.absent(),
    this.puntiCasaAlMomento = const Value.absent(),
    this.puntiOspitiAlMomento = const Value.absent(),
  }) : setId = Value(setId),
       rallyId = Value(rallyId),
       ordine = Value(ordine),
       timestamp = Value(timestamp),
       squadra = Value(squadra),
       tipo = Value(tipo),
       esitoPunto = Value(esitoPunto);
  static Insertable<ScoutAction> custom({
    Expression<int>? id,
    Expression<int>? setId,
    Expression<int>? rallyId,
    Expression<int>? ordine,
    Expression<DateTime>? timestamp,
    Expression<String>? squadra,
    Expression<String>? tipo,
    Expression<int>? giocatoreId,
    Expression<String>? fondamentale,
    Expression<String>? voto,
    Expression<String>? tipoEsecuzione,
    Expression<String>? esitoPunto,
    Expression<double>? traiettoriaX1,
    Expression<double>? traiettoriaY1,
    Expression<double>? traiettoriaX2,
    Expression<double>? traiettoriaY2,
    Expression<int>? puntiCasaAlMomento,
    Expression<int>? puntiOspitiAlMomento,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (setId != null) 'set_id': setId,
      if (rallyId != null) 'rally_id': rallyId,
      if (ordine != null) 'ordine': ordine,
      if (timestamp != null) 'timestamp': timestamp,
      if (squadra != null) 'squadra': squadra,
      if (tipo != null) 'tipo': tipo,
      if (giocatoreId != null) 'giocatore_id': giocatoreId,
      if (fondamentale != null) 'fondamentale': fondamentale,
      if (voto != null) 'voto': voto,
      if (tipoEsecuzione != null) 'tipo_esecuzione': tipoEsecuzione,
      if (esitoPunto != null) 'esito_punto': esitoPunto,
      if (traiettoriaX1 != null) 'traiettoria_x1': traiettoriaX1,
      if (traiettoriaY1 != null) 'traiettoria_y1': traiettoriaY1,
      if (traiettoriaX2 != null) 'traiettoria_x2': traiettoriaX2,
      if (traiettoriaY2 != null) 'traiettoria_y2': traiettoriaY2,
      if (puntiCasaAlMomento != null)
        'punti_casa_al_momento': puntiCasaAlMomento,
      if (puntiOspitiAlMomento != null)
        'punti_ospiti_al_momento': puntiOspitiAlMomento,
    });
  }

  ScoutActionsCompanion copyWith({
    Value<int>? id,
    Value<int>? setId,
    Value<int>? rallyId,
    Value<int>? ordine,
    Value<DateTime>? timestamp,
    Value<Squadra>? squadra,
    Value<TipoAzione>? tipo,
    Value<int?>? giocatoreId,
    Value<Fondamentale?>? fondamentale,
    Value<Voto?>? voto,
    Value<String>? tipoEsecuzione,
    Value<EsitoPunto>? esitoPunto,
    Value<double?>? traiettoriaX1,
    Value<double?>? traiettoriaY1,
    Value<double?>? traiettoriaX2,
    Value<double?>? traiettoriaY2,
    Value<int?>? puntiCasaAlMomento,
    Value<int?>? puntiOspitiAlMomento,
  }) {
    return ScoutActionsCompanion(
      id: id ?? this.id,
      setId: setId ?? this.setId,
      rallyId: rallyId ?? this.rallyId,
      ordine: ordine ?? this.ordine,
      timestamp: timestamp ?? this.timestamp,
      squadra: squadra ?? this.squadra,
      tipo: tipo ?? this.tipo,
      giocatoreId: giocatoreId ?? this.giocatoreId,
      fondamentale: fondamentale ?? this.fondamentale,
      voto: voto ?? this.voto,
      tipoEsecuzione: tipoEsecuzione ?? this.tipoEsecuzione,
      esitoPunto: esitoPunto ?? this.esitoPunto,
      traiettoriaX1: traiettoriaX1 ?? this.traiettoriaX1,
      traiettoriaY1: traiettoriaY1 ?? this.traiettoriaY1,
      traiettoriaX2: traiettoriaX2 ?? this.traiettoriaX2,
      traiettoriaY2: traiettoriaY2 ?? this.traiettoriaY2,
      puntiCasaAlMomento: puntiCasaAlMomento ?? this.puntiCasaAlMomento,
      puntiOspitiAlMomento: puntiOspitiAlMomento ?? this.puntiOspitiAlMomento,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (setId.present) {
      map['set_id'] = Variable<int>(setId.value);
    }
    if (rallyId.present) {
      map['rally_id'] = Variable<int>(rallyId.value);
    }
    if (ordine.present) {
      map['ordine'] = Variable<int>(ordine.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (squadra.present) {
      map['squadra'] = Variable<String>(
        $ScoutActionsTable.$convertersquadra.toSql(squadra.value),
      );
    }
    if (tipo.present) {
      map['tipo'] = Variable<String>(
        $ScoutActionsTable.$convertertipo.toSql(tipo.value),
      );
    }
    if (giocatoreId.present) {
      map['giocatore_id'] = Variable<int>(giocatoreId.value);
    }
    if (fondamentale.present) {
      map['fondamentale'] = Variable<String>(
        $ScoutActionsTable.$converterfondamentalen.toSql(fondamentale.value),
      );
    }
    if (voto.present) {
      map['voto'] = Variable<String>(
        $ScoutActionsTable.$convertervoton.toSql(voto.value),
      );
    }
    if (tipoEsecuzione.present) {
      map['tipo_esecuzione'] = Variable<String>(tipoEsecuzione.value);
    }
    if (esitoPunto.present) {
      map['esito_punto'] = Variable<String>(
        $ScoutActionsTable.$converteresitoPunto.toSql(esitoPunto.value),
      );
    }
    if (traiettoriaX1.present) {
      map['traiettoria_x1'] = Variable<double>(traiettoriaX1.value);
    }
    if (traiettoriaY1.present) {
      map['traiettoria_y1'] = Variable<double>(traiettoriaY1.value);
    }
    if (traiettoriaX2.present) {
      map['traiettoria_x2'] = Variable<double>(traiettoriaX2.value);
    }
    if (traiettoriaY2.present) {
      map['traiettoria_y2'] = Variable<double>(traiettoriaY2.value);
    }
    if (puntiCasaAlMomento.present) {
      map['punti_casa_al_momento'] = Variable<int>(puntiCasaAlMomento.value);
    }
    if (puntiOspitiAlMomento.present) {
      map['punti_ospiti_al_momento'] = Variable<int>(
        puntiOspitiAlMomento.value,
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScoutActionsCompanion(')
          ..write('id: $id, ')
          ..write('setId: $setId, ')
          ..write('rallyId: $rallyId, ')
          ..write('ordine: $ordine, ')
          ..write('timestamp: $timestamp, ')
          ..write('squadra: $squadra, ')
          ..write('tipo: $tipo, ')
          ..write('giocatoreId: $giocatoreId, ')
          ..write('fondamentale: $fondamentale, ')
          ..write('voto: $voto, ')
          ..write('tipoEsecuzione: $tipoEsecuzione, ')
          ..write('esitoPunto: $esitoPunto, ')
          ..write('traiettoriaX1: $traiettoriaX1, ')
          ..write('traiettoriaY1: $traiettoriaY1, ')
          ..write('traiettoriaX2: $traiettoriaX2, ')
          ..write('traiettoriaY2: $traiettoriaY2, ')
          ..write('puntiCasaAlMomento: $puntiCasaAlMomento, ')
          ..write('puntiOspitiAlMomento: $puntiOspitiAlMomento')
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
  late final $MatchSetsTable matchSets = $MatchSetsTable(this);
  late final $RotationsTable rotations = $RotationsTable(this);
  late final $ScoutActionsTable scoutActions = $ScoutActionsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    teams,
    players,
    volleyMatches,
    matchSets,
    rotations,
    scoutActions,
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
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'volley_matches',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('match_sets', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'match_sets',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('rotations', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'players',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('rotations', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'match_sets',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('scout_actions', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'players',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('scout_actions', kind: UpdateKind.update)],
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
      Value<DateTime?> scadenzaCertificato,
    });
typedef $$PlayersTableUpdateCompanionBuilder =
    PlayersCompanion Function({
      Value<int> id,
      Value<int> teamId,
      Value<String> nome,
      Value<String> cognome,
      Value<int> numero,
      Value<Ruolo> ruolo,
      Value<DateTime?> scadenzaCertificato,
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

  static MultiTypedResultKey<$RotationsTable, List<Rotation>>
  _rotationsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.rotations,
    aliasName: 'players__id__rotations__giocatore_id',
  );

  $$RotationsTableProcessedTableManager get rotationsRefs {
    final manager = $$RotationsTableTableManager(
      $_db,
      $_db.rotations,
    ).filter((f) => f.giocatoreId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_rotationsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ScoutActionsTable, List<ScoutAction>>
  _scoutActionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.scoutActions,
    aliasName: 'players__id__scout_actions__giocatore_id',
  );

  $$ScoutActionsTableProcessedTableManager get scoutActionsRefs {
    final manager = $$ScoutActionsTableTableManager(
      $_db,
      $_db.scoutActions,
    ).filter((f) => f.giocatoreId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_scoutActionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
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

  ColumnFilters<DateTime> get scadenzaCertificato => $composableBuilder(
    column: $table.scadenzaCertificato,
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

  Expression<bool> rotationsRefs(
    Expression<bool> Function($$RotationsTableFilterComposer f) f,
  ) {
    final $$RotationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.rotations,
      getReferencedColumn: (t) => t.giocatoreId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RotationsTableFilterComposer(
            $db: $db,
            $table: $db.rotations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> scoutActionsRefs(
    Expression<bool> Function($$ScoutActionsTableFilterComposer f) f,
  ) {
    final $$ScoutActionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.scoutActions,
      getReferencedColumn: (t) => t.giocatoreId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScoutActionsTableFilterComposer(
            $db: $db,
            $table: $db.scoutActions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
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

  ColumnOrderings<DateTime> get scadenzaCertificato => $composableBuilder(
    column: $table.scadenzaCertificato,
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

  GeneratedColumn<DateTime> get scadenzaCertificato => $composableBuilder(
    column: $table.scadenzaCertificato,
    builder: (column) => column,
  );

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

  Expression<T> rotationsRefs<T extends Object>(
    Expression<T> Function($$RotationsTableAnnotationComposer a) f,
  ) {
    final $$RotationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.rotations,
      getReferencedColumn: (t) => t.giocatoreId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RotationsTableAnnotationComposer(
            $db: $db,
            $table: $db.rotations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> scoutActionsRefs<T extends Object>(
    Expression<T> Function($$ScoutActionsTableAnnotationComposer a) f,
  ) {
    final $$ScoutActionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.scoutActions,
      getReferencedColumn: (t) => t.giocatoreId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScoutActionsTableAnnotationComposer(
            $db: $db,
            $table: $db.scoutActions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
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
          PrefetchHooks Function({
            bool teamId,
            bool rotationsRefs,
            bool scoutActionsRefs,
          })
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
                Value<DateTime?> scadenzaCertificato = const Value.absent(),
              }) => PlayersCompanion(
                id: id,
                teamId: teamId,
                nome: nome,
                cognome: cognome,
                numero: numero,
                ruolo: ruolo,
                scadenzaCertificato: scadenzaCertificato,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int teamId,
                required String nome,
                required String cognome,
                required int numero,
                required Ruolo ruolo,
                Value<DateTime?> scadenzaCertificato = const Value.absent(),
              }) => PlayersCompanion.insert(
                id: id,
                teamId: teamId,
                nome: nome,
                cognome: cognome,
                numero: numero,
                ruolo: ruolo,
                scadenzaCertificato: scadenzaCertificato,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PlayersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                teamId = false,
                rotationsRefs = false,
                scoutActionsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (rotationsRefs) db.rotations,
                    if (scoutActionsRefs) db.scoutActions,
                  ],
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
                    return [
                      if (rotationsRefs)
                        await $_getPrefetchedData<
                          Player,
                          $PlayersTable,
                          Rotation
                        >(
                          currentTable: table,
                          referencedTable: $$PlayersTableReferences
                              ._rotationsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlayersTableReferences(
                                db,
                                table,
                                p0,
                              ).rotationsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.giocatoreId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (scoutActionsRefs)
                        await $_getPrefetchedData<
                          Player,
                          $PlayersTable,
                          ScoutAction
                        >(
                          currentTable: table,
                          referencedTable: $$PlayersTableReferences
                              ._scoutActionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlayersTableReferences(
                                db,
                                table,
                                p0,
                              ).scoutActionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.giocatoreId == item.id,
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
      PrefetchHooks Function({
        bool teamId,
        bool rotationsRefs,
        bool scoutActionsRefs,
      })
    >;
typedef $$VolleyMatchesTableCreateCompanionBuilder =
    VolleyMatchesCompanion Function({
      Value<int> id,
      required String nome,
      required DateTime dataOra,
      required bool inCasa,
      Value<String?> palestra,
      Value<String?> avversario,
      Value<int?> teamId,
      Value<double?> lat,
      Value<double?> lon,
      required StatoPartita stato,
      required int setCorrente,
    });
typedef $$VolleyMatchesTableUpdateCompanionBuilder =
    VolleyMatchesCompanion Function({
      Value<int> id,
      Value<String> nome,
      Value<DateTime> dataOra,
      Value<bool> inCasa,
      Value<String?> palestra,
      Value<String?> avversario,
      Value<int?> teamId,
      Value<double?> lat,
      Value<double?> lon,
      Value<StatoPartita> stato,
      Value<int> setCorrente,
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

  static MultiTypedResultKey<$MatchSetsTable, List<MatchSet>>
  _matchSetsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.matchSets,
    aliasName: 'volley_matches__id__match_sets__match_id',
  );

  $$MatchSetsTableProcessedTableManager get matchSetsRefs {
    final manager = $$MatchSetsTableTableManager(
      $_db,
      $_db.matchSets,
    ).filter((f) => f.matchId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_matchSetsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
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

  ColumnFilters<String> get avversario => $composableBuilder(
    column: $table.avversario,
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

  ColumnWithTypeConverterFilters<StatoPartita, StatoPartita, String>
  get stato => $composableBuilder(
    column: $table.stato,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get setCorrente => $composableBuilder(
    column: $table.setCorrente,
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

  Expression<bool> matchSetsRefs(
    Expression<bool> Function($$MatchSetsTableFilterComposer f) f,
  ) {
    final $$MatchSetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.matchSets,
      getReferencedColumn: (t) => t.matchId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchSetsTableFilterComposer(
            $db: $db,
            $table: $db.matchSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
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

  ColumnOrderings<String> get avversario => $composableBuilder(
    column: $table.avversario,
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

  ColumnOrderings<String> get stato => $composableBuilder(
    column: $table.stato,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get setCorrente => $composableBuilder(
    column: $table.setCorrente,
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

  GeneratedColumn<String> get avversario => $composableBuilder(
    column: $table.avversario,
    builder: (column) => column,
  );

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lon =>
      $composableBuilder(column: $table.lon, builder: (column) => column);

  GeneratedColumnWithTypeConverter<StatoPartita, String> get stato =>
      $composableBuilder(column: $table.stato, builder: (column) => column);

  GeneratedColumn<int> get setCorrente => $composableBuilder(
    column: $table.setCorrente,
    builder: (column) => column,
  );

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

  Expression<T> matchSetsRefs<T extends Object>(
    Expression<T> Function($$MatchSetsTableAnnotationComposer a) f,
  ) {
    final $$MatchSetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.matchSets,
      getReferencedColumn: (t) => t.matchId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchSetsTableAnnotationComposer(
            $db: $db,
            $table: $db.matchSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
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
          PrefetchHooks Function({bool teamId, bool matchSetsRefs})
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
                Value<String?> avversario = const Value.absent(),
                Value<int?> teamId = const Value.absent(),
                Value<double?> lat = const Value.absent(),
                Value<double?> lon = const Value.absent(),
                Value<StatoPartita> stato = const Value.absent(),
                Value<int> setCorrente = const Value.absent(),
              }) => VolleyMatchesCompanion(
                id: id,
                nome: nome,
                dataOra: dataOra,
                inCasa: inCasa,
                palestra: palestra,
                avversario: avversario,
                teamId: teamId,
                lat: lat,
                lon: lon,
                stato: stato,
                setCorrente: setCorrente,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String nome,
                required DateTime dataOra,
                required bool inCasa,
                Value<String?> palestra = const Value.absent(),
                Value<String?> avversario = const Value.absent(),
                Value<int?> teamId = const Value.absent(),
                Value<double?> lat = const Value.absent(),
                Value<double?> lon = const Value.absent(),
                required StatoPartita stato,
                required int setCorrente,
              }) => VolleyMatchesCompanion.insert(
                id: id,
                nome: nome,
                dataOra: dataOra,
                inCasa: inCasa,
                palestra: palestra,
                avversario: avversario,
                teamId: teamId,
                lat: lat,
                lon: lon,
                stato: stato,
                setCorrente: setCorrente,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$VolleyMatchesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({teamId = false, matchSetsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (matchSetsRefs) db.matchSets],
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
                return [
                  if (matchSetsRefs)
                    await $_getPrefetchedData<
                      VolleyMatch,
                      $VolleyMatchesTable,
                      MatchSet
                    >(
                      currentTable: table,
                      referencedTable: $$VolleyMatchesTableReferences
                          ._matchSetsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$VolleyMatchesTableReferences(
                            db,
                            table,
                            p0,
                          ).matchSetsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.matchId == item.id),
                      typedResults: items,
                    ),
                ];
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
      PrefetchHooks Function({bool teamId, bool matchSetsRefs})
    >;
typedef $$MatchSetsTableCreateCompanionBuilder =
    MatchSetsCompanion Function({
      Value<int> id,
      required int matchId,
      required int numero,
      Value<bool> aperto,
    });
typedef $$MatchSetsTableUpdateCompanionBuilder =
    MatchSetsCompanion Function({
      Value<int> id,
      Value<int> matchId,
      Value<int> numero,
      Value<bool> aperto,
    });

final class $$MatchSetsTableReferences
    extends BaseReferences<_$AppDatabase, $MatchSetsTable, MatchSet> {
  $$MatchSetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $VolleyMatchesTable _matchIdTable(_$AppDatabase db) =>
      db.volleyMatches.createAlias('match_sets__match_id__volley_matches__id');

  $$VolleyMatchesTableProcessedTableManager get matchId {
    final $_column = $_itemColumn<int>('match_id')!;

    final manager = $$VolleyMatchesTableTableManager(
      $_db,
      $_db.volleyMatches,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_matchIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$RotationsTable, List<Rotation>>
  _rotationsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.rotations,
    aliasName: 'match_sets__id__rotations__set_id',
  );

  $$RotationsTableProcessedTableManager get rotationsRefs {
    final manager = $$RotationsTableTableManager(
      $_db,
      $_db.rotations,
    ).filter((f) => f.setId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_rotationsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ScoutActionsTable, List<ScoutAction>>
  _scoutActionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.scoutActions,
    aliasName: 'match_sets__id__scout_actions__set_id',
  );

  $$ScoutActionsTableProcessedTableManager get scoutActionsRefs {
    final manager = $$ScoutActionsTableTableManager(
      $_db,
      $_db.scoutActions,
    ).filter((f) => f.setId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_scoutActionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MatchSetsTableFilterComposer
    extends Composer<_$AppDatabase, $MatchSetsTable> {
  $$MatchSetsTableFilterComposer({
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

  ColumnFilters<int> get numero => $composableBuilder(
    column: $table.numero,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get aperto => $composableBuilder(
    column: $table.aperto,
    builder: (column) => ColumnFilters(column),
  );

  $$VolleyMatchesTableFilterComposer get matchId {
    final $$VolleyMatchesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchId,
      referencedTable: $db.volleyMatches,
      getReferencedColumn: (t) => t.id,
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
    return composer;
  }

  Expression<bool> rotationsRefs(
    Expression<bool> Function($$RotationsTableFilterComposer f) f,
  ) {
    final $$RotationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.rotations,
      getReferencedColumn: (t) => t.setId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RotationsTableFilterComposer(
            $db: $db,
            $table: $db.rotations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> scoutActionsRefs(
    Expression<bool> Function($$ScoutActionsTableFilterComposer f) f,
  ) {
    final $$ScoutActionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.scoutActions,
      getReferencedColumn: (t) => t.setId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScoutActionsTableFilterComposer(
            $db: $db,
            $table: $db.scoutActions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MatchSetsTableOrderingComposer
    extends Composer<_$AppDatabase, $MatchSetsTable> {
  $$MatchSetsTableOrderingComposer({
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

  ColumnOrderings<int> get numero => $composableBuilder(
    column: $table.numero,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get aperto => $composableBuilder(
    column: $table.aperto,
    builder: (column) => ColumnOrderings(column),
  );

  $$VolleyMatchesTableOrderingComposer get matchId {
    final $$VolleyMatchesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchId,
      referencedTable: $db.volleyMatches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VolleyMatchesTableOrderingComposer(
            $db: $db,
            $table: $db.volleyMatches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MatchSetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MatchSetsTable> {
  $$MatchSetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get numero =>
      $composableBuilder(column: $table.numero, builder: (column) => column);

  GeneratedColumn<bool> get aperto =>
      $composableBuilder(column: $table.aperto, builder: (column) => column);

  $$VolleyMatchesTableAnnotationComposer get matchId {
    final $$VolleyMatchesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchId,
      referencedTable: $db.volleyMatches,
      getReferencedColumn: (t) => t.id,
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
    return composer;
  }

  Expression<T> rotationsRefs<T extends Object>(
    Expression<T> Function($$RotationsTableAnnotationComposer a) f,
  ) {
    final $$RotationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.rotations,
      getReferencedColumn: (t) => t.setId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RotationsTableAnnotationComposer(
            $db: $db,
            $table: $db.rotations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> scoutActionsRefs<T extends Object>(
    Expression<T> Function($$ScoutActionsTableAnnotationComposer a) f,
  ) {
    final $$ScoutActionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.scoutActions,
      getReferencedColumn: (t) => t.setId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScoutActionsTableAnnotationComposer(
            $db: $db,
            $table: $db.scoutActions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MatchSetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MatchSetsTable,
          MatchSet,
          $$MatchSetsTableFilterComposer,
          $$MatchSetsTableOrderingComposer,
          $$MatchSetsTableAnnotationComposer,
          $$MatchSetsTableCreateCompanionBuilder,
          $$MatchSetsTableUpdateCompanionBuilder,
          (MatchSet, $$MatchSetsTableReferences),
          MatchSet,
          PrefetchHooks Function({
            bool matchId,
            bool rotationsRefs,
            bool scoutActionsRefs,
          })
        > {
  $$MatchSetsTableTableManager(_$AppDatabase db, $MatchSetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MatchSetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MatchSetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MatchSetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> matchId = const Value.absent(),
                Value<int> numero = const Value.absent(),
                Value<bool> aperto = const Value.absent(),
              }) => MatchSetsCompanion(
                id: id,
                matchId: matchId,
                numero: numero,
                aperto: aperto,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int matchId,
                required int numero,
                Value<bool> aperto = const Value.absent(),
              }) => MatchSetsCompanion.insert(
                id: id,
                matchId: matchId,
                numero: numero,
                aperto: aperto,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MatchSetsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                matchId = false,
                rotationsRefs = false,
                scoutActionsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (rotationsRefs) db.rotations,
                    if (scoutActionsRefs) db.scoutActions,
                  ],
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
                        if (matchId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.matchId,
                                    referencedTable: $$MatchSetsTableReferences
                                        ._matchIdTable(db),
                                    referencedColumn: $$MatchSetsTableReferences
                                        ._matchIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (rotationsRefs)
                        await $_getPrefetchedData<
                          MatchSet,
                          $MatchSetsTable,
                          Rotation
                        >(
                          currentTable: table,
                          referencedTable: $$MatchSetsTableReferences
                              ._rotationsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MatchSetsTableReferences(
                                db,
                                table,
                                p0,
                              ).rotationsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.setId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (scoutActionsRefs)
                        await $_getPrefetchedData<
                          MatchSet,
                          $MatchSetsTable,
                          ScoutAction
                        >(
                          currentTable: table,
                          referencedTable: $$MatchSetsTableReferences
                              ._scoutActionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MatchSetsTableReferences(
                                db,
                                table,
                                p0,
                              ).scoutActionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.setId == item.id,
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

typedef $$MatchSetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MatchSetsTable,
      MatchSet,
      $$MatchSetsTableFilterComposer,
      $$MatchSetsTableOrderingComposer,
      $$MatchSetsTableAnnotationComposer,
      $$MatchSetsTableCreateCompanionBuilder,
      $$MatchSetsTableUpdateCompanionBuilder,
      (MatchSet, $$MatchSetsTableReferences),
      MatchSet,
      PrefetchHooks Function({
        bool matchId,
        bool rotationsRefs,
        bool scoutActionsRefs,
      })
    >;
typedef $$RotationsTableCreateCompanionBuilder =
    RotationsCompanion Function({
      Value<int> id,
      required int setId,
      required Squadra squadra,
      required int posizione,
      required int giocatoreId,
    });
typedef $$RotationsTableUpdateCompanionBuilder =
    RotationsCompanion Function({
      Value<int> id,
      Value<int> setId,
      Value<Squadra> squadra,
      Value<int> posizione,
      Value<int> giocatoreId,
    });

final class $$RotationsTableReferences
    extends BaseReferences<_$AppDatabase, $RotationsTable, Rotation> {
  $$RotationsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MatchSetsTable _setIdTable(_$AppDatabase db) =>
      db.matchSets.createAlias('rotations__set_id__match_sets__id');

  $$MatchSetsTableProcessedTableManager get setId {
    final $_column = $_itemColumn<int>('set_id')!;

    final manager = $$MatchSetsTableTableManager(
      $_db,
      $_db.matchSets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_setIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PlayersTable _giocatoreIdTable(_$AppDatabase db) =>
      db.players.createAlias('rotations__giocatore_id__players__id');

  $$PlayersTableProcessedTableManager get giocatoreId {
    final $_column = $_itemColumn<int>('giocatore_id')!;

    final manager = $$PlayersTableTableManager(
      $_db,
      $_db.players,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_giocatoreIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RotationsTableFilterComposer
    extends Composer<_$AppDatabase, $RotationsTable> {
  $$RotationsTableFilterComposer({
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

  ColumnWithTypeConverterFilters<Squadra, Squadra, String> get squadra =>
      $composableBuilder(
        column: $table.squadra,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get posizione => $composableBuilder(
    column: $table.posizione,
    builder: (column) => ColumnFilters(column),
  );

  $$MatchSetsTableFilterComposer get setId {
    final $$MatchSetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setId,
      referencedTable: $db.matchSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchSetsTableFilterComposer(
            $db: $db,
            $table: $db.matchSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PlayersTableFilterComposer get giocatoreId {
    final $$PlayersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.giocatoreId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
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
    return composer;
  }
}

class $$RotationsTableOrderingComposer
    extends Composer<_$AppDatabase, $RotationsTable> {
  $$RotationsTableOrderingComposer({
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

  ColumnOrderings<String> get squadra => $composableBuilder(
    column: $table.squadra,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get posizione => $composableBuilder(
    column: $table.posizione,
    builder: (column) => ColumnOrderings(column),
  );

  $$MatchSetsTableOrderingComposer get setId {
    final $$MatchSetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setId,
      referencedTable: $db.matchSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchSetsTableOrderingComposer(
            $db: $db,
            $table: $db.matchSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PlayersTableOrderingComposer get giocatoreId {
    final $$PlayersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.giocatoreId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableOrderingComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RotationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RotationsTable> {
  $$RotationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Squadra, String> get squadra =>
      $composableBuilder(column: $table.squadra, builder: (column) => column);

  GeneratedColumn<int> get posizione =>
      $composableBuilder(column: $table.posizione, builder: (column) => column);

  $$MatchSetsTableAnnotationComposer get setId {
    final $$MatchSetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setId,
      referencedTable: $db.matchSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchSetsTableAnnotationComposer(
            $db: $db,
            $table: $db.matchSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PlayersTableAnnotationComposer get giocatoreId {
    final $$PlayersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.giocatoreId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
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
    return composer;
  }
}

class $$RotationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RotationsTable,
          Rotation,
          $$RotationsTableFilterComposer,
          $$RotationsTableOrderingComposer,
          $$RotationsTableAnnotationComposer,
          $$RotationsTableCreateCompanionBuilder,
          $$RotationsTableUpdateCompanionBuilder,
          (Rotation, $$RotationsTableReferences),
          Rotation,
          PrefetchHooks Function({bool setId, bool giocatoreId})
        > {
  $$RotationsTableTableManager(_$AppDatabase db, $RotationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RotationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RotationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RotationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> setId = const Value.absent(),
                Value<Squadra> squadra = const Value.absent(),
                Value<int> posizione = const Value.absent(),
                Value<int> giocatoreId = const Value.absent(),
              }) => RotationsCompanion(
                id: id,
                setId: setId,
                squadra: squadra,
                posizione: posizione,
                giocatoreId: giocatoreId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int setId,
                required Squadra squadra,
                required int posizione,
                required int giocatoreId,
              }) => RotationsCompanion.insert(
                id: id,
                setId: setId,
                squadra: squadra,
                posizione: posizione,
                giocatoreId: giocatoreId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RotationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({setId = false, giocatoreId = false}) {
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
                    if (setId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.setId,
                                referencedTable: $$RotationsTableReferences
                                    ._setIdTable(db),
                                referencedColumn: $$RotationsTableReferences
                                    ._setIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (giocatoreId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.giocatoreId,
                                referencedTable: $$RotationsTableReferences
                                    ._giocatoreIdTable(db),
                                referencedColumn: $$RotationsTableReferences
                                    ._giocatoreIdTable(db)
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

typedef $$RotationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RotationsTable,
      Rotation,
      $$RotationsTableFilterComposer,
      $$RotationsTableOrderingComposer,
      $$RotationsTableAnnotationComposer,
      $$RotationsTableCreateCompanionBuilder,
      $$RotationsTableUpdateCompanionBuilder,
      (Rotation, $$RotationsTableReferences),
      Rotation,
      PrefetchHooks Function({bool setId, bool giocatoreId})
    >;
typedef $$ScoutActionsTableCreateCompanionBuilder =
    ScoutActionsCompanion Function({
      Value<int> id,
      required int setId,
      required int rallyId,
      required int ordine,
      required DateTime timestamp,
      required Squadra squadra,
      required TipoAzione tipo,
      Value<int?> giocatoreId,
      Value<Fondamentale?> fondamentale,
      Value<Voto?> voto,
      Value<String> tipoEsecuzione,
      required EsitoPunto esitoPunto,
      Value<double?> traiettoriaX1,
      Value<double?> traiettoriaY1,
      Value<double?> traiettoriaX2,
      Value<double?> traiettoriaY2,
      Value<int?> puntiCasaAlMomento,
      Value<int?> puntiOspitiAlMomento,
    });
typedef $$ScoutActionsTableUpdateCompanionBuilder =
    ScoutActionsCompanion Function({
      Value<int> id,
      Value<int> setId,
      Value<int> rallyId,
      Value<int> ordine,
      Value<DateTime> timestamp,
      Value<Squadra> squadra,
      Value<TipoAzione> tipo,
      Value<int?> giocatoreId,
      Value<Fondamentale?> fondamentale,
      Value<Voto?> voto,
      Value<String> tipoEsecuzione,
      Value<EsitoPunto> esitoPunto,
      Value<double?> traiettoriaX1,
      Value<double?> traiettoriaY1,
      Value<double?> traiettoriaX2,
      Value<double?> traiettoriaY2,
      Value<int?> puntiCasaAlMomento,
      Value<int?> puntiOspitiAlMomento,
    });

final class $$ScoutActionsTableReferences
    extends BaseReferences<_$AppDatabase, $ScoutActionsTable, ScoutAction> {
  $$ScoutActionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MatchSetsTable _setIdTable(_$AppDatabase db) =>
      db.matchSets.createAlias('scout_actions__set_id__match_sets__id');

  $$MatchSetsTableProcessedTableManager get setId {
    final $_column = $_itemColumn<int>('set_id')!;

    final manager = $$MatchSetsTableTableManager(
      $_db,
      $_db.matchSets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_setIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PlayersTable _giocatoreIdTable(_$AppDatabase db) =>
      db.players.createAlias('scout_actions__giocatore_id__players__id');

  $$PlayersTableProcessedTableManager? get giocatoreId {
    final $_column = $_itemColumn<int>('giocatore_id');
    if ($_column == null) return null;
    final manager = $$PlayersTableTableManager(
      $_db,
      $_db.players,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_giocatoreIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ScoutActionsTableFilterComposer
    extends Composer<_$AppDatabase, $ScoutActionsTable> {
  $$ScoutActionsTableFilterComposer({
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

  ColumnFilters<int> get rallyId => $composableBuilder(
    column: $table.rallyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ordine => $composableBuilder(
    column: $table.ordine,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Squadra, Squadra, String> get squadra =>
      $composableBuilder(
        column: $table.squadra,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<TipoAzione, TipoAzione, String> get tipo =>
      $composableBuilder(
        column: $table.tipo,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<Fondamentale?, Fondamentale, String>
  get fondamentale => $composableBuilder(
    column: $table.fondamentale,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<Voto?, Voto, String> get voto =>
      $composableBuilder(
        column: $table.voto,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get tipoEsecuzione => $composableBuilder(
    column: $table.tipoEsecuzione,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<EsitoPunto, EsitoPunto, String>
  get esitoPunto => $composableBuilder(
    column: $table.esitoPunto,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<double> get traiettoriaX1 => $composableBuilder(
    column: $table.traiettoriaX1,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get traiettoriaY1 => $composableBuilder(
    column: $table.traiettoriaY1,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get traiettoriaX2 => $composableBuilder(
    column: $table.traiettoriaX2,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get traiettoriaY2 => $composableBuilder(
    column: $table.traiettoriaY2,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get puntiCasaAlMomento => $composableBuilder(
    column: $table.puntiCasaAlMomento,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get puntiOspitiAlMomento => $composableBuilder(
    column: $table.puntiOspitiAlMomento,
    builder: (column) => ColumnFilters(column),
  );

  $$MatchSetsTableFilterComposer get setId {
    final $$MatchSetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setId,
      referencedTable: $db.matchSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchSetsTableFilterComposer(
            $db: $db,
            $table: $db.matchSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PlayersTableFilterComposer get giocatoreId {
    final $$PlayersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.giocatoreId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
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
    return composer;
  }
}

class $$ScoutActionsTableOrderingComposer
    extends Composer<_$AppDatabase, $ScoutActionsTable> {
  $$ScoutActionsTableOrderingComposer({
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

  ColumnOrderings<int> get rallyId => $composableBuilder(
    column: $table.rallyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ordine => $composableBuilder(
    column: $table.ordine,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get squadra => $composableBuilder(
    column: $table.squadra,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tipo => $composableBuilder(
    column: $table.tipo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fondamentale => $composableBuilder(
    column: $table.fondamentale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get voto => $composableBuilder(
    column: $table.voto,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tipoEsecuzione => $composableBuilder(
    column: $table.tipoEsecuzione,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get esitoPunto => $composableBuilder(
    column: $table.esitoPunto,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get traiettoriaX1 => $composableBuilder(
    column: $table.traiettoriaX1,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get traiettoriaY1 => $composableBuilder(
    column: $table.traiettoriaY1,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get traiettoriaX2 => $composableBuilder(
    column: $table.traiettoriaX2,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get traiettoriaY2 => $composableBuilder(
    column: $table.traiettoriaY2,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get puntiCasaAlMomento => $composableBuilder(
    column: $table.puntiCasaAlMomento,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get puntiOspitiAlMomento => $composableBuilder(
    column: $table.puntiOspitiAlMomento,
    builder: (column) => ColumnOrderings(column),
  );

  $$MatchSetsTableOrderingComposer get setId {
    final $$MatchSetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setId,
      referencedTable: $db.matchSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchSetsTableOrderingComposer(
            $db: $db,
            $table: $db.matchSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PlayersTableOrderingComposer get giocatoreId {
    final $$PlayersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.giocatoreId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableOrderingComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ScoutActionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScoutActionsTable> {
  $$ScoutActionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get rallyId =>
      $composableBuilder(column: $table.rallyId, builder: (column) => column);

  GeneratedColumn<int> get ordine =>
      $composableBuilder(column: $table.ordine, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Squadra, String> get squadra =>
      $composableBuilder(column: $table.squadra, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TipoAzione, String> get tipo =>
      $composableBuilder(column: $table.tipo, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Fondamentale?, String> get fondamentale =>
      $composableBuilder(
        column: $table.fondamentale,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<Voto?, String> get voto =>
      $composableBuilder(column: $table.voto, builder: (column) => column);

  GeneratedColumn<String> get tipoEsecuzione => $composableBuilder(
    column: $table.tipoEsecuzione,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<EsitoPunto, String> get esitoPunto =>
      $composableBuilder(
        column: $table.esitoPunto,
        builder: (column) => column,
      );

  GeneratedColumn<double> get traiettoriaX1 => $composableBuilder(
    column: $table.traiettoriaX1,
    builder: (column) => column,
  );

  GeneratedColumn<double> get traiettoriaY1 => $composableBuilder(
    column: $table.traiettoriaY1,
    builder: (column) => column,
  );

  GeneratedColumn<double> get traiettoriaX2 => $composableBuilder(
    column: $table.traiettoriaX2,
    builder: (column) => column,
  );

  GeneratedColumn<double> get traiettoriaY2 => $composableBuilder(
    column: $table.traiettoriaY2,
    builder: (column) => column,
  );

  GeneratedColumn<int> get puntiCasaAlMomento => $composableBuilder(
    column: $table.puntiCasaAlMomento,
    builder: (column) => column,
  );

  GeneratedColumn<int> get puntiOspitiAlMomento => $composableBuilder(
    column: $table.puntiOspitiAlMomento,
    builder: (column) => column,
  );

  $$MatchSetsTableAnnotationComposer get setId {
    final $$MatchSetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setId,
      referencedTable: $db.matchSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchSetsTableAnnotationComposer(
            $db: $db,
            $table: $db.matchSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PlayersTableAnnotationComposer get giocatoreId {
    final $$PlayersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.giocatoreId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
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
    return composer;
  }
}

class $$ScoutActionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScoutActionsTable,
          ScoutAction,
          $$ScoutActionsTableFilterComposer,
          $$ScoutActionsTableOrderingComposer,
          $$ScoutActionsTableAnnotationComposer,
          $$ScoutActionsTableCreateCompanionBuilder,
          $$ScoutActionsTableUpdateCompanionBuilder,
          (ScoutAction, $$ScoutActionsTableReferences),
          ScoutAction,
          PrefetchHooks Function({bool setId, bool giocatoreId})
        > {
  $$ScoutActionsTableTableManager(_$AppDatabase db, $ScoutActionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScoutActionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScoutActionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScoutActionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> setId = const Value.absent(),
                Value<int> rallyId = const Value.absent(),
                Value<int> ordine = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<Squadra> squadra = const Value.absent(),
                Value<TipoAzione> tipo = const Value.absent(),
                Value<int?> giocatoreId = const Value.absent(),
                Value<Fondamentale?> fondamentale = const Value.absent(),
                Value<Voto?> voto = const Value.absent(),
                Value<String> tipoEsecuzione = const Value.absent(),
                Value<EsitoPunto> esitoPunto = const Value.absent(),
                Value<double?> traiettoriaX1 = const Value.absent(),
                Value<double?> traiettoriaY1 = const Value.absent(),
                Value<double?> traiettoriaX2 = const Value.absent(),
                Value<double?> traiettoriaY2 = const Value.absent(),
                Value<int?> puntiCasaAlMomento = const Value.absent(),
                Value<int?> puntiOspitiAlMomento = const Value.absent(),
              }) => ScoutActionsCompanion(
                id: id,
                setId: setId,
                rallyId: rallyId,
                ordine: ordine,
                timestamp: timestamp,
                squadra: squadra,
                tipo: tipo,
                giocatoreId: giocatoreId,
                fondamentale: fondamentale,
                voto: voto,
                tipoEsecuzione: tipoEsecuzione,
                esitoPunto: esitoPunto,
                traiettoriaX1: traiettoriaX1,
                traiettoriaY1: traiettoriaY1,
                traiettoriaX2: traiettoriaX2,
                traiettoriaY2: traiettoriaY2,
                puntiCasaAlMomento: puntiCasaAlMomento,
                puntiOspitiAlMomento: puntiOspitiAlMomento,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int setId,
                required int rallyId,
                required int ordine,
                required DateTime timestamp,
                required Squadra squadra,
                required TipoAzione tipo,
                Value<int?> giocatoreId = const Value.absent(),
                Value<Fondamentale?> fondamentale = const Value.absent(),
                Value<Voto?> voto = const Value.absent(),
                Value<String> tipoEsecuzione = const Value.absent(),
                required EsitoPunto esitoPunto,
                Value<double?> traiettoriaX1 = const Value.absent(),
                Value<double?> traiettoriaY1 = const Value.absent(),
                Value<double?> traiettoriaX2 = const Value.absent(),
                Value<double?> traiettoriaY2 = const Value.absent(),
                Value<int?> puntiCasaAlMomento = const Value.absent(),
                Value<int?> puntiOspitiAlMomento = const Value.absent(),
              }) => ScoutActionsCompanion.insert(
                id: id,
                setId: setId,
                rallyId: rallyId,
                ordine: ordine,
                timestamp: timestamp,
                squadra: squadra,
                tipo: tipo,
                giocatoreId: giocatoreId,
                fondamentale: fondamentale,
                voto: voto,
                tipoEsecuzione: tipoEsecuzione,
                esitoPunto: esitoPunto,
                traiettoriaX1: traiettoriaX1,
                traiettoriaY1: traiettoriaY1,
                traiettoriaX2: traiettoriaX2,
                traiettoriaY2: traiettoriaY2,
                puntiCasaAlMomento: puntiCasaAlMomento,
                puntiOspitiAlMomento: puntiOspitiAlMomento,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ScoutActionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({setId = false, giocatoreId = false}) {
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
                    if (setId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.setId,
                                referencedTable: $$ScoutActionsTableReferences
                                    ._setIdTable(db),
                                referencedColumn: $$ScoutActionsTableReferences
                                    ._setIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (giocatoreId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.giocatoreId,
                                referencedTable: $$ScoutActionsTableReferences
                                    ._giocatoreIdTable(db),
                                referencedColumn: $$ScoutActionsTableReferences
                                    ._giocatoreIdTable(db)
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

typedef $$ScoutActionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScoutActionsTable,
      ScoutAction,
      $$ScoutActionsTableFilterComposer,
      $$ScoutActionsTableOrderingComposer,
      $$ScoutActionsTableAnnotationComposer,
      $$ScoutActionsTableCreateCompanionBuilder,
      $$ScoutActionsTableUpdateCompanionBuilder,
      (ScoutAction, $$ScoutActionsTableReferences),
      ScoutAction,
      PrefetchHooks Function({bool setId, bool giocatoreId})
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
  $$MatchSetsTableTableManager get matchSets =>
      $$MatchSetsTableTableManager(_db, _db.matchSets);
  $$RotationsTableTableManager get rotations =>
      $$RotationsTableTableManager(_db, _db.rotations);
  $$ScoutActionsTableTableManager get scoutActions =>
      $$ScoutActionsTableTableManager(_db, _db.scoutActions);
}

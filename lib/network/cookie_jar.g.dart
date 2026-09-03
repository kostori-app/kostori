// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cookie_jar.dart';

// ignore_for_file: type=lint
class $CookiesTableTable extends CookiesTable
    with TableInfo<$CookiesTableTable, CookiesTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CookiesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _domainMeta = const VerificationMeta('domain');
  @override
  late final GeneratedColumn<String> domain = GeneratedColumn<String>(
    'domain',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _expiresMeta = const VerificationMeta(
    'expires',
  );
  @override
  late final GeneratedColumn<int> expires = GeneratedColumn<int>(
    'expires',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _secureMeta = const VerificationMeta('secure');
  @override
  late final GeneratedColumn<bool> secure = GeneratedColumn<bool>(
    'secure',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("secure" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _httpOnlyMeta = const VerificationMeta(
    'httpOnly',
  );
  @override
  late final GeneratedColumn<bool> httpOnly = GeneratedColumn<bool>(
    'httpOnly',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("httpOnly" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    name,
    value,
    domain,
    path,
    expires,
    secure,
    httpOnly,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cookies';
  @override
  VerificationContext validateIntegrity(
    Insertable<CookiesTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('domain')) {
      context.handle(
        _domainMeta,
        domain.isAcceptableOrUnknown(data['domain']!, _domainMeta),
      );
    } else if (isInserting) {
      context.missing(_domainMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    }
    if (data.containsKey('expires')) {
      context.handle(
        _expiresMeta,
        expires.isAcceptableOrUnknown(data['expires']!, _expiresMeta),
      );
    }
    if (data.containsKey('secure')) {
      context.handle(
        _secureMeta,
        secure.isAcceptableOrUnknown(data['secure']!, _secureMeta),
      );
    }
    if (data.containsKey('httpOnly')) {
      context.handle(
        _httpOnlyMeta,
        httpOnly.isAcceptableOrUnknown(data['httpOnly']!, _httpOnlyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {name, domain, path};
  @override
  CookiesTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CookiesTableData(
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      domain: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}domain'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      ),
      expires: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expires'],
      ),
      secure: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}secure'],
      )!,
      httpOnly: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}httpOnly'],
      )!,
    );
  }

  @override
  $CookiesTableTable createAlias(String alias) {
    return $CookiesTableTable(attachedDatabase, alias);
  }
}

class CookiesTableData extends DataClass
    implements Insertable<CookiesTableData> {
  final String name;
  final String value;
  final String domain;
  final String? path;
  final int? expires;
  final bool secure;
  final bool httpOnly;
  const CookiesTableData({
    required this.name,
    required this.value,
    required this.domain,
    this.path,
    this.expires,
    required this.secure,
    required this.httpOnly,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['name'] = Variable<String>(name);
    map['value'] = Variable<String>(value);
    map['domain'] = Variable<String>(domain);
    if (!nullToAbsent || path != null) {
      map['path'] = Variable<String>(path);
    }
    if (!nullToAbsent || expires != null) {
      map['expires'] = Variable<int>(expires);
    }
    map['secure'] = Variable<bool>(secure);
    map['httpOnly'] = Variable<bool>(httpOnly);
    return map;
  }

  CookiesTableCompanion toCompanion(bool nullToAbsent) {
    return CookiesTableCompanion(
      name: Value(name),
      value: Value(value),
      domain: Value(domain),
      path: path == null && nullToAbsent ? const Value.absent() : Value(path),
      expires: expires == null && nullToAbsent
          ? const Value.absent()
          : Value(expires),
      secure: Value(secure),
      httpOnly: Value(httpOnly),
    );
  }

  factory CookiesTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CookiesTableData(
      name: serializer.fromJson<String>(json['name']),
      value: serializer.fromJson<String>(json['value']),
      domain: serializer.fromJson<String>(json['domain']),
      path: serializer.fromJson<String?>(json['path']),
      expires: serializer.fromJson<int?>(json['expires']),
      secure: serializer.fromJson<bool>(json['secure']),
      httpOnly: serializer.fromJson<bool>(json['httpOnly']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'name': serializer.toJson<String>(name),
      'value': serializer.toJson<String>(value),
      'domain': serializer.toJson<String>(domain),
      'path': serializer.toJson<String?>(path),
      'expires': serializer.toJson<int?>(expires),
      'secure': serializer.toJson<bool>(secure),
      'httpOnly': serializer.toJson<bool>(httpOnly),
    };
  }

  CookiesTableData copyWith({
    String? name,
    String? value,
    String? domain,
    Value<String?> path = const Value.absent(),
    Value<int?> expires = const Value.absent(),
    bool? secure,
    bool? httpOnly,
  }) => CookiesTableData(
    name: name ?? this.name,
    value: value ?? this.value,
    domain: domain ?? this.domain,
    path: path.present ? path.value : this.path,
    expires: expires.present ? expires.value : this.expires,
    secure: secure ?? this.secure,
    httpOnly: httpOnly ?? this.httpOnly,
  );
  CookiesTableData copyWithCompanion(CookiesTableCompanion data) {
    return CookiesTableData(
      name: data.name.present ? data.name.value : this.name,
      value: data.value.present ? data.value.value : this.value,
      domain: data.domain.present ? data.domain.value : this.domain,
      path: data.path.present ? data.path.value : this.path,
      expires: data.expires.present ? data.expires.value : this.expires,
      secure: data.secure.present ? data.secure.value : this.secure,
      httpOnly: data.httpOnly.present ? data.httpOnly.value : this.httpOnly,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CookiesTableData(')
          ..write('name: $name, ')
          ..write('value: $value, ')
          ..write('domain: $domain, ')
          ..write('path: $path, ')
          ..write('expires: $expires, ')
          ..write('secure: $secure, ')
          ..write('httpOnly: $httpOnly')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(name, value, domain, path, expires, secure, httpOnly);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CookiesTableData &&
          other.name == this.name &&
          other.value == this.value &&
          other.domain == this.domain &&
          other.path == this.path &&
          other.expires == this.expires &&
          other.secure == this.secure &&
          other.httpOnly == this.httpOnly);
}

class CookiesTableCompanion extends UpdateCompanion<CookiesTableData> {
  final Value<String> name;
  final Value<String> value;
  final Value<String> domain;
  final Value<String?> path;
  final Value<int?> expires;
  final Value<bool> secure;
  final Value<bool> httpOnly;
  final Value<int> rowid;
  const CookiesTableCompanion({
    this.name = const Value.absent(),
    this.value = const Value.absent(),
    this.domain = const Value.absent(),
    this.path = const Value.absent(),
    this.expires = const Value.absent(),
    this.secure = const Value.absent(),
    this.httpOnly = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CookiesTableCompanion.insert({
    required String name,
    required String value,
    required String domain,
    this.path = const Value.absent(),
    this.expires = const Value.absent(),
    this.secure = const Value.absent(),
    this.httpOnly = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : name = Value(name),
       value = Value(value),
       domain = Value(domain);
  static Insertable<CookiesTableData> custom({
    Expression<String>? name,
    Expression<String>? value,
    Expression<String>? domain,
    Expression<String>? path,
    Expression<int>? expires,
    Expression<bool>? secure,
    Expression<bool>? httpOnly,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (name != null) 'name': name,
      if (value != null) 'value': value,
      if (domain != null) 'domain': domain,
      if (path != null) 'path': path,
      if (expires != null) 'expires': expires,
      if (secure != null) 'secure': secure,
      if (httpOnly != null) 'httpOnly': httpOnly,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CookiesTableCompanion copyWith({
    Value<String>? name,
    Value<String>? value,
    Value<String>? domain,
    Value<String?>? path,
    Value<int?>? expires,
    Value<bool>? secure,
    Value<bool>? httpOnly,
    Value<int>? rowid,
  }) {
    return CookiesTableCompanion(
      name: name ?? this.name,
      value: value ?? this.value,
      domain: domain ?? this.domain,
      path: path ?? this.path,
      expires: expires ?? this.expires,
      secure: secure ?? this.secure,
      httpOnly: httpOnly ?? this.httpOnly,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (domain.present) {
      map['domain'] = Variable<String>(domain.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (expires.present) {
      map['expires'] = Variable<int>(expires.value);
    }
    if (secure.present) {
      map['secure'] = Variable<bool>(secure.value);
    }
    if (httpOnly.present) {
      map['httpOnly'] = Variable<bool>(httpOnly.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CookiesTableCompanion(')
          ..write('name: $name, ')
          ..write('value: $value, ')
          ..write('domain: $domain, ')
          ..write('path: $path, ')
          ..write('expires: $expires, ')
          ..write('secure: $secure, ')
          ..write('httpOnly: $httpOnly, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$_CookieDb extends GeneratedDatabase {
  _$_CookieDb(QueryExecutor e) : super(e);
  $_CookieDbManager get managers => $_CookieDbManager(this);
  late final $CookiesTableTable cookiesTable = $CookiesTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [cookiesTable];
}

typedef $$CookiesTableTableCreateCompanionBuilder =
    CookiesTableCompanion Function({
      required String name,
      required String value,
      required String domain,
      Value<String?> path,
      Value<int?> expires,
      Value<bool> secure,
      Value<bool> httpOnly,
      Value<int> rowid,
    });
typedef $$CookiesTableTableUpdateCompanionBuilder =
    CookiesTableCompanion Function({
      Value<String> name,
      Value<String> value,
      Value<String> domain,
      Value<String?> path,
      Value<int?> expires,
      Value<bool> secure,
      Value<bool> httpOnly,
      Value<int> rowid,
    });

class $$CookiesTableTableFilterComposer
    extends Composer<_$_CookieDb, $CookiesTableTable> {
  $$CookiesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get domain => $composableBuilder(
    column: $table.domain,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expires => $composableBuilder(
    column: $table.expires,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get secure => $composableBuilder(
    column: $table.secure,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get httpOnly => $composableBuilder(
    column: $table.httpOnly,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CookiesTableTableOrderingComposer
    extends Composer<_$_CookieDb, $CookiesTableTable> {
  $$CookiesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get domain => $composableBuilder(
    column: $table.domain,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expires => $composableBuilder(
    column: $table.expires,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get secure => $composableBuilder(
    column: $table.secure,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get httpOnly => $composableBuilder(
    column: $table.httpOnly,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CookiesTableTableAnnotationComposer
    extends Composer<_$_CookieDb, $CookiesTableTable> {
  $$CookiesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get domain =>
      $composableBuilder(column: $table.domain, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<int> get expires =>
      $composableBuilder(column: $table.expires, builder: (column) => column);

  GeneratedColumn<bool> get secure =>
      $composableBuilder(column: $table.secure, builder: (column) => column);

  GeneratedColumn<bool> get httpOnly =>
      $composableBuilder(column: $table.httpOnly, builder: (column) => column);
}

class $$CookiesTableTableTableManager
    extends
        RootTableManager<
          _$_CookieDb,
          $CookiesTableTable,
          CookiesTableData,
          $$CookiesTableTableFilterComposer,
          $$CookiesTableTableOrderingComposer,
          $$CookiesTableTableAnnotationComposer,
          $$CookiesTableTableCreateCompanionBuilder,
          $$CookiesTableTableUpdateCompanionBuilder,
          (
            CookiesTableData,
            BaseReferences<_$_CookieDb, $CookiesTableTable, CookiesTableData>,
          ),
          CookiesTableData,
          PrefetchHooks Function()
        > {
  $$CookiesTableTableTableManager(_$_CookieDb db, $CookiesTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CookiesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CookiesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CookiesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> name = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<String> domain = const Value.absent(),
                Value<String?> path = const Value.absent(),
                Value<int?> expires = const Value.absent(),
                Value<bool> secure = const Value.absent(),
                Value<bool> httpOnly = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CookiesTableCompanion(
                name: name,
                value: value,
                domain: domain,
                path: path,
                expires: expires,
                secure: secure,
                httpOnly: httpOnly,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String name,
                required String value,
                required String domain,
                Value<String?> path = const Value.absent(),
                Value<int?> expires = const Value.absent(),
                Value<bool> secure = const Value.absent(),
                Value<bool> httpOnly = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CookiesTableCompanion.insert(
                name: name,
                value: value,
                domain: domain,
                path: path,
                expires: expires,
                secure: secure,
                httpOnly: httpOnly,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CookiesTableTable, CookiesTableData>(table),
                  BaseReferences<
                    _$_CookieDb,
                    $CookiesTableTable,
                    CookiesTableData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CookiesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$_CookieDb,
      $CookiesTableTable,
      CookiesTableData,
      $$CookiesTableTableFilterComposer,
      $$CookiesTableTableOrderingComposer,
      $$CookiesTableTableAnnotationComposer,
      $$CookiesTableTableCreateCompanionBuilder,
      $$CookiesTableTableUpdateCompanionBuilder,
      (
        CookiesTableData,
        BaseReferences<_$_CookieDb, $CookiesTableTable, CookiesTableData>,
      ),
      CookiesTableData,
      PrefetchHooks Function()
    >;

class $_CookieDbManager {
  final _$_CookieDb _db;
  $_CookieDbManager(this._db);
  $$CookiesTableTableTableManager get cookiesTable =>
      $$CookiesTableTableTableManager(_db, _db.cookiesTable);
}

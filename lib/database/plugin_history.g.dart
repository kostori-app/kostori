// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plugin_history.dart';

// ignore_for_file: type=lint
class $PluginEventTableTable extends PluginEventTable
    with TableInfo<$PluginEventTableTable, PluginEventTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PluginEventTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pluginKeyMeta = const VerificationMeta(
    'pluginKey',
  );
  @override
  late final GeneratedColumn<String> pluginKey = GeneratedColumn<String>(
    'plugin_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemKeyMeta = const VerificationMeta(
    'itemKey',
  );
  @override
  late final GeneratedColumn<String> itemKey = GeneratedColumn<String>(
    'item_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subtitleMeta = const VerificationMeta(
    'subtitle',
  );
  @override
  late final GeneratedColumn<String> subtitle = GeneratedColumn<String>(
    'subtitle',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _coverUrlMeta = const VerificationMeta(
    'coverUrl',
  );
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
    'cover_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _extraJsonMeta = const VerificationMeta(
    'extraJson',
  );
  @override
  late final GeneratedColumn<String> extraJson = GeneratedColumn<String>(
    'extra_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    pluginKey,
    kind,
    itemKey,
    title,
    subtitle,
    coverUrl,
    extraJson,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'plugin_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<PluginEventTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('plugin_key')) {
      context.handle(
        _pluginKeyMeta,
        pluginKey.isAcceptableOrUnknown(data['plugin_key']!, _pluginKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_pluginKeyMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('item_key')) {
      context.handle(
        _itemKeyMeta,
        itemKey.isAcceptableOrUnknown(data['item_key']!, _itemKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_itemKeyMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('subtitle')) {
      context.handle(
        _subtitleMeta,
        subtitle.isAcceptableOrUnknown(data['subtitle']!, _subtitleMeta),
      );
    }
    if (data.containsKey('cover_url')) {
      context.handle(
        _coverUrlMeta,
        coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta),
      );
    }
    if (data.containsKey('extra_json')) {
      context.handle(
        _extraJsonMeta,
        extraJson.isAcceptableOrUnknown(data['extra_json']!, _extraJsonMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {pluginKey, kind, itemKey};
  @override
  PluginEventTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PluginEventTableData(
      pluginKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plugin_key'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      itemKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_key'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      subtitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subtitle'],
      )!,
      coverUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_url'],
      )!,
      extraJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extra_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PluginEventTableTable createAlias(String alias) {
    return $PluginEventTableTable(attachedDatabase, alias);
  }
}

class PluginEventTableData extends DataClass
    implements Insertable<PluginEventTableData> {
  final String pluginKey;

  /// open | search
  final String kind;
  final String itemKey;
  final String title;
  final String subtitle;
  final String coverUrl;

  /// 用于恢复原页的 JSON（page/params/item）
  final String extraJson;
  final int createdAt;
  const PluginEventTableData({
    required this.pluginKey,
    required this.kind,
    required this.itemKey,
    required this.title,
    required this.subtitle,
    required this.coverUrl,
    required this.extraJson,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['plugin_key'] = Variable<String>(pluginKey);
    map['kind'] = Variable<String>(kind);
    map['item_key'] = Variable<String>(itemKey);
    map['title'] = Variable<String>(title);
    map['subtitle'] = Variable<String>(subtitle);
    map['cover_url'] = Variable<String>(coverUrl);
    map['extra_json'] = Variable<String>(extraJson);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  PluginEventTableCompanion toCompanion(bool nullToAbsent) {
    return PluginEventTableCompanion(
      pluginKey: Value(pluginKey),
      kind: Value(kind),
      itemKey: Value(itemKey),
      title: Value(title),
      subtitle: Value(subtitle),
      coverUrl: Value(coverUrl),
      extraJson: Value(extraJson),
      createdAt: Value(createdAt),
    );
  }

  factory PluginEventTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PluginEventTableData(
      pluginKey: serializer.fromJson<String>(json['pluginKey']),
      kind: serializer.fromJson<String>(json['kind']),
      itemKey: serializer.fromJson<String>(json['itemKey']),
      title: serializer.fromJson<String>(json['title']),
      subtitle: serializer.fromJson<String>(json['subtitle']),
      coverUrl: serializer.fromJson<String>(json['coverUrl']),
      extraJson: serializer.fromJson<String>(json['extraJson']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'pluginKey': serializer.toJson<String>(pluginKey),
      'kind': serializer.toJson<String>(kind),
      'itemKey': serializer.toJson<String>(itemKey),
      'title': serializer.toJson<String>(title),
      'subtitle': serializer.toJson<String>(subtitle),
      'coverUrl': serializer.toJson<String>(coverUrl),
      'extraJson': serializer.toJson<String>(extraJson),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  PluginEventTableData copyWith({
    String? pluginKey,
    String? kind,
    String? itemKey,
    String? title,
    String? subtitle,
    String? coverUrl,
    String? extraJson,
    int? createdAt,
  }) => PluginEventTableData(
    pluginKey: pluginKey ?? this.pluginKey,
    kind: kind ?? this.kind,
    itemKey: itemKey ?? this.itemKey,
    title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle,
    coverUrl: coverUrl ?? this.coverUrl,
    extraJson: extraJson ?? this.extraJson,
    createdAt: createdAt ?? this.createdAt,
  );
  PluginEventTableData copyWithCompanion(PluginEventTableCompanion data) {
    return PluginEventTableData(
      pluginKey: data.pluginKey.present ? data.pluginKey.value : this.pluginKey,
      kind: data.kind.present ? data.kind.value : this.kind,
      itemKey: data.itemKey.present ? data.itemKey.value : this.itemKey,
      title: data.title.present ? data.title.value : this.title,
      subtitle: data.subtitle.present ? data.subtitle.value : this.subtitle,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      extraJson: data.extraJson.present ? data.extraJson.value : this.extraJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PluginEventTableData(')
          ..write('pluginKey: $pluginKey, ')
          ..write('kind: $kind, ')
          ..write('itemKey: $itemKey, ')
          ..write('title: $title, ')
          ..write('subtitle: $subtitle, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('extraJson: $extraJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    pluginKey,
    kind,
    itemKey,
    title,
    subtitle,
    coverUrl,
    extraJson,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PluginEventTableData &&
          other.pluginKey == this.pluginKey &&
          other.kind == this.kind &&
          other.itemKey == this.itemKey &&
          other.title == this.title &&
          other.subtitle == this.subtitle &&
          other.coverUrl == this.coverUrl &&
          other.extraJson == this.extraJson &&
          other.createdAt == this.createdAt);
}

class PluginEventTableCompanion extends UpdateCompanion<PluginEventTableData> {
  final Value<String> pluginKey;
  final Value<String> kind;
  final Value<String> itemKey;
  final Value<String> title;
  final Value<String> subtitle;
  final Value<String> coverUrl;
  final Value<String> extraJson;
  final Value<int> createdAt;
  final Value<int> rowid;
  const PluginEventTableCompanion({
    this.pluginKey = const Value.absent(),
    this.kind = const Value.absent(),
    this.itemKey = const Value.absent(),
    this.title = const Value.absent(),
    this.subtitle = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.extraJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PluginEventTableCompanion.insert({
    required String pluginKey,
    required String kind,
    required String itemKey,
    required String title,
    this.subtitle = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.extraJson = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : pluginKey = Value(pluginKey),
       kind = Value(kind),
       itemKey = Value(itemKey),
       title = Value(title),
       createdAt = Value(createdAt);
  static Insertable<PluginEventTableData> custom({
    Expression<String>? pluginKey,
    Expression<String>? kind,
    Expression<String>? itemKey,
    Expression<String>? title,
    Expression<String>? subtitle,
    Expression<String>? coverUrl,
    Expression<String>? extraJson,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (pluginKey != null) 'plugin_key': pluginKey,
      if (kind != null) 'kind': kind,
      if (itemKey != null) 'item_key': itemKey,
      if (title != null) 'title': title,
      if (subtitle != null) 'subtitle': subtitle,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (extraJson != null) 'extra_json': extraJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PluginEventTableCompanion copyWith({
    Value<String>? pluginKey,
    Value<String>? kind,
    Value<String>? itemKey,
    Value<String>? title,
    Value<String>? subtitle,
    Value<String>? coverUrl,
    Value<String>? extraJson,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return PluginEventTableCompanion(
      pluginKey: pluginKey ?? this.pluginKey,
      kind: kind ?? this.kind,
      itemKey: itemKey ?? this.itemKey,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      coverUrl: coverUrl ?? this.coverUrl,
      extraJson: extraJson ?? this.extraJson,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (pluginKey.present) {
      map['plugin_key'] = Variable<String>(pluginKey.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (itemKey.present) {
      map['item_key'] = Variable<String>(itemKey.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (subtitle.present) {
      map['subtitle'] = Variable<String>(subtitle.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (extraJson.present) {
      map['extra_json'] = Variable<String>(extraJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PluginEventTableCompanion(')
          ..write('pluginKey: $pluginKey, ')
          ..write('kind: $kind, ')
          ..write('itemKey: $itemKey, ')
          ..write('title: $title, ')
          ..write('subtitle: $subtitle, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('extraJson: $extraJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$_PluginHistoryDb extends GeneratedDatabase {
  _$_PluginHistoryDb(QueryExecutor e) : super(e);
  $_PluginHistoryDbManager get managers => $_PluginHistoryDbManager(this);
  late final $PluginEventTableTable pluginEventTable = $PluginEventTableTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [pluginEventTable];
}

typedef $$PluginEventTableTableCreateCompanionBuilder =
    PluginEventTableCompanion Function({
      required String pluginKey,
      required String kind,
      required String itemKey,
      required String title,
      Value<String> subtitle,
      Value<String> coverUrl,
      Value<String> extraJson,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$PluginEventTableTableUpdateCompanionBuilder =
    PluginEventTableCompanion Function({
      Value<String> pluginKey,
      Value<String> kind,
      Value<String> itemKey,
      Value<String> title,
      Value<String> subtitle,
      Value<String> coverUrl,
      Value<String> extraJson,
      Value<int> createdAt,
      Value<int> rowid,
    });

class $$PluginEventTableTableFilterComposer
    extends Composer<_$_PluginHistoryDb, $PluginEventTableTable> {
  $$PluginEventTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get pluginKey => $composableBuilder(
    column: $table.pluginKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemKey => $composableBuilder(
    column: $table.itemKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subtitle => $composableBuilder(
    column: $table.subtitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extraJson => $composableBuilder(
    column: $table.extraJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PluginEventTableTableOrderingComposer
    extends Composer<_$_PluginHistoryDb, $PluginEventTableTable> {
  $$PluginEventTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get pluginKey => $composableBuilder(
    column: $table.pluginKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemKey => $composableBuilder(
    column: $table.itemKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subtitle => $composableBuilder(
    column: $table.subtitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extraJson => $composableBuilder(
    column: $table.extraJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PluginEventTableTableAnnotationComposer
    extends Composer<_$_PluginHistoryDb, $PluginEventTableTable> {
  $$PluginEventTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get pluginKey =>
      $composableBuilder(column: $table.pluginKey, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get itemKey =>
      $composableBuilder(column: $table.itemKey, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get subtitle =>
      $composableBuilder(column: $table.subtitle, builder: (column) => column);

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<String> get extraJson =>
      $composableBuilder(column: $table.extraJson, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$PluginEventTableTableTableManager
    extends
        RootTableManager<
          _$_PluginHistoryDb,
          $PluginEventTableTable,
          PluginEventTableData,
          $$PluginEventTableTableFilterComposer,
          $$PluginEventTableTableOrderingComposer,
          $$PluginEventTableTableAnnotationComposer,
          $$PluginEventTableTableCreateCompanionBuilder,
          $$PluginEventTableTableUpdateCompanionBuilder,
          (
            PluginEventTableData,
            BaseReferences<
              _$_PluginHistoryDb,
              $PluginEventTableTable,
              PluginEventTableData
            >,
          ),
          PluginEventTableData,
          PrefetchHooks Function()
        > {
  $$PluginEventTableTableTableManager(
    _$_PluginHistoryDb db,
    $PluginEventTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PluginEventTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PluginEventTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PluginEventTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> pluginKey = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> itemKey = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> subtitle = const Value.absent(),
                Value<String> coverUrl = const Value.absent(),
                Value<String> extraJson = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PluginEventTableCompanion(
                pluginKey: pluginKey,
                kind: kind,
                itemKey: itemKey,
                title: title,
                subtitle: subtitle,
                coverUrl: coverUrl,
                extraJson: extraJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String pluginKey,
                required String kind,
                required String itemKey,
                required String title,
                Value<String> subtitle = const Value.absent(),
                Value<String> coverUrl = const Value.absent(),
                Value<String> extraJson = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => PluginEventTableCompanion.insert(
                pluginKey: pluginKey,
                kind: kind,
                itemKey: itemKey,
                title: title,
                subtitle: subtitle,
                coverUrl: coverUrl,
                extraJson: extraJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PluginEventTableTable, PluginEventTableData>(
                    table,
                  ),
                  BaseReferences<
                    _$_PluginHistoryDb,
                    $PluginEventTableTable,
                    PluginEventTableData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PluginEventTableTableProcessedTableManager =
    ProcessedTableManager<
      _$_PluginHistoryDb,
      $PluginEventTableTable,
      PluginEventTableData,
      $$PluginEventTableTableFilterComposer,
      $$PluginEventTableTableOrderingComposer,
      $$PluginEventTableTableAnnotationComposer,
      $$PluginEventTableTableCreateCompanionBuilder,
      $$PluginEventTableTableUpdateCompanionBuilder,
      (
        PluginEventTableData,
        BaseReferences<
          _$_PluginHistoryDb,
          $PluginEventTableTable,
          PluginEventTableData
        >,
      ),
      PluginEventTableData,
      PrefetchHooks Function()
    >;

class $_PluginHistoryDbManager {
  final _$_PluginHistoryDb _db;
  $_PluginHistoryDbManager(this._db);
  $$PluginEventTableTableTableManager get pluginEventTable =>
      $$PluginEventTableTableTableManager(_db, _db.pluginEventTable);
}

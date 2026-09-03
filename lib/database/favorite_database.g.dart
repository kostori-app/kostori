// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'favorite_database.dart';

// ignore_for_file: type=lint
class $FavoriteFoldersTable extends FavoriteFolders
    with TableInfo<$FavoriteFoldersTable, FavoriteFolder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavoriteFoldersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, sortOrder];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favorite_folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<FavoriteFolder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FavoriteFolder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FavoriteFolder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $FavoriteFoldersTable createAlias(String alias) {
    return $FavoriteFoldersTable(attachedDatabase, alias);
  }
}

class FavoriteFolder extends DataClass implements Insertable<FavoriteFolder> {
  final String id;
  final String name;
  final int sortOrder;
  const FavoriteFolder({
    required this.id,
    required this.name,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  FavoriteFoldersCompanion toCompanion(bool nullToAbsent) {
    return FavoriteFoldersCompanion(
      id: Value(id),
      name: Value(name),
      sortOrder: Value(sortOrder),
    );
  }

  factory FavoriteFolder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FavoriteFolder(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  FavoriteFolder copyWith({String? id, String? name, int? sortOrder}) =>
      FavoriteFolder(
        id: id ?? this.id,
        name: name ?? this.name,
        sortOrder: sortOrder ?? this.sortOrder,
      );
  FavoriteFolder copyWithCompanion(FavoriteFoldersCompanion data) {
    return FavoriteFolder(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteFolder(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FavoriteFolder &&
          other.id == this.id &&
          other.name == this.name &&
          other.sortOrder == this.sortOrder);
}

class FavoriteFoldersCompanion extends UpdateCompanion<FavoriteFolder> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const FavoriteFoldersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FavoriteFoldersCompanion.insert({
    required String id,
    required String name,
    required int sortOrder,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       sortOrder = Value(sortOrder);
  static Insertable<FavoriteFolder> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FavoriteFoldersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return FavoriteFoldersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteFoldersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FavoriteItemsTable extends FavoriteItems
    with TableInfo<$FavoriteItemsTable, FavoriteItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavoriteItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<String> folderId = GeneratedColumn<String>(
    'folder_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES favorite_folders (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<int> type = GeneratedColumn<int>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverPathMeta = const VerificationMeta(
    'coverPath',
  );
  @override
  late final GeneratedColumn<String> coverPath = GeneratedColumn<String>(
    'cover_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timeMeta = const VerificationMeta('time');
  @override
  late final GeneratedColumn<String> time = GeneratedColumn<String>(
    'time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _displayOrderMeta = const VerificationMeta(
    'displayOrder',
  );
  @override
  late final GeneratedColumn<int> displayOrder = GeneratedColumn<int>(
    'display_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _recentlyWatchedMeta = const VerificationMeta(
    'recentlyWatched',
  );
  @override
  late final GeneratedColumn<String> recentlyWatched = GeneratedColumn<String>(
    'recently_watched',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _viewMoreMeta = const VerificationMeta(
    'viewMore',
  );
  @override
  late final GeneratedColumn<String> viewMore = GeneratedColumn<String>(
    'view_more',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    folderId,
    id,
    name,
    author,
    type,
    tags,
    coverPath,
    time,
    displayOrder,
    recentlyWatched,
    viewMore,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favorite_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<FavoriteItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_folderIdMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('cover_path')) {
      context.handle(
        _coverPathMeta,
        coverPath.isAcceptableOrUnknown(data['cover_path']!, _coverPathMeta),
      );
    }
    if (data.containsKey('time')) {
      context.handle(
        _timeMeta,
        time.isAcceptableOrUnknown(data['time']!, _timeMeta),
      );
    }
    if (data.containsKey('display_order')) {
      context.handle(
        _displayOrderMeta,
        displayOrder.isAcceptableOrUnknown(
          data['display_order']!,
          _displayOrderMeta,
        ),
      );
    }
    if (data.containsKey('recently_watched')) {
      context.handle(
        _recentlyWatchedMeta,
        recentlyWatched.isAcceptableOrUnknown(
          data['recently_watched']!,
          _recentlyWatchedMeta,
        ),
      );
    }
    if (data.containsKey('view_more')) {
      context.handle(
        _viewMoreMeta,
        viewMore.isAcceptableOrUnknown(data['view_more']!, _viewMoreMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {folderId, id, type};
  @override
  FavoriteItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FavoriteItemRow(
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_id'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type'],
      )!,
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      ),
      coverPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_path'],
      ),
      time: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time'],
      ),
      displayOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}display_order'],
      )!,
      recentlyWatched: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recently_watched'],
      ),
      viewMore: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}view_more'],
      ),
    );
  }

  @override
  $FavoriteItemsTable createAlias(String alias) {
    return $FavoriteItemsTable(attachedDatabase, alias);
  }
}

class FavoriteItemRow extends DataClass implements Insertable<FavoriteItemRow> {
  final String folderId;
  final String id;
  final String name;
  final String? author;
  final int type;
  final String? tags;
  final String? coverPath;
  final String? time;
  final int displayOrder;
  final String? recentlyWatched;
  final String? viewMore;
  const FavoriteItemRow({
    required this.folderId,
    required this.id,
    required this.name,
    this.author,
    required this.type,
    this.tags,
    this.coverPath,
    this.time,
    required this.displayOrder,
    this.recentlyWatched,
    this.viewMore,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['folder_id'] = Variable<String>(folderId);
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    map['type'] = Variable<int>(type);
    if (!nullToAbsent || tags != null) {
      map['tags'] = Variable<String>(tags);
    }
    if (!nullToAbsent || coverPath != null) {
      map['cover_path'] = Variable<String>(coverPath);
    }
    if (!nullToAbsent || time != null) {
      map['time'] = Variable<String>(time);
    }
    map['display_order'] = Variable<int>(displayOrder);
    if (!nullToAbsent || recentlyWatched != null) {
      map['recently_watched'] = Variable<String>(recentlyWatched);
    }
    if (!nullToAbsent || viewMore != null) {
      map['view_more'] = Variable<String>(viewMore);
    }
    return map;
  }

  FavoriteItemsCompanion toCompanion(bool nullToAbsent) {
    return FavoriteItemsCompanion(
      folderId: Value(folderId),
      id: Value(id),
      name: Value(name),
      author: author == null && nullToAbsent
          ? const Value.absent()
          : Value(author),
      type: Value(type),
      tags: tags == null && nullToAbsent ? const Value.absent() : Value(tags),
      coverPath: coverPath == null && nullToAbsent
          ? const Value.absent()
          : Value(coverPath),
      time: time == null && nullToAbsent ? const Value.absent() : Value(time),
      displayOrder: Value(displayOrder),
      recentlyWatched: recentlyWatched == null && nullToAbsent
          ? const Value.absent()
          : Value(recentlyWatched),
      viewMore: viewMore == null && nullToAbsent
          ? const Value.absent()
          : Value(viewMore),
    );
  }

  factory FavoriteItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FavoriteItemRow(
      folderId: serializer.fromJson<String>(json['folderId']),
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      author: serializer.fromJson<String?>(json['author']),
      type: serializer.fromJson<int>(json['type']),
      tags: serializer.fromJson<String?>(json['tags']),
      coverPath: serializer.fromJson<String?>(json['coverPath']),
      time: serializer.fromJson<String?>(json['time']),
      displayOrder: serializer.fromJson<int>(json['displayOrder']),
      recentlyWatched: serializer.fromJson<String?>(json['recentlyWatched']),
      viewMore: serializer.fromJson<String?>(json['viewMore']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'folderId': serializer.toJson<String>(folderId),
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'author': serializer.toJson<String?>(author),
      'type': serializer.toJson<int>(type),
      'tags': serializer.toJson<String?>(tags),
      'coverPath': serializer.toJson<String?>(coverPath),
      'time': serializer.toJson<String?>(time),
      'displayOrder': serializer.toJson<int>(displayOrder),
      'recentlyWatched': serializer.toJson<String?>(recentlyWatched),
      'viewMore': serializer.toJson<String?>(viewMore),
    };
  }

  FavoriteItemRow copyWith({
    String? folderId,
    String? id,
    String? name,
    Value<String?> author = const Value.absent(),
    int? type,
    Value<String?> tags = const Value.absent(),
    Value<String?> coverPath = const Value.absent(),
    Value<String?> time = const Value.absent(),
    int? displayOrder,
    Value<String?> recentlyWatched = const Value.absent(),
    Value<String?> viewMore = const Value.absent(),
  }) => FavoriteItemRow(
    folderId: folderId ?? this.folderId,
    id: id ?? this.id,
    name: name ?? this.name,
    author: author.present ? author.value : this.author,
    type: type ?? this.type,
    tags: tags.present ? tags.value : this.tags,
    coverPath: coverPath.present ? coverPath.value : this.coverPath,
    time: time.present ? time.value : this.time,
    displayOrder: displayOrder ?? this.displayOrder,
    recentlyWatched: recentlyWatched.present
        ? recentlyWatched.value
        : this.recentlyWatched,
    viewMore: viewMore.present ? viewMore.value : this.viewMore,
  );
  FavoriteItemRow copyWithCompanion(FavoriteItemsCompanion data) {
    return FavoriteItemRow(
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      author: data.author.present ? data.author.value : this.author,
      type: data.type.present ? data.type.value : this.type,
      tags: data.tags.present ? data.tags.value : this.tags,
      coverPath: data.coverPath.present ? data.coverPath.value : this.coverPath,
      time: data.time.present ? data.time.value : this.time,
      displayOrder: data.displayOrder.present
          ? data.displayOrder.value
          : this.displayOrder,
      recentlyWatched: data.recentlyWatched.present
          ? data.recentlyWatched.value
          : this.recentlyWatched,
      viewMore: data.viewMore.present ? data.viewMore.value : this.viewMore,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteItemRow(')
          ..write('folderId: $folderId, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('author: $author, ')
          ..write('type: $type, ')
          ..write('tags: $tags, ')
          ..write('coverPath: $coverPath, ')
          ..write('time: $time, ')
          ..write('displayOrder: $displayOrder, ')
          ..write('recentlyWatched: $recentlyWatched, ')
          ..write('viewMore: $viewMore')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    folderId,
    id,
    name,
    author,
    type,
    tags,
    coverPath,
    time,
    displayOrder,
    recentlyWatched,
    viewMore,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FavoriteItemRow &&
          other.folderId == this.folderId &&
          other.id == this.id &&
          other.name == this.name &&
          other.author == this.author &&
          other.type == this.type &&
          other.tags == this.tags &&
          other.coverPath == this.coverPath &&
          other.time == this.time &&
          other.displayOrder == this.displayOrder &&
          other.recentlyWatched == this.recentlyWatched &&
          other.viewMore == this.viewMore);
}

class FavoriteItemsCompanion extends UpdateCompanion<FavoriteItemRow> {
  final Value<String> folderId;
  final Value<String> id;
  final Value<String> name;
  final Value<String?> author;
  final Value<int> type;
  final Value<String?> tags;
  final Value<String?> coverPath;
  final Value<String?> time;
  final Value<int> displayOrder;
  final Value<String?> recentlyWatched;
  final Value<String?> viewMore;
  final Value<int> rowid;
  const FavoriteItemsCompanion({
    this.folderId = const Value.absent(),
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.author = const Value.absent(),
    this.type = const Value.absent(),
    this.tags = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.time = const Value.absent(),
    this.displayOrder = const Value.absent(),
    this.recentlyWatched = const Value.absent(),
    this.viewMore = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FavoriteItemsCompanion.insert({
    required String folderId,
    required String id,
    required String name,
    this.author = const Value.absent(),
    required int type,
    this.tags = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.time = const Value.absent(),
    this.displayOrder = const Value.absent(),
    this.recentlyWatched = const Value.absent(),
    this.viewMore = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : folderId = Value(folderId),
       id = Value(id),
       name = Value(name),
       type = Value(type);
  static Insertable<FavoriteItemRow> custom({
    Expression<String>? folderId,
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? author,
    Expression<int>? type,
    Expression<String>? tags,
    Expression<String>? coverPath,
    Expression<String>? time,
    Expression<int>? displayOrder,
    Expression<String>? recentlyWatched,
    Expression<String>? viewMore,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (folderId != null) 'folder_id': folderId,
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (author != null) 'author': author,
      if (type != null) 'type': type,
      if (tags != null) 'tags': tags,
      if (coverPath != null) 'cover_path': coverPath,
      if (time != null) 'time': time,
      if (displayOrder != null) 'display_order': displayOrder,
      if (recentlyWatched != null) 'recently_watched': recentlyWatched,
      if (viewMore != null) 'view_more': viewMore,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FavoriteItemsCompanion copyWith({
    Value<String>? folderId,
    Value<String>? id,
    Value<String>? name,
    Value<String?>? author,
    Value<int>? type,
    Value<String?>? tags,
    Value<String?>? coverPath,
    Value<String?>? time,
    Value<int>? displayOrder,
    Value<String?>? recentlyWatched,
    Value<String?>? viewMore,
    Value<int>? rowid,
  }) {
    return FavoriteItemsCompanion(
      folderId: folderId ?? this.folderId,
      id: id ?? this.id,
      name: name ?? this.name,
      author: author ?? this.author,
      type: type ?? this.type,
      tags: tags ?? this.tags,
      coverPath: coverPath ?? this.coverPath,
      time: time ?? this.time,
      displayOrder: displayOrder ?? this.displayOrder,
      recentlyWatched: recentlyWatched ?? this.recentlyWatched,
      viewMore: viewMore ?? this.viewMore,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (folderId.present) {
      map['folder_id'] = Variable<String>(folderId.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(type.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (coverPath.present) {
      map['cover_path'] = Variable<String>(coverPath.value);
    }
    if (time.present) {
      map['time'] = Variable<String>(time.value);
    }
    if (displayOrder.present) {
      map['display_order'] = Variable<int>(displayOrder.value);
    }
    if (recentlyWatched.present) {
      map['recently_watched'] = Variable<String>(recentlyWatched.value);
    }
    if (viewMore.present) {
      map['view_more'] = Variable<String>(viewMore.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteItemsCompanion(')
          ..write('folderId: $folderId, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('author: $author, ')
          ..write('type: $type, ')
          ..write('tags: $tags, ')
          ..write('coverPath: $coverPath, ')
          ..write('time: $time, ')
          ..write('displayOrder: $displayOrder, ')
          ..write('recentlyWatched: $recentlyWatched, ')
          ..write('viewMore: $viewMore, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$FavoriteDatabase extends GeneratedDatabase {
  _$FavoriteDatabase(QueryExecutor e) : super(e);
  $FavoriteDatabaseManager get managers => $FavoriteDatabaseManager(this);
  late final $FavoriteFoldersTable favoriteFolders = $FavoriteFoldersTable(
    this,
  );
  late final $FavoriteItemsTable favoriteItems = $FavoriteItemsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    favoriteFolders,
    favoriteItems,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'favorite_folders',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('favorite_items', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$FavoriteFoldersTableCreateCompanionBuilder =
    FavoriteFoldersCompanion Function({
      required String id,
      required String name,
      required int sortOrder,
      Value<int> rowid,
    });
typedef $$FavoriteFoldersTableUpdateCompanionBuilder =
    FavoriteFoldersCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> sortOrder,
      Value<int> rowid,
    });

final class $$FavoriteFoldersTableReferences
    extends
        BaseReferences<
          _$FavoriteDatabase,
          $FavoriteFoldersTable,
          FavoriteFolder
        > {
  $$FavoriteFoldersTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$FavoriteItemsTable, List<FavoriteItemRow>>
  _favoriteItemsRefsTable(_$FavoriteDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.favoriteItems,
        aliasName: 'favorite_folders__id__favorite_items__folder_id',
      );

  $$FavoriteItemsTableProcessedTableManager get favoriteItemsRefs {
    final manager = $$FavoriteItemsTableTableManager(
      $_db,
      $_db.favoriteItems,
    ).filter((f) => f.folderId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_favoriteItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FavoriteFoldersTableFilterComposer
    extends Composer<_$FavoriteDatabase, $FavoriteFoldersTable> {
  $$FavoriteFoldersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> favoriteItemsRefs(
    Expression<bool> Function($$FavoriteItemsTableFilterComposer f) f,
  ) {
    final $$FavoriteItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.favoriteItems,
      getReferencedColumn: (t) => t.folderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FavoriteItemsTableFilterComposer(
            $db: $db,
            $table: $db.favoriteItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FavoriteFoldersTableOrderingComposer
    extends Composer<_$FavoriteDatabase, $FavoriteFoldersTable> {
  $$FavoriteFoldersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FavoriteFoldersTableAnnotationComposer
    extends Composer<_$FavoriteDatabase, $FavoriteFoldersTable> {
  $$FavoriteFoldersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  Expression<T> favoriteItemsRefs<T extends Object>(
    Expression<T> Function($$FavoriteItemsTableAnnotationComposer a) f,
  ) {
    final $$FavoriteItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.favoriteItems,
      getReferencedColumn: (t) => t.folderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FavoriteItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.favoriteItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FavoriteFoldersTableTableManager
    extends
        RootTableManager<
          _$FavoriteDatabase,
          $FavoriteFoldersTable,
          FavoriteFolder,
          $$FavoriteFoldersTableFilterComposer,
          $$FavoriteFoldersTableOrderingComposer,
          $$FavoriteFoldersTableAnnotationComposer,
          $$FavoriteFoldersTableCreateCompanionBuilder,
          $$FavoriteFoldersTableUpdateCompanionBuilder,
          (FavoriteFolder, $$FavoriteFoldersTableReferences),
          FavoriteFolder,
          PrefetchHooks Function({bool favoriteItemsRefs})
        > {
  $$FavoriteFoldersTableTableManager(
    _$FavoriteDatabase db,
    $FavoriteFoldersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FavoriteFoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FavoriteFoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FavoriteFoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FavoriteFoldersCompanion(
                id: id,
                name: name,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required int sortOrder,
                Value<int> rowid = const Value.absent(),
              }) => FavoriteFoldersCompanion.insert(
                id: id,
                name: name,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FavoriteFoldersTable, FavoriteFolder>(table),
                  $$FavoriteFoldersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({favoriteItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (favoriteItemsRefs) db.favoriteItems,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (favoriteItemsRefs)
                    await $_getPrefetchedData<
                      FavoriteFolder,
                      $FavoriteFoldersTable,
                      FavoriteItemRow
                    >(
                      currentTable: table,
                      referencedTable: $$FavoriteFoldersTableReferences
                          ._favoriteItemsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$FavoriteFoldersTableReferences(
                            db,
                            table,
                            p0,
                          ).favoriteItemsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.folderId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$FavoriteFoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$FavoriteDatabase,
      $FavoriteFoldersTable,
      FavoriteFolder,
      $$FavoriteFoldersTableFilterComposer,
      $$FavoriteFoldersTableOrderingComposer,
      $$FavoriteFoldersTableAnnotationComposer,
      $$FavoriteFoldersTableCreateCompanionBuilder,
      $$FavoriteFoldersTableUpdateCompanionBuilder,
      (FavoriteFolder, $$FavoriteFoldersTableReferences),
      FavoriteFolder,
      PrefetchHooks Function({bool favoriteItemsRefs})
    >;
typedef $$FavoriteItemsTableCreateCompanionBuilder =
    FavoriteItemsCompanion Function({
      required String folderId,
      required String id,
      required String name,
      Value<String?> author,
      required int type,
      Value<String?> tags,
      Value<String?> coverPath,
      Value<String?> time,
      Value<int> displayOrder,
      Value<String?> recentlyWatched,
      Value<String?> viewMore,
      Value<int> rowid,
    });
typedef $$FavoriteItemsTableUpdateCompanionBuilder =
    FavoriteItemsCompanion Function({
      Value<String> folderId,
      Value<String> id,
      Value<String> name,
      Value<String?> author,
      Value<int> type,
      Value<String?> tags,
      Value<String?> coverPath,
      Value<String?> time,
      Value<int> displayOrder,
      Value<String?> recentlyWatched,
      Value<String?> viewMore,
      Value<int> rowid,
    });

final class $$FavoriteItemsTableReferences
    extends
        BaseReferences<
          _$FavoriteDatabase,
          $FavoriteItemsTable,
          FavoriteItemRow
        > {
  $$FavoriteItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $FavoriteFoldersTable _folderIdTable(_$FavoriteDatabase db) => db
      .favoriteFolders
      .createAlias('favorite_items__folder_id__favorite_folders__id');

  $$FavoriteFoldersTableProcessedTableManager get folderId {
    final $_column = $_itemColumn<String>('folder_id')!;

    final manager = $$FavoriteFoldersTableTableManager(
      $_db,
      $_db.favoriteFolders,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_folderIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FavoriteItemsTableFilterComposer
    extends Composer<_$FavoriteDatabase, $FavoriteItemsTable> {
  $$FavoriteItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recentlyWatched => $composableBuilder(
    column: $table.recentlyWatched,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get viewMore => $composableBuilder(
    column: $table.viewMore,
    builder: (column) => ColumnFilters(column),
  );

  $$FavoriteFoldersTableFilterComposer get folderId {
    final $$FavoriteFoldersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.favoriteFolders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FavoriteFoldersTableFilterComposer(
            $db: $db,
            $table: $db.favoriteFolders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FavoriteItemsTableOrderingComposer
    extends Composer<_$FavoriteDatabase, $FavoriteItemsTable> {
  $$FavoriteItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recentlyWatched => $composableBuilder(
    column: $table.recentlyWatched,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get viewMore => $composableBuilder(
    column: $table.viewMore,
    builder: (column) => ColumnOrderings(column),
  );

  $$FavoriteFoldersTableOrderingComposer get folderId {
    final $$FavoriteFoldersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.favoriteFolders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FavoriteFoldersTableOrderingComposer(
            $db: $db,
            $table: $db.favoriteFolders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FavoriteItemsTableAnnotationComposer
    extends Composer<_$FavoriteDatabase, $FavoriteItemsTable> {
  $$FavoriteItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get coverPath =>
      $composableBuilder(column: $table.coverPath, builder: (column) => column);

  GeneratedColumn<String> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);

  GeneratedColumn<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recentlyWatched => $composableBuilder(
    column: $table.recentlyWatched,
    builder: (column) => column,
  );

  GeneratedColumn<String> get viewMore =>
      $composableBuilder(column: $table.viewMore, builder: (column) => column);

  $$FavoriteFoldersTableAnnotationComposer get folderId {
    final $$FavoriteFoldersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.favoriteFolders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FavoriteFoldersTableAnnotationComposer(
            $db: $db,
            $table: $db.favoriteFolders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FavoriteItemsTableTableManager
    extends
        RootTableManager<
          _$FavoriteDatabase,
          $FavoriteItemsTable,
          FavoriteItemRow,
          $$FavoriteItemsTableFilterComposer,
          $$FavoriteItemsTableOrderingComposer,
          $$FavoriteItemsTableAnnotationComposer,
          $$FavoriteItemsTableCreateCompanionBuilder,
          $$FavoriteItemsTableUpdateCompanionBuilder,
          (FavoriteItemRow, $$FavoriteItemsTableReferences),
          FavoriteItemRow,
          PrefetchHooks Function({bool folderId})
        > {
  $$FavoriteItemsTableTableManager(
    _$FavoriteDatabase db,
    $FavoriteItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FavoriteItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FavoriteItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FavoriteItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> folderId = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<int> type = const Value.absent(),
                Value<String?> tags = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<String?> time = const Value.absent(),
                Value<int> displayOrder = const Value.absent(),
                Value<String?> recentlyWatched = const Value.absent(),
                Value<String?> viewMore = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FavoriteItemsCompanion(
                folderId: folderId,
                id: id,
                name: name,
                author: author,
                type: type,
                tags: tags,
                coverPath: coverPath,
                time: time,
                displayOrder: displayOrder,
                recentlyWatched: recentlyWatched,
                viewMore: viewMore,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String folderId,
                required String id,
                required String name,
                Value<String?> author = const Value.absent(),
                required int type,
                Value<String?> tags = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<String?> time = const Value.absent(),
                Value<int> displayOrder = const Value.absent(),
                Value<String?> recentlyWatched = const Value.absent(),
                Value<String?> viewMore = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FavoriteItemsCompanion.insert(
                folderId: folderId,
                id: id,
                name: name,
                author: author,
                type: type,
                tags: tags,
                coverPath: coverPath,
                time: time,
                displayOrder: displayOrder,
                recentlyWatched: recentlyWatched,
                viewMore: viewMore,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FavoriteItemsTable, FavoriteItemRow>(table),
                  $$FavoriteItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({folderId = false}) {
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
                    if (folderId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.folderId,
                        referencedTable: $$FavoriteItemsTableReferences
                            ._folderIdTable(db),
                        referencedColumn: $$FavoriteItemsTableReferences
                            ._folderIdTable(db)
                            .id,
                      ) as T;
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

typedef $$FavoriteItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$FavoriteDatabase,
      $FavoriteItemsTable,
      FavoriteItemRow,
      $$FavoriteItemsTableFilterComposer,
      $$FavoriteItemsTableOrderingComposer,
      $$FavoriteItemsTableAnnotationComposer,
      $$FavoriteItemsTableCreateCompanionBuilder,
      $$FavoriteItemsTableUpdateCompanionBuilder,
      (FavoriteItemRow, $$FavoriteItemsTableReferences),
      FavoriteItemRow,
      PrefetchHooks Function({bool folderId})
    >;

class $FavoriteDatabaseManager {
  final _$FavoriteDatabase _db;
  $FavoriteDatabaseManager(this._db);
  $$FavoriteFoldersTableTableManager get favoriteFolders =>
      $$FavoriteFoldersTableTableManager(_db, _db.favoriteFolders);
  $$FavoriteItemsTableTableManager get favoriteItems =>
      $$FavoriteItemsTableTableManager(_db, _db.favoriteItems);
}

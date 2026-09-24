// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_database.dart';

// ignore_for_file: type=lint
class $DownloadRecordTableTable extends DownloadRecordTable
    with TableInfo<$DownloadRecordTableTable, DownloadRecordTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadRecordTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _animeIdMeta = const VerificationMeta(
    'animeId',
  );
  @override
  late final GeneratedColumn<String> animeId = GeneratedColumn<String>(
    'anime_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceKeyMeta = const VerificationMeta(
    'sourceKey',
  );
  @override
  late final GeneratedColumn<String> sourceKey = GeneratedColumn<String>(
    'source_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _episodeMeta = const VerificationMeta(
    'episode',
  );
  @override
  late final GeneratedColumn<String> episode = GeneratedColumn<String>(
    'episode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _episodeRawMeta = const VerificationMeta(
    'episodeRaw',
  );
  @override
  late final GeneratedColumn<String> episodeRaw = GeneratedColumn<String>(
    'episode_raw',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resolutionMeta = const VerificationMeta(
    'resolution',
  );
  @override
  late final GeneratedColumn<String> resolution = GeneratedColumn<String>(
    'resolution',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _groupNameMeta = const VerificationMeta(
    'groupName',
  );
  @override
  late final GeneratedColumn<String> groupName = GeneratedColumn<String>(
    'group_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalBytesMeta = const VerificationMeta(
    'totalBytes',
  );
  @override
  late final GeneratedColumn<int> totalBytes = GeneratedColumn<int>(
    'total_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
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
  @override
  List<GeneratedColumn> get $columns => [
    filePath,
    animeId,
    sourceKey,
    title,
    episode,
    episodeRaw,
    resolution,
    groupName,
    totalBytes,
    time,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_record';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadRecordTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('anime_id')) {
      context.handle(
        _animeIdMeta,
        animeId.isAcceptableOrUnknown(data['anime_id']!, _animeIdMeta),
      );
    }
    if (data.containsKey('source_key')) {
      context.handle(
        _sourceKeyMeta,
        sourceKey.isAcceptableOrUnknown(data['source_key']!, _sourceKeyMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('episode')) {
      context.handle(
        _episodeMeta,
        episode.isAcceptableOrUnknown(data['episode']!, _episodeMeta),
      );
    }
    if (data.containsKey('episode_raw')) {
      context.handle(
        _episodeRawMeta,
        episodeRaw.isAcceptableOrUnknown(data['episode_raw']!, _episodeRawMeta),
      );
    }
    if (data.containsKey('resolution')) {
      context.handle(
        _resolutionMeta,
        resolution.isAcceptableOrUnknown(data['resolution']!, _resolutionMeta),
      );
    }
    if (data.containsKey('group_name')) {
      context.handle(
        _groupNameMeta,
        groupName.isAcceptableOrUnknown(data['group_name']!, _groupNameMeta),
      );
    }
    if (data.containsKey('total_bytes')) {
      context.handle(
        _totalBytesMeta,
        totalBytes.isAcceptableOrUnknown(data['total_bytes']!, _totalBytesMeta),
      );
    }
    if (data.containsKey('time')) {
      context.handle(
        _timeMeta,
        time.isAcceptableOrUnknown(data['time']!, _timeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {filePath};
  @override
  DownloadRecordTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadRecordTableData(
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      animeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}anime_id'],
      ),
      sourceKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_key'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      episode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}episode'],
      ),
      episodeRaw: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}episode_raw'],
      ),
      resolution: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resolution'],
      ),
      groupName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_name'],
      ),
      totalBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_bytes'],
      ),
      time: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time'],
      ),
    );
  }

  @override
  $DownloadRecordTableTable createAlias(String alias) {
    return $DownloadRecordTableTable(attachedDatabase, alias);
  }
}

class DownloadRecordTableData extends DataClass
    implements Insertable<DownloadRecordTableData> {
  final String filePath;
  final String? animeId;
  final String? sourceKey;
  final String? title;
  final String? episode;
  final String? episodeRaw;
  final String? resolution;
  final String? groupName;
  final int? totalBytes;
  final String? time;
  const DownloadRecordTableData({
    required this.filePath,
    this.animeId,
    this.sourceKey,
    this.title,
    this.episode,
    this.episodeRaw,
    this.resolution,
    this.groupName,
    this.totalBytes,
    this.time,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['file_path'] = Variable<String>(filePath);
    if (!nullToAbsent || animeId != null) {
      map['anime_id'] = Variable<String>(animeId);
    }
    if (!nullToAbsent || sourceKey != null) {
      map['source_key'] = Variable<String>(sourceKey);
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || episode != null) {
      map['episode'] = Variable<String>(episode);
    }
    if (!nullToAbsent || episodeRaw != null) {
      map['episode_raw'] = Variable<String>(episodeRaw);
    }
    if (!nullToAbsent || resolution != null) {
      map['resolution'] = Variable<String>(resolution);
    }
    if (!nullToAbsent || groupName != null) {
      map['group_name'] = Variable<String>(groupName);
    }
    if (!nullToAbsent || totalBytes != null) {
      map['total_bytes'] = Variable<int>(totalBytes);
    }
    if (!nullToAbsent || time != null) {
      map['time'] = Variable<String>(time);
    }
    return map;
  }

  DownloadRecordTableCompanion toCompanion(bool nullToAbsent) {
    return DownloadRecordTableCompanion(
      filePath: Value(filePath),
      animeId: animeId == null && nullToAbsent
          ? const Value.absent()
          : Value(animeId),
      sourceKey: sourceKey == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceKey),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      episode: episode == null && nullToAbsent
          ? const Value.absent()
          : Value(episode),
      episodeRaw: episodeRaw == null && nullToAbsent
          ? const Value.absent()
          : Value(episodeRaw),
      resolution: resolution == null && nullToAbsent
          ? const Value.absent()
          : Value(resolution),
      groupName: groupName == null && nullToAbsent
          ? const Value.absent()
          : Value(groupName),
      totalBytes: totalBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(totalBytes),
      time: time == null && nullToAbsent ? const Value.absent() : Value(time),
    );
  }

  factory DownloadRecordTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadRecordTableData(
      filePath: serializer.fromJson<String>(json['filePath']),
      animeId: serializer.fromJson<String?>(json['animeId']),
      sourceKey: serializer.fromJson<String?>(json['sourceKey']),
      title: serializer.fromJson<String?>(json['title']),
      episode: serializer.fromJson<String?>(json['episode']),
      episodeRaw: serializer.fromJson<String?>(json['episodeRaw']),
      resolution: serializer.fromJson<String?>(json['resolution']),
      groupName: serializer.fromJson<String?>(json['groupName']),
      totalBytes: serializer.fromJson<int?>(json['totalBytes']),
      time: serializer.fromJson<String?>(json['time']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'filePath': serializer.toJson<String>(filePath),
      'animeId': serializer.toJson<String?>(animeId),
      'sourceKey': serializer.toJson<String?>(sourceKey),
      'title': serializer.toJson<String?>(title),
      'episode': serializer.toJson<String?>(episode),
      'episodeRaw': serializer.toJson<String?>(episodeRaw),
      'resolution': serializer.toJson<String?>(resolution),
      'groupName': serializer.toJson<String?>(groupName),
      'totalBytes': serializer.toJson<int?>(totalBytes),
      'time': serializer.toJson<String?>(time),
    };
  }

  DownloadRecordTableData copyWith({
    String? filePath,
    Value<String?> animeId = const Value.absent(),
    Value<String?> sourceKey = const Value.absent(),
    Value<String?> title = const Value.absent(),
    Value<String?> episode = const Value.absent(),
    Value<String?> episodeRaw = const Value.absent(),
    Value<String?> resolution = const Value.absent(),
    Value<String?> groupName = const Value.absent(),
    Value<int?> totalBytes = const Value.absent(),
    Value<String?> time = const Value.absent(),
  }) => DownloadRecordTableData(
    filePath: filePath ?? this.filePath,
    animeId: animeId.present ? animeId.value : this.animeId,
    sourceKey: sourceKey.present ? sourceKey.value : this.sourceKey,
    title: title.present ? title.value : this.title,
    episode: episode.present ? episode.value : this.episode,
    episodeRaw: episodeRaw.present ? episodeRaw.value : this.episodeRaw,
    resolution: resolution.present ? resolution.value : this.resolution,
    groupName: groupName.present ? groupName.value : this.groupName,
    totalBytes: totalBytes.present ? totalBytes.value : this.totalBytes,
    time: time.present ? time.value : this.time,
  );
  DownloadRecordTableData copyWithCompanion(DownloadRecordTableCompanion data) {
    return DownloadRecordTableData(
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      animeId: data.animeId.present ? data.animeId.value : this.animeId,
      sourceKey: data.sourceKey.present ? data.sourceKey.value : this.sourceKey,
      title: data.title.present ? data.title.value : this.title,
      episode: data.episode.present ? data.episode.value : this.episode,
      episodeRaw: data.episodeRaw.present
          ? data.episodeRaw.value
          : this.episodeRaw,
      resolution: data.resolution.present
          ? data.resolution.value
          : this.resolution,
      groupName: data.groupName.present ? data.groupName.value : this.groupName,
      totalBytes: data.totalBytes.present
          ? data.totalBytes.value
          : this.totalBytes,
      time: data.time.present ? data.time.value : this.time,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadRecordTableData(')
          ..write('filePath: $filePath, ')
          ..write('animeId: $animeId, ')
          ..write('sourceKey: $sourceKey, ')
          ..write('title: $title, ')
          ..write('episode: $episode, ')
          ..write('episodeRaw: $episodeRaw, ')
          ..write('resolution: $resolution, ')
          ..write('groupName: $groupName, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('time: $time')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    filePath,
    animeId,
    sourceKey,
    title,
    episode,
    episodeRaw,
    resolution,
    groupName,
    totalBytes,
    time,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadRecordTableData &&
          other.filePath == this.filePath &&
          other.animeId == this.animeId &&
          other.sourceKey == this.sourceKey &&
          other.title == this.title &&
          other.episode == this.episode &&
          other.episodeRaw == this.episodeRaw &&
          other.resolution == this.resolution &&
          other.groupName == this.groupName &&
          other.totalBytes == this.totalBytes &&
          other.time == this.time);
}

class DownloadRecordTableCompanion
    extends UpdateCompanion<DownloadRecordTableData> {
  final Value<String> filePath;
  final Value<String?> animeId;
  final Value<String?> sourceKey;
  final Value<String?> title;
  final Value<String?> episode;
  final Value<String?> episodeRaw;
  final Value<String?> resolution;
  final Value<String?> groupName;
  final Value<int?> totalBytes;
  final Value<String?> time;
  final Value<int> rowid;
  const DownloadRecordTableCompanion({
    this.filePath = const Value.absent(),
    this.animeId = const Value.absent(),
    this.sourceKey = const Value.absent(),
    this.title = const Value.absent(),
    this.episode = const Value.absent(),
    this.episodeRaw = const Value.absent(),
    this.resolution = const Value.absent(),
    this.groupName = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.time = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadRecordTableCompanion.insert({
    required String filePath,
    this.animeId = const Value.absent(),
    this.sourceKey = const Value.absent(),
    this.title = const Value.absent(),
    this.episode = const Value.absent(),
    this.episodeRaw = const Value.absent(),
    this.resolution = const Value.absent(),
    this.groupName = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.time = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : filePath = Value(filePath);
  static Insertable<DownloadRecordTableData> custom({
    Expression<String>? filePath,
    Expression<String>? animeId,
    Expression<String>? sourceKey,
    Expression<String>? title,
    Expression<String>? episode,
    Expression<String>? episodeRaw,
    Expression<String>? resolution,
    Expression<String>? groupName,
    Expression<int>? totalBytes,
    Expression<String>? time,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (filePath != null) 'file_path': filePath,
      if (animeId != null) 'anime_id': animeId,
      if (sourceKey != null) 'source_key': sourceKey,
      if (title != null) 'title': title,
      if (episode != null) 'episode': episode,
      if (episodeRaw != null) 'episode_raw': episodeRaw,
      if (resolution != null) 'resolution': resolution,
      if (groupName != null) 'group_name': groupName,
      if (totalBytes != null) 'total_bytes': totalBytes,
      if (time != null) 'time': time,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadRecordTableCompanion copyWith({
    Value<String>? filePath,
    Value<String?>? animeId,
    Value<String?>? sourceKey,
    Value<String?>? title,
    Value<String?>? episode,
    Value<String?>? episodeRaw,
    Value<String?>? resolution,
    Value<String?>? groupName,
    Value<int?>? totalBytes,
    Value<String?>? time,
    Value<int>? rowid,
  }) {
    return DownloadRecordTableCompanion(
      filePath: filePath ?? this.filePath,
      animeId: animeId ?? this.animeId,
      sourceKey: sourceKey ?? this.sourceKey,
      title: title ?? this.title,
      episode: episode ?? this.episode,
      episodeRaw: episodeRaw ?? this.episodeRaw,
      resolution: resolution ?? this.resolution,
      groupName: groupName ?? this.groupName,
      totalBytes: totalBytes ?? this.totalBytes,
      time: time ?? this.time,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (animeId.present) {
      map['anime_id'] = Variable<String>(animeId.value);
    }
    if (sourceKey.present) {
      map['source_key'] = Variable<String>(sourceKey.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (episode.present) {
      map['episode'] = Variable<String>(episode.value);
    }
    if (episodeRaw.present) {
      map['episode_raw'] = Variable<String>(episodeRaw.value);
    }
    if (resolution.present) {
      map['resolution'] = Variable<String>(resolution.value);
    }
    if (groupName.present) {
      map['group_name'] = Variable<String>(groupName.value);
    }
    if (totalBytes.present) {
      map['total_bytes'] = Variable<int>(totalBytes.value);
    }
    if (time.present) {
      map['time'] = Variable<String>(time.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadRecordTableCompanion(')
          ..write('filePath: $filePath, ')
          ..write('animeId: $animeId, ')
          ..write('sourceKey: $sourceKey, ')
          ..write('title: $title, ')
          ..write('episode: $episode, ')
          ..write('episodeRaw: $episodeRaw, ')
          ..write('resolution: $resolution, ')
          ..write('groupName: $groupName, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('time: $time, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DownloadTaskTableTable extends DownloadTaskTable
    with TableInfo<$DownloadTaskTableTable, DownloadTaskTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadTaskTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, data];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_task';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadTaskTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DownloadTaskTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadTaskTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
    );
  }

  @override
  $DownloadTaskTableTable createAlias(String alias) {
    return $DownloadTaskTableTable(attachedDatabase, alias);
  }
}

class DownloadTaskTableData extends DataClass
    implements Insertable<DownloadTaskTableData> {
  final String id;
  final String data;
  const DownloadTaskTableData({required this.id, required this.data});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['data'] = Variable<String>(data);
    return map;
  }

  DownloadTaskTableCompanion toCompanion(bool nullToAbsent) {
    return DownloadTaskTableCompanion(id: Value(id), data: Value(data));
  }

  factory DownloadTaskTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadTaskTableData(
      id: serializer.fromJson<String>(json['id']),
      data: serializer.fromJson<String>(json['data']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'data': serializer.toJson<String>(data),
    };
  }

  DownloadTaskTableData copyWith({String? id, String? data}) =>
      DownloadTaskTableData(id: id ?? this.id, data: data ?? this.data);
  DownloadTaskTableData copyWithCompanion(DownloadTaskTableCompanion data) {
    return DownloadTaskTableData(
      id: data.id.present ? data.id.value : this.id,
      data: data.data.present ? data.data.value : this.data,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadTaskTableData(')
          ..write('id: $id, ')
          ..write('data: $data')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, data);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadTaskTableData &&
          other.id == this.id &&
          other.data == this.data);
}

class DownloadTaskTableCompanion
    extends UpdateCompanion<DownloadTaskTableData> {
  final Value<String> id;
  final Value<String> data;
  final Value<int> rowid;
  const DownloadTaskTableCompanion({
    this.id = const Value.absent(),
    this.data = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadTaskTableCompanion.insert({
    required String id,
    required String data,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       data = Value(data);
  static Insertable<DownloadTaskTableData> custom({
    Expression<String>? id,
    Expression<String>? data,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (data != null) 'data': data,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadTaskTableCompanion copyWith({
    Value<String>? id,
    Value<String>? data,
    Value<int>? rowid,
  }) {
    return DownloadTaskTableCompanion(
      id: id ?? this.id,
      data: data ?? this.data,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadTaskTableCompanion(')
          ..write('id: $id, ')
          ..write('data: $data, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TorrentJobTableTable extends TorrentJobTable
    with TableInfo<$TorrentJobTableTable, TorrentJobTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TorrentJobTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, data];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'torrent_job';
  @override
  VerificationContext validateIntegrity(
    Insertable<TorrentJobTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TorrentJobTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TorrentJobTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
    );
  }

  @override
  $TorrentJobTableTable createAlias(String alias) {
    return $TorrentJobTableTable(attachedDatabase, alias);
  }
}

class TorrentJobTableData extends DataClass
    implements Insertable<TorrentJobTableData> {
  final String id;
  final String data;
  const TorrentJobTableData({required this.id, required this.data});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['data'] = Variable<String>(data);
    return map;
  }

  TorrentJobTableCompanion toCompanion(bool nullToAbsent) {
    return TorrentJobTableCompanion(id: Value(id), data: Value(data));
  }

  factory TorrentJobTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TorrentJobTableData(
      id: serializer.fromJson<String>(json['id']),
      data: serializer.fromJson<String>(json['data']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'data': serializer.toJson<String>(data),
    };
  }

  TorrentJobTableData copyWith({String? id, String? data}) =>
      TorrentJobTableData(id: id ?? this.id, data: data ?? this.data);
  TorrentJobTableData copyWithCompanion(TorrentJobTableCompanion data) {
    return TorrentJobTableData(
      id: data.id.present ? data.id.value : this.id,
      data: data.data.present ? data.data.value : this.data,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TorrentJobTableData(')
          ..write('id: $id, ')
          ..write('data: $data')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, data);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TorrentJobTableData &&
          other.id == this.id &&
          other.data == this.data);
}

class TorrentJobTableCompanion extends UpdateCompanion<TorrentJobTableData> {
  final Value<String> id;
  final Value<String> data;
  final Value<int> rowid;
  const TorrentJobTableCompanion({
    this.id = const Value.absent(),
    this.data = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TorrentJobTableCompanion.insert({
    required String id,
    required String data,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       data = Value(data);
  static Insertable<TorrentJobTableData> custom({
    Expression<String>? id,
    Expression<String>? data,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (data != null) 'data': data,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TorrentJobTableCompanion copyWith({
    Value<String>? id,
    Value<String>? data,
    Value<int>? rowid,
  }) {
    return TorrentJobTableCompanion(
      id: id ?? this.id,
      data: data ?? this.data,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TorrentJobTableCompanion(')
          ..write('id: $id, ')
          ..write('data: $data, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BtLineTableTable extends BtLineTable
    with TableInfo<$BtLineTableTable, BtLineTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BtLineTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _contentKeyMeta = const VerificationMeta(
    'contentKey',
  );
  @override
  late final GeneratedColumn<String> contentKey = GeneratedColumn<String>(
    'content_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [contentKey, data];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bt_line';
  @override
  VerificationContext validateIntegrity(
    Insertable<BtLineTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('content_key')) {
      context.handle(
        _contentKeyMeta,
        contentKey.isAcceptableOrUnknown(data['content_key']!, _contentKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_contentKeyMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {contentKey};
  @override
  BtLineTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BtLineTableData(
      contentKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_key'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
    );
  }

  @override
  $BtLineTableTable createAlias(String alias) {
    return $BtLineTableTable(attachedDatabase, alias);
  }
}

class BtLineTableData extends DataClass implements Insertable<BtLineTableData> {
  final String contentKey;
  final String data;
  const BtLineTableData({required this.contentKey, required this.data});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['content_key'] = Variable<String>(contentKey);
    map['data'] = Variable<String>(data);
    return map;
  }

  BtLineTableCompanion toCompanion(bool nullToAbsent) {
    return BtLineTableCompanion(
      contentKey: Value(contentKey),
      data: Value(data),
    );
  }

  factory BtLineTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BtLineTableData(
      contentKey: serializer.fromJson<String>(json['contentKey']),
      data: serializer.fromJson<String>(json['data']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'contentKey': serializer.toJson<String>(contentKey),
      'data': serializer.toJson<String>(data),
    };
  }

  BtLineTableData copyWith({String? contentKey, String? data}) =>
      BtLineTableData(
        contentKey: contentKey ?? this.contentKey,
        data: data ?? this.data,
      );
  BtLineTableData copyWithCompanion(BtLineTableCompanion data) {
    return BtLineTableData(
      contentKey: data.contentKey.present
          ? data.contentKey.value
          : this.contentKey,
      data: data.data.present ? data.data.value : this.data,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BtLineTableData(')
          ..write('contentKey: $contentKey, ')
          ..write('data: $data')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(contentKey, data);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BtLineTableData &&
          other.contentKey == this.contentKey &&
          other.data == this.data);
}

class BtLineTableCompanion extends UpdateCompanion<BtLineTableData> {
  final Value<String> contentKey;
  final Value<String> data;
  final Value<int> rowid;
  const BtLineTableCompanion({
    this.contentKey = const Value.absent(),
    this.data = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BtLineTableCompanion.insert({
    required String contentKey,
    required String data,
    this.rowid = const Value.absent(),
  }) : contentKey = Value(contentKey),
       data = Value(data);
  static Insertable<BtLineTableData> custom({
    Expression<String>? contentKey,
    Expression<String>? data,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (contentKey != null) 'content_key': contentKey,
      if (data != null) 'data': data,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BtLineTableCompanion copyWith({
    Value<String>? contentKey,
    Value<String>? data,
    Value<int>? rowid,
  }) {
    return BtLineTableCompanion(
      contentKey: contentKey ?? this.contentKey,
      data: data ?? this.data,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (contentKey.present) {
      map['content_key'] = Variable<String>(contentKey.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BtLineTableCompanion(')
          ..write('contentKey: $contentKey, ')
          ..write('data: $data, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BtActiveTableTable extends BtActiveTable
    with TableInfo<$BtActiveTableTable, BtActiveTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BtActiveTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _contentKeyMeta = const VerificationMeta(
    'contentKey',
  );
  @override
  late final GeneratedColumn<String> contentKey = GeneratedColumn<String>(
    'content_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [contentKey];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bt_active';
  @override
  VerificationContext validateIntegrity(
    Insertable<BtActiveTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('content_key')) {
      context.handle(
        _contentKeyMeta,
        contentKey.isAcceptableOrUnknown(data['content_key']!, _contentKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_contentKeyMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {contentKey};
  @override
  BtActiveTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BtActiveTableData(
      contentKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_key'],
      )!,
    );
  }

  @override
  $BtActiveTableTable createAlias(String alias) {
    return $BtActiveTableTable(attachedDatabase, alias);
  }
}

class BtActiveTableData extends DataClass
    implements Insertable<BtActiveTableData> {
  final String contentKey;
  const BtActiveTableData({required this.contentKey});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['content_key'] = Variable<String>(contentKey);
    return map;
  }

  BtActiveTableCompanion toCompanion(bool nullToAbsent) {
    return BtActiveTableCompanion(contentKey: Value(contentKey));
  }

  factory BtActiveTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BtActiveTableData(
      contentKey: serializer.fromJson<String>(json['contentKey']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'contentKey': serializer.toJson<String>(contentKey),
    };
  }

  BtActiveTableData copyWith({String? contentKey}) =>
      BtActiveTableData(contentKey: contentKey ?? this.contentKey);
  BtActiveTableData copyWithCompanion(BtActiveTableCompanion data) {
    return BtActiveTableData(
      contentKey: data.contentKey.present
          ? data.contentKey.value
          : this.contentKey,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BtActiveTableData(')
          ..write('contentKey: $contentKey')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => contentKey.hashCode;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BtActiveTableData && other.contentKey == this.contentKey);
}

class BtActiveTableCompanion extends UpdateCompanion<BtActiveTableData> {
  final Value<String> contentKey;
  final Value<int> rowid;
  const BtActiveTableCompanion({
    this.contentKey = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BtActiveTableCompanion.insert({
    required String contentKey,
    this.rowid = const Value.absent(),
  }) : contentKey = Value(contentKey);
  static Insertable<BtActiveTableData> custom({
    Expression<String>? contentKey,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (contentKey != null) 'content_key': contentKey,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BtActiveTableCompanion copyWith({
    Value<String>? contentKey,
    Value<int>? rowid,
  }) {
    return BtActiveTableCompanion(
      contentKey: contentKey ?? this.contentKey,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (contentKey.present) {
      map['content_key'] = Variable<String>(contentKey.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BtActiveTableCompanion(')
          ..write('contentKey: $contentKey, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TorrentBindingTableTable extends TorrentBindingTable
    with TableInfo<$TorrentBindingTableTable, TorrentBindingTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TorrentBindingTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jobIdMeta = const VerificationMeta('jobId');
  @override
  late final GeneratedColumn<String> jobId = GeneratedColumn<String>(
    'job_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [key, jobId, filePath, label];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'torrent_binding';
  @override
  VerificationContext validateIntegrity(
    Insertable<TorrentBindingTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('job_id')) {
      context.handle(
        _jobIdMeta,
        jobId.isAcceptableOrUnknown(data['job_id']!, _jobIdMeta),
      );
    } else if (isInserting) {
      context.missing(_jobIdMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  TorrentBindingTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TorrentBindingTableData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      jobId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}job_id'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      ),
    );
  }

  @override
  $TorrentBindingTableTable createAlias(String alias) {
    return $TorrentBindingTableTable(attachedDatabase, alias);
  }
}

class TorrentBindingTableData extends DataClass
    implements Insertable<TorrentBindingTableData> {
  final String key;
  final String jobId;
  final String filePath;
  final String? label;
  const TorrentBindingTableData({
    required this.key,
    required this.jobId,
    required this.filePath,
    this.label,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['job_id'] = Variable<String>(jobId);
    map['file_path'] = Variable<String>(filePath);
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    return map;
  }

  TorrentBindingTableCompanion toCompanion(bool nullToAbsent) {
    return TorrentBindingTableCompanion(
      key: Value(key),
      jobId: Value(jobId),
      filePath: Value(filePath),
      label: label == null && nullToAbsent
          ? const Value.absent()
          : Value(label),
    );
  }

  factory TorrentBindingTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TorrentBindingTableData(
      key: serializer.fromJson<String>(json['key']),
      jobId: serializer.fromJson<String>(json['jobId']),
      filePath: serializer.fromJson<String>(json['filePath']),
      label: serializer.fromJson<String?>(json['label']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'jobId': serializer.toJson<String>(jobId),
      'filePath': serializer.toJson<String>(filePath),
      'label': serializer.toJson<String?>(label),
    };
  }

  TorrentBindingTableData copyWith({
    String? key,
    String? jobId,
    String? filePath,
    Value<String?> label = const Value.absent(),
  }) => TorrentBindingTableData(
    key: key ?? this.key,
    jobId: jobId ?? this.jobId,
    filePath: filePath ?? this.filePath,
    label: label.present ? label.value : this.label,
  );
  TorrentBindingTableData copyWithCompanion(TorrentBindingTableCompanion data) {
    return TorrentBindingTableData(
      key: data.key.present ? data.key.value : this.key,
      jobId: data.jobId.present ? data.jobId.value : this.jobId,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      label: data.label.present ? data.label.value : this.label,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TorrentBindingTableData(')
          ..write('key: $key, ')
          ..write('jobId: $jobId, ')
          ..write('filePath: $filePath, ')
          ..write('label: $label')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, jobId, filePath, label);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TorrentBindingTableData &&
          other.key == this.key &&
          other.jobId == this.jobId &&
          other.filePath == this.filePath &&
          other.label == this.label);
}

class TorrentBindingTableCompanion
    extends UpdateCompanion<TorrentBindingTableData> {
  final Value<String> key;
  final Value<String> jobId;
  final Value<String> filePath;
  final Value<String?> label;
  final Value<int> rowid;
  const TorrentBindingTableCompanion({
    this.key = const Value.absent(),
    this.jobId = const Value.absent(),
    this.filePath = const Value.absent(),
    this.label = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TorrentBindingTableCompanion.insert({
    required String key,
    required String jobId,
    required String filePath,
    this.label = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       jobId = Value(jobId),
       filePath = Value(filePath);
  static Insertable<TorrentBindingTableData> custom({
    Expression<String>? key,
    Expression<String>? jobId,
    Expression<String>? filePath,
    Expression<String>? label,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (jobId != null) 'job_id': jobId,
      if (filePath != null) 'file_path': filePath,
      if (label != null) 'label': label,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TorrentBindingTableCompanion copyWith({
    Value<String>? key,
    Value<String>? jobId,
    Value<String>? filePath,
    Value<String?>? label,
    Value<int>? rowid,
  }) {
    return TorrentBindingTableCompanion(
      key: key ?? this.key,
      jobId: jobId ?? this.jobId,
      filePath: filePath ?? this.filePath,
      label: label ?? this.label,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (jobId.present) {
      map['job_id'] = Variable<String>(jobId.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TorrentBindingTableCompanion(')
          ..write('key: $key, ')
          ..write('jobId: $jobId, ')
          ..write('filePath: $filePath, ')
          ..write('label: $label, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$DownloadDatabase extends GeneratedDatabase {
  _$DownloadDatabase(QueryExecutor e) : super(e);
  $DownloadDatabaseManager get managers => $DownloadDatabaseManager(this);
  late final $DownloadRecordTableTable downloadRecordTable =
      $DownloadRecordTableTable(this);
  late final $DownloadTaskTableTable downloadTaskTable =
      $DownloadTaskTableTable(this);
  late final $TorrentJobTableTable torrentJobTable = $TorrentJobTableTable(
    this,
  );
  late final $BtLineTableTable btLineTable = $BtLineTableTable(this);
  late final $BtActiveTableTable btActiveTable = $BtActiveTableTable(this);
  late final $TorrentBindingTableTable torrentBindingTable =
      $TorrentBindingTableTable(this);
  late final Index dlRecSource = Index(
    'dl_rec_source',
    'CREATE INDEX dl_rec_source ON download_record (source_key)',
  );
  late final Index dlRecAnime = Index(
    'dl_rec_anime',
    'CREATE INDEX dl_rec_anime ON download_record (anime_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    downloadRecordTable,
    downloadTaskTable,
    torrentJobTable,
    btLineTable,
    btActiveTable,
    torrentBindingTable,
    dlRecSource,
    dlRecAnime,
  ];
}

typedef $$DownloadRecordTableTableCreateCompanionBuilder =
    DownloadRecordTableCompanion Function({
      required String filePath,
      Value<String?> animeId,
      Value<String?> sourceKey,
      Value<String?> title,
      Value<String?> episode,
      Value<String?> episodeRaw,
      Value<String?> resolution,
      Value<String?> groupName,
      Value<int?> totalBytes,
      Value<String?> time,
      Value<int> rowid,
    });
typedef $$DownloadRecordTableTableUpdateCompanionBuilder =
    DownloadRecordTableCompanion Function({
      Value<String> filePath,
      Value<String?> animeId,
      Value<String?> sourceKey,
      Value<String?> title,
      Value<String?> episode,
      Value<String?> episodeRaw,
      Value<String?> resolution,
      Value<String?> groupName,
      Value<int?> totalBytes,
      Value<String?> time,
      Value<int> rowid,
    });

class $$DownloadRecordTableTableFilterComposer
    extends Composer<_$DownloadDatabase, $DownloadRecordTableTable> {
  $$DownloadRecordTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get animeId => $composableBuilder(
    column: $table.animeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceKey => $composableBuilder(
    column: $table.sourceKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get episode => $composableBuilder(
    column: $table.episode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get episodeRaw => $composableBuilder(
    column: $table.episodeRaw,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resolution => $composableBuilder(
    column: $table.resolution,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupName => $composableBuilder(
    column: $table.groupName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DownloadRecordTableTableOrderingComposer
    extends Composer<_$DownloadDatabase, $DownloadRecordTableTable> {
  $$DownloadRecordTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get animeId => $composableBuilder(
    column: $table.animeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceKey => $composableBuilder(
    column: $table.sourceKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get episode => $composableBuilder(
    column: $table.episode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get episodeRaw => $composableBuilder(
    column: $table.episodeRaw,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resolution => $composableBuilder(
    column: $table.resolution,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupName => $composableBuilder(
    column: $table.groupName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DownloadRecordTableTableAnnotationComposer
    extends Composer<_$DownloadDatabase, $DownloadRecordTableTable> {
  $$DownloadRecordTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get animeId =>
      $composableBuilder(column: $table.animeId, builder: (column) => column);

  GeneratedColumn<String> get sourceKey =>
      $composableBuilder(column: $table.sourceKey, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get episode =>
      $composableBuilder(column: $table.episode, builder: (column) => column);

  GeneratedColumn<String> get episodeRaw => $composableBuilder(
    column: $table.episodeRaw,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resolution => $composableBuilder(
    column: $table.resolution,
    builder: (column) => column,
  );

  GeneratedColumn<String> get groupName =>
      $composableBuilder(column: $table.groupName, builder: (column) => column);

  GeneratedColumn<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);
}

class $$DownloadRecordTableTableTableManager
    extends
        RootTableManager<
          _$DownloadDatabase,
          $DownloadRecordTableTable,
          DownloadRecordTableData,
          $$DownloadRecordTableTableFilterComposer,
          $$DownloadRecordTableTableOrderingComposer,
          $$DownloadRecordTableTableAnnotationComposer,
          $$DownloadRecordTableTableCreateCompanionBuilder,
          $$DownloadRecordTableTableUpdateCompanionBuilder,
          (
            DownloadRecordTableData,
            BaseReferences<
              _$DownloadDatabase,
              $DownloadRecordTableTable,
              DownloadRecordTableData
            >,
          ),
          DownloadRecordTableData,
          PrefetchHooks Function()
        > {
  $$DownloadRecordTableTableTableManager(
    _$DownloadDatabase db,
    $DownloadRecordTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadRecordTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadRecordTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DownloadRecordTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> filePath = const Value.absent(),
                Value<String?> animeId = const Value.absent(),
                Value<String?> sourceKey = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> episode = const Value.absent(),
                Value<String?> episodeRaw = const Value.absent(),
                Value<String?> resolution = const Value.absent(),
                Value<String?> groupName = const Value.absent(),
                Value<int?> totalBytes = const Value.absent(),
                Value<String?> time = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadRecordTableCompanion(
                filePath: filePath,
                animeId: animeId,
                sourceKey: sourceKey,
                title: title,
                episode: episode,
                episodeRaw: episodeRaw,
                resolution: resolution,
                groupName: groupName,
                totalBytes: totalBytes,
                time: time,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String filePath,
                Value<String?> animeId = const Value.absent(),
                Value<String?> sourceKey = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> episode = const Value.absent(),
                Value<String?> episodeRaw = const Value.absent(),
                Value<String?> resolution = const Value.absent(),
                Value<String?> groupName = const Value.absent(),
                Value<int?> totalBytes = const Value.absent(),
                Value<String?> time = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadRecordTableCompanion.insert(
                filePath: filePath,
                animeId: animeId,
                sourceKey: sourceKey,
                title: title,
                episode: episode,
                episodeRaw: episodeRaw,
                resolution: resolution,
                groupName: groupName,
                totalBytes: totalBytes,
                time: time,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $DownloadRecordTableTable,
                    DownloadRecordTableData
                  >(table),
                  BaseReferences<
                    _$DownloadDatabase,
                    $DownloadRecordTableTable,
                    DownloadRecordTableData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DownloadRecordTableTableProcessedTableManager =
    ProcessedTableManager<
      _$DownloadDatabase,
      $DownloadRecordTableTable,
      DownloadRecordTableData,
      $$DownloadRecordTableTableFilterComposer,
      $$DownloadRecordTableTableOrderingComposer,
      $$DownloadRecordTableTableAnnotationComposer,
      $$DownloadRecordTableTableCreateCompanionBuilder,
      $$DownloadRecordTableTableUpdateCompanionBuilder,
      (
        DownloadRecordTableData,
        BaseReferences<
          _$DownloadDatabase,
          $DownloadRecordTableTable,
          DownloadRecordTableData
        >,
      ),
      DownloadRecordTableData,
      PrefetchHooks Function()
    >;
typedef $$DownloadTaskTableTableCreateCompanionBuilder =
    DownloadTaskTableCompanion Function({
      required String id,
      required String data,
      Value<int> rowid,
    });
typedef $$DownloadTaskTableTableUpdateCompanionBuilder =
    DownloadTaskTableCompanion Function({
      Value<String> id,
      Value<String> data,
      Value<int> rowid,
    });

class $$DownloadTaskTableTableFilterComposer
    extends Composer<_$DownloadDatabase, $DownloadTaskTableTable> {
  $$DownloadTaskTableTableFilterComposer({
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

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DownloadTaskTableTableOrderingComposer
    extends Composer<_$DownloadDatabase, $DownloadTaskTableTable> {
  $$DownloadTaskTableTableOrderingComposer({
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

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DownloadTaskTableTableAnnotationComposer
    extends Composer<_$DownloadDatabase, $DownloadTaskTableTable> {
  $$DownloadTaskTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);
}

class $$DownloadTaskTableTableTableManager
    extends
        RootTableManager<
          _$DownloadDatabase,
          $DownloadTaskTableTable,
          DownloadTaskTableData,
          $$DownloadTaskTableTableFilterComposer,
          $$DownloadTaskTableTableOrderingComposer,
          $$DownloadTaskTableTableAnnotationComposer,
          $$DownloadTaskTableTableCreateCompanionBuilder,
          $$DownloadTaskTableTableUpdateCompanionBuilder,
          (
            DownloadTaskTableData,
            BaseReferences<
              _$DownloadDatabase,
              $DownloadTaskTableTable,
              DownloadTaskTableData
            >,
          ),
          DownloadTaskTableData,
          PrefetchHooks Function()
        > {
  $$DownloadTaskTableTableTableManager(
    _$DownloadDatabase db,
    $DownloadTaskTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadTaskTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadTaskTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadTaskTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> data = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => DownloadTaskTableCompanion(id: id, data: data, rowid: rowid),
          createCompanionCallback:
              ({
                required String id,
                required String data,
                Value<int> rowid = const Value.absent(),
              }) => DownloadTaskTableCompanion.insert(
                id: id,
                data: data,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DownloadTaskTableTable, DownloadTaskTableData>(
                    table,
                  ),
                  BaseReferences<
                    _$DownloadDatabase,
                    $DownloadTaskTableTable,
                    DownloadTaskTableData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DownloadTaskTableTableProcessedTableManager =
    ProcessedTableManager<
      _$DownloadDatabase,
      $DownloadTaskTableTable,
      DownloadTaskTableData,
      $$DownloadTaskTableTableFilterComposer,
      $$DownloadTaskTableTableOrderingComposer,
      $$DownloadTaskTableTableAnnotationComposer,
      $$DownloadTaskTableTableCreateCompanionBuilder,
      $$DownloadTaskTableTableUpdateCompanionBuilder,
      (
        DownloadTaskTableData,
        BaseReferences<
          _$DownloadDatabase,
          $DownloadTaskTableTable,
          DownloadTaskTableData
        >,
      ),
      DownloadTaskTableData,
      PrefetchHooks Function()
    >;
typedef $$TorrentJobTableTableCreateCompanionBuilder =
    TorrentJobTableCompanion Function({
      required String id,
      required String data,
      Value<int> rowid,
    });
typedef $$TorrentJobTableTableUpdateCompanionBuilder =
    TorrentJobTableCompanion Function({
      Value<String> id,
      Value<String> data,
      Value<int> rowid,
    });

class $$TorrentJobTableTableFilterComposer
    extends Composer<_$DownloadDatabase, $TorrentJobTableTable> {
  $$TorrentJobTableTableFilterComposer({
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

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TorrentJobTableTableOrderingComposer
    extends Composer<_$DownloadDatabase, $TorrentJobTableTable> {
  $$TorrentJobTableTableOrderingComposer({
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

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TorrentJobTableTableAnnotationComposer
    extends Composer<_$DownloadDatabase, $TorrentJobTableTable> {
  $$TorrentJobTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);
}

class $$TorrentJobTableTableTableManager
    extends
        RootTableManager<
          _$DownloadDatabase,
          $TorrentJobTableTable,
          TorrentJobTableData,
          $$TorrentJobTableTableFilterComposer,
          $$TorrentJobTableTableOrderingComposer,
          $$TorrentJobTableTableAnnotationComposer,
          $$TorrentJobTableTableCreateCompanionBuilder,
          $$TorrentJobTableTableUpdateCompanionBuilder,
          (
            TorrentJobTableData,
            BaseReferences<
              _$DownloadDatabase,
              $TorrentJobTableTable,
              TorrentJobTableData
            >,
          ),
          TorrentJobTableData,
          PrefetchHooks Function()
        > {
  $$TorrentJobTableTableTableManager(
    _$DownloadDatabase db,
    $TorrentJobTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TorrentJobTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TorrentJobTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TorrentJobTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> data = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => TorrentJobTableCompanion(id: id, data: data, rowid: rowid),
          createCompanionCallback:
              ({
                required String id,
                required String data,
                Value<int> rowid = const Value.absent(),
              }) => TorrentJobTableCompanion.insert(
                id: id,
                data: data,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TorrentJobTableTable, TorrentJobTableData>(
                    table,
                  ),
                  BaseReferences<
                    _$DownloadDatabase,
                    $TorrentJobTableTable,
                    TorrentJobTableData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TorrentJobTableTableProcessedTableManager =
    ProcessedTableManager<
      _$DownloadDatabase,
      $TorrentJobTableTable,
      TorrentJobTableData,
      $$TorrentJobTableTableFilterComposer,
      $$TorrentJobTableTableOrderingComposer,
      $$TorrentJobTableTableAnnotationComposer,
      $$TorrentJobTableTableCreateCompanionBuilder,
      $$TorrentJobTableTableUpdateCompanionBuilder,
      (
        TorrentJobTableData,
        BaseReferences<
          _$DownloadDatabase,
          $TorrentJobTableTable,
          TorrentJobTableData
        >,
      ),
      TorrentJobTableData,
      PrefetchHooks Function()
    >;
typedef $$BtLineTableTableCreateCompanionBuilder =
    BtLineTableCompanion Function({
      required String contentKey,
      required String data,
      Value<int> rowid,
    });
typedef $$BtLineTableTableUpdateCompanionBuilder =
    BtLineTableCompanion Function({
      Value<String> contentKey,
      Value<String> data,
      Value<int> rowid,
    });

class $$BtLineTableTableFilterComposer
    extends Composer<_$DownloadDatabase, $BtLineTableTable> {
  $$BtLineTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get contentKey => $composableBuilder(
    column: $table.contentKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BtLineTableTableOrderingComposer
    extends Composer<_$DownloadDatabase, $BtLineTableTable> {
  $$BtLineTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get contentKey => $composableBuilder(
    column: $table.contentKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BtLineTableTableAnnotationComposer
    extends Composer<_$DownloadDatabase, $BtLineTableTable> {
  $$BtLineTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get contentKey => $composableBuilder(
    column: $table.contentKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);
}

class $$BtLineTableTableTableManager
    extends
        RootTableManager<
          _$DownloadDatabase,
          $BtLineTableTable,
          BtLineTableData,
          $$BtLineTableTableFilterComposer,
          $$BtLineTableTableOrderingComposer,
          $$BtLineTableTableAnnotationComposer,
          $$BtLineTableTableCreateCompanionBuilder,
          $$BtLineTableTableUpdateCompanionBuilder,
          (
            BtLineTableData,
            BaseReferences<
              _$DownloadDatabase,
              $BtLineTableTable,
              BtLineTableData
            >,
          ),
          BtLineTableData,
          PrefetchHooks Function()
        > {
  $$BtLineTableTableTableManager(_$DownloadDatabase db, $BtLineTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BtLineTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BtLineTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BtLineTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> contentKey = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BtLineTableCompanion(
                contentKey: contentKey,
                data: data,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String contentKey,
                required String data,
                Value<int> rowid = const Value.absent(),
              }) => BtLineTableCompanion.insert(
                contentKey: contentKey,
                data: data,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BtLineTableTable, BtLineTableData>(table),
                  BaseReferences<
                    _$DownloadDatabase,
                    $BtLineTableTable,
                    BtLineTableData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BtLineTableTableProcessedTableManager =
    ProcessedTableManager<
      _$DownloadDatabase,
      $BtLineTableTable,
      BtLineTableData,
      $$BtLineTableTableFilterComposer,
      $$BtLineTableTableOrderingComposer,
      $$BtLineTableTableAnnotationComposer,
      $$BtLineTableTableCreateCompanionBuilder,
      $$BtLineTableTableUpdateCompanionBuilder,
      (
        BtLineTableData,
        BaseReferences<_$DownloadDatabase, $BtLineTableTable, BtLineTableData>,
      ),
      BtLineTableData,
      PrefetchHooks Function()
    >;
typedef $$BtActiveTableTableCreateCompanionBuilder =
    BtActiveTableCompanion Function({
      required String contentKey,
      Value<int> rowid,
    });
typedef $$BtActiveTableTableUpdateCompanionBuilder =
    BtActiveTableCompanion Function({
      Value<String> contentKey,
      Value<int> rowid,
    });

class $$BtActiveTableTableFilterComposer
    extends Composer<_$DownloadDatabase, $BtActiveTableTable> {
  $$BtActiveTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get contentKey => $composableBuilder(
    column: $table.contentKey,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BtActiveTableTableOrderingComposer
    extends Composer<_$DownloadDatabase, $BtActiveTableTable> {
  $$BtActiveTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get contentKey => $composableBuilder(
    column: $table.contentKey,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BtActiveTableTableAnnotationComposer
    extends Composer<_$DownloadDatabase, $BtActiveTableTable> {
  $$BtActiveTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get contentKey => $composableBuilder(
    column: $table.contentKey,
    builder: (column) => column,
  );
}

class $$BtActiveTableTableTableManager
    extends
        RootTableManager<
          _$DownloadDatabase,
          $BtActiveTableTable,
          BtActiveTableData,
          $$BtActiveTableTableFilterComposer,
          $$BtActiveTableTableOrderingComposer,
          $$BtActiveTableTableAnnotationComposer,
          $$BtActiveTableTableCreateCompanionBuilder,
          $$BtActiveTableTableUpdateCompanionBuilder,
          (
            BtActiveTableData,
            BaseReferences<
              _$DownloadDatabase,
              $BtActiveTableTable,
              BtActiveTableData
            >,
          ),
          BtActiveTableData,
          PrefetchHooks Function()
        > {
  $$BtActiveTableTableTableManager(
    _$DownloadDatabase db,
    $BtActiveTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BtActiveTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BtActiveTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BtActiveTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> contentKey = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => BtActiveTableCompanion(contentKey: contentKey, rowid: rowid),
          createCompanionCallback:
              ({
                required String contentKey,
                Value<int> rowid = const Value.absent(),
              }) => BtActiveTableCompanion.insert(
                contentKey: contentKey,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BtActiveTableTable, BtActiveTableData>(table),
                  BaseReferences<
                    _$DownloadDatabase,
                    $BtActiveTableTable,
                    BtActiveTableData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BtActiveTableTableProcessedTableManager =
    ProcessedTableManager<
      _$DownloadDatabase,
      $BtActiveTableTable,
      BtActiveTableData,
      $$BtActiveTableTableFilterComposer,
      $$BtActiveTableTableOrderingComposer,
      $$BtActiveTableTableAnnotationComposer,
      $$BtActiveTableTableCreateCompanionBuilder,
      $$BtActiveTableTableUpdateCompanionBuilder,
      (
        BtActiveTableData,
        BaseReferences<
          _$DownloadDatabase,
          $BtActiveTableTable,
          BtActiveTableData
        >,
      ),
      BtActiveTableData,
      PrefetchHooks Function()
    >;
typedef $$TorrentBindingTableTableCreateCompanionBuilder =
    TorrentBindingTableCompanion Function({
      required String key,
      required String jobId,
      required String filePath,
      Value<String?> label,
      Value<int> rowid,
    });
typedef $$TorrentBindingTableTableUpdateCompanionBuilder =
    TorrentBindingTableCompanion Function({
      Value<String> key,
      Value<String> jobId,
      Value<String> filePath,
      Value<String?> label,
      Value<int> rowid,
    });

class $$TorrentBindingTableTableFilterComposer
    extends Composer<_$DownloadDatabase, $TorrentBindingTableTable> {
  $$TorrentBindingTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jobId => $composableBuilder(
    column: $table.jobId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TorrentBindingTableTableOrderingComposer
    extends Composer<_$DownloadDatabase, $TorrentBindingTableTable> {
  $$TorrentBindingTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jobId => $composableBuilder(
    column: $table.jobId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TorrentBindingTableTableAnnotationComposer
    extends Composer<_$DownloadDatabase, $TorrentBindingTableTable> {
  $$TorrentBindingTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get jobId =>
      $composableBuilder(column: $table.jobId, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);
}

class $$TorrentBindingTableTableTableManager
    extends
        RootTableManager<
          _$DownloadDatabase,
          $TorrentBindingTableTable,
          TorrentBindingTableData,
          $$TorrentBindingTableTableFilterComposer,
          $$TorrentBindingTableTableOrderingComposer,
          $$TorrentBindingTableTableAnnotationComposer,
          $$TorrentBindingTableTableCreateCompanionBuilder,
          $$TorrentBindingTableTableUpdateCompanionBuilder,
          (
            TorrentBindingTableData,
            BaseReferences<
              _$DownloadDatabase,
              $TorrentBindingTableTable,
              TorrentBindingTableData
            >,
          ),
          TorrentBindingTableData,
          PrefetchHooks Function()
        > {
  $$TorrentBindingTableTableTableManager(
    _$DownloadDatabase db,
    $TorrentBindingTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TorrentBindingTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TorrentBindingTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$TorrentBindingTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> jobId = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TorrentBindingTableCompanion(
                key: key,
                jobId: jobId,
                filePath: filePath,
                label: label,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String jobId,
                required String filePath,
                Value<String?> label = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TorrentBindingTableCompanion.insert(
                key: key,
                jobId: jobId,
                filePath: filePath,
                label: label,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $TorrentBindingTableTable,
                    TorrentBindingTableData
                  >(table),
                  BaseReferences<
                    _$DownloadDatabase,
                    $TorrentBindingTableTable,
                    TorrentBindingTableData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TorrentBindingTableTableProcessedTableManager =
    ProcessedTableManager<
      _$DownloadDatabase,
      $TorrentBindingTableTable,
      TorrentBindingTableData,
      $$TorrentBindingTableTableFilterComposer,
      $$TorrentBindingTableTableOrderingComposer,
      $$TorrentBindingTableTableAnnotationComposer,
      $$TorrentBindingTableTableCreateCompanionBuilder,
      $$TorrentBindingTableTableUpdateCompanionBuilder,
      (
        TorrentBindingTableData,
        BaseReferences<
          _$DownloadDatabase,
          $TorrentBindingTableTable,
          TorrentBindingTableData
        >,
      ),
      TorrentBindingTableData,
      PrefetchHooks Function()
    >;

class $DownloadDatabaseManager {
  final _$DownloadDatabase _db;
  $DownloadDatabaseManager(this._db);
  $$DownloadRecordTableTableTableManager get downloadRecordTable =>
      $$DownloadRecordTableTableTableManager(_db, _db.downloadRecordTable);
  $$DownloadTaskTableTableTableManager get downloadTaskTable =>
      $$DownloadTaskTableTableTableManager(_db, _db.downloadTaskTable);
  $$TorrentJobTableTableTableManager get torrentJobTable =>
      $$TorrentJobTableTableTableManager(_db, _db.torrentJobTable);
  $$BtLineTableTableTableManager get btLineTable =>
      $$BtLineTableTableTableManager(_db, _db.btLineTable);
  $$BtActiveTableTableTableManager get btActiveTable =>
      $$BtActiveTableTableTableManager(_db, _db.btActiveTable);
  $$TorrentBindingTableTableTableManager get torrentBindingTable =>
      $$TorrentBindingTableTableTableManager(_db, _db.torrentBindingTable);
}

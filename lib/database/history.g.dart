// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'history.dart';

// ignore_for_file: type=lint
class $HistoryTableTable extends HistoryTable
    with TableInfo<$HistoryTableTable, HistoryTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HistoryTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coverMeta = const VerificationMeta('cover');
  @override
  late final GeneratedColumn<String> cover = GeneratedColumn<String>(
    'cover',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timeMeta = const VerificationMeta('time');
  @override
  late final GeneratedColumn<int> time = GeneratedColumn<int>(
    'time',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
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
  static const VerificationMeta _lastWatchEpisodeMeta = const VerificationMeta(
    'lastWatchEpisode',
  );
  @override
  late final GeneratedColumn<int> lastWatchEpisode = GeneratedColumn<int>(
    'lastWatchEpisode',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastWatchTimeMeta = const VerificationMeta(
    'lastWatchTime',
  );
  @override
  late final GeneratedColumn<int> lastWatchTime = GeneratedColumn<int>(
    'lastWatchTime',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastRoadMeta = const VerificationMeta(
    'lastRoad',
  );
  @override
  late final GeneratedColumn<int> lastRoad = GeneratedColumn<int>(
    'lastRoad',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _allEpisodeMeta = const VerificationMeta(
    'allEpisode',
  );
  @override
  late final GeneratedColumn<int> allEpisode = GeneratedColumn<int>(
    'allEpisode',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _watchEpisodeMeta = const VerificationMeta(
    'watchEpisode',
  );
  @override
  late final GeneratedColumn<String> watchEpisode = GeneratedColumn<String>(
    'watchEpisode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _bangumiIdMeta = const VerificationMeta(
    'bangumiId',
  );
  @override
  late final GeneratedColumn<int> bangumiId = GeneratedColumn<int>(
    'bangumiId',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _viewMoreMeta = const VerificationMeta(
    'viewMore',
  );
  @override
  late final GeneratedColumn<String> viewMore = GeneratedColumn<String>(
    'viewMore',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    subtitle,
    cover,
    time,
    type,
    lastWatchEpisode,
    lastWatchTime,
    lastRoad,
    allEpisode,
    watchEpisode,
    bangumiId,
    viewMore,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'history';
  @override
  VerificationContext validateIntegrity(
    Insertable<HistoryTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
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
    } else if (isInserting) {
      context.missing(_subtitleMeta);
    }
    if (data.containsKey('cover')) {
      context.handle(
        _coverMeta,
        cover.isAcceptableOrUnknown(data['cover']!, _coverMeta),
      );
    } else if (isInserting) {
      context.missing(_coverMeta);
    }
    if (data.containsKey('time')) {
      context.handle(
        _timeMeta,
        time.isAcceptableOrUnknown(data['time']!, _timeMeta),
      );
    } else if (isInserting) {
      context.missing(_timeMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('lastWatchEpisode')) {
      context.handle(
        _lastWatchEpisodeMeta,
        lastWatchEpisode.isAcceptableOrUnknown(
          data['lastWatchEpisode']!,
          _lastWatchEpisodeMeta,
        ),
      );
    }
    if (data.containsKey('lastWatchTime')) {
      context.handle(
        _lastWatchTimeMeta,
        lastWatchTime.isAcceptableOrUnknown(
          data['lastWatchTime']!,
          _lastWatchTimeMeta,
        ),
      );
    }
    if (data.containsKey('lastRoad')) {
      context.handle(
        _lastRoadMeta,
        lastRoad.isAcceptableOrUnknown(data['lastRoad']!, _lastRoadMeta),
      );
    }
    if (data.containsKey('allEpisode')) {
      context.handle(
        _allEpisodeMeta,
        allEpisode.isAcceptableOrUnknown(data['allEpisode']!, _allEpisodeMeta),
      );
    }
    if (data.containsKey('watchEpisode')) {
      context.handle(
        _watchEpisodeMeta,
        watchEpisode.isAcceptableOrUnknown(
          data['watchEpisode']!,
          _watchEpisodeMeta,
        ),
      );
    }
    if (data.containsKey('bangumiId')) {
      context.handle(
        _bangumiIdMeta,
        bangumiId.isAcceptableOrUnknown(data['bangumiId']!, _bangumiIdMeta),
      );
    }
    if (data.containsKey('viewMore')) {
      context.handle(
        _viewMoreMeta,
        viewMore.isAcceptableOrUnknown(data['viewMore']!, _viewMoreMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HistoryTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HistoryTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      subtitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subtitle'],
      )!,
      cover: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover'],
      )!,
      time: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}time'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type'],
      )!,
      lastWatchEpisode: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lastWatchEpisode'],
      ),
      lastWatchTime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lastWatchTime'],
      ),
      lastRoad: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lastRoad'],
      ),
      allEpisode: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}allEpisode'],
      ),
      watchEpisode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}watchEpisode'],
      )!,
      bangumiId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bangumiId'],
      ),
      viewMore: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}viewMore'],
      ),
    );
  }

  @override
  $HistoryTableTable createAlias(String alias) {
    return $HistoryTableTable(attachedDatabase, alias);
  }
}

class HistoryTableData extends DataClass
    implements Insertable<HistoryTableData> {
  final String id;
  final String title;
  final String subtitle;
  final String cover;
  final int time;
  final int type;
  final int? lastWatchEpisode;
  final int? lastWatchTime;
  final int? lastRoad;
  final int? allEpisode;
  final String watchEpisode;
  final int? bangumiId;
  final String? viewMore;
  const HistoryTableData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.cover,
    required this.time,
    required this.type,
    this.lastWatchEpisode,
    this.lastWatchTime,
    this.lastRoad,
    this.allEpisode,
    required this.watchEpisode,
    this.bangumiId,
    this.viewMore,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['subtitle'] = Variable<String>(subtitle);
    map['cover'] = Variable<String>(cover);
    map['time'] = Variable<int>(time);
    map['type'] = Variable<int>(type);
    if (!nullToAbsent || lastWatchEpisode != null) {
      map['lastWatchEpisode'] = Variable<int>(lastWatchEpisode);
    }
    if (!nullToAbsent || lastWatchTime != null) {
      map['lastWatchTime'] = Variable<int>(lastWatchTime);
    }
    if (!nullToAbsent || lastRoad != null) {
      map['lastRoad'] = Variable<int>(lastRoad);
    }
    if (!nullToAbsent || allEpisode != null) {
      map['allEpisode'] = Variable<int>(allEpisode);
    }
    map['watchEpisode'] = Variable<String>(watchEpisode);
    if (!nullToAbsent || bangumiId != null) {
      map['bangumiId'] = Variable<int>(bangumiId);
    }
    if (!nullToAbsent || viewMore != null) {
      map['viewMore'] = Variable<String>(viewMore);
    }
    return map;
  }

  HistoryTableCompanion toCompanion(bool nullToAbsent) {
    return HistoryTableCompanion(
      id: Value(id),
      title: Value(title),
      subtitle: Value(subtitle),
      cover: Value(cover),
      time: Value(time),
      type: Value(type),
      lastWatchEpisode: lastWatchEpisode == null && nullToAbsent
          ? const Value.absent()
          : Value(lastWatchEpisode),
      lastWatchTime: lastWatchTime == null && nullToAbsent
          ? const Value.absent()
          : Value(lastWatchTime),
      lastRoad: lastRoad == null && nullToAbsent
          ? const Value.absent()
          : Value(lastRoad),
      allEpisode: allEpisode == null && nullToAbsent
          ? const Value.absent()
          : Value(allEpisode),
      watchEpisode: Value(watchEpisode),
      bangumiId: bangumiId == null && nullToAbsent
          ? const Value.absent()
          : Value(bangumiId),
      viewMore: viewMore == null && nullToAbsent
          ? const Value.absent()
          : Value(viewMore),
    );
  }

  factory HistoryTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HistoryTableData(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      subtitle: serializer.fromJson<String>(json['subtitle']),
      cover: serializer.fromJson<String>(json['cover']),
      time: serializer.fromJson<int>(json['time']),
      type: serializer.fromJson<int>(json['type']),
      lastWatchEpisode: serializer.fromJson<int?>(json['lastWatchEpisode']),
      lastWatchTime: serializer.fromJson<int?>(json['lastWatchTime']),
      lastRoad: serializer.fromJson<int?>(json['lastRoad']),
      allEpisode: serializer.fromJson<int?>(json['allEpisode']),
      watchEpisode: serializer.fromJson<String>(json['watchEpisode']),
      bangumiId: serializer.fromJson<int?>(json['bangumiId']),
      viewMore: serializer.fromJson<String?>(json['viewMore']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'subtitle': serializer.toJson<String>(subtitle),
      'cover': serializer.toJson<String>(cover),
      'time': serializer.toJson<int>(time),
      'type': serializer.toJson<int>(type),
      'lastWatchEpisode': serializer.toJson<int?>(lastWatchEpisode),
      'lastWatchTime': serializer.toJson<int?>(lastWatchTime),
      'lastRoad': serializer.toJson<int?>(lastRoad),
      'allEpisode': serializer.toJson<int?>(allEpisode),
      'watchEpisode': serializer.toJson<String>(watchEpisode),
      'bangumiId': serializer.toJson<int?>(bangumiId),
      'viewMore': serializer.toJson<String?>(viewMore),
    };
  }

  HistoryTableData copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? cover,
    int? time,
    int? type,
    Value<int?> lastWatchEpisode = const Value.absent(),
    Value<int?> lastWatchTime = const Value.absent(),
    Value<int?> lastRoad = const Value.absent(),
    Value<int?> allEpisode = const Value.absent(),
    String? watchEpisode,
    Value<int?> bangumiId = const Value.absent(),
    Value<String?> viewMore = const Value.absent(),
  }) => HistoryTableData(
    id: id ?? this.id,
    title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle,
    cover: cover ?? this.cover,
    time: time ?? this.time,
    type: type ?? this.type,
    lastWatchEpisode: lastWatchEpisode.present
        ? lastWatchEpisode.value
        : this.lastWatchEpisode,
    lastWatchTime: lastWatchTime.present
        ? lastWatchTime.value
        : this.lastWatchTime,
    lastRoad: lastRoad.present ? lastRoad.value : this.lastRoad,
    allEpisode: allEpisode.present ? allEpisode.value : this.allEpisode,
    watchEpisode: watchEpisode ?? this.watchEpisode,
    bangumiId: bangumiId.present ? bangumiId.value : this.bangumiId,
    viewMore: viewMore.present ? viewMore.value : this.viewMore,
  );
  HistoryTableData copyWithCompanion(HistoryTableCompanion data) {
    return HistoryTableData(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      subtitle: data.subtitle.present ? data.subtitle.value : this.subtitle,
      cover: data.cover.present ? data.cover.value : this.cover,
      time: data.time.present ? data.time.value : this.time,
      type: data.type.present ? data.type.value : this.type,
      lastWatchEpisode: data.lastWatchEpisode.present
          ? data.lastWatchEpisode.value
          : this.lastWatchEpisode,
      lastWatchTime: data.lastWatchTime.present
          ? data.lastWatchTime.value
          : this.lastWatchTime,
      lastRoad: data.lastRoad.present ? data.lastRoad.value : this.lastRoad,
      allEpisode: data.allEpisode.present
          ? data.allEpisode.value
          : this.allEpisode,
      watchEpisode: data.watchEpisode.present
          ? data.watchEpisode.value
          : this.watchEpisode,
      bangumiId: data.bangumiId.present ? data.bangumiId.value : this.bangumiId,
      viewMore: data.viewMore.present ? data.viewMore.value : this.viewMore,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HistoryTableData(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('subtitle: $subtitle, ')
          ..write('cover: $cover, ')
          ..write('time: $time, ')
          ..write('type: $type, ')
          ..write('lastWatchEpisode: $lastWatchEpisode, ')
          ..write('lastWatchTime: $lastWatchTime, ')
          ..write('lastRoad: $lastRoad, ')
          ..write('allEpisode: $allEpisode, ')
          ..write('watchEpisode: $watchEpisode, ')
          ..write('bangumiId: $bangumiId, ')
          ..write('viewMore: $viewMore')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    subtitle,
    cover,
    time,
    type,
    lastWatchEpisode,
    lastWatchTime,
    lastRoad,
    allEpisode,
    watchEpisode,
    bangumiId,
    viewMore,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HistoryTableData &&
          other.id == this.id &&
          other.title == this.title &&
          other.subtitle == this.subtitle &&
          other.cover == this.cover &&
          other.time == this.time &&
          other.type == this.type &&
          other.lastWatchEpisode == this.lastWatchEpisode &&
          other.lastWatchTime == this.lastWatchTime &&
          other.lastRoad == this.lastRoad &&
          other.allEpisode == this.allEpisode &&
          other.watchEpisode == this.watchEpisode &&
          other.bangumiId == this.bangumiId &&
          other.viewMore == this.viewMore);
}

class HistoryTableCompanion extends UpdateCompanion<HistoryTableData> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> subtitle;
  final Value<String> cover;
  final Value<int> time;
  final Value<int> type;
  final Value<int?> lastWatchEpisode;
  final Value<int?> lastWatchTime;
  final Value<int?> lastRoad;
  final Value<int?> allEpisode;
  final Value<String> watchEpisode;
  final Value<int?> bangumiId;
  final Value<String?> viewMore;
  final Value<int> rowid;
  const HistoryTableCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.subtitle = const Value.absent(),
    this.cover = const Value.absent(),
    this.time = const Value.absent(),
    this.type = const Value.absent(),
    this.lastWatchEpisode = const Value.absent(),
    this.lastWatchTime = const Value.absent(),
    this.lastRoad = const Value.absent(),
    this.allEpisode = const Value.absent(),
    this.watchEpisode = const Value.absent(),
    this.bangumiId = const Value.absent(),
    this.viewMore = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HistoryTableCompanion.insert({
    required String id,
    required String title,
    required String subtitle,
    required String cover,
    required int time,
    required int type,
    this.lastWatchEpisode = const Value.absent(),
    this.lastWatchTime = const Value.absent(),
    this.lastRoad = const Value.absent(),
    this.allEpisode = const Value.absent(),
    this.watchEpisode = const Value.absent(),
    this.bangumiId = const Value.absent(),
    this.viewMore = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       subtitle = Value(subtitle),
       cover = Value(cover),
       time = Value(time),
       type = Value(type);
  static Insertable<HistoryTableData> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? subtitle,
    Expression<String>? cover,
    Expression<int>? time,
    Expression<int>? type,
    Expression<int>? lastWatchEpisode,
    Expression<int>? lastWatchTime,
    Expression<int>? lastRoad,
    Expression<int>? allEpisode,
    Expression<String>? watchEpisode,
    Expression<int>? bangumiId,
    Expression<String>? viewMore,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (subtitle != null) 'subtitle': subtitle,
      if (cover != null) 'cover': cover,
      if (time != null) 'time': time,
      if (type != null) 'type': type,
      if (lastWatchEpisode != null) 'lastWatchEpisode': lastWatchEpisode,
      if (lastWatchTime != null) 'lastWatchTime': lastWatchTime,
      if (lastRoad != null) 'lastRoad': lastRoad,
      if (allEpisode != null) 'allEpisode': allEpisode,
      if (watchEpisode != null) 'watchEpisode': watchEpisode,
      if (bangumiId != null) 'bangumiId': bangumiId,
      if (viewMore != null) 'viewMore': viewMore,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HistoryTableCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? subtitle,
    Value<String>? cover,
    Value<int>? time,
    Value<int>? type,
    Value<int?>? lastWatchEpisode,
    Value<int?>? lastWatchTime,
    Value<int?>? lastRoad,
    Value<int?>? allEpisode,
    Value<String>? watchEpisode,
    Value<int?>? bangumiId,
    Value<String?>? viewMore,
    Value<int>? rowid,
  }) {
    return HistoryTableCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      cover: cover ?? this.cover,
      time: time ?? this.time,
      type: type ?? this.type,
      lastWatchEpisode: lastWatchEpisode ?? this.lastWatchEpisode,
      lastWatchTime: lastWatchTime ?? this.lastWatchTime,
      lastRoad: lastRoad ?? this.lastRoad,
      allEpisode: allEpisode ?? this.allEpisode,
      watchEpisode: watchEpisode ?? this.watchEpisode,
      bangumiId: bangumiId ?? this.bangumiId,
      viewMore: viewMore ?? this.viewMore,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (subtitle.present) {
      map['subtitle'] = Variable<String>(subtitle.value);
    }
    if (cover.present) {
      map['cover'] = Variable<String>(cover.value);
    }
    if (time.present) {
      map['time'] = Variable<int>(time.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(type.value);
    }
    if (lastWatchEpisode.present) {
      map['lastWatchEpisode'] = Variable<int>(lastWatchEpisode.value);
    }
    if (lastWatchTime.present) {
      map['lastWatchTime'] = Variable<int>(lastWatchTime.value);
    }
    if (lastRoad.present) {
      map['lastRoad'] = Variable<int>(lastRoad.value);
    }
    if (allEpisode.present) {
      map['allEpisode'] = Variable<int>(allEpisode.value);
    }
    if (watchEpisode.present) {
      map['watchEpisode'] = Variable<String>(watchEpisode.value);
    }
    if (bangumiId.present) {
      map['bangumiId'] = Variable<int>(bangumiId.value);
    }
    if (viewMore.present) {
      map['viewMore'] = Variable<String>(viewMore.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HistoryTableCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('subtitle: $subtitle, ')
          ..write('cover: $cover, ')
          ..write('time: $time, ')
          ..write('type: $type, ')
          ..write('lastWatchEpisode: $lastWatchEpisode, ')
          ..write('lastWatchTime: $lastWatchTime, ')
          ..write('lastRoad: $lastRoad, ')
          ..write('allEpisode: $allEpisode, ')
          ..write('watchEpisode: $watchEpisode, ')
          ..write('bangumiId: $bangumiId, ')
          ..write('viewMore: $viewMore, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProgressTableTable extends ProgressTable
    with TableInfo<$ProgressTableTable, ProgressTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProgressTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<int> type = GeneratedColumn<int>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _historyIdMeta = const VerificationMeta(
    'historyId',
  );
  @override
  late final GeneratedColumn<String> historyId = GeneratedColumn<String>(
    'historyId',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _episodeMeta = const VerificationMeta(
    'episode',
  );
  @override
  late final GeneratedColumn<int> episode = GeneratedColumn<int>(
    'episode',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roadMeta = const VerificationMeta('road');
  @override
  late final GeneratedColumn<int> road = GeneratedColumn<int>(
    'road',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _progressInMilliMeta = const VerificationMeta(
    'progressInMilli',
  );
  @override
  late final GeneratedColumn<int> progressInMilli = GeneratedColumn<int>(
    'progressInMilli',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isCompletedMeta = const VerificationMeta(
    'isCompleted',
  );
  @override
  late final GeneratedColumn<bool> isCompleted = GeneratedColumn<bool>(
    'isCompleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("isCompleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _startTimeMeta = const VerificationMeta(
    'startTime',
  );
  @override
  late final GeneratedColumn<String> startTime = GeneratedColumn<String>(
    'startTime',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endTimeMeta = const VerificationMeta(
    'endTime',
  );
  @override
  late final GeneratedColumn<String> endTime = GeneratedColumn<String>(
    'endTime',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    type,
    historyId,
    episode,
    road,
    progressInMilli,
    isCompleted,
    startTime,
    endTime,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'progress';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProgressTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('historyId')) {
      context.handle(
        _historyIdMeta,
        historyId.isAcceptableOrUnknown(data['historyId']!, _historyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_historyIdMeta);
    }
    if (data.containsKey('episode')) {
      context.handle(
        _episodeMeta,
        episode.isAcceptableOrUnknown(data['episode']!, _episodeMeta),
      );
    } else if (isInserting) {
      context.missing(_episodeMeta);
    }
    if (data.containsKey('road')) {
      context.handle(
        _roadMeta,
        road.isAcceptableOrUnknown(data['road']!, _roadMeta),
      );
    } else if (isInserting) {
      context.missing(_roadMeta);
    }
    if (data.containsKey('progressInMilli')) {
      context.handle(
        _progressInMilliMeta,
        progressInMilli.isAcceptableOrUnknown(
          data['progressInMilli']!,
          _progressInMilliMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_progressInMilliMeta);
    }
    if (data.containsKey('isCompleted')) {
      context.handle(
        _isCompletedMeta,
        isCompleted.isAcceptableOrUnknown(
          data['isCompleted']!,
          _isCompletedMeta,
        ),
      );
    }
    if (data.containsKey('startTime')) {
      context.handle(
        _startTimeMeta,
        startTime.isAcceptableOrUnknown(data['startTime']!, _startTimeMeta),
      );
    }
    if (data.containsKey('endTime')) {
      context.handle(
        _endTimeMeta,
        endTime.isAcceptableOrUnknown(data['endTime']!, _endTimeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {type, episode, road, historyId};
  @override
  ProgressTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProgressTableData(
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type'],
      )!,
      historyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}historyId'],
      )!,
      episode: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}episode'],
      )!,
      road: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}road'],
      )!,
      progressInMilli: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}progressInMilli'],
      )!,
      isCompleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}isCompleted'],
      )!,
      startTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}startTime'],
      ),
      endTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}endTime'],
      ),
    );
  }

  @override
  $ProgressTableTable createAlias(String alias) {
    return $ProgressTableTable(attachedDatabase, alias);
  }
}

class ProgressTableData extends DataClass
    implements Insertable<ProgressTableData> {
  final int type;
  final String historyId;
  final int episode;
  final int road;
  final int progressInMilli;
  final bool isCompleted;
  final String? startTime;
  final String? endTime;
  const ProgressTableData({
    required this.type,
    required this.historyId,
    required this.episode,
    required this.road,
    required this.progressInMilli,
    required this.isCompleted,
    this.startTime,
    this.endTime,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['type'] = Variable<int>(type);
    map['historyId'] = Variable<String>(historyId);
    map['episode'] = Variable<int>(episode);
    map['road'] = Variable<int>(road);
    map['progressInMilli'] = Variable<int>(progressInMilli);
    map['isCompleted'] = Variable<bool>(isCompleted);
    if (!nullToAbsent || startTime != null) {
      map['startTime'] = Variable<String>(startTime);
    }
    if (!nullToAbsent || endTime != null) {
      map['endTime'] = Variable<String>(endTime);
    }
    return map;
  }

  ProgressTableCompanion toCompanion(bool nullToAbsent) {
    return ProgressTableCompanion(
      type: Value(type),
      historyId: Value(historyId),
      episode: Value(episode),
      road: Value(road),
      progressInMilli: Value(progressInMilli),
      isCompleted: Value(isCompleted),
      startTime: startTime == null && nullToAbsent
          ? const Value.absent()
          : Value(startTime),
      endTime: endTime == null && nullToAbsent
          ? const Value.absent()
          : Value(endTime),
    );
  }

  factory ProgressTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProgressTableData(
      type: serializer.fromJson<int>(json['type']),
      historyId: serializer.fromJson<String>(json['historyId']),
      episode: serializer.fromJson<int>(json['episode']),
      road: serializer.fromJson<int>(json['road']),
      progressInMilli: serializer.fromJson<int>(json['progressInMilli']),
      isCompleted: serializer.fromJson<bool>(json['isCompleted']),
      startTime: serializer.fromJson<String?>(json['startTime']),
      endTime: serializer.fromJson<String?>(json['endTime']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'type': serializer.toJson<int>(type),
      'historyId': serializer.toJson<String>(historyId),
      'episode': serializer.toJson<int>(episode),
      'road': serializer.toJson<int>(road),
      'progressInMilli': serializer.toJson<int>(progressInMilli),
      'isCompleted': serializer.toJson<bool>(isCompleted),
      'startTime': serializer.toJson<String?>(startTime),
      'endTime': serializer.toJson<String?>(endTime),
    };
  }

  ProgressTableData copyWith({
    int? type,
    String? historyId,
    int? episode,
    int? road,
    int? progressInMilli,
    bool? isCompleted,
    Value<String?> startTime = const Value.absent(),
    Value<String?> endTime = const Value.absent(),
  }) => ProgressTableData(
    type: type ?? this.type,
    historyId: historyId ?? this.historyId,
    episode: episode ?? this.episode,
    road: road ?? this.road,
    progressInMilli: progressInMilli ?? this.progressInMilli,
    isCompleted: isCompleted ?? this.isCompleted,
    startTime: startTime.present ? startTime.value : this.startTime,
    endTime: endTime.present ? endTime.value : this.endTime,
  );
  ProgressTableData copyWithCompanion(ProgressTableCompanion data) {
    return ProgressTableData(
      type: data.type.present ? data.type.value : this.type,
      historyId: data.historyId.present ? data.historyId.value : this.historyId,
      episode: data.episode.present ? data.episode.value : this.episode,
      road: data.road.present ? data.road.value : this.road,
      progressInMilli: data.progressInMilli.present
          ? data.progressInMilli.value
          : this.progressInMilli,
      isCompleted: data.isCompleted.present
          ? data.isCompleted.value
          : this.isCompleted,
      startTime: data.startTime.present ? data.startTime.value : this.startTime,
      endTime: data.endTime.present ? data.endTime.value : this.endTime,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProgressTableData(')
          ..write('type: $type, ')
          ..write('historyId: $historyId, ')
          ..write('episode: $episode, ')
          ..write('road: $road, ')
          ..write('progressInMilli: $progressInMilli, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    type,
    historyId,
    episode,
    road,
    progressInMilli,
    isCompleted,
    startTime,
    endTime,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProgressTableData &&
          other.type == this.type &&
          other.historyId == this.historyId &&
          other.episode == this.episode &&
          other.road == this.road &&
          other.progressInMilli == this.progressInMilli &&
          other.isCompleted == this.isCompleted &&
          other.startTime == this.startTime &&
          other.endTime == this.endTime);
}

class ProgressTableCompanion extends UpdateCompanion<ProgressTableData> {
  final Value<int> type;
  final Value<String> historyId;
  final Value<int> episode;
  final Value<int> road;
  final Value<int> progressInMilli;
  final Value<bool> isCompleted;
  final Value<String?> startTime;
  final Value<String?> endTime;
  final Value<int> rowid;
  const ProgressTableCompanion({
    this.type = const Value.absent(),
    this.historyId = const Value.absent(),
    this.episode = const Value.absent(),
    this.road = const Value.absent(),
    this.progressInMilli = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProgressTableCompanion.insert({
    required int type,
    required String historyId,
    required int episode,
    required int road,
    required int progressInMilli,
    this.isCompleted = const Value.absent(),
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : type = Value(type),
       historyId = Value(historyId),
       episode = Value(episode),
       road = Value(road),
       progressInMilli = Value(progressInMilli);
  static Insertable<ProgressTableData> custom({
    Expression<int>? type,
    Expression<String>? historyId,
    Expression<int>? episode,
    Expression<int>? road,
    Expression<int>? progressInMilli,
    Expression<bool>? isCompleted,
    Expression<String>? startTime,
    Expression<String>? endTime,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (type != null) 'type': type,
      if (historyId != null) 'historyId': historyId,
      if (episode != null) 'episode': episode,
      if (road != null) 'road': road,
      if (progressInMilli != null) 'progressInMilli': progressInMilli,
      if (isCompleted != null) 'isCompleted': isCompleted,
      if (startTime != null) 'startTime': startTime,
      if (endTime != null) 'endTime': endTime,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProgressTableCompanion copyWith({
    Value<int>? type,
    Value<String>? historyId,
    Value<int>? episode,
    Value<int>? road,
    Value<int>? progressInMilli,
    Value<bool>? isCompleted,
    Value<String?>? startTime,
    Value<String?>? endTime,
    Value<int>? rowid,
  }) {
    return ProgressTableCompanion(
      type: type ?? this.type,
      historyId: historyId ?? this.historyId,
      episode: episode ?? this.episode,
      road: road ?? this.road,
      progressInMilli: progressInMilli ?? this.progressInMilli,
      isCompleted: isCompleted ?? this.isCompleted,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (type.present) {
      map['type'] = Variable<int>(type.value);
    }
    if (historyId.present) {
      map['historyId'] = Variable<String>(historyId.value);
    }
    if (episode.present) {
      map['episode'] = Variable<int>(episode.value);
    }
    if (road.present) {
      map['road'] = Variable<int>(road.value);
    }
    if (progressInMilli.present) {
      map['progressInMilli'] = Variable<int>(progressInMilli.value);
    }
    if (isCompleted.present) {
      map['isCompleted'] = Variable<bool>(isCompleted.value);
    }
    if (startTime.present) {
      map['startTime'] = Variable<String>(startTime.value);
    }
    if (endTime.present) {
      map['endTime'] = Variable<String>(endTime.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProgressTableCompanion(')
          ..write('type: $type, ')
          ..write('historyId: $historyId, ')
          ..write('episode: $episode, ')
          ..write('road: $road, ')
          ..write('progressInMilli: $progressInMilli, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$_HistoryDb extends GeneratedDatabase {
  _$_HistoryDb(QueryExecutor e) : super(e);
  $_HistoryDbManager get managers => $_HistoryDbManager(this);
  late final $HistoryTableTable historyTable = $HistoryTableTable(this);
  late final $ProgressTableTable progressTable = $ProgressTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    historyTable,
    progressTable,
  ];
}

typedef $$HistoryTableTableCreateCompanionBuilder =
    HistoryTableCompanion Function({
      required String id,
      required String title,
      required String subtitle,
      required String cover,
      required int time,
      required int type,
      Value<int?> lastWatchEpisode,
      Value<int?> lastWatchTime,
      Value<int?> lastRoad,
      Value<int?> allEpisode,
      Value<String> watchEpisode,
      Value<int?> bangumiId,
      Value<String?> viewMore,
      Value<int> rowid,
    });
typedef $$HistoryTableTableUpdateCompanionBuilder =
    HistoryTableCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> subtitle,
      Value<String> cover,
      Value<int> time,
      Value<int> type,
      Value<int?> lastWatchEpisode,
      Value<int?> lastWatchTime,
      Value<int?> lastRoad,
      Value<int?> allEpisode,
      Value<String> watchEpisode,
      Value<int?> bangumiId,
      Value<String?> viewMore,
      Value<int> rowid,
    });

class $$HistoryTableTableFilterComposer
    extends Composer<_$_HistoryDb, $HistoryTableTable> {
  $$HistoryTableTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subtitle => $composableBuilder(
    column: $table.subtitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cover => $composableBuilder(
    column: $table.cover,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastWatchEpisode => $composableBuilder(
    column: $table.lastWatchEpisode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastWatchTime => $composableBuilder(
    column: $table.lastWatchTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastRoad => $composableBuilder(
    column: $table.lastRoad,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get allEpisode => $composableBuilder(
    column: $table.allEpisode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get watchEpisode => $composableBuilder(
    column: $table.watchEpisode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bangumiId => $composableBuilder(
    column: $table.bangumiId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get viewMore => $composableBuilder(
    column: $table.viewMore,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HistoryTableTableOrderingComposer
    extends Composer<_$_HistoryDb, $HistoryTableTable> {
  $$HistoryTableTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subtitle => $composableBuilder(
    column: $table.subtitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cover => $composableBuilder(
    column: $table.cover,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastWatchEpisode => $composableBuilder(
    column: $table.lastWatchEpisode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastWatchTime => $composableBuilder(
    column: $table.lastWatchTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastRoad => $composableBuilder(
    column: $table.lastRoad,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get allEpisode => $composableBuilder(
    column: $table.allEpisode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get watchEpisode => $composableBuilder(
    column: $table.watchEpisode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bangumiId => $composableBuilder(
    column: $table.bangumiId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get viewMore => $composableBuilder(
    column: $table.viewMore,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HistoryTableTableAnnotationComposer
    extends Composer<_$_HistoryDb, $HistoryTableTable> {
  $$HistoryTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get subtitle =>
      $composableBuilder(column: $table.subtitle, builder: (column) => column);

  GeneratedColumn<String> get cover =>
      $composableBuilder(column: $table.cover, builder: (column) => column);

  GeneratedColumn<int> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);

  GeneratedColumn<int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get lastWatchEpisode => $composableBuilder(
    column: $table.lastWatchEpisode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastWatchTime => $composableBuilder(
    column: $table.lastWatchTime,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastRoad =>
      $composableBuilder(column: $table.lastRoad, builder: (column) => column);

  GeneratedColumn<int> get allEpisode => $composableBuilder(
    column: $table.allEpisode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get watchEpisode => $composableBuilder(
    column: $table.watchEpisode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get bangumiId =>
      $composableBuilder(column: $table.bangumiId, builder: (column) => column);

  GeneratedColumn<String> get viewMore =>
      $composableBuilder(column: $table.viewMore, builder: (column) => column);
}

class $$HistoryTableTableTableManager
    extends
        RootTableManager<
          _$_HistoryDb,
          $HistoryTableTable,
          HistoryTableData,
          $$HistoryTableTableFilterComposer,
          $$HistoryTableTableOrderingComposer,
          $$HistoryTableTableAnnotationComposer,
          $$HistoryTableTableCreateCompanionBuilder,
          $$HistoryTableTableUpdateCompanionBuilder,
          (
            HistoryTableData,
            BaseReferences<_$_HistoryDb, $HistoryTableTable, HistoryTableData>,
          ),
          HistoryTableData,
          PrefetchHooks Function()
        > {
  $$HistoryTableTableTableManager(_$_HistoryDb db, $HistoryTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HistoryTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HistoryTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HistoryTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> subtitle = const Value.absent(),
                Value<String> cover = const Value.absent(),
                Value<int> time = const Value.absent(),
                Value<int> type = const Value.absent(),
                Value<int?> lastWatchEpisode = const Value.absent(),
                Value<int?> lastWatchTime = const Value.absent(),
                Value<int?> lastRoad = const Value.absent(),
                Value<int?> allEpisode = const Value.absent(),
                Value<String> watchEpisode = const Value.absent(),
                Value<int?> bangumiId = const Value.absent(),
                Value<String?> viewMore = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HistoryTableCompanion(
                id: id,
                title: title,
                subtitle: subtitle,
                cover: cover,
                time: time,
                type: type,
                lastWatchEpisode: lastWatchEpisode,
                lastWatchTime: lastWatchTime,
                lastRoad: lastRoad,
                allEpisode: allEpisode,
                watchEpisode: watchEpisode,
                bangumiId: bangumiId,
                viewMore: viewMore,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required String subtitle,
                required String cover,
                required int time,
                required int type,
                Value<int?> lastWatchEpisode = const Value.absent(),
                Value<int?> lastWatchTime = const Value.absent(),
                Value<int?> lastRoad = const Value.absent(),
                Value<int?> allEpisode = const Value.absent(),
                Value<String> watchEpisode = const Value.absent(),
                Value<int?> bangumiId = const Value.absent(),
                Value<String?> viewMore = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HistoryTableCompanion.insert(
                id: id,
                title: title,
                subtitle: subtitle,
                cover: cover,
                time: time,
                type: type,
                lastWatchEpisode: lastWatchEpisode,
                lastWatchTime: lastWatchTime,
                lastRoad: lastRoad,
                allEpisode: allEpisode,
                watchEpisode: watchEpisode,
                bangumiId: bangumiId,
                viewMore: viewMore,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$HistoryTableTable, HistoryTableData>(table),
                  BaseReferences<
                    _$_HistoryDb,
                    $HistoryTableTable,
                    HistoryTableData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HistoryTableTableProcessedTableManager =
    ProcessedTableManager<
      _$_HistoryDb,
      $HistoryTableTable,
      HistoryTableData,
      $$HistoryTableTableFilterComposer,
      $$HistoryTableTableOrderingComposer,
      $$HistoryTableTableAnnotationComposer,
      $$HistoryTableTableCreateCompanionBuilder,
      $$HistoryTableTableUpdateCompanionBuilder,
      (
        HistoryTableData,
        BaseReferences<_$_HistoryDb, $HistoryTableTable, HistoryTableData>,
      ),
      HistoryTableData,
      PrefetchHooks Function()
    >;
typedef $$ProgressTableTableCreateCompanionBuilder =
    ProgressTableCompanion Function({
      required int type,
      required String historyId,
      required int episode,
      required int road,
      required int progressInMilli,
      Value<bool> isCompleted,
      Value<String?> startTime,
      Value<String?> endTime,
      Value<int> rowid,
    });
typedef $$ProgressTableTableUpdateCompanionBuilder =
    ProgressTableCompanion Function({
      Value<int> type,
      Value<String> historyId,
      Value<int> episode,
      Value<int> road,
      Value<int> progressInMilli,
      Value<bool> isCompleted,
      Value<String?> startTime,
      Value<String?> endTime,
      Value<int> rowid,
    });

class $$ProgressTableTableFilterComposer
    extends Composer<_$_HistoryDb, $ProgressTableTable> {
  $$ProgressTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get historyId => $composableBuilder(
    column: $table.historyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get episode => $composableBuilder(
    column: $table.episode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get road => $composableBuilder(
    column: $table.road,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get progressInMilli => $composableBuilder(
    column: $table.progressInMilli,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProgressTableTableOrderingComposer
    extends Composer<_$_HistoryDb, $ProgressTableTable> {
  $$ProgressTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get historyId => $composableBuilder(
    column: $table.historyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get episode => $composableBuilder(
    column: $table.episode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get road => $composableBuilder(
    column: $table.road,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get progressInMilli => $composableBuilder(
    column: $table.progressInMilli,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProgressTableTableAnnotationComposer
    extends Composer<_$_HistoryDb, $ProgressTableTable> {
  $$ProgressTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get historyId =>
      $composableBuilder(column: $table.historyId, builder: (column) => column);

  GeneratedColumn<int> get episode =>
      $composableBuilder(column: $table.episode, builder: (column) => column);

  GeneratedColumn<int> get road =>
      $composableBuilder(column: $table.road, builder: (column) => column);

  GeneratedColumn<int> get progressInMilli => $composableBuilder(
    column: $table.progressInMilli,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => column,
  );

  GeneratedColumn<String> get startTime =>
      $composableBuilder(column: $table.startTime, builder: (column) => column);

  GeneratedColumn<String> get endTime =>
      $composableBuilder(column: $table.endTime, builder: (column) => column);
}

class $$ProgressTableTableTableManager
    extends
        RootTableManager<
          _$_HistoryDb,
          $ProgressTableTable,
          ProgressTableData,
          $$ProgressTableTableFilterComposer,
          $$ProgressTableTableOrderingComposer,
          $$ProgressTableTableAnnotationComposer,
          $$ProgressTableTableCreateCompanionBuilder,
          $$ProgressTableTableUpdateCompanionBuilder,
          (
            ProgressTableData,
            BaseReferences<
              _$_HistoryDb,
              $ProgressTableTable,
              ProgressTableData
            >,
          ),
          ProgressTableData,
          PrefetchHooks Function()
        > {
  $$ProgressTableTableTableManager(_$_HistoryDb db, $ProgressTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProgressTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProgressTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProgressTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> type = const Value.absent(),
                Value<String> historyId = const Value.absent(),
                Value<int> episode = const Value.absent(),
                Value<int> road = const Value.absent(),
                Value<int> progressInMilli = const Value.absent(),
                Value<bool> isCompleted = const Value.absent(),
                Value<String?> startTime = const Value.absent(),
                Value<String?> endTime = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProgressTableCompanion(
                type: type,
                historyId: historyId,
                episode: episode,
                road: road,
                progressInMilli: progressInMilli,
                isCompleted: isCompleted,
                startTime: startTime,
                endTime: endTime,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int type,
                required String historyId,
                required int episode,
                required int road,
                required int progressInMilli,
                Value<bool> isCompleted = const Value.absent(),
                Value<String?> startTime = const Value.absent(),
                Value<String?> endTime = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProgressTableCompanion.insert(
                type: type,
                historyId: historyId,
                episode: episode,
                road: road,
                progressInMilli: progressInMilli,
                isCompleted: isCompleted,
                startTime: startTime,
                endTime: endTime,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProgressTableTable, ProgressTableData>(table),
                  BaseReferences<
                    _$_HistoryDb,
                    $ProgressTableTable,
                    ProgressTableData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProgressTableTableProcessedTableManager =
    ProcessedTableManager<
      _$_HistoryDb,
      $ProgressTableTable,
      ProgressTableData,
      $$ProgressTableTableFilterComposer,
      $$ProgressTableTableOrderingComposer,
      $$ProgressTableTableAnnotationComposer,
      $$ProgressTableTableCreateCompanionBuilder,
      $$ProgressTableTableUpdateCompanionBuilder,
      (
        ProgressTableData,
        BaseReferences<_$_HistoryDb, $ProgressTableTable, ProgressTableData>,
      ),
      ProgressTableData,
      PrefetchHooks Function()
    >;

class $_HistoryDbManager {
  final _$_HistoryDb _db;
  $_HistoryDbManager(this._db);
  $$HistoryTableTableTableManager get historyTable =>
      $$HistoryTableTableTableManager(_db, _db.historyTable);
  $$ProgressTableTableTableManager get progressTable =>
      $$ProgressTableTableTableManager(_db, _db.progressTable);
}

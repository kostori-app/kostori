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
    'pluginKey',
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
    'itemKey',
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
    'coverUrl',
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
    'extraJson',
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
    'createdAt',
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
    if (data.containsKey('pluginKey')) {
      context.handle(
        _pluginKeyMeta,
        pluginKey.isAcceptableOrUnknown(data['pluginKey']!, _pluginKeyMeta),
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
    if (data.containsKey('itemKey')) {
      context.handle(
        _itemKeyMeta,
        itemKey.isAcceptableOrUnknown(data['itemKey']!, _itemKeyMeta),
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
    if (data.containsKey('coverUrl')) {
      context.handle(
        _coverUrlMeta,
        coverUrl.isAcceptableOrUnknown(data['coverUrl']!, _coverUrlMeta),
      );
    }
    if (data.containsKey('extraJson')) {
      context.handle(
        _extraJsonMeta,
        extraJson.isAcceptableOrUnknown(data['extraJson']!, _extraJsonMeta),
      );
    }
    if (data.containsKey('createdAt')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['createdAt']!, _createdAtMeta),
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
        data['${effectivePrefix}pluginKey'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      itemKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}itemKey'],
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
        data['${effectivePrefix}coverUrl'],
      )!,
      extraJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extraJson'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}createdAt'],
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
    map['pluginKey'] = Variable<String>(pluginKey);
    map['kind'] = Variable<String>(kind);
    map['itemKey'] = Variable<String>(itemKey);
    map['title'] = Variable<String>(title);
    map['subtitle'] = Variable<String>(subtitle);
    map['coverUrl'] = Variable<String>(coverUrl);
    map['extraJson'] = Variable<String>(extraJson);
    map['createdAt'] = Variable<int>(createdAt);
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
      if (pluginKey != null) 'pluginKey': pluginKey,
      if (kind != null) 'kind': kind,
      if (itemKey != null) 'itemKey': itemKey,
      if (title != null) 'title': title,
      if (subtitle != null) 'subtitle': subtitle,
      if (coverUrl != null) 'coverUrl': coverUrl,
      if (extraJson != null) 'extraJson': extraJson,
      if (createdAt != null) 'createdAt': createdAt,
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
      map['pluginKey'] = Variable<String>(pluginKey.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (itemKey.present) {
      map['itemKey'] = Variable<String>(itemKey.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (subtitle.present) {
      map['subtitle'] = Variable<String>(subtitle.value);
    }
    if (coverUrl.present) {
      map['coverUrl'] = Variable<String>(coverUrl.value);
    }
    if (extraJson.present) {
      map['extraJson'] = Variable<String>(extraJson.value);
    }
    if (createdAt.present) {
      map['createdAt'] = Variable<int>(createdAt.value);
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

class $TextRuleTableTable extends TextRuleTable
    with TableInfo<$TextRuleTableTable, TextRuleTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TextRuleTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _stepsJsonMeta = const VerificationMeta(
    'stepsJson',
  );
  @override
  late final GeneratedColumn<String> stepsJson = GeneratedColumn<String>(
    'stepsJson',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _sortMeta = const VerificationMeta('sort');
  @override
  late final GeneratedColumn<int> sort = GeneratedColumn<int>(
    'sort',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'createdAt',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, stepsJson, sort, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'text_rules';
  @override
  VerificationContext validateIntegrity(
    Insertable<TextRuleTableData> instance, {
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
    if (data.containsKey('stepsJson')) {
      context.handle(
        _stepsJsonMeta,
        stepsJson.isAcceptableOrUnknown(data['stepsJson']!, _stepsJsonMeta),
      );
    }
    if (data.containsKey('sort')) {
      context.handle(
        _sortMeta,
        sort.isAcceptableOrUnknown(data['sort']!, _sortMeta),
      );
    }
    if (data.containsKey('createdAt')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['createdAt']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TextRuleTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TextRuleTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      stepsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stepsJson'],
      )!,
      sort: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}createdAt'],
      )!,
    );
  }

  @override
  $TextRuleTableTable createAlias(String alias) {
    return $TextRuleTableTable(attachedDatabase, alias);
  }
}

class TextRuleTableData extends DataClass
    implements Insertable<TextRuleTableData> {
  final String id;
  final String name;

  /// 步骤 JSON（find/replace/caseSensitive 数组）
  final String stepsJson;

  /// 排序（越小越靠前，即应用顺序）
  final int sort;
  final int createdAt;
  const TextRuleTableData({
    required this.id,
    required this.name,
    required this.stepsJson,
    required this.sort,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['stepsJson'] = Variable<String>(stepsJson);
    map['sort'] = Variable<int>(sort);
    map['createdAt'] = Variable<int>(createdAt);
    return map;
  }

  TextRuleTableCompanion toCompanion(bool nullToAbsent) {
    return TextRuleTableCompanion(
      id: Value(id),
      name: Value(name),
      stepsJson: Value(stepsJson),
      sort: Value(sort),
      createdAt: Value(createdAt),
    );
  }

  factory TextRuleTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TextRuleTableData(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      stepsJson: serializer.fromJson<String>(json['stepsJson']),
      sort: serializer.fromJson<int>(json['sort']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'stepsJson': serializer.toJson<String>(stepsJson),
      'sort': serializer.toJson<int>(sort),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  TextRuleTableData copyWith({
    String? id,
    String? name,
    String? stepsJson,
    int? sort,
    int? createdAt,
  }) => TextRuleTableData(
    id: id ?? this.id,
    name: name ?? this.name,
    stepsJson: stepsJson ?? this.stepsJson,
    sort: sort ?? this.sort,
    createdAt: createdAt ?? this.createdAt,
  );
  TextRuleTableData copyWithCompanion(TextRuleTableCompanion data) {
    return TextRuleTableData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      stepsJson: data.stepsJson.present ? data.stepsJson.value : this.stepsJson,
      sort: data.sort.present ? data.sort.value : this.sort,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TextRuleTableData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('stepsJson: $stepsJson, ')
          ..write('sort: $sort, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, stepsJson, sort, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TextRuleTableData &&
          other.id == this.id &&
          other.name == this.name &&
          other.stepsJson == this.stepsJson &&
          other.sort == this.sort &&
          other.createdAt == this.createdAt);
}

class TextRuleTableCompanion extends UpdateCompanion<TextRuleTableData> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> stepsJson;
  final Value<int> sort;
  final Value<int> createdAt;
  final Value<int> rowid;
  const TextRuleTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.stepsJson = const Value.absent(),
    this.sort = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TextRuleTableCompanion.insert({
    required String id,
    required String name,
    this.stepsJson = const Value.absent(),
    this.sort = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<TextRuleTableData> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? stepsJson,
    Expression<int>? sort,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (stepsJson != null) 'stepsJson': stepsJson,
      if (sort != null) 'sort': sort,
      if (createdAt != null) 'createdAt': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TextRuleTableCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? stepsJson,
    Value<int>? sort,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return TextRuleTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      stepsJson: stepsJson ?? this.stepsJson,
      sort: sort ?? this.sort,
      createdAt: createdAt ?? this.createdAt,
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
    if (stepsJson.present) {
      map['stepsJson'] = Variable<String>(stepsJson.value);
    }
    if (sort.present) {
      map['sort'] = Variable<int>(sort.value);
    }
    if (createdAt.present) {
      map['createdAt'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TextRuleTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('stepsJson: $stepsJson, ')
          ..write('sort: $sort, ')
          ..write('createdAt: $createdAt, ')
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
  late final $PluginEventTableTable pluginEventTable = $PluginEventTableTable(
    this,
  );
  late final $TextRuleTableTable textRuleTable = $TextRuleTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    historyTable,
    progressTable,
    pluginEventTable,
    textRuleTable,
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
    extends Composer<_$_HistoryDb, $PluginEventTableTable> {
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
    extends Composer<_$_HistoryDb, $PluginEventTableTable> {
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
    extends Composer<_$_HistoryDb, $PluginEventTableTable> {
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
          _$_HistoryDb,
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
              _$_HistoryDb,
              $PluginEventTableTable,
              PluginEventTableData
            >,
          ),
          PluginEventTableData,
          PrefetchHooks Function()
        > {
  $$PluginEventTableTableTableManager(
    _$_HistoryDb db,
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
                    _$_HistoryDb,
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
      _$_HistoryDb,
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
          _$_HistoryDb,
          $PluginEventTableTable,
          PluginEventTableData
        >,
      ),
      PluginEventTableData,
      PrefetchHooks Function()
    >;
typedef $$TextRuleTableTableCreateCompanionBuilder =
    TextRuleTableCompanion Function({
      required String id,
      required String name,
      Value<String> stepsJson,
      Value<int> sort,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$TextRuleTableTableUpdateCompanionBuilder =
    TextRuleTableCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> stepsJson,
      Value<int> sort,
      Value<int> createdAt,
      Value<int> rowid,
    });

class $$TextRuleTableTableFilterComposer
    extends Composer<_$_HistoryDb, $TextRuleTableTable> {
  $$TextRuleTableTableFilterComposer({
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

  ColumnFilters<String> get stepsJson => $composableBuilder(
    column: $table.stepsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sort => $composableBuilder(
    column: $table.sort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TextRuleTableTableOrderingComposer
    extends Composer<_$_HistoryDb, $TextRuleTableTable> {
  $$TextRuleTableTableOrderingComposer({
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

  ColumnOrderings<String> get stepsJson => $composableBuilder(
    column: $table.stepsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sort => $composableBuilder(
    column: $table.sort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TextRuleTableTableAnnotationComposer
    extends Composer<_$_HistoryDb, $TextRuleTableTable> {
  $$TextRuleTableTableAnnotationComposer({
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

  GeneratedColumn<String> get stepsJson =>
      $composableBuilder(column: $table.stepsJson, builder: (column) => column);

  GeneratedColumn<int> get sort =>
      $composableBuilder(column: $table.sort, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$TextRuleTableTableTableManager
    extends
        RootTableManager<
          _$_HistoryDb,
          $TextRuleTableTable,
          TextRuleTableData,
          $$TextRuleTableTableFilterComposer,
          $$TextRuleTableTableOrderingComposer,
          $$TextRuleTableTableAnnotationComposer,
          $$TextRuleTableTableCreateCompanionBuilder,
          $$TextRuleTableTableUpdateCompanionBuilder,
          (
            TextRuleTableData,
            BaseReferences<
              _$_HistoryDb,
              $TextRuleTableTable,
              TextRuleTableData
            >,
          ),
          TextRuleTableData,
          PrefetchHooks Function()
        > {
  $$TextRuleTableTableTableManager(_$_HistoryDb db, $TextRuleTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TextRuleTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TextRuleTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TextRuleTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> stepsJson = const Value.absent(),
                Value<int> sort = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TextRuleTableCompanion(
                id: id,
                name: name,
                stepsJson: stepsJson,
                sort: sort,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String> stepsJson = const Value.absent(),
                Value<int> sort = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => TextRuleTableCompanion.insert(
                id: id,
                name: name,
                stepsJson: stepsJson,
                sort: sort,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TextRuleTableTable, TextRuleTableData>(table),
                  BaseReferences<
                    _$_HistoryDb,
                    $TextRuleTableTable,
                    TextRuleTableData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TextRuleTableTableProcessedTableManager =
    ProcessedTableManager<
      _$_HistoryDb,
      $TextRuleTableTable,
      TextRuleTableData,
      $$TextRuleTableTableFilterComposer,
      $$TextRuleTableTableOrderingComposer,
      $$TextRuleTableTableAnnotationComposer,
      $$TextRuleTableTableCreateCompanionBuilder,
      $$TextRuleTableTableUpdateCompanionBuilder,
      (
        TextRuleTableData,
        BaseReferences<_$_HistoryDb, $TextRuleTableTable, TextRuleTableData>,
      ),
      TextRuleTableData,
      PrefetchHooks Function()
    >;

class $_HistoryDbManager {
  final _$_HistoryDb _db;
  $_HistoryDbManager(this._db);
  $$HistoryTableTableTableManager get historyTable =>
      $$HistoryTableTableTableManager(_db, _db.historyTable);
  $$ProgressTableTableTableManager get progressTable =>
      $$ProgressTableTableTableManager(_db, _db.progressTable);
  $$PluginEventTableTableTableManager get pluginEventTable =>
      $$PluginEventTableTableTableManager(_db, _db.pluginEventTable);
  $$TextRuleTableTableTableManager get textRuleTable =>
      $$TextRuleTableTableTableManager(_db, _db.textRuleTable);
}

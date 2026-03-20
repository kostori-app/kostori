// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bangumi.dart';

// ignore_for_file: type=lint
class $BangumiDataTableTable extends BangumiDataTable
    with TableInfo<$BangumiDataTableTable, BangumiDataTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BangumiDataTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleTranslateMeta = const VerificationMeta(
    'titleTranslate',
  );
  @override
  late final GeneratedColumn<String> titleTranslate = GeneratedColumn<String>(
    'titleTranslate',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _langMeta = const VerificationMeta('lang');
  @override
  late final GeneratedColumn<String> lang = GeneratedColumn<String>(
    'lang',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _officialSiteMeta = const VerificationMeta(
    'officialSite',
  );
  @override
  late final GeneratedColumn<String> officialSite = GeneratedColumn<String>(
    'officialSite',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _beginMeta = const VerificationMeta('begin');
  @override
  late final GeneratedColumn<String> begin = GeneratedColumn<String>(
    'begin',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _broadcastMeta = const VerificationMeta(
    'broadcast',
  );
  @override
  late final GeneratedColumn<String> broadcast = GeneratedColumn<String>(
    'broadcast',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endMeta = const VerificationMeta('end');
  @override
  late final GeneratedColumn<String> end = GeneratedColumn<String>(
    'end',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _commentMeta = const VerificationMeta(
    'comment',
  );
  @override
  late final GeneratedColumn<String> comment = GeneratedColumn<String>(
    'comment',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sitesMeta = const VerificationMeta('sites');
  @override
  late final GeneratedColumn<String> sites = GeneratedColumn<String>(
    'sites',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    title,
    titleTranslate,
    type,
    lang,
    officialSite,
    begin,
    broadcast,
    end,
    comment,
    sites,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bangumi_data';
  @override
  VerificationContext validateIntegrity(
    Insertable<BangumiDataTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('titleTranslate')) {
      context.handle(
        _titleTranslateMeta,
        titleTranslate.isAcceptableOrUnknown(
          data['titleTranslate']!,
          _titleTranslateMeta,
        ),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('lang')) {
      context.handle(
        _langMeta,
        lang.isAcceptableOrUnknown(data['lang']!, _langMeta),
      );
    }
    if (data.containsKey('officialSite')) {
      context.handle(
        _officialSiteMeta,
        officialSite.isAcceptableOrUnknown(
          data['officialSite']!,
          _officialSiteMeta,
        ),
      );
    }
    if (data.containsKey('begin')) {
      context.handle(
        _beginMeta,
        begin.isAcceptableOrUnknown(data['begin']!, _beginMeta),
      );
    }
    if (data.containsKey('broadcast')) {
      context.handle(
        _broadcastMeta,
        broadcast.isAcceptableOrUnknown(data['broadcast']!, _broadcastMeta),
      );
    }
    if (data.containsKey('end')) {
      context.handle(
        _endMeta,
        end.isAcceptableOrUnknown(data['end']!, _endMeta),
      );
    }
    if (data.containsKey('comment')) {
      context.handle(
        _commentMeta,
        comment.isAcceptableOrUnknown(data['comment']!, _commentMeta),
      );
    }
    if (data.containsKey('sites')) {
      context.handle(
        _sitesMeta,
        sites.isAcceptableOrUnknown(data['sites']!, _sitesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {title};
  @override
  BangumiDataTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BangumiDataTableData(
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      titleTranslate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}titleTranslate'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      ),
      lang: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lang'],
      ),
      officialSite: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}officialSite'],
      ),
      begin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}begin'],
      ),
      broadcast: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}broadcast'],
      ),
      end: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end'],
      ),
      comment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comment'],
      ),
      sites: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sites'],
      ),
    );
  }

  @override
  $BangumiDataTableTable createAlias(String alias) {
    return $BangumiDataTableTable(attachedDatabase, alias);
  }
}

class BangumiDataTableData extends DataClass
    implements Insertable<BangumiDataTableData> {
  final String title;
  final String? titleTranslate;
  final String? type;
  final String? lang;
  final String? officialSite;
  final String? begin;
  final String? broadcast;
  final String? end;
  final String? comment;
  final String? sites;
  const BangumiDataTableData({
    required this.title,
    this.titleTranslate,
    this.type,
    this.lang,
    this.officialSite,
    this.begin,
    this.broadcast,
    this.end,
    this.comment,
    this.sites,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || titleTranslate != null) {
      map['titleTranslate'] = Variable<String>(titleTranslate);
    }
    if (!nullToAbsent || type != null) {
      map['type'] = Variable<String>(type);
    }
    if (!nullToAbsent || lang != null) {
      map['lang'] = Variable<String>(lang);
    }
    if (!nullToAbsent || officialSite != null) {
      map['officialSite'] = Variable<String>(officialSite);
    }
    if (!nullToAbsent || begin != null) {
      map['begin'] = Variable<String>(begin);
    }
    if (!nullToAbsent || broadcast != null) {
      map['broadcast'] = Variable<String>(broadcast);
    }
    if (!nullToAbsent || end != null) {
      map['end'] = Variable<String>(end);
    }
    if (!nullToAbsent || comment != null) {
      map['comment'] = Variable<String>(comment);
    }
    if (!nullToAbsent || sites != null) {
      map['sites'] = Variable<String>(sites);
    }
    return map;
  }

  BangumiDataTableCompanion toCompanion(bool nullToAbsent) {
    return BangumiDataTableCompanion(
      title: Value(title),
      titleTranslate: titleTranslate == null && nullToAbsent
          ? const Value.absent()
          : Value(titleTranslate),
      type: type == null && nullToAbsent ? const Value.absent() : Value(type),
      lang: lang == null && nullToAbsent ? const Value.absent() : Value(lang),
      officialSite: officialSite == null && nullToAbsent
          ? const Value.absent()
          : Value(officialSite),
      begin: begin == null && nullToAbsent
          ? const Value.absent()
          : Value(begin),
      broadcast: broadcast == null && nullToAbsent
          ? const Value.absent()
          : Value(broadcast),
      end: end == null && nullToAbsent ? const Value.absent() : Value(end),
      comment: comment == null && nullToAbsent
          ? const Value.absent()
          : Value(comment),
      sites: sites == null && nullToAbsent
          ? const Value.absent()
          : Value(sites),
    );
  }

  factory BangumiDataTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BangumiDataTableData(
      title: serializer.fromJson<String>(json['title']),
      titleTranslate: serializer.fromJson<String?>(json['titleTranslate']),
      type: serializer.fromJson<String?>(json['type']),
      lang: serializer.fromJson<String?>(json['lang']),
      officialSite: serializer.fromJson<String?>(json['officialSite']),
      begin: serializer.fromJson<String?>(json['begin']),
      broadcast: serializer.fromJson<String?>(json['broadcast']),
      end: serializer.fromJson<String?>(json['end']),
      comment: serializer.fromJson<String?>(json['comment']),
      sites: serializer.fromJson<String?>(json['sites']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'title': serializer.toJson<String>(title),
      'titleTranslate': serializer.toJson<String?>(titleTranslate),
      'type': serializer.toJson<String?>(type),
      'lang': serializer.toJson<String?>(lang),
      'officialSite': serializer.toJson<String?>(officialSite),
      'begin': serializer.toJson<String?>(begin),
      'broadcast': serializer.toJson<String?>(broadcast),
      'end': serializer.toJson<String?>(end),
      'comment': serializer.toJson<String?>(comment),
      'sites': serializer.toJson<String?>(sites),
    };
  }

  BangumiDataTableData copyWith({
    String? title,
    Value<String?> titleTranslate = const Value.absent(),
    Value<String?> type = const Value.absent(),
    Value<String?> lang = const Value.absent(),
    Value<String?> officialSite = const Value.absent(),
    Value<String?> begin = const Value.absent(),
    Value<String?> broadcast = const Value.absent(),
    Value<String?> end = const Value.absent(),
    Value<String?> comment = const Value.absent(),
    Value<String?> sites = const Value.absent(),
  }) => BangumiDataTableData(
    title: title ?? this.title,
    titleTranslate: titleTranslate.present
        ? titleTranslate.value
        : this.titleTranslate,
    type: type.present ? type.value : this.type,
    lang: lang.present ? lang.value : this.lang,
    officialSite: officialSite.present ? officialSite.value : this.officialSite,
    begin: begin.present ? begin.value : this.begin,
    broadcast: broadcast.present ? broadcast.value : this.broadcast,
    end: end.present ? end.value : this.end,
    comment: comment.present ? comment.value : this.comment,
    sites: sites.present ? sites.value : this.sites,
  );
  BangumiDataTableData copyWithCompanion(BangumiDataTableCompanion data) {
    return BangumiDataTableData(
      title: data.title.present ? data.title.value : this.title,
      titleTranslate: data.titleTranslate.present
          ? data.titleTranslate.value
          : this.titleTranslate,
      type: data.type.present ? data.type.value : this.type,
      lang: data.lang.present ? data.lang.value : this.lang,
      officialSite: data.officialSite.present
          ? data.officialSite.value
          : this.officialSite,
      begin: data.begin.present ? data.begin.value : this.begin,
      broadcast: data.broadcast.present ? data.broadcast.value : this.broadcast,
      end: data.end.present ? data.end.value : this.end,
      comment: data.comment.present ? data.comment.value : this.comment,
      sites: data.sites.present ? data.sites.value : this.sites,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BangumiDataTableData(')
          ..write('title: $title, ')
          ..write('titleTranslate: $titleTranslate, ')
          ..write('type: $type, ')
          ..write('lang: $lang, ')
          ..write('officialSite: $officialSite, ')
          ..write('begin: $begin, ')
          ..write('broadcast: $broadcast, ')
          ..write('end: $end, ')
          ..write('comment: $comment, ')
          ..write('sites: $sites')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    title,
    titleTranslate,
    type,
    lang,
    officialSite,
    begin,
    broadcast,
    end,
    comment,
    sites,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BangumiDataTableData &&
          other.title == this.title &&
          other.titleTranslate == this.titleTranslate &&
          other.type == this.type &&
          other.lang == this.lang &&
          other.officialSite == this.officialSite &&
          other.begin == this.begin &&
          other.broadcast == this.broadcast &&
          other.end == this.end &&
          other.comment == this.comment &&
          other.sites == this.sites);
}

class BangumiDataTableCompanion extends UpdateCompanion<BangumiDataTableData> {
  final Value<String> title;
  final Value<String?> titleTranslate;
  final Value<String?> type;
  final Value<String?> lang;
  final Value<String?> officialSite;
  final Value<String?> begin;
  final Value<String?> broadcast;
  final Value<String?> end;
  final Value<String?> comment;
  final Value<String?> sites;
  final Value<int> rowid;
  const BangumiDataTableCompanion({
    this.title = const Value.absent(),
    this.titleTranslate = const Value.absent(),
    this.type = const Value.absent(),
    this.lang = const Value.absent(),
    this.officialSite = const Value.absent(),
    this.begin = const Value.absent(),
    this.broadcast = const Value.absent(),
    this.end = const Value.absent(),
    this.comment = const Value.absent(),
    this.sites = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BangumiDataTableCompanion.insert({
    required String title,
    this.titleTranslate = const Value.absent(),
    this.type = const Value.absent(),
    this.lang = const Value.absent(),
    this.officialSite = const Value.absent(),
    this.begin = const Value.absent(),
    this.broadcast = const Value.absent(),
    this.end = const Value.absent(),
    this.comment = const Value.absent(),
    this.sites = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : title = Value(title);
  static Insertable<BangumiDataTableData> custom({
    Expression<String>? title,
    Expression<String>? titleTranslate,
    Expression<String>? type,
    Expression<String>? lang,
    Expression<String>? officialSite,
    Expression<String>? begin,
    Expression<String>? broadcast,
    Expression<String>? end,
    Expression<String>? comment,
    Expression<String>? sites,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (title != null) 'title': title,
      if (titleTranslate != null) 'titleTranslate': titleTranslate,
      if (type != null) 'type': type,
      if (lang != null) 'lang': lang,
      if (officialSite != null) 'officialSite': officialSite,
      if (begin != null) 'begin': begin,
      if (broadcast != null) 'broadcast': broadcast,
      if (end != null) 'end': end,
      if (comment != null) 'comment': comment,
      if (sites != null) 'sites': sites,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BangumiDataTableCompanion copyWith({
    Value<String>? title,
    Value<String?>? titleTranslate,
    Value<String?>? type,
    Value<String?>? lang,
    Value<String?>? officialSite,
    Value<String?>? begin,
    Value<String?>? broadcast,
    Value<String?>? end,
    Value<String?>? comment,
    Value<String?>? sites,
    Value<int>? rowid,
  }) {
    return BangumiDataTableCompanion(
      title: title ?? this.title,
      titleTranslate: titleTranslate ?? this.titleTranslate,
      type: type ?? this.type,
      lang: lang ?? this.lang,
      officialSite: officialSite ?? this.officialSite,
      begin: begin ?? this.begin,
      broadcast: broadcast ?? this.broadcast,
      end: end ?? this.end,
      comment: comment ?? this.comment,
      sites: sites ?? this.sites,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (titleTranslate.present) {
      map['titleTranslate'] = Variable<String>(titleTranslate.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (lang.present) {
      map['lang'] = Variable<String>(lang.value);
    }
    if (officialSite.present) {
      map['officialSite'] = Variable<String>(officialSite.value);
    }
    if (begin.present) {
      map['begin'] = Variable<String>(begin.value);
    }
    if (broadcast.present) {
      map['broadcast'] = Variable<String>(broadcast.value);
    }
    if (end.present) {
      map['end'] = Variable<String>(end.value);
    }
    if (comment.present) {
      map['comment'] = Variable<String>(comment.value);
    }
    if (sites.present) {
      map['sites'] = Variable<String>(sites.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BangumiDataTableCompanion(')
          ..write('title: $title, ')
          ..write('titleTranslate: $titleTranslate, ')
          ..write('type: $type, ')
          ..write('lang: $lang, ')
          ..write('officialSite: $officialSite, ')
          ..write('begin: $begin, ')
          ..write('broadcast: $broadcast, ')
          ..write('end: $end, ')
          ..write('comment: $comment, ')
          ..write('sites: $sites, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BangumiCalendarTableTable extends BangumiCalendarTable
    with TableInfo<$BangumiCalendarTableTable, BangumiCalendarTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BangumiCalendarTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<int> type = GeneratedColumn<int>(
    'type',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameCnMeta = const VerificationMeta('nameCn');
  @override
  late final GeneratedColumn<String> nameCn = GeneratedColumn<String>(
    'nameCn',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _airDateMeta = const VerificationMeta(
    'airDate',
  );
  @override
  late final GeneratedColumn<String> airDate = GeneratedColumn<String>(
    'airDate',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _airWeekdayMeta = const VerificationMeta(
    'airWeekday',
  );
  @override
  late final GeneratedColumn<int> airWeekday = GeneratedColumn<int>(
    'airWeekday',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<int> total = GeneratedColumn<int>(
    'total',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _countMeta = const VerificationMeta('count');
  @override
  late final GeneratedColumn<String> count = GeneratedColumn<String>(
    'count',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<double> score = GeneratedColumn<double>(
    'score',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rankMeta = const VerificationMeta('rank');
  @override
  late final GeneratedColumn<int> rank = GeneratedColumn<int>(
    'rank',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imagesMeta = const VerificationMeta('images');
  @override
  late final GeneratedColumn<String> images = GeneratedColumn<String>(
    'images',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _collectionMeta = const VerificationMeta(
    'collection',
  );
  @override
  late final GeneratedColumn<String> collection = GeneratedColumn<String>(
    'collection',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    name,
    nameCn,
    summary,
    airDate,
    airWeekday,
    total,
    count,
    score,
    rank,
    images,
    collection,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bangumi_calendar';
  @override
  VerificationContext validateIntegrity(
    Insertable<BangumiCalendarTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('nameCn')) {
      context.handle(
        _nameCnMeta,
        nameCn.isAcceptableOrUnknown(data['nameCn']!, _nameCnMeta),
      );
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    }
    if (data.containsKey('airDate')) {
      context.handle(
        _airDateMeta,
        airDate.isAcceptableOrUnknown(data['airDate']!, _airDateMeta),
      );
    }
    if (data.containsKey('airWeekday')) {
      context.handle(
        _airWeekdayMeta,
        airWeekday.isAcceptableOrUnknown(data['airWeekday']!, _airWeekdayMeta),
      );
    }
    if (data.containsKey('total')) {
      context.handle(
        _totalMeta,
        total.isAcceptableOrUnknown(data['total']!, _totalMeta),
      );
    }
    if (data.containsKey('count')) {
      context.handle(
        _countMeta,
        count.isAcceptableOrUnknown(data['count']!, _countMeta),
      );
    }
    if (data.containsKey('score')) {
      context.handle(
        _scoreMeta,
        score.isAcceptableOrUnknown(data['score']!, _scoreMeta),
      );
    }
    if (data.containsKey('rank')) {
      context.handle(
        _rankMeta,
        rank.isAcceptableOrUnknown(data['rank']!, _rankMeta),
      );
    }
    if (data.containsKey('images')) {
      context.handle(
        _imagesMeta,
        images.isAcceptableOrUnknown(data['images']!, _imagesMeta),
      );
    }
    if (data.containsKey('collection')) {
      context.handle(
        _collectionMeta,
        collection.isAcceptableOrUnknown(data['collection']!, _collectionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BangumiCalendarTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BangumiCalendarTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      nameCn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nameCn'],
      ),
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      ),
      airDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}airDate'],
      ),
      airWeekday: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}airWeekday'],
      ),
      total: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total'],
      ),
      count: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}count'],
      ),
      score: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}score'],
      ),
      rank: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rank'],
      ),
      images: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}images'],
      ),
      collection: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection'],
      ),
    );
  }

  @override
  $BangumiCalendarTableTable createAlias(String alias) {
    return $BangumiCalendarTableTable(attachedDatabase, alias);
  }
}

class BangumiCalendarTableData extends DataClass
    implements Insertable<BangumiCalendarTableData> {
  final int id;
  final int? type;
  final String? name;
  final String? nameCn;
  final String? summary;
  final String? airDate;
  final int? airWeekday;
  final int? total;
  final String? count;
  final double? score;
  final int? rank;
  final String? images;
  final String? collection;
  const BangumiCalendarTableData({
    required this.id,
    this.type,
    this.name,
    this.nameCn,
    this.summary,
    this.airDate,
    this.airWeekday,
    this.total,
    this.count,
    this.score,
    this.rank,
    this.images,
    this.collection,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || type != null) {
      map['type'] = Variable<int>(type);
    }
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || nameCn != null) {
      map['nameCn'] = Variable<String>(nameCn);
    }
    if (!nullToAbsent || summary != null) {
      map['summary'] = Variable<String>(summary);
    }
    if (!nullToAbsent || airDate != null) {
      map['airDate'] = Variable<String>(airDate);
    }
    if (!nullToAbsent || airWeekday != null) {
      map['airWeekday'] = Variable<int>(airWeekday);
    }
    if (!nullToAbsent || total != null) {
      map['total'] = Variable<int>(total);
    }
    if (!nullToAbsent || count != null) {
      map['count'] = Variable<String>(count);
    }
    if (!nullToAbsent || score != null) {
      map['score'] = Variable<double>(score);
    }
    if (!nullToAbsent || rank != null) {
      map['rank'] = Variable<int>(rank);
    }
    if (!nullToAbsent || images != null) {
      map['images'] = Variable<String>(images);
    }
    if (!nullToAbsent || collection != null) {
      map['collection'] = Variable<String>(collection);
    }
    return map;
  }

  BangumiCalendarTableCompanion toCompanion(bool nullToAbsent) {
    return BangumiCalendarTableCompanion(
      id: Value(id),
      type: type == null && nullToAbsent ? const Value.absent() : Value(type),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      nameCn: nameCn == null && nullToAbsent
          ? const Value.absent()
          : Value(nameCn),
      summary: summary == null && nullToAbsent
          ? const Value.absent()
          : Value(summary),
      airDate: airDate == null && nullToAbsent
          ? const Value.absent()
          : Value(airDate),
      airWeekday: airWeekday == null && nullToAbsent
          ? const Value.absent()
          : Value(airWeekday),
      total: total == null && nullToAbsent
          ? const Value.absent()
          : Value(total),
      count: count == null && nullToAbsent
          ? const Value.absent()
          : Value(count),
      score: score == null && nullToAbsent
          ? const Value.absent()
          : Value(score),
      rank: rank == null && nullToAbsent ? const Value.absent() : Value(rank),
      images: images == null && nullToAbsent
          ? const Value.absent()
          : Value(images),
      collection: collection == null && nullToAbsent
          ? const Value.absent()
          : Value(collection),
    );
  }

  factory BangumiCalendarTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BangumiCalendarTableData(
      id: serializer.fromJson<int>(json['id']),
      type: serializer.fromJson<int?>(json['type']),
      name: serializer.fromJson<String?>(json['name']),
      nameCn: serializer.fromJson<String?>(json['nameCn']),
      summary: serializer.fromJson<String?>(json['summary']),
      airDate: serializer.fromJson<String?>(json['airDate']),
      airWeekday: serializer.fromJson<int?>(json['airWeekday']),
      total: serializer.fromJson<int?>(json['total']),
      count: serializer.fromJson<String?>(json['count']),
      score: serializer.fromJson<double?>(json['score']),
      rank: serializer.fromJson<int?>(json['rank']),
      images: serializer.fromJson<String?>(json['images']),
      collection: serializer.fromJson<String?>(json['collection']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'type': serializer.toJson<int?>(type),
      'name': serializer.toJson<String?>(name),
      'nameCn': serializer.toJson<String?>(nameCn),
      'summary': serializer.toJson<String?>(summary),
      'airDate': serializer.toJson<String?>(airDate),
      'airWeekday': serializer.toJson<int?>(airWeekday),
      'total': serializer.toJson<int?>(total),
      'count': serializer.toJson<String?>(count),
      'score': serializer.toJson<double?>(score),
      'rank': serializer.toJson<int?>(rank),
      'images': serializer.toJson<String?>(images),
      'collection': serializer.toJson<String?>(collection),
    };
  }

  BangumiCalendarTableData copyWith({
    int? id,
    Value<int?> type = const Value.absent(),
    Value<String?> name = const Value.absent(),
    Value<String?> nameCn = const Value.absent(),
    Value<String?> summary = const Value.absent(),
    Value<String?> airDate = const Value.absent(),
    Value<int?> airWeekday = const Value.absent(),
    Value<int?> total = const Value.absent(),
    Value<String?> count = const Value.absent(),
    Value<double?> score = const Value.absent(),
    Value<int?> rank = const Value.absent(),
    Value<String?> images = const Value.absent(),
    Value<String?> collection = const Value.absent(),
  }) => BangumiCalendarTableData(
    id: id ?? this.id,
    type: type.present ? type.value : this.type,
    name: name.present ? name.value : this.name,
    nameCn: nameCn.present ? nameCn.value : this.nameCn,
    summary: summary.present ? summary.value : this.summary,
    airDate: airDate.present ? airDate.value : this.airDate,
    airWeekday: airWeekday.present ? airWeekday.value : this.airWeekday,
    total: total.present ? total.value : this.total,
    count: count.present ? count.value : this.count,
    score: score.present ? score.value : this.score,
    rank: rank.present ? rank.value : this.rank,
    images: images.present ? images.value : this.images,
    collection: collection.present ? collection.value : this.collection,
  );
  BangumiCalendarTableData copyWithCompanion(
    BangumiCalendarTableCompanion data,
  ) {
    return BangumiCalendarTableData(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      name: data.name.present ? data.name.value : this.name,
      nameCn: data.nameCn.present ? data.nameCn.value : this.nameCn,
      summary: data.summary.present ? data.summary.value : this.summary,
      airDate: data.airDate.present ? data.airDate.value : this.airDate,
      airWeekday: data.airWeekday.present
          ? data.airWeekday.value
          : this.airWeekday,
      total: data.total.present ? data.total.value : this.total,
      count: data.count.present ? data.count.value : this.count,
      score: data.score.present ? data.score.value : this.score,
      rank: data.rank.present ? data.rank.value : this.rank,
      images: data.images.present ? data.images.value : this.images,
      collection: data.collection.present
          ? data.collection.value
          : this.collection,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BangumiCalendarTableData(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('name: $name, ')
          ..write('nameCn: $nameCn, ')
          ..write('summary: $summary, ')
          ..write('airDate: $airDate, ')
          ..write('airWeekday: $airWeekday, ')
          ..write('total: $total, ')
          ..write('count: $count, ')
          ..write('score: $score, ')
          ..write('rank: $rank, ')
          ..write('images: $images, ')
          ..write('collection: $collection')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    name,
    nameCn,
    summary,
    airDate,
    airWeekday,
    total,
    count,
    score,
    rank,
    images,
    collection,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BangumiCalendarTableData &&
          other.id == this.id &&
          other.type == this.type &&
          other.name == this.name &&
          other.nameCn == this.nameCn &&
          other.summary == this.summary &&
          other.airDate == this.airDate &&
          other.airWeekday == this.airWeekday &&
          other.total == this.total &&
          other.count == this.count &&
          other.score == this.score &&
          other.rank == this.rank &&
          other.images == this.images &&
          other.collection == this.collection);
}

class BangumiCalendarTableCompanion
    extends UpdateCompanion<BangumiCalendarTableData> {
  final Value<int> id;
  final Value<int?> type;
  final Value<String?> name;
  final Value<String?> nameCn;
  final Value<String?> summary;
  final Value<String?> airDate;
  final Value<int?> airWeekday;
  final Value<int?> total;
  final Value<String?> count;
  final Value<double?> score;
  final Value<int?> rank;
  final Value<String?> images;
  final Value<String?> collection;
  const BangumiCalendarTableCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.name = const Value.absent(),
    this.nameCn = const Value.absent(),
    this.summary = const Value.absent(),
    this.airDate = const Value.absent(),
    this.airWeekday = const Value.absent(),
    this.total = const Value.absent(),
    this.count = const Value.absent(),
    this.score = const Value.absent(),
    this.rank = const Value.absent(),
    this.images = const Value.absent(),
    this.collection = const Value.absent(),
  });
  BangumiCalendarTableCompanion.insert({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.name = const Value.absent(),
    this.nameCn = const Value.absent(),
    this.summary = const Value.absent(),
    this.airDate = const Value.absent(),
    this.airWeekday = const Value.absent(),
    this.total = const Value.absent(),
    this.count = const Value.absent(),
    this.score = const Value.absent(),
    this.rank = const Value.absent(),
    this.images = const Value.absent(),
    this.collection = const Value.absent(),
  });
  static Insertable<BangumiCalendarTableData> custom({
    Expression<int>? id,
    Expression<int>? type,
    Expression<String>? name,
    Expression<String>? nameCn,
    Expression<String>? summary,
    Expression<String>? airDate,
    Expression<int>? airWeekday,
    Expression<int>? total,
    Expression<String>? count,
    Expression<double>? score,
    Expression<int>? rank,
    Expression<String>? images,
    Expression<String>? collection,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (name != null) 'name': name,
      if (nameCn != null) 'nameCn': nameCn,
      if (summary != null) 'summary': summary,
      if (airDate != null) 'airDate': airDate,
      if (airWeekday != null) 'airWeekday': airWeekday,
      if (total != null) 'total': total,
      if (count != null) 'count': count,
      if (score != null) 'score': score,
      if (rank != null) 'rank': rank,
      if (images != null) 'images': images,
      if (collection != null) 'collection': collection,
    });
  }

  BangumiCalendarTableCompanion copyWith({
    Value<int>? id,
    Value<int?>? type,
    Value<String?>? name,
    Value<String?>? nameCn,
    Value<String?>? summary,
    Value<String?>? airDate,
    Value<int?>? airWeekday,
    Value<int?>? total,
    Value<String?>? count,
    Value<double?>? score,
    Value<int?>? rank,
    Value<String?>? images,
    Value<String?>? collection,
  }) {
    return BangumiCalendarTableCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      nameCn: nameCn ?? this.nameCn,
      summary: summary ?? this.summary,
      airDate: airDate ?? this.airDate,
      airWeekday: airWeekday ?? this.airWeekday,
      total: total ?? this.total,
      count: count ?? this.count,
      score: score ?? this.score,
      rank: rank ?? this.rank,
      images: images ?? this.images,
      collection: collection ?? this.collection,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(type.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (nameCn.present) {
      map['nameCn'] = Variable<String>(nameCn.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (airDate.present) {
      map['airDate'] = Variable<String>(airDate.value);
    }
    if (airWeekday.present) {
      map['airWeekday'] = Variable<int>(airWeekday.value);
    }
    if (total.present) {
      map['total'] = Variable<int>(total.value);
    }
    if (count.present) {
      map['count'] = Variable<String>(count.value);
    }
    if (score.present) {
      map['score'] = Variable<double>(score.value);
    }
    if (rank.present) {
      map['rank'] = Variable<int>(rank.value);
    }
    if (images.present) {
      map['images'] = Variable<String>(images.value);
    }
    if (collection.present) {
      map['collection'] = Variable<String>(collection.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BangumiCalendarTableCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('name: $name, ')
          ..write('nameCn: $nameCn, ')
          ..write('summary: $summary, ')
          ..write('airDate: $airDate, ')
          ..write('airWeekday: $airWeekday, ')
          ..write('total: $total, ')
          ..write('count: $count, ')
          ..write('score: $score, ')
          ..write('rank: $rank, ')
          ..write('images: $images, ')
          ..write('collection: $collection')
          ..write(')'))
        .toString();
  }
}

class $BangumiBindingTableTable extends BangumiBindingTable
    with TableInfo<$BangumiBindingTableTable, BangumiBindingTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BangumiBindingTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<int> type = GeneratedColumn<int>(
    'type',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameCnMeta = const VerificationMeta('nameCn');
  @override
  late final GeneratedColumn<String> nameCn = GeneratedColumn<String>(
    'nameCn',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _airDateMeta = const VerificationMeta(
    'airDate',
  );
  @override
  late final GeneratedColumn<String> airDate = GeneratedColumn<String>(
    'airDate',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _airWeekdayMeta = const VerificationMeta(
    'airWeekday',
  );
  @override
  late final GeneratedColumn<int> airWeekday = GeneratedColumn<int>(
    'airWeekday',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<int> total = GeneratedColumn<int>(
    'total',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalEpisodesMeta = const VerificationMeta(
    'totalEpisodes',
  );
  @override
  late final GeneratedColumn<int> totalEpisodes = GeneratedColumn<int>(
    'totalEpisodes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _countMeta = const VerificationMeta('count');
  @override
  late final GeneratedColumn<String> count = GeneratedColumn<String>(
    'count',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<double> score = GeneratedColumn<double>(
    'score',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rankMeta = const VerificationMeta('rank');
  @override
  late final GeneratedColumn<int> rank = GeneratedColumn<int>(
    'rank',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imagesMeta = const VerificationMeta('images');
  @override
  late final GeneratedColumn<String> images = GeneratedColumn<String>(
    'images',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _collectionMeta = const VerificationMeta(
    'collection',
  );
  @override
  late final GeneratedColumn<String> collection = GeneratedColumn<String>(
    'collection',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _aliasMeta = const VerificationMeta('alias');
  @override
  late final GeneratedColumn<String> alias = GeneratedColumn<String>(
    'alias',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    name,
    nameCn,
    summary,
    airDate,
    airWeekday,
    total,
    totalEpisodes,
    count,
    score,
    rank,
    images,
    collection,
    tags,
    alias,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bangumi_binding';
  @override
  VerificationContext validateIntegrity(
    Insertable<BangumiBindingTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('nameCn')) {
      context.handle(
        _nameCnMeta,
        nameCn.isAcceptableOrUnknown(data['nameCn']!, _nameCnMeta),
      );
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    }
    if (data.containsKey('airDate')) {
      context.handle(
        _airDateMeta,
        airDate.isAcceptableOrUnknown(data['airDate']!, _airDateMeta),
      );
    }
    if (data.containsKey('airWeekday')) {
      context.handle(
        _airWeekdayMeta,
        airWeekday.isAcceptableOrUnknown(data['airWeekday']!, _airWeekdayMeta),
      );
    }
    if (data.containsKey('total')) {
      context.handle(
        _totalMeta,
        total.isAcceptableOrUnknown(data['total']!, _totalMeta),
      );
    }
    if (data.containsKey('totalEpisodes')) {
      context.handle(
        _totalEpisodesMeta,
        totalEpisodes.isAcceptableOrUnknown(
          data['totalEpisodes']!,
          _totalEpisodesMeta,
        ),
      );
    }
    if (data.containsKey('count')) {
      context.handle(
        _countMeta,
        count.isAcceptableOrUnknown(data['count']!, _countMeta),
      );
    }
    if (data.containsKey('score')) {
      context.handle(
        _scoreMeta,
        score.isAcceptableOrUnknown(data['score']!, _scoreMeta),
      );
    }
    if (data.containsKey('rank')) {
      context.handle(
        _rankMeta,
        rank.isAcceptableOrUnknown(data['rank']!, _rankMeta),
      );
    }
    if (data.containsKey('images')) {
      context.handle(
        _imagesMeta,
        images.isAcceptableOrUnknown(data['images']!, _imagesMeta),
      );
    }
    if (data.containsKey('collection')) {
      context.handle(
        _collectionMeta,
        collection.isAcceptableOrUnknown(data['collection']!, _collectionMeta),
      );
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('alias')) {
      context.handle(
        _aliasMeta,
        alias.isAcceptableOrUnknown(data['alias']!, _aliasMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BangumiBindingTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BangumiBindingTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      nameCn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nameCn'],
      ),
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      ),
      airDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}airDate'],
      ),
      airWeekday: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}airWeekday'],
      ),
      total: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total'],
      ),
      totalEpisodes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}totalEpisodes'],
      ),
      count: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}count'],
      ),
      score: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}score'],
      ),
      rank: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rank'],
      ),
      images: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}images'],
      ),
      collection: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection'],
      ),
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      ),
      alias: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alias'],
      ),
    );
  }

  @override
  $BangumiBindingTableTable createAlias(String alias) {
    return $BangumiBindingTableTable(attachedDatabase, alias);
  }
}

class BangumiBindingTableData extends DataClass
    implements Insertable<BangumiBindingTableData> {
  final int id;
  final int? type;
  final String? name;
  final String? nameCn;
  final String? summary;
  final String? airDate;
  final int? airWeekday;
  final int? total;
  final int? totalEpisodes;
  final String? count;
  final double? score;
  final int? rank;
  final String? images;
  final String? collection;
  final String? tags;
  final String? alias;
  const BangumiBindingTableData({
    required this.id,
    this.type,
    this.name,
    this.nameCn,
    this.summary,
    this.airDate,
    this.airWeekday,
    this.total,
    this.totalEpisodes,
    this.count,
    this.score,
    this.rank,
    this.images,
    this.collection,
    this.tags,
    this.alias,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || type != null) {
      map['type'] = Variable<int>(type);
    }
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || nameCn != null) {
      map['nameCn'] = Variable<String>(nameCn);
    }
    if (!nullToAbsent || summary != null) {
      map['summary'] = Variable<String>(summary);
    }
    if (!nullToAbsent || airDate != null) {
      map['airDate'] = Variable<String>(airDate);
    }
    if (!nullToAbsent || airWeekday != null) {
      map['airWeekday'] = Variable<int>(airWeekday);
    }
    if (!nullToAbsent || total != null) {
      map['total'] = Variable<int>(total);
    }
    if (!nullToAbsent || totalEpisodes != null) {
      map['totalEpisodes'] = Variable<int>(totalEpisodes);
    }
    if (!nullToAbsent || count != null) {
      map['count'] = Variable<String>(count);
    }
    if (!nullToAbsent || score != null) {
      map['score'] = Variable<double>(score);
    }
    if (!nullToAbsent || rank != null) {
      map['rank'] = Variable<int>(rank);
    }
    if (!nullToAbsent || images != null) {
      map['images'] = Variable<String>(images);
    }
    if (!nullToAbsent || collection != null) {
      map['collection'] = Variable<String>(collection);
    }
    if (!nullToAbsent || tags != null) {
      map['tags'] = Variable<String>(tags);
    }
    if (!nullToAbsent || alias != null) {
      map['alias'] = Variable<String>(alias);
    }
    return map;
  }

  BangumiBindingTableCompanion toCompanion(bool nullToAbsent) {
    return BangumiBindingTableCompanion(
      id: Value(id),
      type: type == null && nullToAbsent ? const Value.absent() : Value(type),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      nameCn: nameCn == null && nullToAbsent
          ? const Value.absent()
          : Value(nameCn),
      summary: summary == null && nullToAbsent
          ? const Value.absent()
          : Value(summary),
      airDate: airDate == null && nullToAbsent
          ? const Value.absent()
          : Value(airDate),
      airWeekday: airWeekday == null && nullToAbsent
          ? const Value.absent()
          : Value(airWeekday),
      total: total == null && nullToAbsent
          ? const Value.absent()
          : Value(total),
      totalEpisodes: totalEpisodes == null && nullToAbsent
          ? const Value.absent()
          : Value(totalEpisodes),
      count: count == null && nullToAbsent
          ? const Value.absent()
          : Value(count),
      score: score == null && nullToAbsent
          ? const Value.absent()
          : Value(score),
      rank: rank == null && nullToAbsent ? const Value.absent() : Value(rank),
      images: images == null && nullToAbsent
          ? const Value.absent()
          : Value(images),
      collection: collection == null && nullToAbsent
          ? const Value.absent()
          : Value(collection),
      tags: tags == null && nullToAbsent ? const Value.absent() : Value(tags),
      alias: alias == null && nullToAbsent
          ? const Value.absent()
          : Value(alias),
    );
  }

  factory BangumiBindingTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BangumiBindingTableData(
      id: serializer.fromJson<int>(json['id']),
      type: serializer.fromJson<int?>(json['type']),
      name: serializer.fromJson<String?>(json['name']),
      nameCn: serializer.fromJson<String?>(json['nameCn']),
      summary: serializer.fromJson<String?>(json['summary']),
      airDate: serializer.fromJson<String?>(json['airDate']),
      airWeekday: serializer.fromJson<int?>(json['airWeekday']),
      total: serializer.fromJson<int?>(json['total']),
      totalEpisodes: serializer.fromJson<int?>(json['totalEpisodes']),
      count: serializer.fromJson<String?>(json['count']),
      score: serializer.fromJson<double?>(json['score']),
      rank: serializer.fromJson<int?>(json['rank']),
      images: serializer.fromJson<String?>(json['images']),
      collection: serializer.fromJson<String?>(json['collection']),
      tags: serializer.fromJson<String?>(json['tags']),
      alias: serializer.fromJson<String?>(json['alias']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'type': serializer.toJson<int?>(type),
      'name': serializer.toJson<String?>(name),
      'nameCn': serializer.toJson<String?>(nameCn),
      'summary': serializer.toJson<String?>(summary),
      'airDate': serializer.toJson<String?>(airDate),
      'airWeekday': serializer.toJson<int?>(airWeekday),
      'total': serializer.toJson<int?>(total),
      'totalEpisodes': serializer.toJson<int?>(totalEpisodes),
      'count': serializer.toJson<String?>(count),
      'score': serializer.toJson<double?>(score),
      'rank': serializer.toJson<int?>(rank),
      'images': serializer.toJson<String?>(images),
      'collection': serializer.toJson<String?>(collection),
      'tags': serializer.toJson<String?>(tags),
      'alias': serializer.toJson<String?>(alias),
    };
  }

  BangumiBindingTableData copyWith({
    int? id,
    Value<int?> type = const Value.absent(),
    Value<String?> name = const Value.absent(),
    Value<String?> nameCn = const Value.absent(),
    Value<String?> summary = const Value.absent(),
    Value<String?> airDate = const Value.absent(),
    Value<int?> airWeekday = const Value.absent(),
    Value<int?> total = const Value.absent(),
    Value<int?> totalEpisodes = const Value.absent(),
    Value<String?> count = const Value.absent(),
    Value<double?> score = const Value.absent(),
    Value<int?> rank = const Value.absent(),
    Value<String?> images = const Value.absent(),
    Value<String?> collection = const Value.absent(),
    Value<String?> tags = const Value.absent(),
    Value<String?> alias = const Value.absent(),
  }) => BangumiBindingTableData(
    id: id ?? this.id,
    type: type.present ? type.value : this.type,
    name: name.present ? name.value : this.name,
    nameCn: nameCn.present ? nameCn.value : this.nameCn,
    summary: summary.present ? summary.value : this.summary,
    airDate: airDate.present ? airDate.value : this.airDate,
    airWeekday: airWeekday.present ? airWeekday.value : this.airWeekday,
    total: total.present ? total.value : this.total,
    totalEpisodes: totalEpisodes.present
        ? totalEpisodes.value
        : this.totalEpisodes,
    count: count.present ? count.value : this.count,
    score: score.present ? score.value : this.score,
    rank: rank.present ? rank.value : this.rank,
    images: images.present ? images.value : this.images,
    collection: collection.present ? collection.value : this.collection,
    tags: tags.present ? tags.value : this.tags,
    alias: alias.present ? alias.value : this.alias,
  );
  BangumiBindingTableData copyWithCompanion(BangumiBindingTableCompanion data) {
    return BangumiBindingTableData(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      name: data.name.present ? data.name.value : this.name,
      nameCn: data.nameCn.present ? data.nameCn.value : this.nameCn,
      summary: data.summary.present ? data.summary.value : this.summary,
      airDate: data.airDate.present ? data.airDate.value : this.airDate,
      airWeekday: data.airWeekday.present
          ? data.airWeekday.value
          : this.airWeekday,
      total: data.total.present ? data.total.value : this.total,
      totalEpisodes: data.totalEpisodes.present
          ? data.totalEpisodes.value
          : this.totalEpisodes,
      count: data.count.present ? data.count.value : this.count,
      score: data.score.present ? data.score.value : this.score,
      rank: data.rank.present ? data.rank.value : this.rank,
      images: data.images.present ? data.images.value : this.images,
      collection: data.collection.present
          ? data.collection.value
          : this.collection,
      tags: data.tags.present ? data.tags.value : this.tags,
      alias: data.alias.present ? data.alias.value : this.alias,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BangumiBindingTableData(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('name: $name, ')
          ..write('nameCn: $nameCn, ')
          ..write('summary: $summary, ')
          ..write('airDate: $airDate, ')
          ..write('airWeekday: $airWeekday, ')
          ..write('total: $total, ')
          ..write('totalEpisodes: $totalEpisodes, ')
          ..write('count: $count, ')
          ..write('score: $score, ')
          ..write('rank: $rank, ')
          ..write('images: $images, ')
          ..write('collection: $collection, ')
          ..write('tags: $tags, ')
          ..write('alias: $alias')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    name,
    nameCn,
    summary,
    airDate,
    airWeekday,
    total,
    totalEpisodes,
    count,
    score,
    rank,
    images,
    collection,
    tags,
    alias,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BangumiBindingTableData &&
          other.id == this.id &&
          other.type == this.type &&
          other.name == this.name &&
          other.nameCn == this.nameCn &&
          other.summary == this.summary &&
          other.airDate == this.airDate &&
          other.airWeekday == this.airWeekday &&
          other.total == this.total &&
          other.totalEpisodes == this.totalEpisodes &&
          other.count == this.count &&
          other.score == this.score &&
          other.rank == this.rank &&
          other.images == this.images &&
          other.collection == this.collection &&
          other.tags == this.tags &&
          other.alias == this.alias);
}

class BangumiBindingTableCompanion
    extends UpdateCompanion<BangumiBindingTableData> {
  final Value<int> id;
  final Value<int?> type;
  final Value<String?> name;
  final Value<String?> nameCn;
  final Value<String?> summary;
  final Value<String?> airDate;
  final Value<int?> airWeekday;
  final Value<int?> total;
  final Value<int?> totalEpisodes;
  final Value<String?> count;
  final Value<double?> score;
  final Value<int?> rank;
  final Value<String?> images;
  final Value<String?> collection;
  final Value<String?> tags;
  final Value<String?> alias;
  const BangumiBindingTableCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.name = const Value.absent(),
    this.nameCn = const Value.absent(),
    this.summary = const Value.absent(),
    this.airDate = const Value.absent(),
    this.airWeekday = const Value.absent(),
    this.total = const Value.absent(),
    this.totalEpisodes = const Value.absent(),
    this.count = const Value.absent(),
    this.score = const Value.absent(),
    this.rank = const Value.absent(),
    this.images = const Value.absent(),
    this.collection = const Value.absent(),
    this.tags = const Value.absent(),
    this.alias = const Value.absent(),
  });
  BangumiBindingTableCompanion.insert({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.name = const Value.absent(),
    this.nameCn = const Value.absent(),
    this.summary = const Value.absent(),
    this.airDate = const Value.absent(),
    this.airWeekday = const Value.absent(),
    this.total = const Value.absent(),
    this.totalEpisodes = const Value.absent(),
    this.count = const Value.absent(),
    this.score = const Value.absent(),
    this.rank = const Value.absent(),
    this.images = const Value.absent(),
    this.collection = const Value.absent(),
    this.tags = const Value.absent(),
    this.alias = const Value.absent(),
  });
  static Insertable<BangumiBindingTableData> custom({
    Expression<int>? id,
    Expression<int>? type,
    Expression<String>? name,
    Expression<String>? nameCn,
    Expression<String>? summary,
    Expression<String>? airDate,
    Expression<int>? airWeekday,
    Expression<int>? total,
    Expression<int>? totalEpisodes,
    Expression<String>? count,
    Expression<double>? score,
    Expression<int>? rank,
    Expression<String>? images,
    Expression<String>? collection,
    Expression<String>? tags,
    Expression<String>? alias,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (name != null) 'name': name,
      if (nameCn != null) 'nameCn': nameCn,
      if (summary != null) 'summary': summary,
      if (airDate != null) 'airDate': airDate,
      if (airWeekday != null) 'airWeekday': airWeekday,
      if (total != null) 'total': total,
      if (totalEpisodes != null) 'totalEpisodes': totalEpisodes,
      if (count != null) 'count': count,
      if (score != null) 'score': score,
      if (rank != null) 'rank': rank,
      if (images != null) 'images': images,
      if (collection != null) 'collection': collection,
      if (tags != null) 'tags': tags,
      if (alias != null) 'alias': alias,
    });
  }

  BangumiBindingTableCompanion copyWith({
    Value<int>? id,
    Value<int?>? type,
    Value<String?>? name,
    Value<String?>? nameCn,
    Value<String?>? summary,
    Value<String?>? airDate,
    Value<int?>? airWeekday,
    Value<int?>? total,
    Value<int?>? totalEpisodes,
    Value<String?>? count,
    Value<double?>? score,
    Value<int?>? rank,
    Value<String?>? images,
    Value<String?>? collection,
    Value<String?>? tags,
    Value<String?>? alias,
  }) {
    return BangumiBindingTableCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      nameCn: nameCn ?? this.nameCn,
      summary: summary ?? this.summary,
      airDate: airDate ?? this.airDate,
      airWeekday: airWeekday ?? this.airWeekday,
      total: total ?? this.total,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
      count: count ?? this.count,
      score: score ?? this.score,
      rank: rank ?? this.rank,
      images: images ?? this.images,
      collection: collection ?? this.collection,
      tags: tags ?? this.tags,
      alias: alias ?? this.alias,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(type.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (nameCn.present) {
      map['nameCn'] = Variable<String>(nameCn.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (airDate.present) {
      map['airDate'] = Variable<String>(airDate.value);
    }
    if (airWeekday.present) {
      map['airWeekday'] = Variable<int>(airWeekday.value);
    }
    if (total.present) {
      map['total'] = Variable<int>(total.value);
    }
    if (totalEpisodes.present) {
      map['totalEpisodes'] = Variable<int>(totalEpisodes.value);
    }
    if (count.present) {
      map['count'] = Variable<String>(count.value);
    }
    if (score.present) {
      map['score'] = Variable<double>(score.value);
    }
    if (rank.present) {
      map['rank'] = Variable<int>(rank.value);
    }
    if (images.present) {
      map['images'] = Variable<String>(images.value);
    }
    if (collection.present) {
      map['collection'] = Variable<String>(collection.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (alias.present) {
      map['alias'] = Variable<String>(alias.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BangumiBindingTableCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('name: $name, ')
          ..write('nameCn: $nameCn, ')
          ..write('summary: $summary, ')
          ..write('airDate: $airDate, ')
          ..write('airWeekday: $airWeekday, ')
          ..write('total: $total, ')
          ..write('totalEpisodes: $totalEpisodes, ')
          ..write('count: $count, ')
          ..write('score: $score, ')
          ..write('rank: $rank, ')
          ..write('images: $images, ')
          ..write('collection: $collection, ')
          ..write('tags: $tags, ')
          ..write('alias: $alias')
          ..write(')'))
        .toString();
  }
}

class $BangumiAllEpInfoTableTable extends BangumiAllEpInfoTable
    with TableInfo<$BangumiAllEpInfoTableTable, BangumiAllEpInfoTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BangumiAllEpInfoTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, data];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bangumi_AllEpInfo';
  @override
  VerificationContext validateIntegrity(
    Insertable<BangumiAllEpInfoTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BangumiAllEpInfoTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BangumiAllEpInfoTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      ),
    );
  }

  @override
  $BangumiAllEpInfoTableTable createAlias(String alias) {
    return $BangumiAllEpInfoTableTable(attachedDatabase, alias);
  }
}

class BangumiAllEpInfoTableData extends DataClass
    implements Insertable<BangumiAllEpInfoTableData> {
  final int id;
  final String? data;
  const BangumiAllEpInfoTableData({required this.id, this.data});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || data != null) {
      map['data'] = Variable<String>(data);
    }
    return map;
  }

  BangumiAllEpInfoTableCompanion toCompanion(bool nullToAbsent) {
    return BangumiAllEpInfoTableCompanion(
      id: Value(id),
      data: data == null && nullToAbsent ? const Value.absent() : Value(data),
    );
  }

  factory BangumiAllEpInfoTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BangumiAllEpInfoTableData(
      id: serializer.fromJson<int>(json['id']),
      data: serializer.fromJson<String?>(json['data']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'data': serializer.toJson<String?>(data),
    };
  }

  BangumiAllEpInfoTableData copyWith({
    int? id,
    Value<String?> data = const Value.absent(),
  }) => BangumiAllEpInfoTableData(
    id: id ?? this.id,
    data: data.present ? data.value : this.data,
  );
  BangumiAllEpInfoTableData copyWithCompanion(
    BangumiAllEpInfoTableCompanion data,
  ) {
    return BangumiAllEpInfoTableData(
      id: data.id.present ? data.id.value : this.id,
      data: data.data.present ? data.data.value : this.data,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BangumiAllEpInfoTableData(')
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
      (other is BangumiAllEpInfoTableData &&
          other.id == this.id &&
          other.data == this.data);
}

class BangumiAllEpInfoTableCompanion
    extends UpdateCompanion<BangumiAllEpInfoTableData> {
  final Value<int> id;
  final Value<String?> data;
  const BangumiAllEpInfoTableCompanion({
    this.id = const Value.absent(),
    this.data = const Value.absent(),
  });
  BangumiAllEpInfoTableCompanion.insert({
    this.id = const Value.absent(),
    this.data = const Value.absent(),
  });
  static Insertable<BangumiAllEpInfoTableData> custom({
    Expression<int>? id,
    Expression<String>? data,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (data != null) 'data': data,
    });
  }

  BangumiAllEpInfoTableCompanion copyWith({
    Value<int>? id,
    Value<String?>? data,
  }) {
    return BangumiAllEpInfoTableCompanion(
      id: id ?? this.id,
      data: data ?? this.data,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BangumiAllEpInfoTableCompanion(')
          ..write('id: $id, ')
          ..write('data: $data')
          ..write(')'))
        .toString();
  }
}

abstract class _$_BangumiDb extends GeneratedDatabase {
  _$_BangumiDb(QueryExecutor e) : super(e);
  $_BangumiDbManager get managers => $_BangumiDbManager(this);
  late final $BangumiDataTableTable bangumiDataTable = $BangumiDataTableTable(
    this,
  );
  late final $BangumiCalendarTableTable bangumiCalendarTable =
      $BangumiCalendarTableTable(this);
  late final $BangumiBindingTableTable bangumiBindingTable =
      $BangumiBindingTableTable(this);
  late final $BangumiAllEpInfoTableTable bangumiAllEpInfoTable =
      $BangumiAllEpInfoTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    bangumiDataTable,
    bangumiCalendarTable,
    bangumiBindingTable,
    bangumiAllEpInfoTable,
  ];
}

typedef $$BangumiDataTableTableCreateCompanionBuilder =
    BangumiDataTableCompanion Function({
      required String title,
      Value<String?> titleTranslate,
      Value<String?> type,
      Value<String?> lang,
      Value<String?> officialSite,
      Value<String?> begin,
      Value<String?> broadcast,
      Value<String?> end,
      Value<String?> comment,
      Value<String?> sites,
      Value<int> rowid,
    });
typedef $$BangumiDataTableTableUpdateCompanionBuilder =
    BangumiDataTableCompanion Function({
      Value<String> title,
      Value<String?> titleTranslate,
      Value<String?> type,
      Value<String?> lang,
      Value<String?> officialSite,
      Value<String?> begin,
      Value<String?> broadcast,
      Value<String?> end,
      Value<String?> comment,
      Value<String?> sites,
      Value<int> rowid,
    });

class $$BangumiDataTableTableFilterComposer
    extends Composer<_$_BangumiDb, $BangumiDataTableTable> {
  $$BangumiDataTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titleTranslate => $composableBuilder(
    column: $table.titleTranslate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lang => $composableBuilder(
    column: $table.lang,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get officialSite => $composableBuilder(
    column: $table.officialSite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get begin => $composableBuilder(
    column: $table.begin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get broadcast => $composableBuilder(
    column: $table.broadcast,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get end => $composableBuilder(
    column: $table.end,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get comment => $composableBuilder(
    column: $table.comment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sites => $composableBuilder(
    column: $table.sites,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BangumiDataTableTableOrderingComposer
    extends Composer<_$_BangumiDb, $BangumiDataTableTable> {
  $$BangumiDataTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titleTranslate => $composableBuilder(
    column: $table.titleTranslate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lang => $composableBuilder(
    column: $table.lang,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get officialSite => $composableBuilder(
    column: $table.officialSite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get begin => $composableBuilder(
    column: $table.begin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get broadcast => $composableBuilder(
    column: $table.broadcast,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get end => $composableBuilder(
    column: $table.end,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get comment => $composableBuilder(
    column: $table.comment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sites => $composableBuilder(
    column: $table.sites,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BangumiDataTableTableAnnotationComposer
    extends Composer<_$_BangumiDb, $BangumiDataTableTable> {
  $$BangumiDataTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get titleTranslate => $composableBuilder(
    column: $table.titleTranslate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get lang =>
      $composableBuilder(column: $table.lang, builder: (column) => column);

  GeneratedColumn<String> get officialSite => $composableBuilder(
    column: $table.officialSite,
    builder: (column) => column,
  );

  GeneratedColumn<String> get begin =>
      $composableBuilder(column: $table.begin, builder: (column) => column);

  GeneratedColumn<String> get broadcast =>
      $composableBuilder(column: $table.broadcast, builder: (column) => column);

  GeneratedColumn<String> get end =>
      $composableBuilder(column: $table.end, builder: (column) => column);

  GeneratedColumn<String> get comment =>
      $composableBuilder(column: $table.comment, builder: (column) => column);

  GeneratedColumn<String> get sites =>
      $composableBuilder(column: $table.sites, builder: (column) => column);
}

class $$BangumiDataTableTableTableManager
    extends
        RootTableManager<
          _$_BangumiDb,
          $BangumiDataTableTable,
          BangumiDataTableData,
          $$BangumiDataTableTableFilterComposer,
          $$BangumiDataTableTableOrderingComposer,
          $$BangumiDataTableTableAnnotationComposer,
          $$BangumiDataTableTableCreateCompanionBuilder,
          $$BangumiDataTableTableUpdateCompanionBuilder,
          (
            BangumiDataTableData,
            BaseReferences<
              _$_BangumiDb,
              $BangumiDataTableTable,
              BangumiDataTableData
            >,
          ),
          BangumiDataTableData,
          PrefetchHooks Function()
        > {
  $$BangumiDataTableTableTableManager(
    _$_BangumiDb db,
    $BangumiDataTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BangumiDataTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BangumiDataTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BangumiDataTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> title = const Value.absent(),
                Value<String?> titleTranslate = const Value.absent(),
                Value<String?> type = const Value.absent(),
                Value<String?> lang = const Value.absent(),
                Value<String?> officialSite = const Value.absent(),
                Value<String?> begin = const Value.absent(),
                Value<String?> broadcast = const Value.absent(),
                Value<String?> end = const Value.absent(),
                Value<String?> comment = const Value.absent(),
                Value<String?> sites = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BangumiDataTableCompanion(
                title: title,
                titleTranslate: titleTranslate,
                type: type,
                lang: lang,
                officialSite: officialSite,
                begin: begin,
                broadcast: broadcast,
                end: end,
                comment: comment,
                sites: sites,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String title,
                Value<String?> titleTranslate = const Value.absent(),
                Value<String?> type = const Value.absent(),
                Value<String?> lang = const Value.absent(),
                Value<String?> officialSite = const Value.absent(),
                Value<String?> begin = const Value.absent(),
                Value<String?> broadcast = const Value.absent(),
                Value<String?> end = const Value.absent(),
                Value<String?> comment = const Value.absent(),
                Value<String?> sites = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BangumiDataTableCompanion.insert(
                title: title,
                titleTranslate: titleTranslate,
                type: type,
                lang: lang,
                officialSite: officialSite,
                begin: begin,
                broadcast: broadcast,
                end: end,
                comment: comment,
                sites: sites,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BangumiDataTableTableProcessedTableManager =
    ProcessedTableManager<
      _$_BangumiDb,
      $BangumiDataTableTable,
      BangumiDataTableData,
      $$BangumiDataTableTableFilterComposer,
      $$BangumiDataTableTableOrderingComposer,
      $$BangumiDataTableTableAnnotationComposer,
      $$BangumiDataTableTableCreateCompanionBuilder,
      $$BangumiDataTableTableUpdateCompanionBuilder,
      (
        BangumiDataTableData,
        BaseReferences<
          _$_BangumiDb,
          $BangumiDataTableTable,
          BangumiDataTableData
        >,
      ),
      BangumiDataTableData,
      PrefetchHooks Function()
    >;
typedef $$BangumiCalendarTableTableCreateCompanionBuilder =
    BangumiCalendarTableCompanion Function({
      Value<int> id,
      Value<int?> type,
      Value<String?> name,
      Value<String?> nameCn,
      Value<String?> summary,
      Value<String?> airDate,
      Value<int?> airWeekday,
      Value<int?> total,
      Value<String?> count,
      Value<double?> score,
      Value<int?> rank,
      Value<String?> images,
      Value<String?> collection,
    });
typedef $$BangumiCalendarTableTableUpdateCompanionBuilder =
    BangumiCalendarTableCompanion Function({
      Value<int> id,
      Value<int?> type,
      Value<String?> name,
      Value<String?> nameCn,
      Value<String?> summary,
      Value<String?> airDate,
      Value<int?> airWeekday,
      Value<int?> total,
      Value<String?> count,
      Value<double?> score,
      Value<int?> rank,
      Value<String?> images,
      Value<String?> collection,
    });

class $$BangumiCalendarTableTableFilterComposer
    extends Composer<_$_BangumiDb, $BangumiCalendarTableTable> {
  $$BangumiCalendarTableTableFilterComposer({
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

  ColumnFilters<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nameCn => $composableBuilder(
    column: $table.nameCn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get airDate => $composableBuilder(
    column: $table.airDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get airWeekday => $composableBuilder(
    column: $table.airWeekday,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rank => $composableBuilder(
    column: $table.rank,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get images => $composableBuilder(
    column: $table.images,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BangumiCalendarTableTableOrderingComposer
    extends Composer<_$_BangumiDb, $BangumiCalendarTableTable> {
  $$BangumiCalendarTableTableOrderingComposer({
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

  ColumnOrderings<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nameCn => $composableBuilder(
    column: $table.nameCn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get airDate => $composableBuilder(
    column: $table.airDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get airWeekday => $composableBuilder(
    column: $table.airWeekday,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rank => $composableBuilder(
    column: $table.rank,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get images => $composableBuilder(
    column: $table.images,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BangumiCalendarTableTableAnnotationComposer
    extends Composer<_$_BangumiDb, $BangumiCalendarTableTable> {
  $$BangumiCalendarTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get nameCn =>
      $composableBuilder(column: $table.nameCn, builder: (column) => column);

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<String> get airDate =>
      $composableBuilder(column: $table.airDate, builder: (column) => column);

  GeneratedColumn<int> get airWeekday => $composableBuilder(
    column: $table.airWeekday,
    builder: (column) => column,
  );

  GeneratedColumn<int> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);

  GeneratedColumn<String> get count =>
      $composableBuilder(column: $table.count, builder: (column) => column);

  GeneratedColumn<double> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<int> get rank =>
      $composableBuilder(column: $table.rank, builder: (column) => column);

  GeneratedColumn<String> get images =>
      $composableBuilder(column: $table.images, builder: (column) => column);

  GeneratedColumn<String> get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => column,
  );
}

class $$BangumiCalendarTableTableTableManager
    extends
        RootTableManager<
          _$_BangumiDb,
          $BangumiCalendarTableTable,
          BangumiCalendarTableData,
          $$BangumiCalendarTableTableFilterComposer,
          $$BangumiCalendarTableTableOrderingComposer,
          $$BangumiCalendarTableTableAnnotationComposer,
          $$BangumiCalendarTableTableCreateCompanionBuilder,
          $$BangumiCalendarTableTableUpdateCompanionBuilder,
          (
            BangumiCalendarTableData,
            BaseReferences<
              _$_BangumiDb,
              $BangumiCalendarTableTable,
              BangumiCalendarTableData
            >,
          ),
          BangumiCalendarTableData,
          PrefetchHooks Function()
        > {
  $$BangumiCalendarTableTableTableManager(
    _$_BangumiDb db,
    $BangumiCalendarTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BangumiCalendarTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BangumiCalendarTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$BangumiCalendarTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> type = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> nameCn = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<String?> airDate = const Value.absent(),
                Value<int?> airWeekday = const Value.absent(),
                Value<int?> total = const Value.absent(),
                Value<String?> count = const Value.absent(),
                Value<double?> score = const Value.absent(),
                Value<int?> rank = const Value.absent(),
                Value<String?> images = const Value.absent(),
                Value<String?> collection = const Value.absent(),
              }) => BangumiCalendarTableCompanion(
                id: id,
                type: type,
                name: name,
                nameCn: nameCn,
                summary: summary,
                airDate: airDate,
                airWeekday: airWeekday,
                total: total,
                count: count,
                score: score,
                rank: rank,
                images: images,
                collection: collection,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> type = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> nameCn = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<String?> airDate = const Value.absent(),
                Value<int?> airWeekday = const Value.absent(),
                Value<int?> total = const Value.absent(),
                Value<String?> count = const Value.absent(),
                Value<double?> score = const Value.absent(),
                Value<int?> rank = const Value.absent(),
                Value<String?> images = const Value.absent(),
                Value<String?> collection = const Value.absent(),
              }) => BangumiCalendarTableCompanion.insert(
                id: id,
                type: type,
                name: name,
                nameCn: nameCn,
                summary: summary,
                airDate: airDate,
                airWeekday: airWeekday,
                total: total,
                count: count,
                score: score,
                rank: rank,
                images: images,
                collection: collection,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BangumiCalendarTableTableProcessedTableManager =
    ProcessedTableManager<
      _$_BangumiDb,
      $BangumiCalendarTableTable,
      BangumiCalendarTableData,
      $$BangumiCalendarTableTableFilterComposer,
      $$BangumiCalendarTableTableOrderingComposer,
      $$BangumiCalendarTableTableAnnotationComposer,
      $$BangumiCalendarTableTableCreateCompanionBuilder,
      $$BangumiCalendarTableTableUpdateCompanionBuilder,
      (
        BangumiCalendarTableData,
        BaseReferences<
          _$_BangumiDb,
          $BangumiCalendarTableTable,
          BangumiCalendarTableData
        >,
      ),
      BangumiCalendarTableData,
      PrefetchHooks Function()
    >;
typedef $$BangumiBindingTableTableCreateCompanionBuilder =
    BangumiBindingTableCompanion Function({
      Value<int> id,
      Value<int?> type,
      Value<String?> name,
      Value<String?> nameCn,
      Value<String?> summary,
      Value<String?> airDate,
      Value<int?> airWeekday,
      Value<int?> total,
      Value<int?> totalEpisodes,
      Value<String?> count,
      Value<double?> score,
      Value<int?> rank,
      Value<String?> images,
      Value<String?> collection,
      Value<String?> tags,
      Value<String?> alias,
    });
typedef $$BangumiBindingTableTableUpdateCompanionBuilder =
    BangumiBindingTableCompanion Function({
      Value<int> id,
      Value<int?> type,
      Value<String?> name,
      Value<String?> nameCn,
      Value<String?> summary,
      Value<String?> airDate,
      Value<int?> airWeekday,
      Value<int?> total,
      Value<int?> totalEpisodes,
      Value<String?> count,
      Value<double?> score,
      Value<int?> rank,
      Value<String?> images,
      Value<String?> collection,
      Value<String?> tags,
      Value<String?> alias,
    });

class $$BangumiBindingTableTableFilterComposer
    extends Composer<_$_BangumiDb, $BangumiBindingTableTable> {
  $$BangumiBindingTableTableFilterComposer({
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

  ColumnFilters<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nameCn => $composableBuilder(
    column: $table.nameCn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get airDate => $composableBuilder(
    column: $table.airDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get airWeekday => $composableBuilder(
    column: $table.airWeekday,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalEpisodes => $composableBuilder(
    column: $table.totalEpisodes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rank => $composableBuilder(
    column: $table.rank,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get images => $composableBuilder(
    column: $table.images,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get alias => $composableBuilder(
    column: $table.alias,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BangumiBindingTableTableOrderingComposer
    extends Composer<_$_BangumiDb, $BangumiBindingTableTable> {
  $$BangumiBindingTableTableOrderingComposer({
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

  ColumnOrderings<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nameCn => $composableBuilder(
    column: $table.nameCn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get airDate => $composableBuilder(
    column: $table.airDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get airWeekday => $composableBuilder(
    column: $table.airWeekday,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalEpisodes => $composableBuilder(
    column: $table.totalEpisodes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rank => $composableBuilder(
    column: $table.rank,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get images => $composableBuilder(
    column: $table.images,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alias => $composableBuilder(
    column: $table.alias,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BangumiBindingTableTableAnnotationComposer
    extends Composer<_$_BangumiDb, $BangumiBindingTableTable> {
  $$BangumiBindingTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get nameCn =>
      $composableBuilder(column: $table.nameCn, builder: (column) => column);

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<String> get airDate =>
      $composableBuilder(column: $table.airDate, builder: (column) => column);

  GeneratedColumn<int> get airWeekday => $composableBuilder(
    column: $table.airWeekday,
    builder: (column) => column,
  );

  GeneratedColumn<int> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);

  GeneratedColumn<int> get totalEpisodes => $composableBuilder(
    column: $table.totalEpisodes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get count =>
      $composableBuilder(column: $table.count, builder: (column) => column);

  GeneratedColumn<double> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<int> get rank =>
      $composableBuilder(column: $table.rank, builder: (column) => column);

  GeneratedColumn<String> get images =>
      $composableBuilder(column: $table.images, builder: (column) => column);

  GeneratedColumn<String> get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get alias =>
      $composableBuilder(column: $table.alias, builder: (column) => column);
}

class $$BangumiBindingTableTableTableManager
    extends
        RootTableManager<
          _$_BangumiDb,
          $BangumiBindingTableTable,
          BangumiBindingTableData,
          $$BangumiBindingTableTableFilterComposer,
          $$BangumiBindingTableTableOrderingComposer,
          $$BangumiBindingTableTableAnnotationComposer,
          $$BangumiBindingTableTableCreateCompanionBuilder,
          $$BangumiBindingTableTableUpdateCompanionBuilder,
          (
            BangumiBindingTableData,
            BaseReferences<
              _$_BangumiDb,
              $BangumiBindingTableTable,
              BangumiBindingTableData
            >,
          ),
          BangumiBindingTableData,
          PrefetchHooks Function()
        > {
  $$BangumiBindingTableTableTableManager(
    _$_BangumiDb db,
    $BangumiBindingTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BangumiBindingTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BangumiBindingTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$BangumiBindingTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> type = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> nameCn = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<String?> airDate = const Value.absent(),
                Value<int?> airWeekday = const Value.absent(),
                Value<int?> total = const Value.absent(),
                Value<int?> totalEpisodes = const Value.absent(),
                Value<String?> count = const Value.absent(),
                Value<double?> score = const Value.absent(),
                Value<int?> rank = const Value.absent(),
                Value<String?> images = const Value.absent(),
                Value<String?> collection = const Value.absent(),
                Value<String?> tags = const Value.absent(),
                Value<String?> alias = const Value.absent(),
              }) => BangumiBindingTableCompanion(
                id: id,
                type: type,
                name: name,
                nameCn: nameCn,
                summary: summary,
                airDate: airDate,
                airWeekday: airWeekday,
                total: total,
                totalEpisodes: totalEpisodes,
                count: count,
                score: score,
                rank: rank,
                images: images,
                collection: collection,
                tags: tags,
                alias: alias,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> type = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> nameCn = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<String?> airDate = const Value.absent(),
                Value<int?> airWeekday = const Value.absent(),
                Value<int?> total = const Value.absent(),
                Value<int?> totalEpisodes = const Value.absent(),
                Value<String?> count = const Value.absent(),
                Value<double?> score = const Value.absent(),
                Value<int?> rank = const Value.absent(),
                Value<String?> images = const Value.absent(),
                Value<String?> collection = const Value.absent(),
                Value<String?> tags = const Value.absent(),
                Value<String?> alias = const Value.absent(),
              }) => BangumiBindingTableCompanion.insert(
                id: id,
                type: type,
                name: name,
                nameCn: nameCn,
                summary: summary,
                airDate: airDate,
                airWeekday: airWeekday,
                total: total,
                totalEpisodes: totalEpisodes,
                count: count,
                score: score,
                rank: rank,
                images: images,
                collection: collection,
                tags: tags,
                alias: alias,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BangumiBindingTableTableProcessedTableManager =
    ProcessedTableManager<
      _$_BangumiDb,
      $BangumiBindingTableTable,
      BangumiBindingTableData,
      $$BangumiBindingTableTableFilterComposer,
      $$BangumiBindingTableTableOrderingComposer,
      $$BangumiBindingTableTableAnnotationComposer,
      $$BangumiBindingTableTableCreateCompanionBuilder,
      $$BangumiBindingTableTableUpdateCompanionBuilder,
      (
        BangumiBindingTableData,
        BaseReferences<
          _$_BangumiDb,
          $BangumiBindingTableTable,
          BangumiBindingTableData
        >,
      ),
      BangumiBindingTableData,
      PrefetchHooks Function()
    >;
typedef $$BangumiAllEpInfoTableTableCreateCompanionBuilder =
    BangumiAllEpInfoTableCompanion Function({
      Value<int> id,
      Value<String?> data,
    });
typedef $$BangumiAllEpInfoTableTableUpdateCompanionBuilder =
    BangumiAllEpInfoTableCompanion Function({
      Value<int> id,
      Value<String?> data,
    });

class $$BangumiAllEpInfoTableTableFilterComposer
    extends Composer<_$_BangumiDb, $BangumiAllEpInfoTableTable> {
  $$BangumiAllEpInfoTableTableFilterComposer({
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

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BangumiAllEpInfoTableTableOrderingComposer
    extends Composer<_$_BangumiDb, $BangumiAllEpInfoTableTable> {
  $$BangumiAllEpInfoTableTableOrderingComposer({
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

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BangumiAllEpInfoTableTableAnnotationComposer
    extends Composer<_$_BangumiDb, $BangumiAllEpInfoTableTable> {
  $$BangumiAllEpInfoTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);
}

class $$BangumiAllEpInfoTableTableTableManager
    extends
        RootTableManager<
          _$_BangumiDb,
          $BangumiAllEpInfoTableTable,
          BangumiAllEpInfoTableData,
          $$BangumiAllEpInfoTableTableFilterComposer,
          $$BangumiAllEpInfoTableTableOrderingComposer,
          $$BangumiAllEpInfoTableTableAnnotationComposer,
          $$BangumiAllEpInfoTableTableCreateCompanionBuilder,
          $$BangumiAllEpInfoTableTableUpdateCompanionBuilder,
          (
            BangumiAllEpInfoTableData,
            BaseReferences<
              _$_BangumiDb,
              $BangumiAllEpInfoTableTable,
              BangumiAllEpInfoTableData
            >,
          ),
          BangumiAllEpInfoTableData,
          PrefetchHooks Function()
        > {
  $$BangumiAllEpInfoTableTableTableManager(
    _$_BangumiDb db,
    $BangumiAllEpInfoTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BangumiAllEpInfoTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$BangumiAllEpInfoTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$BangumiAllEpInfoTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> data = const Value.absent(),
              }) => BangumiAllEpInfoTableCompanion(id: id, data: data),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> data = const Value.absent(),
              }) => BangumiAllEpInfoTableCompanion.insert(id: id, data: data),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BangumiAllEpInfoTableTableProcessedTableManager =
    ProcessedTableManager<
      _$_BangumiDb,
      $BangumiAllEpInfoTableTable,
      BangumiAllEpInfoTableData,
      $$BangumiAllEpInfoTableTableFilterComposer,
      $$BangumiAllEpInfoTableTableOrderingComposer,
      $$BangumiAllEpInfoTableTableAnnotationComposer,
      $$BangumiAllEpInfoTableTableCreateCompanionBuilder,
      $$BangumiAllEpInfoTableTableUpdateCompanionBuilder,
      (
        BangumiAllEpInfoTableData,
        BaseReferences<
          _$_BangumiDb,
          $BangumiAllEpInfoTableTable,
          BangumiAllEpInfoTableData
        >,
      ),
      BangumiAllEpInfoTableData,
      PrefetchHooks Function()
    >;

class $_BangumiDbManager {
  final _$_BangumiDb _db;
  $_BangumiDbManager(this._db);
  $$BangumiDataTableTableTableManager get bangumiDataTable =>
      $$BangumiDataTableTableTableManager(_db, _db.bangumiDataTable);
  $$BangumiCalendarTableTableTableManager get bangumiCalendarTable =>
      $$BangumiCalendarTableTableTableManager(_db, _db.bangumiCalendarTable);
  $$BangumiBindingTableTableTableManager get bangumiBindingTable =>
      $$BangumiBindingTableTableTableManager(_db, _db.bangumiBindingTable);
  $$BangumiAllEpInfoTableTableTableManager get bangumiAllEpInfoTable =>
      $$BangumiAllEpInfoTableTableTableManager(_db, _db.bangumiAllEpInfoTable);
}

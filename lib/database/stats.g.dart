// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stats.dart';

// ignore_for_file: type=lint
class $StatsTableTable extends StatsTable
    with TableInfo<$StatsTableTable, StatsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StatsTableTable(this.attachedDatabase, [this._alias]);
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
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverMeta = const VerificationMeta('cover');
  @override
  late final GeneratedColumn<String> cover = GeneratedColumn<String>(
    'cover',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<int> type = GeneratedColumn<int>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _likedMeta = const VerificationMeta('liked');
  @override
  late final GeneratedColumn<bool> liked = GeneratedColumn<bool>(
    'liked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("liked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isBangumiMeta = const VerificationMeta(
    'isBangumi',
  );
  @override
  late final GeneratedColumn<bool> isBangumi = GeneratedColumn<bool>(
    'isBangumi',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("isBangumi" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  static const VerificationMeta _totalClickCountMeta = const VerificationMeta(
    'totalClickCount',
  );
  @override
  late final GeneratedColumn<String> totalClickCount = GeneratedColumn<String>(
    'totalClickCount',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _firstClickTimeMeta = const VerificationMeta(
    'firstClickTime',
  );
  @override
  late final GeneratedColumn<String> firstClickTime = GeneratedColumn<String>(
    'firstClickTime',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastClickTimeMeta = const VerificationMeta(
    'lastClickTime',
  );
  @override
  late final GeneratedColumn<String> lastClickTime = GeneratedColumn<String>(
    'lastClickTime',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalWatchDurationsMeta =
      const VerificationMeta('totalWatchDurations');
  @override
  late final GeneratedColumn<String> totalWatchDurations =
      GeneratedColumn<String>(
        'totalWatchDurations',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<String> rating = GeneratedColumn<String>(
    'rating',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _favoriteMeta = const VerificationMeta(
    'favorite',
  );
  @override
  late final GeneratedColumn<String> favorite = GeneratedColumn<String>(
    'favorite',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    cover,
    bangumiId,
    type,
    liked,
    isBangumi,
    comment,
    totalClickCount,
    firstClickTime,
    lastClickTime,
    totalWatchDurations,
    rating,
    favorite,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stats';
  @override
  VerificationContext validateIntegrity(
    Insertable<StatsTableData> instance, {
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
    }
    if (data.containsKey('cover')) {
      context.handle(
        _coverMeta,
        cover.isAcceptableOrUnknown(data['cover']!, _coverMeta),
      );
    }
    if (data.containsKey('bangumiId')) {
      context.handle(
        _bangumiIdMeta,
        bangumiId.isAcceptableOrUnknown(data['bangumiId']!, _bangumiIdMeta),
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
    if (data.containsKey('liked')) {
      context.handle(
        _likedMeta,
        liked.isAcceptableOrUnknown(data['liked']!, _likedMeta),
      );
    }
    if (data.containsKey('isBangumi')) {
      context.handle(
        _isBangumiMeta,
        isBangumi.isAcceptableOrUnknown(data['isBangumi']!, _isBangumiMeta),
      );
    }
    if (data.containsKey('comment')) {
      context.handle(
        _commentMeta,
        comment.isAcceptableOrUnknown(data['comment']!, _commentMeta),
      );
    }
    if (data.containsKey('totalClickCount')) {
      context.handle(
        _totalClickCountMeta,
        totalClickCount.isAcceptableOrUnknown(
          data['totalClickCount']!,
          _totalClickCountMeta,
        ),
      );
    }
    if (data.containsKey('firstClickTime')) {
      context.handle(
        _firstClickTimeMeta,
        firstClickTime.isAcceptableOrUnknown(
          data['firstClickTime']!,
          _firstClickTimeMeta,
        ),
      );
    }
    if (data.containsKey('lastClickTime')) {
      context.handle(
        _lastClickTimeMeta,
        lastClickTime.isAcceptableOrUnknown(
          data['lastClickTime']!,
          _lastClickTimeMeta,
        ),
      );
    }
    if (data.containsKey('totalWatchDurations')) {
      context.handle(
        _totalWatchDurationsMeta,
        totalWatchDurations.isAcceptableOrUnknown(
          data['totalWatchDurations']!,
          _totalWatchDurationsMeta,
        ),
      );
    }
    if (data.containsKey('rating')) {
      context.handle(
        _ratingMeta,
        rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta),
      );
    }
    if (data.containsKey('favorite')) {
      context.handle(
        _favoriteMeta,
        favorite.isAcceptableOrUnknown(data['favorite']!, _favoriteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id, type};
  @override
  StatsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StatsTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      cover: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover'],
      ),
      bangumiId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bangumiId'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type'],
      )!,
      liked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}liked'],
      )!,
      isBangumi: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}isBangumi'],
      )!,
      comment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comment'],
      ),
      totalClickCount: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}totalClickCount'],
      ),
      firstClickTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}firstClickTime'],
      ),
      lastClickTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lastClickTime'],
      ),
      totalWatchDurations: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}totalWatchDurations'],
      ),
      rating: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rating'],
      ),
      favorite: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}favorite'],
      ),
    );
  }

  @override
  $StatsTableTable createAlias(String alias) {
    return $StatsTableTable(attachedDatabase, alias);
  }
}

class StatsTableData extends DataClass implements Insertable<StatsTableData> {
  final String id;
  final String? title;
  final String? cover;
  final int? bangumiId;
  final int type;
  final bool liked;
  final bool isBangumi;
  final String? comment;
  final String? totalClickCount;
  final String? firstClickTime;
  final String? lastClickTime;
  final String? totalWatchDurations;
  final String? rating;
  final String? favorite;
  const StatsTableData({
    required this.id,
    this.title,
    this.cover,
    this.bangumiId,
    required this.type,
    required this.liked,
    required this.isBangumi,
    this.comment,
    this.totalClickCount,
    this.firstClickTime,
    this.lastClickTime,
    this.totalWatchDurations,
    this.rating,
    this.favorite,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || cover != null) {
      map['cover'] = Variable<String>(cover);
    }
    if (!nullToAbsent || bangumiId != null) {
      map['bangumiId'] = Variable<int>(bangumiId);
    }
    map['type'] = Variable<int>(type);
    map['liked'] = Variable<bool>(liked);
    map['isBangumi'] = Variable<bool>(isBangumi);
    if (!nullToAbsent || comment != null) {
      map['comment'] = Variable<String>(comment);
    }
    if (!nullToAbsent || totalClickCount != null) {
      map['totalClickCount'] = Variable<String>(totalClickCount);
    }
    if (!nullToAbsent || firstClickTime != null) {
      map['firstClickTime'] = Variable<String>(firstClickTime);
    }
    if (!nullToAbsent || lastClickTime != null) {
      map['lastClickTime'] = Variable<String>(lastClickTime);
    }
    if (!nullToAbsent || totalWatchDurations != null) {
      map['totalWatchDurations'] = Variable<String>(totalWatchDurations);
    }
    if (!nullToAbsent || rating != null) {
      map['rating'] = Variable<String>(rating);
    }
    if (!nullToAbsent || favorite != null) {
      map['favorite'] = Variable<String>(favorite);
    }
    return map;
  }

  StatsTableCompanion toCompanion(bool nullToAbsent) {
    return StatsTableCompanion(
      id: Value(id),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      cover: cover == null && nullToAbsent
          ? const Value.absent()
          : Value(cover),
      bangumiId: bangumiId == null && nullToAbsent
          ? const Value.absent()
          : Value(bangumiId),
      type: Value(type),
      liked: Value(liked),
      isBangumi: Value(isBangumi),
      comment: comment == null && nullToAbsent
          ? const Value.absent()
          : Value(comment),
      totalClickCount: totalClickCount == null && nullToAbsent
          ? const Value.absent()
          : Value(totalClickCount),
      firstClickTime: firstClickTime == null && nullToAbsent
          ? const Value.absent()
          : Value(firstClickTime),
      lastClickTime: lastClickTime == null && nullToAbsent
          ? const Value.absent()
          : Value(lastClickTime),
      totalWatchDurations: totalWatchDurations == null && nullToAbsent
          ? const Value.absent()
          : Value(totalWatchDurations),
      rating: rating == null && nullToAbsent
          ? const Value.absent()
          : Value(rating),
      favorite: favorite == null && nullToAbsent
          ? const Value.absent()
          : Value(favorite),
    );
  }

  factory StatsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StatsTableData(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String?>(json['title']),
      cover: serializer.fromJson<String?>(json['cover']),
      bangumiId: serializer.fromJson<int?>(json['bangumiId']),
      type: serializer.fromJson<int>(json['type']),
      liked: serializer.fromJson<bool>(json['liked']),
      isBangumi: serializer.fromJson<bool>(json['isBangumi']),
      comment: serializer.fromJson<String?>(json['comment']),
      totalClickCount: serializer.fromJson<String?>(json['totalClickCount']),
      firstClickTime: serializer.fromJson<String?>(json['firstClickTime']),
      lastClickTime: serializer.fromJson<String?>(json['lastClickTime']),
      totalWatchDurations: serializer.fromJson<String?>(
        json['totalWatchDurations'],
      ),
      rating: serializer.fromJson<String?>(json['rating']),
      favorite: serializer.fromJson<String?>(json['favorite']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String?>(title),
      'cover': serializer.toJson<String?>(cover),
      'bangumiId': serializer.toJson<int?>(bangumiId),
      'type': serializer.toJson<int>(type),
      'liked': serializer.toJson<bool>(liked),
      'isBangumi': serializer.toJson<bool>(isBangumi),
      'comment': serializer.toJson<String?>(comment),
      'totalClickCount': serializer.toJson<String?>(totalClickCount),
      'firstClickTime': serializer.toJson<String?>(firstClickTime),
      'lastClickTime': serializer.toJson<String?>(lastClickTime),
      'totalWatchDurations': serializer.toJson<String?>(totalWatchDurations),
      'rating': serializer.toJson<String?>(rating),
      'favorite': serializer.toJson<String?>(favorite),
    };
  }

  StatsTableData copyWith({
    String? id,
    Value<String?> title = const Value.absent(),
    Value<String?> cover = const Value.absent(),
    Value<int?> bangumiId = const Value.absent(),
    int? type,
    bool? liked,
    bool? isBangumi,
    Value<String?> comment = const Value.absent(),
    Value<String?> totalClickCount = const Value.absent(),
    Value<String?> firstClickTime = const Value.absent(),
    Value<String?> lastClickTime = const Value.absent(),
    Value<String?> totalWatchDurations = const Value.absent(),
    Value<String?> rating = const Value.absent(),
    Value<String?> favorite = const Value.absent(),
  }) => StatsTableData(
    id: id ?? this.id,
    title: title.present ? title.value : this.title,
    cover: cover.present ? cover.value : this.cover,
    bangumiId: bangumiId.present ? bangumiId.value : this.bangumiId,
    type: type ?? this.type,
    liked: liked ?? this.liked,
    isBangumi: isBangumi ?? this.isBangumi,
    comment: comment.present ? comment.value : this.comment,
    totalClickCount: totalClickCount.present
        ? totalClickCount.value
        : this.totalClickCount,
    firstClickTime: firstClickTime.present
        ? firstClickTime.value
        : this.firstClickTime,
    lastClickTime: lastClickTime.present
        ? lastClickTime.value
        : this.lastClickTime,
    totalWatchDurations: totalWatchDurations.present
        ? totalWatchDurations.value
        : this.totalWatchDurations,
    rating: rating.present ? rating.value : this.rating,
    favorite: favorite.present ? favorite.value : this.favorite,
  );
  StatsTableData copyWithCompanion(StatsTableCompanion data) {
    return StatsTableData(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      cover: data.cover.present ? data.cover.value : this.cover,
      bangumiId: data.bangumiId.present ? data.bangumiId.value : this.bangumiId,
      type: data.type.present ? data.type.value : this.type,
      liked: data.liked.present ? data.liked.value : this.liked,
      isBangumi: data.isBangumi.present ? data.isBangumi.value : this.isBangumi,
      comment: data.comment.present ? data.comment.value : this.comment,
      totalClickCount: data.totalClickCount.present
          ? data.totalClickCount.value
          : this.totalClickCount,
      firstClickTime: data.firstClickTime.present
          ? data.firstClickTime.value
          : this.firstClickTime,
      lastClickTime: data.lastClickTime.present
          ? data.lastClickTime.value
          : this.lastClickTime,
      totalWatchDurations: data.totalWatchDurations.present
          ? data.totalWatchDurations.value
          : this.totalWatchDurations,
      rating: data.rating.present ? data.rating.value : this.rating,
      favorite: data.favorite.present ? data.favorite.value : this.favorite,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StatsTableData(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('cover: $cover, ')
          ..write('bangumiId: $bangumiId, ')
          ..write('type: $type, ')
          ..write('liked: $liked, ')
          ..write('isBangumi: $isBangumi, ')
          ..write('comment: $comment, ')
          ..write('totalClickCount: $totalClickCount, ')
          ..write('firstClickTime: $firstClickTime, ')
          ..write('lastClickTime: $lastClickTime, ')
          ..write('totalWatchDurations: $totalWatchDurations, ')
          ..write('rating: $rating, ')
          ..write('favorite: $favorite')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    cover,
    bangumiId,
    type,
    liked,
    isBangumi,
    comment,
    totalClickCount,
    firstClickTime,
    lastClickTime,
    totalWatchDurations,
    rating,
    favorite,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StatsTableData &&
          other.id == this.id &&
          other.title == this.title &&
          other.cover == this.cover &&
          other.bangumiId == this.bangumiId &&
          other.type == this.type &&
          other.liked == this.liked &&
          other.isBangumi == this.isBangumi &&
          other.comment == this.comment &&
          other.totalClickCount == this.totalClickCount &&
          other.firstClickTime == this.firstClickTime &&
          other.lastClickTime == this.lastClickTime &&
          other.totalWatchDurations == this.totalWatchDurations &&
          other.rating == this.rating &&
          other.favorite == this.favorite);
}

class StatsTableCompanion extends UpdateCompanion<StatsTableData> {
  final Value<String> id;
  final Value<String?> title;
  final Value<String?> cover;
  final Value<int?> bangumiId;
  final Value<int> type;
  final Value<bool> liked;
  final Value<bool> isBangumi;
  final Value<String?> comment;
  final Value<String?> totalClickCount;
  final Value<String?> firstClickTime;
  final Value<String?> lastClickTime;
  final Value<String?> totalWatchDurations;
  final Value<String?> rating;
  final Value<String?> favorite;
  final Value<int> rowid;
  const StatsTableCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.cover = const Value.absent(),
    this.bangumiId = const Value.absent(),
    this.type = const Value.absent(),
    this.liked = const Value.absent(),
    this.isBangumi = const Value.absent(),
    this.comment = const Value.absent(),
    this.totalClickCount = const Value.absent(),
    this.firstClickTime = const Value.absent(),
    this.lastClickTime = const Value.absent(),
    this.totalWatchDurations = const Value.absent(),
    this.rating = const Value.absent(),
    this.favorite = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StatsTableCompanion.insert({
    required String id,
    this.title = const Value.absent(),
    this.cover = const Value.absent(),
    this.bangumiId = const Value.absent(),
    required int type,
    this.liked = const Value.absent(),
    this.isBangumi = const Value.absent(),
    this.comment = const Value.absent(),
    this.totalClickCount = const Value.absent(),
    this.firstClickTime = const Value.absent(),
    this.lastClickTime = const Value.absent(),
    this.totalWatchDurations = const Value.absent(),
    this.rating = const Value.absent(),
    this.favorite = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type);
  static Insertable<StatsTableData> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? cover,
    Expression<int>? bangumiId,
    Expression<int>? type,
    Expression<bool>? liked,
    Expression<bool>? isBangumi,
    Expression<String>? comment,
    Expression<String>? totalClickCount,
    Expression<String>? firstClickTime,
    Expression<String>? lastClickTime,
    Expression<String>? totalWatchDurations,
    Expression<String>? rating,
    Expression<String>? favorite,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (cover != null) 'cover': cover,
      if (bangumiId != null) 'bangumiId': bangumiId,
      if (type != null) 'type': type,
      if (liked != null) 'liked': liked,
      if (isBangumi != null) 'isBangumi': isBangumi,
      if (comment != null) 'comment': comment,
      if (totalClickCount != null) 'totalClickCount': totalClickCount,
      if (firstClickTime != null) 'firstClickTime': firstClickTime,
      if (lastClickTime != null) 'lastClickTime': lastClickTime,
      if (totalWatchDurations != null)
        'totalWatchDurations': totalWatchDurations,
      if (rating != null) 'rating': rating,
      if (favorite != null) 'favorite': favorite,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StatsTableCompanion copyWith({
    Value<String>? id,
    Value<String?>? title,
    Value<String?>? cover,
    Value<int?>? bangumiId,
    Value<int>? type,
    Value<bool>? liked,
    Value<bool>? isBangumi,
    Value<String?>? comment,
    Value<String?>? totalClickCount,
    Value<String?>? firstClickTime,
    Value<String?>? lastClickTime,
    Value<String?>? totalWatchDurations,
    Value<String?>? rating,
    Value<String?>? favorite,
    Value<int>? rowid,
  }) {
    return StatsTableCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      cover: cover ?? this.cover,
      bangumiId: bangumiId ?? this.bangumiId,
      type: type ?? this.type,
      liked: liked ?? this.liked,
      isBangumi: isBangumi ?? this.isBangumi,
      comment: comment ?? this.comment,
      totalClickCount: totalClickCount ?? this.totalClickCount,
      firstClickTime: firstClickTime ?? this.firstClickTime,
      lastClickTime: lastClickTime ?? this.lastClickTime,
      totalWatchDurations: totalWatchDurations ?? this.totalWatchDurations,
      rating: rating ?? this.rating,
      favorite: favorite ?? this.favorite,
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
    if (cover.present) {
      map['cover'] = Variable<String>(cover.value);
    }
    if (bangumiId.present) {
      map['bangumiId'] = Variable<int>(bangumiId.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(type.value);
    }
    if (liked.present) {
      map['liked'] = Variable<bool>(liked.value);
    }
    if (isBangumi.present) {
      map['isBangumi'] = Variable<bool>(isBangumi.value);
    }
    if (comment.present) {
      map['comment'] = Variable<String>(comment.value);
    }
    if (totalClickCount.present) {
      map['totalClickCount'] = Variable<String>(totalClickCount.value);
    }
    if (firstClickTime.present) {
      map['firstClickTime'] = Variable<String>(firstClickTime.value);
    }
    if (lastClickTime.present) {
      map['lastClickTime'] = Variable<String>(lastClickTime.value);
    }
    if (totalWatchDurations.present) {
      map['totalWatchDurations'] = Variable<String>(totalWatchDurations.value);
    }
    if (rating.present) {
      map['rating'] = Variable<String>(rating.value);
    }
    if (favorite.present) {
      map['favorite'] = Variable<String>(favorite.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StatsTableCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('cover: $cover, ')
          ..write('bangumiId: $bangumiId, ')
          ..write('type: $type, ')
          ..write('liked: $liked, ')
          ..write('isBangumi: $isBangumi, ')
          ..write('comment: $comment, ')
          ..write('totalClickCount: $totalClickCount, ')
          ..write('firstClickTime: $firstClickTime, ')
          ..write('lastClickTime: $lastClickTime, ')
          ..write('totalWatchDurations: $totalWatchDurations, ')
          ..write('rating: $rating, ')
          ..write('favorite: $favorite, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$_StatsDb extends GeneratedDatabase {
  _$_StatsDb(QueryExecutor e) : super(e);
  $_StatsDbManager get managers => $_StatsDbManager(this);
  late final $StatsTableTable statsTable = $StatsTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [statsTable];
}

typedef $$StatsTableTableCreateCompanionBuilder =
    StatsTableCompanion Function({
      required String id,
      Value<String?> title,
      Value<String?> cover,
      Value<int?> bangumiId,
      required int type,
      Value<bool> liked,
      Value<bool> isBangumi,
      Value<String?> comment,
      Value<String?> totalClickCount,
      Value<String?> firstClickTime,
      Value<String?> lastClickTime,
      Value<String?> totalWatchDurations,
      Value<String?> rating,
      Value<String?> favorite,
      Value<int> rowid,
    });
typedef $$StatsTableTableUpdateCompanionBuilder =
    StatsTableCompanion Function({
      Value<String> id,
      Value<String?> title,
      Value<String?> cover,
      Value<int?> bangumiId,
      Value<int> type,
      Value<bool> liked,
      Value<bool> isBangumi,
      Value<String?> comment,
      Value<String?> totalClickCount,
      Value<String?> firstClickTime,
      Value<String?> lastClickTime,
      Value<String?> totalWatchDurations,
      Value<String?> rating,
      Value<String?> favorite,
      Value<int> rowid,
    });

class $$StatsTableTableFilterComposer
    extends Composer<_$_StatsDb, $StatsTableTable> {
  $$StatsTableTableFilterComposer({
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

  ColumnFilters<String> get cover => $composableBuilder(
    column: $table.cover,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bangumiId => $composableBuilder(
    column: $table.bangumiId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get liked => $composableBuilder(
    column: $table.liked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isBangumi => $composableBuilder(
    column: $table.isBangumi,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get comment => $composableBuilder(
    column: $table.comment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get totalClickCount => $composableBuilder(
    column: $table.totalClickCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get firstClickTime => $composableBuilder(
    column: $table.firstClickTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastClickTime => $composableBuilder(
    column: $table.lastClickTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get totalWatchDurations => $composableBuilder(
    column: $table.totalWatchDurations,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get favorite => $composableBuilder(
    column: $table.favorite,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StatsTableTableOrderingComposer
    extends Composer<_$_StatsDb, $StatsTableTable> {
  $$StatsTableTableOrderingComposer({
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

  ColumnOrderings<String> get cover => $composableBuilder(
    column: $table.cover,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bangumiId => $composableBuilder(
    column: $table.bangumiId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get liked => $composableBuilder(
    column: $table.liked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isBangumi => $composableBuilder(
    column: $table.isBangumi,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get comment => $composableBuilder(
    column: $table.comment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get totalClickCount => $composableBuilder(
    column: $table.totalClickCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get firstClickTime => $composableBuilder(
    column: $table.firstClickTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastClickTime => $composableBuilder(
    column: $table.lastClickTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get totalWatchDurations => $composableBuilder(
    column: $table.totalWatchDurations,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get favorite => $composableBuilder(
    column: $table.favorite,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StatsTableTableAnnotationComposer
    extends Composer<_$_StatsDb, $StatsTableTable> {
  $$StatsTableTableAnnotationComposer({
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

  GeneratedColumn<String> get cover =>
      $composableBuilder(column: $table.cover, builder: (column) => column);

  GeneratedColumn<int> get bangumiId =>
      $composableBuilder(column: $table.bangumiId, builder: (column) => column);

  GeneratedColumn<int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<bool> get liked =>
      $composableBuilder(column: $table.liked, builder: (column) => column);

  GeneratedColumn<bool> get isBangumi =>
      $composableBuilder(column: $table.isBangumi, builder: (column) => column);

  GeneratedColumn<String> get comment =>
      $composableBuilder(column: $table.comment, builder: (column) => column);

  GeneratedColumn<String> get totalClickCount => $composableBuilder(
    column: $table.totalClickCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get firstClickTime => $composableBuilder(
    column: $table.firstClickTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastClickTime => $composableBuilder(
    column: $table.lastClickTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get totalWatchDurations => $composableBuilder(
    column: $table.totalWatchDurations,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<String> get favorite =>
      $composableBuilder(column: $table.favorite, builder: (column) => column);
}

class $$StatsTableTableTableManager
    extends
        RootTableManager<
          _$_StatsDb,
          $StatsTableTable,
          StatsTableData,
          $$StatsTableTableFilterComposer,
          $$StatsTableTableOrderingComposer,
          $$StatsTableTableAnnotationComposer,
          $$StatsTableTableCreateCompanionBuilder,
          $$StatsTableTableUpdateCompanionBuilder,
          (
            StatsTableData,
            BaseReferences<_$_StatsDb, $StatsTableTable, StatsTableData>,
          ),
          StatsTableData,
          PrefetchHooks Function()
        > {
  $$StatsTableTableTableManager(_$_StatsDb db, $StatsTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StatsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StatsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StatsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> cover = const Value.absent(),
                Value<int?> bangumiId = const Value.absent(),
                Value<int> type = const Value.absent(),
                Value<bool> liked = const Value.absent(),
                Value<bool> isBangumi = const Value.absent(),
                Value<String?> comment = const Value.absent(),
                Value<String?> totalClickCount = const Value.absent(),
                Value<String?> firstClickTime = const Value.absent(),
                Value<String?> lastClickTime = const Value.absent(),
                Value<String?> totalWatchDurations = const Value.absent(),
                Value<String?> rating = const Value.absent(),
                Value<String?> favorite = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StatsTableCompanion(
                id: id,
                title: title,
                cover: cover,
                bangumiId: bangumiId,
                type: type,
                liked: liked,
                isBangumi: isBangumi,
                comment: comment,
                totalClickCount: totalClickCount,
                firstClickTime: firstClickTime,
                lastClickTime: lastClickTime,
                totalWatchDurations: totalWatchDurations,
                rating: rating,
                favorite: favorite,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> title = const Value.absent(),
                Value<String?> cover = const Value.absent(),
                Value<int?> bangumiId = const Value.absent(),
                required int type,
                Value<bool> liked = const Value.absent(),
                Value<bool> isBangumi = const Value.absent(),
                Value<String?> comment = const Value.absent(),
                Value<String?> totalClickCount = const Value.absent(),
                Value<String?> firstClickTime = const Value.absent(),
                Value<String?> lastClickTime = const Value.absent(),
                Value<String?> totalWatchDurations = const Value.absent(),
                Value<String?> rating = const Value.absent(),
                Value<String?> favorite = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StatsTableCompanion.insert(
                id: id,
                title: title,
                cover: cover,
                bangumiId: bangumiId,
                type: type,
                liked: liked,
                isBangumi: isBangumi,
                comment: comment,
                totalClickCount: totalClickCount,
                firstClickTime: firstClickTime,
                lastClickTime: lastClickTime,
                totalWatchDurations: totalWatchDurations,
                rating: rating,
                favorite: favorite,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StatsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$_StatsDb,
      $StatsTableTable,
      StatsTableData,
      $$StatsTableTableFilterComposer,
      $$StatsTableTableOrderingComposer,
      $$StatsTableTableAnnotationComposer,
      $$StatsTableTableCreateCompanionBuilder,
      $$StatsTableTableUpdateCompanionBuilder,
      (
        StatsTableData,
        BaseReferences<_$_StatsDb, $StatsTableTable, StatsTableData>,
      ),
      StatsTableData,
      PrefetchHooks Function()
    >;

class $_StatsDbManager {
  final _$_StatsDb _db;
  $_StatsDbManager(this._db);
  $$StatsTableTableTableManager get statsTable =>
      $$StatsTableTableTableManager(_db, _db.statsTable);
}

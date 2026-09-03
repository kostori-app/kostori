// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_database.dart';

// ignore_for_file: type=lint
class $AiApiKeysTable extends AiApiKeys
    with TableInfo<$AiApiKeysTable, AiApiKey> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiApiKeysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _apiKeyMeta = const VerificationMeta('apiKey');
  @override
  late final GeneratedColumn<String> apiKey = GeneratedColumn<String>(
    'api_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseUrlMeta = const VerificationMeta(
    'baseUrl',
  );
  @override
  late final GeneratedColumn<String> baseUrl = GeneratedColumn<String>(
    'base_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _balanceUrlMeta = const VerificationMeta(
    'balanceUrl',
  );
  @override
  late final GeneratedColumn<String> balanceUrl = GeneratedColumn<String>(
    'balance_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _balanceKeyMeta = const VerificationMeta(
    'balanceKey',
  );
  @override
  late final GeneratedColumn<String> balanceKey = GeneratedColumn<String>(
    'balance_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _apiFormatMeta = const VerificationMeta(
    'apiFormat',
  );
  @override
  late final GeneratedColumn<String> apiFormat = GeneratedColumn<String>(
    'api_format',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modelsUrlMeta = const VerificationMeta(
    'modelsUrl',
  );
  @override
  late final GeneratedColumn<String> modelsUrl = GeneratedColumn<String>(
    'models_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isEnabledMeta = const VerificationMeta(
    'isEnabled',
  );
  @override
  late final GeneratedColumn<bool> isEnabled = GeneratedColumn<bool>(
    'is_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    provider,
    apiKey,
    baseUrl,
    model,
    balanceUrl,
    balanceKey,
    apiFormat,
    modelsUrl,
    isEnabled,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_api_keys';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiApiKey> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('api_key')) {
      context.handle(
        _apiKeyMeta,
        apiKey.isAcceptableOrUnknown(data['api_key']!, _apiKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_apiKeyMeta);
    }
    if (data.containsKey('base_url')) {
      context.handle(
        _baseUrlMeta,
        baseUrl.isAcceptableOrUnknown(data['base_url']!, _baseUrlMeta),
      );
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    }
    if (data.containsKey('balance_url')) {
      context.handle(
        _balanceUrlMeta,
        balanceUrl.isAcceptableOrUnknown(data['balance_url']!, _balanceUrlMeta),
      );
    }
    if (data.containsKey('balance_key')) {
      context.handle(
        _balanceKeyMeta,
        balanceKey.isAcceptableOrUnknown(data['balance_key']!, _balanceKeyMeta),
      );
    }
    if (data.containsKey('api_format')) {
      context.handle(
        _apiFormatMeta,
        apiFormat.isAcceptableOrUnknown(data['api_format']!, _apiFormatMeta),
      );
    }
    if (data.containsKey('models_url')) {
      context.handle(
        _modelsUrlMeta,
        modelsUrl.isAcceptableOrUnknown(data['models_url']!, _modelsUrlMeta),
      );
    }
    if (data.containsKey('is_enabled')) {
      context.handle(
        _isEnabledMeta,
        isEnabled.isAcceptableOrUnknown(data['is_enabled']!, _isEnabledMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {provider};
  @override
  AiApiKey map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiApiKey(
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      )!,
      apiKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}api_key'],
      )!,
      baseUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_url'],
      ),
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      ),
      balanceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}balance_url'],
      ),
      balanceKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}balance_key'],
      ),
      apiFormat: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}api_format'],
      ),
      modelsUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}models_url'],
      ),
      isEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_enabled'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AiApiKeysTable createAlias(String alias) {
    return $AiApiKeysTable(attachedDatabase, alias);
  }
}

class AiApiKey extends DataClass implements Insertable<AiApiKey> {
  final String provider;
  final String apiKey;
  final String? baseUrl;
  final String? model;

  /// 余额查询 URL（可自定义；为空表示使用内置默认查询）
  final String? balanceUrl;

  /// 余额结果 JSON key path（点号分隔，如 `data.balance`）
  final String? balanceKey;

  /// 接口格式：openai | openai_responses | gemini | claude；null 视为 openai
  final String? apiFormat;

  /// 自定义的"查询可用模型"接口地址；为空使用内置默认
  final String? modelsUrl;
  final bool isEnabled;
  final DateTime updatedAt;
  const AiApiKey({
    required this.provider,
    required this.apiKey,
    this.baseUrl,
    this.model,
    this.balanceUrl,
    this.balanceKey,
    this.apiFormat,
    this.modelsUrl,
    required this.isEnabled,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['provider'] = Variable<String>(provider);
    map['api_key'] = Variable<String>(apiKey);
    if (!nullToAbsent || baseUrl != null) {
      map['base_url'] = Variable<String>(baseUrl);
    }
    if (!nullToAbsent || model != null) {
      map['model'] = Variable<String>(model);
    }
    if (!nullToAbsent || balanceUrl != null) {
      map['balance_url'] = Variable<String>(balanceUrl);
    }
    if (!nullToAbsent || balanceKey != null) {
      map['balance_key'] = Variable<String>(balanceKey);
    }
    if (!nullToAbsent || apiFormat != null) {
      map['api_format'] = Variable<String>(apiFormat);
    }
    if (!nullToAbsent || modelsUrl != null) {
      map['models_url'] = Variable<String>(modelsUrl);
    }
    map['is_enabled'] = Variable<bool>(isEnabled);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AiApiKeysCompanion toCompanion(bool nullToAbsent) {
    return AiApiKeysCompanion(
      provider: Value(provider),
      apiKey: Value(apiKey),
      baseUrl: baseUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(baseUrl),
      model: model == null && nullToAbsent
          ? const Value.absent()
          : Value(model),
      balanceUrl: balanceUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(balanceUrl),
      balanceKey: balanceKey == null && nullToAbsent
          ? const Value.absent()
          : Value(balanceKey),
      apiFormat: apiFormat == null && nullToAbsent
          ? const Value.absent()
          : Value(apiFormat),
      modelsUrl: modelsUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(modelsUrl),
      isEnabled: Value(isEnabled),
      updatedAt: Value(updatedAt),
    );
  }

  factory AiApiKey.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiApiKey(
      provider: serializer.fromJson<String>(json['provider']),
      apiKey: serializer.fromJson<String>(json['apiKey']),
      baseUrl: serializer.fromJson<String?>(json['baseUrl']),
      model: serializer.fromJson<String?>(json['model']),
      balanceUrl: serializer.fromJson<String?>(json['balanceUrl']),
      balanceKey: serializer.fromJson<String?>(json['balanceKey']),
      apiFormat: serializer.fromJson<String?>(json['apiFormat']),
      modelsUrl: serializer.fromJson<String?>(json['modelsUrl']),
      isEnabled: serializer.fromJson<bool>(json['isEnabled']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'provider': serializer.toJson<String>(provider),
      'apiKey': serializer.toJson<String>(apiKey),
      'baseUrl': serializer.toJson<String?>(baseUrl),
      'model': serializer.toJson<String?>(model),
      'balanceUrl': serializer.toJson<String?>(balanceUrl),
      'balanceKey': serializer.toJson<String?>(balanceKey),
      'apiFormat': serializer.toJson<String?>(apiFormat),
      'modelsUrl': serializer.toJson<String?>(modelsUrl),
      'isEnabled': serializer.toJson<bool>(isEnabled),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AiApiKey copyWith({
    String? provider,
    String? apiKey,
    Value<String?> baseUrl = const Value.absent(),
    Value<String?> model = const Value.absent(),
    Value<String?> balanceUrl = const Value.absent(),
    Value<String?> balanceKey = const Value.absent(),
    Value<String?> apiFormat = const Value.absent(),
    Value<String?> modelsUrl = const Value.absent(),
    bool? isEnabled,
    DateTime? updatedAt,
  }) => AiApiKey(
    provider: provider ?? this.provider,
    apiKey: apiKey ?? this.apiKey,
    baseUrl: baseUrl.present ? baseUrl.value : this.baseUrl,
    model: model.present ? model.value : this.model,
    balanceUrl: balanceUrl.present ? balanceUrl.value : this.balanceUrl,
    balanceKey: balanceKey.present ? balanceKey.value : this.balanceKey,
    apiFormat: apiFormat.present ? apiFormat.value : this.apiFormat,
    modelsUrl: modelsUrl.present ? modelsUrl.value : this.modelsUrl,
    isEnabled: isEnabled ?? this.isEnabled,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AiApiKey copyWithCompanion(AiApiKeysCompanion data) {
    return AiApiKey(
      provider: data.provider.present ? data.provider.value : this.provider,
      apiKey: data.apiKey.present ? data.apiKey.value : this.apiKey,
      baseUrl: data.baseUrl.present ? data.baseUrl.value : this.baseUrl,
      model: data.model.present ? data.model.value : this.model,
      balanceUrl: data.balanceUrl.present
          ? data.balanceUrl.value
          : this.balanceUrl,
      balanceKey: data.balanceKey.present
          ? data.balanceKey.value
          : this.balanceKey,
      apiFormat: data.apiFormat.present ? data.apiFormat.value : this.apiFormat,
      modelsUrl: data.modelsUrl.present ? data.modelsUrl.value : this.modelsUrl,
      isEnabled: data.isEnabled.present ? data.isEnabled.value : this.isEnabled,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiApiKey(')
          ..write('provider: $provider, ')
          ..write('apiKey: $apiKey, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('model: $model, ')
          ..write('balanceUrl: $balanceUrl, ')
          ..write('balanceKey: $balanceKey, ')
          ..write('apiFormat: $apiFormat, ')
          ..write('modelsUrl: $modelsUrl, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    provider,
    apiKey,
    baseUrl,
    model,
    balanceUrl,
    balanceKey,
    apiFormat,
    modelsUrl,
    isEnabled,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiApiKey &&
          other.provider == this.provider &&
          other.apiKey == this.apiKey &&
          other.baseUrl == this.baseUrl &&
          other.model == this.model &&
          other.balanceUrl == this.balanceUrl &&
          other.balanceKey == this.balanceKey &&
          other.apiFormat == this.apiFormat &&
          other.modelsUrl == this.modelsUrl &&
          other.isEnabled == this.isEnabled &&
          other.updatedAt == this.updatedAt);
}

class AiApiKeysCompanion extends UpdateCompanion<AiApiKey> {
  final Value<String> provider;
  final Value<String> apiKey;
  final Value<String?> baseUrl;
  final Value<String?> model;
  final Value<String?> balanceUrl;
  final Value<String?> balanceKey;
  final Value<String?> apiFormat;
  final Value<String?> modelsUrl;
  final Value<bool> isEnabled;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AiApiKeysCompanion({
    this.provider = const Value.absent(),
    this.apiKey = const Value.absent(),
    this.baseUrl = const Value.absent(),
    this.model = const Value.absent(),
    this.balanceUrl = const Value.absent(),
    this.balanceKey = const Value.absent(),
    this.apiFormat = const Value.absent(),
    this.modelsUrl = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AiApiKeysCompanion.insert({
    required String provider,
    required String apiKey,
    this.baseUrl = const Value.absent(),
    this.model = const Value.absent(),
    this.balanceUrl = const Value.absent(),
    this.balanceKey = const Value.absent(),
    this.apiFormat = const Value.absent(),
    this.modelsUrl = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : provider = Value(provider),
       apiKey = Value(apiKey);
  static Insertable<AiApiKey> custom({
    Expression<String>? provider,
    Expression<String>? apiKey,
    Expression<String>? baseUrl,
    Expression<String>? model,
    Expression<String>? balanceUrl,
    Expression<String>? balanceKey,
    Expression<String>? apiFormat,
    Expression<String>? modelsUrl,
    Expression<bool>? isEnabled,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (provider != null) 'provider': provider,
      if (apiKey != null) 'api_key': apiKey,
      if (baseUrl != null) 'base_url': baseUrl,
      if (model != null) 'model': model,
      if (balanceUrl != null) 'balance_url': balanceUrl,
      if (balanceKey != null) 'balance_key': balanceKey,
      if (apiFormat != null) 'api_format': apiFormat,
      if (modelsUrl != null) 'models_url': modelsUrl,
      if (isEnabled != null) 'is_enabled': isEnabled,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AiApiKeysCompanion copyWith({
    Value<String>? provider,
    Value<String>? apiKey,
    Value<String?>? baseUrl,
    Value<String?>? model,
    Value<String?>? balanceUrl,
    Value<String?>? balanceKey,
    Value<String?>? apiFormat,
    Value<String?>? modelsUrl,
    Value<bool>? isEnabled,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return AiApiKeysCompanion(
      provider: provider ?? this.provider,
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      balanceUrl: balanceUrl ?? this.balanceUrl,
      balanceKey: balanceKey ?? this.balanceKey,
      apiFormat: apiFormat ?? this.apiFormat,
      modelsUrl: modelsUrl ?? this.modelsUrl,
      isEnabled: isEnabled ?? this.isEnabled,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (apiKey.present) {
      map['api_key'] = Variable<String>(apiKey.value);
    }
    if (baseUrl.present) {
      map['base_url'] = Variable<String>(baseUrl.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (balanceUrl.present) {
      map['balance_url'] = Variable<String>(balanceUrl.value);
    }
    if (balanceKey.present) {
      map['balance_key'] = Variable<String>(balanceKey.value);
    }
    if (apiFormat.present) {
      map['api_format'] = Variable<String>(apiFormat.value);
    }
    if (modelsUrl.present) {
      map['models_url'] = Variable<String>(modelsUrl.value);
    }
    if (isEnabled.present) {
      map['is_enabled'] = Variable<bool>(isEnabled.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiApiKeysCompanion(')
          ..write('provider: $provider, ')
          ..write('apiKey: $apiKey, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('model: $model, ')
          ..write('balanceUrl: $balanceUrl, ')
          ..write('balanceKey: $balanceKey, ')
          ..write('apiFormat: $apiFormat, ')
          ..write('modelsUrl: $modelsUrl, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AiSessionsTable extends AiSessions
    with TableInfo<$AiSessionsTable, AiSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 20,
    ),
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
    requiredDuringInsert: false,
    defaultValue: const Constant('新对话'),
  );
  static const VerificationMeta _configKeyMeta = const VerificationMeta(
    'configKey',
  );
  @override
  late final GeneratedColumn<String> configKey = GeneratedColumn<String>(
    'config_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _compressedContentMeta = const VerificationMeta(
    'compressedContent',
  );
  @override
  late final GeneratedColumn<String> compressedContent =
      GeneratedColumn<String>(
        'compressed_content',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _skillKeysMeta = const VerificationMeta(
    'skillKeys',
  );
  @override
  late final GeneratedColumn<String> skillKeys = GeneratedColumn<String>(
    'skill_keys',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _followUpsMeta = const VerificationMeta(
    'followUps',
  );
  @override
  late final GeneratedColumn<String> followUps = GeneratedColumn<String>(
    'follow_ups',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sessionId,
    type,
    title,
    configKey,
    profileId,
    provider,
    compressedContent,
    skillKeys,
    followUps,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('config_key')) {
      context.handle(
        _configKeyMeta,
        configKey.isAcceptableOrUnknown(data['config_key']!, _configKeyMeta),
      );
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('compressed_content')) {
      context.handle(
        _compressedContentMeta,
        compressedContent.isAcceptableOrUnknown(
          data['compressed_content']!,
          _compressedContentMeta,
        ),
      );
    }
    if (data.containsKey('skill_keys')) {
      context.handle(
        _skillKeysMeta,
        skillKeys.isAcceptableOrUnknown(data['skill_keys']!, _skillKeysMeta),
      );
    }
    if (data.containsKey('follow_ups')) {
      context.handle(
        _followUpsMeta,
        followUps.isAcceptableOrUnknown(data['follow_ups']!, _followUpsMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId};
  @override
  AiSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiSession(
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      configKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}config_key'],
      ),
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      ),
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      )!,
      compressedContent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}compressed_content'],
      ),
      skillKeys: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}skill_keys'],
      ),
      followUps: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}follow_ups'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AiSessionsTable createAlias(String alias) {
    return $AiSessionsTable(attachedDatabase, alias);
  }
}

class AiSession extends DataClass implements Insertable<AiSession> {
  /// UUID 或随机字符串
  final String sessionId;

  /// 会话类型: 'chat' | 'soul_profile' | 'translation'
  final String type;

  /// 会话标题
  final String title;

  /// 关联的 System Prompt 配置 key
  final String? configKey;

  /// 关联的助手档案 id（AssistantProfile）
  final String? profileId;

  /// 使用的服务商
  final String provider;

  /// 已压缩的旧上下文摘要
  final String? compressedContent;

  /// 会话启用的技能 keys（JSON 数组字符串）
  final String? skillKeys;

  /// 已生成的后续追问建议（JSON 数组字符串）
  final String? followUps;
  final DateTime createdAt;
  final DateTime updatedAt;
  const AiSession({
    required this.sessionId,
    required this.type,
    required this.title,
    this.configKey,
    this.profileId,
    required this.provider,
    this.compressedContent,
    this.skillKeys,
    this.followUps,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<String>(sessionId);
    map['type'] = Variable<String>(type);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || configKey != null) {
      map['config_key'] = Variable<String>(configKey);
    }
    if (!nullToAbsent || profileId != null) {
      map['profile_id'] = Variable<String>(profileId);
    }
    map['provider'] = Variable<String>(provider);
    if (!nullToAbsent || compressedContent != null) {
      map['compressed_content'] = Variable<String>(compressedContent);
    }
    if (!nullToAbsent || skillKeys != null) {
      map['skill_keys'] = Variable<String>(skillKeys);
    }
    if (!nullToAbsent || followUps != null) {
      map['follow_ups'] = Variable<String>(followUps);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AiSessionsCompanion toCompanion(bool nullToAbsent) {
    return AiSessionsCompanion(
      sessionId: Value(sessionId),
      type: Value(type),
      title: Value(title),
      configKey: configKey == null && nullToAbsent
          ? const Value.absent()
          : Value(configKey),
      profileId: profileId == null && nullToAbsent
          ? const Value.absent()
          : Value(profileId),
      provider: Value(provider),
      compressedContent: compressedContent == null && nullToAbsent
          ? const Value.absent()
          : Value(compressedContent),
      skillKeys: skillKeys == null && nullToAbsent
          ? const Value.absent()
          : Value(skillKeys),
      followUps: followUps == null && nullToAbsent
          ? const Value.absent()
          : Value(followUps),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory AiSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiSession(
      sessionId: serializer.fromJson<String>(json['sessionId']),
      type: serializer.fromJson<String>(json['type']),
      title: serializer.fromJson<String>(json['title']),
      configKey: serializer.fromJson<String?>(json['configKey']),
      profileId: serializer.fromJson<String?>(json['profileId']),
      provider: serializer.fromJson<String>(json['provider']),
      compressedContent: serializer.fromJson<String?>(
        json['compressedContent'],
      ),
      skillKeys: serializer.fromJson<String?>(json['skillKeys']),
      followUps: serializer.fromJson<String?>(json['followUps']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sessionId': serializer.toJson<String>(sessionId),
      'type': serializer.toJson<String>(type),
      'title': serializer.toJson<String>(title),
      'configKey': serializer.toJson<String?>(configKey),
      'profileId': serializer.toJson<String?>(profileId),
      'provider': serializer.toJson<String>(provider),
      'compressedContent': serializer.toJson<String?>(compressedContent),
      'skillKeys': serializer.toJson<String?>(skillKeys),
      'followUps': serializer.toJson<String?>(followUps),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AiSession copyWith({
    String? sessionId,
    String? type,
    String? title,
    Value<String?> configKey = const Value.absent(),
    Value<String?> profileId = const Value.absent(),
    String? provider,
    Value<String?> compressedContent = const Value.absent(),
    Value<String?> skillKeys = const Value.absent(),
    Value<String?> followUps = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => AiSession(
    sessionId: sessionId ?? this.sessionId,
    type: type ?? this.type,
    title: title ?? this.title,
    configKey: configKey.present ? configKey.value : this.configKey,
    profileId: profileId.present ? profileId.value : this.profileId,
    provider: provider ?? this.provider,
    compressedContent: compressedContent.present
        ? compressedContent.value
        : this.compressedContent,
    skillKeys: skillKeys.present ? skillKeys.value : this.skillKeys,
    followUps: followUps.present ? followUps.value : this.followUps,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AiSession copyWithCompanion(AiSessionsCompanion data) {
    return AiSession(
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      type: data.type.present ? data.type.value : this.type,
      title: data.title.present ? data.title.value : this.title,
      configKey: data.configKey.present ? data.configKey.value : this.configKey,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      provider: data.provider.present ? data.provider.value : this.provider,
      compressedContent: data.compressedContent.present
          ? data.compressedContent.value
          : this.compressedContent,
      skillKeys: data.skillKeys.present ? data.skillKeys.value : this.skillKeys,
      followUps: data.followUps.present ? data.followUps.value : this.followUps,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiSession(')
          ..write('sessionId: $sessionId, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('configKey: $configKey, ')
          ..write('profileId: $profileId, ')
          ..write('provider: $provider, ')
          ..write('compressedContent: $compressedContent, ')
          ..write('skillKeys: $skillKeys, ')
          ..write('followUps: $followUps, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sessionId,
    type,
    title,
    configKey,
    profileId,
    provider,
    compressedContent,
    skillKeys,
    followUps,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiSession &&
          other.sessionId == this.sessionId &&
          other.type == this.type &&
          other.title == this.title &&
          other.configKey == this.configKey &&
          other.profileId == this.profileId &&
          other.provider == this.provider &&
          other.compressedContent == this.compressedContent &&
          other.skillKeys == this.skillKeys &&
          other.followUps == this.followUps &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AiSessionsCompanion extends UpdateCompanion<AiSession> {
  final Value<String> sessionId;
  final Value<String> type;
  final Value<String> title;
  final Value<String?> configKey;
  final Value<String?> profileId;
  final Value<String> provider;
  final Value<String?> compressedContent;
  final Value<String?> skillKeys;
  final Value<String?> followUps;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AiSessionsCompanion({
    this.sessionId = const Value.absent(),
    this.type = const Value.absent(),
    this.title = const Value.absent(),
    this.configKey = const Value.absent(),
    this.profileId = const Value.absent(),
    this.provider = const Value.absent(),
    this.compressedContent = const Value.absent(),
    this.skillKeys = const Value.absent(),
    this.followUps = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AiSessionsCompanion.insert({
    required String sessionId,
    required String type,
    this.title = const Value.absent(),
    this.configKey = const Value.absent(),
    this.profileId = const Value.absent(),
    required String provider,
    this.compressedContent = const Value.absent(),
    this.skillKeys = const Value.absent(),
    this.followUps = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : sessionId = Value(sessionId),
       type = Value(type),
       provider = Value(provider);
  static Insertable<AiSession> custom({
    Expression<String>? sessionId,
    Expression<String>? type,
    Expression<String>? title,
    Expression<String>? configKey,
    Expression<String>? profileId,
    Expression<String>? provider,
    Expression<String>? compressedContent,
    Expression<String>? skillKeys,
    Expression<String>? followUps,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (type != null) 'type': type,
      if (title != null) 'title': title,
      if (configKey != null) 'config_key': configKey,
      if (profileId != null) 'profile_id': profileId,
      if (provider != null) 'provider': provider,
      if (compressedContent != null) 'compressed_content': compressedContent,
      if (skillKeys != null) 'skill_keys': skillKeys,
      if (followUps != null) 'follow_ups': followUps,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AiSessionsCompanion copyWith({
    Value<String>? sessionId,
    Value<String>? type,
    Value<String>? title,
    Value<String?>? configKey,
    Value<String?>? profileId,
    Value<String>? provider,
    Value<String?>? compressedContent,
    Value<String?>? skillKeys,
    Value<String?>? followUps,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return AiSessionsCompanion(
      sessionId: sessionId ?? this.sessionId,
      type: type ?? this.type,
      title: title ?? this.title,
      configKey: configKey ?? this.configKey,
      profileId: profileId ?? this.profileId,
      provider: provider ?? this.provider,
      compressedContent: compressedContent ?? this.compressedContent,
      skillKeys: skillKeys ?? this.skillKeys,
      followUps: followUps ?? this.followUps,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (configKey.present) {
      map['config_key'] = Variable<String>(configKey.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (compressedContent.present) {
      map['compressed_content'] = Variable<String>(compressedContent.value);
    }
    if (skillKeys.present) {
      map['skill_keys'] = Variable<String>(skillKeys.value);
    }
    if (followUps.present) {
      map['follow_ups'] = Variable<String>(followUps.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiSessionsCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('configKey: $configKey, ')
          ..write('profileId: $profileId, ')
          ..write('provider: $provider, ')
          ..write('compressedContent: $compressedContent, ')
          ..write('skillKeys: $skillKeys, ')
          ..write('followUps: $followUps, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AiTasksTable extends AiTasks with TableInfo<$AiTasksTable, AiTask> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiTasksTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskTypeMeta = const VerificationMeta(
    'taskType',
  );
  @override
  late final GeneratedColumn<String> taskType = GeneratedColumn<String>(
    'task_type',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 50,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('user'),
  );
  static const VerificationMeta _inputContentMeta = const VerificationMeta(
    'inputContent',
  );
  @override
  late final GeneratedColumn<String> inputContent = GeneratedColumn<String>(
    'input_content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _inputImagesMeta = const VerificationMeta(
    'inputImages',
  );
  @override
  late final GeneratedColumn<String> inputImages = GeneratedColumn<String>(
    'input_images',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _outputContentMeta = const VerificationMeta(
    'outputContent',
  );
  @override
  late final GeneratedColumn<String> outputContent = GeneratedColumn<String>(
    'output_content',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thoughtMeta = const VerificationMeta(
    'thought',
  );
  @override
  late final GeneratedColumn<String> thought = GeneratedColumn<String>(
    'thought',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelNameMeta = const VerificationMeta(
    'modelName',
  );
  @override
  late final GeneratedColumn<String> modelName = GeneratedColumn<String>(
    'model_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tokenConsumedMeta = const VerificationMeta(
    'tokenConsumed',
  );
  @override
  late final GeneratedColumn<int> tokenConsumed = GeneratedColumn<int>(
    'token_consumed',
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
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    taskType,
    role,
    inputContent,
    inputImages,
    outputContent,
    thought,
    provider,
    modelName,
    tokenConsumed,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiTask> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('task_type')) {
      context.handle(
        _taskTypeMeta,
        taskType.isAcceptableOrUnknown(data['task_type']!, _taskTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_taskTypeMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    }
    if (data.containsKey('input_content')) {
      context.handle(
        _inputContentMeta,
        inputContent.isAcceptableOrUnknown(
          data['input_content']!,
          _inputContentMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_inputContentMeta);
    }
    if (data.containsKey('input_images')) {
      context.handle(
        _inputImagesMeta,
        inputImages.isAcceptableOrUnknown(
          data['input_images']!,
          _inputImagesMeta,
        ),
      );
    }
    if (data.containsKey('output_content')) {
      context.handle(
        _outputContentMeta,
        outputContent.isAcceptableOrUnknown(
          data['output_content']!,
          _outputContentMeta,
        ),
      );
    }
    if (data.containsKey('thought')) {
      context.handle(
        _thoughtMeta,
        thought.isAcceptableOrUnknown(data['thought']!, _thoughtMeta),
      );
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('model_name')) {
      context.handle(
        _modelNameMeta,
        modelName.isAcceptableOrUnknown(data['model_name']!, _modelNameMeta),
      );
    }
    if (data.containsKey('token_consumed')) {
      context.handle(
        _tokenConsumedMeta,
        tokenConsumed.isAcceptableOrUnknown(
          data['token_consumed']!,
          _tokenConsumedMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AiTask map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiTask(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      taskType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_type'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      inputContent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}input_content'],
      )!,
      inputImages: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}input_images'],
      ),
      outputContent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}output_content'],
      ),
      thought: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thought'],
      ),
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      )!,
      modelName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_name'],
      ),
      tokenConsumed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}token_consumed'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AiTasksTable createAlias(String alias) {
    return $AiTasksTable(attachedDatabase, alias);
  }
}

class AiTask extends DataClass implements Insertable<AiTask> {
  final int id;
  final String sessionId;
  final String taskType;
  final String role;
  final String inputContent;

  /// 用户消息附带的图片（data URL 的 JSON 数组），用于聊天界面展示
  final String? inputImages;
  final String? outputContent;
  final String? thought;
  final String provider;
  final String? modelName;
  final int tokenConsumed;
  final DateTime createdAt;
  const AiTask({
    required this.id,
    required this.sessionId,
    required this.taskType,
    required this.role,
    required this.inputContent,
    this.inputImages,
    this.outputContent,
    this.thought,
    required this.provider,
    this.modelName,
    required this.tokenConsumed,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['task_type'] = Variable<String>(taskType);
    map['role'] = Variable<String>(role);
    map['input_content'] = Variable<String>(inputContent);
    if (!nullToAbsent || inputImages != null) {
      map['input_images'] = Variable<String>(inputImages);
    }
    if (!nullToAbsent || outputContent != null) {
      map['output_content'] = Variable<String>(outputContent);
    }
    if (!nullToAbsent || thought != null) {
      map['thought'] = Variable<String>(thought);
    }
    map['provider'] = Variable<String>(provider);
    if (!nullToAbsent || modelName != null) {
      map['model_name'] = Variable<String>(modelName);
    }
    map['token_consumed'] = Variable<int>(tokenConsumed);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AiTasksCompanion toCompanion(bool nullToAbsent) {
    return AiTasksCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      taskType: Value(taskType),
      role: Value(role),
      inputContent: Value(inputContent),
      inputImages: inputImages == null && nullToAbsent
          ? const Value.absent()
          : Value(inputImages),
      outputContent: outputContent == null && nullToAbsent
          ? const Value.absent()
          : Value(outputContent),
      thought: thought == null && nullToAbsent
          ? const Value.absent()
          : Value(thought),
      provider: Value(provider),
      modelName: modelName == null && nullToAbsent
          ? const Value.absent()
          : Value(modelName),
      tokenConsumed: Value(tokenConsumed),
      createdAt: Value(createdAt),
    );
  }

  factory AiTask.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiTask(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      taskType: serializer.fromJson<String>(json['taskType']),
      role: serializer.fromJson<String>(json['role']),
      inputContent: serializer.fromJson<String>(json['inputContent']),
      inputImages: serializer.fromJson<String?>(json['inputImages']),
      outputContent: serializer.fromJson<String?>(json['outputContent']),
      thought: serializer.fromJson<String?>(json['thought']),
      provider: serializer.fromJson<String>(json['provider']),
      modelName: serializer.fromJson<String?>(json['modelName']),
      tokenConsumed: serializer.fromJson<int>(json['tokenConsumed']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'taskType': serializer.toJson<String>(taskType),
      'role': serializer.toJson<String>(role),
      'inputContent': serializer.toJson<String>(inputContent),
      'inputImages': serializer.toJson<String?>(inputImages),
      'outputContent': serializer.toJson<String?>(outputContent),
      'thought': serializer.toJson<String?>(thought),
      'provider': serializer.toJson<String>(provider),
      'modelName': serializer.toJson<String?>(modelName),
      'tokenConsumed': serializer.toJson<int>(tokenConsumed),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  AiTask copyWith({
    int? id,
    String? sessionId,
    String? taskType,
    String? role,
    String? inputContent,
    Value<String?> inputImages = const Value.absent(),
    Value<String?> outputContent = const Value.absent(),
    Value<String?> thought = const Value.absent(),
    String? provider,
    Value<String?> modelName = const Value.absent(),
    int? tokenConsumed,
    DateTime? createdAt,
  }) => AiTask(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    taskType: taskType ?? this.taskType,
    role: role ?? this.role,
    inputContent: inputContent ?? this.inputContent,
    inputImages: inputImages.present ? inputImages.value : this.inputImages,
    outputContent: outputContent.present
        ? outputContent.value
        : this.outputContent,
    thought: thought.present ? thought.value : this.thought,
    provider: provider ?? this.provider,
    modelName: modelName.present ? modelName.value : this.modelName,
    tokenConsumed: tokenConsumed ?? this.tokenConsumed,
    createdAt: createdAt ?? this.createdAt,
  );
  AiTask copyWithCompanion(AiTasksCompanion data) {
    return AiTask(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      taskType: data.taskType.present ? data.taskType.value : this.taskType,
      role: data.role.present ? data.role.value : this.role,
      inputContent: data.inputContent.present
          ? data.inputContent.value
          : this.inputContent,
      inputImages: data.inputImages.present
          ? data.inputImages.value
          : this.inputImages,
      outputContent: data.outputContent.present
          ? data.outputContent.value
          : this.outputContent,
      thought: data.thought.present ? data.thought.value : this.thought,
      provider: data.provider.present ? data.provider.value : this.provider,
      modelName: data.modelName.present ? data.modelName.value : this.modelName,
      tokenConsumed: data.tokenConsumed.present
          ? data.tokenConsumed.value
          : this.tokenConsumed,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiTask(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('taskType: $taskType, ')
          ..write('role: $role, ')
          ..write('inputContent: $inputContent, ')
          ..write('inputImages: $inputImages, ')
          ..write('outputContent: $outputContent, ')
          ..write('thought: $thought, ')
          ..write('provider: $provider, ')
          ..write('modelName: $modelName, ')
          ..write('tokenConsumed: $tokenConsumed, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    taskType,
    role,
    inputContent,
    inputImages,
    outputContent,
    thought,
    provider,
    modelName,
    tokenConsumed,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiTask &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.taskType == this.taskType &&
          other.role == this.role &&
          other.inputContent == this.inputContent &&
          other.inputImages == this.inputImages &&
          other.outputContent == this.outputContent &&
          other.thought == this.thought &&
          other.provider == this.provider &&
          other.modelName == this.modelName &&
          other.tokenConsumed == this.tokenConsumed &&
          other.createdAt == this.createdAt);
}

class AiTasksCompanion extends UpdateCompanion<AiTask> {
  final Value<int> id;
  final Value<String> sessionId;
  final Value<String> taskType;
  final Value<String> role;
  final Value<String> inputContent;
  final Value<String?> inputImages;
  final Value<String?> outputContent;
  final Value<String?> thought;
  final Value<String> provider;
  final Value<String?> modelName;
  final Value<int> tokenConsumed;
  final Value<DateTime> createdAt;
  const AiTasksCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.taskType = const Value.absent(),
    this.role = const Value.absent(),
    this.inputContent = const Value.absent(),
    this.inputImages = const Value.absent(),
    this.outputContent = const Value.absent(),
    this.thought = const Value.absent(),
    this.provider = const Value.absent(),
    this.modelName = const Value.absent(),
    this.tokenConsumed = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  AiTasksCompanion.insert({
    this.id = const Value.absent(),
    required String sessionId,
    required String taskType,
    this.role = const Value.absent(),
    required String inputContent,
    this.inputImages = const Value.absent(),
    this.outputContent = const Value.absent(),
    this.thought = const Value.absent(),
    required String provider,
    this.modelName = const Value.absent(),
    this.tokenConsumed = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : sessionId = Value(sessionId),
       taskType = Value(taskType),
       inputContent = Value(inputContent),
       provider = Value(provider);
  static Insertable<AiTask> custom({
    Expression<int>? id,
    Expression<String>? sessionId,
    Expression<String>? taskType,
    Expression<String>? role,
    Expression<String>? inputContent,
    Expression<String>? inputImages,
    Expression<String>? outputContent,
    Expression<String>? thought,
    Expression<String>? provider,
    Expression<String>? modelName,
    Expression<int>? tokenConsumed,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (taskType != null) 'task_type': taskType,
      if (role != null) 'role': role,
      if (inputContent != null) 'input_content': inputContent,
      if (inputImages != null) 'input_images': inputImages,
      if (outputContent != null) 'output_content': outputContent,
      if (thought != null) 'thought': thought,
      if (provider != null) 'provider': provider,
      if (modelName != null) 'model_name': modelName,
      if (tokenConsumed != null) 'token_consumed': tokenConsumed,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  AiTasksCompanion copyWith({
    Value<int>? id,
    Value<String>? sessionId,
    Value<String>? taskType,
    Value<String>? role,
    Value<String>? inputContent,
    Value<String?>? inputImages,
    Value<String?>? outputContent,
    Value<String?>? thought,
    Value<String>? provider,
    Value<String?>? modelName,
    Value<int>? tokenConsumed,
    Value<DateTime>? createdAt,
  }) {
    return AiTasksCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      taskType: taskType ?? this.taskType,
      role: role ?? this.role,
      inputContent: inputContent ?? this.inputContent,
      inputImages: inputImages ?? this.inputImages,
      outputContent: outputContent ?? this.outputContent,
      thought: thought ?? this.thought,
      provider: provider ?? this.provider,
      modelName: modelName ?? this.modelName,
      tokenConsumed: tokenConsumed ?? this.tokenConsumed,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (taskType.present) {
      map['task_type'] = Variable<String>(taskType.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (inputContent.present) {
      map['input_content'] = Variable<String>(inputContent.value);
    }
    if (inputImages.present) {
      map['input_images'] = Variable<String>(inputImages.value);
    }
    if (outputContent.present) {
      map['output_content'] = Variable<String>(outputContent.value);
    }
    if (thought.present) {
      map['thought'] = Variable<String>(thought.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (modelName.present) {
      map['model_name'] = Variable<String>(modelName.value);
    }
    if (tokenConsumed.present) {
      map['token_consumed'] = Variable<int>(tokenConsumed.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiTasksCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('taskType: $taskType, ')
          ..write('role: $role, ')
          ..write('inputContent: $inputContent, ')
          ..write('inputImages: $inputImages, ')
          ..write('outputContent: $outputContent, ')
          ..write('thought: $thought, ')
          ..write('provider: $provider, ')
          ..write('modelName: $modelName, ')
          ..write('tokenConsumed: $tokenConsumed, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $AiConfigsTable extends AiConfigs
    with TableInfo<$AiConfigsTable, AiConfig> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiConfigsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _configKeyMeta = const VerificationMeta(
    'configKey',
  );
  @override
  late final GeneratedColumn<String> configKey = GeneratedColumn<String>(
    'config_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _systemPromptMeta = const VerificationMeta(
    'systemPrompt',
  );
  @override
  late final GeneratedColumn<String> systemPrompt = GeneratedColumn<String>(
    'system_prompt',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _temperatureMeta = const VerificationMeta(
    'temperature',
  );
  @override
  late final GeneratedColumn<double> temperature = GeneratedColumn<double>(
    'temperature',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.7),
  );
  static const VerificationMeta _memoMeta = const VerificationMeta('memo');
  @override
  late final GeneratedColumn<String> memo = GeneratedColumn<String>(
    'memo',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isSystemMeta = const VerificationMeta(
    'isSystem',
  );
  @override
  late final GeneratedColumn<bool> isSystem = GeneratedColumn<bool>(
    'is_system',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_system" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    configKey,
    systemPrompt,
    temperature,
    memo,
    isSystem,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_configs';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiConfig> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('config_key')) {
      context.handle(
        _configKeyMeta,
        configKey.isAcceptableOrUnknown(data['config_key']!, _configKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_configKeyMeta);
    }
    if (data.containsKey('system_prompt')) {
      context.handle(
        _systemPromptMeta,
        systemPrompt.isAcceptableOrUnknown(
          data['system_prompt']!,
          _systemPromptMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_systemPromptMeta);
    }
    if (data.containsKey('temperature')) {
      context.handle(
        _temperatureMeta,
        temperature.isAcceptableOrUnknown(
          data['temperature']!,
          _temperatureMeta,
        ),
      );
    }
    if (data.containsKey('memo')) {
      context.handle(
        _memoMeta,
        memo.isAcceptableOrUnknown(data['memo']!, _memoMeta),
      );
    }
    if (data.containsKey('is_system')) {
      context.handle(
        _isSystemMeta,
        isSystem.isAcceptableOrUnknown(data['is_system']!, _isSystemMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AiConfig map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiConfig(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      configKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}config_key'],
      )!,
      systemPrompt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}system_prompt'],
      )!,
      temperature: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}temperature'],
      )!,
      memo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}memo'],
      ),
      isSystem: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_system'],
      )!,
    );
  }

  @override
  $AiConfigsTable createAlias(String alias) {
    return $AiConfigsTable(attachedDatabase, alias);
  }
}

class AiConfig extends DataClass implements Insertable<AiConfig> {
  final int id;
  final String configKey;
  final String systemPrompt;
  final double temperature;
  final String? memo;
  final bool isSystem;
  const AiConfig({
    required this.id,
    required this.configKey,
    required this.systemPrompt,
    required this.temperature,
    this.memo,
    required this.isSystem,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['config_key'] = Variable<String>(configKey);
    map['system_prompt'] = Variable<String>(systemPrompt);
    map['temperature'] = Variable<double>(temperature);
    if (!nullToAbsent || memo != null) {
      map['memo'] = Variable<String>(memo);
    }
    map['is_system'] = Variable<bool>(isSystem);
    return map;
  }

  AiConfigsCompanion toCompanion(bool nullToAbsent) {
    return AiConfigsCompanion(
      id: Value(id),
      configKey: Value(configKey),
      systemPrompt: Value(systemPrompt),
      temperature: Value(temperature),
      memo: memo == null && nullToAbsent ? const Value.absent() : Value(memo),
      isSystem: Value(isSystem),
    );
  }

  factory AiConfig.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiConfig(
      id: serializer.fromJson<int>(json['id']),
      configKey: serializer.fromJson<String>(json['configKey']),
      systemPrompt: serializer.fromJson<String>(json['systemPrompt']),
      temperature: serializer.fromJson<double>(json['temperature']),
      memo: serializer.fromJson<String?>(json['memo']),
      isSystem: serializer.fromJson<bool>(json['isSystem']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'configKey': serializer.toJson<String>(configKey),
      'systemPrompt': serializer.toJson<String>(systemPrompt),
      'temperature': serializer.toJson<double>(temperature),
      'memo': serializer.toJson<String?>(memo),
      'isSystem': serializer.toJson<bool>(isSystem),
    };
  }

  AiConfig copyWith({
    int? id,
    String? configKey,
    String? systemPrompt,
    double? temperature,
    Value<String?> memo = const Value.absent(),
    bool? isSystem,
  }) => AiConfig(
    id: id ?? this.id,
    configKey: configKey ?? this.configKey,
    systemPrompt: systemPrompt ?? this.systemPrompt,
    temperature: temperature ?? this.temperature,
    memo: memo.present ? memo.value : this.memo,
    isSystem: isSystem ?? this.isSystem,
  );
  AiConfig copyWithCompanion(AiConfigsCompanion data) {
    return AiConfig(
      id: data.id.present ? data.id.value : this.id,
      configKey: data.configKey.present ? data.configKey.value : this.configKey,
      systemPrompt: data.systemPrompt.present
          ? data.systemPrompt.value
          : this.systemPrompt,
      temperature: data.temperature.present
          ? data.temperature.value
          : this.temperature,
      memo: data.memo.present ? data.memo.value : this.memo,
      isSystem: data.isSystem.present ? data.isSystem.value : this.isSystem,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiConfig(')
          ..write('id: $id, ')
          ..write('configKey: $configKey, ')
          ..write('systemPrompt: $systemPrompt, ')
          ..write('temperature: $temperature, ')
          ..write('memo: $memo, ')
          ..write('isSystem: $isSystem')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, configKey, systemPrompt, temperature, memo, isSystem);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiConfig &&
          other.id == this.id &&
          other.configKey == this.configKey &&
          other.systemPrompt == this.systemPrompt &&
          other.temperature == this.temperature &&
          other.memo == this.memo &&
          other.isSystem == this.isSystem);
}

class AiConfigsCompanion extends UpdateCompanion<AiConfig> {
  final Value<int> id;
  final Value<String> configKey;
  final Value<String> systemPrompt;
  final Value<double> temperature;
  final Value<String?> memo;
  final Value<bool> isSystem;
  const AiConfigsCompanion({
    this.id = const Value.absent(),
    this.configKey = const Value.absent(),
    this.systemPrompt = const Value.absent(),
    this.temperature = const Value.absent(),
    this.memo = const Value.absent(),
    this.isSystem = const Value.absent(),
  });
  AiConfigsCompanion.insert({
    this.id = const Value.absent(),
    required String configKey,
    required String systemPrompt,
    this.temperature = const Value.absent(),
    this.memo = const Value.absent(),
    this.isSystem = const Value.absent(),
  }) : configKey = Value(configKey),
       systemPrompt = Value(systemPrompt);
  static Insertable<AiConfig> custom({
    Expression<int>? id,
    Expression<String>? configKey,
    Expression<String>? systemPrompt,
    Expression<double>? temperature,
    Expression<String>? memo,
    Expression<bool>? isSystem,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (configKey != null) 'config_key': configKey,
      if (systemPrompt != null) 'system_prompt': systemPrompt,
      if (temperature != null) 'temperature': temperature,
      if (memo != null) 'memo': memo,
      if (isSystem != null) 'is_system': isSystem,
    });
  }

  AiConfigsCompanion copyWith({
    Value<int>? id,
    Value<String>? configKey,
    Value<String>? systemPrompt,
    Value<double>? temperature,
    Value<String?>? memo,
    Value<bool>? isSystem,
  }) {
    return AiConfigsCompanion(
      id: id ?? this.id,
      configKey: configKey ?? this.configKey,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      temperature: temperature ?? this.temperature,
      memo: memo ?? this.memo,
      isSystem: isSystem ?? this.isSystem,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (configKey.present) {
      map['config_key'] = Variable<String>(configKey.value);
    }
    if (systemPrompt.present) {
      map['system_prompt'] = Variable<String>(systemPrompt.value);
    }
    if (temperature.present) {
      map['temperature'] = Variable<double>(temperature.value);
    }
    if (memo.present) {
      map['memo'] = Variable<String>(memo.value);
    }
    if (isSystem.present) {
      map['is_system'] = Variable<bool>(isSystem.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiConfigsCompanion(')
          ..write('id: $id, ')
          ..write('configKey: $configKey, ')
          ..write('systemPrompt: $systemPrompt, ')
          ..write('temperature: $temperature, ')
          ..write('memo: $memo, ')
          ..write('isSystem: $isSystem')
          ..write(')'))
        .toString();
  }
}

class $AiModelsTable extends AiModels with TableInfo<$AiModelsTable, AiModel> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiModelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _modelIdMeta = const VerificationMeta(
    'modelId',
  );
  @override
  late final GeneratedColumn<String> modelId = GeneratedColumn<String>(
    'model_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
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
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelTypeMeta = const VerificationMeta(
    'modelType',
  );
  @override
  late final GeneratedColumn<String> modelType = GeneratedColumn<String>(
    'model_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('chat'),
  );
  static const VerificationMeta _inputModalityMeta = const VerificationMeta(
    'inputModality',
  );
  @override
  late final GeneratedColumn<String> inputModality = GeneratedColumn<String>(
    'input_modality',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('text'),
  );
  static const VerificationMeta _outputModalityMeta = const VerificationMeta(
    'outputModality',
  );
  @override
  late final GeneratedColumn<String> outputModality = GeneratedColumn<String>(
    'output_modality',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('text'),
  );
  static const VerificationMeta _supportsVisionMeta = const VerificationMeta(
    'supportsVision',
  );
  @override
  late final GeneratedColumn<bool> supportsVision = GeneratedColumn<bool>(
    'supports_vision',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("supports_vision" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _supportsToolsMeta = const VerificationMeta(
    'supportsTools',
  );
  @override
  late final GeneratedColumn<bool> supportsTools = GeneratedColumn<bool>(
    'supports_tools',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("supports_tools" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _supportsReasoningMeta = const VerificationMeta(
    'supportsReasoning',
  );
  @override
  late final GeneratedColumn<bool> supportsReasoning = GeneratedColumn<bool>(
    'supports_reasoning',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("supports_reasoning" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    modelId,
    provider,
    label,
    modelType,
    inputModality,
    outputModality,
    supportsVision,
    supportsTools,
    supportsReasoning,
    isActive,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_models';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiModel> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('model_id')) {
      context.handle(
        _modelIdMeta,
        modelId.isAcceptableOrUnknown(data['model_id']!, _modelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_modelIdMeta);
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('model_type')) {
      context.handle(
        _modelTypeMeta,
        modelType.isAcceptableOrUnknown(data['model_type']!, _modelTypeMeta),
      );
    }
    if (data.containsKey('input_modality')) {
      context.handle(
        _inputModalityMeta,
        inputModality.isAcceptableOrUnknown(
          data['input_modality']!,
          _inputModalityMeta,
        ),
      );
    }
    if (data.containsKey('output_modality')) {
      context.handle(
        _outputModalityMeta,
        outputModality.isAcceptableOrUnknown(
          data['output_modality']!,
          _outputModalityMeta,
        ),
      );
    }
    if (data.containsKey('supports_vision')) {
      context.handle(
        _supportsVisionMeta,
        supportsVision.isAcceptableOrUnknown(
          data['supports_vision']!,
          _supportsVisionMeta,
        ),
      );
    }
    if (data.containsKey('supports_tools')) {
      context.handle(
        _supportsToolsMeta,
        supportsTools.isAcceptableOrUnknown(
          data['supports_tools']!,
          _supportsToolsMeta,
        ),
      );
    }
    if (data.containsKey('supports_reasoning')) {
      context.handle(
        _supportsReasoningMeta,
        supportsReasoning.isAcceptableOrUnknown(
          data['supports_reasoning']!,
          _supportsReasoningMeta,
        ),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {provider, modelId};
  @override
  AiModel map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiModel(
      modelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_id'],
      )!,
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      modelType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_type'],
      )!,
      inputModality: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}input_modality'],
      )!,
      outputModality: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}output_modality'],
      )!,
      supportsVision: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}supports_vision'],
      )!,
      supportsTools: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}supports_tools'],
      )!,
      supportsReasoning: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}supports_reasoning'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
    );
  }

  @override
  $AiModelsTable createAlias(String alias) {
    return $AiModelsTable(attachedDatabase, alias);
  }
}

class AiModel extends DataClass implements Insertable<AiModel> {
  final String modelId;
  final String provider;
  final String label;

  /// 模型类型：chat / embedding / image / audio / rerank 等
  final String modelType;

  /// 输入模态（逗号分隔）：text,image,audio,video
  final String inputModality;

  /// 输出模态（逗号分隔）：text,image,audio
  final String outputModality;

  /// 是否支持多模态（图片理解）
  final bool supportsVision;

  /// 是否支持工具调用（function calling）
  final bool supportsTools;

  /// 是否支持推理（reasoning / thinking）
  final bool supportsReasoning;
  final bool isActive;
  const AiModel({
    required this.modelId,
    required this.provider,
    required this.label,
    required this.modelType,
    required this.inputModality,
    required this.outputModality,
    required this.supportsVision,
    required this.supportsTools,
    required this.supportsReasoning,
    required this.isActive,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['model_id'] = Variable<String>(modelId);
    map['provider'] = Variable<String>(provider);
    map['label'] = Variable<String>(label);
    map['model_type'] = Variable<String>(modelType);
    map['input_modality'] = Variable<String>(inputModality);
    map['output_modality'] = Variable<String>(outputModality);
    map['supports_vision'] = Variable<bool>(supportsVision);
    map['supports_tools'] = Variable<bool>(supportsTools);
    map['supports_reasoning'] = Variable<bool>(supportsReasoning);
    map['is_active'] = Variable<bool>(isActive);
    return map;
  }

  AiModelsCompanion toCompanion(bool nullToAbsent) {
    return AiModelsCompanion(
      modelId: Value(modelId),
      provider: Value(provider),
      label: Value(label),
      modelType: Value(modelType),
      inputModality: Value(inputModality),
      outputModality: Value(outputModality),
      supportsVision: Value(supportsVision),
      supportsTools: Value(supportsTools),
      supportsReasoning: Value(supportsReasoning),
      isActive: Value(isActive),
    );
  }

  factory AiModel.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiModel(
      modelId: serializer.fromJson<String>(json['modelId']),
      provider: serializer.fromJson<String>(json['provider']),
      label: serializer.fromJson<String>(json['label']),
      modelType: serializer.fromJson<String>(json['modelType']),
      inputModality: serializer.fromJson<String>(json['inputModality']),
      outputModality: serializer.fromJson<String>(json['outputModality']),
      supportsVision: serializer.fromJson<bool>(json['supportsVision']),
      supportsTools: serializer.fromJson<bool>(json['supportsTools']),
      supportsReasoning: serializer.fromJson<bool>(json['supportsReasoning']),
      isActive: serializer.fromJson<bool>(json['isActive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'modelId': serializer.toJson<String>(modelId),
      'provider': serializer.toJson<String>(provider),
      'label': serializer.toJson<String>(label),
      'modelType': serializer.toJson<String>(modelType),
      'inputModality': serializer.toJson<String>(inputModality),
      'outputModality': serializer.toJson<String>(outputModality),
      'supportsVision': serializer.toJson<bool>(supportsVision),
      'supportsTools': serializer.toJson<bool>(supportsTools),
      'supportsReasoning': serializer.toJson<bool>(supportsReasoning),
      'isActive': serializer.toJson<bool>(isActive),
    };
  }

  AiModel copyWith({
    String? modelId,
    String? provider,
    String? label,
    String? modelType,
    String? inputModality,
    String? outputModality,
    bool? supportsVision,
    bool? supportsTools,
    bool? supportsReasoning,
    bool? isActive,
  }) => AiModel(
    modelId: modelId ?? this.modelId,
    provider: provider ?? this.provider,
    label: label ?? this.label,
    modelType: modelType ?? this.modelType,
    inputModality: inputModality ?? this.inputModality,
    outputModality: outputModality ?? this.outputModality,
    supportsVision: supportsVision ?? this.supportsVision,
    supportsTools: supportsTools ?? this.supportsTools,
    supportsReasoning: supportsReasoning ?? this.supportsReasoning,
    isActive: isActive ?? this.isActive,
  );
  AiModel copyWithCompanion(AiModelsCompanion data) {
    return AiModel(
      modelId: data.modelId.present ? data.modelId.value : this.modelId,
      provider: data.provider.present ? data.provider.value : this.provider,
      label: data.label.present ? data.label.value : this.label,
      modelType: data.modelType.present ? data.modelType.value : this.modelType,
      inputModality: data.inputModality.present
          ? data.inputModality.value
          : this.inputModality,
      outputModality: data.outputModality.present
          ? data.outputModality.value
          : this.outputModality,
      supportsVision: data.supportsVision.present
          ? data.supportsVision.value
          : this.supportsVision,
      supportsTools: data.supportsTools.present
          ? data.supportsTools.value
          : this.supportsTools,
      supportsReasoning: data.supportsReasoning.present
          ? data.supportsReasoning.value
          : this.supportsReasoning,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiModel(')
          ..write('modelId: $modelId, ')
          ..write('provider: $provider, ')
          ..write('label: $label, ')
          ..write('modelType: $modelType, ')
          ..write('inputModality: $inputModality, ')
          ..write('outputModality: $outputModality, ')
          ..write('supportsVision: $supportsVision, ')
          ..write('supportsTools: $supportsTools, ')
          ..write('supportsReasoning: $supportsReasoning, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    modelId,
    provider,
    label,
    modelType,
    inputModality,
    outputModality,
    supportsVision,
    supportsTools,
    supportsReasoning,
    isActive,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiModel &&
          other.modelId == this.modelId &&
          other.provider == this.provider &&
          other.label == this.label &&
          other.modelType == this.modelType &&
          other.inputModality == this.inputModality &&
          other.outputModality == this.outputModality &&
          other.supportsVision == this.supportsVision &&
          other.supportsTools == this.supportsTools &&
          other.supportsReasoning == this.supportsReasoning &&
          other.isActive == this.isActive);
}

class AiModelsCompanion extends UpdateCompanion<AiModel> {
  final Value<String> modelId;
  final Value<String> provider;
  final Value<String> label;
  final Value<String> modelType;
  final Value<String> inputModality;
  final Value<String> outputModality;
  final Value<bool> supportsVision;
  final Value<bool> supportsTools;
  final Value<bool> supportsReasoning;
  final Value<bool> isActive;
  final Value<int> rowid;
  const AiModelsCompanion({
    this.modelId = const Value.absent(),
    this.provider = const Value.absent(),
    this.label = const Value.absent(),
    this.modelType = const Value.absent(),
    this.inputModality = const Value.absent(),
    this.outputModality = const Value.absent(),
    this.supportsVision = const Value.absent(),
    this.supportsTools = const Value.absent(),
    this.supportsReasoning = const Value.absent(),
    this.isActive = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AiModelsCompanion.insert({
    required String modelId,
    required String provider,
    required String label,
    this.modelType = const Value.absent(),
    this.inputModality = const Value.absent(),
    this.outputModality = const Value.absent(),
    this.supportsVision = const Value.absent(),
    this.supportsTools = const Value.absent(),
    this.supportsReasoning = const Value.absent(),
    this.isActive = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : modelId = Value(modelId),
       provider = Value(provider),
       label = Value(label);
  static Insertable<AiModel> custom({
    Expression<String>? modelId,
    Expression<String>? provider,
    Expression<String>? label,
    Expression<String>? modelType,
    Expression<String>? inputModality,
    Expression<String>? outputModality,
    Expression<bool>? supportsVision,
    Expression<bool>? supportsTools,
    Expression<bool>? supportsReasoning,
    Expression<bool>? isActive,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (modelId != null) 'model_id': modelId,
      if (provider != null) 'provider': provider,
      if (label != null) 'label': label,
      if (modelType != null) 'model_type': modelType,
      if (inputModality != null) 'input_modality': inputModality,
      if (outputModality != null) 'output_modality': outputModality,
      if (supportsVision != null) 'supports_vision': supportsVision,
      if (supportsTools != null) 'supports_tools': supportsTools,
      if (supportsReasoning != null) 'supports_reasoning': supportsReasoning,
      if (isActive != null) 'is_active': isActive,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AiModelsCompanion copyWith({
    Value<String>? modelId,
    Value<String>? provider,
    Value<String>? label,
    Value<String>? modelType,
    Value<String>? inputModality,
    Value<String>? outputModality,
    Value<bool>? supportsVision,
    Value<bool>? supportsTools,
    Value<bool>? supportsReasoning,
    Value<bool>? isActive,
    Value<int>? rowid,
  }) {
    return AiModelsCompanion(
      modelId: modelId ?? this.modelId,
      provider: provider ?? this.provider,
      label: label ?? this.label,
      modelType: modelType ?? this.modelType,
      inputModality: inputModality ?? this.inputModality,
      outputModality: outputModality ?? this.outputModality,
      supportsVision: supportsVision ?? this.supportsVision,
      supportsTools: supportsTools ?? this.supportsTools,
      supportsReasoning: supportsReasoning ?? this.supportsReasoning,
      isActive: isActive ?? this.isActive,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (modelId.present) {
      map['model_id'] = Variable<String>(modelId.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (modelType.present) {
      map['model_type'] = Variable<String>(modelType.value);
    }
    if (inputModality.present) {
      map['input_modality'] = Variable<String>(inputModality.value);
    }
    if (outputModality.present) {
      map['output_modality'] = Variable<String>(outputModality.value);
    }
    if (supportsVision.present) {
      map['supports_vision'] = Variable<bool>(supportsVision.value);
    }
    if (supportsTools.present) {
      map['supports_tools'] = Variable<bool>(supportsTools.value);
    }
    if (supportsReasoning.present) {
      map['supports_reasoning'] = Variable<bool>(supportsReasoning.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiModelsCompanion(')
          ..write('modelId: $modelId, ')
          ..write('provider: $provider, ')
          ..write('label: $label, ')
          ..write('modelType: $modelType, ')
          ..write('inputModality: $inputModality, ')
          ..write('outputModality: $outputModality, ')
          ..write('supportsVision: $supportsVision, ')
          ..write('supportsTools: $supportsTools, ')
          ..write('supportsReasoning: $supportsReasoning, ')
          ..write('isActive: $isActive, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AiProviderStatsTable extends AiProviderStats
    with TableInfo<$AiProviderStatsTable, AiProviderStat> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiProviderStatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isValidMeta = const VerificationMeta(
    'isValid',
  );
  @override
  late final GeneratedColumn<bool> isValid = GeneratedColumn<bool>(
    'is_valid',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_valid" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _lastCheckAtMeta = const VerificationMeta(
    'lastCheckAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastCheckAt = GeneratedColumn<DateTime>(
    'last_check_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalCallsMeta = const VerificationMeta(
    'totalCalls',
  );
  @override
  late final GeneratedColumn<int> totalCalls = GeneratedColumn<int>(
    'total_calls',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    provider,
    isValid,
    lastCheckAt,
    totalCalls,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_provider_stats';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiProviderStat> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('is_valid')) {
      context.handle(
        _isValidMeta,
        isValid.isAcceptableOrUnknown(data['is_valid']!, _isValidMeta),
      );
    }
    if (data.containsKey('last_check_at')) {
      context.handle(
        _lastCheckAtMeta,
        lastCheckAt.isAcceptableOrUnknown(
          data['last_check_at']!,
          _lastCheckAtMeta,
        ),
      );
    }
    if (data.containsKey('total_calls')) {
      context.handle(
        _totalCallsMeta,
        totalCalls.isAcceptableOrUnknown(data['total_calls']!, _totalCallsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {provider};
  @override
  AiProviderStat map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiProviderStat(
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      )!,
      isValid: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_valid'],
      )!,
      lastCheckAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_check_at'],
      ),
      totalCalls: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_calls'],
      )!,
    );
  }

  @override
  $AiProviderStatsTable createAlias(String alias) {
    return $AiProviderStatsTable(attachedDatabase, alias);
  }
}

class AiProviderStat extends DataClass implements Insertable<AiProviderStat> {
  final String provider;
  final bool isValid;
  final DateTime? lastCheckAt;
  final int totalCalls;
  const AiProviderStat({
    required this.provider,
    required this.isValid,
    this.lastCheckAt,
    required this.totalCalls,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['provider'] = Variable<String>(provider);
    map['is_valid'] = Variable<bool>(isValid);
    if (!nullToAbsent || lastCheckAt != null) {
      map['last_check_at'] = Variable<DateTime>(lastCheckAt);
    }
    map['total_calls'] = Variable<int>(totalCalls);
    return map;
  }

  AiProviderStatsCompanion toCompanion(bool nullToAbsent) {
    return AiProviderStatsCompanion(
      provider: Value(provider),
      isValid: Value(isValid),
      lastCheckAt: lastCheckAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastCheckAt),
      totalCalls: Value(totalCalls),
    );
  }

  factory AiProviderStat.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiProviderStat(
      provider: serializer.fromJson<String>(json['provider']),
      isValid: serializer.fromJson<bool>(json['isValid']),
      lastCheckAt: serializer.fromJson<DateTime?>(json['lastCheckAt']),
      totalCalls: serializer.fromJson<int>(json['totalCalls']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'provider': serializer.toJson<String>(provider),
      'isValid': serializer.toJson<bool>(isValid),
      'lastCheckAt': serializer.toJson<DateTime?>(lastCheckAt),
      'totalCalls': serializer.toJson<int>(totalCalls),
    };
  }

  AiProviderStat copyWith({
    String? provider,
    bool? isValid,
    Value<DateTime?> lastCheckAt = const Value.absent(),
    int? totalCalls,
  }) => AiProviderStat(
    provider: provider ?? this.provider,
    isValid: isValid ?? this.isValid,
    lastCheckAt: lastCheckAt.present ? lastCheckAt.value : this.lastCheckAt,
    totalCalls: totalCalls ?? this.totalCalls,
  );
  AiProviderStat copyWithCompanion(AiProviderStatsCompanion data) {
    return AiProviderStat(
      provider: data.provider.present ? data.provider.value : this.provider,
      isValid: data.isValid.present ? data.isValid.value : this.isValid,
      lastCheckAt: data.lastCheckAt.present
          ? data.lastCheckAt.value
          : this.lastCheckAt,
      totalCalls: data.totalCalls.present
          ? data.totalCalls.value
          : this.totalCalls,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiProviderStat(')
          ..write('provider: $provider, ')
          ..write('isValid: $isValid, ')
          ..write('lastCheckAt: $lastCheckAt, ')
          ..write('totalCalls: $totalCalls')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(provider, isValid, lastCheckAt, totalCalls);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiProviderStat &&
          other.provider == this.provider &&
          other.isValid == this.isValid &&
          other.lastCheckAt == this.lastCheckAt &&
          other.totalCalls == this.totalCalls);
}

class AiProviderStatsCompanion extends UpdateCompanion<AiProviderStat> {
  final Value<String> provider;
  final Value<bool> isValid;
  final Value<DateTime?> lastCheckAt;
  final Value<int> totalCalls;
  final Value<int> rowid;
  const AiProviderStatsCompanion({
    this.provider = const Value.absent(),
    this.isValid = const Value.absent(),
    this.lastCheckAt = const Value.absent(),
    this.totalCalls = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AiProviderStatsCompanion.insert({
    required String provider,
    this.isValid = const Value.absent(),
    this.lastCheckAt = const Value.absent(),
    this.totalCalls = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : provider = Value(provider);
  static Insertable<AiProviderStat> custom({
    Expression<String>? provider,
    Expression<bool>? isValid,
    Expression<DateTime>? lastCheckAt,
    Expression<int>? totalCalls,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (provider != null) 'provider': provider,
      if (isValid != null) 'is_valid': isValid,
      if (lastCheckAt != null) 'last_check_at': lastCheckAt,
      if (totalCalls != null) 'total_calls': totalCalls,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AiProviderStatsCompanion copyWith({
    Value<String>? provider,
    Value<bool>? isValid,
    Value<DateTime?>? lastCheckAt,
    Value<int>? totalCalls,
    Value<int>? rowid,
  }) {
    return AiProviderStatsCompanion(
      provider: provider ?? this.provider,
      isValid: isValid ?? this.isValid,
      lastCheckAt: lastCheckAt ?? this.lastCheckAt,
      totalCalls: totalCalls ?? this.totalCalls,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (isValid.present) {
      map['is_valid'] = Variable<bool>(isValid.value);
    }
    if (lastCheckAt.present) {
      map['last_check_at'] = Variable<DateTime>(lastCheckAt.value);
    }
    if (totalCalls.present) {
      map['total_calls'] = Variable<int>(totalCalls.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiProviderStatsCompanion(')
          ..write('provider: $provider, ')
          ..write('isValid: $isValid, ')
          ..write('lastCheckAt: $lastCheckAt, ')
          ..write('totalCalls: $totalCalls, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AiCustomProvidersTable extends AiCustomProviders
    with TableInfo<$AiCustomProvidersTable, AiCustomProvider> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiCustomProvidersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
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
  static const VerificationMeta _baseUrlMeta = const VerificationMeta(
    'baseUrl',
  );
  @override
  late final GeneratedColumn<String> baseUrl = GeneratedColumn<String>(
    'base_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _defaultModelMeta = const VerificationMeta(
    'defaultModel',
  );
  @override
  late final GeneratedColumn<String> defaultModel = GeneratedColumn<String>(
    'default_model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _apiKeyMeta = const VerificationMeta('apiKey');
  @override
  late final GeneratedColumn<String> apiKey = GeneratedColumn<String>(
    'api_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _apiFormatMeta = const VerificationMeta(
    'apiFormat',
  );
  @override
  late final GeneratedColumn<String> apiFormat = GeneratedColumn<String>(
    'api_format',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modelsUrlMeta = const VerificationMeta(
    'modelsUrl',
  );
  @override
  late final GeneratedColumn<String> modelsUrl = GeneratedColumn<String>(
    'models_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isEnabledMeta = const VerificationMeta(
    'isEnabled',
  );
  @override
  late final GeneratedColumn<bool> isEnabled = GeneratedColumn<bool>(
    'is_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _balanceUrlMeta = const VerificationMeta(
    'balanceUrl',
  );
  @override
  late final GeneratedColumn<String> balanceUrl = GeneratedColumn<String>(
    'balance_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _balanceKeyMeta = const VerificationMeta(
    'balanceKey',
  );
  @override
  late final GeneratedColumn<String> balanceKey = GeneratedColumn<String>(
    'balance_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    provider,
    name,
    baseUrl,
    defaultModel,
    apiKey,
    apiFormat,
    modelsUrl,
    isEnabled,
    balanceUrl,
    balanceKey,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_custom_providers';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiCustomProvider> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('base_url')) {
      context.handle(
        _baseUrlMeta,
        baseUrl.isAcceptableOrUnknown(data['base_url']!, _baseUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_baseUrlMeta);
    }
    if (data.containsKey('default_model')) {
      context.handle(
        _defaultModelMeta,
        defaultModel.isAcceptableOrUnknown(
          data['default_model']!,
          _defaultModelMeta,
        ),
      );
    }
    if (data.containsKey('api_key')) {
      context.handle(
        _apiKeyMeta,
        apiKey.isAcceptableOrUnknown(data['api_key']!, _apiKeyMeta),
      );
    }
    if (data.containsKey('api_format')) {
      context.handle(
        _apiFormatMeta,
        apiFormat.isAcceptableOrUnknown(data['api_format']!, _apiFormatMeta),
      );
    }
    if (data.containsKey('models_url')) {
      context.handle(
        _modelsUrlMeta,
        modelsUrl.isAcceptableOrUnknown(data['models_url']!, _modelsUrlMeta),
      );
    }
    if (data.containsKey('is_enabled')) {
      context.handle(
        _isEnabledMeta,
        isEnabled.isAcceptableOrUnknown(data['is_enabled']!, _isEnabledMeta),
      );
    }
    if (data.containsKey('balance_url')) {
      context.handle(
        _balanceUrlMeta,
        balanceUrl.isAcceptableOrUnknown(data['balance_url']!, _balanceUrlMeta),
      );
    }
    if (data.containsKey('balance_key')) {
      context.handle(
        _balanceKeyMeta,
        balanceKey.isAcceptableOrUnknown(data['balance_key']!, _balanceKeyMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {provider};
  @override
  AiCustomProvider map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiCustomProvider(
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      baseUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_url'],
      )!,
      defaultModel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_model'],
      ),
      apiKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}api_key'],
      ),
      apiFormat: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}api_format'],
      ),
      modelsUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}models_url'],
      ),
      isEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_enabled'],
      )!,
      balanceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}balance_url'],
      ),
      balanceKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}balance_key'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AiCustomProvidersTable createAlias(String alias) {
    return $AiCustomProvidersTable(attachedDatabase, alias);
  }
}

class AiCustomProvider extends DataClass
    implements Insertable<AiCustomProvider> {
  /// 唯一 key，如 custom_xxx
  final String provider;

  /// 展示名称
  final String name;
  final String baseUrl;
  final String? defaultModel;
  final String? apiKey;

  /// 接口格式：openai | openai_responses | gemini | claude；null 视为 openai
  final String? apiFormat;

  /// 自定义的"查询可用模型"接口地址；为空使用内置默认
  final String? modelsUrl;
  final bool isEnabled;

  /// 余额查询 URL（可自定义；为空表示使用内置默认查询）
  final String? balanceUrl;

  /// 余额结果 JSON key path（点号分隔，如 `data.balance`）
  final String? balanceKey;
  final DateTime createdAt;
  final DateTime updatedAt;
  const AiCustomProvider({
    required this.provider,
    required this.name,
    required this.baseUrl,
    this.defaultModel,
    this.apiKey,
    this.apiFormat,
    this.modelsUrl,
    required this.isEnabled,
    this.balanceUrl,
    this.balanceKey,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['provider'] = Variable<String>(provider);
    map['name'] = Variable<String>(name);
    map['base_url'] = Variable<String>(baseUrl);
    if (!nullToAbsent || defaultModel != null) {
      map['default_model'] = Variable<String>(defaultModel);
    }
    if (!nullToAbsent || apiKey != null) {
      map['api_key'] = Variable<String>(apiKey);
    }
    if (!nullToAbsent || apiFormat != null) {
      map['api_format'] = Variable<String>(apiFormat);
    }
    if (!nullToAbsent || modelsUrl != null) {
      map['models_url'] = Variable<String>(modelsUrl);
    }
    map['is_enabled'] = Variable<bool>(isEnabled);
    if (!nullToAbsent || balanceUrl != null) {
      map['balance_url'] = Variable<String>(balanceUrl);
    }
    if (!nullToAbsent || balanceKey != null) {
      map['balance_key'] = Variable<String>(balanceKey);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AiCustomProvidersCompanion toCompanion(bool nullToAbsent) {
    return AiCustomProvidersCompanion(
      provider: Value(provider),
      name: Value(name),
      baseUrl: Value(baseUrl),
      defaultModel: defaultModel == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultModel),
      apiKey: apiKey == null && nullToAbsent
          ? const Value.absent()
          : Value(apiKey),
      apiFormat: apiFormat == null && nullToAbsent
          ? const Value.absent()
          : Value(apiFormat),
      modelsUrl: modelsUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(modelsUrl),
      isEnabled: Value(isEnabled),
      balanceUrl: balanceUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(balanceUrl),
      balanceKey: balanceKey == null && nullToAbsent
          ? const Value.absent()
          : Value(balanceKey),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory AiCustomProvider.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiCustomProvider(
      provider: serializer.fromJson<String>(json['provider']),
      name: serializer.fromJson<String>(json['name']),
      baseUrl: serializer.fromJson<String>(json['baseUrl']),
      defaultModel: serializer.fromJson<String?>(json['defaultModel']),
      apiKey: serializer.fromJson<String?>(json['apiKey']),
      apiFormat: serializer.fromJson<String?>(json['apiFormat']),
      modelsUrl: serializer.fromJson<String?>(json['modelsUrl']),
      isEnabled: serializer.fromJson<bool>(json['isEnabled']),
      balanceUrl: serializer.fromJson<String?>(json['balanceUrl']),
      balanceKey: serializer.fromJson<String?>(json['balanceKey']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'provider': serializer.toJson<String>(provider),
      'name': serializer.toJson<String>(name),
      'baseUrl': serializer.toJson<String>(baseUrl),
      'defaultModel': serializer.toJson<String?>(defaultModel),
      'apiKey': serializer.toJson<String?>(apiKey),
      'apiFormat': serializer.toJson<String?>(apiFormat),
      'modelsUrl': serializer.toJson<String?>(modelsUrl),
      'isEnabled': serializer.toJson<bool>(isEnabled),
      'balanceUrl': serializer.toJson<String?>(balanceUrl),
      'balanceKey': serializer.toJson<String?>(balanceKey),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AiCustomProvider copyWith({
    String? provider,
    String? name,
    String? baseUrl,
    Value<String?> defaultModel = const Value.absent(),
    Value<String?> apiKey = const Value.absent(),
    Value<String?> apiFormat = const Value.absent(),
    Value<String?> modelsUrl = const Value.absent(),
    bool? isEnabled,
    Value<String?> balanceUrl = const Value.absent(),
    Value<String?> balanceKey = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => AiCustomProvider(
    provider: provider ?? this.provider,
    name: name ?? this.name,
    baseUrl: baseUrl ?? this.baseUrl,
    defaultModel: defaultModel.present ? defaultModel.value : this.defaultModel,
    apiKey: apiKey.present ? apiKey.value : this.apiKey,
    apiFormat: apiFormat.present ? apiFormat.value : this.apiFormat,
    modelsUrl: modelsUrl.present ? modelsUrl.value : this.modelsUrl,
    isEnabled: isEnabled ?? this.isEnabled,
    balanceUrl: balanceUrl.present ? balanceUrl.value : this.balanceUrl,
    balanceKey: balanceKey.present ? balanceKey.value : this.balanceKey,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AiCustomProvider copyWithCompanion(AiCustomProvidersCompanion data) {
    return AiCustomProvider(
      provider: data.provider.present ? data.provider.value : this.provider,
      name: data.name.present ? data.name.value : this.name,
      baseUrl: data.baseUrl.present ? data.baseUrl.value : this.baseUrl,
      defaultModel: data.defaultModel.present
          ? data.defaultModel.value
          : this.defaultModel,
      apiKey: data.apiKey.present ? data.apiKey.value : this.apiKey,
      apiFormat: data.apiFormat.present ? data.apiFormat.value : this.apiFormat,
      modelsUrl: data.modelsUrl.present ? data.modelsUrl.value : this.modelsUrl,
      isEnabled: data.isEnabled.present ? data.isEnabled.value : this.isEnabled,
      balanceUrl: data.balanceUrl.present
          ? data.balanceUrl.value
          : this.balanceUrl,
      balanceKey: data.balanceKey.present
          ? data.balanceKey.value
          : this.balanceKey,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiCustomProvider(')
          ..write('provider: $provider, ')
          ..write('name: $name, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('defaultModel: $defaultModel, ')
          ..write('apiKey: $apiKey, ')
          ..write('apiFormat: $apiFormat, ')
          ..write('modelsUrl: $modelsUrl, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('balanceUrl: $balanceUrl, ')
          ..write('balanceKey: $balanceKey, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    provider,
    name,
    baseUrl,
    defaultModel,
    apiKey,
    apiFormat,
    modelsUrl,
    isEnabled,
    balanceUrl,
    balanceKey,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiCustomProvider &&
          other.provider == this.provider &&
          other.name == this.name &&
          other.baseUrl == this.baseUrl &&
          other.defaultModel == this.defaultModel &&
          other.apiKey == this.apiKey &&
          other.apiFormat == this.apiFormat &&
          other.modelsUrl == this.modelsUrl &&
          other.isEnabled == this.isEnabled &&
          other.balanceUrl == this.balanceUrl &&
          other.balanceKey == this.balanceKey &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AiCustomProvidersCompanion extends UpdateCompanion<AiCustomProvider> {
  final Value<String> provider;
  final Value<String> name;
  final Value<String> baseUrl;
  final Value<String?> defaultModel;
  final Value<String?> apiKey;
  final Value<String?> apiFormat;
  final Value<String?> modelsUrl;
  final Value<bool> isEnabled;
  final Value<String?> balanceUrl;
  final Value<String?> balanceKey;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AiCustomProvidersCompanion({
    this.provider = const Value.absent(),
    this.name = const Value.absent(),
    this.baseUrl = const Value.absent(),
    this.defaultModel = const Value.absent(),
    this.apiKey = const Value.absent(),
    this.apiFormat = const Value.absent(),
    this.modelsUrl = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.balanceUrl = const Value.absent(),
    this.balanceKey = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AiCustomProvidersCompanion.insert({
    required String provider,
    required String name,
    required String baseUrl,
    this.defaultModel = const Value.absent(),
    this.apiKey = const Value.absent(),
    this.apiFormat = const Value.absent(),
    this.modelsUrl = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.balanceUrl = const Value.absent(),
    this.balanceKey = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : provider = Value(provider),
       name = Value(name),
       baseUrl = Value(baseUrl);
  static Insertable<AiCustomProvider> custom({
    Expression<String>? provider,
    Expression<String>? name,
    Expression<String>? baseUrl,
    Expression<String>? defaultModel,
    Expression<String>? apiKey,
    Expression<String>? apiFormat,
    Expression<String>? modelsUrl,
    Expression<bool>? isEnabled,
    Expression<String>? balanceUrl,
    Expression<String>? balanceKey,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (provider != null) 'provider': provider,
      if (name != null) 'name': name,
      if (baseUrl != null) 'base_url': baseUrl,
      if (defaultModel != null) 'default_model': defaultModel,
      if (apiKey != null) 'api_key': apiKey,
      if (apiFormat != null) 'api_format': apiFormat,
      if (modelsUrl != null) 'models_url': modelsUrl,
      if (isEnabled != null) 'is_enabled': isEnabled,
      if (balanceUrl != null) 'balance_url': balanceUrl,
      if (balanceKey != null) 'balance_key': balanceKey,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AiCustomProvidersCompanion copyWith({
    Value<String>? provider,
    Value<String>? name,
    Value<String>? baseUrl,
    Value<String?>? defaultModel,
    Value<String?>? apiKey,
    Value<String?>? apiFormat,
    Value<String?>? modelsUrl,
    Value<bool>? isEnabled,
    Value<String?>? balanceUrl,
    Value<String?>? balanceKey,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return AiCustomProvidersCompanion(
      provider: provider ?? this.provider,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      defaultModel: defaultModel ?? this.defaultModel,
      apiKey: apiKey ?? this.apiKey,
      apiFormat: apiFormat ?? this.apiFormat,
      modelsUrl: modelsUrl ?? this.modelsUrl,
      isEnabled: isEnabled ?? this.isEnabled,
      balanceUrl: balanceUrl ?? this.balanceUrl,
      balanceKey: balanceKey ?? this.balanceKey,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (baseUrl.present) {
      map['base_url'] = Variable<String>(baseUrl.value);
    }
    if (defaultModel.present) {
      map['default_model'] = Variable<String>(defaultModel.value);
    }
    if (apiKey.present) {
      map['api_key'] = Variable<String>(apiKey.value);
    }
    if (apiFormat.present) {
      map['api_format'] = Variable<String>(apiFormat.value);
    }
    if (modelsUrl.present) {
      map['models_url'] = Variable<String>(modelsUrl.value);
    }
    if (isEnabled.present) {
      map['is_enabled'] = Variable<bool>(isEnabled.value);
    }
    if (balanceUrl.present) {
      map['balance_url'] = Variable<String>(balanceUrl.value);
    }
    if (balanceKey.present) {
      map['balance_key'] = Variable<String>(balanceKey.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiCustomProvidersCompanion(')
          ..write('provider: $provider, ')
          ..write('name: $name, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('defaultModel: $defaultModel, ')
          ..write('apiKey: $apiKey, ')
          ..write('apiFormat: $apiFormat, ')
          ..write('modelsUrl: $modelsUrl, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('balanceUrl: $balanceUrl, ')
          ..write('balanceKey: $balanceKey, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AiSkillsTable extends AiSkills with TableInfo<$AiSkillsTable, AiSkill> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiSkillsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
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
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _systemPromptMeta = const VerificationMeta(
    'systemPrompt',
  );
  @override
  late final GeneratedColumn<String> systemPrompt = GeneratedColumn<String>(
    'system_prompt',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isBuiltinMeta = const VerificationMeta(
    'isBuiltin',
  );
  @override
  late final GeneratedColumn<bool> isBuiltin = GeneratedColumn<bool>(
    'is_builtin',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_builtin" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isEnabledMeta = const VerificationMeta(
    'isEnabled',
  );
  @override
  late final GeneratedColumn<bool> isEnabled = GeneratedColumn<bool>(
    'is_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    key,
    name,
    description,
    systemPrompt,
    isBuiltin,
    isEnabled,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_skills';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiSkill> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('system_prompt')) {
      context.handle(
        _systemPromptMeta,
        systemPrompt.isAcceptableOrUnknown(
          data['system_prompt']!,
          _systemPromptMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_systemPromptMeta);
    }
    if (data.containsKey('is_builtin')) {
      context.handle(
        _isBuiltinMeta,
        isBuiltin.isAcceptableOrUnknown(data['is_builtin']!, _isBuiltinMeta),
      );
    }
    if (data.containsKey('is_enabled')) {
      context.handle(
        _isEnabledMeta,
        isEnabled.isAcceptableOrUnknown(data['is_enabled']!, _isEnabledMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AiSkill map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiSkill(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      systemPrompt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}system_prompt'],
      )!,
      isBuiltin: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_builtin'],
      )!,
      isEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_enabled'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AiSkillsTable createAlias(String alias) {
    return $AiSkillsTable(attachedDatabase, alias);
  }
}

class AiSkill extends DataClass implements Insertable<AiSkill> {
  final int id;
  final String key;
  final String name;
  final String? description;
  final String systemPrompt;
  final bool isBuiltin;
  final bool isEnabled;
  final DateTime createdAt;
  const AiSkill({
    required this.id,
    required this.key,
    required this.name,
    this.description,
    required this.systemPrompt,
    required this.isBuiltin,
    required this.isEnabled,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['key'] = Variable<String>(key);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['system_prompt'] = Variable<String>(systemPrompt);
    map['is_builtin'] = Variable<bool>(isBuiltin);
    map['is_enabled'] = Variable<bool>(isEnabled);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AiSkillsCompanion toCompanion(bool nullToAbsent) {
    return AiSkillsCompanion(
      id: Value(id),
      key: Value(key),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      systemPrompt: Value(systemPrompt),
      isBuiltin: Value(isBuiltin),
      isEnabled: Value(isEnabled),
      createdAt: Value(createdAt),
    );
  }

  factory AiSkill.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiSkill(
      id: serializer.fromJson<int>(json['id']),
      key: serializer.fromJson<String>(json['key']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      systemPrompt: serializer.fromJson<String>(json['systemPrompt']),
      isBuiltin: serializer.fromJson<bool>(json['isBuiltin']),
      isEnabled: serializer.fromJson<bool>(json['isEnabled']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'key': serializer.toJson<String>(key),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'systemPrompt': serializer.toJson<String>(systemPrompt),
      'isBuiltin': serializer.toJson<bool>(isBuiltin),
      'isEnabled': serializer.toJson<bool>(isEnabled),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  AiSkill copyWith({
    int? id,
    String? key,
    String? name,
    Value<String?> description = const Value.absent(),
    String? systemPrompt,
    bool? isBuiltin,
    bool? isEnabled,
    DateTime? createdAt,
  }) => AiSkill(
    id: id ?? this.id,
    key: key ?? this.key,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    systemPrompt: systemPrompt ?? this.systemPrompt,
    isBuiltin: isBuiltin ?? this.isBuiltin,
    isEnabled: isEnabled ?? this.isEnabled,
    createdAt: createdAt ?? this.createdAt,
  );
  AiSkill copyWithCompanion(AiSkillsCompanion data) {
    return AiSkill(
      id: data.id.present ? data.id.value : this.id,
      key: data.key.present ? data.key.value : this.key,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      systemPrompt: data.systemPrompt.present
          ? data.systemPrompt.value
          : this.systemPrompt,
      isBuiltin: data.isBuiltin.present ? data.isBuiltin.value : this.isBuiltin,
      isEnabled: data.isEnabled.present ? data.isEnabled.value : this.isEnabled,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiSkill(')
          ..write('id: $id, ')
          ..write('key: $key, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('systemPrompt: $systemPrompt, ')
          ..write('isBuiltin: $isBuiltin, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    key,
    name,
    description,
    systemPrompt,
    isBuiltin,
    isEnabled,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiSkill &&
          other.id == this.id &&
          other.key == this.key &&
          other.name == this.name &&
          other.description == this.description &&
          other.systemPrompt == this.systemPrompt &&
          other.isBuiltin == this.isBuiltin &&
          other.isEnabled == this.isEnabled &&
          other.createdAt == this.createdAt);
}

class AiSkillsCompanion extends UpdateCompanion<AiSkill> {
  final Value<int> id;
  final Value<String> key;
  final Value<String> name;
  final Value<String?> description;
  final Value<String> systemPrompt;
  final Value<bool> isBuiltin;
  final Value<bool> isEnabled;
  final Value<DateTime> createdAt;
  const AiSkillsCompanion({
    this.id = const Value.absent(),
    this.key = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.systemPrompt = const Value.absent(),
    this.isBuiltin = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  AiSkillsCompanion.insert({
    this.id = const Value.absent(),
    required String key,
    required String name,
    this.description = const Value.absent(),
    required String systemPrompt,
    this.isBuiltin = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : key = Value(key),
       name = Value(name),
       systemPrompt = Value(systemPrompt);
  static Insertable<AiSkill> custom({
    Expression<int>? id,
    Expression<String>? key,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? systemPrompt,
    Expression<bool>? isBuiltin,
    Expression<bool>? isEnabled,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (key != null) 'key': key,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (systemPrompt != null) 'system_prompt': systemPrompt,
      if (isBuiltin != null) 'is_builtin': isBuiltin,
      if (isEnabled != null) 'is_enabled': isEnabled,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  AiSkillsCompanion copyWith({
    Value<int>? id,
    Value<String>? key,
    Value<String>? name,
    Value<String?>? description,
    Value<String>? systemPrompt,
    Value<bool>? isBuiltin,
    Value<bool>? isEnabled,
    Value<DateTime>? createdAt,
  }) {
    return AiSkillsCompanion(
      id: id ?? this.id,
      key: key ?? this.key,
      name: name ?? this.name,
      description: description ?? this.description,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      isBuiltin: isBuiltin ?? this.isBuiltin,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (systemPrompt.present) {
      map['system_prompt'] = Variable<String>(systemPrompt.value);
    }
    if (isBuiltin.present) {
      map['is_builtin'] = Variable<bool>(isBuiltin.value);
    }
    if (isEnabled.present) {
      map['is_enabled'] = Variable<bool>(isEnabled.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiSkillsCompanion(')
          ..write('id: $id, ')
          ..write('key: $key, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('systemPrompt: $systemPrompt, ')
          ..write('isBuiltin: $isBuiltin, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $AiMcpServersTable extends AiMcpServers
    with TableInfo<$AiMcpServersTable, AiMcpServer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiMcpServersTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _transportMeta = const VerificationMeta(
    'transport',
  );
  @override
  late final GeneratedColumn<String> transport = GeneratedColumn<String>(
    'transport',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('http'),
  );
  static const VerificationMeta _commandMeta = const VerificationMeta(
    'command',
  );
  @override
  late final GeneratedColumn<String> command = GeneratedColumn<String>(
    'command',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _argsMeta = const VerificationMeta('args');
  @override
  late final GeneratedColumn<String> args = GeneratedColumn<String>(
    'args',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _envMeta = const VerificationMeta('env');
  @override
  late final GeneratedColumn<String> env = GeneratedColumn<String>(
    'env',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _headersMeta = const VerificationMeta(
    'headers',
  );
  @override
  late final GeneratedColumn<String> headers = GeneratedColumn<String>(
    'headers',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isEnabledMeta = const VerificationMeta(
    'isEnabled',
  );
  @override
  late final GeneratedColumn<bool> isEnabled = GeneratedColumn<bool>(
    'is_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    transport,
    command,
    args,
    env,
    url,
    headers,
    isEnabled,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_mcp_servers';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiMcpServer> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('transport')) {
      context.handle(
        _transportMeta,
        transport.isAcceptableOrUnknown(data['transport']!, _transportMeta),
      );
    }
    if (data.containsKey('command')) {
      context.handle(
        _commandMeta,
        command.isAcceptableOrUnknown(data['command']!, _commandMeta),
      );
    }
    if (data.containsKey('args')) {
      context.handle(
        _argsMeta,
        args.isAcceptableOrUnknown(data['args']!, _argsMeta),
      );
    }
    if (data.containsKey('env')) {
      context.handle(
        _envMeta,
        env.isAcceptableOrUnknown(data['env']!, _envMeta),
      );
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    }
    if (data.containsKey('headers')) {
      context.handle(
        _headersMeta,
        headers.isAcceptableOrUnknown(data['headers']!, _headersMeta),
      );
    }
    if (data.containsKey('is_enabled')) {
      context.handle(
        _isEnabledMeta,
        isEnabled.isAcceptableOrUnknown(data['is_enabled']!, _isEnabledMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AiMcpServer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiMcpServer(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      transport: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transport'],
      )!,
      command: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}command'],
      ),
      args: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}args'],
      ),
      env: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}env'],
      ),
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      ),
      headers: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}headers'],
      ),
      isEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_enabled'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AiMcpServersTable createAlias(String alias) {
    return $AiMcpServersTable(attachedDatabase, alias);
  }
}

class AiMcpServer extends DataClass implements Insertable<AiMcpServer> {
  final int id;
  final String name;

  /// 'stdio' | 'http' | 'sse'
  final String transport;

  /// stdio: 可执行文件
  final String? command;

  /// stdio: JSON 数组参数
  final String? args;

  /// stdio: 环境变量 JSON
  final String? env;

  /// http/sse: 端点地址
  final String? url;

  /// http/sse: JSON 对象 headers
  final String? headers;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  const AiMcpServer({
    required this.id,
    required this.name,
    required this.transport,
    this.command,
    this.args,
    this.env,
    this.url,
    this.headers,
    required this.isEnabled,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['transport'] = Variable<String>(transport);
    if (!nullToAbsent || command != null) {
      map['command'] = Variable<String>(command);
    }
    if (!nullToAbsent || args != null) {
      map['args'] = Variable<String>(args);
    }
    if (!nullToAbsent || env != null) {
      map['env'] = Variable<String>(env);
    }
    if (!nullToAbsent || url != null) {
      map['url'] = Variable<String>(url);
    }
    if (!nullToAbsent || headers != null) {
      map['headers'] = Variable<String>(headers);
    }
    map['is_enabled'] = Variable<bool>(isEnabled);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AiMcpServersCompanion toCompanion(bool nullToAbsent) {
    return AiMcpServersCompanion(
      id: Value(id),
      name: Value(name),
      transport: Value(transport),
      command: command == null && nullToAbsent
          ? const Value.absent()
          : Value(command),
      args: args == null && nullToAbsent ? const Value.absent() : Value(args),
      env: env == null && nullToAbsent ? const Value.absent() : Value(env),
      url: url == null && nullToAbsent ? const Value.absent() : Value(url),
      headers: headers == null && nullToAbsent
          ? const Value.absent()
          : Value(headers),
      isEnabled: Value(isEnabled),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory AiMcpServer.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiMcpServer(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      transport: serializer.fromJson<String>(json['transport']),
      command: serializer.fromJson<String?>(json['command']),
      args: serializer.fromJson<String?>(json['args']),
      env: serializer.fromJson<String?>(json['env']),
      url: serializer.fromJson<String?>(json['url']),
      headers: serializer.fromJson<String?>(json['headers']),
      isEnabled: serializer.fromJson<bool>(json['isEnabled']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'transport': serializer.toJson<String>(transport),
      'command': serializer.toJson<String?>(command),
      'args': serializer.toJson<String?>(args),
      'env': serializer.toJson<String?>(env),
      'url': serializer.toJson<String?>(url),
      'headers': serializer.toJson<String?>(headers),
      'isEnabled': serializer.toJson<bool>(isEnabled),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AiMcpServer copyWith({
    int? id,
    String? name,
    String? transport,
    Value<String?> command = const Value.absent(),
    Value<String?> args = const Value.absent(),
    Value<String?> env = const Value.absent(),
    Value<String?> url = const Value.absent(),
    Value<String?> headers = const Value.absent(),
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => AiMcpServer(
    id: id ?? this.id,
    name: name ?? this.name,
    transport: transport ?? this.transport,
    command: command.present ? command.value : this.command,
    args: args.present ? args.value : this.args,
    env: env.present ? env.value : this.env,
    url: url.present ? url.value : this.url,
    headers: headers.present ? headers.value : this.headers,
    isEnabled: isEnabled ?? this.isEnabled,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AiMcpServer copyWithCompanion(AiMcpServersCompanion data) {
    return AiMcpServer(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      transport: data.transport.present ? data.transport.value : this.transport,
      command: data.command.present ? data.command.value : this.command,
      args: data.args.present ? data.args.value : this.args,
      env: data.env.present ? data.env.value : this.env,
      url: data.url.present ? data.url.value : this.url,
      headers: data.headers.present ? data.headers.value : this.headers,
      isEnabled: data.isEnabled.present ? data.isEnabled.value : this.isEnabled,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiMcpServer(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('transport: $transport, ')
          ..write('command: $command, ')
          ..write('args: $args, ')
          ..write('env: $env, ')
          ..write('url: $url, ')
          ..write('headers: $headers, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    transport,
    command,
    args,
    env,
    url,
    headers,
    isEnabled,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiMcpServer &&
          other.id == this.id &&
          other.name == this.name &&
          other.transport == this.transport &&
          other.command == this.command &&
          other.args == this.args &&
          other.env == this.env &&
          other.url == this.url &&
          other.headers == this.headers &&
          other.isEnabled == this.isEnabled &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AiMcpServersCompanion extends UpdateCompanion<AiMcpServer> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> transport;
  final Value<String?> command;
  final Value<String?> args;
  final Value<String?> env;
  final Value<String?> url;
  final Value<String?> headers;
  final Value<bool> isEnabled;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const AiMcpServersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.transport = const Value.absent(),
    this.command = const Value.absent(),
    this.args = const Value.absent(),
    this.env = const Value.absent(),
    this.url = const Value.absent(),
    this.headers = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  AiMcpServersCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.transport = const Value.absent(),
    this.command = const Value.absent(),
    this.args = const Value.absent(),
    this.env = const Value.absent(),
    this.url = const Value.absent(),
    this.headers = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<AiMcpServer> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? transport,
    Expression<String>? command,
    Expression<String>? args,
    Expression<String>? env,
    Expression<String>? url,
    Expression<String>? headers,
    Expression<bool>? isEnabled,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (transport != null) 'transport': transport,
      if (command != null) 'command': command,
      if (args != null) 'args': args,
      if (env != null) 'env': env,
      if (url != null) 'url': url,
      if (headers != null) 'headers': headers,
      if (isEnabled != null) 'is_enabled': isEnabled,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  AiMcpServersCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? transport,
    Value<String?>? command,
    Value<String?>? args,
    Value<String?>? env,
    Value<String?>? url,
    Value<String?>? headers,
    Value<bool>? isEnabled,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return AiMcpServersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      transport: transport ?? this.transport,
      command: command ?? this.command,
      args: args ?? this.args,
      env: env ?? this.env,
      url: url ?? this.url,
      headers: headers ?? this.headers,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (transport.present) {
      map['transport'] = Variable<String>(transport.value);
    }
    if (command.present) {
      map['command'] = Variable<String>(command.value);
    }
    if (args.present) {
      map['args'] = Variable<String>(args.value);
    }
    if (env.present) {
      map['env'] = Variable<String>(env.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (headers.present) {
      map['headers'] = Variable<String>(headers.value);
    }
    if (isEnabled.present) {
      map['is_enabled'] = Variable<bool>(isEnabled.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiMcpServersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('transport: $transport, ')
          ..write('command: $command, ')
          ..write('args: $args, ')
          ..write('env: $env, ')
          ..write('url: $url, ')
          ..write('headers: $headers, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $AiAuxSettingsTable extends AiAuxSettings
    with TableInfo<$AiAuxSettingsTable, AiAuxSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiAuxSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
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
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_aux_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiAuxSetting> instance, {
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
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AiAuxSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiAuxSetting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      ),
    );
  }

  @override
  $AiAuxSettingsTable createAlias(String alias) {
    return $AiAuxSettingsTable(attachedDatabase, alias);
  }
}

class AiAuxSetting extends DataClass implements Insertable<AiAuxSetting> {
  final String key;
  final String? value;
  const AiAuxSetting({required this.key, this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<String>(value);
    }
    return map;
  }

  AiAuxSettingsCompanion toCompanion(bool nullToAbsent) {
    return AiAuxSettingsCompanion(
      key: Value(key),
      value: value == null && nullToAbsent
          ? const Value.absent()
          : Value(value),
    );
  }

  factory AiAuxSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiAuxSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String?>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String?>(value),
    };
  }

  AiAuxSetting copyWith({
    String? key,
    Value<String?> value = const Value.absent(),
  }) => AiAuxSetting(
    key: key ?? this.key,
    value: value.present ? value.value : this.value,
  );
  AiAuxSetting copyWithCompanion(AiAuxSettingsCompanion data) {
    return AiAuxSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiAuxSetting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiAuxSetting &&
          other.key == this.key &&
          other.value == this.value);
}

class AiAuxSettingsCompanion extends UpdateCompanion<AiAuxSetting> {
  final Value<String> key;
  final Value<String?> value;
  final Value<int> rowid;
  const AiAuxSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AiAuxSettingsCompanion.insert({
    required String key,
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key);
  static Insertable<AiAuxSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AiAuxSettingsCompanion copyWith({
    Value<String>? key,
    Value<String?>? value,
    Value<int>? rowid,
  }) {
    return AiAuxSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiAuxSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AiDatabase extends GeneratedDatabase {
  _$AiDatabase(QueryExecutor e) : super(e);
  $AiDatabaseManager get managers => $AiDatabaseManager(this);
  late final $AiApiKeysTable aiApiKeys = $AiApiKeysTable(this);
  late final $AiSessionsTable aiSessions = $AiSessionsTable(this);
  late final $AiTasksTable aiTasks = $AiTasksTable(this);
  late final $AiConfigsTable aiConfigs = $AiConfigsTable(this);
  late final $AiModelsTable aiModels = $AiModelsTable(this);
  late final $AiProviderStatsTable aiProviderStats = $AiProviderStatsTable(
    this,
  );
  late final $AiCustomProvidersTable aiCustomProviders =
      $AiCustomProvidersTable(this);
  late final $AiSkillsTable aiSkills = $AiSkillsTable(this);
  late final $AiMcpServersTable aiMcpServers = $AiMcpServersTable(this);
  late final $AiAuxSettingsTable aiAuxSettings = $AiAuxSettingsTable(this);
  late final Index tasksSessionIdx = Index(
    'tasks_session_idx',
    'CREATE INDEX tasks_session_idx ON ai_tasks (session_id)',
  );
  late final AiApiKeyDao aiApiKeyDao = AiApiKeyDao(this as AiDatabase);
  late final AiSessionDao aiSessionDao = AiSessionDao(this as AiDatabase);
  late final AiTaskDao aiTaskDao = AiTaskDao(this as AiDatabase);
  late final AiConfigDao aiConfigDao = AiConfigDao(this as AiDatabase);
  late final AiModelDao aiModelDao = AiModelDao(this as AiDatabase);
  late final AiProviderStatsDao aiProviderStatsDao = AiProviderStatsDao(
    this as AiDatabase,
  );
  late final AiCustomProviderDao aiCustomProviderDao = AiCustomProviderDao(
    this as AiDatabase,
  );
  late final AiSkillDao aiSkillDao = AiSkillDao(this as AiDatabase);
  late final AiMcpServerDao aiMcpServerDao = AiMcpServerDao(this as AiDatabase);
  late final AiAuxSettingsDao aiAuxSettingsDao = AiAuxSettingsDao(
    this as AiDatabase,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    aiApiKeys,
    aiSessions,
    aiTasks,
    aiConfigs,
    aiModels,
    aiProviderStats,
    aiCustomProviders,
    aiSkills,
    aiMcpServers,
    aiAuxSettings,
    tasksSessionIdx,
  ];
}

typedef $$AiApiKeysTableCreateCompanionBuilder = AiApiKeysCompanion Function({
  required String provider,
  required String apiKey,
  Value<String?> baseUrl,
  Value<String?> model,
  Value<String?> balanceUrl,
  Value<String?> balanceKey,
  Value<String?> apiFormat,
  Value<String?> modelsUrl,
  Value<bool> isEnabled,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$AiApiKeysTableUpdateCompanionBuilder = AiApiKeysCompanion Function({
  Value<String> provider,
  Value<String> apiKey,
  Value<String?> baseUrl,
  Value<String?> model,
  Value<String?> balanceUrl,
  Value<String?> balanceKey,
  Value<String?> apiFormat,
  Value<String?> modelsUrl,
  Value<bool> isEnabled,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$AiApiKeysTableFilterComposer
    extends Composer<_$AiDatabase, $AiApiKeysTable> {
  $$AiApiKeysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get apiKey => $composableBuilder(
    column: $table.apiKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get balanceUrl => $composableBuilder(
    column: $table.balanceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get balanceKey => $composableBuilder(
    column: $table.balanceKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get apiFormat => $composableBuilder(
    column: $table.apiFormat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelsUrl => $composableBuilder(
    column: $table.modelsUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AiApiKeysTableOrderingComposer
    extends Composer<_$AiDatabase, $AiApiKeysTable> {
  $$AiApiKeysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get apiKey => $composableBuilder(
    column: $table.apiKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get balanceUrl => $composableBuilder(
    column: $table.balanceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get balanceKey => $composableBuilder(
    column: $table.balanceKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get apiFormat => $composableBuilder(
    column: $table.apiFormat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelsUrl => $composableBuilder(
    column: $table.modelsUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AiApiKeysTableAnnotationComposer
    extends Composer<_$AiDatabase, $AiApiKeysTable> {
  $$AiApiKeysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get apiKey =>
      $composableBuilder(column: $table.apiKey, builder: (column) => column);

  GeneratedColumn<String> get baseUrl =>
      $composableBuilder(column: $table.baseUrl, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<String> get balanceUrl => $composableBuilder(
    column: $table.balanceUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get balanceKey => $composableBuilder(
    column: $table.balanceKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get apiFormat =>
      $composableBuilder(column: $table.apiFormat, builder: (column) => column);

  GeneratedColumn<String> get modelsUrl =>
      $composableBuilder(column: $table.modelsUrl, builder: (column) => column);

  GeneratedColumn<bool> get isEnabled =>
      $composableBuilder(column: $table.isEnabled, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AiApiKeysTableTableManager
    extends
        RootTableManager<
          _$AiDatabase,
          $AiApiKeysTable,
          AiApiKey,
          $$AiApiKeysTableFilterComposer,
          $$AiApiKeysTableOrderingComposer,
          $$AiApiKeysTableAnnotationComposer,
          $$AiApiKeysTableCreateCompanionBuilder,
          $$AiApiKeysTableUpdateCompanionBuilder,
          (AiApiKey, BaseReferences<_$AiDatabase, $AiApiKeysTable, AiApiKey>),
          AiApiKey,
          PrefetchHooks Function()
        > {
  $$AiApiKeysTableTableManager(_$AiDatabase db, $AiApiKeysTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiApiKeysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiApiKeysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiApiKeysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> provider = const Value.absent(),
                Value<String> apiKey = const Value.absent(),
                Value<String?> baseUrl = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<String?> balanceUrl = const Value.absent(),
                Value<String?> balanceKey = const Value.absent(),
                Value<String?> apiFormat = const Value.absent(),
                Value<String?> modelsUrl = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiApiKeysCompanion(
                provider: provider,
                apiKey: apiKey,
                baseUrl: baseUrl,
                model: model,
                balanceUrl: balanceUrl,
                balanceKey: balanceKey,
                apiFormat: apiFormat,
                modelsUrl: modelsUrl,
                isEnabled: isEnabled,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String provider,
                required String apiKey,
                Value<String?> baseUrl = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<String?> balanceUrl = const Value.absent(),
                Value<String?> balanceKey = const Value.absent(),
                Value<String?> apiFormat = const Value.absent(),
                Value<String?> modelsUrl = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiApiKeysCompanion.insert(
                provider: provider,
                apiKey: apiKey,
                baseUrl: baseUrl,
                model: model,
                balanceUrl: balanceUrl,
                balanceKey: balanceKey,
                apiFormat: apiFormat,
                modelsUrl: modelsUrl,
                isEnabled: isEnabled,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AiApiKeysTable, AiApiKey>(table),
                  BaseReferences<_$AiDatabase, $AiApiKeysTable, AiApiKey>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AiApiKeysTableProcessedTableManager =
    ProcessedTableManager<
      _$AiDatabase,
      $AiApiKeysTable,
      AiApiKey,
      $$AiApiKeysTableFilterComposer,
      $$AiApiKeysTableOrderingComposer,
      $$AiApiKeysTableAnnotationComposer,
      $$AiApiKeysTableCreateCompanionBuilder,
      $$AiApiKeysTableUpdateCompanionBuilder,
      (AiApiKey, BaseReferences<_$AiDatabase, $AiApiKeysTable, AiApiKey>),
      AiApiKey,
      PrefetchHooks Function()
    >;
typedef $$AiSessionsTableCreateCompanionBuilder = AiSessionsCompanion Function({
  required String sessionId,
  required String type,
  Value<String> title,
  Value<String?> configKey,
  Value<String?> profileId,
  required String provider,
  Value<String?> compressedContent,
  Value<String?> skillKeys,
  Value<String?> followUps,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$AiSessionsTableUpdateCompanionBuilder = AiSessionsCompanion Function({
  Value<String> sessionId,
  Value<String> type,
  Value<String> title,
  Value<String?> configKey,
  Value<String?> profileId,
  Value<String> provider,
  Value<String?> compressedContent,
  Value<String?> skillKeys,
  Value<String?> followUps,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$AiSessionsTableFilterComposer
    extends Composer<_$AiDatabase, $AiSessionsTable> {
  $$AiSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get configKey => $composableBuilder(
    column: $table.configKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get compressedContent => $composableBuilder(
    column: $table.compressedContent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get skillKeys => $composableBuilder(
    column: $table.skillKeys,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get followUps => $composableBuilder(
    column: $table.followUps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AiSessionsTableOrderingComposer
    extends Composer<_$AiDatabase, $AiSessionsTable> {
  $$AiSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get configKey => $composableBuilder(
    column: $table.configKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get compressedContent => $composableBuilder(
    column: $table.compressedContent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get skillKeys => $composableBuilder(
    column: $table.skillKeys,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get followUps => $composableBuilder(
    column: $table.followUps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AiSessionsTableAnnotationComposer
    extends Composer<_$AiDatabase, $AiSessionsTable> {
  $$AiSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get configKey =>
      $composableBuilder(column: $table.configKey, builder: (column) => column);

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get compressedContent => $composableBuilder(
    column: $table.compressedContent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get skillKeys =>
      $composableBuilder(column: $table.skillKeys, builder: (column) => column);

  GeneratedColumn<String> get followUps =>
      $composableBuilder(column: $table.followUps, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AiSessionsTableTableManager
    extends
        RootTableManager<
          _$AiDatabase,
          $AiSessionsTable,
          AiSession,
          $$AiSessionsTableFilterComposer,
          $$AiSessionsTableOrderingComposer,
          $$AiSessionsTableAnnotationComposer,
          $$AiSessionsTableCreateCompanionBuilder,
          $$AiSessionsTableUpdateCompanionBuilder,
          (
            AiSession,
            BaseReferences<_$AiDatabase, $AiSessionsTable, AiSession>,
          ),
          AiSession,
          PrefetchHooks Function()
        > {
  $$AiSessionsTableTableManager(_$AiDatabase db, $AiSessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sessionId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> configKey = const Value.absent(),
                Value<String?> profileId = const Value.absent(),
                Value<String> provider = const Value.absent(),
                Value<String?> compressedContent = const Value.absent(),
                Value<String?> skillKeys = const Value.absent(),
                Value<String?> followUps = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiSessionsCompanion(
                sessionId: sessionId,
                type: type,
                title: title,
                configKey: configKey,
                profileId: profileId,
                provider: provider,
                compressedContent: compressedContent,
                skillKeys: skillKeys,
                followUps: followUps,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sessionId,
                required String type,
                Value<String> title = const Value.absent(),
                Value<String?> configKey = const Value.absent(),
                Value<String?> profileId = const Value.absent(),
                required String provider,
                Value<String?> compressedContent = const Value.absent(),
                Value<String?> skillKeys = const Value.absent(),
                Value<String?> followUps = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiSessionsCompanion.insert(
                sessionId: sessionId,
                type: type,
                title: title,
                configKey: configKey,
                profileId: profileId,
                provider: provider,
                compressedContent: compressedContent,
                skillKeys: skillKeys,
                followUps: followUps,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AiSessionsTable, AiSession>(table),
                  BaseReferences<_$AiDatabase, $AiSessionsTable, AiSession>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AiSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AiDatabase,
      $AiSessionsTable,
      AiSession,
      $$AiSessionsTableFilterComposer,
      $$AiSessionsTableOrderingComposer,
      $$AiSessionsTableAnnotationComposer,
      $$AiSessionsTableCreateCompanionBuilder,
      $$AiSessionsTableUpdateCompanionBuilder,
      (AiSession, BaseReferences<_$AiDatabase, $AiSessionsTable, AiSession>),
      AiSession,
      PrefetchHooks Function()
    >;
typedef $$AiTasksTableCreateCompanionBuilder = AiTasksCompanion Function({
  Value<int> id,
  required String sessionId,
  required String taskType,
  Value<String> role,
  required String inputContent,
  Value<String?> inputImages,
  Value<String?> outputContent,
  Value<String?> thought,
  required String provider,
  Value<String?> modelName,
  Value<int> tokenConsumed,
  Value<DateTime> createdAt,
});
typedef $$AiTasksTableUpdateCompanionBuilder = AiTasksCompanion Function({
  Value<int> id,
  Value<String> sessionId,
  Value<String> taskType,
  Value<String> role,
  Value<String> inputContent,
  Value<String?> inputImages,
  Value<String?> outputContent,
  Value<String?> thought,
  Value<String> provider,
  Value<String?> modelName,
  Value<int> tokenConsumed,
  Value<DateTime> createdAt,
});

class $$AiTasksTableFilterComposer
    extends Composer<_$AiDatabase, $AiTasksTable> {
  $$AiTasksTableFilterComposer({
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

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskType => $composableBuilder(
    column: $table.taskType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inputContent => $composableBuilder(
    column: $table.inputContent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inputImages => $composableBuilder(
    column: $table.inputImages,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outputContent => $composableBuilder(
    column: $table.outputContent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thought => $composableBuilder(
    column: $table.thought,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelName => $composableBuilder(
    column: $table.modelName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tokenConsumed => $composableBuilder(
    column: $table.tokenConsumed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AiTasksTableOrderingComposer
    extends Composer<_$AiDatabase, $AiTasksTable> {
  $$AiTasksTableOrderingComposer({
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

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskType => $composableBuilder(
    column: $table.taskType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inputContent => $composableBuilder(
    column: $table.inputContent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inputImages => $composableBuilder(
    column: $table.inputImages,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outputContent => $composableBuilder(
    column: $table.outputContent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thought => $composableBuilder(
    column: $table.thought,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelName => $composableBuilder(
    column: $table.modelName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tokenConsumed => $composableBuilder(
    column: $table.tokenConsumed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AiTasksTableAnnotationComposer
    extends Composer<_$AiDatabase, $AiTasksTable> {
  $$AiTasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get taskType =>
      $composableBuilder(column: $table.taskType, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get inputContent => $composableBuilder(
    column: $table.inputContent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get inputImages => $composableBuilder(
    column: $table.inputImages,
    builder: (column) => column,
  );

  GeneratedColumn<String> get outputContent => $composableBuilder(
    column: $table.outputContent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get thought =>
      $composableBuilder(column: $table.thought, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get modelName =>
      $composableBuilder(column: $table.modelName, builder: (column) => column);

  GeneratedColumn<int> get tokenConsumed => $composableBuilder(
    column: $table.tokenConsumed,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$AiTasksTableTableManager
    extends
        RootTableManager<
          _$AiDatabase,
          $AiTasksTable,
          AiTask,
          $$AiTasksTableFilterComposer,
          $$AiTasksTableOrderingComposer,
          $$AiTasksTableAnnotationComposer,
          $$AiTasksTableCreateCompanionBuilder,
          $$AiTasksTableUpdateCompanionBuilder,
          (AiTask, BaseReferences<_$AiDatabase, $AiTasksTable, AiTask>),
          AiTask,
          PrefetchHooks Function()
        > {
  $$AiTasksTableTableManager(_$AiDatabase db, $AiTasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiTasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiTasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiTasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String> taskType = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> inputContent = const Value.absent(),
                Value<String?> inputImages = const Value.absent(),
                Value<String?> outputContent = const Value.absent(),
                Value<String?> thought = const Value.absent(),
                Value<String> provider = const Value.absent(),
                Value<String?> modelName = const Value.absent(),
                Value<int> tokenConsumed = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => AiTasksCompanion(
                id: id,
                sessionId: sessionId,
                taskType: taskType,
                role: role,
                inputContent: inputContent,
                inputImages: inputImages,
                outputContent: outputContent,
                thought: thought,
                provider: provider,
                modelName: modelName,
                tokenConsumed: tokenConsumed,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String sessionId,
                required String taskType,
                Value<String> role = const Value.absent(),
                required String inputContent,
                Value<String?> inputImages = const Value.absent(),
                Value<String?> outputContent = const Value.absent(),
                Value<String?> thought = const Value.absent(),
                required String provider,
                Value<String?> modelName = const Value.absent(),
                Value<int> tokenConsumed = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => AiTasksCompanion.insert(
                id: id,
                sessionId: sessionId,
                taskType: taskType,
                role: role,
                inputContent: inputContent,
                inputImages: inputImages,
                outputContent: outputContent,
                thought: thought,
                provider: provider,
                modelName: modelName,
                tokenConsumed: tokenConsumed,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AiTasksTable, AiTask>(table),
                  BaseReferences<_$AiDatabase, $AiTasksTable, AiTask>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AiTasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AiDatabase,
      $AiTasksTable,
      AiTask,
      $$AiTasksTableFilterComposer,
      $$AiTasksTableOrderingComposer,
      $$AiTasksTableAnnotationComposer,
      $$AiTasksTableCreateCompanionBuilder,
      $$AiTasksTableUpdateCompanionBuilder,
      (AiTask, BaseReferences<_$AiDatabase, $AiTasksTable, AiTask>),
      AiTask,
      PrefetchHooks Function()
    >;
typedef $$AiConfigsTableCreateCompanionBuilder = AiConfigsCompanion Function({
  Value<int> id,
  required String configKey,
  required String systemPrompt,
  Value<double> temperature,
  Value<String?> memo,
  Value<bool> isSystem,
});
typedef $$AiConfigsTableUpdateCompanionBuilder = AiConfigsCompanion Function({
  Value<int> id,
  Value<String> configKey,
  Value<String> systemPrompt,
  Value<double> temperature,
  Value<String?> memo,
  Value<bool> isSystem,
});

class $$AiConfigsTableFilterComposer
    extends Composer<_$AiDatabase, $AiConfigsTable> {
  $$AiConfigsTableFilterComposer({
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

  ColumnFilters<String> get configKey => $composableBuilder(
    column: $table.configKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get systemPrompt => $composableBuilder(
    column: $table.systemPrompt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get temperature => $composableBuilder(
    column: $table.temperature,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memo => $composableBuilder(
    column: $table.memo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSystem => $composableBuilder(
    column: $table.isSystem,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AiConfigsTableOrderingComposer
    extends Composer<_$AiDatabase, $AiConfigsTable> {
  $$AiConfigsTableOrderingComposer({
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

  ColumnOrderings<String> get configKey => $composableBuilder(
    column: $table.configKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get systemPrompt => $composableBuilder(
    column: $table.systemPrompt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get temperature => $composableBuilder(
    column: $table.temperature,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memo => $composableBuilder(
    column: $table.memo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSystem => $composableBuilder(
    column: $table.isSystem,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AiConfigsTableAnnotationComposer
    extends Composer<_$AiDatabase, $AiConfigsTable> {
  $$AiConfigsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get configKey =>
      $composableBuilder(column: $table.configKey, builder: (column) => column);

  GeneratedColumn<String> get systemPrompt => $composableBuilder(
    column: $table.systemPrompt,
    builder: (column) => column,
  );

  GeneratedColumn<double> get temperature => $composableBuilder(
    column: $table.temperature,
    builder: (column) => column,
  );

  GeneratedColumn<String> get memo =>
      $composableBuilder(column: $table.memo, builder: (column) => column);

  GeneratedColumn<bool> get isSystem =>
      $composableBuilder(column: $table.isSystem, builder: (column) => column);
}

class $$AiConfigsTableTableManager
    extends
        RootTableManager<
          _$AiDatabase,
          $AiConfigsTable,
          AiConfig,
          $$AiConfigsTableFilterComposer,
          $$AiConfigsTableOrderingComposer,
          $$AiConfigsTableAnnotationComposer,
          $$AiConfigsTableCreateCompanionBuilder,
          $$AiConfigsTableUpdateCompanionBuilder,
          (AiConfig, BaseReferences<_$AiDatabase, $AiConfigsTable, AiConfig>),
          AiConfig,
          PrefetchHooks Function()
        > {
  $$AiConfigsTableTableManager(_$AiDatabase db, $AiConfigsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiConfigsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiConfigsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiConfigsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> configKey = const Value.absent(),
                Value<String> systemPrompt = const Value.absent(),
                Value<double> temperature = const Value.absent(),
                Value<String?> memo = const Value.absent(),
                Value<bool> isSystem = const Value.absent(),
              }) => AiConfigsCompanion(
                id: id,
                configKey: configKey,
                systemPrompt: systemPrompt,
                temperature: temperature,
                memo: memo,
                isSystem: isSystem,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String configKey,
                required String systemPrompt,
                Value<double> temperature = const Value.absent(),
                Value<String?> memo = const Value.absent(),
                Value<bool> isSystem = const Value.absent(),
              }) => AiConfigsCompanion.insert(
                id: id,
                configKey: configKey,
                systemPrompt: systemPrompt,
                temperature: temperature,
                memo: memo,
                isSystem: isSystem,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AiConfigsTable, AiConfig>(table),
                  BaseReferences<_$AiDatabase, $AiConfigsTable, AiConfig>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AiConfigsTableProcessedTableManager =
    ProcessedTableManager<
      _$AiDatabase,
      $AiConfigsTable,
      AiConfig,
      $$AiConfigsTableFilterComposer,
      $$AiConfigsTableOrderingComposer,
      $$AiConfigsTableAnnotationComposer,
      $$AiConfigsTableCreateCompanionBuilder,
      $$AiConfigsTableUpdateCompanionBuilder,
      (AiConfig, BaseReferences<_$AiDatabase, $AiConfigsTable, AiConfig>),
      AiConfig,
      PrefetchHooks Function()
    >;
typedef $$AiModelsTableCreateCompanionBuilder = AiModelsCompanion Function({
  required String modelId,
  required String provider,
  required String label,
  Value<String> modelType,
  Value<String> inputModality,
  Value<String> outputModality,
  Value<bool> supportsVision,
  Value<bool> supportsTools,
  Value<bool> supportsReasoning,
  Value<bool> isActive,
  Value<int> rowid,
});
typedef $$AiModelsTableUpdateCompanionBuilder = AiModelsCompanion Function({
  Value<String> modelId,
  Value<String> provider,
  Value<String> label,
  Value<String> modelType,
  Value<String> inputModality,
  Value<String> outputModality,
  Value<bool> supportsVision,
  Value<bool> supportsTools,
  Value<bool> supportsReasoning,
  Value<bool> isActive,
  Value<int> rowid,
});

class $$AiModelsTableFilterComposer
    extends Composer<_$AiDatabase, $AiModelsTable> {
  $$AiModelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelType => $composableBuilder(
    column: $table.modelType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inputModality => $composableBuilder(
    column: $table.inputModality,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outputModality => $composableBuilder(
    column: $table.outputModality,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get supportsVision => $composableBuilder(
    column: $table.supportsVision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get supportsTools => $composableBuilder(
    column: $table.supportsTools,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get supportsReasoning => $composableBuilder(
    column: $table.supportsReasoning,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AiModelsTableOrderingComposer
    extends Composer<_$AiDatabase, $AiModelsTable> {
  $$AiModelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelType => $composableBuilder(
    column: $table.modelType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inputModality => $composableBuilder(
    column: $table.inputModality,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outputModality => $composableBuilder(
    column: $table.outputModality,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get supportsVision => $composableBuilder(
    column: $table.supportsVision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get supportsTools => $composableBuilder(
    column: $table.supportsTools,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get supportsReasoning => $composableBuilder(
    column: $table.supportsReasoning,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AiModelsTableAnnotationComposer
    extends Composer<_$AiDatabase, $AiModelsTable> {
  $$AiModelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get modelId =>
      $composableBuilder(column: $table.modelId, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get modelType =>
      $composableBuilder(column: $table.modelType, builder: (column) => column);

  GeneratedColumn<String> get inputModality => $composableBuilder(
    column: $table.inputModality,
    builder: (column) => column,
  );

  GeneratedColumn<String> get outputModality => $composableBuilder(
    column: $table.outputModality,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get supportsVision => $composableBuilder(
    column: $table.supportsVision,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get supportsTools => $composableBuilder(
    column: $table.supportsTools,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get supportsReasoning => $composableBuilder(
    column: $table.supportsReasoning,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);
}

class $$AiModelsTableTableManager
    extends
        RootTableManager<
          _$AiDatabase,
          $AiModelsTable,
          AiModel,
          $$AiModelsTableFilterComposer,
          $$AiModelsTableOrderingComposer,
          $$AiModelsTableAnnotationComposer,
          $$AiModelsTableCreateCompanionBuilder,
          $$AiModelsTableUpdateCompanionBuilder,
          (AiModel, BaseReferences<_$AiDatabase, $AiModelsTable, AiModel>),
          AiModel,
          PrefetchHooks Function()
        > {
  $$AiModelsTableTableManager(_$AiDatabase db, $AiModelsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiModelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiModelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiModelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> modelId = const Value.absent(),
                Value<String> provider = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String> modelType = const Value.absent(),
                Value<String> inputModality = const Value.absent(),
                Value<String> outputModality = const Value.absent(),
                Value<bool> supportsVision = const Value.absent(),
                Value<bool> supportsTools = const Value.absent(),
                Value<bool> supportsReasoning = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiModelsCompanion(
                modelId: modelId,
                provider: provider,
                label: label,
                modelType: modelType,
                inputModality: inputModality,
                outputModality: outputModality,
                supportsVision: supportsVision,
                supportsTools: supportsTools,
                supportsReasoning: supportsReasoning,
                isActive: isActive,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String modelId,
                required String provider,
                required String label,
                Value<String> modelType = const Value.absent(),
                Value<String> inputModality = const Value.absent(),
                Value<String> outputModality = const Value.absent(),
                Value<bool> supportsVision = const Value.absent(),
                Value<bool> supportsTools = const Value.absent(),
                Value<bool> supportsReasoning = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiModelsCompanion.insert(
                modelId: modelId,
                provider: provider,
                label: label,
                modelType: modelType,
                inputModality: inputModality,
                outputModality: outputModality,
                supportsVision: supportsVision,
                supportsTools: supportsTools,
                supportsReasoning: supportsReasoning,
                isActive: isActive,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AiModelsTable, AiModel>(table),
                  BaseReferences<_$AiDatabase, $AiModelsTable, AiModel>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AiModelsTableProcessedTableManager =
    ProcessedTableManager<
      _$AiDatabase,
      $AiModelsTable,
      AiModel,
      $$AiModelsTableFilterComposer,
      $$AiModelsTableOrderingComposer,
      $$AiModelsTableAnnotationComposer,
      $$AiModelsTableCreateCompanionBuilder,
      $$AiModelsTableUpdateCompanionBuilder,
      (AiModel, BaseReferences<_$AiDatabase, $AiModelsTable, AiModel>),
      AiModel,
      PrefetchHooks Function()
    >;
typedef $$AiProviderStatsTableCreateCompanionBuilder =
    AiProviderStatsCompanion Function({
      required String provider,
      Value<bool> isValid,
      Value<DateTime?> lastCheckAt,
      Value<int> totalCalls,
      Value<int> rowid,
    });
typedef $$AiProviderStatsTableUpdateCompanionBuilder =
    AiProviderStatsCompanion Function({
      Value<String> provider,
      Value<bool> isValid,
      Value<DateTime?> lastCheckAt,
      Value<int> totalCalls,
      Value<int> rowid,
    });

class $$AiProviderStatsTableFilterComposer
    extends Composer<_$AiDatabase, $AiProviderStatsTable> {
  $$AiProviderStatsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isValid => $composableBuilder(
    column: $table.isValid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastCheckAt => $composableBuilder(
    column: $table.lastCheckAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalCalls => $composableBuilder(
    column: $table.totalCalls,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AiProviderStatsTableOrderingComposer
    extends Composer<_$AiDatabase, $AiProviderStatsTable> {
  $$AiProviderStatsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isValid => $composableBuilder(
    column: $table.isValid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastCheckAt => $composableBuilder(
    column: $table.lastCheckAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalCalls => $composableBuilder(
    column: $table.totalCalls,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AiProviderStatsTableAnnotationComposer
    extends Composer<_$AiDatabase, $AiProviderStatsTable> {
  $$AiProviderStatsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<bool> get isValid =>
      $composableBuilder(column: $table.isValid, builder: (column) => column);

  GeneratedColumn<DateTime> get lastCheckAt => $composableBuilder(
    column: $table.lastCheckAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalCalls => $composableBuilder(
    column: $table.totalCalls,
    builder: (column) => column,
  );
}

class $$AiProviderStatsTableTableManager
    extends
        RootTableManager<
          _$AiDatabase,
          $AiProviderStatsTable,
          AiProviderStat,
          $$AiProviderStatsTableFilterComposer,
          $$AiProviderStatsTableOrderingComposer,
          $$AiProviderStatsTableAnnotationComposer,
          $$AiProviderStatsTableCreateCompanionBuilder,
          $$AiProviderStatsTableUpdateCompanionBuilder,
          (
            AiProviderStat,
            BaseReferences<_$AiDatabase, $AiProviderStatsTable, AiProviderStat>,
          ),
          AiProviderStat,
          PrefetchHooks Function()
        > {
  $$AiProviderStatsTableTableManager(
    _$AiDatabase db,
    $AiProviderStatsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiProviderStatsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiProviderStatsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiProviderStatsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> provider = const Value.absent(),
                Value<bool> isValid = const Value.absent(),
                Value<DateTime?> lastCheckAt = const Value.absent(),
                Value<int> totalCalls = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiProviderStatsCompanion(
                provider: provider,
                isValid: isValid,
                lastCheckAt: lastCheckAt,
                totalCalls: totalCalls,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String provider,
                Value<bool> isValid = const Value.absent(),
                Value<DateTime?> lastCheckAt = const Value.absent(),
                Value<int> totalCalls = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiProviderStatsCompanion.insert(
                provider: provider,
                isValid: isValid,
                lastCheckAt: lastCheckAt,
                totalCalls: totalCalls,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AiProviderStatsTable, AiProviderStat>(table),
                  BaseReferences<
                    _$AiDatabase,
                    $AiProviderStatsTable,
                    AiProviderStat
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AiProviderStatsTableProcessedTableManager =
    ProcessedTableManager<
      _$AiDatabase,
      $AiProviderStatsTable,
      AiProviderStat,
      $$AiProviderStatsTableFilterComposer,
      $$AiProviderStatsTableOrderingComposer,
      $$AiProviderStatsTableAnnotationComposer,
      $$AiProviderStatsTableCreateCompanionBuilder,
      $$AiProviderStatsTableUpdateCompanionBuilder,
      (
        AiProviderStat,
        BaseReferences<_$AiDatabase, $AiProviderStatsTable, AiProviderStat>,
      ),
      AiProviderStat,
      PrefetchHooks Function()
    >;
typedef $$AiCustomProvidersTableCreateCompanionBuilder =
    AiCustomProvidersCompanion Function({
      required String provider,
      required String name,
      required String baseUrl,
      Value<String?> defaultModel,
      Value<String?> apiKey,
      Value<String?> apiFormat,
      Value<String?> modelsUrl,
      Value<bool> isEnabled,
      Value<String?> balanceUrl,
      Value<String?> balanceKey,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$AiCustomProvidersTableUpdateCompanionBuilder =
    AiCustomProvidersCompanion Function({
      Value<String> provider,
      Value<String> name,
      Value<String> baseUrl,
      Value<String?> defaultModel,
      Value<String?> apiKey,
      Value<String?> apiFormat,
      Value<String?> modelsUrl,
      Value<bool> isEnabled,
      Value<String?> balanceUrl,
      Value<String?> balanceKey,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$AiCustomProvidersTableFilterComposer
    extends Composer<_$AiDatabase, $AiCustomProvidersTable> {
  $$AiCustomProvidersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defaultModel => $composableBuilder(
    column: $table.defaultModel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get apiKey => $composableBuilder(
    column: $table.apiKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get apiFormat => $composableBuilder(
    column: $table.apiFormat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelsUrl => $composableBuilder(
    column: $table.modelsUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get balanceUrl => $composableBuilder(
    column: $table.balanceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get balanceKey => $composableBuilder(
    column: $table.balanceKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AiCustomProvidersTableOrderingComposer
    extends Composer<_$AiDatabase, $AiCustomProvidersTable> {
  $$AiCustomProvidersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultModel => $composableBuilder(
    column: $table.defaultModel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get apiKey => $composableBuilder(
    column: $table.apiKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get apiFormat => $composableBuilder(
    column: $table.apiFormat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelsUrl => $composableBuilder(
    column: $table.modelsUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get balanceUrl => $composableBuilder(
    column: $table.balanceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get balanceKey => $composableBuilder(
    column: $table.balanceKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AiCustomProvidersTableAnnotationComposer
    extends Composer<_$AiDatabase, $AiCustomProvidersTable> {
  $$AiCustomProvidersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get baseUrl =>
      $composableBuilder(column: $table.baseUrl, builder: (column) => column);

  GeneratedColumn<String> get defaultModel => $composableBuilder(
    column: $table.defaultModel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get apiKey =>
      $composableBuilder(column: $table.apiKey, builder: (column) => column);

  GeneratedColumn<String> get apiFormat =>
      $composableBuilder(column: $table.apiFormat, builder: (column) => column);

  GeneratedColumn<String> get modelsUrl =>
      $composableBuilder(column: $table.modelsUrl, builder: (column) => column);

  GeneratedColumn<bool> get isEnabled =>
      $composableBuilder(column: $table.isEnabled, builder: (column) => column);

  GeneratedColumn<String> get balanceUrl => $composableBuilder(
    column: $table.balanceUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get balanceKey => $composableBuilder(
    column: $table.balanceKey,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AiCustomProvidersTableTableManager
    extends
        RootTableManager<
          _$AiDatabase,
          $AiCustomProvidersTable,
          AiCustomProvider,
          $$AiCustomProvidersTableFilterComposer,
          $$AiCustomProvidersTableOrderingComposer,
          $$AiCustomProvidersTableAnnotationComposer,
          $$AiCustomProvidersTableCreateCompanionBuilder,
          $$AiCustomProvidersTableUpdateCompanionBuilder,
          (
            AiCustomProvider,
            BaseReferences<
              _$AiDatabase,
              $AiCustomProvidersTable,
              AiCustomProvider
            >,
          ),
          AiCustomProvider,
          PrefetchHooks Function()
        > {
  $$AiCustomProvidersTableTableManager(
    _$AiDatabase db,
    $AiCustomProvidersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiCustomProvidersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiCustomProvidersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiCustomProvidersTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> provider = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> baseUrl = const Value.absent(),
                Value<String?> defaultModel = const Value.absent(),
                Value<String?> apiKey = const Value.absent(),
                Value<String?> apiFormat = const Value.absent(),
                Value<String?> modelsUrl = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<String?> balanceUrl = const Value.absent(),
                Value<String?> balanceKey = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiCustomProvidersCompanion(
                provider: provider,
                name: name,
                baseUrl: baseUrl,
                defaultModel: defaultModel,
                apiKey: apiKey,
                apiFormat: apiFormat,
                modelsUrl: modelsUrl,
                isEnabled: isEnabled,
                balanceUrl: balanceUrl,
                balanceKey: balanceKey,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String provider,
                required String name,
                required String baseUrl,
                Value<String?> defaultModel = const Value.absent(),
                Value<String?> apiKey = const Value.absent(),
                Value<String?> apiFormat = const Value.absent(),
                Value<String?> modelsUrl = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<String?> balanceUrl = const Value.absent(),
                Value<String?> balanceKey = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiCustomProvidersCompanion.insert(
                provider: provider,
                name: name,
                baseUrl: baseUrl,
                defaultModel: defaultModel,
                apiKey: apiKey,
                apiFormat: apiFormat,
                modelsUrl: modelsUrl,
                isEnabled: isEnabled,
                balanceUrl: balanceUrl,
                balanceKey: balanceKey,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AiCustomProvidersTable, AiCustomProvider>(table),
                  BaseReferences<
                    _$AiDatabase,
                    $AiCustomProvidersTable,
                    AiCustomProvider
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AiCustomProvidersTableProcessedTableManager =
    ProcessedTableManager<
      _$AiDatabase,
      $AiCustomProvidersTable,
      AiCustomProvider,
      $$AiCustomProvidersTableFilterComposer,
      $$AiCustomProvidersTableOrderingComposer,
      $$AiCustomProvidersTableAnnotationComposer,
      $$AiCustomProvidersTableCreateCompanionBuilder,
      $$AiCustomProvidersTableUpdateCompanionBuilder,
      (
        AiCustomProvider,
        BaseReferences<_$AiDatabase, $AiCustomProvidersTable, AiCustomProvider>,
      ),
      AiCustomProvider,
      PrefetchHooks Function()
    >;
typedef $$AiSkillsTableCreateCompanionBuilder = AiSkillsCompanion Function({
  Value<int> id,
  required String key,
  required String name,
  Value<String?> description,
  required String systemPrompt,
  Value<bool> isBuiltin,
  Value<bool> isEnabled,
  Value<DateTime> createdAt,
});
typedef $$AiSkillsTableUpdateCompanionBuilder = AiSkillsCompanion Function({
  Value<int> id,
  Value<String> key,
  Value<String> name,
  Value<String?> description,
  Value<String> systemPrompt,
  Value<bool> isBuiltin,
  Value<bool> isEnabled,
  Value<DateTime> createdAt,
});

class $$AiSkillsTableFilterComposer
    extends Composer<_$AiDatabase, $AiSkillsTable> {
  $$AiSkillsTableFilterComposer({
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

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get systemPrompt => $composableBuilder(
    column: $table.systemPrompt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isBuiltin => $composableBuilder(
    column: $table.isBuiltin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AiSkillsTableOrderingComposer
    extends Composer<_$AiDatabase, $AiSkillsTable> {
  $$AiSkillsTableOrderingComposer({
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

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get systemPrompt => $composableBuilder(
    column: $table.systemPrompt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isBuiltin => $composableBuilder(
    column: $table.isBuiltin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AiSkillsTableAnnotationComposer
    extends Composer<_$AiDatabase, $AiSkillsTable> {
  $$AiSkillsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get systemPrompt => $composableBuilder(
    column: $table.systemPrompt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isBuiltin =>
      $composableBuilder(column: $table.isBuiltin, builder: (column) => column);

  GeneratedColumn<bool> get isEnabled =>
      $composableBuilder(column: $table.isEnabled, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$AiSkillsTableTableManager
    extends
        RootTableManager<
          _$AiDatabase,
          $AiSkillsTable,
          AiSkill,
          $$AiSkillsTableFilterComposer,
          $$AiSkillsTableOrderingComposer,
          $$AiSkillsTableAnnotationComposer,
          $$AiSkillsTableCreateCompanionBuilder,
          $$AiSkillsTableUpdateCompanionBuilder,
          (AiSkill, BaseReferences<_$AiDatabase, $AiSkillsTable, AiSkill>),
          AiSkill,
          PrefetchHooks Function()
        > {
  $$AiSkillsTableTableManager(_$AiDatabase db, $AiSkillsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiSkillsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiSkillsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiSkillsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String> systemPrompt = const Value.absent(),
                Value<bool> isBuiltin = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => AiSkillsCompanion(
                id: id,
                key: key,
                name: name,
                description: description,
                systemPrompt: systemPrompt,
                isBuiltin: isBuiltin,
                isEnabled: isEnabled,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String key,
                required String name,
                Value<String?> description = const Value.absent(),
                required String systemPrompt,
                Value<bool> isBuiltin = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => AiSkillsCompanion.insert(
                id: id,
                key: key,
                name: name,
                description: description,
                systemPrompt: systemPrompt,
                isBuiltin: isBuiltin,
                isEnabled: isEnabled,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AiSkillsTable, AiSkill>(table),
                  BaseReferences<_$AiDatabase, $AiSkillsTable, AiSkill>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AiSkillsTableProcessedTableManager =
    ProcessedTableManager<
      _$AiDatabase,
      $AiSkillsTable,
      AiSkill,
      $$AiSkillsTableFilterComposer,
      $$AiSkillsTableOrderingComposer,
      $$AiSkillsTableAnnotationComposer,
      $$AiSkillsTableCreateCompanionBuilder,
      $$AiSkillsTableUpdateCompanionBuilder,
      (AiSkill, BaseReferences<_$AiDatabase, $AiSkillsTable, AiSkill>),
      AiSkill,
      PrefetchHooks Function()
    >;
typedef $$AiMcpServersTableCreateCompanionBuilder =
    AiMcpServersCompanion Function({
      Value<int> id,
      required String name,
      Value<String> transport,
      Value<String?> command,
      Value<String?> args,
      Value<String?> env,
      Value<String?> url,
      Value<String?> headers,
      Value<bool> isEnabled,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$AiMcpServersTableUpdateCompanionBuilder =
    AiMcpServersCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> transport,
      Value<String?> command,
      Value<String?> args,
      Value<String?> env,
      Value<String?> url,
      Value<String?> headers,
      Value<bool> isEnabled,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$AiMcpServersTableFilterComposer
    extends Composer<_$AiDatabase, $AiMcpServersTable> {
  $$AiMcpServersTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transport => $composableBuilder(
    column: $table.transport,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get command => $composableBuilder(
    column: $table.command,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get args => $composableBuilder(
    column: $table.args,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get env => $composableBuilder(
    column: $table.env,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get headers => $composableBuilder(
    column: $table.headers,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AiMcpServersTableOrderingComposer
    extends Composer<_$AiDatabase, $AiMcpServersTable> {
  $$AiMcpServersTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transport => $composableBuilder(
    column: $table.transport,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get command => $composableBuilder(
    column: $table.command,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get args => $composableBuilder(
    column: $table.args,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get env => $composableBuilder(
    column: $table.env,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get headers => $composableBuilder(
    column: $table.headers,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AiMcpServersTableAnnotationComposer
    extends Composer<_$AiDatabase, $AiMcpServersTable> {
  $$AiMcpServersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get transport =>
      $composableBuilder(column: $table.transport, builder: (column) => column);

  GeneratedColumn<String> get command =>
      $composableBuilder(column: $table.command, builder: (column) => column);

  GeneratedColumn<String> get args =>
      $composableBuilder(column: $table.args, builder: (column) => column);

  GeneratedColumn<String> get env =>
      $composableBuilder(column: $table.env, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get headers =>
      $composableBuilder(column: $table.headers, builder: (column) => column);

  GeneratedColumn<bool> get isEnabled =>
      $composableBuilder(column: $table.isEnabled, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AiMcpServersTableTableManager
    extends
        RootTableManager<
          _$AiDatabase,
          $AiMcpServersTable,
          AiMcpServer,
          $$AiMcpServersTableFilterComposer,
          $$AiMcpServersTableOrderingComposer,
          $$AiMcpServersTableAnnotationComposer,
          $$AiMcpServersTableCreateCompanionBuilder,
          $$AiMcpServersTableUpdateCompanionBuilder,
          (
            AiMcpServer,
            BaseReferences<_$AiDatabase, $AiMcpServersTable, AiMcpServer>,
          ),
          AiMcpServer,
          PrefetchHooks Function()
        > {
  $$AiMcpServersTableTableManager(_$AiDatabase db, $AiMcpServersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiMcpServersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiMcpServersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiMcpServersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> transport = const Value.absent(),
                Value<String?> command = const Value.absent(),
                Value<String?> args = const Value.absent(),
                Value<String?> env = const Value.absent(),
                Value<String?> url = const Value.absent(),
                Value<String?> headers = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => AiMcpServersCompanion(
                id: id,
                name: name,
                transport: transport,
                command: command,
                args: args,
                env: env,
                url: url,
                headers: headers,
                isEnabled: isEnabled,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String> transport = const Value.absent(),
                Value<String?> command = const Value.absent(),
                Value<String?> args = const Value.absent(),
                Value<String?> env = const Value.absent(),
                Value<String?> url = const Value.absent(),
                Value<String?> headers = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => AiMcpServersCompanion.insert(
                id: id,
                name: name,
                transport: transport,
                command: command,
                args: args,
                env: env,
                url: url,
                headers: headers,
                isEnabled: isEnabled,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AiMcpServersTable, AiMcpServer>(table),
                  BaseReferences<_$AiDatabase, $AiMcpServersTable, AiMcpServer>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AiMcpServersTableProcessedTableManager =
    ProcessedTableManager<
      _$AiDatabase,
      $AiMcpServersTable,
      AiMcpServer,
      $$AiMcpServersTableFilterComposer,
      $$AiMcpServersTableOrderingComposer,
      $$AiMcpServersTableAnnotationComposer,
      $$AiMcpServersTableCreateCompanionBuilder,
      $$AiMcpServersTableUpdateCompanionBuilder,
      (
        AiMcpServer,
        BaseReferences<_$AiDatabase, $AiMcpServersTable, AiMcpServer>,
      ),
      AiMcpServer,
      PrefetchHooks Function()
    >;
typedef $$AiAuxSettingsTableCreateCompanionBuilder =
    AiAuxSettingsCompanion Function({
      required String key,
      Value<String?> value,
      Value<int> rowid,
    });
typedef $$AiAuxSettingsTableUpdateCompanionBuilder =
    AiAuxSettingsCompanion Function({
      Value<String> key,
      Value<String?> value,
      Value<int> rowid,
    });

class $$AiAuxSettingsTableFilterComposer
    extends Composer<_$AiDatabase, $AiAuxSettingsTable> {
  $$AiAuxSettingsTableFilterComposer({
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

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AiAuxSettingsTableOrderingComposer
    extends Composer<_$AiDatabase, $AiAuxSettingsTable> {
  $$AiAuxSettingsTableOrderingComposer({
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

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AiAuxSettingsTableAnnotationComposer
    extends Composer<_$AiDatabase, $AiAuxSettingsTable> {
  $$AiAuxSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AiAuxSettingsTableTableManager
    extends
        RootTableManager<
          _$AiDatabase,
          $AiAuxSettingsTable,
          AiAuxSetting,
          $$AiAuxSettingsTableFilterComposer,
          $$AiAuxSettingsTableOrderingComposer,
          $$AiAuxSettingsTableAnnotationComposer,
          $$AiAuxSettingsTableCreateCompanionBuilder,
          $$AiAuxSettingsTableUpdateCompanionBuilder,
          (
            AiAuxSetting,
            BaseReferences<_$AiDatabase, $AiAuxSettingsTable, AiAuxSetting>,
          ),
          AiAuxSetting,
          PrefetchHooks Function()
        > {
  $$AiAuxSettingsTableTableManager(_$AiDatabase db, $AiAuxSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiAuxSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiAuxSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiAuxSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String?> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => AiAuxSettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                Value<String?> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiAuxSettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AiAuxSettingsTable, AiAuxSetting>(table),
                  BaseReferences<
                    _$AiDatabase,
                    $AiAuxSettingsTable,
                    AiAuxSetting
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AiAuxSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AiDatabase,
      $AiAuxSettingsTable,
      AiAuxSetting,
      $$AiAuxSettingsTableFilterComposer,
      $$AiAuxSettingsTableOrderingComposer,
      $$AiAuxSettingsTableAnnotationComposer,
      $$AiAuxSettingsTableCreateCompanionBuilder,
      $$AiAuxSettingsTableUpdateCompanionBuilder,
      (
        AiAuxSetting,
        BaseReferences<_$AiDatabase, $AiAuxSettingsTable, AiAuxSetting>,
      ),
      AiAuxSetting,
      PrefetchHooks Function()
    >;

class $AiDatabaseManager {
  final _$AiDatabase _db;
  $AiDatabaseManager(this._db);
  $$AiApiKeysTableTableManager get aiApiKeys =>
      $$AiApiKeysTableTableManager(_db, _db.aiApiKeys);
  $$AiSessionsTableTableManager get aiSessions =>
      $$AiSessionsTableTableManager(_db, _db.aiSessions);
  $$AiTasksTableTableManager get aiTasks =>
      $$AiTasksTableTableManager(_db, _db.aiTasks);
  $$AiConfigsTableTableManager get aiConfigs =>
      $$AiConfigsTableTableManager(_db, _db.aiConfigs);
  $$AiModelsTableTableManager get aiModels =>
      $$AiModelsTableTableManager(_db, _db.aiModels);
  $$AiProviderStatsTableTableManager get aiProviderStats =>
      $$AiProviderStatsTableTableManager(_db, _db.aiProviderStats);
  $$AiCustomProvidersTableTableManager get aiCustomProviders =>
      $$AiCustomProvidersTableTableManager(_db, _db.aiCustomProviders);
  $$AiSkillsTableTableManager get aiSkills =>
      $$AiSkillsTableTableManager(_db, _db.aiSkills);
  $$AiMcpServersTableTableManager get aiMcpServers =>
      $$AiMcpServersTableTableManager(_db, _db.aiMcpServers);
  $$AiAuxSettingsTableTableManager get aiAuxSettings =>
      $$AiAuxSettingsTableTableManager(_db, _db.aiAuxSettings);
}

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

  /// 自定义 baseUrl（可为空，使用默认值）
  final String? baseUrl;

  /// 当前使用的模型名称
  final String? model;

  /// Key 是否启用
  final bool isEnabled;

  /// 最后更新时间
  final DateTime updatedAt;
  const AiApiKey({
    required this.provider,
    required this.apiKey,
    this.baseUrl,
    this.model,
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
      'isEnabled': serializer.toJson<bool>(isEnabled),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AiApiKey copyWith({
    String? provider,
    String? apiKey,
    Value<String?> baseUrl = const Value.absent(),
    Value<String?> model = const Value.absent(),
    bool? isEnabled,
    DateTime? updatedAt,
  }) => AiApiKey(
    provider: provider ?? this.provider,
    apiKey: apiKey ?? this.apiKey,
    baseUrl: baseUrl.present ? baseUrl.value : this.baseUrl,
    model: model.present ? model.value : this.model,
    isEnabled: isEnabled ?? this.isEnabled,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AiApiKey copyWithCompanion(AiApiKeysCompanion data) {
    return AiApiKey(
      provider: data.provider.present ? data.provider.value : this.provider,
      apiKey: data.apiKey.present ? data.apiKey.value : this.apiKey,
      baseUrl: data.baseUrl.present ? data.baseUrl.value : this.baseUrl,
      model: data.model.present ? data.model.value : this.model,
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
          ..write('isEnabled: $isEnabled, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(provider, apiKey, baseUrl, model, isEnabled, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiApiKey &&
          other.provider == this.provider &&
          other.apiKey == this.apiKey &&
          other.baseUrl == this.baseUrl &&
          other.model == this.model &&
          other.isEnabled == this.isEnabled &&
          other.updatedAt == this.updatedAt);
}

class AiApiKeysCompanion extends UpdateCompanion<AiApiKey> {
  final Value<String> provider;
  final Value<String> apiKey;
  final Value<String?> baseUrl;
  final Value<String?> model;
  final Value<bool> isEnabled;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AiApiKeysCompanion({
    this.provider = const Value.absent(),
    this.apiKey = const Value.absent(),
    this.baseUrl = const Value.absent(),
    this.model = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AiApiKeysCompanion.insert({
    required String provider,
    required String apiKey,
    this.baseUrl = const Value.absent(),
    this.model = const Value.absent(),
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
    Expression<bool>? isEnabled,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (provider != null) 'provider': provider,
      if (apiKey != null) 'api_key': apiKey,
      if (baseUrl != null) 'base_url': baseUrl,
      if (model != null) 'model': model,
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
    Value<bool>? isEnabled,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return AiApiKeysCompanion(
      provider: provider ?? this.provider,
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
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
          ..write('isEnabled: $isEnabled, ')
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
  static const VerificationMeta _outputContentMeta = const VerificationMeta(
    'outputContent',
  );
  @override
  late final GeneratedColumn<String> outputContent = GeneratedColumn<String>(
    'output_content',
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
    taskType,
    provider,
    inputContent,
    outputContent,
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
    if (data.containsKey('task_type')) {
      context.handle(
        _taskTypeMeta,
        taskType.isAcceptableOrUnknown(data['task_type']!, _taskTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_taskTypeMeta);
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    } else if (isInserting) {
      context.missing(_providerMeta);
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
    if (data.containsKey('output_content')) {
      context.handle(
        _outputContentMeta,
        outputContent.isAcceptableOrUnknown(
          data['output_content']!,
          _outputContentMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_outputContentMeta);
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
      taskType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_type'],
      )!,
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      )!,
      inputContent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}input_content'],
      )!,
      outputContent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}output_content'],
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

  /// 任务类型: 'translation' | 'soul_profile' | 'anime_recommend'
  final String taskType;

  /// 使用的服务商，外键关联 AiApiKeys.provider
  final String provider;

  /// 输入内容：原文或番剧列表 ID
  final String inputContent;

  /// AI 返回的结果（Markdown）
  final String outputContent;

  /// 使用的模型名称
  final String? modelName;

  /// 消耗 Token 数量
  final int tokenConsumed;
  final DateTime createdAt;
  const AiTask({
    required this.id,
    required this.taskType,
    required this.provider,
    required this.inputContent,
    required this.outputContent,
    this.modelName,
    required this.tokenConsumed,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['task_type'] = Variable<String>(taskType);
    map['provider'] = Variable<String>(provider);
    map['input_content'] = Variable<String>(inputContent);
    map['output_content'] = Variable<String>(outputContent);
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
      taskType: Value(taskType),
      provider: Value(provider),
      inputContent: Value(inputContent),
      outputContent: Value(outputContent),
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
      taskType: serializer.fromJson<String>(json['taskType']),
      provider: serializer.fromJson<String>(json['provider']),
      inputContent: serializer.fromJson<String>(json['inputContent']),
      outputContent: serializer.fromJson<String>(json['outputContent']),
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
      'taskType': serializer.toJson<String>(taskType),
      'provider': serializer.toJson<String>(provider),
      'inputContent': serializer.toJson<String>(inputContent),
      'outputContent': serializer.toJson<String>(outputContent),
      'modelName': serializer.toJson<String?>(modelName),
      'tokenConsumed': serializer.toJson<int>(tokenConsumed),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  AiTask copyWith({
    int? id,
    String? taskType,
    String? provider,
    String? inputContent,
    String? outputContent,
    Value<String?> modelName = const Value.absent(),
    int? tokenConsumed,
    DateTime? createdAt,
  }) => AiTask(
    id: id ?? this.id,
    taskType: taskType ?? this.taskType,
    provider: provider ?? this.provider,
    inputContent: inputContent ?? this.inputContent,
    outputContent: outputContent ?? this.outputContent,
    modelName: modelName.present ? modelName.value : this.modelName,
    tokenConsumed: tokenConsumed ?? this.tokenConsumed,
    createdAt: createdAt ?? this.createdAt,
  );
  AiTask copyWithCompanion(AiTasksCompanion data) {
    return AiTask(
      id: data.id.present ? data.id.value : this.id,
      taskType: data.taskType.present ? data.taskType.value : this.taskType,
      provider: data.provider.present ? data.provider.value : this.provider,
      inputContent: data.inputContent.present
          ? data.inputContent.value
          : this.inputContent,
      outputContent: data.outputContent.present
          ? data.outputContent.value
          : this.outputContent,
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
          ..write('taskType: $taskType, ')
          ..write('provider: $provider, ')
          ..write('inputContent: $inputContent, ')
          ..write('outputContent: $outputContent, ')
          ..write('modelName: $modelName, ')
          ..write('tokenConsumed: $tokenConsumed, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    taskType,
    provider,
    inputContent,
    outputContent,
    modelName,
    tokenConsumed,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiTask &&
          other.id == this.id &&
          other.taskType == this.taskType &&
          other.provider == this.provider &&
          other.inputContent == this.inputContent &&
          other.outputContent == this.outputContent &&
          other.modelName == this.modelName &&
          other.tokenConsumed == this.tokenConsumed &&
          other.createdAt == this.createdAt);
}

class AiTasksCompanion extends UpdateCompanion<AiTask> {
  final Value<int> id;
  final Value<String> taskType;
  final Value<String> provider;
  final Value<String> inputContent;
  final Value<String> outputContent;
  final Value<String?> modelName;
  final Value<int> tokenConsumed;
  final Value<DateTime> createdAt;
  const AiTasksCompanion({
    this.id = const Value.absent(),
    this.taskType = const Value.absent(),
    this.provider = const Value.absent(),
    this.inputContent = const Value.absent(),
    this.outputContent = const Value.absent(),
    this.modelName = const Value.absent(),
    this.tokenConsumed = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  AiTasksCompanion.insert({
    this.id = const Value.absent(),
    required String taskType,
    required String provider,
    required String inputContent,
    required String outputContent,
    this.modelName = const Value.absent(),
    this.tokenConsumed = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : taskType = Value(taskType),
       provider = Value(provider),
       inputContent = Value(inputContent),
       outputContent = Value(outputContent);
  static Insertable<AiTask> custom({
    Expression<int>? id,
    Expression<String>? taskType,
    Expression<String>? provider,
    Expression<String>? inputContent,
    Expression<String>? outputContent,
    Expression<String>? modelName,
    Expression<int>? tokenConsumed,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (taskType != null) 'task_type': taskType,
      if (provider != null) 'provider': provider,
      if (inputContent != null) 'input_content': inputContent,
      if (outputContent != null) 'output_content': outputContent,
      if (modelName != null) 'model_name': modelName,
      if (tokenConsumed != null) 'token_consumed': tokenConsumed,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  AiTasksCompanion copyWith({
    Value<int>? id,
    Value<String>? taskType,
    Value<String>? provider,
    Value<String>? inputContent,
    Value<String>? outputContent,
    Value<String?>? modelName,
    Value<int>? tokenConsumed,
    Value<DateTime>? createdAt,
  }) {
    return AiTasksCompanion(
      id: id ?? this.id,
      taskType: taskType ?? this.taskType,
      provider: provider ?? this.provider,
      inputContent: inputContent ?? this.inputContent,
      outputContent: outputContent ?? this.outputContent,
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
    if (taskType.present) {
      map['task_type'] = Variable<String>(taskType.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (inputContent.present) {
      map['input_content'] = Variable<String>(inputContent.value);
    }
    if (outputContent.present) {
      map['output_content'] = Variable<String>(outputContent.value);
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
          ..write('taskType: $taskType, ')
          ..write('provider: $provider, ')
          ..write('inputContent: $inputContent, ')
          ..write('outputContent: $outputContent, ')
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
  @override
  List<GeneratedColumn> get $columns => [
    configKey,
    systemPrompt,
    temperature,
    memo,
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {configKey};
  @override
  AiConfig map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiConfig(
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
    );
  }

  @override
  $AiConfigsTable createAlias(String alias) {
    return $AiConfigsTable(attachedDatabase, alias);
  }
}

class AiConfig extends DataClass implements Insertable<AiConfig> {
  /// 唯一键: 'translator_v1' | 'profile_expert'
  final String configKey;

  /// System Prompt
  final String systemPrompt;

  /// 创造力参数: 0.0 ~ 1.0
  final double temperature;

  /// 备注
  final String? memo;
  const AiConfig({
    required this.configKey,
    required this.systemPrompt,
    required this.temperature,
    this.memo,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['config_key'] = Variable<String>(configKey);
    map['system_prompt'] = Variable<String>(systemPrompt);
    map['temperature'] = Variable<double>(temperature);
    if (!nullToAbsent || memo != null) {
      map['memo'] = Variable<String>(memo);
    }
    return map;
  }

  AiConfigsCompanion toCompanion(bool nullToAbsent) {
    return AiConfigsCompanion(
      configKey: Value(configKey),
      systemPrompt: Value(systemPrompt),
      temperature: Value(temperature),
      memo: memo == null && nullToAbsent ? const Value.absent() : Value(memo),
    );
  }

  factory AiConfig.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiConfig(
      configKey: serializer.fromJson<String>(json['configKey']),
      systemPrompt: serializer.fromJson<String>(json['systemPrompt']),
      temperature: serializer.fromJson<double>(json['temperature']),
      memo: serializer.fromJson<String?>(json['memo']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'configKey': serializer.toJson<String>(configKey),
      'systemPrompt': serializer.toJson<String>(systemPrompt),
      'temperature': serializer.toJson<double>(temperature),
      'memo': serializer.toJson<String?>(memo),
    };
  }

  AiConfig copyWith({
    String? configKey,
    String? systemPrompt,
    double? temperature,
    Value<String?> memo = const Value.absent(),
  }) => AiConfig(
    configKey: configKey ?? this.configKey,
    systemPrompt: systemPrompt ?? this.systemPrompt,
    temperature: temperature ?? this.temperature,
    memo: memo.present ? memo.value : this.memo,
  );
  AiConfig copyWithCompanion(AiConfigsCompanion data) {
    return AiConfig(
      configKey: data.configKey.present ? data.configKey.value : this.configKey,
      systemPrompt: data.systemPrompt.present
          ? data.systemPrompt.value
          : this.systemPrompt,
      temperature: data.temperature.present
          ? data.temperature.value
          : this.temperature,
      memo: data.memo.present ? data.memo.value : this.memo,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiConfig(')
          ..write('configKey: $configKey, ')
          ..write('systemPrompt: $systemPrompt, ')
          ..write('temperature: $temperature, ')
          ..write('memo: $memo')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(configKey, systemPrompt, temperature, memo);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiConfig &&
          other.configKey == this.configKey &&
          other.systemPrompt == this.systemPrompt &&
          other.temperature == this.temperature &&
          other.memo == this.memo);
}

class AiConfigsCompanion extends UpdateCompanion<AiConfig> {
  final Value<String> configKey;
  final Value<String> systemPrompt;
  final Value<double> temperature;
  final Value<String?> memo;
  final Value<int> rowid;
  const AiConfigsCompanion({
    this.configKey = const Value.absent(),
    this.systemPrompt = const Value.absent(),
    this.temperature = const Value.absent(),
    this.memo = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AiConfigsCompanion.insert({
    required String configKey,
    required String systemPrompt,
    this.temperature = const Value.absent(),
    this.memo = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : configKey = Value(configKey),
       systemPrompt = Value(systemPrompt);
  static Insertable<AiConfig> custom({
    Expression<String>? configKey,
    Expression<String>? systemPrompt,
    Expression<double>? temperature,
    Expression<String>? memo,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (configKey != null) 'config_key': configKey,
      if (systemPrompt != null) 'system_prompt': systemPrompt,
      if (temperature != null) 'temperature': temperature,
      if (memo != null) 'memo': memo,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AiConfigsCompanion copyWith({
    Value<String>? configKey,
    Value<String>? systemPrompt,
    Value<double>? temperature,
    Value<String?>? memo,
    Value<int>? rowid,
  }) {
    return AiConfigsCompanion(
      configKey: configKey ?? this.configKey,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      temperature: temperature ?? this.temperature,
      memo: memo ?? this.memo,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
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
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiConfigsCompanion(')
          ..write('configKey: $configKey, ')
          ..write('systemPrompt: $systemPrompt, ')
          ..write('temperature: $temperature, ')
          ..write('memo: $memo, ')
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

abstract class _$AiDatabase extends GeneratedDatabase {
  _$AiDatabase(QueryExecutor e) : super(e);
  $AiDatabaseManager get managers => $AiDatabaseManager(this);
  late final $AiApiKeysTable aiApiKeys = $AiApiKeysTable(this);
  late final $AiTasksTable aiTasks = $AiTasksTable(this);
  late final $AiConfigsTable aiConfigs = $AiConfigsTable(this);
  late final $AiProviderStatsTable aiProviderStats = $AiProviderStatsTable(
    this,
  );
  late final AiApiKeyDao aiApiKeyDao = AiApiKeyDao(this as AiDatabase);
  late final AiTaskDao aiTaskDao = AiTaskDao(this as AiDatabase);
  late final AiConfigDao aiConfigDao = AiConfigDao(this as AiDatabase);
  late final AiProviderStatsDao aiProviderStatsDao = AiProviderStatsDao(
    this as AiDatabase,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    aiApiKeys,
    aiTasks,
    aiConfigs,
    aiProviderStats,
  ];
}

typedef $$AiApiKeysTableCreateCompanionBuilder =
    AiApiKeysCompanion Function({
      required String provider,
      required String apiKey,
      Value<String?> baseUrl,
      Value<String?> model,
      Value<bool> isEnabled,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$AiApiKeysTableUpdateCompanionBuilder =
    AiApiKeysCompanion Function({
      Value<String> provider,
      Value<String> apiKey,
      Value<String?> baseUrl,
      Value<String?> model,
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
                Value<bool> isEnabled = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiApiKeysCompanion(
                provider: provider,
                apiKey: apiKey,
                baseUrl: baseUrl,
                model: model,
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
                Value<bool> isEnabled = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiApiKeysCompanion.insert(
                provider: provider,
                apiKey: apiKey,
                baseUrl: baseUrl,
                model: model,
                isEnabled: isEnabled,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
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
typedef $$AiTasksTableCreateCompanionBuilder =
    AiTasksCompanion Function({
      Value<int> id,
      required String taskType,
      required String provider,
      required String inputContent,
      required String outputContent,
      Value<String?> modelName,
      Value<int> tokenConsumed,
      Value<DateTime> createdAt,
    });
typedef $$AiTasksTableUpdateCompanionBuilder =
    AiTasksCompanion Function({
      Value<int> id,
      Value<String> taskType,
      Value<String> provider,
      Value<String> inputContent,
      Value<String> outputContent,
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

  ColumnFilters<String> get taskType => $composableBuilder(
    column: $table.taskType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inputContent => $composableBuilder(
    column: $table.inputContent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outputContent => $composableBuilder(
    column: $table.outputContent,
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

  ColumnOrderings<String> get taskType => $composableBuilder(
    column: $table.taskType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inputContent => $composableBuilder(
    column: $table.inputContent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outputContent => $composableBuilder(
    column: $table.outputContent,
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

  GeneratedColumn<String> get taskType =>
      $composableBuilder(column: $table.taskType, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get inputContent => $composableBuilder(
    column: $table.inputContent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get outputContent => $composableBuilder(
    column: $table.outputContent,
    builder: (column) => column,
  );

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
                Value<String> taskType = const Value.absent(),
                Value<String> provider = const Value.absent(),
                Value<String> inputContent = const Value.absent(),
                Value<String> outputContent = const Value.absent(),
                Value<String?> modelName = const Value.absent(),
                Value<int> tokenConsumed = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => AiTasksCompanion(
                id: id,
                taskType: taskType,
                provider: provider,
                inputContent: inputContent,
                outputContent: outputContent,
                modelName: modelName,
                tokenConsumed: tokenConsumed,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String taskType,
                required String provider,
                required String inputContent,
                required String outputContent,
                Value<String?> modelName = const Value.absent(),
                Value<int> tokenConsumed = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => AiTasksCompanion.insert(
                id: id,
                taskType: taskType,
                provider: provider,
                inputContent: inputContent,
                outputContent: outputContent,
                modelName: modelName,
                tokenConsumed: tokenConsumed,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
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
typedef $$AiConfigsTableCreateCompanionBuilder =
    AiConfigsCompanion Function({
      required String configKey,
      required String systemPrompt,
      Value<double> temperature,
      Value<String?> memo,
      Value<int> rowid,
    });
typedef $$AiConfigsTableUpdateCompanionBuilder =
    AiConfigsCompanion Function({
      Value<String> configKey,
      Value<String> systemPrompt,
      Value<double> temperature,
      Value<String?> memo,
      Value<int> rowid,
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
                Value<String> configKey = const Value.absent(),
                Value<String> systemPrompt = const Value.absent(),
                Value<double> temperature = const Value.absent(),
                Value<String?> memo = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiConfigsCompanion(
                configKey: configKey,
                systemPrompt: systemPrompt,
                temperature: temperature,
                memo: memo,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String configKey,
                required String systemPrompt,
                Value<double> temperature = const Value.absent(),
                Value<String?> memo = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiConfigsCompanion.insert(
                configKey: configKey,
                systemPrompt: systemPrompt,
                temperature: temperature,
                memo: memo,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
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
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
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

class $AiDatabaseManager {
  final _$AiDatabase _db;
  $AiDatabaseManager(this._db);
  $$AiApiKeysTableTableManager get aiApiKeys =>
      $$AiApiKeysTableTableManager(_db, _db.aiApiKeys);
  $$AiTasksTableTableManager get aiTasks =>
      $$AiTasksTableTableManager(_db, _db.aiTasks);
  $$AiConfigsTableTableManager get aiConfigs =>
      $$AiConfigsTableTableManager(_db, _db.aiConfigs);
  $$AiProviderStatsTableTableManager get aiProviderStats =>
      $$AiProviderStatsTableTableManager(_db, _db.aiProviderStats);
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_task_database.dart';

// ignore_for_file: type=lint
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
  static const VerificationMeta _outputVariantsMeta = const VerificationMeta(
    'outputVariants',
  );
  @override
  late final GeneratedColumn<String> outputVariants = GeneratedColumn<String>(
    'output_variants',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _variantIndexMeta = const VerificationMeta(
    'variantIndex',
  );
  @override
  late final GeneratedColumn<int> variantIndex = GeneratedColumn<int>(
    'variant_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
    outputVariants,
    variantIndex,
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
    if (data.containsKey('output_variants')) {
      context.handle(
        _outputVariantsMeta,
        outputVariants.isAcceptableOrUnknown(
          data['output_variants']!,
          _outputVariantsMeta,
        ),
      );
    }
    if (data.containsKey('variant_index')) {
      context.handle(
        _variantIndexMeta,
        variantIndex.isAcceptableOrUnknown(
          data['variant_index']!,
          _variantIndexMeta,
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
      outputVariants: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}output_variants'],
      ),
      variantIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}variant_index'],
      )!,
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

  /// 多候选回复（JSON 字符串数组），outputContent 为当前选中项
  final String? outputVariants;

  /// 当前选中的候选下标
  final int variantIndex;
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
    this.outputVariants,
    required this.variantIndex,
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
    if (!nullToAbsent || outputVariants != null) {
      map['output_variants'] = Variable<String>(outputVariants);
    }
    map['variant_index'] = Variable<int>(variantIndex);
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
      outputVariants: outputVariants == null && nullToAbsent
          ? const Value.absent()
          : Value(outputVariants),
      variantIndex: Value(variantIndex),
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
      outputVariants: serializer.fromJson<String?>(json['outputVariants']),
      variantIndex: serializer.fromJson<int>(json['variantIndex']),
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
      'outputVariants': serializer.toJson<String?>(outputVariants),
      'variantIndex': serializer.toJson<int>(variantIndex),
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
    Value<String?> outputVariants = const Value.absent(),
    int? variantIndex,
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
    outputVariants: outputVariants.present
        ? outputVariants.value
        : this.outputVariants,
    variantIndex: variantIndex ?? this.variantIndex,
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
      outputVariants: data.outputVariants.present
          ? data.outputVariants.value
          : this.outputVariants,
      variantIndex: data.variantIndex.present
          ? data.variantIndex.value
          : this.variantIndex,
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
          ..write('outputVariants: $outputVariants, ')
          ..write('variantIndex: $variantIndex, ')
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
    outputVariants,
    variantIndex,
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
          other.outputVariants == this.outputVariants &&
          other.variantIndex == this.variantIndex &&
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
  final Value<String?> outputVariants;
  final Value<int> variantIndex;
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
    this.outputVariants = const Value.absent(),
    this.variantIndex = const Value.absent(),
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
    this.outputVariants = const Value.absent(),
    this.variantIndex = const Value.absent(),
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
    Expression<String>? outputVariants,
    Expression<int>? variantIndex,
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
      if (outputVariants != null) 'output_variants': outputVariants,
      if (variantIndex != null) 'variant_index': variantIndex,
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
    Value<String?>? outputVariants,
    Value<int>? variantIndex,
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
      outputVariants: outputVariants ?? this.outputVariants,
      variantIndex: variantIndex ?? this.variantIndex,
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
    if (outputVariants.present) {
      map['output_variants'] = Variable<String>(outputVariants.value);
    }
    if (variantIndex.present) {
      map['variant_index'] = Variable<int>(variantIndex.value);
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
          ..write('outputVariants: $outputVariants, ')
          ..write('variantIndex: $variantIndex, ')
          ..write('thought: $thought, ')
          ..write('provider: $provider, ')
          ..write('modelName: $modelName, ')
          ..write('tokenConsumed: $tokenConsumed, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AiTaskDatabase extends GeneratedDatabase {
  _$AiTaskDatabase(QueryExecutor e) : super(e);
  $AiTaskDatabaseManager get managers => $AiTaskDatabaseManager(this);
  late final $AiTasksTable aiTasks = $AiTasksTable(this);
  late final AiTaskDao aiTaskDao = AiTaskDao(this as AiTaskDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [aiTasks];
}

typedef $$AiTasksTableCreateCompanionBuilder = AiTasksCompanion Function({
  Value<int> id,
  required String sessionId,
  required String taskType,
  Value<String> role,
  required String inputContent,
  Value<String?> inputImages,
  Value<String?> outputContent,
  Value<String?> outputVariants,
  Value<int> variantIndex,
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
  Value<String?> outputVariants,
  Value<int> variantIndex,
  Value<String?> thought,
  Value<String> provider,
  Value<String?> modelName,
  Value<int> tokenConsumed,
  Value<DateTime> createdAt,
});

class $$AiTasksTableFilterComposer
    extends Composer<_$AiTaskDatabase, $AiTasksTable> {
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

  ColumnFilters<String> get outputVariants => $composableBuilder(
    column: $table.outputVariants,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get variantIndex => $composableBuilder(
    column: $table.variantIndex,
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
    extends Composer<_$AiTaskDatabase, $AiTasksTable> {
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

  ColumnOrderings<String> get outputVariants => $composableBuilder(
    column: $table.outputVariants,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get variantIndex => $composableBuilder(
    column: $table.variantIndex,
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
    extends Composer<_$AiTaskDatabase, $AiTasksTable> {
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

  GeneratedColumn<String> get outputVariants => $composableBuilder(
    column: $table.outputVariants,
    builder: (column) => column,
  );

  GeneratedColumn<int> get variantIndex => $composableBuilder(
    column: $table.variantIndex,
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
          _$AiTaskDatabase,
          $AiTasksTable,
          AiTask,
          $$AiTasksTableFilterComposer,
          $$AiTasksTableOrderingComposer,
          $$AiTasksTableAnnotationComposer,
          $$AiTasksTableCreateCompanionBuilder,
          $$AiTasksTableUpdateCompanionBuilder,
          (AiTask, BaseReferences<_$AiTaskDatabase, $AiTasksTable, AiTask>),
          AiTask,
          PrefetchHooks Function()
        > {
  $$AiTasksTableTableManager(_$AiTaskDatabase db, $AiTasksTable table)
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
                Value<String?> outputVariants = const Value.absent(),
                Value<int> variantIndex = const Value.absent(),
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
                outputVariants: outputVariants,
                variantIndex: variantIndex,
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
                Value<String?> outputVariants = const Value.absent(),
                Value<int> variantIndex = const Value.absent(),
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
                outputVariants: outputVariants,
                variantIndex: variantIndex,
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
                  BaseReferences<_$AiTaskDatabase, $AiTasksTable, AiTask>(
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
      _$AiTaskDatabase,
      $AiTasksTable,
      AiTask,
      $$AiTasksTableFilterComposer,
      $$AiTasksTableOrderingComposer,
      $$AiTasksTableAnnotationComposer,
      $$AiTasksTableCreateCompanionBuilder,
      $$AiTasksTableUpdateCompanionBuilder,
      (AiTask, BaseReferences<_$AiTaskDatabase, $AiTasksTable, AiTask>),
      AiTask,
      PrefetchHooks Function()
    >;

class $AiTaskDatabaseManager {
  final _$AiTaskDatabase _db;
  $AiTaskDatabaseManager(this._db);
  $$AiTasksTableTableManager get aiTasks =>
      $$AiTasksTableTableManager(_db, _db.aiTasks);
}

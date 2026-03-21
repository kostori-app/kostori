// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_model_dao.dart';

// ignore_for_file: type=lint
mixin _$AiModelDaoMixin on DatabaseAccessor<AiDatabase> {
  $AiModelsTable get aiModels => attachedDatabase.aiModels;
  AiModelDaoManager get managers => AiModelDaoManager(this);
}

class AiModelDaoManager {
  final _$AiModelDaoMixin _db;
  AiModelDaoManager(this._db);
  $$AiModelsTableTableManager get aiModels =>
      $$AiModelsTableTableManager(_db.attachedDatabase, _db.aiModels);
}

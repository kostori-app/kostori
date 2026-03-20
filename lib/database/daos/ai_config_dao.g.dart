// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_config_dao.dart';

// ignore_for_file: type=lint
mixin _$AiConfigDaoMixin on DatabaseAccessor<AiDatabase> {
  $AiConfigsTable get aiConfigs => attachedDatabase.aiConfigs;
  AiConfigDaoManager get managers => AiConfigDaoManager(this);
}

class AiConfigDaoManager {
  final _$AiConfigDaoMixin _db;
  AiConfigDaoManager(this._db);
  $$AiConfigsTableTableManager get aiConfigs =>
      $$AiConfigsTableTableManager(_db.attachedDatabase, _db.aiConfigs);
}

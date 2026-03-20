// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_api_key_dao.dart';

// ignore_for_file: type=lint
mixin _$AiApiKeyDaoMixin on DatabaseAccessor<AiDatabase> {
  $AiApiKeysTable get aiApiKeys => attachedDatabase.aiApiKeys;
  AiApiKeyDaoManager get managers => AiApiKeyDaoManager(this);
}

class AiApiKeyDaoManager {
  final _$AiApiKeyDaoMixin _db;
  AiApiKeyDaoManager(this._db);
  $$AiApiKeysTableTableManager get aiApiKeys =>
      $$AiApiKeysTableTableManager(_db.attachedDatabase, _db.aiApiKeys);
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_custom_provider_dao.dart';

// ignore_for_file: type=lint
mixin _$AiCustomProviderDaoMixin on DatabaseAccessor<AiDatabase> {
  $AiCustomProvidersTable get aiCustomProviders =>
      attachedDatabase.aiCustomProviders;
  AiCustomProviderDaoManager get managers => AiCustomProviderDaoManager(this);
}

class AiCustomProviderDaoManager {
  final _$AiCustomProviderDaoMixin _db;
  AiCustomProviderDaoManager(this._db);
  $$AiCustomProvidersTableTableManager get aiCustomProviders =>
      $$AiCustomProvidersTableTableManager(
        _db.attachedDatabase,
        _db.aiCustomProviders,
      );
}

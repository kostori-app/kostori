// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_provider_stats_dao.dart';

// ignore_for_file: type=lint
mixin _$AiProviderStatsDaoMixin on DatabaseAccessor<AiDatabase> {
  $AiProviderStatsTable get aiProviderStats => attachedDatabase.aiProviderStats;
  AiProviderStatsDaoManager get managers => AiProviderStatsDaoManager(this);
}

class AiProviderStatsDaoManager {
  final _$AiProviderStatsDaoMixin _db;
  AiProviderStatsDaoManager(this._db);
  $$AiProviderStatsTableTableManager get aiProviderStats =>
      $$AiProviderStatsTableTableManager(
        _db.attachedDatabase,
        _db.aiProviderStats,
      );
}

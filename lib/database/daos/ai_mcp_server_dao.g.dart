// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_mcp_server_dao.dart';

// ignore_for_file: type=lint
mixin _$AiMcpServerDaoMixin on DatabaseAccessor<AiDatabase> {
  $AiMcpServersTable get aiMcpServers => attachedDatabase.aiMcpServers;
  AiMcpServerDaoManager get managers => AiMcpServerDaoManager(this);
}

class AiMcpServerDaoManager {
  final _$AiMcpServerDaoMixin _db;
  AiMcpServerDaoManager(this._db);
  $$AiMcpServersTableTableManager get aiMcpServers =>
      $$AiMcpServersTableTableManager(_db.attachedDatabase, _db.aiMcpServers);
}

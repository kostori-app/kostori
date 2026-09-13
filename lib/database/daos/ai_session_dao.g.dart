// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_session_dao.dart';

// ignore_for_file: type=lint
mixin _$AiSessionDaoMixin on DatabaseAccessor<AiDatabase> {
  $AiSessionsTable get aiSessions => attachedDatabase.aiSessions;
  AiSessionDaoManager get managers => AiSessionDaoManager(this);
}

class AiSessionDaoManager {
  final _$AiSessionDaoMixin _db;
  AiSessionDaoManager(this._db);
  $$AiSessionsTableTableManager get aiSessions =>
      $$AiSessionsTableTableManager(_db.attachedDatabase, _db.aiSessions);
}

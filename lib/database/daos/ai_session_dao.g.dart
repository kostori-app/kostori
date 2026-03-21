// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_session_dao.dart';

// ignore_for_file: type=lint
mixin _$AiSessionDaoMixin on DatabaseAccessor<AiDatabase> {
  $AiSessionsTable get aiSessions => attachedDatabase.aiSessions;
  $AiTasksTable get aiTasks => attachedDatabase.aiTasks;
  AiSessionDaoManager get managers => AiSessionDaoManager(this);
}

class AiSessionDaoManager {
  final _$AiSessionDaoMixin _db;
  AiSessionDaoManager(this._db);
  $$AiSessionsTableTableManager get aiSessions =>
      $$AiSessionsTableTableManager(_db.attachedDatabase, _db.aiSessions);
  $$AiTasksTableTableManager get aiTasks =>
      $$AiTasksTableTableManager(_db.attachedDatabase, _db.aiTasks);
}

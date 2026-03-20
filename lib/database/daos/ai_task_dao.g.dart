// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_task_dao.dart';

// ignore_for_file: type=lint
mixin _$AiTaskDaoMixin on DatabaseAccessor<AiDatabase> {
  $AiTasksTable get aiTasks => attachedDatabase.aiTasks;
  AiTaskDaoManager get managers => AiTaskDaoManager(this);
}

class AiTaskDaoManager {
  final _$AiTaskDaoMixin _db;
  AiTaskDaoManager(this._db);
  $$AiTasksTableTableManager get aiTasks =>
      $$AiTasksTableTableManager(_db.attachedDatabase, _db.aiTasks);
}

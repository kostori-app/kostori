// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_skill_dao.dart';

// ignore_for_file: type=lint
mixin _$AiSkillDaoMixin on DatabaseAccessor<AiDatabase> {
  $AiSkillsTable get aiSkills => attachedDatabase.aiSkills;
  AiSkillDaoManager get managers => AiSkillDaoManager(this);
}

class AiSkillDaoManager {
  final _$AiSkillDaoMixin _db;
  AiSkillDaoManager(this._db);
  $$AiSkillsTableTableManager get aiSkills =>
      $$AiSkillsTableTableManager(_db.attachedDatabase, _db.aiSkills);
}

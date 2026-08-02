// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_aux_settings_dao.dart';

// ignore_for_file: type=lint
mixin _$AiAuxSettingsDaoMixin on DatabaseAccessor<AiDatabase> {
  $AiAuxSettingsTable get aiAuxSettings => attachedDatabase.aiAuxSettings;
  AiAuxSettingsDaoManager get managers => AiAuxSettingsDaoManager(this);
}

class AiAuxSettingsDaoManager {
  final _$AiAuxSettingsDaoMixin _db;
  AiAuxSettingsDaoManager(this._db);
  $$AiAuxSettingsTableTableManager get aiAuxSettings =>
      $$AiAuxSettingsTableTableManager(_db.attachedDatabase, _db.aiAuxSettings);
}

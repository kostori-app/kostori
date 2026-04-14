import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/settings.dart';
import 'package:kostori/network/api.dart';
import 'package:kostori/utils/init.dart';
import 'package:kostori/utils/io.dart';
import 'package:path_provider/path_provider.dart';

class Appdata with Init {
  Appdata._create();

  final Settings settings = Settings._create();

  bool _isSavingData = false;

  Future<void> saveData([bool sync = true]) async {
    while (_isSavingData) {
      await Future.delayed(const Duration(milliseconds: 20));
    }
    _isSavingData = true;
    try {
      var data = jsonEncode(toJson());
      var file = File(FilePath.join(App.dataPath, 'appdata.json'));
      await file.writeAsString(data);
    } finally {
      _isSavingData = false;
    }
  }

  Map<String, dynamic> toJson() {
    return {'settings': settings.toJson()};
  }

  static const _disableSync = [
    "proxy",
    "authorizationRequired",
    "customImageProcessing",
    "webdav",
  ];

  void syncData(Map<String, dynamic> data) {
    if (data['settings'] is Map) {
      final incoming = Map<String, dynamic>.from(data['settings'] as Map);
      for (final key in _disableSync) {
        incoming.remove(key);
      }
      final current = settings.toJson();
      current.addAll(incoming);
      settings.fromJson(current);
    }
    saveData();
  }

  var implicitData = <String, dynamic>{};

  void writeImplicitData() async {
    while (_isSavingData) {
      await Future.delayed(const Duration(milliseconds: 20));
    }
    _isSavingData = true;
    try {
      var file = File(FilePath.join(App.dataPath, 'implicitData.json'));
      await file.writeAsString(jsonEncode(implicitData));
    } finally {
      _isSavingData = false;
    }
  }

  Map<String, dynamic> _migrateSettings(Map<String, dynamic> oldJson) {
    const mapping = {
      'theme_mode': 'themeMode',
      'BangumiUserName': 'bangumiUserName',
      'AMOLED': 'amoled',
      'hAenable': 'haEnable',
      'deepleKey': 'deeplKey',
      'explore_sources_order': 'exploreSourcesOrder',
      'explore_pages_v2': 'explorePagesV2',
      'explore_horizontal_layout': 'exploreHorizontalLayout',
      'FavoriteTypeWish': 'favoriteTypeWish',
      'FavoriteTypeDoing': 'favoriteTypeDoing',
      'FavoriteTypeCollect': 'favoriteTypeCollect',
      'FavoriteTypeOnHold': 'favoriteTypeOnHold',
      'FavoriteTypeDropped': 'favoriteTypeDropped',
    };

    final newJson = Map<String, dynamic>.from(oldJson);
    mapping.forEach((oldKey, newKey) {
      if (newJson.containsKey(oldKey)) {
        newJson[newKey] = newJson[oldKey];
        newJson.remove(oldKey);
      }
    });
    return newJson;
  }

  @override
  Future<void> doInit() async {
    var dataPath = (await getApplicationSupportDirectory()).path;
    var file = File(FilePath.join(dataPath, 'appdata.json'));
    if (await file.exists()) {
      try {
        var json =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        if (json['settings'] is Map) {
          final migratedSettings = _migrateSettings(
            Map<String, dynamic>.from(json['settings'] as Map),
          );
          try {
            settings.fromJson(migratedSettings);
          } catch (e) {
            Log.error(
              "Appdata",
              "Settings parse error, falling back to defaults: $e",
            );
            final current = settings.toJson();
            for (final key in migratedSettings.keys) {
              try {
                current[key] = migratedSettings[key];
                settings.fromJson(Map<String, dynamic>.from(current));
              } catch (_) {
                current[key] = settings.toJson()[key];
              }
            }
          }
        }
      } catch (e) {
        Log.error("Appdata", "Failed to load appdata", e);
        file.deleteIgnoreError();
      }
    }
    if (settings.s.animeSourceListUrl.isEmpty) {
      settings.update((s) => s.copyWith(animeSourceListUrl: Api.kostoriConfig));
    }
    try {
      var implicitDataFile = File(FilePath.join(dataPath, 'implicitData.json'));
      if (await implicitDataFile.exists()) {
        implicitData = jsonDecode(await implicitDataFile.readAsString());
      }
    } catch (e) {
      Log.error("Appdata", "Failed to load implicit data", e);
      Log.info("Appdata", "Resetting implicit data");
      var implicitDataFile = File(FilePath.join(dataPath, 'implicitData.json'));
      implicitDataFile.deleteIgnoreError();
    }
  }
}

final appdata = Appdata._create();

class Settings with ChangeNotifier {
  Settings._create();

  SettingsData _state = const SettingsData();

  SettingsData get s => _state;

  /// 批量更新，freezed copyWith
  void update(SettingsData Function(SettingsData) updater) {
    final next = updater(_state);
    if (next == _state) return;
    _state = next;
    notifyListeners();
  }

  /// 从 json 全量替换（用于 doInit / syncData）
  void fromJson(Map<String, dynamic> json) {
    _state = SettingsData.fromJson(json);
    notifyListeners();
  }

  /// 导出 json（用于 saveData / syncData）
  Map<String, dynamic> toJson() => _state.toJson();

  dynamic operator [](String key) => _state.toJson()[key];

  void operator []=(String key, dynamic value) {
    final json = _state.toJson()..[key] = value;
    _state = SettingsData.fromJson(json);
    if (key != 'dataVersion') notifyListeners();
  }

  @override
  String toString() => _state.toString();
}

const defaultAnimeSourceUrl =
    "https://cdn.jsdelivr.net/gh/kostori-app/kostori-configs@latest/index.json";

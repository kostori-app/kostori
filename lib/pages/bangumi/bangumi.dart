import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/bangumi.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/network/api.dart';
import 'package:kostori/network/app_dio.dart';
import 'package:kostori/network/request.dart';

import 'package:kostori/foundation/log.dart';
import 'package:kostori/pages/bangumi/staff_response.dart';
import 'bangumi_item.dart';
import 'character_full_item.dart';
import 'character_response.dart';
import 'comment_response.dart';
import 'episode_item.dart';

class Bangumi {
  static Future<List<BangumiItem>> bangumiPostSearch(String keyword) async {
    List<BangumiItem> bangumiList = [];

    var params = <String, dynamic>{
      'keyword': keyword,
      'sort': 'rank',
      "filter": {
        "type": [2],
        "tag": [],
        "rank": [">0", "<=99999"],
        "nsfw": true
      },
    };

    try {
      final res = await Request().post(
          Api.formatUrl(Api.bangumiRankSearch, [100, 0]),
          data: params,
          options: Options(
              headers: bangumiHTTPHeader, contentType: 'application/json'));
      final jsonData = res.data;
      final jsonList = jsonData['data'];
      for (dynamic jsonItem in jsonList) {
        if (jsonItem is Map<String, dynamic>) {
          try {
            BangumiItem bangumiItem = BangumiItem.fromJson(jsonItem);
            if (bangumiItem.nameCn != '') {
              bangumiList.add(bangumiItem);
            }
          } catch (e, s) {
            Log.addLog(LogLevel.error, 'bangumi', '$e\n$s');
          }
        }
      }
    } catch (e, s) {
      Log.addLog(LogLevel.error, 'bangumi', '$e\n$s');
    }
    return bangumiList;
  }

  static Future<List<BangumiItem>> bangumiGetSearch(String keyword) async {
    List<BangumiItem> bangumiList = [];

    var key = keyword.replaceAll(
        RegExp(r'[^\w\s\u4e00-\u9fa5\u3040-\u309F\u30A0-\u30FF]'), '');
    try {
      var res = await Request().get(("${Api.bangumiBySearch}$key"),
          options: Options(
              headers: bangumiHTTPHeader, contentType: 'application/json'));
      if (res.data['code'] == 404) {
        await Future.delayed(Duration(seconds: 1));
        key = key.substring(0, 5);
        res = await Request().get(("${Api.bangumiBySearch}$key"),
            options: Options(
                headers: bangumiHTTPHeader, contentType: 'application/json'));
      }
      final jsonData = res.data;
      final jsonList = jsonData["list"];
      for (dynamic jsonItem in jsonList) {
        if (jsonItem is Map<String, dynamic>) {
          try {
            BangumiItem bangumiItem = BangumiItem.fromJson(jsonItem);
            if (bangumiItem.nameCn != '' && bangumiItem.type == 2) {
              bangumiList.add(bangumiItem);
            }
          } catch (e, s) {
            Log.addLog(LogLevel.error, 'bangumi', '$e\n$s');
          }
        }
      }
    } catch (e) {
      Log.addLog(LogLevel.error, 'bangumi', '$e');
    }
    return bangumiList;
  }

  static Future<BangumiItem?> getBangumiInfoByID(int id) async {
    try {
      final res = await Request().get(Api.bangumiInfoByID + id.toString(),
          options: Options(headers: bangumiHTTPHeader));
      return BangumiItem.fromJson(res.data);
    } catch (e) {
      Log.addLog(LogLevel.error, 'bangumi', '$e');
      return null;
    }
  }

  static Future<CommentResponse> getBangumiCommentsByID(int id,
      {int offset = 0}) async {
    CommentResponse commentResponse = CommentResponse.fromTemplate();
    try {
      final res = await Request().get(
          '${Api.bangumiInfoByIDNext}$id/comments?offset=$offset&limit=20',
          options: Options(headers: bangumiHTTPHeader));
      final jsonData = res.data;
      commentResponse = CommentResponse.fromJson(jsonData);
    } catch (e, s) {
      Log.addLog(LogLevel.error, 'bangumi', '$e\n$s');
    }
    return commentResponse;
  }

  static Future<CharacterResponse> getCharatersByID(int id) async {
    CharacterResponse characterResponse = CharacterResponse.fromTemplate();
    try {
      final res = await Request().get('${Api.bangumiInfoByID}$id/characters',
          options: Options(headers: bangumiHTTPHeader));
      final jsonData = res.data;
      characterResponse = CharacterResponse.fromJson(jsonData);
    } catch (e, s) {
      Log.addLog(LogLevel.error, 'bangumi', '$e\n$s');
    }
    return characterResponse;
  }

  //获取新番时间表
  static Future<List<List<BangumiItem>>> getCalendar() async {
    List<List<BangumiItem>> bangumiCalendar = [];
    try {
      var res = await Request().get(Api.bangumiCalendar,
          options: Options(headers: bangumiHTTPHeader));
      final jsonData = res.data;
      for (dynamic jsonDayList in jsonData) {
        List<BangumiItem> bangumiList = [];
        final jsonList = jsonDayList['items'];
        for (dynamic jsonItem in jsonList) {
          try {
            BangumiItem bangumiItem = BangumiItem.fromJson(jsonItem);
            if (bangumiItem.nameCn != '') {
              bangumiList.add(bangumiItem);
            }
          } catch (e, s) {
            Log.addLog(LogLevel.error, 'bangumi', '$e\n$s');
          }
        }
        bangumiCalendar.add(bangumiList);
      }
    } catch (e, s) {
      Log.addLog(LogLevel.error, 'bangumi', '$e\n$s');
    }
    return bangumiCalendar;
  }

  static Future<void> getCalendarData() async {
    try {
      var res = await getCalendar();
      for (dynamic jsonlist in res) {
        for (dynamic json in jsonlist) {
          var bangumiItem = json;
          BangumiManager().addBnagumiCalendar(bangumiItem);
        }
      }
    } catch (e, s) {
      Log.addLog(LogLevel.error, 'bangumi', '$e\n$s');
    }
  }

  static Future<void> getBangumiData() async {
    try {
      // 1. 发起网络请求
      final response = await Request().get(
        Api.bangumiDataUrl,
        options: Options(headers: bangumiHTTPHeader),
      );

      // 2. 校验响应数据格式
      final responseData = response.data;
      if (responseData is! Map<String, dynamic> ||
          responseData['items'] is! List) {
        Log.addLog(LogLevel.error, 'bangumi', 'Invalid API response structure');
        return;
      }

      // 3. 获取原始数据列表
      final itemsList = responseData['items'] as List;

      // 4. 空数据直接跳过
      if (itemsList.isEmpty) {
        Log.addLog(LogLevel.error, 'bangumi', 'Received empty data list');
        return;
      }

      // 5. 解析数据
      final bangumiDataList = parseBangumiDataList(itemsList);

      // 6. 截取最后100条数据
      final last100Items = bangumiDataList.length > 100
          ? bangumiDataList.sublist(bangumiDataList.length - 100)
          : bangumiDataList;

      // 7. 数据库操作（插入最后100条）
      await BangumiManager().addBulkBangumiData(last100Items);
    } on DioException catch (e, s) {
      Log.addLog(
          LogLevel.error, 'bangumi', 'Network error: ${e.message}\nStack: $s');
    } on FormatException catch (e, s) {
      Log.addLog(LogLevel.error, 'bangumi',
          'Data parsing failed: ${e.message}\nStack: $s');
    } catch (e, s) {
      Log.addLog(LogLevel.error, 'bangumi', 'Unexpected error: $e\nStack: $s');
    }
  }

// 解析方法保持不变
  static List<BangumiData> parseBangumiDataList(List<dynamic> jsonList) {
    return jsonList.map<BangumiData>((json) {
      try {
        return BangumiData.fromJson(json);
      } catch (e, s) {
        Log.addLog(
            LogLevel.error, 'bangumi', 'Failed to parse item: $e\nStack: $s');
        throw FormatException('Invalid BangumiData item');
      }
    }).toList();
  }

  static Future<void> checkBangumiData() async {
    try {
      var res = await Request().get(Api.checkBangumiDataUrl,
          options: Options(headers: bangumiHTTPHeader));
      final jsonData = res.data;
      if (appdata.settings['bangumiDataVer'] != jsonData['tag_name']) {
        Log.addLog(LogLevel.info, 'bangumi', '${jsonData['tag_name']}');
        await getBangumiData();
        SmartDialog.showToast(
            'bangumiData数据更新成功${appdata.settings['bangumiDataVer']} - ${jsonData['tag_name']}');
        Log.addLog(LogLevel.info, 'bangumi',
            '当前数据库版本: ${appdata.settings['bangumiDataVer']}, 远端数据库版本: ${jsonData['tag_name']}');
        appdata.settings['bangumiDataVer'] = jsonData['tag_name'];
        appdata.saveData();
        Log.addLog(LogLevel.info, 'bangumi',
            '更新完成,当前数据库版本: ${appdata.settings['bangumiDataVer']}');
      } else {
        SmartDialog.showToast(
            '当前bangumiData数据版本: ${appdata.settings['bangumiDataVer']} 已是最新');
      }
    } catch (e, s) {
      SmartDialog.showNotify(
          msg: 'bangumiData更新失败...', notifyType: NotifyType.error);
      Log.addLog(LogLevel.error, 'bangumi', '$e\n$s');
    }
  }

  static Future<void> resetBangumiData() async {
    try {
      var res = await Request().get(Api.checkBangumiDataUrl,
          options: Options(headers: bangumiHTTPHeader));
      final jsonData = res.data;
      Log.addLog(LogLevel.info, 'bangumi', '${jsonData['tag_name']}');
      BangumiManager().clearBangumiData();
      BangumiManager().clearBnagumiCalendar();
      Log.addLog(LogLevel.info, 'bangumi', 'Cleared bangumi data successfully');
      await getBangumiData();
      await getCalendarData();
      SmartDialog.showToast(
          'bangumiData数据更新成功${appdata.settings['bangumiDataVer']} - ${jsonData['tag_name']}');
      Log.addLog(LogLevel.info, 'bangumi',
          '当前数据库版本: ${appdata.settings['bangumiDataVer']}, 远端数据库版本: ${jsonData['tag_name']}');
      appdata.settings['bangumiDataVer'] = jsonData['tag_name'];
      appdata.saveData();
      Log.addLog(LogLevel.info, 'bangumi',
          '更新完成,当前数据库版本: ${appdata.settings['bangumiDataVer']}');
    } catch (e, s) {
      SmartDialog.showNotify(
          msg: 'bangumiData重置失败...', notifyType: NotifyType.error);
      Log.addLog(LogLevel.error, 'bangumi', '$e\n$s');
    }
  }

  static Future<StaffResponse> getBangumiStaffByID(int id) async {
    StaffResponse staffResponse = StaffResponse.fromTemplate();
    try {
      final res = await Request().get(
          Api.formatUrl(Api.bangumiStaffByIDNext, [id]),
          options: Options(headers: bangumiHTTPHeader));
      final jsonData = res.data;
      staffResponse = StaffResponse.fromJson(jsonData);
    } catch (e) {}
    return staffResponse;
  }

  static Future<EpisodeInfo> getBangumiEpisodeByID(int id, int episode) async {
    EpisodeInfo episodeInfo = EpisodeInfo.fromTemplate();
    var params = <String, dynamic>{
      'subject_id': id,
      'offset': episode - 1,
      'limit': 1
    };
    try {
      final res = await Request().get(Api.bangumiEpisodeByID,
          data: params, options: Options(headers: bangumiHTTPHeader));
      final jsonData = res.data['data'][0];
      episodeInfo = EpisodeInfo.fromJson(jsonData);
    } catch (e, s) {
      Log.addLog(LogLevel.error, 'bangumi', '$e\n$s');
    }
    return episodeInfo;
  }

  static Future<EpisodeCommentResponse> getBangumiCommentsByEpisodeID(
      int id) async {
    EpisodeCommentResponse commentResponse =
        EpisodeCommentResponse.fromTemplate();
    try {
      final res = await Request().get(
          '${Api.bangumiEpisodeByIDNext}$id/comments',
          options: Options(headers: bangumiHTTPHeader));
      final jsonData = res.data;
      commentResponse = EpisodeCommentResponse.fromJson(jsonData);
    } catch (e, s) {
      Log.addLog(LogLevel.error, 'bangumi', '$e\n$s');
    }
    return commentResponse;
  }

  static Future<CharacterCommentResponse> getCharacterCommentsByCharacterID(
      int id) async {
    CharacterCommentResponse commentResponse =
        CharacterCommentResponse.fromTemplate();
    try {
      final res = await Request().get(
          '${Api.bangumiCharacterByIDNext}$id/comments',
          options: Options(headers: bangumiHTTPHeader));
      final jsonData = res.data;
      commentResponse = CharacterCommentResponse.fromJson(jsonData);
    } catch (e, s) {
      Log.addLog(LogLevel.error, 'bangumi', '$e\n$s');
    }
    return commentResponse;
  }

  static Future<CharacterFullItem> getCharacterByCharacterID(int id) async {
    CharacterFullItem characterFullItem = CharacterFullItem.fromTemplate();
    try {
      final res = await Request().get(
          Api.formatUrl(Api.characterInfoByCharacterIDNext, [id]),
          options: Options(headers: bangumiHTTPHeader));
      final jsonData = res.data;
      characterFullItem = CharacterFullItem.fromJson(jsonData);
    } catch (e, s) {
      Log.addLog(LogLevel.error, 'bangumi', '$e\n$s');
    }
    return characterFullItem;
  }
}

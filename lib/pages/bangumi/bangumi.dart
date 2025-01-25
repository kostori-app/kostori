import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/bangumi.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/network/api.dart';
import 'package:kostori/network/app_dio.dart';
import 'package:kostori/network/request.dart';

import 'package:kostori/foundation/log.dart';
import 'bangumi_item.dart';
import 'character_response.dart';
import 'comment_response.dart';

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

  static Future<bool> getBangumiData() async {
    bool state = false;
    List<BangumiData> bangumiDataList = []; // 用于存储批量数据
    try {
      var res = await Request().get(Api.bangumiDataUrl,
          options: Options(headers: bangumiHTTPHeader));
      final jsonData = res.data;
      final jsonList = jsonData['items']; // 这里 jsonList 已经是一个 JSON 数组

      // 直接解析 JSON 列表
      bangumiDataList = (jsonList as List).map((json) {
        return BangumiData.fromJson(json); // 将 JSON 转换为 BangumiData 实例
      }).toList();

      // 批量插入到数据库
      await BangumiManager().addBulkBangumiData(bangumiDataList);

      state = true; // 数据处理成功
    } catch (e, s) {
      Log.addLog(LogLevel.error, 'bangumi', '$e\n$s');
    }
    return state;
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
}

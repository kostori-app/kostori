import 'dart:math';

import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/bangumi.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/network/api.dart';
import 'package:kostori/network/app_dio.dart';
import 'package:kostori/network/request.dart';

import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/bangumi/staff/staff_response.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/bangumi/character/character_full_item.dart';
import 'package:kostori/foundation/bangumi/character/character_response.dart';
import 'package:kostori/foundation/bangumi/comment/comment_response.dart';
import 'package:kostori/foundation/bangumi/episode/episode_item.dart';

class Bangumi {
  static Future<List<BangumiItem>> bangumiPostSearch(String keyword,
      {List<String> tags = const [],
      bool nsfw = false,
      String sort = 'rank',
      int offset = 0}) async {
    List<BangumiItem> bangumiList = [];

    var params = <String, dynamic>{
      'keyword': keyword,
      'sort': sort,
      "filter": {
        "type": [2],
        "tag": tags,
        "rank": (sort == 'rank') ? [">0", "<=99999"] : [">=0", "<=99999"],
        "nsfw": nsfw
      },
    };

    try {
      final res = await Request().post(
          Api.formatUrl(Api.bangumiRankSearch, [20, offset]),
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
            Log.addLog(LogLevel.error, 'bangumiPostSearch', '$e\n$s');
          }
        }
      }
    } catch (e, s) {
      Log.addLog(LogLevel.error, 'bangumiPostSearch', '$e\n$s');
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
            Log.addLog(LogLevel.error, 'bangumiGetSearch', '$e\n$s');
          }
        }
      }
    } catch (e, s) {
      Log.addLog(LogLevel.error, 'bangumiGetSearch', '$e\n$s');
    }
    return bangumiList;
  }

  static Future<List<BangumiItem>> combinedBangumiSearch(String keyword) async {
    try {
      final results = await Future.wait([
        bangumiPostSearch(keyword).timeout(const Duration(seconds: 10)),
        bangumiGetSearch(keyword).timeout(const Duration(seconds: 10)),
      ]).catchError((e, s) {
        Log.addLog(LogLevel.warning, 'bangumi', 'Partial search failed: $e');
        return [<BangumiItem>[], <BangumiItem>[]];
      });

      final combinedList = [...results[0], ...results[1]];
      final uniqueItems = <int, BangumiItem>{};

      // 计算字符匹配度（适用于中文、日文、英文等）
      int calculateCharacterMatchScore(String keyword, String text) {
        if (text.isEmpty) return 0;

        final keywordChars =
            keyword.runes.map((rune) => String.fromCharCode(rune)).toList();
        final textChars =
            text.runes.map((rune) => String.fromCharCode(rune)).toList();

        int matchCount = 0;
        for (final char in keywordChars) {
          if (textChars.contains(char)) {
            matchCount++;
          }
        }

        // 返回匹配字符数占总字符数的百分比（0-100）
        return (matchCount / keywordChars.length * 100).round();
      }

      // 综合计算项目的匹配度
      int calculateItemMatchScore(BangumiItem item) {
        final namecn = item.nameCn;
        final name = item.name;

        // 计算两个字段的匹配度
        final scoreNamecn = calculateCharacterMatchScore(keyword, namecn);
        final scoreName = calculateCharacterMatchScore(keyword, name);

        // 取最高分
        return max(scoreNamecn, scoreName);
      }

      // 排序逻辑：先按匹配度降序，再按评分降序
      combinedList
        ..sort((a, b) {
          final matchScoreA = calculateItemMatchScore(a);
          final matchScoreB = calculateItemMatchScore(b);

          if (matchScoreA != matchScoreB) {
            return matchScoreB.compareTo(matchScoreA); // 匹配度高的在前
          }
          return b.score.compareTo(a.score); // 评分高的在前
        })
        ..forEach((item) {
          uniqueItems.putIfAbsent(item.id, () => item);
        });

      return uniqueItems.values.toList();
    } catch (e, s) {
      Log.addLog(LogLevel.error, 'bangumi', 'Combined search failed: $e\n$s');
      return [];
    }
  }

  static Future<BangumiItem?> getBangumiInfoByID(int id) async {
    try {
      final res = await Request().get(Api.bangumiInfoByID + id.toString(),
          options: Options(headers: bangumiHTTPHeader));
      return BangumiItem.fromJson(res.data);
    } catch (e, s) {
      Log.addLog(LogLevel.error, 'getBangumiInfoByID', '$e\n$s');
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
      BangumiManager().clearBnagumiCalendar();
      for (dynamic jsonlist in res) {
        for (dynamic json in jsonlist) {
          var bangumiItem = json;
          BangumiManager().addBangumiCalendar(bangumiItem);
        }
      }
    } catch (e, s) {
      Log.addLog(LogLevel.error, 'bangumiGetCalendarData', '$e\n$s');
    }
  }

  static Future<void> getBangumiInfoBind(int id) async {
    try {
      var res = await getBangumiInfoByID(id);
      // Log.addLog(LogLevel.info, 'bangumiGetBangumiInfoBind', res.toString());
      if (res != null) {
        BangumiManager().addBnagumiBinding(res);
      }
    } catch (e, s) {
      Log.addLog(LogLevel.error, 'bangumiGetBangumiInfoBind', '$e\n$s');
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
        Log.addLog(
            LogLevel.info, 'checkBangumiData', '${jsonData['tag_name']}');
        BangumiManager().clearBangumiData();
        await getBangumiData();
        App.rootContext.showMessage(
            message:
                'bangumiData数据更新成功${appdata.settings['bangumiDataVer']} -> ${jsonData['tag_name']}');
        Log.addLog(LogLevel.info, 'checkBangumiData',
            '当前数据库版本: ${appdata.settings['bangumiDataVer']}, 远端数据库版本: ${jsonData['tag_name']}');
        appdata.settings['bangumiDataVer'] = jsonData['tag_name'];
        appdata.saveData();
        Log.addLog(LogLevel.info, 'bangumiDataVer',
            '更新完成,当前数据库版本: ${appdata.settings['bangumiDataVer']}');
      } else {
        App.rootContext.showMessage(
            message:
                '当前bangumiData数据版本: ${appdata.settings['bangumiDataVer']} 已是最新');
      }
    } catch (e, s) {
      App.rootContext.showMessage(message: 'bangumiData更新失败...');
      Log.addLog(LogLevel.error, 'checkBangumiData', '$e\n$s');
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
      App.rootContext.showMessage(
          message:
              'bangumiData数据更新成功${appdata.settings['bangumiDataVer']} - ${jsonData['tag_name']}');
      Log.addLog(LogLevel.info, 'bangumi',
          '当前数据库版本: ${appdata.settings['bangumiDataVer']}, 远端数据库版本: ${jsonData['tag_name']}');
      appdata.settings['bangumiDataVer'] = jsonData['tag_name'];
      appdata.saveData();
      Log.addLog(LogLevel.info, 'bangumi',
          '更新完成,当前数据库版本: ${appdata.settings['bangumiDataVer']}');
    } catch (e, s) {
      App.rootContext.showMessage(message: 'bangumiData重置失败...');
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

  static Future<List<EpisodeInfo>> getBangumiEpisodeAllByID(int id) async {
    try {
      var params = <String, dynamic>{'subject_id': id};
      final res = await Request().get(
        Api.bangumiEpisodeByID,
        data: params,
        options: Options(headers: bangumiHTTPHeader),
      );

      final List<dynamic> jsonDataList = res.data['data'] ?? [];
      if (res.data['data'] != null) {
        BangumiManager().addBnagumiAllEpInfo(id, res.data['data']);
      }

      return jsonDataList.map((json) => EpisodeInfo.fromJson(json)).toList();
    } catch (e, s) {
      Log.addLog(LogLevel.error, 'bangumiGetBangumiEpisodeAllByID', '$e\n$s');
      return []; // 返回空列表而不是null
    }
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

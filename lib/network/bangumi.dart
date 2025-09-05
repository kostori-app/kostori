// ignore_for_file: use_build_context_synchronously, empty_catches

import 'dart:math';

import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/bangumi.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/bangumi/bangumi_subject_relations_item.dart';
import 'package:kostori/foundation/bangumi/character/character_casts_item.dart';
import 'package:kostori/foundation/bangumi/character/character_full_item.dart';
import 'package:kostori/foundation/bangumi/character/character_response.dart';
import 'package:kostori/foundation/bangumi/comment/comment_response.dart';
import 'package:kostori/foundation/bangumi/episode/episode_item.dart';
import 'package:kostori/foundation/bangumi/reviews/reviews_comments_item.dart';
import 'package:kostori/foundation/bangumi/reviews/reviews_info_item.dart';
import 'package:kostori/foundation/bangumi/reviews/reviews_response.dart';
import 'package:kostori/foundation/bangumi/staff/staff_response.dart';
import 'package:kostori/foundation/bangumi/topics/topics_info_item.dart';
import 'package:kostori/foundation/bangumi/topics/topics_response.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/network/api.dart';
import 'package:kostori/network/app_dio.dart';

class Bangumi {
  static Future<List<BangumiItem>> bangumiPostSearch(
    String keyword, {
    List<String> tags = const [],
    bool nsfw = false,
    String sort = 'rank',
    int offset = 0,
    String airDate = '',
    String endDate = '',
  }) async {
    List<BangumiItem> bangumiList = [];

    var params = <String, dynamic>{
      'keyword': keyword,
      'sort': sort,
      "filter": {
        "type": [2],
        "tag": tags,
        "rank": (sort == 'rank') ? [">0", "<=99999"] : [">=0", "<=99999"],
        "air_date": [
          if (airDate.isNotEmpty) '>=$airDate',
          if (endDate.isNotEmpty) '<$endDate',
        ],
        "nsfw": nsfw,
      },
    };

    try {
      final res = await AppDio().request(
        Api.formatUrl(Api.bangumiRankSearch, [20, offset]),
        data: params,
        options: Options(
          method: 'POST',
          headers: bangumiHTTPHeader,
          contentType: 'application/json',
        ),
      );
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
      RegExp(r'[^\w\s\u4e00-\u9fa5\u3040-\u309F\u30A0-\u30FF]'),
      '',
    );
    try {
      var res = await AppDio().request(
        ("${Api.bangumiBySearch}$key"),
        options: Options(
          method: 'GET',
          headers: bangumiHTTPHeader,
          contentType: 'application/json',
        ),
      );
      if (res.data['code'] == 404) {
        await Future.delayed(Duration(seconds: 1));
        key = key.substring(0, 5);
        res = await AppDio().get(
          ("${Api.bangumiBySearch}$key"),
          options: Options(
            headers: bangumiHTTPHeader,
            contentType: 'application/json',
          ),
        );
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
      final results =
          await Future.wait([
            bangumiPostSearch(keyword).timeout(const Duration(seconds: 5)),
            bangumiGetSearch(keyword).timeout(const Duration(seconds: 5)),
          ]).catchError((e, s) {
            Log.addLog(
              LogLevel.warning,
              'bangumi',
              'Partial search failed: $e',
            );
            return [<BangumiItem>[], <BangumiItem>[]];
          });

      final combinedList = [...results[0], ...results[1]];
      final uniqueItems = <int, BangumiItem>{};

      // 计算字符匹配度（适用于中文、日文、英文等）
      int calculateCharacterMatchScore(String keyword, String text) {
        if (text.isEmpty) return 0;

        final keywordChars = keyword.runes
            .map((rune) => String.fromCharCode(rune))
            .toList();
        final textChars = text.runes
            .map((rune) => String.fromCharCode(rune))
            .toList();

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
      final res = await AppDio().request(
        Api.bangumiInfoByID + id.toString(),
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );
      return BangumiItem.fromJson(res.data);
    } catch (e, s) {
      Log.addLog(LogLevel.error, 'getBangumiInfoByID', '$e\n$s');
      return null;
    }
  }

  static Future<List<BangumiSRI>> getBangumiSRIByID(int id) async {
    List<BangumiSRI> bangumiList = [];
    try {
      final res = await AppDio().request(
        '${Api.bangumiInfoByID}$id/subjects',
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );
      final jsonList = res.data;
      for (dynamic jsonItem in jsonList) {
        if (jsonItem is Map<String, dynamic>) {
          try {
            BangumiSRI bangumiSRI = BangumiSRI.fromJson(jsonItem);
            if (bangumiSRI.type == 2) {
              bangumiList.add(bangumiSRI);
            }
          } catch (e, s) {
            Log.addLog(LogLevel.error, 'getBangumiSRIByID', '$e\n$s');
          }
        }
      }
    } catch (e, s) {
      Log.addLog(LogLevel.error, 'getBangumiSRIByID', '$e\n$s');
    }
    return bangumiList;
  }

  static Future<CommentResponse> getBangumiCommentsByID(
    int id, {
    int offset = 0,
  }) async {
    CommentResponse commentResponse = CommentResponse.fromTemplate();
    try {
      final res = await AppDio().request(
        '${Api.bangumiInfoByIDNext}$id/comments?offset=$offset&limit=20',
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );
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
      final res = await AppDio().request(
        '${Api.bangumiInfoByID}$id/characters',
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );
      final jsonData = res.data;
      characterResponse = CharacterResponse.fromJson(jsonData);
    } catch (e) {
      Log.addLog(LogLevel.error, 'getCharatersByID', '$e');
    }
    return characterResponse;
  }

  static Future<TopicsResponse> getTopicsByID(int id, {int offset = 0}) async {
    TopicsResponse topicsResponse = TopicsResponse.fromTemplate();
    var params = <String, dynamic>{'offset': offset, 'limit': 20};
    try {
      final res = await AppDio().request(
        Api.formatUrl(Api.bangumiTopicsByIDNext, [id]),
        queryParameters: params,
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );
      final jsonData = res.data['data'];
      topicsResponse = TopicsResponse.fromJson(jsonData);
    } catch (e) {
      Log.addLog(LogLevel.error, 'getTopicsByID', '$e');
    }
    return topicsResponse;
  }

  static Future<TopicsInfoItem?> getTopicsInfoByID(int id) async {
    try {
      final res = await AppDio().request(
        '${Api.bangumiTopicsInfoByIDNext}$id',
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );
      final jsonData = res.data;
      if (res.statusCode == 404) return null;
      TopicsInfoItem topicsInfoItem = TopicsInfoItem.fromJson(jsonData);
      return topicsInfoItem;
    } catch (e) {
      Log.addLog(LogLevel.error, 'getTopicsInfoByID', '$e');
    }
    return null;
  }

  static Future<List<TopicsInfoItem>> getTopicsLatestByID({
    int offset = 0,
  }) async {
    List<TopicsInfoItem> topicsInfoItems = [];
    var params = <String, dynamic>{'offset': offset, 'limit': 100};
    try {
      final res = await AppDio().request(
        Api.bangumiTopicsLatestByIDNext,
        queryParameters: params,
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );
      final jsonData = res.data['data'];
      if (res.statusCode == 200 && jsonData is List) {
        for (dynamic json in jsonData) {
          try {
            TopicsInfoItem topicsInfoItem = TopicsInfoItem.fromJson(json);
            if (topicsInfoItem.subject.type == 2) {
              topicsInfoItems.add(topicsInfoItem);
            }
          } catch (e, s) {
            Log.addLog(LogLevel.error, 'getTopicsLatestByID', '$e\n$s');
          }
        }
      }
    } catch (e) {
      Log.addLog(LogLevel.error, 'getTopicsLatestByID', '$e');
    }
    return topicsInfoItems;
  }

  static Future<List<TopicsInfoItem>> getTopicsTrendingByID({
    int offset = 0,
  }) async {
    List<TopicsInfoItem> topicsInfoItems = [];
    var params = <String, dynamic>{'offset': offset, 'limit': 100};
    try {
      final res = await AppDio().request(
        Api.bangumiTopicsTrendingByIDNext,
        queryParameters: params,
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );
      final jsonData = res.data['data'];
      if (res.statusCode == 200 && jsonData is List) {
        for (dynamic json in jsonData) {
          try {
            TopicsInfoItem topicsInfoItem = TopicsInfoItem.fromJson(json);
            if (topicsInfoItem.subject.type == 2) {
              topicsInfoItems.add(topicsInfoItem);
            }
          } catch (e, s) {
            Log.addLog(LogLevel.error, 'getTopicsLatestByID', '$e\n$s');
          }
        }
      }
    } catch (e) {
      Log.addLog(LogLevel.error, 'getTopicsLatestByID', '$e');
    }
    return topicsInfoItems;
  }

  static Future<ReviewsResponse> getReviewsByID(
    int id, {
    int offset = 0,
  }) async {
    ReviewsResponse reviewsResponse = ReviewsResponse.fromTemplate();
    var params = <String, dynamic>{'offset': offset, 'limit': 20};
    try {
      final res = await AppDio().request(
        Api.formatUrl(Api.bangumiReviewsByIDNext, [id]),
        queryParameters: params,
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );
      final jsonData = res.data['data'];
      reviewsResponse = ReviewsResponse.fromJson(jsonData);
    } catch (e) {
      Log.addLog(LogLevel.error, 'getReviewsByID', '$e');
    }
    return reviewsResponse;
  }

  static Future<ReviewsInfoItem?> getReviewsInfoByID(int id) async {
    try {
      final res = await AppDio().request(
        '${Api.bangumiReviewsInfoByIDNext}$id',
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );
      final jsonData = res.data;
      if (res.statusCode == 200) {
        ReviewsInfoItem reviewsInfoItem = ReviewsInfoItem.fromJson(jsonData);
        return reviewsInfoItem;
      }
    } catch (e) {
      Log.addLog(LogLevel.error, 'getReviewsInfoByID', '$e');
    }
    return null;
  }

  static Future<List<ReviewsCommentsItem>> getReviewsCommentsByID(
    int id,
  ) async {
    List<ReviewsCommentsItem> reviewsCommentsItem = [];
    try {
      final res = await AppDio().request(
        Api.formatUrl(Api.bangumiReviewsCommentsByIDNext, [id]),
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );
      final jsonData = res.data;
      if (res.statusCode == 200 && jsonData is List) {
        for (var json in jsonData) {
          try {
            reviewsCommentsItem.add(ReviewsCommentsItem.fromJson(json));
          } catch (e) {
            Log.addLog(LogLevel.error, 'getReviewsCommentsByID', '$e');
          }
        }
      }
    } catch (e) {
      Log.addLog(LogLevel.error, 'getReviewsCommentsByID', '$e');
    }
    return reviewsCommentsItem;
  }

  static Future<List<BangumiItem>> getReviewsSubjectsByID(int id) async {
    List<BangumiItem> bangumiReviewsSubjects = [];
    try {
      var res = await AppDio().request(
        Api.formatUrl(Api.bangumiReviewsSubjectsByIDNext, [id]),
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );
      final jsonData = res.data;
      for (dynamic json in jsonData) {
        try {
          BangumiItem bangumiItem = BangumiItem.fromJson(json);
          if (bangumiItem.type == 2) {
            bangumiReviewsSubjects.add(bangumiItem);
          }
        } catch (e, s) {
          Log.addLog(LogLevel.error, 'getReviewsSubjectsByID', '$e\n$s');
        }
      }
    } catch (e, s) {
      Log.addLog(LogLevel.error, 'getReviewsSubjectsByID', '$e\n$s');
    }
    return bangumiReviewsSubjects;
  }

  //获取新番时间表
  static Future<List<List<BangumiItem>>> getCalendar() async {
    List<List<BangumiItem>> bangumiCalendar = [];
    try {
      var res = await AppDio().request(
        Api.bangumiCalendar,
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );
      final jsonData = res.data;
      BangumiManager().clearBnagumiCalendar();
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
            Log.addLog(LogLevel.error, 'getCalendar', '$e\n$s');
          }
        }
        bangumiCalendar.add(bangumiList);
      }
    } catch (e, s) {
      Log.addLog(LogLevel.error, 'getCalendar', '$e\n$s');
    }
    return bangumiCalendar;
  }

  static Future<void> getCalendarData() async {
    try {
      var res = await getCalendar();

      for (dynamic jsonlist in res) {
        BangumiManager().batchAddBangumiCalendar(jsonlist);
      }
    } catch (e, s) {
      Log.addLog(LogLevel.error, 'bangumiGetCalendarData', '$e\n$s');
    }
  }

  static Future<void> getBangumiInfoBind(int id) async {
    try {
      var res = await getBangumiInfoByID(id);
      if (res != null) {
        BangumiManager().addBangumiBinding(res);
        Log.addLog(LogLevel.info, 'bangumiGetBangumiInfoBind', '绑定$id成功');
      }
    } catch (e, s) {
      Log.addLog(LogLevel.error, 'bangumiGetBangumiInfoBind', '$e\n$s');
    }
  }

  static Future<void> getBangumiData() async {
    try {
      final response = await AppDio().request(
        Api.bangumiDataUrl,
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );

      final responseData = response.data;
      if (responseData is! Map<String, dynamic> ||
          responseData['items'] is! List) {
        Log.addLog(LogLevel.error, 'bangumi', 'Invalid API response structure');
        return;
      }

      final itemsList = responseData['items'] as List;

      if (itemsList.isEmpty) {
        Log.addLog(LogLevel.error, 'bangumi', 'Received empty data list');
        return;
      }

      final bangumiDataList = parseBangumiDataList(itemsList);

      final last100Items = bangumiDataList.length > 200
          ? bangumiDataList.sublist(bangumiDataList.length - 200)
          : bangumiDataList;
      BangumiManager().clearBangumiData();
      BangumiManager().batchAddBangumiData(last100Items);
    } on DioException catch (e, s) {
      Log.addLog(
        LogLevel.error,
        'getBangumiData',
        'Network error: ${e.message}\nStack: $s',
      );
    } on FormatException catch (e, s) {
      Log.addLog(
        LogLevel.error,
        'getBangumiData',
        'Data parsing failed: ${e.message}\nStack: $s',
      );
    } catch (e, s) {
      Log.addLog(
        LogLevel.error,
        'getBangumiData',
        'Unexpected error: $e\nStack: $s',
      );
    }
  }

  static List<BangumiData> parseBangumiDataList(List<dynamic> jsonList) {
    return jsonList.map<BangumiData>((json) {
      try {
        return BangumiData.fromJson(json);
      } catch (e, s) {
        Log.addLog(
          LogLevel.error,
          'parseBangumiDataList',
          'Failed to parse item: $e\nStack: $s',
        );
        throw FormatException('Invalid BangumiData item');
      }
    }).toList();
  }

  static Future<void> checkBangumiData() async {
    try {
      var res = await AppDio().request(
        Api.checkBangumiDataUrl,
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );
      final jsonData = res.data;
      if (appdata.settings['bangumiDataVer'] != jsonData['tag_name']) {
        Log.addLog(
          LogLevel.info,
          'checkBangumiData',
          '${jsonData['tag_name']}',
        );

        await getBangumiData();
        App.rootContext.showMessage(
          message:
              'bangumiData数据更新成功${appdata.settings['bangumiDataVer']} -> ${jsonData['tag_name']}',
        );
        Log.addLog(
          LogLevel.info,
          'checkBangumiData',
          '当前数据库版本: ${appdata.settings['bangumiDataVer']}, 远端数据库版本: ${jsonData['tag_name']}',
        );
        appdata.settings['bangumiDataVer'] = jsonData['tag_name'];
        appdata.saveData();
        Log.addLog(
          LogLevel.info,
          'bangumiDataVer',
          '更新完成,当前数据库版本: ${appdata.settings['bangumiDataVer']}',
        );
      } else {
        App.rootContext.showMessage(
          message:
              '当前bangumiData数据版本: ${appdata.settings['bangumiDataVer']} 已是最新',
        );
      }
    } catch (e, s) {
      App.rootContext.showMessage(message: 'bangumiData更新失败...');
      Log.addLog(LogLevel.error, 'checkBangumiData', '$e\n$s');
    }
  }

  static Future<void> resetBangumiData() async {
    try {
      var res = await AppDio().request(
        Api.checkBangumiDataUrl,
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );
      final jsonData = res.data;
      Log.addLog(LogLevel.info, 'bangumi', '${jsonData['tag_name']}');
      appdata.settings['getBangumiAllEpInfoTime'] = null;
      Log.addLog(LogLevel.info, 'bangumi', 'Cleared bangumi data successfully');
      await getBangumiData();
      await getCalendarData();
      App.rootContext.showMessage(
        message:
            'bangumiData数据更新成功${appdata.settings['bangumiDataVer']} - ${jsonData['tag_name']}',
      );
      Log.addLog(
        LogLevel.info,
        'bangumi',
        '当前数据库版本: ${appdata.settings['bangumiDataVer']}, 远端数据库版本: ${jsonData['tag_name']}',
      );
      appdata.settings['bangumiDataVer'] = jsonData['tag_name'];
      appdata.saveData();
      Log.addLog(
        LogLevel.info,
        'bangumi',
        '更新完成,当前数据库版本: ${appdata.settings['bangumiDataVer']}',
      );
    } catch (e, s) {
      App.rootContext.showMessage(message: 'bangumiData重置失败...');
      Log.addLog(LogLevel.error, 'bangumi', '$e\n$s');
    }
  }

  static Future<StaffResponse> getBangumiStaffByID(int id) async {
    StaffResponse staffResponse = StaffResponse.fromTemplate();
    try {
      final res = await AppDio().request(
        Api.formatUrl(Api.bangumiStaffByIDNext, [id]),
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );
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
      'limit': 1,
    };
    try {
      final res = await AppDio().request(
        Api.bangumiEpisodeByID,
        queryParameters: params,
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );
      final jsonData = res.data['data'][0];
      episodeInfo = EpisodeInfo.fromJson(jsonData);
    } catch (e, s) {
      Log.addLog(LogLevel.error, 'getBangumiEpisodeByID', '$e\n$s');
    }
    return episodeInfo;
  }

  static Future<EpisodeInfo> getBangumiEpisodeByEpID(int id) async {
    EpisodeInfo episodeInfo = EpisodeInfo.fromTemplate();
    var params = <String, dynamic>{'episode_id': id};
    try {
      final res = await AppDio().request(
        Api.bangumiEpisodeByID,
        queryParameters: params,
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );
      final jsonData = res.data['data'][0];
      episodeInfo = EpisodeInfo.fromJson(jsonData);
    } catch (e, s) {
      Log.addLog(LogLevel.error, 'getBangumiEpisodeByEpID', '$e\n$s');
    }
    return episodeInfo;
  }

  static Future<List<EpisodeInfo>> getBangumiEpisodeAllByID(int id) async {
    try {
      var params = <String, dynamic>{'subject_id': id};
      final res = await AppDio().request(
        Api.bangumiEpisodeByID,
        queryParameters: params,
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
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
    int id,
  ) async {
    EpisodeCommentResponse commentResponse =
        EpisodeCommentResponse.fromTemplate();
    try {
      final res = await AppDio().request(
        '${Api.bangumiEpisodeByIDNext}$id/comments',
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );
      final jsonData = res.data;
      commentResponse = EpisodeCommentResponse.fromJson(jsonData);
    } catch (e, s) {
      Log.addLog(LogLevel.error, 'getBangumiCommentsByEpisodeID', '$e\n$s');
    }
    return commentResponse;
  }

  static Future<CharacterCommentResponse> getCharacterCommentsByCharacterID(
    int id,
  ) async {
    CharacterCommentResponse commentResponse =
        CharacterCommentResponse.fromTemplate();
    try {
      final res = await AppDio().request(
        '${Api.bangumiCharacterByIDNext}$id/comments',
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );
      final jsonData = res.data;
      commentResponse = CharacterCommentResponse.fromJson(jsonData);
    } catch (e, s) {
      Log.addLog(LogLevel.error, 'getCharacterCommentsByCharacterID', '$e\n$s');
    }
    return commentResponse;
  }

  static Future<CharacterFullItem> getCharacterByCharacterID(int id) async {
    CharacterFullItem characterFullItem = CharacterFullItem.fromTemplate();
    try {
      final res = await AppDio().request(
        Api.formatUrl(Api.characterInfoByCharacterIDNext, [id]),
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );
      final jsonData = res.data;
      characterFullItem = CharacterFullItem.fromJson(jsonData);
    } catch (e, s) {
      Log.addLog(LogLevel.error, 'getCharacterByCharacterID', '$e\n$s');
    }
    return characterFullItem;
  }

  static Future<List<CharacterCastsItem>> getCharacterCastsByCharacterID(
    int id, {
    int offset = 0,
  }) async {
    List<CharacterCastsItem> characterCastsItems = [];
    var params = <String, dynamic>{
      'subjectType': 2,
      'limit': 100,
      'offset': offset,
    };
    try {
      final res = await AppDio().request(
        Api.formatUrl(Api.characterCastsByCharacterIDNext, [id]),
        queryParameters: params,
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );
      final jsonData = res.data['data'];
      for (dynamic jsonItem in jsonData) {
        CharacterCastsItem characterCastsItem = CharacterCastsItem.fromJson(
          jsonItem,
        );
        if (characterCastsItem.subject.type == 2) {
          characterCastsItems.add(characterCastsItem);
        }
      }
    } catch (e, s) {
      Log.addLog(LogLevel.error, 'getCharacterCastsByCharacterID', '$e\n$s');
    }
    return characterCastsItems;
  }

  static Future<Map<bool, BangumiItem?>> isBangumiExists(int id) async {
    try {
      final res = await AppDio().request(
        Api.bangumiInfoByID + id.toString(),
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );
      if (res.data['type'] == 2) {
        return {true: BangumiItem.fromJson(res.data)};
      }
    } catch (e) {}
    return {false: null};
  }

  static Future<String> getBangumiUserAvatarByName(String name) async {
    try {
      final res = await AppDio().request(
        '${Api.bangumiUserAvatar}$name',
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );
      final avatar = res.data["avatar"]["large"];
      return avatar;
    } catch (e) {
      Log.addLog(LogLevel.error, 'getBangumiUserAvatarByName', '$e');
    }
    return '';
  }

  static Future<List<BangumiItem>> getBangumiUseFavoritesByName({
    String name = '',
    int type = 2,
    int subjectType = 2,
    int limit = 100,
    int offset = 0,
  }) async {
    List<BangumiItem> bangumiList = [];
    var params = <String, dynamic>{
      'type': type,
      'subjectType': subjectType,
      'limit': limit,
      'offset': offset,
    };
    try {
      final res = await AppDio().request(
        Api.formatUrl(Api.bangumiUserFavoritesSubjectByNameNext, [name]),
        queryParameters: params,
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );
      final jsonData = res.data;
      final jsonList = jsonData['data'];
      for (dynamic jsonItem in jsonList) {
        bangumiList.add(BangumiItem.fromJson(jsonItem));
      }
    } catch (e) {
      Log.addLog(LogLevel.error, 'getBangumiUseFavorites', '$e');
    }
    return bangumiList;
  }

  static Future<List<BangumiItem>> getBangumiTrendsList({
    int type = 2,
    int limit = 24,
    int offset = 0,
  }) async {
    List<BangumiItem> bangumiList = [];
    var params = <String, dynamic>{
      'type': type,
      'limit': limit,
      'offset': offset,
    };
    try {
      final res = await AppDio().request(
        Api.bangumiTrendingByNext,
        queryParameters: params,
        options: Options(
          method: 'GET',
          headers: bangumiHTTPHeader,
          contentType: 'application/json',
        ),
      );
      final jsonData = res.data;
      final jsonList = jsonData['data'];
      for (dynamic jsonItem in jsonList) {
        if (jsonItem is Map<String, dynamic>) {
          bangumiList.add(BangumiItem.fromJson(jsonItem['subject']));
        }
      }
    } catch (e, s) {
      Log.addLog(LogLevel.error, 'getBangumiTrendsList', '$e\n$s');
    }
    return bangumiList;
  }
}

// ignore_for_file: use_build_context_synchronously, empty_catches

import 'dart:math';

import 'package:kostori/database/bangumi.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/bangumi/bangumi_subject_relations_item.dart';
import 'package:kostori/foundation/bangumi/character/character_casts_item.dart';
import 'package:kostori/foundation/bangumi/character/character_full_item.dart';
import 'package:kostori/foundation/bangumi/character/character_response.dart';
import 'package:kostori/foundation/bangumi/comment/comment_response.dart';
import 'package:kostori/foundation/bangumi/person_work_item.dart';
import 'package:kostori/foundation/bangumi/episode/episode_item.dart';
import 'package:kostori/foundation/bangumi/reviews/reviews_comments_item.dart';
import 'package:kostori/foundation/bangumi/reviews/reviews_info_item.dart';
import 'package:kostori/foundation/bangumi/reviews/reviews_response.dart';
import 'package:kostori/foundation/bangumi/staff/staff_response.dart';
import 'package:kostori/foundation/bangumi/topics/topics_info_item.dart';
import 'package:kostori/foundation/bangumi/topics/topics_response.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/init.dart';
import 'package:kostori/network/api.dart';
import 'package:kostori/network/app_dio.dart';
import 'package:kostori/network/bangumi_token_interceptor.dart';
import 'package:kostori/utils/utils.dart';

class Bangumi {
  static final instance = Bangumi._();

  Bangumi._() {
    _dio.interceptors.add(BangumiTokenInterceptor(_dio));
  }

  BangumiManager get manager => providerContainer.read(bangumiManagerProvider);

  final _dio = AppDio();

  Future<List<BangumiItem>> bangumiPostSearch(
    String keyword, {
    List<String> tags = const [],
    bool? nsfw,
    String sort = 'rank',
    int offset = 0,
    String airDate = '',
    String endDate = '',
  }) async {
    List<BangumiItem> bangumiList = [];

    // 未显式指定时读取设置（bangumiShowNsfw，默认开启）
    final effectiveNsfw =
        nsfw ?? (appdata.implicitData['bangumiShowNsfw'] as bool? ?? true);

    var data = <String, dynamic>{
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
        "nsfw": effectiveNsfw,
      },
    };

    try {
      final res = await _dio.request(
        Api.formatUrl(Api.bangumiRankSearch, [20, offset]),
        data: data,
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
            NetLog.error('bangumiPostSearch', '$e\n$s');
          }
        }
      }
    } catch (e, s) {
      NetLog.error('bangumiPostSearch', '$e\n$s');
    }
    return bangumiList;
  }

  Future<List<BangumiItem>> bangumiGetSearch(String keyword) async {
    List<BangumiItem> bangumiList = [];

    var key = keyword.replaceAll(
      RegExp(r'[^\w\s\u4e00-\u9fa5\u3040-\u309F\u30A0-\u30FF]'),
      '',
    );
    try {
      var res = await _dio.request(
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
        res = await _dio.get(
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
            NetLog.error('bangumiGetSearch', '$e\n$s');
          }
        }
      }
    } catch (e, s) {
      NetLog.error('bangumiGetSearch', '$e\n$s');
    }
    return bangumiList;
  }

  Future<List<BangumiItem>> combinedBangumiSearch(String keyword) async {
    try {
      final results =
          await Future.wait([
            bangumiPostSearch(keyword).timeout(const Duration(seconds: 5)),
            bangumiGetSearch(keyword).timeout(const Duration(seconds: 5)),
          ]).catchError((e, s) {
            NetLog.warning('bangumi', 'Partial search failed: $e');
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
      NetLog.error('bangumi', 'Combined search failed: $e\n$s');
      return [];
    }
  }

  Future<List<CharacterActor>> postCharactersSearchByStringNext({
    required String keyword,
    int offset = 0,
    bool nsfw = true,
  }) async {
    List<CharacterActor> characterList = [];
    final data = <String, dynamic>{
      'keyword': keyword,
      "filter": {"nsfw": nsfw},
    };
    final params = <String, dynamic>{'offset': offset, 'limit': 20};
    try {
      final res = await _dio.request(
        Api.charactersByStringNext,
        data: data,
        queryParameters: params,
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
            CharacterActor characterItem = CharacterActor.fromJson(jsonItem);
            characterList.add(characterItem);
          } catch (e, s) {
            NetLog.error('postCharactersSearchByStringNext', '$e\n$s');
          }
        }
      }
    } catch (e, s) {
      NetLog.error('postCharactersSearchByStringNext', '$e\n$s');
    }
    return characterList;
  }

  Future<List<CharacterActor>> postPersonsSearchByStringNext({
    required String keyword,
    int offset = 0,
    List<String> career = const [],
  }) async {
    List<CharacterActor> personList = [];
    final data = <String, dynamic>{
      'keyword': keyword,
      "filter": {"career": []},
    };
    final params = <String, dynamic>{'offset': offset, 'limit': 20};
    try {
      final res = await _dio.request(
        Api.personsByStringNext,
        data: data,
        queryParameters: params,
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
            CharacterActor personItem = CharacterActor.fromJson(jsonItem);
            personList.add(personItem);
          } catch (e, s) {
            NetLog.error('postPersonsSearchByStringNext', '$e\n$s');
          }
        }
      }
    } catch (e, s) {
      NetLog.error('postPersonsSearchByStringNext', '$e\n$s');
    }
    return personList;
  }

  Future<BangumiItem?> getBangumiInfoByID(int id) async {
    try {
      final res = await _dio.request(
        Api.bangumiInfoByID + id.toString(),
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );
      return BangumiItem.fromJson(res.data);
    } catch (e, s) {
      NetLog.error('getBangumiInfoByID', '$e\n$s');
      return null;
    }
  }

  Future<List<BangumiSRI>> getBangumiSRIByID(int id) async {
    List<BangumiSRI> bangumiList = [];
    try {
      final res = await _dio.request(
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
            NetLog.error('getBangumiSRIByID', '$e\n$s');
          }
        }
      }
    } catch (e, s) {
      NetLog.error('getBangumiSRIByID', '$e\n$s');
    }
    return bangumiList;
  }

  Future<CommentResponse> getBangumiCommentsByID(
    int id, {
    int offset = 0,
  }) async {
    CommentResponse commentResponse = CommentResponse.fromTemplate();
    try {
      final res = await _dio.request(
        '${Api.bangumiInfoByIDNext}$id/comments?offset=$offset&limit=20',
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );
      final jsonData = res.data;
      commentResponse = CommentResponse.fromJson(jsonData);
    } catch (e, s) {
      NetLog.error('bangumi', '$e\n$s');
    }
    return commentResponse;
  }

  Future<CharacterResponse> getCharatersByID(int id) async {
    CharacterResponse characterResponse = CharacterResponse.fromTemplate();
    try {
      final res = await _dio.request(
        '${Api.bangumiInfoByID}$id/characters',
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );
      final jsonData = res.data;
      characterResponse = CharacterResponse.fromJson(jsonData);
    } catch (e) {
      NetLog.error('getCharatersByID', '$e');
    }
    return characterResponse;
  }

  Future<TopicsResponse> getTopicsByID(int id, {int offset = 0}) async {
    TopicsResponse topicsResponse = TopicsResponse.fromTemplate();
    var params = <String, dynamic>{'offset': offset, 'limit': 20};
    try {
      final res = await _dio.request(
        Api.formatUrl(Api.bangumiTopicsByIDNext, [id]),
        queryParameters: params,
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );
      final jsonData = res.data['data'];
      topicsResponse = TopicsResponse.fromJson(jsonData);
    } catch (e) {
      NetLog.error('getTopicsByID', '$e');
    }
    return topicsResponse;
  }

  Future<TopicsInfoItem?> getTopicsInfoByID(int id) async {
    try {
      final res = await _dio.request(
        '${Api.bangumiTopicsInfoByIDNext}$id',
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );
      final jsonData = res.data;
      if (res.statusCode == 404) return null;
      TopicsInfoItem topicsInfoItem = TopicsInfoItem.fromJson(jsonData);
      return topicsInfoItem;
    } catch (e) {
      NetLog.error('getTopicsInfoByID', '$e');
    }
    return null;
  }

  Future<List<TopicsInfoItem>> getTopicsLatestByID({int offset = 0}) async {
    List<TopicsInfoItem> topicsInfoItems = [];
    var params = <String, dynamic>{'offset': offset, 'limit': 100};
    try {
      final res = await _dio.request(
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
            NetLog.error('getTopicsLatestByID', '$e\n$s');
          }
        }
      }
    } catch (e) {
      NetLog.error('getTopicsLatestByID', '$e');
    }
    return topicsInfoItems;
  }

  Future<List<TopicsInfoItem>> getTopicsTrendingByID({int offset = 0}) async {
    List<TopicsInfoItem> topicsInfoItems = [];
    var params = <String, dynamic>{'offset': offset, 'limit': 100};
    try {
      final res = await _dio.request(
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
            NetLog.error('getTopicsLatestByID', '$e\n$s');
          }
        }
      }
    } catch (e) {
      NetLog.error('getTopicsLatestByID', '$e');
    }
    return topicsInfoItems;
  }

  Future<ReviewsResponse> getReviewsByID(int id, {int offset = 0}) async {
    ReviewsResponse reviewsResponse = ReviewsResponse.fromTemplate();
    var params = <String, dynamic>{'offset': offset, 'limit': 20};
    try {
      final res = await _dio.request(
        Api.formatUrl(Api.bangumiReviewsByIDNext, [id]),
        queryParameters: params,
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );
      final jsonData = res.data['data'];
      reviewsResponse = ReviewsResponse.fromJson(jsonData);
    } catch (e) {
      NetLog.error('getReviewsByID', '$e');
    }
    return reviewsResponse;
  }

  Future<ReviewsInfoItem?> getReviewsInfoByID(int id) async {
    try {
      final res = await _dio.request(
        '${Api.bangumiReviewsInfoByIDNext}$id',
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );
      final jsonData = res.data;
      if (res.statusCode == 200) {
        ReviewsInfoItem reviewsInfoItem = ReviewsInfoItem.fromJson(jsonData);
        return reviewsInfoItem;
      }
    } catch (e) {
      NetLog.error('getReviewsInfoByID', '$e');
    }
    return null;
  }

  Future<List<ReviewsCommentsItem>> getReviewsCommentsByID(int id) async {
    List<ReviewsCommentsItem> reviewsCommentsItem = [];
    try {
      final res = await _dio.request(
        Api.formatUrl(Api.bangumiReviewsCommentsByIDNext, [id]),
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );
      final jsonData = res.data;
      if (res.statusCode == 200 && jsonData is List) {
        for (var json in jsonData) {
          try {
            reviewsCommentsItem.add(ReviewsCommentsItem.fromJson(json));
          } catch (e) {
            NetLog.error('getReviewsCommentsByID', '$e');
          }
        }
      }
    } catch (e) {
      NetLog.error('getReviewsCommentsByID', '$e');
    }
    return reviewsCommentsItem;
  }

  Future<List<BangumiItem>> getReviewsSubjectsByID(int id) async {
    List<BangumiItem> bangumiReviewsSubjects = [];
    try {
      var res = await _dio.request(
        Api.checkBangumiDataUrl,
        options: Options(
          method: 'GET',
          headers: bangumiHTTPHeader,
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      final jsonData = res.data;
      for (dynamic json in jsonData) {
        try {
          BangumiItem bangumiItem = BangumiItem.fromJson(json);
          if (bangumiItem.type == 2) {
            bangumiReviewsSubjects.add(bangumiItem);
          }
        } catch (e, s) {
          NetLog.error('getReviewsSubjectsByID', '$e\n$s');
        }
      }
    } catch (e, s) {
      NetLog.error('getReviewsSubjectsByID', '$e\n$s');
    }
    return bangumiReviewsSubjects;
  }

  Future<List<List<BangumiItem>>> getCalendar() async {
    List<List<BangumiItem>> bangumiCalendar = [];
    try {
      var res = await _dio.request(
        Api.bangumiCalendar,
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );
      final jsonData = res.data;
      await manager.clearBangumiCalendar();
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
            NetLog.error('getCalendar', '$e\n$s');
          }
        }
        bangumiCalendar.add(bangumiList);
      }
    } catch (e, s) {
      NetLog.error('getCalendar', '$e\n$s');
    }
    return bangumiCalendar;
  }

  Future<void> getCalendarData({bool isUpdata = false}) async {
    final nowStr = Utils.formatDate(DateTime.now());
    if (!isUpdata) {
      final needsUpdate = appdata.settings['getCalendarDataTime'] != nowStr;
      final enableSkipUpdate = appdata.settings['enableSkipUpdate'] ?? true;
      if (!needsUpdate && enableSkipUpdate) return;
    }
    try {
      var res = await getCalendar();

      for (dynamic jsonlist in res) {
        await manager.batchAddBangumiCalendar(jsonlist);
      }
      appdata.settings['getCalendarDataTime'] = nowStr;
      appdata.saveData();
    } catch (e, s) {
      NetLog.error('getCalendarData', '$e\n$s');
    }
  }

  Future<BangumiItem?> bindFind(int id) async {
    var item = await manager.findBinding(id);
    if (item == null) {
      await getBangumiInfoBind(id);
      item = await manager.findBinding(id);
    }
    return item;
  }

  Future<void> getBangumiInfoBind(int id) async {
    try {
      var res = await getBangumiInfoByID(id);
      if (res != null) {
        await manager.addBangumiBinding(res);
      }
    } catch (e, s) {
      NetLog.error('bangumiGetBangumiInfoBind', '$e\n$s');
    }
  }

  Future<void> getBangumiData() async {
    try {
      final response = await _dio.request(
        Api.bangumiDataUrl,
        options: Options(method: 'GET', headers: {'user-agent': webUA}),
      );

      final responseData = response.data;
      if (responseData is! Map<String, dynamic> ||
          responseData['items'] is! List) {
        NetLog.error('bangumi', 'Invalid API response structure');
        return;
      }

      final itemsList = responseData['items'] as List;

      if (itemsList.isEmpty) {
        NetLog.error('bangumi', 'Received empty data list');
        return;
      }

      final bangumiDataList = parseBangumiDataList(itemsList);

      final last100Items = bangumiDataList.length > 200
          ? bangumiDataList.sublist(bangumiDataList.length - 200)
          : bangumiDataList;
      await manager.clearBangumiData();
      DebugLog.info('getBangumiData', 'clearBangumiData success');
      await manager.batchAddBangumiData(last100Items);

      DebugLog.info('getBangumiData', 'batchAddBangumiData success');
    } on DioException catch (e, s) {
      NetLog.error('getBangumiData', 'Network error: ${e.message}\nStack: $s');
    } on FormatException catch (e, s) {
      NetLog.error(
        'getBangumiData',
        'Data parsing failed: ${e.message}\nStack: $s',
      );
    } catch (e, s) {
      NetLog.error('getBangumiData', 'Unexpected error: $e\nStack: $s');
    }
  }

  List<BangumiData> parseBangumiDataList(List<dynamic> jsonList) {
    return jsonList.map<BangumiData>((json) {
      try {
        return BangumiData.fromJson(json);
      } catch (e, s) {
        NetLog.error(
          'parseBangumiDataList',
          'Failed to parse item: $e\nStack: $s',
        );
        throw FormatException('Invalid BangumiData item');
      }
    }).toList();
  }

  Future<void> checkBangumiData({bool isUpdata = false}) async {
    final nowStr = Utils.formatDate(DateTime.now());
    if (!isUpdata) {
      final needsUpdate = appdata.settings['getBangumiDataTime'] != nowStr;
      final enableSkipUpdate = appdata.settings['enableSkipUpdate'] ?? true;
      if (!needsUpdate && enableSkipUpdate) return;
    }
    try {
      var res = await _dio.request(
        Api.checkBangumiDataUrl,
        options: Options(method: 'GET', headers: {'user-agent': webUA}),
      );
      final jsonData = res.data;
      if (appdata.settings['bangumiDataVer'] != jsonData['tag_name']) {
        NetLog.info('checkBangumiData', '${jsonData['tag_name']}');

        await getBangumiData();
        App.rootContext.showMessage(
          message:
              'bangumiData数据更新成功${appdata.settings['bangumiDataVer']} -> ${jsonData['tag_name']}',
        );
        NetLog.info(
          'checkBangumiData',
          '当前数据库版本: ${appdata.settings['bangumiDataVer']}, 远端数据库版本: ${jsonData['tag_name']}',
        );
        appdata.settings['bangumiDataVer'] = jsonData['tag_name'];
        appdata.settings['getBangumiDataTime'] = nowStr;
        appdata.saveData();
        NetLog.info(
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
      if (e is DioException && e.response?.statusCode == 403) {
        NetLog.warning('checkBangumiData', 'Rate limit exceeded, skip');
        return;
      }
      // 后台启动检查：网络不可达/超时等无响应错误静默失败，不打扰用户
      if (e is DioException && e.response == null) {
        NetLog.warning('checkBangumiData', '网络请求失败（超时/不可达）: $e');
        return;
      }
      App.rootContext.showMessage(
        message: 'bangumiData更新失败...',
        level: LogLevel.error,
      );
      NetLog.error('checkBangumiData', '$e\n$s');
    }
  }

  Future<void> resetBangumiData() async {
    try {
      var res = await _dio.request(
        Api.checkBangumiDataUrl,
        options: Options(method: 'GET', headers: {'user-agent': webUA}),
      );
      final jsonData = res.data;
      NetLog.info('resetBangumiData', '${jsonData['tag_name']}');
      appdata.settings['getBangumiAllEpInfoTime'] = null;
      NetLog.info('resetBangumiData', 'Cleared bangumi data successfully');
      await getBangumiData();
      await getCalendarData(isUpdata: true);
      App.rootContext.showMessage(
        message:
            'bangumiData数据更新成功${appdata.settings['bangumiDataVer']} - ${jsonData['tag_name']}',
      );
      NetLog.info(
        'resetBangumiData',
        '当前数据库版本: ${appdata.settings['bangumiDataVer']}, 远端数据库版本: ${jsonData['tag_name']}',
      );
      appdata.settings['bangumiDataVer'] = jsonData['tag_name'];
      appdata.saveData();
      NetLog.info(
        'resetBangumiData',
        '更新完成,当前数据库版本: ${appdata.settings['bangumiDataVer']}',
      );
    } catch (e, s) {
      App.rootContext.showMessage(
        message: 'bangumiData重置失败...',
        level: LogLevel.error,
      );
      NetLog.error('resetBangumiData', '$e\n$s');
    }
  }

  Future<StaffResponse> getBangumiStaffByID(int id) async {
    StaffResponse staffResponse = StaffResponse.fromTemplate();
    try {
      final res = await _dio.request(
        Api.formatUrl(Api.bangumiStaffByIDNext, [id]),
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );
      final jsonData = res.data;
      staffResponse = StaffResponse.fromJson(jsonData);
    } catch (e) {}
    return staffResponse;
  }

  Future<EpisodeInfo> getBangumiEpisodeByID(int id, int episode) async {
    EpisodeInfo episodeInfo = EpisodeInfo.fromTemplate();
    var params = <String, dynamic>{
      'subject_id': id,
      'offset': episode - 1,
      'limit': 1,
    };
    try {
      final res = await _dio.request(
        Api.bangumiEpisodeByID,
        queryParameters: params,
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );
      final jsonData = res.data['data'][0];
      episodeInfo = EpisodeInfo.fromJson(jsonData);
    } catch (e, s) {
      NetLog.error('getBangumiEpisodeByID', '$e\n$s');
    }
    return episodeInfo;
  }

  Future<EpisodeInfo> getBangumiEpisodeByEpID(int id) async {
    EpisodeInfo episodeInfo = EpisodeInfo.fromTemplate();
    var params = <String, dynamic>{'episode_id': id};
    try {
      final res = await _dio.request(
        Api.bangumiEpisodeByID,
        queryParameters: params,
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );
      final jsonData = res.data['data'][0];
      episodeInfo = EpisodeInfo.fromJson(jsonData);
    } catch (e, s) {
      NetLog.error('getBangumiEpisodeByEpID', '$e\n$s');
    }
    return episodeInfo;
  }

  Future<List<EpisodeInfo>> getBangumiEpisodeAllByID(int id) async {
    try {
      var params = <String, dynamic>{'subject_id': id};
      final res = await _dio.request(
        Api.bangumiEpisodeByID,
        queryParameters: params,
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );

      final List<dynamic> jsonDataList = res.data['data'] ?? [];
      if (res.data['data'] != null) {
        await manager.addBangumiAllEpInfo(id, res.data['data']);
      }

      return jsonDataList.map((json) => EpisodeInfo.fromJson(json)).toList();
    } catch (e, s) {
      NetLog.error('bangumiGetBangumiEpisodeAllByID', '$e\n$s');
      return [];
    }
  }

  Future<EpisodeCommentResponse> getEpisodeCommentsByEpisodeID(int id) async {
    EpisodeCommentResponse commentResponse =
        EpisodeCommentResponse.fromTemplate();
    try {
      final res = await _dio.request(
        Api.formatUrl(Api.episodeCommentsByIDNext, [id]),
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );
      final jsonData = res.data;
      commentResponse = EpisodeCommentResponse.fromJson(jsonData);
    } catch (e, s) {
      NetLog.error('getBangumiCommentsByEpisodeID', '$e\n$s');
    }
    return commentResponse;
  }

  Future<CharacterCommentResponse> getCharacterCommentsByCharacterID(int id) {
    final url = Api.formatUrl(Api.characterCommentsByIDNext, [id]);
    return _fetchComments(url, 'getCharacterCommentsByCharacterID');
  }

  Future<CharacterCommentResponse> getPersonCommentsByPersonID(int id) {
    final url = Api.formatUrl(Api.personCommentsByPersonIDNext, [id]);
    return _fetchComments(url, 'getPersonCommentsByPersonID');
  }

  Future<CharacterCommentResponse> _fetchComments(
    String url,
    String logTag,
  ) async {
    try {
      final res = await _dio.request(
        url,
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );
      return CharacterCommentResponse.fromJson(res.data);
    } catch (e, s) {
      NetLog.error(logTag, '$e\n$s');
      return CharacterCommentResponse.fromTemplate();
    }
  }

  Future<CharacterFullItem> getCharacterByCharacterID(int id) {
    final url = Api.formatUrl(Api.characterInfoByCharacterIDNext, [id]);
    return _fetchCharacter(url, 'getCharacterByCharacterID');
  }

  Future<CharacterFullItem> getPersonByPersonID(int id) {
    final url = Api.formatUrl(Api.personByPersonIDNext, [id]);
    return _fetchCharacter(url, 'getCharacterByPersonID');
  }

  Future<CharacterFullItem> _fetchCharacter(String url, String logTag) async {
    try {
      final res = await _dio.request(
        url,
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );
      return CharacterFullItem.fromJson(res.data);
    } catch (e, s) {
      NetLog.error(logTag, '$e\n$s');
      return CharacterFullItem.fromTemplate();
    }
  }

  Future<List<CharacterCastsItem>> getCharacterCastsByCharacterID(
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
      final res = await _dio.request(
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
      NetLog.error('getCharacterCastsByCharacterID', '$e\n$s');
    }
    return characterCastsItems;
  }

  Future<List<CharacterPersonCastsItem>> getCastsByPersonId(
    int id, {
    int offset = 0,
    int type = 0,
  }) async {
    List<CharacterPersonCastsItem> characterPersonCastsItem = [];
    var params = <String, dynamic>{
      'subjectType': 2,
      'type': type,
      'limit': 20,
      'offset': offset,
    };
    try {
      final res = await _dio.request(
        Api.formatUrl(Api.castsByPersonIDNext, [id]),
        queryParameters: params,
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );
      final jsonData = res.data['data'];
      for (dynamic jsonItem in jsonData) {
        characterPersonCastsItem.add(
          CharacterPersonCastsItem.fromJson(jsonItem),
        );
      }
    } catch (e, s) {
      NetLog.error('getCastsByPersonId', '$e\n$s');
    }
    return characterPersonCastsItem;
  }

  Future<List<PersonWorkItem>> getPersonWorks(
    int id, {
    int offset = 0,
    int subjectType = 2,
  }) async {
    List<PersonWorkItem> works = [];
    final params = <String, dynamic>{
      'subjectType': subjectType,
      'limit': 20,
      'offset': offset,
    };
    try {
      final res = await _dio.request(
        Api.formatUrl(Api.worksByPersonIDNext, [id]),
        queryParameters: params,
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );
      final jsonData = res.data['data'];
      for (dynamic jsonItem in jsonData) {
        works.add(PersonWorkItem.fromJson(jsonItem));
      }
    } catch (e, s) {
      NetLog.error('getPersonWorks', '$e\n$s');
    }
    return works;
  }

  Future<Map<bool, BangumiItem?>> isBangumiExists(int id) async {
    try {
      final res = await _dio.request(
        Api.bangumiInfoByID + id.toString(),
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );
      if (res.data['type'] == 2) {
        return {true: BangumiItem.fromJson(res.data)};
      }
    } catch (e) {}
    return {false: null};
  }

  Future<String> getBangumiUserAvatarByName(String name) async {
    try {
      final res = await _dio.request(
        '${Api.bangumiUserAvatar}$name',
        options: Options(method: 'GET', headers: bangumiHTTPHeader),
      );
      final avatar = res.data["avatar"]["large"];
      return avatar;
    } catch (e) {
      NetLog.error('getBangumiUserAvatarByName', '$e');
    }
    return '';
  }

  Future<List<BangumiItem>> getBangumiUseFavoritesByName({
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
      final res = await _dio.request(
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
      NetLog.error('getBangumiUseFavorites', '$e');
    }
    return bangumiList;
  }

  Future<List<BangumiItem>> getBangumiTrendsList({
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
      final res = await _dio.request(
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
      if (e is DioException && e.response == null) {
        NetLog.warning('getBangumiTrendsList', '网络请求失败（超时/不可达）: $e');
      } else {
        NetLog.error('getBangumiTrendsList', '$e\n$s');
      }
    }
    return bangumiList;
  }
}

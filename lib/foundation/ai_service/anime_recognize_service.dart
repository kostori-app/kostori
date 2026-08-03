// 动漫识别服务：接入 trace.moe API（POST multipart 图片 → 返回候选来源）。

import 'dart:async';
import 'dart:typed_data';

import 'package:kostori/foundation/res.dart';
import 'package:kostori/network/app_dio.dart';

class AnimeRecognizeResult {
  final int? anilistId;
  final String filename;
  final int? episode;
  final double from;
  final double to;
  final double similarity;
  final String video;
  final String image;
  final int? season;

  /// trace.moe 附带的 anilist 信息（请求 anilistInfo 时返回），含 title 等
  final Map<String, dynamic>? anilist;

  const AnimeRecognizeResult({
    this.anilistId,
    required this.filename,
    this.episode,
    required this.from,
    required this.to,
    required this.similarity,
    required this.video,
    required this.image,
    this.season,
    this.anilist,
  });

  factory AnimeRecognizeResult.fromJson(Map<String, dynamic> json) =>
      AnimeRecognizeResult(
        anilistId: _toInt(json['anilistId']),
        filename: (json['filename'] as String?) ?? '',
        episode: _toInt(json['episode']),
        from: _toDouble(json['from']),
        to: _toDouble(json['to']),
        similarity: _toDouble(json['similarity']),
        video: (json['video'] as String?) ?? '',
        image: (json['image'] as String?) ?? '',
        season: _toInt(json['season']),
        anilist: json['anilist'] is Map
            ? (json['anilist'] as Map).cast<String, dynamic>()
            : null,
      );

  static int? _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  /// 标题：优先取 anilist 的多语言标题（中文→原生→罗马音→英文），
  /// 取不到再回退到从 filename 解析
  String get title {
    final t = anilist?['title'];
    if (t is Map) {
      for (final key in ['chinese', 'native', 'romaji', 'english']) {
        final v = t[key];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
    }
    return _parseFromFilename();
  }

  /// 从 filename 解析动漫标题（去掉扩展名、集数、方括号标记等）
  String _parseFromFilename() {
    var t = filename;
    final dot = t.lastIndexOf('.');
    if (dot > 0) t = t.substring(0, dot);
    t = t.replaceFirst(RegExp(r'[-_\s]*(EP|ep)?\s*\d+$'), '');
    t = t.replaceFirst(RegExp(r'\s*[\[\(][^\]\)]*[\]\)]\s*$'), '');
    t = t.replaceFirst(RegExp(r'\s*第\s*\d+\s*[话話集]?\s*$'), '');
    t = t.replaceAll(RegExp(r'[\[\(\)\]]'), ' ').trim();
    return t.isEmpty ? filename : t;
  }

  /// 相似度百分比（0~100）
  String get similarityPercent => '${(similarity * 100).toStringAsFixed(1)}%';

  /// 格式化时间点：秒 → "hh:mm:ss" / "mm:ss"
  static String fmtTime(double seconds) {
    final total = seconds.round();
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }
}

/// trace.moe 识别服务（可 mock / 注入 Dio 测试）
class AnimeRecognizeService {
  AnimeRecognizeService({Dio? dio}) : _dio = dio ?? AppDio();

  final Dio _dio;

  static const _endpoint = 'https://api.trace.moe/search';
  static const _timeout = Duration(seconds: 30);
  static const _maxRetries = 3;

  /// 识别：multipart/form-data 提交 image 文件流。
  /// 429/503 限流做指数退避重试；超时/网络错误可重试。
  Future<Res<List<AnimeRecognizeResult>>> recognize(
    Uint8List bytes, {
    String? imageUrl,
  }) async {
    if (bytes.isEmpty && (imageUrl == null || imageUrl.isEmpty)) {
      return Res.error('图片无效');
    }
    final form = imageUrl != null && bytes.isEmpty
        ? FormData.fromMap({'url': imageUrl})
        : FormData.fromMap({
            'image': MultipartFile.fromBytes(bytes, filename: 'screenshot.jpg'),
          });

    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final response = await _dio.post(
          _endpoint,
          data: form,
          // 请求附带 anilist 信息（多语言标题等），便于展示规范片名
          queryParameters: {'anilistInfo': true},
          options: Options(receiveTimeout: _timeout),
        );
        final status = response.statusCode;
        if (status == 429 || status == 503) {
          if (attempt < _maxRetries) {
            await Future.delayed(Duration(seconds: (attempt + 1) * 2));
            continue;
          }
          return Res.error('识别服务繁忙，请稍后再试');
        }
        if (status != 200) {
          return Res.error('识别失败（HTTP $status）');
        }
        final json = response.data;
        if (json is! Map<String, dynamic>) return Res.error('响应格式错误');
        final err = json['error'];
        if (err is String && err.isNotEmpty) return Res.error(err);
        final list = json['result'];
        final results =
            (list is List ? list : const [])
                .whereType<Map>()
                .map(
                  (e) =>
                      AnimeRecognizeResult.fromJson(e.cast<String, dynamic>()),
                )
                .toList()
              ..sort((a, b) => b.similarity.compareTo(a.similarity));
        return Res(results);
      } on DioException catch (e) {
        final isTimeout =
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout;
        final code = e.response?.statusCode;
        if (code == 429 || code == 503) {
          if (attempt < _maxRetries) {
            await Future.delayed(Duration(seconds: (attempt + 1) * 2));
            continue;
          }
          return Res.error('识别服务繁忙，请稍后再试');
        }
        if (attempt < _maxRetries && isTimeout) {
          await Future.delayed(Duration(seconds: (attempt + 1) * 2));
          continue;
        }
        return Res.error(isTimeout ? '识别超时，请重试' : '识别失败：$e');
      }
    }
    return Res.error('识别失败，请重试');
  }
}

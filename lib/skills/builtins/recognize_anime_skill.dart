// 动漫识别技能：调用 trace.moe 识别图片中的动漫来源。
// 工具参数为文本，支持传图片 URL（image_url）或 base64 图片（image_base64）。

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:kostori/foundation/ai_service/anime_recognize_service.dart';
import 'package:kostori/skills/skill.dart';
import 'package:kostori/skills/skill_registry.dart';

class RecognizeAnimeSkill extends Skill {
  @override
  String get id => 'recognize_anime';

  @override
  String get name => '识别动漫';

  @override
  String get description =>
      '使用 trace.moe 识别一张图片出自哪部动漫。优先使用当前消息中用户附带/上传的图片；'
      '也可传入图片 URL（image_url）或 base64 编码的图片数据（image_base64，可含 data: 前缀）。'
      '返回候选的动漫标题、集数、时间点与相似度。当用户上传/给出一张图片并想识别它出自哪部番时调用，'
      'image_url 与 image_base64 可不填（使用消息附带图片）。';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'image_url': {
        'type': 'string',
        'description': '图片的 URL 地址，可为空（为空时使用消息附带的图片）',
      },
      'image_base64': {
        'type': 'string',
        'description':
            '图片的 base64 数据（可含 data:image/...;base64, 前缀），可为空（为空时使用消息附带的图片）',
      },
    },
  };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final url = (arguments['image_url'] as String? ?? '').trim();
    final b64 = (arguments['image_base64'] as String? ?? '').trim();

    Uint8List bytes = Uint8List(0);
    String? effectiveUrl = url.isEmpty ? null : url;

    if (b64.isNotEmpty) {
      final data = b64.contains(',') ? b64.split(',').last : b64;
      try {
        bytes = base64Decode(data);
      } catch (_) {
        return '图片 base64 解码失败，请确认数据有效';
      }
    } else if (url.isEmpty) {
      // 未传 URL/base64：使用当前消息附带的图片
      final context = SkillRegistry.instance.contextImage;
      if (context == null || context.isEmpty) {
        throw SkillException('需要提供 image_url / image_base64，或随消息附带图片');
      }
      bytes = context;
    }

    // 压缩：最长边 512 JPEG，加快识别
    if (bytes.isNotEmpty) {
      try {
        bytes = await FlutterImageCompress.compressWithList(
          bytes,
          minWidth: 512,
          minHeight: 512,
          quality: 80,
          format: CompressFormat.jpeg,
        );
      } catch (_) {}
    }

    final res = await AnimeRecognizeService().recognize(
      bytes,
      imageUrl: effectiveUrl,
    );
    if (!res.success) return res.errorMessage ?? '识别失败';

    final results = res.data;
    if (results.isEmpty) {
      return '未识别到动漫，可能是非动漫图片';
    }
    final sb = StringBuffer();
    sb.writeln('识别到 ${results.length} 个候选（按相似度排序）：');
    for (var i = 0; i < results.length && i < 3; i++) {
      final r = results[i];
      sb.writeln(
        '${i + 1}. 《${r.title}》第${r.episode ?? '?'}集'
        '（${AnimeRecognizeResult.fmtTime(r.from)} → '
        '${AnimeRecognizeResult.fmtTime(r.to)}）'
        ' 相似度 ${r.similarityPercent}',
      );
    }
    return sb.toString();
  }
}

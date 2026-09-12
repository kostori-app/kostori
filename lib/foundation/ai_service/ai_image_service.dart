import 'dart:convert';
import 'dart:typed_data';

import 'package:kostori/database/ai_database.dart';
import 'package:kostori/foundation/ai_service/openai_provider_registry.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/res.dart';
import 'package:kostori/network/app_dio.dart';

/// 出图引擎：OpenAI 兼容 `/images/generations`，或 SD WebUI `/sdapi/v1/txt2img`
enum AiImageEngine { openai, sd }

class AiImageGenConfig {
  final AiImageEngine engine;
  final String model;
  final String size; // 例如 1024x1024
  final int steps; // SD 采样步数
  final String baseUrl; // 可选覆盖（SD 通常必填）

  const AiImageGenConfig({
    this.engine = AiImageEngine.openai,
    this.model = '',
    this.size = '1024x1024',
    this.steps = 20,
    this.baseUrl = '',
  });

  static AiImageGenConfig load() {
    final v = appdata.implicitData['aiImageGen'];
    if (v is Map) {
      return AiImageGenConfig(
        engine: v['engine'] == 'sd' ? AiImageEngine.sd : AiImageEngine.openai,
        model: v['model']?.toString() ?? '',
        size: v['size']?.toString() ?? '1024x1024',
        steps: (v['steps'] as num?)?.toInt() ?? 20,
        baseUrl: v['baseUrl']?.toString() ?? '',
      );
    }
    return const AiImageGenConfig();
  }

  AiImageGenConfig copyWith({
    AiImageEngine? engine,
    String? model,
    String? size,
    int? steps,
    String? baseUrl,
  }) => AiImageGenConfig(
    engine: engine ?? this.engine,
    model: model ?? this.model,
    size: size ?? this.size,
    steps: steps ?? this.steps,
    baseUrl: baseUrl ?? this.baseUrl,
  );

  void save() {
    appdata.implicitData['aiImageGen'] = {
      'engine': engine.name,
      'model': model,
      'size': size,
      'steps': steps,
      'baseUrl': baseUrl,
    };
    appdata.writeImplicitData();
  }
}

class AiImageService {
  /// 生成图片。成功返回 PNG 字节。
  static Future<Res<Uint8List>> generate({
    required String provider,
    required String prompt,
    required AiImageGenConfig config,
  }) async {
    final row = await AiDatabase.instance.aiApiKeyDao.getByProvider(provider);
    final apiKey = row?.apiKey ?? '';
    final providerBase =
        OpenAiProviderRegistry.allProviders[provider]?.baseUrl ?? '';
    final override = config.baseUrl.trim();
    final rowBase = row?.baseUrl?.trim() ?? '';
    var base = override.isNotEmpty
        ? override
        : (rowBase.isNotEmpty ? rowBase : providerBase);
    base = base.replaceAll(RegExp(r'/+$'), '');
    if (base.isEmpty) return const Res.error('Base URL is empty');

    try {
      if (config.engine == AiImageEngine.sd) {
        return await _generateSd(base, prompt, config);
      }
      return await _generateOpenAi(base, apiKey, prompt, config);
    } catch (e) {
      Log.error('AiImageService', e.toString());
      return Res.error(e.toString());
    }
  }

  static Future<Res<Uint8List>> _generateOpenAi(
    String base,
    String apiKey,
    String prompt,
    AiImageGenConfig config,
  ) async {
    final model = config.model.trim();
    final res = await AppDio().post(
      '$base/images/generations',
      options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
      data: {
        'prompt': prompt,
        'n': 1,
        'size': config.size,
        if (model.isNotEmpty) 'model': model,
      },
    );
    final data = (res.data is Map) ? res.data['data'] : null;
    if (data is List && data.isNotEmpty && data.first is Map) {
      final first = data.first as Map;
      final b64 = first['b64_json'];
      if (b64 is String && b64.isNotEmpty) {
        return Res(base64Decode(b64));
      }
      final url = first['url'];
      if (url is String && url.isNotEmpty) {
        final img = await AppDio().get<List<int>>(
          url,
          options: Options(responseType: ResponseType.bytes),
        );
        final bytes = img.data;
        if (bytes != null) return Res(Uint8List.fromList(bytes));
      }
    }
    return const Res.error('No image returned');
  }

  static Future<Res<Uint8List>> _generateSd(
    String base,
    String prompt,
    AiImageGenConfig config,
  ) async {
    final parts = config.size.split('x');
    final w = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 1024;
    final h = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 1024;
    final res = await AppDio().post(
      '$base/sdapi/v1/txt2img',
      data: {
        'prompt': prompt,
        'steps': config.steps,
        'width': w,
        'height': h,
        'cfg_scale': 7,
      },
    );
    final images = (res.data is Map) ? res.data['images'] : null;
    if (images is List && images.isNotEmpty && images.first is String) {
      return Res(base64Decode(images.first as String));
    }
    return const Res.error('No image returned');
  }
}

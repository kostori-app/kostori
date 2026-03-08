part of 'package:kostori/foundation/services/services.dart';

class ApiKeyManager {
  ApiKeyManager._internal();

  static final ApiKeyManager _instance = ApiKeyManager._internal();

  factory ApiKeyManager() => _instance;

  static const _fixedKeyPref = 'service_fixed_api_key';
  static const _useFixedPref = 'service_use_fixed_api_key';

  String? _randomKey;
  String? _fixedKey;
  bool _useFixed = false;

  // 当前生效的 Key
  String get activeKey {
    if (_useFixed && (_fixedKey?.isNotEmpty ?? false)) {
      return _fixedKey!;
    }
    return _randomKey ?? '';
  }

  bool get isUsingFixed => _useFixed;

  String? get fixedKey => _fixedKey;

  String? get randomKey => _randomKey;

  // ─────────────────────────────────────────
  // 初始化：从持久化存储读取设置
  // ─────────────────────────────────────────

  Future<void> init() async {
    _fixedKey = appdata.implicitData[_fixedKeyPref];
    _useFixed = appdata.implicitData[_useFixedPref] ?? false;
    _randomKey = _generateKey();
    Log.info('ApiKeyManager', '随机 Key 已生成：$_randomKey');
    Log.info('ApiKeyManager', '固定 Key：$_fixedKey');
    Log.info('ApiKeyManager', 'useFixed：$_useFixed');
    Log.info('ApiKeyManager', 'activeKey：$activeKey');
    Log.info('ApiKeyManager', '当前使用：${isUsingFixed ? "固定 Key" : "随机 Key"}');
  }

  // ─────────────────────────────────────────
  // 随机 Key 生成
  // ─────────────────────────────────────────

  String _generateKey({int length = 32}) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    return List.generate(
      length,
      (_) => chars[rand.nextInt(chars.length)],
    ).join();
  }

  /// 手动重新生成随机 Key（服务运行中也可以调用）
  void regenerateRandomKey() {
    _randomKey = _generateKey();
    Log.info('[ApiKeyManager]', '随机 Key 已重新生成：$_randomKey');
  }

  // ─────────────────────────────────────────
  // 固定 Key 设置
  // ─────────────────────────────────────────

  Future<String?> setFixedKey(String key) async {
    if (key.isEmpty) {
      _fixedKey = null;
      appdata.implicitData.remove(_fixedKeyPref);
      appdata.writeImplicitData();
      return null;
    }

    if (key.length < 8) return '密钥长度不能少于 8 位';
    if (key.length > 64) return '密钥长度不能超过 64 位';

    final valid = RegExp(r'^[a-zA-Z0-9_\-\.]+$');
    if (!valid.hasMatch(key)) return '只允许字母、数字、_ - . 字符';

    _fixedKey = key;
    appdata.implicitData[_fixedKeyPref] = key;
    appdata.writeImplicitData();

    // ← 加这里
    Log.info('[ApiKeyManager]', ' 已保存固定 Key：$key');
    Log.info(
      '[ApiKeyManager]',
      'implicitData 写入后：${appdata.implicitData[_fixedKeyPref]}',
    );

    return null;
  }

  Future<void> setUseFixed(bool value) async {
    _useFixed = value;
    appdata.implicitData[_useFixedPref] = value;
    appdata.writeImplicitData();
  }

  Future<void> clearFixedKey() async {
    _fixedKey = null;
    _useFixed = false;
    appdata.implicitData.remove(_fixedKeyPref);
    appdata.implicitData.remove(_useFixedPref);
    appdata.writeImplicitData();
  }

  // ─────────────────────────────────────────
  // 校验
  // ─────────────────────────────────────────

  bool validate(String key) => key == activeKey;
}

part of 'package:kostori/foundation/hub_services/services.dart';

class ApiKeyManager {
  ApiKeyManager._internal();

  static final ApiKeyManager _instance = ApiKeyManager._internal();

  factory ApiKeyManager() => _instance;

  // ─── 用户层 ───
  static const _fixedKeyPref = 'service_fixed_api_key';
  static const _useFixedPref = 'service_use_fixed_api_key';

  // ─── 管理层 ───
  static const _adminFixedKeyPref = 'service_admin_fixed_api_key';
  static const _useAdminFixedPref = 'service_use_admin_fixed_api_key';

  // 用户层
  String? _randomKey;
  String? _fixedKey;
  bool _useFixed = false;

  // 管理层
  String? _adminRandomKey;
  String? _adminFixedKey;
  bool _useAdminFixed = false;

  // ─────────────────────────────────────────
  // Getter：用户层
  // ─────────────────────────────────────────

  String get activeKey {
    if (_useFixed && (_fixedKey?.isNotEmpty ?? false)) return _fixedKey!;
    return _randomKey ?? '';
  }

  bool get isUsingFixed => _useFixed;

  String? get fixedKey => _fixedKey;

  String? get randomKey => _randomKey;

  // ─────────────────────────────────────────
  // Getter：管理层
  // ─────────────────────────────────────────

  String get adminActiveKey {
    if (_useAdminFixed && (_adminFixedKey?.isNotEmpty ?? false)) {
      return _adminFixedKey!;
    }
    return _adminRandomKey ?? '';
  }

  bool get isUsingAdminFixed => _useAdminFixed;

  String? get adminFixedKey => _adminFixedKey;

  String? get adminRandomKey => _adminRandomKey;

  // ─────────────────────────────────────────
  // 初始化
  // ─────────────────────────────────────────

  Future<void> init() async {
    // 用户层
    _fixedKey = appdata.implicitData[_fixedKeyPref];
    _useFixed = appdata.implicitData[_useFixedPref] ?? false;
    _randomKey = _generateKey();

    // 管理层
    _adminFixedKey = appdata.implicitData[_adminFixedKeyPref];
    _useAdminFixed = appdata.implicitData[_useAdminFixedPref] ?? false;
    _adminRandomKey = _generateKey();

    HubLog.info('ApiKeyManager', '用户层 activeKey：$activeKey');
    HubLog.info('ApiKeyManager', '管理层 activeKey：$adminActiveKey');
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

  void regenerateRandomKey() {
    _randomKey = _generateKey();
    HubLog.info('ApiKeyManager', '用户层随机 Key 已重新生成');
  }

  void regenerateAdminRandomKey() {
    _adminRandomKey = _generateKey();
    HubLog.info('ApiKeyManager', '管理层随机 Key 已重新生成');
  }

  // ─────────────────────────────────────────
  // 用户层固定 Key
  // ─────────────────────────────────────────

  Future<String?> setFixedKey(String key) async {
    if (key.isEmpty) {
      _fixedKey = null;
      appdata.implicitData.remove(_fixedKeyPref);
      appdata.writeImplicitData();
      return null;
    }
    final err = _validateKey(key);
    if (err != null) return err;

    _fixedKey = key;
    appdata.implicitData[_fixedKeyPref] = key;
    appdata.writeImplicitData();
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
  // 管理层固定 Key
  // ─────────────────────────────────────────

  Future<String?> setAdminFixedKey(String key) async {
    if (key.isEmpty) {
      _adminFixedKey = null;
      appdata.implicitData.remove(_adminFixedKeyPref);
      appdata.writeImplicitData();
      return null;
    }
    final err = _validateKey(key);
    if (err != null) return err;

    _adminFixedKey = key;
    appdata.implicitData[_adminFixedKeyPref] = key;
    appdata.writeImplicitData();
    return null;
  }

  Future<void> setUseAdminFixed(bool value) async {
    _useAdminFixed = value;
    appdata.implicitData[_useAdminFixedPref] = value;
    appdata.writeImplicitData();
  }

  Future<void> clearAdminFixedKey() async {
    _adminFixedKey = null;
    _useAdminFixed = false;
    appdata.implicitData.remove(_adminFixedKeyPref);
    appdata.implicitData.remove(_useAdminFixedPref);
    appdata.writeImplicitData();
  }

  // ─────────────────────────────────────────
  // 校验
  // ─────────────────────────────────────────

  /// 校验用户层 Key
  bool validate(String key) => key == activeKey;

  /// 校验管理层 Key
  bool validateAdmin(String key) => key == adminActiveKey;

  /// 格式校验（共用）
  String? _validateKey(String key) {
    if (key.length < 8) return '密钥长度不能少于 8 位';
    if (key.length > 64) return '密钥长度不能超过 64 位';
    final valid = RegExp(r'^[a-zA-Z0-9_\-.]+$');
    if (!valid.hasMatch(key)) return '只允许字母、数字、_ - . 字符';
    return null;
  }
}

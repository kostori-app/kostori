import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:kostori/utils/protocol_parser.dart';

// ─────────────────────────────────────────────
//  剪贴板状态
// ─────────────────────────────────────────────
enum ClipboardStatus {
  /// 尚未检测
  idle,

  /// 正在读取
  checking,

  /// 找到可解析的协议
  found,

  /// 已读取但无可解析内容
  noMatch,

  /// 内容与上次相同，跳过（仅自动检测会触发此状态）
  unchanged,
}

class ClipboardProvider extends ChangeNotifier {
  ClipboardProvider({this.autoCheckOnInit = true}) {
    if (autoCheckOnInit) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onLifecycleResumed());
    }
  }

  final bool autoCheckOnInit;

  ClipboardStatus _status = ClipboardStatus.idle;
  String? _rawText;
  ParsedProtocol? _parsed;

  String? _lastAutoCheckedText;

  ClipboardStatus get status => _status;

  String? get rawText => _rawText;

  ParsedProtocol? get parsed => _parsed;

  bool get hasPendingProtocol =>
      _status == ClipboardStatus.found && _parsed != null;

  void onLifecycleResumed() => _check(force: false);

  Future<void> checkClipboard() => _check(force: true);

  Future<void> _check({required bool force}) async {
    _setStatus(ClipboardStatus.checking);

    ClipboardData? data;
    try {
      data = await Clipboard.getData(Clipboard.kTextPlain);
    } catch (e) {
      debugPrint('[ClipboardProvider] 读取失败: $e');
      _setStatus(ClipboardStatus.idle);
      return;
    }

    final text = data?.text?.trim();

    if (text == null || text.isEmpty) {
      _rawText = null;
      _parsed = null;
      _setStatus(ClipboardStatus.noMatch);
      return;
    }

    if (!force && text == _lastAutoCheckedText) {
      _setStatus(ClipboardStatus.unchanged);
      return;
    }

    if (!force) _lastAutoCheckedText = text;

    _rawText = text;

    if (!ProtocolParser.looksLikeProtocol(text)) {
      _parsed = null;
      _setStatus(ClipboardStatus.noMatch);
      return;
    }

    final result = ProtocolParser.parse(text);
    _parsed = result;
    _setStatus(
      result != null ? ClipboardStatus.found : ClipboardStatus.noMatch,
    );
  }

  void consume() {
    _parsed = null;
    _lastAutoCheckedText = null;
    _setStatus(ClipboardStatus.idle);
  }

  void clear() {
    _rawText = null;
    _parsed = null;
    _lastAutoCheckedText = null;
    _setStatus(ClipboardStatus.idle);
  }

  void _setStatus(ClipboardStatus s) {
    _status = s;
    notifyListeners();
  }
}

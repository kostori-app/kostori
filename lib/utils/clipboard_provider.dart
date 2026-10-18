import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:kostori/utils/protocol_parser.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'clipboard_provider.g.dart';

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

const _clipboardUnset = Object();

@immutable
class ClipboardState {
  const ClipboardState({
    this.status = ClipboardStatus.idle,
    this.rawText,
    this.parsed,
  });

  final ClipboardStatus status;
  final String? rawText;
  final ParsedProtocol? parsed;

  ClipboardState copyWith({
    ClipboardStatus? status,
    Object? rawText = _clipboardUnset,
    Object? parsed = _clipboardUnset,
  }) {
    return ClipboardState(
      status: status ?? this.status,
      rawText: identical(rawText, _clipboardUnset)
          ? this.rawText
          : rawText as String?,
      parsed: identical(parsed, _clipboardUnset)
          ? this.parsed
          : parsed as ParsedProtocol?,
    );
  }
}

@Riverpod(keepAlive: true)
class ClipboardNotifier extends _$ClipboardNotifier {
  String? _lastAutoCheckedText;
  bool _disposed = false;

  @override
  ClipboardState build() {
    ref.onDispose(() => _disposed = true);
    return const ClipboardState();
  }

  ClipboardStatus get status => state.status;

  String? get rawText => state.rawText;

  ParsedProtocol? get parsed => state.parsed;

  bool get hasPendingProtocol =>
      state.status == ClipboardStatus.found && state.parsed != null;

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
      state = state.copyWith(rawText: null, parsed: null);
      _setStatus(ClipboardStatus.noMatch);
      return;
    }

    if (!force && text == _lastAutoCheckedText) {
      _setStatus(ClipboardStatus.unchanged);
      return;
    }

    if (!force) _lastAutoCheckedText = text;

    state = state.copyWith(rawText: text);

    if (!ProtocolParser.looksLikeProtocol(text)) {
      state = state.copyWith(parsed: null);
      _setStatus(ClipboardStatus.noMatch);
      return;
    }

    final result = ProtocolParser.parse(text);
    state = state.copyWith(parsed: result);
    _setStatus(
      result != null ? ClipboardStatus.found : ClipboardStatus.noMatch,
    );
  }

  void consume() {
    state = state.copyWith(parsed: null);
    _lastAutoCheckedText = null;
    _setStatus(ClipboardStatus.idle);
  }

  void clear() {
    state = state.copyWith(rawText: null, parsed: null);
    _lastAutoCheckedText = null;
    _setStatus(ClipboardStatus.idle);
  }

  void _setStatus(ClipboardStatus s) {
    if (_disposed) return;
    state = state.copyWith(status: s);
  }
}

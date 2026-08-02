// 插件模块：AI Hub 中除聊天外的模块化能力（灵魂侧写 / Tag 生成 / 周月总结 / 用户自定义）。
// 内置插件为固定入口，用户可新增/编辑/删除自定义插件（提示词驱动的一问一答模块）。

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PluginModule {
  final String id;
  final String name;
  final String icon;
  final String description;
  final String prompt;
  final bool isBuiltin;

  const PluginModule({
    required this.id,
    required this.name,
    this.icon = '🧩',
    this.description = '',
    this.prompt = '',
    this.isBuiltin = false,
  });

  PluginModule copyWith({
    String? name,
    String? icon,
    String? description,
    String? prompt,
  }) => PluginModule(
    id: id,
    name: name ?? this.name,
    icon: icon ?? this.icon,
    description: description ?? this.description,
    prompt: prompt ?? this.prompt,
    isBuiltin: isBuiltin,
  );

  factory PluginModule.fromJson(Map<String, dynamic> json) => PluginModule(
    id:
        (json['id'] as String?) ??
        'plugin_${DateTime.now().millisecondsSinceEpoch}',
    name: (json['name'] as String?) ?? '',
    icon: (json['icon'] as String?) ?? '🧩',
    description: (json['description'] as String?) ?? '',
    prompt: (json['prompt'] as String?) ?? '',
    isBuiltin: (json['isBuiltin'] as bool?) ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'icon': icon,
    'description': description,
    'prompt': prompt,
    'isBuiltin': isBuiltin,
  };
}

class PluginStore extends ChangeNotifier {
  static final PluginStore instance = PluginStore._();

  PluginStore._();

  static const _kKey = 'ai_plugin_modules';

  List<PluginModule> _plugins = [];
  bool _loaded = false;

  List<PluginModule> get plugins => List.unmodifiable(_plugins);

  bool get isLoaded => _loaded;

  /// 内置插件（固定 id，不可删除，仅作入口）
  static List<PluginModule> _builtinPlugins() => [
    PluginModule(
      id: 'soul_profile',
      name: t.soulProfile,
      icon: '🧠',
      description: t.soulProfilerDescription,
      isBuiltin: true,
    ),
    PluginModule(
      id: 'image_tag',
      name: t.imageTag,
      icon: '🎨',
      description: t.imageTagDescription,
      isBuiltin: true,
    ),
    PluginModule(
      id: 'summary',
      name: t.summary,
      icon: '📊',
      description: t.summaryDescription,
      isBuiltin: true,
    ),
  ];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    _plugins = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _plugins = [
            for (final e in decoded)
              if (e is Map) PluginModule.fromJson(e.cast<String, dynamic>()),
          ];
        }
      } catch (_) {
        _plugins = [];
      }
    }
    // 确保内置插件存在（名称/描述跟随当前语言）
    var changed = false;
    for (final b in _builtinPlugins()) {
      final idx = _plugins.indexWhere((p) => p.id == b.id);
      if (idx < 0) {
        _plugins.insert(0, b);
        changed = true;
      } else {
        final old = _plugins[idx];
        _plugins[idx] = PluginModule(
          id: old.id,
          name: b.name,
          icon: old.icon.isEmpty ? b.icon : old.icon,
          description: b.description,
          prompt: old.prompt,
          isBuiltin: true,
        );
        if (old.name != b.name || old.description != b.description) {
          changed = true;
        }
      }
    }
    if (changed) await _save();
    _loaded = true;
    notifyListeners();
  }

  Future<void> ensureLoaded() async {
    if (!_loaded) await init();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kKey,
      jsonEncode([for (final p in _plugins) p.toJson()]),
    );
  }

  PluginModule? find(String id) {
    for (final p in _plugins) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> upsert(PluginModule module) async {
    await ensureLoaded();
    final idx = _plugins.indexWhere((p) => p.id == module.id);
    if (idx >= 0) {
      _plugins[idx] = module;
    } else {
      _plugins.add(module);
    }
    await _save();
    notifyListeners();
  }

  /// 删除插件；内置插件拒绝删除并返回 false
  Future<bool> remove(String id) async {
    await ensureLoaded();
    final target = find(id);
    if (target != null && target.isBuiltin) return false;
    _plugins.removeWhere((p) => p.id == id);
    await _save();
    notifyListeners();
    return true;
  }
}

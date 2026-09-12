// AI 扮演角色：名称 / 头像 / 人设（系统提示词）/ 开场白 / 标签。
// 内置角色为固定入口，用户可新增/编辑/删除自定义角色。

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiRole {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final String persona;
  final String greeting;
  final List<String> tags;
  final bool isBuiltin;

  const AiRole({
    required this.id,
    required this.name,
    this.emoji = '🧑',
    this.description = '',
    this.persona = '',
    this.greeting = '',
    this.tags = const [],
    this.isBuiltin = false,
  });

  AiRole copyWith({
    String? name,
    String? emoji,
    String? description,
    String? persona,
    String? greeting,
    List<String>? tags,
  }) => AiRole(
    id: id,
    name: name ?? this.name,
    emoji: emoji ?? this.emoji,
    description: description ?? this.description,
    persona: persona ?? this.persona,
    greeting: greeting ?? this.greeting,
    tags: tags ?? this.tags,
    isBuiltin: isBuiltin,
  );

  factory AiRole.fromJson(Map<String, dynamic> json) => AiRole(
    id: (json['id'] as String?) ?? 'role_${DateTime.now().millisecondsSinceEpoch}',
    name: (json['name'] as String?) ?? '',
    emoji: (json['emoji'] as String?) ?? '🧑',
    description: (json['description'] as String?) ?? '',
    persona: (json['persona'] as String?) ?? '',
    greeting: (json['greeting'] as String?) ?? '',
    tags: (json['tags'] as List?)?.whereType<String>().toList() ?? const [],
    isBuiltin: (json['isBuiltin'] as bool?) ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'description': description,
    'persona': persona,
    'greeting': greeting,
    'tags': tags,
    'isBuiltin': isBuiltin,
  };
}

class AiRoleStore extends ChangeNotifier {
  static final AiRoleStore instance = AiRoleStore._();

  AiRoleStore._();

  static const _kKey = 'ai_role_play';

  List<AiRole> _roles = [];
  bool _loaded = false;

  List<AiRole> get roles => List.unmodifiable(_roles);

  bool get isLoaded => _loaded;

  static List<AiRole> _builtinRoles() => [
    AiRole(
      id: 'gentle_sister',
      name: t.roleGentleName,
      emoji: '👧',
      description: t.roleGentleDesc,
      persona: t.roleGentlePersona,
      greeting: t.roleGentleGreeting,
      tags: const ['温柔'],
      isBuiltin: true,
    ),
    AiRole(
      id: 'tsundere_junior',
      name: t.roleTsundereName,
      emoji: '😤',
      description: t.roleTsundereDesc,
      persona: t.roleTsunderePersona,
      greeting: t.roleTsundereGreeting,
      tags: const ['傲娇'],
      isBuiltin: true,
    ),
    AiRole(
      id: 'professor',
      name: t.roleProfessorName,
      emoji: '🎓',
      description: t.roleProfessorDesc,
      persona: t.roleProfessorPersona,
      greeting: t.roleProfessorGreeting,
      tags: const ['博学'],
      isBuiltin: true,
    ),
  ];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    _roles = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _roles = [
            for (final e in decoded)
              if (e is Map) AiRole.fromJson(e.cast<String, dynamic>()),
          ];
        }
      } catch (_) {
        _roles = [];
      }
    }
    var changed = false;
    for (final b in _builtinRoles()) {
      final idx = _roles.indexWhere((r) => r.id == b.id);
      if (idx < 0) {
        _roles.insert(0, b);
        changed = true;
      } else {
        final old = _roles[idx];
        _roles[idx] = AiRole(
          id: old.id,
          name: b.name,
          emoji: old.emoji.isEmpty ? b.emoji : old.emoji,
          description: b.description,
          persona: old.persona.isEmpty ? b.persona : old.persona,
          greeting: old.greeting.isEmpty ? b.greeting : old.greeting,
          tags: old.tags,
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
      jsonEncode([for (final r in _roles) r.toJson()]),
    );
  }

  Future<void> upsert(AiRole role) async {
    await ensureLoaded();
    final idx = _roles.indexWhere((r) => r.id == role.id);
    if (idx >= 0) {
      _roles[idx] = role;
    } else {
      _roles.add(role);
    }
    await _save();
    notifyListeners();
  }

  /// 删除角色；内置角色拒绝删除并返回 false
  Future<bool> remove(String id) async {
    await ensureLoaded();
    AiRole? target;
    for (final r in _roles) {
      if (r.id == id) {
        target = r;
        break;
      }
    }
    if (target != null && target.isBuiltin) return false;
    _roles.removeWhere((r) => r.id == id);
    await _save();
    notifyListeners();
    return true;
  }
}

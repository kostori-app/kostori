// 通用 JSON 差分指令：模型输出 <actions> JSON 数组，应用到任意 JSON 对象。
// 供「设定/世界书条目 AI 精修」等通用场景使用。

import 'dart:convert';

class JsonAction {
  final String type; // set | add | remove
  final String path;
  final Object? value;
  final int? index;

  const JsonAction({
    required this.type,
    required this.path,
    this.value,
    this.index,
  });
}

/// 从文本里解析 `<actions>[...]</actions>`；兼容数组外的杂散对象
List<JsonAction> parseJsonActions(String text) {
  final m = RegExp(r'<actions>([\s\S]*?)</actions>').firstMatch(text);
  if (m == null) return const [];
  final raw = m.group(1)!.trim();
  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    decoded = null;
  }
  if (decoded is! List) {
    final objs = <Object?>[];
    final re = RegExp(r'\{(?:[^{}]|(?:\{[^{}]*\}))*?\}');
    for (final om in re.allMatches(raw)) {
      try {
        objs.add(jsonDecode(om.group(0)!));
      } catch (_) {}
    }
    decoded = objs;
  }
  return [
    for (final e in decoded)
      if (e is Map && e['type'] != null && e['path'] != null)
        JsonAction(
          type: e['type'].toString(),
          path: e['path'].toString(),
          value: e['value'],
          index: (e['index'] as num?)?.toInt(),
        ),
  ];
}

/// 深拷贝后依次应用差分，返回新对象
Map<String, dynamic> applyJsonActions(
  Map<String, dynamic> root,
  List<JsonAction> actions,
) {
  final json = jsonDecode(jsonEncode(root)) as Map<String, dynamic>;
  for (final a in actions) {
    try {
      _applyOne(json, a);
    } catch (_) {
      // 单条失败不影响其它
    }
  }
  return json;
}

class _Seg {
  final String key;
  final int? index;
  const _Seg(this.key, this.index);
}

List<_Seg> _parsePath(String path) {
  final segs = <_Seg>[];
  for (final part in path.split('.')) {
    if (part.trim().isEmpty) continue;
    final m = RegExp(r'^(\w+)(?:\[(\d+)\])?$').firstMatch(part.trim());
    if (m == null) {
      segs.add(_Seg(part.trim(), null));
    } else {
      segs.add(_Seg(m.group(1)!, m.group(2) == null ? null : int.parse(m.group(2)!)));
    }
  }
  return segs;
}

void _applyOne(Map<String, dynamic> root, JsonAction a) {
  final segs = _parsePath(a.path);
  if (segs.isEmpty) return;

  // 定位到「最后一段的父容器」
  Object? container = root;
  for (var i = 0; i < segs.length - 1; i++) {
    final s = segs[i];
    if (container is Map) {
      container = container[s.key];
    } else if (container is List && s.index != null) {
      container = container[s.index!];
    } else {
      return;
    }
    if (s.index != null && container is List) {
      container = container[s.index!];
    }
  }

  final last = segs.last;
  switch (a.type) {
    case 'set':
      if (container is Map) {
        if (last.index != null && container[last.key] is List) {
          final list = container[last.key] as List;
          if (last.index! >= 0 && last.index! < list.length) {
            list[last.index!] = a.value;
          }
        } else if (a.index != null && container[last.key] is List) {
          final list = container[last.key] as List;
          if (a.index! >= 0 && a.index! < list.length) list[a.index!] = a.value;
        } else {
          container[last.key] = a.value;
        }
      } else if (container is List && last.index != null) {
        if (last.index! >= 0 && last.index! < container.length) {
          container[last.index!] = a.value;
        }
      }
    case 'add':
      final target = (container is Map) ? container[last.key] : null;
      if (target is List) target.add(a.value);
    case 'remove':
      final target = (container is Map) ? container[last.key] : null;
      if (target is List) {
        final i = a.index ?? last.index ?? -1;
        if (i >= 0 && i < target.length) target.removeAt(i);
      }
  }
}

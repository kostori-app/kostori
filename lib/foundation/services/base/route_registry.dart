part of 'package:kostori/foundation/services/services.dart';

typedef RouteHandler = Future<void> Function(HttpRequest request);

// RouteEntry 加上 doc 字段
class RouteEntry {
  final RouteHandler handler;
  final List<MiddlewareHandler> middlewares;
  final RouteDoc? doc;

  RouteEntry(this.handler, {this.middlewares = const [], this.doc});
}

class RouteRegistry {
  final Map<String, Map<String, RouteEntry>> _routes = {};
  final Map<String, List<_ParamRoute>> _paramRoutes = {};

  void register(
    String method,
    String path,
    RouteHandler handler, {
    List<MiddlewareHandler> middlewares = const [],
    RouteDoc? doc,
  }) {
    final entry = RouteEntry(handler, middlewares: middlewares, doc: doc);
    if (path.contains(':')) {
      _paramRoutes
          .putIfAbsent(method.toUpperCase(), () => [])
          .add(_ParamRoute(path, entry));
    } else {
      _routes.putIfAbsent(
        method.toUpperCase(),
        () => <String, RouteEntry>{},
      )[path] = entry;
    }
  }

  void addGet(
    String path,
    RouteHandler handler, {
    List<MiddlewareHandler> middlewares = const [],
    RouteDoc? doc,
  }) => register('GET', path, handler, middlewares: middlewares, doc: doc);

  void addPost(
    String path,
    RouteHandler handler, {
    List<MiddlewareHandler> middlewares = const [],
    RouteDoc? doc,
  }) => register('POST', path, handler, middlewares: middlewares, doc: doc);

  void addPut(
    String path,
    RouteHandler handler, {
    List<MiddlewareHandler> middlewares = const [],
    RouteDoc? doc,
  }) => register('PUT', path, handler, middlewares: middlewares, doc: doc);

  void addDelete(
    String path,
    RouteHandler handler, {
    List<MiddlewareHandler> middlewares = const [],
    RouteDoc? doc,
  }) => register('DELETE', path, handler, middlewares: middlewares, doc: doc);

  RouteMatch? resolve(String method, String path) {
    final exact = _routes[method.toUpperCase()]?[path];
    if (exact != null) return RouteMatch(exact, {});

    for (final paramRoute in _paramRoutes[method.toUpperCase()] ?? []) {
      final params = paramRoute.match(path);
      if (params != null) return RouteMatch(paramRoute.entry, params);
    }

    return null;
  }

  List<Map<String, dynamic>> registeredRoutes() {
    final list = <Map<String, dynamic>>[];

    for (final method in _routes.keys) {
      for (final entry in _routes[method]!.entries) {
        list.add({
          'method': method,
          'path': entry.key,
          'type': 'exact',
          'doc': entry.value.doc != null
              ? {
                  'summary': entry.value.doc!.summary,
                  'description': entry.value.doc!.description,
                  'requiresAuth': entry.value.doc!.requiresAuth,
                  'params': entry.value.doc!.params
                      .map((p) => p.toJson())
                      .toList(),
                  'response': entry.value.doc!.response,
                }
              : null,
        });
      }
    }

    for (final method in _paramRoutes.keys) {
      for (final route in _paramRoutes[method]!) {
        list.add({
          'method': method,
          'path': route.pattern,
          'type': 'param',
          'doc': route.entry.doc != null
              ? {
                  'summary': route.entry.doc!.summary,
                  'description': route.entry.doc!.description,
                  'requiresAuth': route.entry.doc!.requiresAuth,
                  'params': route.entry.doc!.params
                      .map((p) => p.toJson())
                      .toList(),
                  'response': route.entry.doc!.response,
                }
              : null,
        });
      }
    }

    return list;
  }
}

class _ParamRoute {
  final String pattern;
  final RouteEntry entry;
  final RegExp _regex;
  final List<String> _paramNames;

  _ParamRoute._(this.pattern, this.entry, this._regex, this._paramNames);

  factory _ParamRoute(String pattern, RouteEntry entry) {
    final paramNames = RegExp(
      r':(\w+)',
    ).allMatches(pattern).map((m) => m.group(1)!).toList();

    // 先处理好pattern，再拼接正则字符串
    final regexPattern = pattern.replaceAll(RegExp(r':(\w+)'), r'([^/]+)');
    final regex = RegExp('^$regexPattern\$');

    return _ParamRoute._(pattern, entry, regex, paramNames);
  }

  Map<String, String>? match(String path) {
    final m = _regex.firstMatch(path);
    if (m == null) return null;
    return {
      for (int i = 0; i < _paramNames.length; i++)
        _paramNames[i]: m.group(i + 1)!,
    };
  }
}

class RouteMatch {
  final RouteEntry entry;
  final Map<String, String> params;

  RouteMatch(this.entry, this.params);
}

// 文档参数
class DocParam {
  final String name;
  final String type; // query / path / body / header
  final String description;
  final bool required;
  final String? example;

  const DocParam({
    required this.name,
    required this.type,
    this.description = '',
    this.required = false,
    this.example,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'in': type,
    'description': description,
    'required': required,
    if (example != null) 'example': example,
  };
}

// 路由文档
class RouteDoc {
  final String summary;
  final String description;
  final List<DocParam> params;
  final String? response;
  final bool requiresAuth;

  const RouteDoc({
    this.summary = '',
    this.description = '',
    this.params = const [],
    this.response,
    this.requiresAuth = false,
  });
}

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/utils/ext.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'cookie_jar.g.dart';

// ═══════════════════════════════════════════════════════════
// 表定义
// ═══════════════════════════════════════════════════════════

class CookiesTable extends Table {
  @override
  String get tableName => 'cookies';

  TextColumn get name => text()();

  TextColumn get value => text()();

  TextColumn get domain => text()();

  TextColumn get path => text().nullable()();

  IntColumn get expires => integer().nullable()();

  BoolColumn get secure => boolean().withDefault(const Constant(false))();

  BoolColumn get httpOnly =>
      boolean().named('httpOnly').withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {name, domain, path};
}

// ═══════════════════════════════════════════════════════════
// 数据库
// ═══════════════════════════════════════════════════════════

@DriftDatabase(tables: [CookiesTable])
class _CookieDb extends _$_CookieDb {
  _CookieDb(String dbPath) : super(_openConn(dbPath));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (m) => m.createAll());
}

LazyDatabase _openConn(String dbPath) => LazyDatabase(() async {
  return NativeDatabase(
  File(dbPath),
  setup: (db) {
    db.execute('PRAGMA journal_mode = WAL;');
    db.execute('PRAGMA synchronous = NORMAL;');
  },
);
});

// ═══════════════════════════════════════════════════════════
// CookieJarSql
// ═══════════════════════════════════════════════════════════

class CookieJarSql {
  late _CookieDb _db;
  final String path;

  CookieJarSql(this.path) {
    _db = _CookieDb(path);
  }

  Future<T> _withDb<T>(Future<T> Function() op) async {
    try {
      return await op();
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('connection was closed') ||
          msg.contains("Can't re-open a database")) {
        _db = _CookieDb(path);
        return await op();
      }
      rethrow;
    }
  }

  Cookie _rowToCookie(CookiesTableData r) => Cookie(r.name, r.value)
    ..domain = r.domain
    ..path = r.path
    ..expires = r.expires != null
        ? DateTime.fromMillisecondsSinceEpoch(r.expires!)
        : null
    ..secure = r.secure
    ..httpOnly = r.httpOnly;

  Future<void> saveFromResponse(Uri uri, List<Cookie> cookies) async {
    final current = await loadForRequest(uri);
    for (var cookie in cookies) {
      if (cookie.name != 'cf_clearance') {
        final currentCookie = current.firstWhereOrNull(
          (e) =>
              e.name == cookie.name &&
              (cookie.path == null || cookie.path!.startsWith(e.path!)),
        );
        if (currentCookie != null) cookie.domain = currentCookie.domain;
      }
      await _withDb(
        () => _db
            .into(_db.cookiesTable)
            .insertOnConflictUpdate(
              CookiesTableCompanion(
                name: Value(cookie.name),
                value: Value(cookie.value),
                domain: Value(cookie.domain ?? uri.host),
                path: Value(cookie.path ?? '/'),
                expires: Value(cookie.expires?.millisecondsSinceEpoch),
                secure: Value(cookie.secure),
                httpOnly: Value(cookie.httpOnly),
              ),
            ),
      );
    }
  }

  Future<List<Cookie>> _loadWithDomain(String domain) async {
    return _withDb(() async {
      final rows = await (_db.select(
        _db.cookiesTable,
      )..where((t) => t.domain.equals(domain))).get();
      return rows.map(_rowToCookie).toList();
    });
  }

  List<String> _getAcceptedDomains(String host) {
    final parts = host.split('.');
    return [
      host,
      for (var i = 0; i < parts.length - 1; i++)
        '.${parts.sublist(i).join('.')}',
    ];
  }

  Future<List<Cookie>> loadForRequest(Uri uri) async {
    final acceptedDomains = _getAcceptedDomains(uri.host);
    final cookies = <Cookie>[];
    for (final domain in acceptedDomains) {
      cookies.addAll(await _loadWithDomain(domain));
    }

    final now = DateTime.now();
    final expired = cookies
        .where((c) => c.expires != null && c.expires!.isBefore(now))
        .toList();

    for (final c in expired) {
      await _withDb(
        () =>
            (_db.delete(_db.cookiesTable)..where(
                  (t) =>
                      t.name.equals(c.name) &
                      t.domain.equals(c.domain!) &
                      t.path.equals(c.path!),
                ))
                .go(),
      );
    }

    return cookies
        .where((e) => !expired.contains(e) && _checkPathMatch(uri, e.path))
        .toList();
  }

  bool _checkPathMatch(Uri uri, String? cookiePath) {
    if (cookiePath == null || cookiePath == '/' || cookiePath == uri.path) {
      return true;
    }
    return uri.path.startsWith(
      cookiePath.endsWith('/') ? cookiePath : cookiePath,
    );
  }

  Future<void> saveFromResponseCookieHeader(
    Uri uri,
    List<String> cookieHeader,
  ) async {
    final cookies = <Cookie>[];
    for (final header in cookieHeader) {
      try {
        cookies.add(Cookie.fromSetCookieValue(header));
      } catch (_) {
        Log.warning('Network', 'Invalid cookie header: $header');
      }
    }
    await saveFromResponse(uri, cookies);
  }

  Future<String> loadForRequestCookieHeader(Uri uri) async {
    final cookies = await loadForRequest(uri);
    final map = <String, Cookie>{};
    for (final cookie in cookies) {
      if (map.containsKey(cookie.name)) {
        if (cookie.domain![0] != '.' && map[cookie.name]!.domain![0] == '.') {
          map[cookie.name] = cookie;
        } else if (cookie.domain!.length > map[cookie.name]!.domain!.length) {
          map[cookie.name] = cookie;
        }
      } else {
        map[cookie.name] = cookie;
      }
    }
    return map.entries
        .map((e) => '${e.value.name}=${e.value.value}')
        .join('; ');
  }

  Future<void> delete(Uri uri, String name) async {
    for (final domain in _getAcceptedDomains(uri.host)) {
      await _withDb(
        () =>
            (_db.delete(_db.cookiesTable)..where(
                  (t) =>
                      t.name.equals(name) &
                      t.domain.equals(domain) &
                      t.path.equals(uri.path),
                ))
                .go(),
      );
    }
  }

  Future<void> deleteCookieByName(String name) async {
    await _withDb(
      () => (_db.delete(
        _db.cookiesTable,
      )..where((t) => t.name.equals(name))).go(),
    );
  }

  Future<void> deleteUri(Uri uri) async {
    for (final domain in _getAcceptedDomains(uri.host)) {
      await _withDb(
        () => (_db.delete(
          _db.cookiesTable,
        )..where((t) => t.domain.equals(domain))).go(),
      );
    }
  }

  Future<void> deleteAll() async {
    await _withDb(() => _db.delete(_db.cookiesTable).go());
  }

  Future<void> dispose() async {
    await _db.close();
  }
}

// ═══════════════════════════════════════════════════════════
// SingleInstanceCookieJar
// ═══════════════════════════════════════════════════════════

class SingleInstanceCookieJar extends CookieJarSql {
  SingleInstanceCookieJar._create(super.path);

  static SingleInstanceCookieJar? instance;

  factory SingleInstanceCookieJar(String path) =>
      instance ??= SingleInstanceCookieJar._create(path);

  static Future<SingleInstanceCookieJar> createInstance() async {
    if (instance != null) return instance!;
    final dataPath = (await getApplicationSupportDirectory()).path;
    instance = SingleInstanceCookieJar(p.join(dataPath, 'cookie.db'));
    return instance!;
  }
}

// ═══════════════════════════════════════════════════════════
// CookieManagerSql（Dio 拦截器）
// ═══════════════════════════════════════════════════════════

class CookieManagerSql extends Interceptor {
  CookieJarSql get _jar => SingleInstanceCookieJar.instance!;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final cookies = await _jar.loadForRequestCookieHeader(options.uri);
    if (cookies.isNotEmpty) {
      final existing = options.headers['cookie'];
      options.headers['cookie'] = existing != null
          ? '$existing; $cookies'
          : cookies;
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    await _jar.saveFromResponseCookieHeader(
      response.requestOptions.uri,
      response.headers['set-cookie'] ?? [],
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.next(err);
  }
}

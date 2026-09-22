import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:kostori/database/db_common.dart';
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

  /// 正在进行中的重开（并发触发时共用一次，避免创建多个 drift 实例）
  Future<void>? _reopening;

  CookieJarSql(this.path) {
    _db = _CookieDb(path);
  }

  /// 重开数据库连接：先关旧连接再建新连接。
  /// （drift 对同一数据库类的多个存活实例会告警，多实例还有损坏风险）
  Future<void> _reopen() {
    final pending = _reopening;
    if (pending != null) return pending;
    final future = () async {
      try {
        await _db.close();
      } catch (_) {}
      _db = _CookieDb(path);
    }();
    _reopening = future;
    return future.whenComplete(() {
      if (identical(_reopening, future)) _reopening = null;
    });
  }

  Future<T> _withDb<T>(Future<T> Function() op) async {
    try {
      return await op();
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('connection was closed') ||
          msg.contains("Can't re-open a database")) {
        await _reopen();
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

  /// 全部 Cookie（跨端同步导出用）
  Future<List<CookiesTableData>> allRows() =>
      _withDb(() => _db.select(_db.cookiesTable).get());

  /// 把 WAL 里的改动写回主库文件（导出整库前调用）
  Future<void> checkpoint() => walCheckpoint(
    () =>
        _withDb(() => _db.customStatement('PRAGMA wal_checkpoint(TRUNCATE);')),
  );

  /// 跨端合并 Cookie：
  /// - 本机没有的同名（name+domain+path）Cookie 直接补齐；
  /// - 双方都有时取过期时间更晚的一条（会话 Cookie 或无法比较时保留本机），
  ///   避免用另一端的旧登录态覆盖本机；
  /// - `cf_clearance` 与设备/IP 绑定，本机已有就保留本机。
  Future<void> mergeCookies(List<CookiesTableData> rows) async {
    if (rows.isEmpty) return;
    final localRows = await _withDb(() => _db.select(_db.cookiesTable).get());
    final local = <String, CookiesTableData>{
      for (final r in localRows) _cookieKey(r.name, r.domain, r.path): r,
    };

    final toWrite = <CookiesTableData>[];
    for (final r in rows) {
      final l = local[_cookieKey(r.name, r.domain, r.path)];
      if (l == null) {
        toWrite.add(r);
        continue;
      }
      if (r.name == 'cf_clearance') continue;
      final remoteExpires = r.expires;
      final localExpires = l.expires;
      if (remoteExpires != null &&
          (localExpires == null || remoteExpires > localExpires)) {
        toWrite.add(r);
      }
    }
    if (toWrite.isEmpty) return;

    await _withDb(
      () => _db.batch((batch) {
        for (final r in toWrite) {
          batch.insert(
            _db.cookiesTable,
            CookiesTableCompanion(
              name: Value(r.name),
              value: Value(r.value),
              domain: Value(r.domain),
              path: Value(r.path),
              expires: Value(r.expires),
              secure: Value(r.secure),
              httpOnly: Value(r.httpOnly),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      }),
    );
  }

  static String _cookieKey(String name, String domain, String? path) =>
      '$name\u0000$domain\u0000$path';

  /// 关闭连接（数据导入替换 cookie.db 之前调用），完成后用 [reopen] 打开
  Future<void> close() async {
    final pending = _reopening;
    if (pending != null) {
      try {
        await pending;
      } catch (_) {}
    }
    await _db.close();
  }

  /// 重新打开连接（与 [close] 配对；复用同一实例，避免多实例竞态）
  Future<void> reopen() => _reopen();
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

import 'dart:io';

import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/network/dns_resolver.dart';

/// 域名的地址来源方式。
enum DnsRuleMode {
  /// 不覆写：照常解析（用系统 DNS，除非规则另有指定）
  none,

  /// hosts 设置：像 hosts 文件一样，把域名直接指向填好的 IP，完全不查 DNS
  hosts,

  /// 指定 DNS：只用这里填的 DNS 服务器解析该域名，并发查询取最快返回的
  servers;

  static DnsRuleMode parse(String? v) => switch (v) {
    // 早期版本把这个模式记作 static
    'hosts' || 'static' => DnsRuleMode.hosts,
    'servers' => DnsRuleMode.servers,
    _ => DnsRuleMode.none,
  };

  String get value => name;
}

/// 一条域名规则：地址来源（hosts / 指定 DNS）与「无代理」收敛到同一条
/// 条目上，因为都是按域名匹配的，写在一起更好读也更好维护。
class DomainRule {
  const DomainRule({
    required this.domain,
    this.enabled = true,
    this.dnsMode = DnsRuleMode.none,
    this.ips = const [],
    this.servers = const [],
    this.noProxy = false,
  });

  final String domain;

  /// 整条规则是否生效（关掉即整条不参与匹配）。
  final bool enabled;

  final DnsRuleMode dnsMode;

  /// [DnsRuleMode.hosts] 时直接使用的 IP，可多个（请求并发竞速，取最先响应的）。
  final List<String> ips;

  /// [DnsRuleMode.servers] 时使用的 DNS 服务器，可多个（并发查询取最快返回的）。
  final List<String> servers;

  /// 命中该域名时忽略代理直连（与地址来源方式互相独立）。
  final bool noProxy;

  DomainRule copyWith({
    String? domain,
    bool? enabled,
    DnsRuleMode? dnsMode,
    List<String>? ips,
    List<String>? servers,
    bool? noProxy,
  }) => DomainRule(
    domain: domain ?? this.domain,
    enabled: enabled ?? this.enabled,
    dnsMode: dnsMode ?? this.dnsMode,
    ips: ips ?? this.ips,
    servers: servers ?? this.servers,
    noProxy: noProxy ?? this.noProxy,
  );

  /// 去掉空白项与重复项，避免用户多打一个逗号/空格就多出一条空项。
  List<String> get normalizedIps => _cleanList(ips);

  List<String> get normalizedServers => _cleanList(servers);

  factory DomainRule.fromJson(Map json) => DomainRule(
    domain: (json['domain'] ?? '').toString().trim(),
    enabled: json['enabled'] as bool? ?? true,
    dnsMode: DnsRuleMode.parse(json['dns']?.toString()),
    // 早期版本只有单个 ip 字段
    ips: _toStringList(json['ips'] ?? json['ip']),
    servers: _toStringList(json['servers']),
    noProxy: json['noProxy'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'domain': domain,
    'enabled': enabled,
    'dns': dnsMode.value,
    'ips': normalizedIps,
    'servers': normalizedServers,
    'noProxy': noProxy,
  };
}

/// 点分隔后缀匹配，让 bgm.tv 这类规则能命中 api.bgm.tv；
/// 只填单个主机名（如 bgm）时按「标签相等」匹配，兼容旧条目：
/// bgm 能命中 bgm.tv、api.bgm.tv。
bool hostMatchesDomain(String host, String domain) {
  if (domain.isEmpty || host.isEmpty) return false;
  final h = host.toLowerCase();
  final d = domain.toLowerCase();
  if (h == d) return true;
  if (h.endsWith('.$d')) return true;
  if (!d.contains('.') && h.split('.').contains(d)) return true;
  return false;
}

const _rulesKey = 'domainRules';

List<DomainRule>? _rulesCache;
List<dynamic>? _rulesCacheKey;

/// 读取全部域名规则。
///
/// 旧数据在首次读取时并进来：
/// - `noProxyOverrides`（整份替换成规则列表）
/// - `dnsOverrides`（域名 -> IP，并成 hosts 模式的规则，执行后清空旧键）
///
/// 解析结果按原始 List 实例缓存：每个请求都要读一次设置，逐条映射没有必要。
List<DomainRule> loadDomainRules() {
  var raw = appdata.settings[_rulesKey];
  if (raw == null) {
    final migrated = _migrateLegacyRules();
    saveDomainRules(migrated);
    raw = appdata.settings[_rulesKey];
  }
  final cached = _rulesCache;
  if (cached != null && identical(_rulesCacheKey, raw)) return cached;
  if (raw is! List) return const [];
  var rules = raw
      .whereType<Map>()
      .map(DomainRule.fromJson)
      .where((e) => e.domain.isNotEmpty)
      .toList();
  rules = _absorbLegacyHosts(rules);
  _rulesCache = rules;
  _rulesCacheKey = appdata.settings[_rulesKey];
  return rules;
}

void saveDomainRules(List<DomainRule> rules) {
  appdata.settings[_rulesKey] = rules.map((e) => e.toJson()).toList();
  appdata.saveData();
  DnsResolver.clearCache();
}

/// 命中 [host] 的第一条规则（按列表顺序，靠前的优先）。
/// 同一域名可以有多条规则：取第一条命中的。
DomainRule? matchDomainRule(List<DomainRule> rules, String host) {
  for (final rule in rules) {
    if (!rule.enabled) continue;
    if (hostMatchesDomain(host, rule.domain)) return rule;
  }
  return null;
}

/// 命中 [host] 的第一条带地址来源（hosts / 指定 DNS）的规则。
///
/// 与 [matchDomainRule] 不同：只关心 DNS 覆写的规则，纯「忽略代理」的规则
/// 不会挡住同域名后面的 hosts / 指定 DNS 规则。
DomainRule? matchDnsRule(List<DomainRule> rules, String host) {
  for (final rule in rules) {
    if (!rule.enabled || rule.dnsMode == DnsRuleMode.none) continue;
    if (hostMatchesDomain(host, rule.domain)) return rule;
  }
  return null;
}

/// 该域名是否需要忽略代理。
///
/// 与地址来源方式完全独立：只要有任意一条启用中的规则对它标了直连就直连，
/// 不受同域名其它规则是不是 hosts 设置影响。
bool shouldBypassProxy(List<DomainRule> rules, String host) {
  for (final rule in rules) {
    if (!rule.enabled || !rule.noProxy) continue;
    if (hostMatchesDomain(host, rule.domain)) return true;
  }
  return false;
}

/// DNS 覆写总开关（含 hosts 与「指定 DNS」两种方式）。
bool get dnsOverridesEnabled => appdata.settings['enableDnsOverrides'] == true;

void setDnsOverridesEnabled(bool value) {
  appdata.settings['enableDnsOverrides'] = value;
  appdata.saveData();
  DnsResolver.clearCache();
}

/// 无代理覆写总开关。
bool get noProxyOverridesEnabled =>
    appdata.settings['enableNoProxyOverrides'] != false;

void setNoProxyOverridesEnabled(bool value) {
  appdata.settings['enableNoProxyOverrides'] = value;
  appdata.saveData();
}

/// 规则里可直接使用的 IP（过滤非法项，避免把坏地址交给底层客户端）。
List<String> hostsIpsOf(DomainRule rule) => rule.normalizedIps
    .where((ip) => InternetAddress.tryParse(ip) != null)
    .toList();

/// 规则里可直接使用的 DNS 服务器（过滤非法项）。
List<DnsEndpoint> dnsServersOf(DomainRule rule) => rule.normalizedServers
    .map(DnsEndpoint.tryParse)
    .whereType<DnsEndpoint>()
    .toList();

/// 交给底层客户端的 hosts 表：域名（小写、去尾点）-> IP 列表。
Map<String, List<String>> buildHostsOverrides(List<DomainRule> rules) {
  final result = <String, List<String>>{};
  for (final rule in rules) {
    if (!rule.enabled || rule.dnsMode != DnsRuleMode.hosts) continue;
    final ips = hostsIpsOf(rule);
    if (ips.isEmpty) continue;
    result.putIfAbsent(_normalizeHost(rule.domain), () => ips);
  }
  return result;
}

/// 是否有启用中的「指定 DNS」规则（有才需要切到动态解析器）。
bool hasDnsServerRules(List<DomainRule> rules) => rules.any(
  (e) =>
      e.enabled &&
      e.dnsMode == DnsRuleMode.servers &&
      dnsServersOf(e).isNotEmpty,
);

/// 构造一次解析的配置快照：[rule] 为空或不是「指定 DNS」时没有自定义上游，
/// 由解析器回落系统解析。
DnsPlan buildDnsPlan(DomainRule? rule) {
  final servers = rule != null && rule.dnsMode == DnsRuleMode.servers
      ? dnsServersOf(rule)
      : const <DnsEndpoint>[];
  return DnsPlan(
    servers: servers,
    signature: servers.map((e) => e.text).join(','),
  );
}

/// 旧版 dnsOverrides 的条目：域名 -> 单个 IP。
/// 现在有 hosts 模式了，这些会被一次性搬进规则列表（见 [_absorbLegacyHosts]），
/// 搬完就把旧键清空，因此这里只会读到一次。
Map<String, String> _legacyHostsEntries() {
  final config = appdata.settings['dnsOverrides'];
  if (config is! Map) return const {};
  final result = <String, String>{};
  for (final entry in config.entries) {
    final domain = _normalizeHost(entry.key.toString());
    if (domain.isEmpty) continue;
    final value = entry.value;
    final enabled = value is Map ? (value['enabled'] as bool? ?? true) : true;
    final ip = value is Map ? value['ip']?.toString() ?? '' : '$value';
    final trimmed = ip.trim();
    if (!enabled || InternetAddress.tryParse(trimmed) == null) continue;
    result.putIfAbsent(domain, () => trimmed);
  }
  return result;
}

/// 把旧版 dnsOverrides（域名 -> IP）并进规则列表的 hosts 模式。
///
/// 只在旧键还有内容时执行一次；执行后清空旧键，避免用户删掉规则后又被搬回来。
List<DomainRule> _absorbLegacyHosts(List<DomainRule> rules) {
  final legacy = _legacyHostsEntries();
  if (legacy.isEmpty) return rules;

  final result = List<DomainRule>.of(rules);
  for (final entry in legacy.entries) {
    final index = result.indexWhere(
      (e) => _normalizeHost(e.domain) == entry.key,
    );
    if (index < 0) {
      result.add(
        DomainRule(
          domain: entry.key,
          dnsMode: DnsRuleMode.hosts,
          ips: [entry.value],
        ),
      );
      continue;
    }
    // 同域名已有规则：只在还没指定地址时补 IP，不覆盖用户的选择
    if (result[index].dnsMode != DnsRuleMode.none) continue;
    result[index] = result[index].copyWith(
      dnsMode: DnsRuleMode.hosts,
      ips: [entry.value],
    );
  }

  appdata.settings[_rulesKey] = result.map((e) => e.toJson()).toList();
  appdata.settings['dnsOverrides'] = <String, dynamic>{};
  appdata.saveData();
  return result;
}

String _normalizeHost(String host) {
  var value = host.trim().toLowerCase();
  while (value.endsWith('.')) {
    value = value.substring(0, value.length - 1);
  }
  return value;
}

List<String> _cleanList(List<String> values) {
  final result = <String>[];
  for (final value in values) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || result.contains(trimmed)) continue;
    result.add(trimmed);
  }
  return result;
}

List<String> _toStringList(dynamic raw) {
  if (raw == null) return const [];
  if (raw is String) return raw.trim().isEmpty ? const [] : [raw.trim()];
  if (raw is List) {
    return raw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return const [];
}

/// 把旧版的「无代理覆写」列表搬进统一规则列表。
/// 旧列表在设置里带着默认值（Bangumi 直连），所以这里不需要另外给默认规则 ——
/// 用户清空过列表的话也应尊重其清空结果。
List<DomainRule> _migrateLegacyRules() {
  final merged = <String, DomainRule>{};
  final order = <String>[];

  void touch(String domain) {
    final key = _normalizeHost(domain);
    if (key.isEmpty || merged.containsKey(key)) return;
    merged[key] = DomainRule(domain: key);
    order.add(key);
  }

  final noProxy = appdata.settings['noProxyOverrides'];
  if (noProxy is List) {
    for (final entry in noProxy) {
      final domain = entry is Map
          ? entry['domain']?.toString() ?? ''
          : entry.toString();
      if (domain.isEmpty) continue;
      final enabled = entry is Map ? (entry['enabled'] as bool? ?? true) : true;
      if (!enabled) continue;
      touch(domain);
      final key = _normalizeHost(domain);
      merged[key] = merged[key]!.copyWith(noProxy: true);
    }
  }

  return [for (final key in order) merged[key]!];
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/js_engine.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/network/dns_resolver.dart';
import 'package:kostori/network/domain_rules.dart';
import 'package:kostori/network/hosts_probe.dart';

/// 域名规则页：把原先分开的「DNS 覆写」与「无代理覆写」合并到一处。
///
/// 两者本质都是按域名匹配的规则：一条规则可以把域名指向指定的 IP
/// （像 hosts 文件那样完全不查 DNS），也可以只让它忽略代理直连。
class DomainRuleManagerPage extends StatefulWidget {
  const DomainRuleManagerPage({super.key});

  @override
  State<DomainRuleManagerPage> createState() => _DomainRuleManagerPageState();
}

class _DomainRuleManagerPageState extends State<DomainRuleManagerPage> {
  late List<DomainRule> _rules;
  late bool _dnsEnabled;
  late bool _noProxyEnabled;

  /// IP -> 测速耗时文案（ms），统一测速后显示在每个 IP 后面
  final Map<String, String> _latencies = {};
  bool _probing = false;

  @override
  void initState() {
    super.initState();
    _rules = List.of(loadDomainRules());
    _dnsEnabled = dnsOverridesEnabled;
    _noProxyEnabled = noProxyOverridesEnabled;
  }

  void _reloadRules() {
    setState(() {
      _rules = List.of(loadDomainRules());
      _dnsEnabled = dnsOverridesEnabled;
      _noProxyEnabled = noProxyOverridesEnabled;
      _latencies.clear();
    });
  }

  void _persistRules(List<DomainRule> rules) {
    saveDomainRules(rules);
    JsEngine().resetDio();
    setState(() {
      _rules = rules;
      _latencies.clear();
    });
  }

  void _addRule() async {
    final changed = await showPopUpWidget<bool?>(
      context,
      const DomainRuleEditorPage(),
    );
    if (changed ?? false) _reloadRules();
  }

  void _editRule(int index) async {
    final changed = await showPopUpWidget<bool?>(
      context,
      DomainRuleEditorPage(index: index),
    );
    if (changed ?? false) _reloadRules();
  }

  void _deleteRule(int index) {
    final rules = List.of(_rules)..removeAt(index);
    _persistRules(rules);
    context.showMessage(message: t.ruleDeleted);
  }

  /// 统一给所有 hosts 规则里的多个 IP 测速：一次并发测完，
  /// 每个域名下的 IP 各按快慢重排后保存。
  Future<void> _probeAll() async {
    if (_probing) return;
    final targets = <String>{};
    for (final rule in _rules) {
      if (!rule.enabled || rule.dnsMode != DnsRuleMode.hosts) continue;
      final ips = hostsIpsOf(rule);
      if (ips.length < 2) continue;
      targets.addAll(ips);
    }
    if (targets.isEmpty) {
      context.showMessage(
        message: t.hostsNeedMultipleIps,
        level: LogLevel.warning,
      );
      return;
    }

    setState(() => _probing = true);
    final results = await runWithLoadingDialog<List<HostsProbeResult>>(
      context,
      message: t.hostsProbing,
      task: (_) => HostsProbe.probeAll(targets.toList()),
    );
    if (!mounted) return;

    final byIp = {for (final result in results) result.ip: result};
    final updated = [
      for (final rule in _rules)
        if (rule.enabled &&
            rule.dnsMode == DnsRuleMode.hosts &&
            hostsIpsOf(rule).length > 1)
          rule.copyWith(ips: HostsProbe.sortBySpeed(hostsIpsOf(rule), byIp))
        else
          rule,
    ];
    saveDomainRules(updated);
    JsEngine().resetDio();

    HostsProbeResult? fastest;
    for (final result in results) {
      if (!result.ok) continue;
      if (fastest == null || result.latency! < fastest.latency!) {
        fastest = result;
      }
    }
    final unreachable = results.where((e) => !e.ok).length;

    setState(() {
      _probing = false;
      _rules = updated;
      _latencies
        ..clear()
        ..addAll({
          for (final result in results)
            if (result.ok) result.ip: '${result.latency} ms',
        });
    });

    if (fastest == null) {
      context.showMessage(message: t.hostsAllUnreachable);
    } else if (unreachable > 0) {
      context.showMessage(
        message: t.hostsSortedWithUnreachable(count: unreachable),
      );
    } else {
      context.showMessage(
        message: t.hostsSortedFastest(latency: fastest.latency!),
      );
    }
  }

  void _toggleDns(bool value) {
    setDnsOverridesEnabled(value);
    setState(() => _dnsEnabled = value);
    JsEngine().resetDio();
  }

  void _toggleNoProxy(bool value) {
    setNoProxyOverridesEnabled(value);
    setState(() => _noProxyEnabled = value);
    JsEngine().resetDio();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopUpWidgetScaffold(
      title: t.domainRules,
      tailing: [
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: t.add,
          onPressed: _addRule,
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          _HintCard(text: t.domainRulesDesc),
          const SizedBox(height: 16),
          _Card(
            children: [
              _SwitchRow(
                title: t.enableDnsOverrides,
                subtitle: t.enableDnsOverridesDesc,
                value: _dnsEnabled,
                onChanged: _toggleDns,
              ),
              Divider(height: 1, color: cs.outlineVariant),
              _SwitchRow(
                title: t.enableNoProxyOverrides,
                subtitle: t.enableNoProxyOverridesDesc,
                value: _noProxyEnabled,
                onChanged: _toggleNoProxy,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_rules.isEmpty)
            _HintCard(text: t.domainRulesEmpty, icon: Icons.inbox_outlined)
          else
            for (var i = 0; i < _rules.length; i++) _ruleCard(_rules[i], i),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              CapsuleButton(
                text: t.addRule,
                leading: const Icon(Icons.add, size: 16),
                onTap: _addRule,
              ),
              CapsuleButton(
                text: t.hostsSortBySpeed,
                leading: const Icon(Icons.speed, size: 16),
                isLoading: _probing,
                onTap: _probeAll,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            t.hostsSortBySpeedHint,
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _ruleCard(DomainRule rule, int index) {
    final cs = Theme.of(context).colorScheme;
    final badges = <Widget>[];
    switch (rule.dnsMode) {
      case DnsRuleMode.none:
        break;
      case DnsRuleMode.hosts:
        badges.add(_Tag(text: t.dnsModeHosts, color: cs.primary));
      case DnsRuleMode.servers:
        badges.add(_Tag(text: t.dnsModeServers, color: cs.primary));
    }
    if (rule.noProxy) {
      badges.add(_Tag(text: t.domainRuleBadgeNoProxy, color: cs.secondary));
    }
    final entries = switch (rule.dnsMode) {
      DnsRuleMode.none => const <String>[],
      DnsRuleMode.hosts => rule.normalizedIps,
      DnsRuleMode.servers => rule.normalizedServers,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: rule.enabled ? 1 : 0.5,
        child: Material(
          color: cs.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: cs.outlineVariant, width: 0.6),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _editRule(index),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rule.domain,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (entries.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final entry in entries)
                                _Tag(
                                  text: entry,
                                  suffix: rule.dnsMode == DnsRuleMode.hosts
                                      ? _latencies[entry]
                                      : null,
                                ),
                            ],
                          ),
                        ],
                        if (badges.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(spacing: 6, runSpacing: 6, children: badges),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: t.edit,
                    onPressed: () => _editRule(index),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    tooltip: t.delete,
                    onPressed: () => _deleteRule(index),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 单条规则的编辑页。
class DomainRuleEditorPage extends StatefulWidget {
  const DomainRuleEditorPage({super.key, this.index});

  /// 为空表示新建
  final int? index;

  @override
  State<DomainRuleEditorPage> createState() => _DomainRuleEditorPageState();
}

class _DomainRuleEditorPageState extends State<DomainRuleEditorPage> {
  final TextEditingController _domainCtrl = TextEditingController();
  DnsRuleMode _mode = DnsRuleMode.none;
  bool _noProxy = false;
  bool _enabled = true;
  List<String> _ips = [];
  List<String> _servers = [];

  bool get _isNew => widget.index == null;

  @override
  void initState() {
    super.initState();
    final rules = loadDomainRules();
    final index = widget.index;
    if (index != null && index < rules.length) {
      final rule = rules[index];
      _domainCtrl.text = rule.domain;
      _mode = rule.dnsMode;
      _noProxy = rule.noProxy;
      _enabled = rule.enabled;
      _ips = List.of(rule.normalizedIps);
      _servers = List.of(rule.normalizedServers);
    }
  }

  @override
  void dispose() {
    _domainCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final domain = _domainCtrl.text.trim();
    if (domain.isEmpty) {
      _toast(t.domainRequired);
      return;
    }
    if (_mode == DnsRuleMode.hosts && _ips.isEmpty) {
      _toast(t.ipRequired);
      return;
    }
    if (_mode == DnsRuleMode.servers && _servers.isEmpty) {
      _toast(t.dnsServerRequired);
      return;
    }
    final rules = List.of(loadDomainRules());
    final rule = DomainRule(
      domain: domain,
      enabled: _enabled,
      dnsMode: _mode,
      // 两种模式的地址都存下来：dnsMode 决定用哪一份，另一份留着，
      // 否则 hosts ↔ 指定 DNS 来回切一次就得重填一遍
      ips: _ips,
      servers: _servers,
      noProxy: _noProxy,
    );
    final index = widget.index;
    if (index == null || index >= rules.length) {
      rules.add(rule);
    } else {
      rules[index] = rule;
    }
    saveDomainRules(rules);
    // 保存了 DNS/直连规则就顺手打开对应总开关，
    // 避免「只开了单条规则、总开关没开」导致看起来完全没生效
    if (_mode != DnsRuleMode.none) setDnsOverridesEnabled(true);
    if (_noProxy) setNoProxyOverridesEnabled(true);
    JsEngine().resetDio();
    _close(true);
  }

  /// 关掉整个弹层，并把结果带回 `showPopUpWidget` 的调用方。
  ///
  /// 本页挂在弹层内部自己的 Navigator 上（`PopUpWidget` 里还嵌了一层
  /// Navigator），直接 `context.pop()` 只会关掉内层这一页，外层路由原样
  /// 留在根导航器上，看起来就是「保存了但没退出」。这里顺着内层 Navigator
  /// 找到外层的弹层路由，精确地把它关掉；上面如果还盖着确认框之类的路由，
  /// 就绕开它们按路由移除。
  void _close([bool? result]) {
    final route = ModalRoute.of(Navigator.of(context).context);
    final navigator = route?.navigator;
    if (route == null || navigator == null) {
      context.pop(result);
      return;
    }
    if (route.isCurrent) {
      navigator.pop(result);
    } else {
      navigator.removeRoute(route, result);
    }
  }

  void _toast(String message) {
    context.showMessage(message: message, level: LogLevel.warning);
  }

  /// 用系统解析器（getaddrinfo，即系统当前在用的 DNS）把这个域名查出来，
  /// 直接填成 hosts 条目，省得手工查。
  ///
  /// 说明：
  /// - 走系统解析而不是应用内的规则 —— 目的就是拿到「此刻真实」的地址来钉住；
  /// - 不走代理，代理只作用于 HTTP(S) 请求本身；
  /// - 可能同时返回 IPv4 与 IPv6，IPv4 排在前面（多个地址是并发竞速，顺序只影响展示）；
  /// - 自动丢掉无用的地址（0.0.0.0 / :: / 169.254.* / fe80:* 链路本地 / 带 %scope 的）。
  Future<void> _resolveAndFill() async {
    final host = _domainCtrl.text.trim();
    if (host.isEmpty) {
      _toast(t.domainRequired);
      return;
    }
    final resolved = await runWithLoadingDialog<List<String>>(
      context,
      message: t.dnsResolving,
      task: (_) async {
        final result = await InternetAddress.lookup(host);
        final usable = <String>[];
        for (final info in result) {
          final ip = info.address.trim();
          if (ip.isEmpty || usable.contains(ip)) continue;
          final parsed = InternetAddress.tryParse(ip);
          if (parsed == null) continue;
          // 去掉指定/链路本地这类没法当目标地址的
          if (parsed.isLoopback ||
              ip == '0.0.0.0' ||
              ip == '::' ||
              ip.contains('%') ||
              ip.startsWith('169.254.') ||
              ip.toLowerCase().startsWith('fe80:')) {
            continue;
          }
          usable.add(ip);
        }
        // IPv4 排前面：多数网络下它更可能直接可用
        usable.sort((a, b) {
          final av4 =
              InternetAddress.tryParse(a)!.type == InternetAddressType.IPv4;
          final bv4 =
              InternetAddress.tryParse(b)!.type == InternetAddressType.IPv4;
          if (av4 == bv4) return 0;
          return av4 ? -1 : 1;
        });
        return usable;
      },
    );
    if (!mounted) return;
    if (resolved.isEmpty) {
      _toast(t.dnsResolveEmpty);
      return;
    }
    final merged = [..._ips];
    for (final address in resolved) {
      if (!merged.contains(address)) merged.add(address);
    }
    setState(() => _ips = merged);
  }

  void _delete() {
    final rules = List.of(loadDomainRules());
    final index = widget.index;
    if (index == null || index >= rules.length) return;
    rules.removeAt(index);
    saveDomainRules(rules);
    JsEngine().resetDio();
    _close(true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopUpWidgetScaffold(
      title: _isNew ? t.newRule : t.editRule,
      tailing: [CapsuleButton(text: t.save, primary: true, onTap: _save)],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(t.domain, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _domainCtrl,
            decoration: InputDecoration(
              hintText: 'bgm.tv',
              helperText: t.domainRuleDomainHint,
              helperMaxLines: 3,
            ),
          ),
          const SizedBox(height: 20),

          Text(t.dnsMode, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          CapsuleOptions(
            wrap: true,
            children: [
              for (final mode in DnsRuleMode.values)
                CapsuleOption(
                  text: switch (mode) {
                    DnsRuleMode.none => t.dnsModeNone,
                    DnsRuleMode.hosts => t.dnsModeHosts,
                    DnsRuleMode.servers => t.dnsModeServers,
                  },
                  isSelected: _mode == mode,
                  onTap: () => setState(() => _mode = mode),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(switch (_mode) {
            DnsRuleMode.none => t.dnsModeNoneDesc,
            DnsRuleMode.hosts => t.dnsModeHostsDesc,
            DnsRuleMode.servers => t.dnsModeServersDesc,
          }, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),

          if (_mode == DnsRuleMode.hosts) ...[
            const SizedBox(height: 16),
            _TokenEditor(
              values: _ips,
              placeholder: '1.1.1.1',
              invalidMessage: t.ipInvalid,
              validate: (value) => InternetAddress.tryParse(value) != null,
              onChanged: (values) => setState(() => _ips = values),
              trailingAction: CapsuleButton(
                text: t.dnsResolveNow,
                leading: const Icon(Icons.search, size: 16),
                onTap: _resolveAndFill,
              ),
            ),
          ],

          if (_mode == DnsRuleMode.servers) ...[
            const SizedBox(height: 16),
            _TokenEditor(
              values: _servers,
              placeholder: '1.1.1.1',
              invalidMessage: t.dnsServerInvalid,
              validate: (value) => DnsEndpoint.tryParse(value) != null,
              onChanged: (values) => setState(() => _servers = values),
            ),
            const SizedBox(height: 6),
            Text(
              t.dnsServerAddressHint,
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ],

          const SizedBox(height: 20),
          _Card(
            children: [
              _SwitchRow(
                title: t.domainRuleNoProxy,
                subtitle: t.domainRuleNoProxyDesc,
                value: _noProxy,
                onChanged: (value) => setState(() => _noProxy = value),
              ),
              Divider(height: 1, color: cs.outlineVariant),
              _SwitchRow(
                title: t.domainRuleEnabled,
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
              ),
            ],
          ),

          if (!_isNew) ...[
            const SizedBox(height: 24),
            Center(
              child: Button.text(
                onPressed: () => showConfirmDialog(
                  context: context,
                  title: t.delete,
                  content: t.confirmDeleteRule,
                  onConfirm: _delete,
                  btnColor: cs.error,
                ),
                child: Text(t.delete, style: TextStyle(color: cs.error)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 可增删的字符串列表编辑器。
class _TokenEditor extends StatefulWidget {
  const _TokenEditor({
    required this.values,
    required this.placeholder,
    required this.validate,
    required this.invalidMessage,
    required this.onChanged,
    this.trailingAction,
  });

  final List<String> values;
  final String placeholder;
  final bool Function(String value) validate;
  final String invalidMessage;
  final ValueChanged<List<String>> onChanged;

  /// 附加操作（如「自动解析」按钮）
  final Widget? trailingAction;

  @override
  State<_TokenEditor> createState() => _TokenEditorState();
}

class _TokenEditorState extends State<_TokenEditor> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return;
    if (widget.values.contains(value)) {
      _controller.clear();
      return;
    }
    if (!widget.validate(value)) {
      context.showMessage(
        message: widget.invalidMessage,
        level: LogLevel.warning,
      );
      return;
    }
    widget.onChanged([...widget.values, value]);
    _controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.values.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final value in widget.values)
                  _Tag(
                    text: value,
                    onDelete: () =>
                        widget.onChanged(List.of(widget.values)..remove(value)),
                  ),
              ],
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: widget.placeholder,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                onSubmitted: _add,
              ),
            ),
            const SizedBox(width: 8),
            CapsuleButton(text: t.add, onTap: () => _add(_controller.text)),
          ],
        ),
        if (widget.trailingAction != null) ...[
          const SizedBox(height: 8),
          widget.trailingAction!,
        ],
      ],
    );
  }
}

/// 小标签：既用于规则摘要，也用于可删除的 IP 项。
class _Tag extends StatelessWidget {
  const _Tag({required this.text, this.color, this.suffix, this.onDelete});

  final String text;
  final Color? color;

  /// 右侧附加的小字（如测速耗时）
  final String? suffix;

  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = color ?? cs.onSurfaceVariant;
    return Container(
      padding: EdgeInsets.only(left: 8, right: onDelete == null ? 8 : 2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant, width: 0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: TextStyle(fontSize: 12, color: fg)),
          if (suffix != null) ...[
            const SizedBox(width: 6),
            Text(
              suffix!,
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
          if (onDelete != null)
            InkWell(
              onTap: onDelete,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close, size: 14, color: fg),
              ),
            ),
        ],
      ),
    );
  }
}

/// 弹层内的圆角分组卡片。
class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: CustomSwitch(value: value, onChanged: onChanged),
      onTap: () => onChanged(!value),
    );
  }
}

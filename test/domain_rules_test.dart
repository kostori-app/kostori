import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/network/domain_rules.dart';

void main() {
  group('hostMatchesDomain', () {
    test('精确匹配与子域名后缀匹配', () {
      expect(hostMatchesDomain('bgm.example', 'bgm.example'), isTrue);
      expect(hostMatchesDomain('api.bgm.example', 'bgm.example'), isTrue);
      expect(hostMatchesDomain('cdn.bgm.example', 'bgm.example'), isTrue);
      expect(hostMatchesDomain('notbgm.example', 'bgm.example'), isFalse);
      expect(hostMatchesDomain('bgm.example.evil.com', 'bgm.example'), isFalse);
      expect(hostMatchesDomain('api.bgm.example', 'api.bgm.example'), isTrue);
    });

    test('只写主机名时按标签匹配（兼容旧条目与内置的 bgm / bangumi）', () {
      expect(hostMatchesDomain('bgm.example', 'bgm'), isTrue);
      expect(hostMatchesDomain('api.bgm.example', 'bgm'), isTrue);
      expect(hostMatchesDomain('bgm', 'bgm'), isTrue);
      expect(hostMatchesDomain('bangumi.example', 'bgm'), isFalse);
      expect(hostMatchesDomain('bgm.evil.com', 'bgm'), isTrue);
    });

    test('空输入不匹配', () {
      expect(hostMatchesDomain('bgm.example', ''), isFalse);
      expect(hostMatchesDomain('', 'bgm.example'), isFalse);
    });
  });

  group('DomainRule 序列化', () {
    test('hosts 与指定 DNS 的地址同时保留，来回切换不丢', () {
      const rule = DomainRule(
        domain: 'bgm.example',
        dnsMode: DnsRuleMode.hosts,
        ips: ['1.1.1.1'],
        servers: ['8.8.8.8'],
      );
      final restored = DomainRule.fromJson(rule.toJson());
      expect(restored.ips, ['1.1.1.1']);
      expect(restored.servers, ['8.8.8.8']);
    });

    test('dnsMode 决定用哪一份地址，另一份不影响生效', () {
      const asHosts = DomainRule(
        domain: 'bgm.example',
        dnsMode: DnsRuleMode.hosts,
        ips: ['1.1.1.1'],
        servers: ['8.8.8.8'],
      );
      expect(buildHostsOverrides([asHosts]), {
        'bgm.example': ['1.1.1.1'],
      });
      expect(hasDnsServerRules([asHosts]), isFalse);

      final asServers = asHosts.copyWith(dnsMode: DnsRuleMode.servers);
      expect(buildHostsOverrides([asServers]), isEmpty);
      expect(hasDnsServerRules([asServers]), isTrue);
    });

    test('往返保持一致', () {
      const rule = DomainRule(
        domain: 'bgm.example',
        dnsMode: DnsRuleMode.hosts,
        ips: ['1.1.1.1', '2.2.2.2'],
        noProxy: true,
      );
      final restored = DomainRule.fromJson(rule.toJson());
      expect(restored.domain, 'bgm.example');
      expect(restored.dnsMode, DnsRuleMode.hosts);
      expect(restored.ips, ['1.1.1.1', '2.2.2.2']);
      expect(restored.noProxy, isTrue);
      expect(restored.enabled, isTrue);
    });

    test('兼容旧版的单个 ip 字段与 static 标记', () {
      final fromIp = DomainRule.fromJson({
        'domain': 'bgm.example',
        'ip': '1.2.3.4',
        'dns': 'static',
      });
      expect(fromIp.dnsMode, DnsRuleMode.hosts);
      expect(fromIp.ips, ['1.2.3.4']);
    });

    test('未写 noProxy 时默认为直连关闭', () {
      final rule = DomainRule.fromJson({'domain': 'bgm.example'});
      expect(rule.noProxy, isFalse);
    });

    test('空项与重复项会被清理', () {
      const rule = DomainRule(
        domain: 'bgm.example',
        dnsMode: DnsRuleMode.hosts,
        ips: [' 1.1.1.1 ', '1.1.1.1', '', '  '],
      );
      expect(rule.normalizedIps, ['1.1.1.1']);
      expect(rule.toJson()['ips'], ['1.1.1.1']);
    });
  });

  group('DnsRuleMode', () {
    test('支持「不覆写」「hosts 设置」「指定 DNS」三种', () {
      expect(DnsRuleMode.values, [
        DnsRuleMode.none,
        DnsRuleMode.hosts,
        DnsRuleMode.servers,
      ]);
      expect(DnsRuleMode.parse('hosts'), DnsRuleMode.hosts);
      expect(DnsRuleMode.parse('static'), DnsRuleMode.hosts);
      expect(DnsRuleMode.parse('servers'), DnsRuleMode.servers);
      expect(DnsRuleMode.parse('whatever'), DnsRuleMode.none);
      expect(DnsRuleMode.parse(null), DnsRuleMode.none);
    });
  });

  group('matchDomainRule / shouldBypassProxy', () {
    final rules = [
      const DomainRule(domain: 'disabled.tv', noProxy: true, enabled: false),
      const DomainRule(domain: 'first.tv', noProxy: true),
      const DomainRule(
        domain: 'first.tv',
        dnsMode: DnsRuleMode.hosts,
        ips: ['1.1.1.1'],
      ),
      const DomainRule(domain: 'no-proxy.tv'),
    ];

    test('按顺序取第一条命中的规则', () {
      expect(matchDomainRule(rules, 'a.first.tv')?.noProxy, isTrue);
      expect(matchDomainRule(rules, 'first.tv')?.dnsMode, DnsRuleMode.none);
    });

    test('已停用的规则不参与匹配', () {
      expect(matchDomainRule(rules, 'a.disabled.tv'), isNull);
    });

    test('带地址来源的规则不会被纯直连规则遮挡', () {
      const mixed = [
        DomainRule(domain: 'xfdm.pro', noProxy: true),
        DomainRule(
          domain: 'dm1.xfdm.pro',
          dnsMode: DnsRuleMode.servers,
          servers: ['1.1.1.1'],
        ),
      ];
      expect(matchDomainRule(mixed, 'dm1.xfdm.pro')?.dnsMode, DnsRuleMode.none);
      expect(matchDnsRule(mixed, 'dm1.xfdm.pro')?.dnsMode, DnsRuleMode.servers);
      expect(matchDnsRule(mixed, 'other.tv'), isNull);
    });

    test('未命中的域名返回 null', () {
      expect(matchDomainRule(rules, 'other.tv'), isNull);
      expect(shouldBypassProxy(rules, 'other.tv'), isFalse);
    });

    test('直连与地址来源相互独立，不受同域名其它规则影响', () {
      const hostsOnly = [
        // 先命中的是一条 hosts 设置但没开直连的规则
        DomainRule(
          domain: 'mix.tv',
          dnsMode: DnsRuleMode.hosts,
          ips: ['1.1.1.1'],
        ),
        // 后面一条专门开直连
        DomainRule(domain: 'mix.tv', noProxy: true),
      ];
      expect(matchDomainRule(hostsOnly, 'mix.tv')?.dnsMode, DnsRuleMode.hosts);
      expect(shouldBypassProxy(hostsOnly, 'mix.tv'), isTrue);
      expect(shouldBypassProxy(hostsOnly, 'a.mix.tv'), isTrue);
    });

    test('停用的直连规则不生效', () {
      expect(
        shouldBypassProxy([
          const DomainRule(domain: 'off.tv', noProxy: true, enabled: false),
        ], 'off.tv'),
        isFalse,
      );
    });
  });

  group('buildHostsOverrides', () {
    test('收集启用中的 hosts 规则并过滤非法 IP', () {
      final overrides = buildHostsOverrides([
        const DomainRule(
          domain: 'BGM.example',
          dnsMode: DnsRuleMode.hosts,
          ips: ['1.1.1.1', '2.2.2.2'],
        ),
        const DomainRule(
          domain: 'off.tv',
          dnsMode: DnsRuleMode.hosts,
          ips: ['3.3.3.3'],
          enabled: false,
        ),
        const DomainRule(
          domain: 'bad.tv',
          dnsMode: DnsRuleMode.hosts,
          ips: ['not-an-ip'],
        ),
        const DomainRule(domain: 'plain.tv', noProxy: true),
      ]);
      expect(overrides, {
        'bgm.example': ['1.1.1.1', '2.2.2.2'],
      });
    });

    test('没有可用条目时为空表（照常解析）', () {
      expect(buildHostsOverrides(const []), isEmpty);
      expect(
        buildHostsOverrides([
          const DomainRule(domain: 'none.tv', noProxy: true),
        ]),
        isEmpty,
      );
    });
  });

  group('hostsIpsOf', () {
    test('过滤掉非法 IP', () {
      const rule = DomainRule(
        domain: 'bgm.example',
        dnsMode: DnsRuleMode.hosts,
        ips: ['1.1.1.1', 'oops', '::1'],
      );
      expect(hostsIpsOf(rule), ['1.1.1.1', '::1']);
    });
  });

  group('指定 DNS', () {
    test('序列化往返保留服务器列表', () {
      const rule = DomainRule(
        domain: 'xfdm.pro',
        dnsMode: DnsRuleMode.servers,
        servers: ['1.1.1.1', '8.8.8.8:53'],
      );
      final restored = DomainRule.fromJson(rule.toJson());
      expect(restored.dnsMode, DnsRuleMode.servers);
      expect(restored.servers, ['1.1.1.1', '8.8.8.8:53']);
    });

    test('dnsServersOf 过滤非法服务器', () {
      const rule = DomainRule(
        domain: 'xfdm.pro',
        dnsMode: DnsRuleMode.servers,
        servers: ['1.1.1.1', 'dns.google', '[2400:3200::1]:5353'],
      );
      final servers = dnsServersOf(rule);
      expect(servers.map((e) => e.text), ['1.1.1.1', '2400:3200::1:5353']);
    });

    test('有启用中的指定 DNS 规则时才需要动态解析器', () {
      const off = DomainRule(
        domain: 'off.tv',
        enabled: false,
        dnsMode: DnsRuleMode.servers,
        servers: ['1.1.1.1'],
      );
      const on = DomainRule(
        domain: 'xfdm.pro',
        dnsMode: DnsRuleMode.servers,
        servers: ['1.1.1.1'],
      );
      expect(hasDnsServerRules([off]), isFalse);
      expect(hasDnsServerRules([on]), isTrue);

      final plan = buildDnsPlan(on);
      expect(plan.useCustom, isTrue);
      expect(plan.signature, '1.1.1.1');
      expect(buildDnsPlan(null).useCustom, isFalse);
    });
  });
}

part of 'me_page_plugins.dart';

class PluginSignManagerPage extends StatefulWidget {
  const PluginSignManagerPage({super.key});

  @override
  State<PluginSignManagerPage> createState() => _PluginSignManagerPageState();
}

class _PluginSignManagerPageState extends State<PluginSignManagerPage> {
  final Set<String> _busy = {};

  List<MePagePlugin> _signable() {
    final manager = MePagePluginManager();
    return manager
        .all()
        .where(
          (p) =>
              manager.isEnabled(p.key) &&
              p.signinAvailable,
        )
        .toList();
  }

  Future<void> _runOne(MePagePlugin p) async {
    setState(() => _busy.add(p.key));
    await MePagePluginManager().runSignin(p);
    if (mounted) setState(() => _busy.remove(p.key));
  }

  Future<void> _runAll() async {
    await MePagePluginManager().runCollectiveSignin();
    if (mounted) setState(() {});
    final all = _signable();
    final done = all.where((p) => p.signedToday.isNotEmpty).length;
    App.rootContext.showMessage(
      message: done >= all.length
          ? t.signAllSuccess(success: done)
          : t.noPluginToSign,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final manager = MePagePluginManager();
    final plugins = _signable();
    return PopUpWidgetScaffold(
      title: t.signInManager,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Material(
            color: cs.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: cs.outlineVariant, width: 0.6),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          t.signInManager,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 34,
                        child: Button.filled(
                          onPressed: _runAll,
                          child: Text(t.signAll),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          t.autoSignAtStart,
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      CustomSwitch(
                        value: manager.autoSigninMaster,
                        onChanged: (v) {
                          appdata.implicitData['meAutoSignin'] = v;
                          appdata.writeImplicitData();
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (plugins.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  t.noMePagePlugin,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            )
          else
            for (final p in plugins)
              _SignCard(
                plugin: p,
                busy: _busy.contains(p.key),
                onSign: () => _runOne(p),
                onAutoChanged: () {
                  if (mounted) setState(() {});
                },
              ),
        ],
      ),
    );
  }
}

class _SignCard extends StatelessWidget {
  const _SignCard({
    required this.plugin,
    required this.busy,
    required this.onSign,
    required this.onAutoChanged,
  });

  final MePagePlugin plugin;
  final bool busy;
  final VoidCallback onSign;
  final VoidCallback onAutoChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final signed = plugin.signedToday.isNotEmpty;
    final logged = plugin.isLogged;
    final lastSign = plugin.data['lastSign'];
    final lastError = lastSign is Map && lastSign['ok'] != true
        ? (lastSign['message']?.toString() ?? '')
        : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: cs.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cs.outlineVariant, width: 0.6),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.extension_outlined, color: cs.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      plugin.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (signed)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 18, color: cs.primary),
                        const SizedBox(width: 4),
                        Text(
                          t.signedAlready,
                          style: TextStyle(fontSize: 12, color: cs.primary),
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      height: 32,
                      child: Button.filled(
                        isLoading: busy,
                        onPressed: logged ? onSign : () {},
                        child: Text(t.signAll),
                      ),
                    ),
                ],
              ),
              if (!logged)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    t.needLoginFirst,
                    style: TextStyle(fontSize: 12, color: cs.error),
                  ),
                ),
              if (lastError.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    lastError,
                    style: TextStyle(fontSize: 12, color: cs.error),
                  ),
                ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'v${plugin.version}',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  CustomSwitch(
                    value: plugin.isAutoSign,
                    onChanged: (v) {
                      plugin.setAutoSign(v);
                      onAutoChanged();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
Map<String, dynamic> _asMap2(dynamic v) {
  if (v is Map) {
    return v.map((k, val) => MapEntry(k.toString(), val));
  }
  return <String, dynamic>{};
}

Widget _genericPluginImage(
  String url, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
}) {
  return AnimatedImage(
    image: CachedImageProvider(url, sourceKey: 'me_plugin'),
    width: width,
    height: height,
    fit: fit,
  );
}

/// 站点图片 provider：headers/sourceKey 取插件声明，与预览/列表同一缓存 key

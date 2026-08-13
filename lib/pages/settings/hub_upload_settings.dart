part of 'settings_page.dart';

// ── 服务端上传配置（二级页面） ─────────────────────────────────────────────────

class _HubUploadPage extends StatefulWidget {
  final HubService hub;

  const _HubUploadPage({required this.hub});

  @override
  State<_HubUploadPage> createState() => _HubUploadPageState();
}

class _HubUploadPageState extends State<_HubUploadPage> {
  late HubUploadConfig _cfg;
  final _endpointCtrl = TextEditingController();
  final _bucketCtrl = TextEditingController();
  final _keyIdCtrl = TextEditingController();
  final _secretCtrl = TextEditingController();
  final _cdnCtrl = TextEditingController();
  final _maxSizeCtrl = TextEditingController();
  final _localPathCtrl = TextEditingController();
  final _publicBaseUrlCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cfg = widget.hub.uploadConfig;
    _sync();
  }

  void _sync() {
    final o = _cfg.ossConfig;
    _endpointCtrl.text = o?.endpoint ?? '';
    _bucketCtrl.text = o?.bucket ?? '';
    _keyIdCtrl.text = o?.accessKeyId ?? '';
    _secretCtrl.text = o?.accessKeySecret ?? '';
    _cdnCtrl.text = o?.cdnDomain ?? '';
    _maxSizeCtrl.text = (_cfg.maxSizeBytes / (1024 * 1024)).toStringAsFixed(0);
    _localPathCtrl.text = _cfg.localStorePath ?? '';
    _publicBaseUrlCtrl.text = _cfg.publicBaseUrl ?? '';
  }

  @override
  void dispose() {
    _endpointCtrl.dispose();
    _bucketCtrl.dispose();
    _keyIdCtrl.dispose();
    _secretCtrl.dispose();
    _cdnCtrl.dispose();
    _maxSizeCtrl.dispose();
    _localPathCtrl.dispose();
    _publicBaseUrlCtrl.dispose();
    super.dispose();
  }

  void _err(String msg) =>
      App.rootContext.showMessage(message: msg, level: LogLevel.warning);

  /// 自动探测公网 IP（IPv4 优先，失败回退 IPv6），拼上当前端口填入输入框。
  Future<void> _autoDetectPublicIp() async {
    try {
      final port = widget.hub.port;
      String? ip;
      // IPv4 探测
      for (final api in const [
        'https://api.ipify.org',
        'https://ipv4.icanhazip.com',
        'https://v4.ident.me',
      ]) {
        try {
          final r = await AppDio().request(
            api,
            options: Options(
              method: 'GET',
              responseType: ResponseType.plain,
              sendTimeout: const Duration(seconds: 4),
              receiveTimeout: const Duration(seconds: 4),
            ),
          );
          final s = (r.data ?? '').toString().trim();
          if (_looksLikeIp(s, ipv6: false)) {
            ip = s;
            break;
          }
        } catch (_) {}
      }
      // IPv6 探测（IPv4 失败时）
      if (ip == null) {
        for (final api in const [
          'https://api64.ipify.org',
          'https://ipv6.icanhazip.com',
        ]) {
          try {
            final r = await AppDio().request(
              api,
              options: Options(
                method: 'GET',
                responseType: ResponseType.plain,
                sendTimeout: const Duration(seconds: 4),
                receiveTimeout: const Duration(seconds: 4),
              ),
            );
            final s = (r.data ?? '').toString().trim();
            if (_looksLikeIp(s, ipv6: true)) {
              ip = s;
              break;
            }
          } catch (_) {}
        }
      }

      if (ip == null) {
        _err(t.publicIpDetectFailed);
        return;
      }

      final isV6 = ip.contains(':');
      final url = isV6 ? 'http://[$ip]:$port' : 'http://$ip:$port';
      setState(() => _publicBaseUrlCtrl.text = url);
      App.rootContext.showMessage(message: t.publicIpDetected);
    } catch (e) {
      _err(t.publicIpDetectFailed);
    }
  }

  bool _looksLikeIp(String s, {required bool ipv6}) {
    if (ipv6) {
      return RegExp(r'^[0-9a-fA-F:]+$').hasMatch(s) && s.contains(':');
    }
    return RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(s);
  }

  void _save() {
    final needOss = _cfg.mode == HubUploadMode.serverOss;
    if (needOss) {
      final ep = _endpointCtrl.text.trim();
      final uri = Uri.tryParse(ep);
      if (ep.isEmpty ||
          uri == null ||
          !uri.hasScheme ||
          uri.host.isEmpty ||
          (uri.scheme != 'http' && uri.scheme != 'https')) {
        _err(t.endpointMustBeAValidUrl);
        return;
      }
      if (_bucketCtrl.text.trim().isEmpty) {
        _err(t.bucketCannotBeEmpty);
        return;
      }
      if (_keyIdCtrl.text.trim().isEmpty) {
        _err(t.accessKeyIdCannotBeEmpty);
        return;
      }
      if (_secretCtrl.text.trim().isEmpty) {
        _err(t.accessKeySecretCannotBeEmpty);
        return;
      }
      final cdn = _cdnCtrl.text.trim();
      if (cdn.isNotEmpty) {
        final cu = Uri.tryParse(cdn);
        if (cu == null || !cu.hasScheme || cu.host.isEmpty) {
          _err(t.cdnDomainMustBeAValidUrl);
          return;
        }
      }
    }

    final maxMb = int.tryParse(_maxSizeCtrl.text.trim());
    if (maxMb == null || maxMb < 1 || maxMb > 100) {
      _err(t.maxSizeMustBe1to100Mb);
      return;
    }

    OssConfig? oss;
    if (needOss) {
      final cdn = _cdnCtrl.text.trim();
      oss = OssConfig(
        endpoint: _endpointCtrl.text.trim(),
        bucket: _bucketCtrl.text.trim(),
        accessKeyId: _keyIdCtrl.text.trim(),
        accessKeySecret: _secretCtrl.text.trim(),
        cdnDomain: cdn.isEmpty ? null : cdn,
      );
    }

    final lp = _localPathCtrl.text.trim();
    final pb = _publicBaseUrlCtrl.text.trim();
    final newCfg = _cfg.copyWith(
      ossConfig: oss,
      clearOssConfig: oss == null,
      maxSizeBytes: maxMb * 1024 * 1024,
      localStorePath: lp.isEmpty ? null : lp,
      clearLocalStorePath: lp.isEmpty,
      publicBaseUrl: pb.isEmpty ? null : pb,
      clearPublicBaseUrl: pb.isEmpty,
    );

    widget.hub.uploadConfig = newCfg;
    setState(() => _cfg = newCfg);
    App.rootContext.showMessage(message: t.saved);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final needOss = _cfg.mode == HubUploadMode.serverOss;
    final locked = widget.hub.isRunning;

    return PopUpWidgetScaffold(
      title: t.imageUpload,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: cs.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: cs.outlineVariant, width: 0.6),
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 运行中锁定提示 ──────────────────────────────────────
                    if (locked)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 13,
                              color: cs.onSurface.toOpacity(0.4),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              t.stopTheServerToChangeUploadMode,
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurface.toOpacity(0.4),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ── 模式选择（运行中不可操作）──────────────────────────
                    Opacity(
                      opacity: locked ? 0.45 : 1.0,
                      child: IgnorePointer(
                        ignoring: locked,
                        child: SegmentedButton<HubUploadMode>(
                          segments: [
                            ButtonSegment(
                              value: HubUploadMode.serverLocal,
                              label: Text(t.local),
                              icon: const Icon(
                                Icons.storage_outlined,
                                size: 15,
                              ),
                            ),
                            ButtonSegment(
                              value: HubUploadMode.serverOss,
                              label: Text(t.serverOss),
                              icon: const Icon(Icons.cloud_outlined, size: 15),
                            ),
                            ButtonSegment(
                              value: HubUploadMode.clientOss,
                              label: Text(t.clientOss),
                              icon: const Icon(Icons.upload_outlined, size: 15),
                            ),
                          ],
                          selected: {_cfg.mode},
                          onSelectionChanged: (s) => setState(
                            () => _cfg = _cfg.copyWith(mode: s.first),
                          ),
                          style: ButtonStyle(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                    ),

                    // ── 模式说明 ────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        switch (_cfg.mode) {
                          HubUploadMode.serverLocal =>
                            t.imagesStoredOnServerDisk,
                          HubUploadMode.serverOss =>
                            t.serverReceivesAndProxiesImageToOss,
                          HubUploadMode.clientOss =>
                            t.clientUploadsDirectlyToOss,
                        },
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.toOpacity(0.45),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_cfg.mode != HubUploadMode.clientOss)
              _FormCard(
                children: [
                  _FormSectionTitle(
                    title: t.maxSizeMb,
                    icon: Icons.data_usage_outlined,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _maxSizeCtrl,
                    decoration: _formFieldDecoration(
                      labelText: t.maxSizeMb,
                      hintText: t.defaultValue(v: '5'),
                    ),
                  ),
                ],
              ),
            if (_cfg.mode == HubUploadMode.serverLocal)
              _FormCard(
                children: [
                  _FormSectionTitle(
                    title: t.storePath,
                    icon: Icons.folder_outlined,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _localPathCtrl,
                    decoration: _formFieldDecoration(
                      labelText: t.storePath,
                      hintText: '/data/hub_uploads',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FormSectionTitle(
                    title: t.publicBaseUrl,
                    icon: Icons.public_outlined,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.publicBaseUrlHint,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _publicBaseUrlCtrl,
                          decoration: _formFieldDecoration(
                            labelText: t.publicBaseUrl,
                            hintText: 'http://[2001:db8::1]:9100',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.auto_fix_high_outlined,
                          size: 18,
                        ),
                        tooltip: t.publicIpDetected,
                        onPressed: _autoDetectPublicIp,
                      ),
                    ],
                  ),
                ],
              ),
            if (needOss) ...[
              const SizedBox(height: 16),
              _FormCard(
                children: [
                  _FormSectionTitle(
                    title: 'OSS / S3',
                    icon: Icons.cloud_outlined,
                  ),
                  const SizedBox(height: 12),
                  _HubOssField(
                    label: 'Endpoint',
                    hint: 'https://oss-cn-hangzhou.aliyuncs.com',
                    ctrl: _endpointCtrl,
                  ),
                  _HubOssField(
                    label: 'Bucket',
                    hint: 'my-bucket',
                    ctrl: _bucketCtrl,
                  ),
                  _HubOssField(
                    label: 'Key ID',
                    hint: 'Access Key ID',
                    ctrl: _keyIdCtrl,
                  ),
                  _HubOssField(
                    label: 'Secret',
                    hint: 'Access Key Secret',
                    ctrl: _secretCtrl,
                    obscure: true,
                  ),
                  _HubOssField(
                    label: 'CDN',
                    hint: 'https://cdn.example.com  (optional)',
                    ctrl: _cdnCtrl,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: Button.filled(onPressed: _save, child: Text(t.save)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 客户端 OSS 配置 ────────────────────────────────────────────────────────────

class _ClientUploadConfigSetting extends StatefulWidget {
  final HubClient client;

  const _ClientUploadConfigSetting({required this.client});

  @override
  State<_ClientUploadConfigSetting> createState() =>
      _ClientUploadConfigSettingState();
}

class _ClientUploadConfigSettingState
    extends State<_ClientUploadConfigSetting> {
  static const _cfgKey = 'hub_client_upload_config';
  static const _enabledKey = 'hub_client_oss_enabled';

  late HubUploadConfig _cfg;
  late bool _enabled;

  final _endpointCtrl = TextEditingController();
  final _bucketCtrl = TextEditingController();
  final _keyIdCtrl = TextEditingController();
  final _secretCtrl = TextEditingController();
  final _cdnCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final raw = appdata.implicitData[_cfgKey];
    _cfg = (raw is Map)
        ? HubUploadConfig.fromJson(Map<String, dynamic>.from(raw))
        : const HubUploadConfig(mode: HubUploadMode.clientOss);
    _enabled = appdata.implicitData[_enabledKey] as bool? ?? false;
    _sync();
  }

  void _sync() {
    final o = _cfg.ossConfig;
    _endpointCtrl.text = o?.endpoint ?? '';
    _bucketCtrl.text = o?.bucket ?? '';
    _keyIdCtrl.text = o?.accessKeyId ?? '';
    _secretCtrl.text = o?.accessKeySecret ?? '';
    _cdnCtrl.text = o?.cdnDomain ?? '';
  }

  @override
  void dispose() {
    _endpointCtrl.dispose();
    _bucketCtrl.dispose();
    _keyIdCtrl.dispose();
    _secretCtrl.dispose();
    _cdnCtrl.dispose();
    super.dispose();
  }

  void _err(String msg) =>
      App.rootContext.showMessage(message: msg, level: LogLevel.warning);

  void _setEnabled(bool v) {
    appdata.implicitData[_enabledKey] = v;
    appdata.writeImplicitData();
    setState(() => _enabled = v);
  }

  void _save() {
    final allEmpty =
        _endpointCtrl.text.trim().isEmpty &&
        _bucketCtrl.text.trim().isEmpty &&
        _keyIdCtrl.text.trim().isEmpty &&
        _secretCtrl.text.trim().isEmpty;
    if (allEmpty) {
      _clear();
      return;
    }

    final ep = _endpointCtrl.text.trim();
    final uri = Uri.tryParse(ep);
    if (uri == null ||
        !uri.hasScheme ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      _err(t.endpointMustBeAValidUrl);
      return;
    }
    if (_bucketCtrl.text.trim().isEmpty) {
      _err(t.bucketCannotBeEmpty);
      return;
    }
    if (_keyIdCtrl.text.trim().isEmpty) {
      _err(t.accessKeyIdCannotBeEmpty);
      return;
    }
    if (_secretCtrl.text.trim().isEmpty) {
      _err(t.accessKeySecretCannotBeEmpty);
      return;
    }
    final cdn = _cdnCtrl.text.trim();
    if (cdn.isNotEmpty) {
      final cu = Uri.tryParse(cdn);
      if (cu == null || !cu.hasScheme || cu.host.isEmpty) {
        _err(t.cdnDomainMustBeAValidUrl);
        return;
      }
    }

    final oss = OssConfig(
      endpoint: ep,
      bucket: _bucketCtrl.text.trim(),
      accessKeyId: _keyIdCtrl.text.trim(),
      accessKeySecret: _secretCtrl.text.trim(),
      cdnDomain: cdn.isEmpty ? null : cdn,
    );
    final newCfg = HubUploadConfig(
      mode: HubUploadMode.clientOss,
      ossConfig: oss,
    );
    appdata.implicitData[_cfgKey] = newCfg.toJson();
    appdata.writeImplicitData();
    setState(() => _cfg = newCfg);
    App.rootContext.showMessage(message: t.saved);
  }

  void _clear() {
    final cleared = const HubUploadConfig();
    appdata.implicitData[_cfgKey] = cleared.toJson();
    appdata.writeImplicitData();
    setState(() {
      _cfg = cleared;
      _endpointCtrl.clear();
      _bucketCtrl.clear();
      _keyIdCtrl.clear();
      _secretCtrl.clear();
      _cdnCtrl.clear();
    });
    App.rootContext.showMessage(message: t.cleared);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasOss = _cfg.ossConfig?.isValid ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingPartTitle(
          title: t.clientImageUpload,
          icon: Icons.cloud_upload_outlined,
        ),

        // ── 总开关 ────────────────────────────────────────────────────────
        _SettingRow(
          title: t.enableClientOss,
          subtitle: t.uploadImagesDirectlyFromClientToOss,
          trailing: CustomSwitch(value: _enabled, onChanged: _setEnabled),
        ),

        // ── 开关打开后展开配置 ─────────────────────────────────────────────
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _enabled
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Row(
                  children: [
                    Icon(
                      hasOss ? Icons.check_circle_outline : Icons.info_outline,
                      size: 14,
                      color: hasOss
                          ? Colors.green
                          : cs.onSurface.toOpacity(0.4),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        hasOss ? _cfg.ossConfig!.host : t.ossNotConfigured,
                        style: TextStyle(
                          fontSize: 12,
                          color: hasOss
                              ? Colors.green
                              : cs.onSurface.toOpacity(0.4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              _HubOssForm(
                endpointCtrl: _endpointCtrl,
                bucketCtrl: _bucketCtrl,
                keyIdCtrl: _keyIdCtrl,
                secretCtrl: _secretCtrl,
                cdnCtrl: _cdnCtrl,
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    FilledButton.tonal(onPressed: _save, child: Text(t.save)),
                    if (hasOss) ...[
                      const SizedBox(width: 10),
                      TextButton(
                        onPressed: _clear,
                        child: Text(t.clear, style: TextStyle(color: cs.error)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          secondChild: const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ── 共用 OSS 表单 ─────────────────────────────────────────────────────────────

class _HubOssForm extends StatelessWidget {
  final TextEditingController endpointCtrl;
  final TextEditingController bucketCtrl;
  final TextEditingController keyIdCtrl;
  final TextEditingController secretCtrl;
  final TextEditingController cdnCtrl;

  const _HubOssForm({
    required this.endpointCtrl,
    required this.bucketCtrl,
    required this.keyIdCtrl,
    required this.secretCtrl,
    required this.cdnCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Text(
            'OSS / S3',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: cs.onSurface.toOpacity(0.4),
            ),
          ),
        ),
        _HubOssField(
          label: 'Endpoint',
          hint: 'https://oss-cn-hangzhou.aliyuncs.com',
          ctrl: endpointCtrl,
        ),
        _HubOssField(label: 'Bucket', hint: 'my-bucket', ctrl: bucketCtrl),
        _HubOssField(label: 'Key ID', hint: 'Access Key ID', ctrl: keyIdCtrl),
        _HubOssField(
          label: 'Secret',
          hint: 'Access Key Secret',
          ctrl: secretCtrl,
          obscure: true,
        ),
        _HubOssField(
          label: 'CDN',
          hint: 'https://cdn.example.com  (optional)',
          ctrl: cdnCtrl,
        ),
      ],
    );
  }
}

// ── OSS 单字段 ────────────────────────────────────────────────────────────────

class _HubOssField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController ctrl;
  final bool obscure;

  const _HubOssField({
    required this.label,
    required this.hint,
    required this.ctrl,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 3, 16, 3),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.toOpacity(0.55),
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: ctrl,
              obscureText: obscure,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                hintText: hint,
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.toOpacity(0.25),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                filled: true,
                fillColor: cs.surfaceContainerHighest.toOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: cs.primary, width: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

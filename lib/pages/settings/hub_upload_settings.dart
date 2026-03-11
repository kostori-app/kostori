part of 'settings_page.dart';

// ── 服务端上传配置 ─────────────────────────────────────────────────────────────

class _UploadConfigSetting extends StatefulWidget {
  final HubService hub;
  final bool serverRunning;
  const _UploadConfigSetting({required this.hub, required this.serverRunning});

  @override
  State<_UploadConfigSetting> createState() => _UploadConfigSettingState();
}

class _UploadConfigSettingState extends State<_UploadConfigSetting> {
  late HubUploadConfig _cfg;
  final _endpointCtrl = TextEditingController();
  final _bucketCtrl = TextEditingController();
  final _keyIdCtrl = TextEditingController();
  final _secretCtrl = TextEditingController();
  final _cdnCtrl = TextEditingController();
  final _maxSizeCtrl = TextEditingController();
  final _localPathCtrl = TextEditingController();

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
    super.dispose();
  }

  void _err(String msg) =>
      App.rootContext.showMessage(message: msg, level: LogLevel.warning);

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
        _err('Endpoint must be a valid http(s) URL'.tl);
        return;
      }
      if (_bucketCtrl.text.trim().isEmpty) {
        _err('Bucket cannot be empty'.tl);
        return;
      }
      if (_keyIdCtrl.text.trim().isEmpty) {
        _err('Access Key ID cannot be empty'.tl);
        return;
      }
      if (_secretCtrl.text.trim().isEmpty) {
        _err('Access Key Secret cannot be empty'.tl);
        return;
      }
      final cdn = _cdnCtrl.text.trim();
      if (cdn.isNotEmpty) {
        final cu = Uri.tryParse(cdn);
        if (cu == null || !cu.hasScheme || cu.host.isEmpty) {
          _err('CDN Domain must be a valid URL'.tl);
          return;
        }
      }
    }

    final maxMb = int.tryParse(_maxSizeCtrl.text.trim());
    if (maxMb == null || maxMb < 1 || maxMb > 100) {
      _err('Max size must be 1–100 MB'.tl);
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
    final newCfg = _cfg.copyWith(
      ossConfig: oss,
      clearOssConfig: oss == null,
      maxSizeBytes: maxMb * 1024 * 1024,
      localStorePath: lp.isEmpty ? null : lp,
      clearLocalStorePath: lp.isEmpty,
    );

    widget.hub.uploadConfig = newCfg;
    setState(() => _cfg = newCfg);
    App.rootContext.showMessage(message: 'Saved'.tl);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final needOss = _cfg.mode == HubUploadMode.serverOss;
    final locked = widget.serverRunning;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingPartTitle(
          title: 'Image Upload'.tl,
          icon: Icons.cloud_upload_outlined,
        ),

        // ── 运行中锁定提示 ────────────────────────────────────────────────
        if (locked)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Row(
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 13,
                  color: cs.onSurface.toOpacity(0.4),
                ),
                const SizedBox(width: 5),
                Text(
                  'Stop the server to change upload mode'.tl,
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.toOpacity(0.4),
                  ),
                ),
              ],
            ),
          ),

        // ── 模式选择（运行中不可操作）────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Opacity(
            opacity: locked ? 0.45 : 1.0,
            child: IgnorePointer(
              ignoring: locked,
              child: SegmentedButton<HubUploadMode>(
                segments: [
                  ButtonSegment(
                    value: HubUploadMode.serverLocal,
                    label: Text('Local'.tl),
                    icon: const Icon(Icons.storage_outlined, size: 15),
                  ),
                  ButtonSegment(
                    value: HubUploadMode.serverOss,
                    label: Text('Server OSS'.tl),
                    icon: const Icon(Icons.cloud_outlined, size: 15),
                  ),
                  ButtonSegment(
                    value: HubUploadMode.clientOss,
                    label: Text('Client OSS'.tl),
                    icon: const Icon(Icons.upload_outlined, size: 15),
                  ),
                ],
                selected: {_cfg.mode},
                onSelectionChanged: (s) =>
                    setState(() => _cfg = _cfg.copyWith(mode: s.first)),
                style: ButtonStyle(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ),
        ),

        // ── 模式说明 ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: Text(
            switch (_cfg.mode) {
              HubUploadMode.serverLocal =>
                'Images stored on server disk, served via /hub/files/'.tl,
              HubUploadMode.serverOss =>
                'Server receives and proxies image to OSS. Keys stay on server.'
                    .tl,
              HubUploadMode.clientOss =>
                'Client uploads directly to OSS. Server only gets the final URL.'
                    .tl,
            },
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurface.toOpacity(0.45),
              height: 1.5,
            ),
          ),
        ),

        if (_cfg.mode != HubUploadMode.clientOss)
          _SettingRow(
            title: 'Max Size (MB)'.tl,
            subtitle: 'Default: @p'.tlParams({'p': '5'}),
            trailing: _NumberInput(
              controller: _maxSizeCtrl,
              enabled: true,
              onChanged: (_) {},
            ),
          ),

        if (_cfg.mode == HubUploadMode.serverLocal)
          _SettingRow(
            title: 'Store Path'.tl,
            subtitle: 'Leave empty for default'.tl,
            trailing: _HubTextField(
              controller: _localPathCtrl,
              hint: '/data/hub_uploads',
              width: 200,
            ),
          ),

        if (needOss) ...[
          const SizedBox(height: 4),
          _HubOssForm(
            endpointCtrl: _endpointCtrl,
            bucketCtrl: _bucketCtrl,
            keyIdCtrl: _keyIdCtrl,
            secretCtrl: _secretCtrl,
            cdnCtrl: _cdnCtrl,
          ),
        ],

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: FilledButton.tonal(onPressed: _save, child: Text('Save'.tl)),
        ),
      ],
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
      _err('Endpoint must be a valid http(s) URL'.tl);
      return;
    }
    if (_bucketCtrl.text.trim().isEmpty) {
      _err('Bucket cannot be empty'.tl);
      return;
    }
    if (_keyIdCtrl.text.trim().isEmpty) {
      _err('Access Key ID cannot be empty'.tl);
      return;
    }
    if (_secretCtrl.text.trim().isEmpty) {
      _err('Access Key Secret cannot be empty'.tl);
      return;
    }
    final cdn = _cdnCtrl.text.trim();
    if (cdn.isNotEmpty) {
      final cu = Uri.tryParse(cdn);
      if (cu == null || !cu.hasScheme || cu.host.isEmpty) {
        _err('CDN Domain must be a valid URL'.tl);
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
    App.rootContext.showMessage(message: 'Saved'.tl);
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
    App.rootContext.showMessage(message: 'Cleared'.tl);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasOss = _cfg.ossConfig?.isValid ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingPartTitle(
          title: 'Client Image Upload'.tl,
          icon: Icons.cloud_upload_outlined,
        ),

        // ── 总开关 ────────────────────────────────────────────────────────
        _SettingRow(
          title: 'Enable Client OSS'.tl,
          subtitle: 'Upload images directly from client to OSS'.tl,
          trailing: Switch(value: _enabled, onChanged: _setEnabled),
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
              // 状态
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
                        hasOss ? _cfg.ossConfig!.host : 'OSS not configured'.tl,
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
                    FilledButton.tonal(
                      onPressed: _save,
                      child: Text('Save'.tl),
                    ),
                    if (hasOss) ...[
                      const SizedBox(width: 10),
                      TextButton(
                        onPressed: _clear,
                        child: Text(
                          'Clear'.tl,
                          style: TextStyle(color: cs.error),
                        ),
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

// ── 通用内联文本框 ─────────────────────────────────────────────────────────────

class _HubTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final double width;

  const _HubTextField({
    required this.controller,
    required this.hint,
    this.width = 180,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: 12,
            color: cs.onSurface.toOpacity(0.3),
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
    );
  }
}

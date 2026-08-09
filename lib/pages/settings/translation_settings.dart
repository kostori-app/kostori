part of 'settings_page.dart';

// ─────────────────────────────────────────────
// DeepL 配置页（在翻译选择弹窗中点击 DeepL 时进入）
// ─────────────────────────────────────────────

class DeepLConfigPage extends StatefulWidget {
  const DeepLConfigPage({super.key});

  @override
  State<DeepLConfigPage> createState() => _DeepLConfigPageState();
}

class _DeepLConfigPageState extends State<DeepLConfigPage> {
  final _apiKeyCtrl = TextEditingController();
  bool _obscure = true;
  String _usage = '';

  @override
  void initState() {
    super.initState();
    _apiKeyCtrl.text = appdata.settings.s.deeplKey;
    _fetchUsage(_apiKeyCtrl.text);
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchUsage(String? apiKey) async {
    if (apiKey == null || apiKey.isEmpty) return;
    try {
      final response = await AppDio().request(
        'https://api-free.deepl.com/v2/usage',
        options: Options(
          method: 'POST',
          headers: {'Authorization': 'DeepL-Auth-Key $apiKey'},
          receiveTimeout: const Duration(seconds: 20),
        ),
      );
      final json = response.data;
      if (mounted) {
        setState(() {
          _usage = '${json['character_count']} / ${json['character_limit']}';
        });
      }
    } catch (_) {}
  }

  void _save() {
    final key = _apiKeyCtrl.text.trim();
    if (key.isEmpty) {
      App.rootContext.showMessage(message: t.apiKeyCannotBeEmpty);
      return;
    }
    appdata.settings.update((s) => s.copyWith(deeplKey: key));
    appdata.saveData();
    App.rootContext.showMessage(message: t.saved);
    App.rootContext.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopUpWidgetScaffold(
      title: 'DeepL',
      body: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.5,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                child: SingleChildScrollView(
                  child: _SettingCard(
                    children: [
                      _SettingPartTitle(
                        title: t.apiConfiguration,
                        icon: Icons.key_outlined,
                      ),
                      // API Key
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextFormField(
                          controller: _apiKeyCtrl,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: 'API Key',
                            prefixIcon: const Icon(Icons.key, size: 20),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                          onChanged: (v) => _fetchUsage(v),
                        ),
                      ),
                      // 用量显示
                      if (_usage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Row(
                            children: [
                              const Icon(Icons.data_usage, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                '${t.usage} $_usage',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.colorScheme.outline,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.extended(
                onPressed: _save,
                label: Text(t.apply),
                icon: const Icon(Icons.check),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

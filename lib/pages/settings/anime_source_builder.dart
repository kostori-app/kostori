part of 'settings_page.dart';

/// 积木式番剧源构建器：用表单配置各功能块，生成 JS 源脚本并导入。
/// 覆盖基础播放链路：基础信息 + 搜索 + 番剧详情 + 播放。
class AnimeSourceBuilderPage extends StatefulWidget {
  const AnimeSourceBuilderPage({super.key});

  @override
  State<AnimeSourceBuilderPage> createState() => _AnimeSourceBuilderPageState();
}

class _AnimeSourceBuilderPageState extends State<AnimeSourceBuilderPage> {
  // 基础信息
  final _nameCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  final _versionCtrl = TextEditingController(text: '1.0.0');
  final _baseUrlCtrl = TextEditingController();

  // 搜索
  final _searchUrlCtrl = TextEditingController();
  final _searchListSelCtrl = TextEditingController();
  final _searchTitleSelCtrl = TextEditingController();
  final _searchCoverSelCtrl = TextEditingController();
  final _searchLinkSelCtrl = TextEditingController();
  final _searchPageParamCtrl = TextEditingController(text: 'page');
  final _searchMaxPageSelCtrl = TextEditingController();

  // 封面属性（搜索与详情共用），默认 src；部分站点封面在 data-bg 等属性
  final _coverAttrCtrl = TextEditingController(text: 'src');

  // 请求头（可选），User-Agent 部分站点必需
  final _userAgentCtrl = TextEditingController();

  // 播放方式：false = 正则提取，true = 直接返回剧集链接
  bool _playDirect = false;

  // explore（首页分页列表）
  final _exploreTitleCtrl = TextEditingController();
  final _exploreUrlCtrl = TextEditingController();

  // 分类
  final _categoryTitleCtrl = TextEditingController();
  // 分类名列表，一行一个，格式 "值-名称" 或仅 "名称"（值与名称相同）
  final _categoryNamesCtrl = TextEditingController();
  final _categoryUrlCtrl = TextEditingController();

  // 详情
  final _detailUrlCtrl = TextEditingController();
  final _detailTitleSelCtrl = TextEditingController();
  final _detailCoverSelCtrl = TextEditingController();
  final _detailDescSelCtrl = TextEditingController();
  final _detailEpSelCtrl = TextEditingController();
  final _detailEpTitleSelCtrl = TextEditingController();
  final _detailEpLinkSelCtrl = TextEditingController();

  // 播放
  final _playUrlCtrl = TextEditingController();
  final _playExtractCtrl = TextEditingController();

  bool _generating = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _keyCtrl.dispose();
    _versionCtrl.dispose();
    _baseUrlCtrl.dispose();
    _searchUrlCtrl.dispose();
    _searchListSelCtrl.dispose();
    _searchTitleSelCtrl.dispose();
    _searchCoverSelCtrl.dispose();
    _searchLinkSelCtrl.dispose();
    _searchPageParamCtrl.dispose();
    _searchMaxPageSelCtrl.dispose();
    _coverAttrCtrl.dispose();
    _userAgentCtrl.dispose();
    _exploreTitleCtrl.dispose();
    _exploreUrlCtrl.dispose();
    _categoryTitleCtrl.dispose();
    _categoryNamesCtrl.dispose();
    _categoryUrlCtrl.dispose();
    _detailUrlCtrl.dispose();
    _detailTitleSelCtrl.dispose();
    _detailCoverSelCtrl.dispose();
    _detailDescSelCtrl.dispose();
    _detailEpSelCtrl.dispose();
    _detailEpTitleSelCtrl.dispose();
    _detailEpLinkSelCtrl.dispose();
    _playUrlCtrl.dispose();
    _playExtractCtrl.dispose();
    super.dispose();
  }

  void _err(String msg) =>
      App.rootContext.showMessage(message: msg, level: LogLevel.warning);

  String _jsStr(String s) => s.replaceAll(r'\', r'\\').replaceAll('"', r'\"');

  /// 把用户填的 URL 模板（含 {keyword}/{page}/{id}/{ep} 占位符）转成
  /// JS 反引号模板字面量，占位符转成 ${keyword} 等 JS 插值。
  /// 若模板是相对路径（以 / 开头）则自动拼 ${baseUrl}。
  // ignore: unnecessary_brace_in_string_interps
  String _jsUrlTemplate(String template) {
    var t = template
        .replaceAll('{keyword}', r'${keyword}')
        .replaceAll('{page}', r'${page}')
        .replaceAll('{id}', r'${id}')
        .replaceAll('{ep}', r'${ep}')
        .replaceAll('{category}', r'${category}')
        .replaceAll('{param}', r'${param}')
        .replaceAll('`', r'\`');
    if (t.startsWith('/')) {
      t = r'${baseUrl}' + t;
    }
    return '`$t`';
  }

  /// 搜索翻页：生成 maxPage 提取逻辑。
  /// 有总页数选择器时返回提取代码；否则返回 null（单页）。
  String? _searchMaxPageJs(String selector) {
    if (selector.trim().isEmpty) return null;
    return 'const mp = doc.querySelector("${_jsStr(selector.trim())}");'
        'const maxPage = mp ? parseInt(mp.text) || null : null;';
  }

  /// 生成「从 HTML 列表提取 Anime」的公共代码段。
  /// 复用搜索选择器（列表项/标题/封面/链接 + 封面属性）。
  String _listParseJs({String indent = '    '}) {
    final sb = StringBuffer();
    sb.writeln(
      '${indent}const items = doc.querySelectorAll("${_jsStr(_searchListSelCtrl.text.trim())}")',
    );
    sb.writeln('${indent}const animes = []');
    sb.writeln('${indent}for (const item of items) {');
    sb.writeln(
      '$indent  const a = item.querySelector("${_jsStr(_searchLinkSelCtrl.text.trim())}")',
    );
    sb.writeln('$indent  if (!a) continue');
    sb.writeln(
      '$indent  const title = item.querySelector("${_jsStr(_searchTitleSelCtrl.text.trim())}")?.text ?? a.text',
    );
    sb.writeln(
      '$indent  const cover = item.querySelector("${_jsStr(_searchCoverSelCtrl.text.trim())}")?.attributes["${_jsStr(_coverAttr)}"] ?? ""',
    );
    sb.writeln('$indent  const href = a.attributes.href ?? ""');
    sb.writeln(
      '$indent  const id = href.split("/").filter(s => s).pop() || href',
    );
    sb.writeln('$indent  animes.push(new Anime({ id, title, cover }))');
    sb.writeln('$indent}');
    return sb.toString();
  }

  /// 封面属性名（默认 src，可为 data-bg 等）
  String get _coverAttr {
    final a = _coverAttrCtrl.text.trim();
    return a.isEmpty ? 'src' : a;
  }

  /// 生成请求头对象（含 User-Agent / Referer）
  String _headersJs({bool referer = false}) {
    final ua = _userAgentCtrl.text.trim();
    final parts = <String>[];
    if (ua.isNotEmpty) parts.add('"User-Agent": "${_jsStr(ua)}"');
    if (referer) parts.add('"Referer": baseUrl || ""');
    if (parts.isEmpty) return '{}';
    return '{ ${parts.join(', ')} }';
  }

  /// 生成 JS 源脚本
  String buildJs() {
    final sb = StringBuffer();
    sb.write(_buildHeaderJs());
    final search = _buildSearchJs();
    if (search.isNotEmpty) sb.write(search);
    final explore = _buildExploreJs();
    if (explore.isNotEmpty) sb.write(explore);
    final category = _buildCategoryJs();
    if (category.isNotEmpty) sb.write(category);
    final detail = _buildDetailJs();
    if (detail.isNotEmpty) sb.write(detail);
    sb.writeln('}');
    return sb.toString();
  }

  String _className() {
    final key = _keyCtrl.text.trim();
    if (key.isNotEmpty) {
      final safe = key.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
      return '${safe[0].toUpperCase()}${safe.substring(1)}Source';
    }
    return 'GeneratedSource';
  }

  /// 基础信息积木的代码
  String _buildHeaderJs() {
    final name = _nameCtrl.text.trim();
    final key = _keyCtrl.text.trim();
    final version = _versionCtrl.text.trim().isEmpty
        ? '1.0.0'
        : _versionCtrl.text.trim();
    final baseUrl = _baseUrlCtrl.text.trim();
    final sb = StringBuffer();
    sb.writeln('class ${_className()} extends AnimeSource {');
    sb.writeln('  name = "${_jsStr(name)}"');
    sb.writeln('  key = "${_jsStr(key)}"');
    sb.writeln('  version = "${_jsStr(version)}"');
    if (baseUrl.isNotEmpty) {
      sb.writeln('  baseUrl = "${_jsStr(baseUrl)}"');
    }
    return sb.toString();
  }

  /// 搜索积木的代码
  String _buildSearchJs() {
    if (_searchUrlCtrl.text.trim().isEmpty) return '';
    final sb = StringBuffer();
    sb.writeln('');
    sb.writeln('  async search(keyword, page) {');
    sb.writeln(
      '    const res = await Network.get(`${_jsUrlTemplate(_searchUrlCtrl.text.trim())}`, ${_headersJs()})',
    );
    sb.writeln(
      '    const doc = new HtmlDocument(Convert.decodeUtf8(res.body))',
    );
    sb.write(_listParseJs());
    final maxPageJs = _searchMaxPageJs(_searchMaxPageSelCtrl.text.trim());
    if (maxPageJs != null) {
      sb.writeln('    $maxPageJs');
      sb.writeln('    return { animes, maxPage }');
    } else {
      sb.writeln('    return { animes, maxPage: null }');
    }
    sb.writeln('  }');
    return sb.toString();
  }

  /// explore（首页分页列表）积木的代码
  String _buildExploreJs() {
    if (_exploreUrlCtrl.text.trim().isEmpty) return '';
    final title = _exploreTitleCtrl.text.trim().isEmpty
        ? '首页'
        : _exploreTitleCtrl.text.trim();
    final sb = StringBuffer();
    sb.writeln('');
    sb.writeln('  explore = [');
    sb.writeln('    {');
    sb.writeln('      title: "${_jsStr(title)}",');
    sb.writeln('      type: "multiPageAnimeList",');
    sb.writeln('      async load(page) {');
    sb.writeln(
      '        const res = await Network.get(`${_jsUrlTemplate(_exploreUrlCtrl.text.trim())}`, ${_headersJs()})',
    );
    sb.writeln(
      '        const doc = new HtmlDocument(Convert.decodeUtf8(res.body))',
    );
    sb.write(_listParseJs(indent: '        '));
    final maxPageJs = _searchMaxPageJs(_searchMaxPageSelCtrl.text.trim());
    if (maxPageJs != null) {
      sb.writeln('        $maxPageJs');
      sb.writeln('        return { animes, maxPage }');
    } else {
      sb.writeln('        return { animes, maxPage: null }');
    }
    sb.writeln('      },');
    sb.writeln('    },');
    sb.writeln('  ]');
    return sb.toString();
  }

  /// 分类积木的代码（category + categoryAnimes）
  String _buildCategoryJs() {
    if (_categoryNamesCtrl.text.trim().isEmpty &&
        _categoryUrlCtrl.text.trim().isEmpty) {
      return '';
    }
    final title = _categoryTitleCtrl.text.trim().isEmpty
        ? '分类'
        : _categoryTitleCtrl.text.trim();
    final sb = StringBuffer();

    // category（导航）
    final categories = _parseCategoryNames();
    if (categories.isNotEmpty) {
      sb.writeln('');
      sb.writeln('  category = {');
      sb.writeln('    title: "${_jsStr(title)}",');
      sb.writeln('    parts: [');
      sb.writeln('      {');
      sb.writeln('        name: "全部",');
      sb.writeln('        type: "fixed",');
      sb.writeln('        categories: [');
      for (final c in categories) {
        sb.writeln(
          '          { label: "${_jsStr(c.label)}", target: { page: "category", attributes: { category: "${_jsStr(c.value)}" } } },',
        );
      }
      sb.writeln('        ],');
      sb.writeln('      },');
      sb.writeln('    ],');
      sb.writeln('  }');
    }

    // categoryAnimes（分类下的列表）
    if (_categoryUrlCtrl.text.trim().isNotEmpty) {
      sb.writeln('');
      sb.writeln('  categoryAnimes = {');
      sb.writeln('    async load(category, param, options, page) {');
      sb.writeln(
        '      const res = await Network.get(`${_jsUrlTemplate(_categoryUrlCtrl.text.trim())}`, ${_headersJs()})',
      );
      sb.writeln(
        '      const doc = new HtmlDocument(Convert.decodeUtf8(res.body))',
      );
      sb.write(_listParseJs(indent: '      '));
      final maxPageJs = _searchMaxPageJs(_searchMaxPageSelCtrl.text.trim());
      if (maxPageJs != null) {
        sb.writeln('      $maxPageJs');
        sb.writeln('      return { animes, maxPage }');
      } else {
        sb.writeln('      return { animes, maxPage: null }');
      }
      sb.writeln('    },');
      sb.writeln('  }');
    }
    return sb.toString();
  }

  /// 解析分类名列表：一行一个，格式 "值-名称" 或仅 "名称"（值与名称相同）
  List<({String label, String value})> _parseCategoryNames() {
    final result = <({String label, String value})>[];
    for (final line in _categoryNamesCtrl.text.split('\n')) {
      final t = line.trim();
      if (t.isEmpty) continue;
      final idx = t.lastIndexOf('-');
      if (idx > 0) {
        result.add((
          label: t.substring(idx + 1).trim(),
          value: t.substring(0, idx).trim(),
        ));
      } else {
        result.add((label: t, value: t));
      }
    }
    return result;
  }

  /// 详情 + 播放积木的代码
  String _buildDetailJs() {
    if (_detailUrlCtrl.text.trim().isEmpty) return '';
    final sb = StringBuffer();
    sb.writeln('');
    sb.writeln('  anime = {');
    sb.writeln('    async loadInfo(id) {');
    sb.writeln(
      '      const res = await Network.get(`${_jsUrlTemplate(_detailUrlCtrl.text.trim())}`, ${_headersJs()})',
    );
    sb.writeln(
      '      const doc = new HtmlDocument(Convert.decodeUtf8(res.body))',
    );
    sb.writeln(
      '      const title = doc.querySelector("${_jsStr(_detailTitleSelCtrl.text.trim())}")?.text ?? ""',
    );
    sb.writeln(
      '      const cover = doc.querySelector("${_jsStr(_detailCoverSelCtrl.text.trim())}")?.attributes["${_jsStr(_coverAttr)}"] ?? ""',
    );
    sb.writeln(
      '      const description = doc.querySelector("${_jsStr(_detailDescSelCtrl.text.trim())}")?.text ?? ""',
    );
    sb.writeln('      const episode = {}');
    sb.writeln(
      '      const eps = doc.querySelectorAll("${_jsStr(_detailEpSelCtrl.text.trim())}")',
    );
    sb.writeln('      let i = 0');
    sb.writeln('      for (const ep of eps) {');
    sb.writeln(
      '        const a = ep.querySelector("${_jsStr(_detailEpLinkSelCtrl.text.trim())}")',
    );
    sb.writeln('        if (!a) continue');
    sb.writeln(
      '        const t = ep.querySelector("${_jsStr(_detailEpTitleSelCtrl.text.trim())}")?.text ?? a.text',
    );
    sb.writeln('        const href = a.attributes.href ?? ""');
    sb.writeln(
      '        const epId = href.split("/").filter(s => s).pop() || String(i)',
    );
    sb.writeln('        episode[epId] = t');
    sb.writeln('        i++');
    sb.writeln('      }');
    sb.writeln(
      '      return new AnimeDetails({ title, cover, description, episode })',
    );
    sb.writeln('    },');
    if (_playUrlCtrl.text.trim().isNotEmpty || _playDirect) {
      sb.writeln('    async loadEp(id, ep) {');
      if (_playDirect) {
        // 直接返回剧集链接作为播放地址
        sb.writeln('      return ep');
      } else {
        sb.writeln(
          '      const res = await Network.get(`${_jsUrlTemplate(_playUrlCtrl.text.trim())}`, ${_headersJs(referer: true)})',
        );
        sb.writeln(
          '      const doc = new HtmlDocument(Convert.decodeUtf8(res.body))',
        );
        sb.writeln(
          '      const raw = doc.querySelector("body")?.innerHTML ?? ""',
        );
        sb.writeln(
          '      const m = raw.match(/${_jsStr(_playExtractCtrl.text.trim())}/)',
        );
        sb.writeln('      if (m) return m[0]');
        sb.writeln('      return ""');
      }
      sb.writeln('    },');
    }
    sb.writeln('  }');
    return sb.toString();
  }

  Future<void> _generateAndImport() async {
    final name = _nameCtrl.text.trim();
    final key = _keyCtrl.text.trim();
    if (name.isEmpty) return _err(t.builderNameRequired);
    if (key.isEmpty) return _err(t.builderKeyRequired);
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(key)) {
      return _err(t.builderKeyInvalid);
    }
    final js = buildJs();
    setState(() => _generating = true);
    try {
      final source = await AnimeSourceParser().createAndParse(js, '$key.js');
      AnimeSourceManager().add(source);
      // 让已打开的番剧源页刷新
      App.forceRebuild();
      App.rootContext.showMessage(message: t.builderImported);
      App.rootPop();
    } catch (e) {
      _err('${t.builderGenerateFailed}: $e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Widget _card(
    BuildContext context,
    String title,
    IconData icon,
    List<Widget> children, {
    String? code,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Material(
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
            Row(
              children: [
                Icon(icon, size: 18, color: cs.primary),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
            if (code != null && code.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              _codeBlock(code),
            ],
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  /// 代码块预览
  Widget _codeBlock(String text) {
    final cs = Theme.of(context).colorScheme;
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontFamily: 'monospace',
          height: 1.4,
        ),
      ),
    );
  }

  /// 表单字段（带实时刷新）
  Widget _field(TextEditingController ctrl, String label, {int? maxLines}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      onChanged: (_) => setState(() {}),
      decoration: _decoration(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopUpWidgetScaffold(
      title: t.builderTitle,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _card(context, t.builderBasic, Icons.info_outline, [
                  _field(_nameCtrl, t.builderName),
                  const SizedBox(height: 12),
                  _field(_keyCtrl, t.builderKey),
                  const SizedBox(height: 12),
                  _field(_versionCtrl, t.builderVersion),
                  const SizedBox(height: 12),
                  _field(_baseUrlCtrl, t.builderBaseUrl),
                  const SizedBox(height: 12),
                  _field(_userAgentCtrl, t.builderUserAgent),
                ], code: _buildHeaderJs()),
                const SizedBox(height: 16),
                _card(context, t.builderSearch, Icons.search, [
                  _field(_searchUrlCtrl, t.builderSearchUrl),
                  const SizedBox(height: 12),
                  _field(_searchListSelCtrl, t.builderListSelector),
                  const SizedBox(height: 12),
                  _field(_searchTitleSelCtrl, t.builderTitleSelector),
                  const SizedBox(height: 12),
                  _field(_searchCoverSelCtrl, t.builderCoverSelector),
                  const SizedBox(height: 12),
                  _field(_coverAttrCtrl, t.builderCoverAttr),
                  const SizedBox(height: 12),
                  _field(_searchLinkSelCtrl, t.builderLinkSelector),
                  const SizedBox(height: 12),
                  _field(_searchPageParamCtrl, t.builderPageParam),
                  const SizedBox(height: 12),
                  _field(_searchMaxPageSelCtrl, t.builderMaxPageSelector),
                ], code: _buildSearchJs()),
                const SizedBox(height: 16),
                _card(
                  context,
                  t.builderExplore,
                  Icons.explore_outlined,
                  [
                    _field(_exploreTitleCtrl, t.builderExploreTitle),
                    const SizedBox(height: 12),
                    _field(_exploreUrlCtrl, t.builderExploreUrl),
                  ],
                  code: _buildExploreJs(),
                ),
                const SizedBox(height: 16),
                _card(
                  context,
                  t.builderCategory,
                  Icons.category_outlined,
                  [
                    _field(_categoryTitleCtrl, t.builderCategoryTitle),
                    const SizedBox(height: 12),
                    _field(
                      _categoryNamesCtrl,
                      t.builderCategoryNames,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 12),
                    _field(_categoryUrlCtrl, t.builderCategoryUrl),
                  ],
                  code: _buildCategoryJs(),
                ),
                const SizedBox(height: 16),
                _card(
                  context,
                  t.builderDetail,
                  Icons.article_outlined,
                  [
                    _field(_detailUrlCtrl, t.builderDetailUrl),
                    const SizedBox(height: 12),
                    _field(_detailTitleSelCtrl, t.builderTitleSelector),
                    const SizedBox(height: 12),
                    _field(_detailCoverSelCtrl, t.builderCoverSelector),
                    const SizedBox(height: 12),
                    _field(_detailDescSelCtrl, t.builderDescSelector),
                    const SizedBox(height: 12),
                    _field(_detailEpSelCtrl, t.builderEpisodeSelector),
                    const SizedBox(height: 12),
                    _field(
                      _detailEpTitleSelCtrl,
                      t.builderEpisodeTitleSelector,
                    ),
                    const SizedBox(height: 12),
                    _field(_detailEpLinkSelCtrl, t.builderEpisodeLinkSelector),
                  ],
                  code: _buildDetailJs(),
                ),
                const SizedBox(height: 16),
                _card(
                  context,
                  t.builderPlay,
                  Icons.play_circle_outline,
                  [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        t.builderPlayDirect,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        _playDirect
                            ? t.builderPlayDirectDesc
                            : t.builderPlayRegexDesc,
                        style: const TextStyle(fontSize: 12),
                      ),
                      value: _playDirect,
                      onChanged: (v) => setState(() => _playDirect = v),
                    ),
                    if (!_playDirect) ...[
                      const SizedBox(height: 12),
                      _field(_playUrlCtrl, t.builderPlayUrl),
                      const SizedBox(height: 12),
                      _field(
                        _playExtractCtrl,
                        t.builderExtractRegex,
                        maxLines: 3,
                      ),
                    ],
                  ],
                  code: _buildDetailJs(),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _generating ? null : _generateAndImport,
                icon: const Icon(Icons.extension_outlined),
                label: Text(t.builderGenerate),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

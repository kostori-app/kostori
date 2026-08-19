// 动漫识别页：选图 → 压缩(最长边512 JPEG) → trace.moe 识别 → 展示候选 → （可选）入会话讨论。

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/ai_service/anime_recognize_service.dart';
import 'package:kostori/foundation/ai_service/ai_conversation_service.dart';
import 'package:kostori/foundation/ai_service/assistant_profile.dart';
import 'package:kostori/foundation/ai_service/openai_provider_registry.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/pages/ai_hub/ai_hub_page.dart';
import 'package:kostori/pages/bangumi/bangumi_search_page.dart';
import 'package:kostori/pages/hub/hub_chat_widgets.dart';
import 'package:kostori/pages/video_test_page.dart';
import 'package:kostori/i18n/strings.g.dart';

class AnimeRecognizePage extends StatefulWidget {
  const AnimeRecognizePage({super.key});

  @override
  State<AnimeRecognizePage> createState() => _AnimeRecognizePageState();
}

class _AnimeRecognizePageState extends State<AnimeRecognizePage> {
  Uint8List? _image;
  bool _recognizing = false;
  List<AnimeRecognizeResult>? _results;
  String? _error;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    // 激活期间屏蔽全局二维码拖拽识别，避免拖入图片时先弹"未识别到二维码"
    App.animeRecognizeActive = true;
  }

  @override
  void dispose() {
    App.animeRecognizeActive = false;
    super.dispose();
  }

  /// 直接拖入图片文件识别
  Future<void> _onDragDone(DropDoneDetails detail) async {
    if (_recognizing) return;
    for (final f in detail.files) {
      final ext = f.path.split('.').last.toLowerCase();
      if (!{'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'}.contains(ext)) {
        continue;
      }
      try {
        final bytes = await File(f.path).readAsBytes();
        if (!mounted) return;
        setState(() {
          _image = bytes;
          _results = null;
          _error = null;
        });
        await _recognize(bytes);
      } catch (_) {
        if (mounted) {
          setState(() {
            _error = t.recognizeImageFailed;
            _recognizing = false;
          });
        }
      }
      return;
    }
    if (mounted) {
      App.rootContext.showMessage(message: t.chooseImage);
    }
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(t.takePhoto),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(t.pickImages),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final f = await ImagePicker().pickImage(source: source, imageQuality: 85);
      if (f == null) return;
      final bytes = await f.readAsBytes();
      if (!mounted) return;
      setState(() {
        _image = bytes;
        _results = null;
        _error = null;
      });
      await _recognize(bytes);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = t.recognizeImageFailed;
          _recognizing = false;
        });
      }
    }
  }

  Future<void> _recognize(Uint8List bytes) async {
    if (!mounted) return;
    setState(() {
      _recognizing = true;
      _error = null;
    });
    // 压缩：最长边 512、JPEG，降低体积加快识别
    var toSend = bytes;
    try {
      toSend = await hubCompressImage(bytes, maxDim: 512, quality: 80);
    } catch (_) {}
    final res = await AnimeRecognizeService().recognize(toSend);
    if (!mounted) return;
    setState(() {
      _recognizing = false;
      if (res.success) {
        _results = res.data;
      } else {
        _error = res.errorMessage ?? t.recognizeFailed;
      }
    });
  }

  String _defaultProvider() {
    final providers = OpenAiProviderRegistry.allProviders.entries
        .where((e) => !e.value.isCustom)
        .toList();
    return providers.isNotEmpty ? providers.first.key : 'siliconFlow';
  }

  Future<String> _getOrCreateChatSession() async {
    final sessions = await AiConversationService()
        .watchSessions(type: 'chat')
        .first;
    if (sessions.isNotEmpty) return sessions.first.sessionId;
    final store = AssistantProfileStore.instance;
    if (!store.isInitialized) await store.init();
    final id = await AiConversationService().createSession(
      type: 'chat',
      provider: _defaultProvider(),
      title: t.newChat,
      configKey: null,
    );
    await AiConversationService().updateSessionProfile(
      id,
      store.activeId ?? defaultProfile.id,
    );
    return id;
  }

  /// 识别结果入会话：生成一段描述文本发送给 AI，并进入 AI 对话页
  Future<void> _discussInAi(AnimeRecognizeResult r) async {
    final desc = t.recognizePrompt(
      title: r.title,
      episode: r.episode != null ? t.recognizeEpisodeSuffix(n: r.episode!) : '',
      from: AnimeRecognizeResult.fmtTime(r.from),
      to: AnimeRecognizeResult.fmtTime(r.to),
      similarity: r.similarityPercent,
    );
    final sid = await _getOrCreateChatSession();
    unawaited(
      AiConversationService().sendMessage(sessionId: sid, userMessage: desc),
    );
    if (mounted) context.to(() => AiChatPage());
  }

  /// 视频预览：跳转软件内视频测试模块并自动播放该地址
  void _openVideoPreview(String url) {
    context.to(() => VideoTestPage(url: url));
  }

  /// 按识别标题跳转到 Bangumi 搜索页搜索
  void _openBangumi(AnimeRecognizeResult r) {
    context.to(() => BangumiSearchPage(keyword: r.title));
  }

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme;

    Widget body;
    if (_image == null) {
      // 初始：选择图片
      body = _EmptyState(
        icon: Icons.image_search,
        title: t.animeRecognize,
        subtitle: t.chooseImageToRecognize,
        actionLabel: t.chooseImage,
        onTap: _pickImage,
      );
    } else if (_recognizing) {
      body = _LoadingState(image: _image!);
    } else if (_error != null) {
      body = _ErrorState(
        image: _image!,
        error: _error!,
        onRetry: () => _recognize(_image!),
        onRetryLabel: t.retry,
      );
    } else {
      final results = _results ?? const [];
      if (results.isEmpty) {
        body = _EmptyState(
          icon: Icons.search_off,
          title: t.noAnimeFound,
          subtitle: t.chooseAnotherImage,
          actionLabel: t.chooseImage,
          onTap: _pickImage,
        );
      } else {
        body = ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${t.recognizeResult} · ${results.length}',
              style: ts.titleSmall,
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < results.length; i++) ...[
              _ResultCard(
                result: results[i],
                onVideoPreview: results[i].video.isNotEmpty
                    ? () => _openVideoPreview(results[i].video)
                    : null,
                onDiscuss: () => _discussInAi(results[i]),
                onBangumi: () => _openBangumi(results[i]),
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      }
    }
    // 限制页面内容宽度，避免在宽屏下过宽
    body = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: body,
      ),
    );

    // DropTarget 包裹整个页面（含 AppBar/底部栏），避免拖拽落到下层页面的二维码识别
    return DropTarget(
      onDragDone: _onDragDone,
      onDragEntered: (_) {
        if (mounted) setState(() => _isDragging = true);
      },
      onDragExited: (_) {
        if (mounted) setState(() => _isDragging = false);
      },
      child: Stack(
        children: [
          Scaffold(
            appBar: Appbar(
              title: Text(t.animeRecognize),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new),
                tooltip: t.back,
                onPressed: () => context.canPop() ? context.pop() : App.pop(),
              ),
            ),
            body: body,
            bottomNavigationBar: _image == null
                ? null
                : SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: OutlinedButton.icon(
                        onPressed: _recognizing ? null : _pickImage,
                        icon: const Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 18,
                        ),
                        label: Text(t.chooseImage),
                      ),
                    ),
                  ),
          ),
          if (_isDragging)
            Positioned.fill(
              child: Container(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.08),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.inverseSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      t.dropImageToRecognize,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onInverseSurface,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── 空状态 / 加载 / 错误 ─────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: scheme.outlineVariant),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.image});

  final Uint8List image;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: Image.memory(image, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 20),
            const PolygonRefreshIndicator(),
            const SizedBox(height: 12),
            Text(
              t.recognizing,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.image,
    required this.error,
    required this.onRetry,
    required this.onRetryLabel,
  });

  final Uint8List image;
  final String error;
  final VoidCallback onRetry;
  final String onRetryLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: Image.memory(image, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 16),
            Icon(Icons.error_outline, size: 28, color: scheme.error),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: scheme.error),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(onRetryLabel),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 识别结果卡片 ────────────────────────────────

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.result,
    this.onVideoPreview,
    this.onDiscuss,
    this.onBangumi,
  });

  final AnimeRecognizeResult result;
  final VoidCallback? onVideoPreview;
  final VoidCallback? onDiscuss;
  final VoidCallback? onBangumi;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant, width: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (result.image.isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                result.image,
                fit: BoxFit.cover,
                loadingBuilder: (ctx, child, progress) => progress == null
                    ? child
                    : Container(
                        color: scheme.surfaceContainerHighest,
                        child: const Center(child: PolygonRefreshIndicator()),
                      ),
                errorBuilder: (ctx, e, s) => Container(
                  color: scheme.surfaceContainerHighest,
                  child: Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: scheme.outline,
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        result.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      result.similarityPercent,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${result.episode != null ? '${t.episodeLabel}${result.episode}' : t.unknownEpisode}'
                  ' · ${AnimeRecognizeResult.fmtTime(result.from)} → '
                  '${AnimeRecognizeResult.fmtTime(result.to)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (result.filename.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    result.filename,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: scheme.outline),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (onVideoPreview != null)
                      TextButton.icon(
                        onPressed: onVideoPreview,
                        icon: const Icon(Icons.play_circle_outline, size: 18),
                        label: Text(t.openVideoPreview),
                      ),
                    if (onBangumi != null)
                      TextButton.icon(
                        onPressed: onBangumi,
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: Text(t.viewOnBangumi),
                      ),
                    const Spacer(),
                    if (onDiscuss != null)
                      FilledButton.tonalIcon(
                        onPressed: onDiscuss,
                        icon: const Icon(Icons.auto_awesome, size: 16),
                        label: Text(t.discussInAi),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

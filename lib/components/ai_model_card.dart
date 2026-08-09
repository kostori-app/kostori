import 'package:flutter/material.dart';
import 'package:kostori/database/ai_database.dart';
import 'package:kostori/i18n/strings.g.dart';

// ─────────────────────────────────────────────
// 模型选项标签（i18n）+ 基名提取
// ─────────────────────────────────────────────

String modelTypeLabel(String v) => switch (v) {
  'chat' => t.modelTypeChat,
  'image' => t.modelTypeImage,
  'embedding' => t.modelTypeEmbedding,
  'audio' => t.modelTypeAudio,
  'rerank' => t.modelTypeRerank,
  'other' => t.modelTypeOther,
  _ => v,
};

String modalityValueLabel(String v) => switch (v) {
  'text' => t.modalityText,
  'image' => t.modalityImage,
  'audio' => t.modalityAudio,
  'video' => t.modalityVideo,
  _ => v,
};

String capabilityLabel(String v) => switch (v) {
  'tools' => t.capabilityTools,
  'reasoning' => t.capabilityReasoning,
  _ => v,
};

/// 将逗号分隔的模态列表本地化为可读文本（text,image → 文本, 图片）
String localizeModalities(String raw) => raw
    .split(',')
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty)
    .map(modalityValueLabel)
    .join(', ');

/// 提取模型基名：去掉尾部版本/日期/后缀（如 gpt-4o-2024-05-13 → gpt-4o）
String baseModelName(String id) {
  const suffixTokens = {'latest', 'preview', 'free', 'api', 'snapshot', 'base'};
  var current = id;
  for (var depth = 0; depth < 6; depth++) {
    final idx = current.lastIndexOf('-');
    if (idx <= 0) break;
    final suffix = current.substring(idx + 1);
    final isVersion = RegExp(r'^\d+$').hasMatch(suffix);
    if (!isVersion && !suffixTokens.contains(suffix.toLowerCase())) break;
    current = current.substring(0, idx);
  }
  return current;
}

// ─────────────────────────────────────────────
// 模型单行卡片（名称 / ID / 类型 / 模态 / 能力）
// ─────────────────────────────────────────────

class AiModelCard extends StatelessWidget {
  const AiModelCard({
    super.key,
    required this.model,
    required this.onTap,
    this.isSelected = false,
    this.showDefaultBadge = false,
    this.onLongPress,
    this.onSecondaryTap,
    this.trailing,
  });

  final AiModel model;
  final bool isSelected;

  /// 是否在选中时显示「默认模型」徽章
  final bool showDefaultBadge;

  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final input = model.inputModality;
    final output = model.outputModality;

    return Material(
      color: isSelected
          ? scheme.primaryContainer.withValues(alpha: 0.35)
          : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        onSecondaryTap: onSecondaryTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // ── 选中标识 ────────────────────────
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                size: 20,
                color: isSelected ? scheme.primary : scheme.outlineVariant,
              ),
              const SizedBox(width: 10),

              // ── 信息区（名称 / ID / 类型 / 模态）────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            model.label,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? scheme.onPrimaryContainer
                                  : scheme.onSurface,
                            ),
                          ),
                        ),
                        if (isSelected && showDefaultBadge) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              t.defaultModel,
                              style: TextStyle(
                                fontSize: 10,
                                color: scheme.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      model.modelId,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // ── 模型类型 / 输入模态 / 输出模态 ──
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _metaChip(
                          context,
                          modelTypeLabel(
                            model.modelType.isEmpty ? 'chat' : model.modelType,
                          ),
                        ),
                        if (input.isNotEmpty)
                          _metaChip(
                            context,
                            '${t.inputModality}: ${localizeModalities(input)}',
                          ),
                        if (output.isNotEmpty)
                          _metaChip(
                            context,
                            '${t.outputModality}: ${localizeModalities(output)}',
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // ── 能力图标（工具 / 推理）────────────
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _capIcon(
                    context,
                    Icons.build_outlined,
                    model.supportsTools,
                    t.capabilityTools,
                  ),
                  const SizedBox(height: 4),
                  _capIcon(
                    context,
                    Icons.psychology_outlined,
                    model.supportsReasoning,
                    t.capabilityReasoning,
                  ),
                ],
              ),

              const SizedBox(width: 4),
              trailing ??
                  Icon(Icons.chevron_right, size: 20, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaChip(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
      ),
    );
  }

  Widget _capIcon(
    BuildContext context,
    IconData icon,
    bool enabled,
    String tooltip,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Icon(
        icon,
        size: 16,
        color: enabled ? scheme.primary : scheme.outlineVariant,
      ),
    );
  }
}

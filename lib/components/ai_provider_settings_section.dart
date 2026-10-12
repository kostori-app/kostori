import 'package:flutter/material.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/components/empty_state.dart';
import 'package:kostori/foundation/ai_service/ai_provider_settings.dart';
import 'package:kostori/foundation/context.dart';

/// 统一展示服务商状态，内置和自定义使用相同卡片。
class AiProviderSettingsSection extends StatefulWidget {
  const AiProviderSettingsSection({
    super.key,
    required this.providers,
    required this.onOpen,
    required this.onAdd,
  });
  final List<AiProviderSettings> providers;
  final ValueChanged<AiProviderSettings> onOpen;
  final VoidCallback onAdd;

  @override
  State<AiProviderSettingsSection> createState() =>
      _AiProviderSettingsSectionState();
}

class _AiProviderSettingsSectionState extends State<AiProviderSettingsSection> {
  bool _custom = false;

  String _protocol(BuildContext context, String format) => switch (format) {
    'openai_responses' => context.t.aiProtocolResponses,
    'gemini' => context.t.aiProtocolGemini,
    'claude' => context.t.aiProtocolClaude,
    _ => context.t.aiProtocolChatCompletions,
  };

  @override
  Widget build(BuildContext context) {
    final configured = widget.providers
        .where((provider) => provider.isEnabled && provider.isConfigured)
        .length;
    final providers = widget.providers
        .where((provider) => provider.isCustom == _custom)
        .toList();
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.t.aiProviderSummary(
                    enabled: configured,
                    total: widget.providers.length,
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Button.icon(
                icon: const Icon(Icons.add),
                tooltip: context.t.newCustomProvider,
                onPressed: () {
                  setState(() => _custom = true);
                  widget.onAdd();
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CapsuleChipGroup(
            children: [
              CapsuleChip(
                text: context.t.aiBuiltInProviders,
                isSelected: !_custom,
                onTap: () => setState(() => _custom = false),
              ),
              CapsuleChip(
                text: context.t.customProviders,
                isSelected: _custom,
                onTap: () => setState(() => _custom = true),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (providers.isEmpty)
          SizedBox(
            height: 140,
            child: EmptyState(message: context.t.noCustomProviders),
          )
        else
          for (final provider in providers)
            ListTile(
              key: ValueKey('ai-provider-${provider.source}'),
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  provider.isCustom
                      ? Icons.dns_outlined
                      : Icons.auto_awesome_outlined,
                  size: 19,
                  color: scheme.onSecondaryContainer,
                ),
              ),
              title: Text(
                provider.source == 'openai'
                    ? context.t.aiOpenAiProvider
                    : provider.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                provider.isConfigured
                    ? '${provider.model.isEmpty ? context.t.defaultModel : provider.model} · ${_protocol(context, provider.apiFormat)}'
                    : context.t.notConfigured,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    !provider.isConfigured
                        ? context.t.notConfigured
                        : provider.isEnabled
                        ? context.t.enabled
                        : context.t.disabled,
                    style: TextStyle(
                      fontSize: 12,
                      color: provider.isConfigured && provider.isEnabled
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
              onTap: () => widget.onOpen(provider),
            ),
        const SizedBox(height: 8),
      ],
    );
  }
}

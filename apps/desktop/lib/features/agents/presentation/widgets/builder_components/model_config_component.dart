import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/design_system/design_system.dart';
import '../../../models/agent_builder_state.dart';
import '../../screens/agent_builder_screen.dart';

/// Model Configuration Component for Agent Builder
class ModelConfigComponent extends ConsumerWidget {
  const ModelConfigComponent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ThemeColors(context);
    final builderState = ref.watch(agentBuilderStateProvider);

    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(colors),
            const SizedBox(height: SpacingTokens.sectionSpacing),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left side - Model selection and basic settings
                Expanded(
                  flex: 2,
                  child: _buildModelSettings(builderState, colors),
                ),

                const SizedBox(width: SpacingTokens.lg),

                // Right side - Advanced parameters
                Expanded(
                  flex: 1,
                  child: _buildAdvancedSettings(context, builderState, colors),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeColors colors) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(SpacingTokens.sm),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
          ),
          child: Icon(
            Icons.settings,
            color: colors.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: SpacingTokens.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Model Configuration',
              style: TextStyles.titleLarge.copyWith(color: colors.onSurface),
            ),
            Text(
              'Configure the AI model and generation parameters',
              style: TextStyles.bodyMedium.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModelSettings(AgentBuilderState builderState, ThemeColors colors) {
    return AsmblCard(
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology, color: colors.accent, size: 20),
                const SizedBox(width: SpacingTokens.sm),
                Text(
                  'Model Selection',
                  style: TextStyles.titleSmall.copyWith(color: colors.onSurface),
                ),
              ],
            ),
            const SizedBox(height: SpacingTokens.md),

            // Model provider selection
            Text(
              'Model Provider',
              style: TextStyles.bodySmall.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: SpacingTokens.sm),
            _buildModelProviderSelector(builderState, colors),

            const SizedBox(height: SpacingTokens.lg),

            // Model selection
            Text(
              'Model',
              style: TextStyles.bodySmall.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: SpacingTokens.sm),
            _buildModelSelector(builderState, colors),

            const SizedBox(height: SpacingTokens.lg),

            // Performance tier
            Text(
              'Performance Tier',
              style: TextStyles.bodySmall.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: SpacingTokens.sm),
            _buildPerformanceTierSelector(builderState, colors),

            const SizedBox(height: SpacingTokens.lg),

            // Model info card
            Container(
              padding: const EdgeInsets.all(SpacingTokens.md),
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
                border: Border.all(color: colors.accent.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: colors.accent, size: 16),
                      const SizedBox(width: SpacingTokens.xs),
                      Text(
                        'Model Information',
                        style: TextStyles.bodySmall.copyWith(
                          color: colors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: SpacingTokens.xs),
                  Text(
                    _getModelDescription(builderState.modelProvider, builderState.modelName),
                    style: TextStyles.caption.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedSettings(BuildContext context, AgentBuilderState builderState, ThemeColors colors) {
    return Column(
      children: [
        // Generation parameters
        AsmblCard(
          child: Padding(
            padding: const EdgeInsets.all(SpacingTokens.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.tune, color: colors.primary, size: 20),
                    const SizedBox(width: SpacingTokens.sm),
                    Text(
                      'Generation Parameters',
                      style: TextStyles.titleSmall.copyWith(color: colors.onSurface),
                    ),
                  ],
                ),
                const SizedBox(height: SpacingTokens.md),

                // Temperature
                _buildSliderSetting(
                  context,
                  'Temperature',
                  'Controls randomness in responses',
                  builderState.temperature,
                  0.0,
                  2.0,
                  (value) => builderState.updateTemperature(value),
                  colors,
                ),

                const SizedBox(height: SpacingTokens.lg),

                // Max tokens
                _buildSliderSetting(
                  context,
                  'Max Tokens',
                  'Maximum response length',
                  builderState.maxTokens.toDouble(),
                  256,
                  4096,
                  (value) => builderState.updateMaxTokens(value.round()),
                  colors,
                  showAsInteger: true,
                ),

                const SizedBox(height: SpacingTokens.lg),

                // Top P
                _buildSliderSetting(
                  context,
                  'Top P',
                  'Nucleus sampling parameter',
                  builderState.topP,
                  0.0,
                  1.0,
                  (value) => builderState.updateTopP(value),
                  colors,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: SpacingTokens.lg),

        // Cost estimation
        AsmblCard(
          child: Padding(
            padding: const EdgeInsets.all(SpacingTokens.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.monetization_on, color: colors.accent, size: 20),
                    const SizedBox(width: SpacingTokens.sm),
                    Text(
                      'Cost Estimation',
                      style: TextStyles.titleSmall.copyWith(color: colors.onSurface),
                    ),
                  ],
                ),
                const SizedBox(height: SpacingTokens.md),

                _buildCostMetric('Input Tokens', '\$0.003 / 1K', Icons.input, colors),
                const SizedBox(height: SpacingTokens.sm),
                _buildCostMetric('Output Tokens', '\$0.015 / 1K', Icons.output, colors),
                const SizedBox(height: SpacingTokens.sm),
                _buildCostMetric('Est. Cost/Message', '\$0.02', Icons.calculate, colors),

                const SizedBox(height: SpacingTokens.md),

                Container(
                  padding: const EdgeInsets.all(SpacingTokens.sm),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.savings, color: colors.primary, size: 16),
                      const SizedBox(width: SpacingTokens.sm),
                      Expanded(
                        child: Text(
                          'Estimated monthly cost for moderate usage: \$15-30',
                          style: TextStyles.caption.copyWith(color: colors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModelProviderSelector(AgentBuilderState builderState, ThemeColors colors) {
    final providers = ['OpenAI', 'Anthropic', 'Google', 'Local'];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
        border: Border.all(color: colors.border),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 3,
          crossAxisSpacing: 1,
          mainAxisSpacing: 1,
        ),
        itemCount: providers.length,
        itemBuilder: (context, index) {
          final provider = providers[index];
          final isSelected = builderState.modelProvider == provider;

          return InkWell(
            onTap: () => builderState.updateModelProvider(provider),
            child: Container(
              decoration: BoxDecoration(
                color: isSelected
                    ? colors.primary.withValues(alpha: 0.1)
                    : colors.surface,
                border: isSelected
                    ? Border.all(color: colors.primary, width: 2)
                    : null,
              ),
              child: Center(
                child: Text(
                  provider,
                  style: TextStyles.bodySmall.copyWith(
                    color: isSelected ? colors.primary : colors.onSurface,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModelSelector(AgentBuilderState builderState, ThemeColors colors) {
    final models = _getModelsForProvider(builderState.modelProvider);

    return DropdownButtonFormField<String>(
      initialValue: models.contains(builderState.modelName) ? builderState.modelName : models.first,
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        filled: true,
        fillColor: colors.surface,
      ),
      items: models.map((model) => DropdownMenuItem(
        value: model,
        child: Text(
          model,
          style: TextStyles.bodyMedium.copyWith(color: colors.onSurface),
        ),
      )).toList(),
      onChanged: (value) {
        if (value != null) {
          builderState.updateModelName(value);
        }
      },
    );
  }

  Widget _buildPerformanceTierSelector(AgentBuilderState builderState, ThemeColors colors) {
    final tiers = [
      {'name': 'Fast', 'desc': 'Quick responses, lower quality', 'icon': Icons.flash_on},
      {'name': 'Balanced', 'desc': 'Good balance of speed and quality', 'icon': Icons.balance},
      {'name': 'Quality', 'desc': 'Best quality, slower responses', 'icon': Icons.star},
    ];

    return Column(
      children: tiers.map((tier) {
        final isSelected = builderState.performanceTier == tier['name'];
        return Padding(
          padding: const EdgeInsets.only(bottom: SpacingTokens.sm),
          child: InkWell(
            onTap: () => builderState.updatePerformanceTier(tier['name'] as String),
            child: Container(
              padding: const EdgeInsets.all(SpacingTokens.md),
              decoration: BoxDecoration(
                color: isSelected
                    ? colors.primary.withValues(alpha: 0.1)
                    : colors.surface,
                border: Border.all(
                  color: isSelected
                      ? colors.primary
                      : colors.border,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
              ),
              child: Row(
                children: [
                  Icon(
                    tier['icon'] as IconData,
                    color: isSelected ? colors.primary : colors.onSurfaceVariant,
                    size: 20,
                  ),
                  const SizedBox(width: SpacingTokens.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tier['name'] as String,
                          style: TextStyles.bodyMedium.copyWith(
                            color: isSelected ? colors.primary : colors.onSurface,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        Text(
                          tier['desc'] as String,
                          style: TextStyles.caption.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSliderSetting(
    BuildContext context,
    String label,
    String description,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
    ThemeColors colors, {
    bool showAsInteger = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyles.bodySmall.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              showAsInteger ? value.round().toString() : value.toStringAsFixed(2),
              style: TextStyles.bodySmall.copyWith(color: colors.primary),
            ),
          ],
        ),
        const SizedBox(height: SpacingTokens.xs),
        Text(
          description,
          style: TextStyles.caption.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: SpacingTokens.sm),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: colors.primary,
            inactiveTrackColor: colors.primary.withValues(alpha: 0.3),
            thumbColor: colors.primary,
            overlayColor: colors.primary.withValues(alpha: 0.1),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: showAsInteger ? (max - min).round() : null,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildCostMetric(String label, String cost, IconData icon, ThemeColors colors) {
    return Row(
      children: [
        Icon(icon, color: colors.accent, size: 16),
        const SizedBox(width: SpacingTokens.sm),
        Expanded(
          child: Text(
            label,
            style: TextStyles.bodySmall.copyWith(color: colors.onSurface),
          ),
        ),
        Text(
          cost,
          style: TextStyles.bodySmall.copyWith(
            color: colors.accent,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  List<String> _getModelsForProvider(String provider) {
    switch (provider) {
      case 'OpenAI':
        return ['gpt-4o', 'gpt-4o-mini', 'gpt-4-turbo', 'gpt-3.5-turbo'];
      case 'Anthropic':
        return ['claude-3-5-sonnet-20241022', 'claude-3-opus-20240229', 'claude-3-haiku-20240307'];
      case 'Google':
        return ['gemini-1.5-pro', 'gemini-1.5-flash', 'gemini-1.0-pro'];
      case 'Local':
        return ['llama-3.1-8b', 'llama-3.1-70b', 'mistral-7b', 'codellama-13b'];
      default:
        return ['gpt-4o'];
    }
  }

  String _getModelDescription(String provider, String model) {
    switch (provider) {
      case 'OpenAI':
        if (model.contains('gpt-4o')) return 'Latest multimodal model with excellent reasoning capabilities';
        if (model.contains('gpt-4')) return 'Advanced reasoning model, slower but higher quality';
        return 'Fast and efficient model for most tasks';
      case 'Anthropic':
        if (model.contains('opus')) return 'Most capable model for complex reasoning and analysis';
        if (model.contains('sonnet')) return 'Balanced performance for most use cases';
        return 'Fast and efficient for simple tasks';
      case 'Google':
        if (model.contains('pro')) return 'Advanced model with multimodal capabilities';
        return 'Fast model optimized for speed';
      case 'Local':
        return 'Runs locally on your machine for privacy and cost control';
      default:
        return 'Select a model to see description';
    }
  }
}
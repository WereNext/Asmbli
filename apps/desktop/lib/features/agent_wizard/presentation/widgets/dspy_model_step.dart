import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/models/model_config.dart';
import '../../../../core/services/model_config_service.dart';
import '../../models/dspy_agent_wizard_state.dart';

/// Step 3: Model Selection
///
/// Select the LLM model and configure parameters.
/// Uses unified ModelConfigService for dynamic model discovery.
class DspyModelStep extends ConsumerWidget {
  final DspyAgentWizardState wizardState;
  final VoidCallback onChanged;

  const DspyModelStep({
    super.key,
    required this.wizardState,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readyModels = ref.watch(readyModelConfigsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(SpacingTokens.xxl),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: SpacingTokens.xxl),
              _buildModelSelection(context, readyModels),
              const SizedBox(height: SpacingTokens.xxl),
              _buildParameters(context),
              const SizedBox(height: SpacingTokens.lg),
              _buildApiKeyInfo(context, readyModels),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Model Selection', style: TextStyles.pageTitle),
        const SizedBox(height: SpacingTokens.sm),
        Text(
          'Choose the AI model that powers your agent. Each model has different capabilities and costs.',
          style: TextStyles.bodyMedium.copyWith(
            color: ThemeColors(context).onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildModelSelection(BuildContext context, List<ModelConfig> readyModels) {
    final colors = ThemeColors(context);

    if (readyModels.isEmpty) {
      return _buildNoModelsMessage(context);
    }

    // Group models by provider type (Local vs API providers)
    final localModels = readyModels.where((m) => m.isLocal).toList();
    final apiModels = readyModels.where((m) => m.isApi).toList();

    // Further group API models by provider
    final apiByProvider = <String, List<ModelConfig>>{};
    for (final model in apiModels) {
      apiByProvider.putIfAbsent(model.provider, () => []).add(model);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.memory, color: colors.primary, size: 20),
            const SizedBox(width: SpacingTokens.sm),
            Text('AI Model', style: TextStyles.cardTitle),
          ],
        ),
        const SizedBox(height: SpacingTokens.md),

        // Local models section
        if (localModels.isNotEmpty) ...[
          _buildProviderSection(context, 'Local', localModels, isLocal: true),
        ],

        // API models by provider
        ...apiByProvider.entries.map((entry) => _buildProviderSection(
          context,
          entry.key,
          entry.value,
        )),
      ],
    );
  }

  Widget _buildNoModelsMessage(BuildContext context) {
    final colors = ThemeColors(context);

    return Container(
      padding: const EdgeInsets.all(SpacingTokens.xl),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.1),
        border: Border.all(color: colors.warning.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
      ),
      child: Column(
        children: [
          Icon(Icons.warning_amber, color: colors.warning, size: 48),
          const SizedBox(height: SpacingTokens.md),
          Text(
            'No Models Configured',
            style: TextStyles.cardTitle.copyWith(color: colors.warning),
          ),
          const SizedBox(height: SpacingTokens.sm),
          Text(
            'Configure at least one model in Settings to continue.\n'
            'You can add API keys for cloud models or install local models via Ollama.',
            style: TextStyles.bodyMedium.copyWith(
              color: colors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: SpacingTokens.lg),
          AsmblButton.primary(
            text: 'Go to Settings',
            icon: Icons.settings,
            onPressed: () {
              // Navigate to settings
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProviderSection(
    BuildContext context,
    String provider,
    List<ModelConfig> models, {
    bool isLocal = false,
  }) {
    final colors = ThemeColors(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: SpacingTokens.sm),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _getProviderColor(provider, isLocal).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isLocal ? 'Ollama (Local)' : provider,
                  style: TextStyles.bodySmall.copyWith(
                    color: _getProviderColor(provider, isLocal),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isLocal) ...[
                const SizedBox(width: SpacingTokens.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SpacingTokens.xs,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.success.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'FREE',
                    style: TextStyles.bodySmall.copyWith(
                      color: colors.success,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Wrap(
          spacing: SpacingTokens.sm,
          runSpacing: SpacingTokens.sm,
          children: models.map((model) => _buildModelCard(context, model)).toList(),
        ),
        const SizedBox(height: SpacingTokens.md),
      ],
    );
  }

  Widget _buildModelCard(BuildContext context, ModelConfig model) {
    // Check if this model is selected by comparing model ID
    final isSelected = wizardState.selectedModelId == model.model ||
                       wizardState.selectedModelId == model.id;
    final colors = ThemeColors(context);

    return InkWell(
      onTap: () {
        wizardState.setSelectedModelId(model.model);
        wizardState.setSelectedModelConfig(model);
        onChanged();
      },
      borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(SpacingTokens.md),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary.withValues(alpha: 0.1) : colors.surface,
          border: Border.all(
            color: isSelected ? colors.primary : colors.border,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    model.name,
                    style: TextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, color: colors.primary, size: 18),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _getModelDescription(model),
              style: TextStyles.bodySmall.copyWith(
                color: colors.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: SpacingTokens.sm),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SpacingTokens.xs,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    model.model,
                    style: TextStyles.bodySmall.copyWith(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                const Spacer(),
                if (model.isLocal && model.modelSize != null)
                  Text(
                    model.displaySize,
                    style: TextStyles.bodySmall.copyWith(
                      fontSize: 10,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getModelDescription(ModelConfig model) {
    if (model.isLocal) {
      return 'Local model via Ollama';
    }

    final provider = model.provider.toLowerCase();
    if (provider.contains('anthropic') || provider.contains('claude')) {
      return 'Anthropic Claude model';
    } else if (provider.contains('openai') || provider.contains('gpt')) {
      return 'OpenAI GPT model';
    } else if (provider.contains('google') || provider.contains('gemini')) {
      return 'Google Gemini model';
    }
    return 'API model';
  }

  Widget _buildParameters(BuildContext context) {
    final colors = ThemeColors(context);

    return AsmblCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, color: colors.primary, size: 20),
              const SizedBox(width: SpacingTokens.sm),
              Text('Response Settings', style: TextStyles.cardTitle),
            ],
          ),
          const SizedBox(height: SpacingTokens.sm),
          Text(
            'Adjust how your agent responds',
            style: TextStyles.bodySmall.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: SpacingTokens.lg),

          // Temperature slider (now called Creativity)
          _buildParameterSlider(
            context,
            label: 'Creativity',
            description: 'Lower = more consistent and focused. Higher = more varied and creative.',
            value: wizardState.temperature,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            onChanged: (value) {
              wizardState.setTemperature(value);
              onChanged();
            },
          ),

          const SizedBox(height: SpacingTokens.lg),

          // Max tokens slider (now called Response Length)
          _buildParameterSlider(
            context,
            label: 'Response Length',
            description: 'How long the agent\'s responses can be',
            value: wizardState.maxTokens.toDouble(),
            min: 100,
            max: 8000,
            divisions: 79,
            displayValue: _getResponseLengthLabel(wizardState.maxTokens),
            onChanged: (value) {
              wizardState.setMaxTokens(value.round());
              onChanged();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildParameterSlider(
    BuildContext context, {
    required String label,
    required String description,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    String? displayValue,
  }) {
    final colors = ThemeColors(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: SpacingTokens.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                displayValue ?? value.toStringAsFixed(2),
                style: TextStyles.bodySmall.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
          activeColor: colors.primary,
        ),
        Text(
          description,
          style: TextStyles.bodySmall.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildApiKeyInfo(BuildContext context, List<ModelConfig> readyModels) {
    final colors = ThemeColors(context);

    // Find currently selected model
    final selectedModel = readyModels.where(
      (m) => m.model == wizardState.selectedModelId || m.id == wizardState.selectedModelId
    ).firstOrNull;

    if (selectedModel == null) {
      return const SizedBox.shrink();
    }

    if (selectedModel.isLocal) {
      return Container(
        padding: const EdgeInsets.all(SpacingTokens.md),
        decoration: BoxDecoration(
          color: colors.success.withValues(alpha: 0.1),
          border: Border.all(color: colors.success.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: colors.success, size: 20),
            const SizedBox(width: SpacingTokens.sm),
            Expanded(
              child: Text(
                'Local model - no API key required. Make sure Ollama is running.',
                style: TextStyles.bodySmall.copyWith(color: colors.onSurface),
              ),
            ),
          ],
        ),
      );
    }

    // API model - show configured status
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.md),
      decoration: BoxDecoration(
        color: colors.success.withValues(alpha: 0.1),
        border: Border.all(color: colors.success.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: colors.success, size: 20),
          const SizedBox(width: SpacingTokens.sm),
          Expanded(
            child: Text(
              '${selectedModel.provider} API key configured and ready.',
              style: TextStyles.bodySmall.copyWith(color: colors.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  String _getResponseLengthLabel(int tokens) {
    if (tokens < 500) return 'Brief';
    if (tokens < 1500) return 'Short';
    if (tokens < 3000) return 'Medium';
    if (tokens < 5000) return 'Long';
    return 'Very Long';
  }

  Color _getProviderColor(String provider, bool isLocal) {
    if (isLocal) return Colors.purple;

    final lowerProvider = provider.toLowerCase();
    if (lowerProvider.contains('anthropic') || lowerProvider.contains('claude')) {
      return Colors.orange;
    } else if (lowerProvider.contains('openai') || lowerProvider.contains('gpt')) {
      return Colors.green;
    } else if (lowerProvider.contains('google') || lowerProvider.contains('gemini')) {
      return Colors.blue;
    }
    return Colors.grey;
  }
}

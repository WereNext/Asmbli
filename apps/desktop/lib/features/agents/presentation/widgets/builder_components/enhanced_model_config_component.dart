import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/design_system/design_system.dart';
import '../../../../../core/di/service_locator.dart';
import '../../../../../core/services/agent_model_recommendation_service.dart';
import '../../../../../core/services/agent_template_service.dart';
import '../../../../../core/models/agent_template.dart';
import '../../../../../core/models/model_config.dart';
import '../../../../../core/services/model_config_service.dart';
import '../../../models/agent_builder_state.dart';
import '../../screens/agent_builder_screen.dart';
import '../agent_capability_selector.dart';

/// Enhanced Model Configuration Component with intelligent recommendations
class EnhancedModelConfigComponent extends ConsumerStatefulWidget {
  const EnhancedModelConfigComponent({super.key});

  @override
  ConsumerState<EnhancedModelConfigComponent> createState() => _EnhancedModelConfigComponentState();
}

class _EnhancedModelConfigComponentState extends ConsumerState<EnhancedModelConfigComponent> {
  late AgentModelRecommendationService _recommendationService;
  late AgentTemplateService _templateService;
  late ModelConfigService _modelConfigService;
  
  String _selectedMode = 'template'; // 'template', 'custom', 'simple'
  AgentTemplate? _selectedTemplate;
  List<String> _selectedCapabilities = [];
  AgentModelConfiguration? _generatedConfig;
  List<ModelConfig> _availableModels = [];

  @override
  void initState() {
    super.initState();
    _recommendationService = ServiceLocator.instance.get<AgentModelRecommendationService>();
    _templateService = AgentTemplateService();
    _modelConfigService = ServiceLocator.instance.get<ModelConfigService>();
    _loadAvailableModels();
  }

  Future<void> _loadAvailableModels() async {
    setState(() {
      _availableModels = _modelConfigService.getReadyModels();
    });
  }

  @override
  Widget build(BuildContext context) {
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

            // Mode selector
            _buildModeSelector(colors),
            const SizedBox(height: SpacingTokens.lg),

            // Content based on selected mode
            _buildModeContent(builderState, colors),
            
            // Current configuration display
            if (_generatedConfig != null || _selectedTemplate != null)
              _buildCurrentConfiguration(builderState, colors),
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
            Icons.auto_awesome,
            color: colors.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: SpacingTokens.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Intelligent Model Configuration',
              style: TextStyles.titleLarge.copyWith(color: colors.onSurface),
            ),
            Text(
              'Let us recommend the best models for your agent\'s capabilities',
              style: TextStyles.bodyMedium.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModeSelector(ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildModeOption(
              'template',
              'Use Template',
              'Pre-configured agents with optimal models',
              Icons.widgets,
              colors,
            ),
          ),
          Expanded(
            child: _buildModeOption(
              'custom',
              'Custom Build',
              'Select capabilities and get model recommendations',
              Icons.tune,
              colors,
            ),
          ),
          Expanded(
            child: _buildModeOption(
              'simple',
              'Single Model',
              'Traditional single-model setup',
              Icons.psychology,
              colors,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeOption(String mode, String title, String subtitle, IconData icon, ThemeColors colors) {
    final isSelected = _selectedMode == mode;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(SpacingTokens.md),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
          border: isSelected ? Border.all(color: colors.primary) : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? colors.primary : colors.onSurfaceVariant,
              size: 24,
            ),
            const SizedBox(height: SpacingTokens.xs),
            Text(
              title,
              style: TextStyles.bodyMedium.copyWith(
                color: isSelected ? colors.primary : colors.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(height: SpacingTokens.xs),
            Text(
              subtitle,
              style: TextStyles.caption.copyWith(
                color: colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeContent(AgentBuilderState builderState, ThemeColors colors) {
    switch (_selectedMode) {
      case 'template':
        return _buildTemplateMode(colors);
      case 'custom':
        return _buildCustomMode(builderState, colors);
      case 'simple':
        return _buildSimpleMode(builderState, colors);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTemplateMode(ThemeColors colors) {
    final templates = _templateService.getAllTemplates();
    final categories = _templateService.getCategories();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose a Template',
          style: TextStyles.sectionTitle,
        ),
        const SizedBox(height: SpacingTokens.md),
        
        ...categories.map((category) {
          final categoryTemplates = templates.where((t) => t.category == category).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: SpacingTokens.md),
                child: Text(
                  category,
                  style: TextStyles.cardTitle.copyWith(color: colors.accent),
                ),
              ),
              Wrap(
                spacing: SpacingTokens.md,
                runSpacing: SpacingTokens.md,
                children: categoryTemplates.map((template) {
                  final isSelected = _selectedTemplate?.id == template.id;
                  return _buildTemplateCard(template, isSelected, colors);
                }).toList(),
              ),
              const SizedBox(height: SpacingTokens.lg),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildTemplateCard(AgentTemplate template, bool isSelected, ThemeColors colors) {
    return GestureDetector(
      onTap: () => _selectTemplate(template),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 320,
        padding: const EdgeInsets.all(SpacingTokens.md),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary.withValues(alpha: 0.1) : colors.surface,
          borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
          border: Border.all(
            color: isSelected ? colors.primary : colors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(SpacingTokens.xs),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
                  ),
                  child: Icon(template.icon, color: colors.accent, size: 20),
                ),
                const SizedBox(width: SpacingTokens.sm),
                Expanded(
                  child: Text(
                    template.name,
                    style: TextStyles.cardTitle.copyWith(
                      color: isSelected ? colors.primary : colors.onSurface,
                    ),
                  ),
                ),
                if (template.isMultiModel)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SpacingTokens.xs,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
                    ),
                    child: Text(
                      'Multi-Model',
                      style: TextStyles.caption.copyWith(
                        color: colors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: SpacingTokens.sm),
            
            Text(
              template.description,
              style: TextStyles.bodySmall.copyWith(
                color: colors.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: SpacingTokens.md),
            
            // Capabilities
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: template.capabilities.take(3).map((capability) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SpacingTokens.xs,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
                  ),
                  child: Text(
                    _getCapabilityDisplayName(capability),
                    style: TextStyles.caption.copyWith(
                      color: colors.primary,
                    ),
                  ),
                );
              }).toList(),
            ),
            
            if (template.capabilities.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '+${template.capabilities.length - 3} more',
                  style: TextStyles.caption.copyWith(
                    color: colors.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomMode(AgentBuilderState builderState, ThemeColors colors) {
    return AgentCapabilitySelector(
      selectedCapabilities: _selectedCapabilities,
      onCapabilitiesChanged: (capabilities) {
        setState(() {
          _selectedCapabilities = capabilities;
        });
      },
      onConfigurationGenerated: (config) {
        setState(() {
          _generatedConfig = config;
        });
        _applyConfiguration(builderState, config);
      },
    );
  }

  Widget _buildSimpleMode(AgentBuilderState builderState, ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select a Single Model',
            style: TextStyles.sectionTitle,
          ),
          const SizedBox(height: SpacingTokens.md),
          
          Text(
            'Choose one model for all tasks. This is the traditional approach.',
            style: TextStyles.bodyMedium.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: SpacingTokens.lg),
          
          // Model selection dropdown
          DropdownButtonFormField<String>(
            value: builderState.selectedModelId,
            decoration: InputDecoration(
              labelText: 'Model',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
              ),
            ),
            items: _availableModels.map((model) {
              return DropdownMenuItem(
                value: model.id,
                child: Row(
                  children: [
                    Icon(
                      model.isLocal ? Icons.computer : Icons.cloud,
                      size: 16,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: SpacingTokens.sm),
                    Expanded(
                      child: Text(
                        model.name,
                        style: TextStyles.bodyMedium,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                builderState.setSelectedModelId(value);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentConfiguration(AgentBuilderState builderState, ThemeColors colors) {
    return Container(
      margin: const EdgeInsets.only(top: SpacingTokens.xl),
      padding: const EdgeInsets.all(SpacingTokens.lg),
      decoration: BoxDecoration(
        color: colors.success.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
        border: Border.all(color: colors.success.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: colors.success),
              const SizedBox(width: SpacingTokens.sm),
              Text(
                'Configuration Applied',
                style: TextStyles.cardTitle.copyWith(color: colors.success),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.md),
          
          if (_selectedTemplate != null) ...[
            Text(
              'Template: ${_selectedTemplate!.name}',
              style: TextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: SpacingTokens.sm),
            Text(
              'Capabilities: ${_selectedTemplate!.capabilities.join(', ')}',
              style: TextStyles.bodyMedium.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            if (_selectedTemplate!.isMultiModel) ...[
              const SizedBox(height: SpacingTokens.sm),
              Text(
                'Models: ${_selectedTemplate!.recommendedModels?.length ?? 0} specialized models',
                style: TextStyles.bodyMedium.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ],
          
          if (_generatedConfig != null) ...[
            Text(
              'Custom Configuration',
              style: TextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: SpacingTokens.sm),
            Text(
              'Primary: ${_generatedConfig!.primaryModelId}',
              style: TextStyles.bodyMedium.copyWith(
                color: colors.onSurfaceVariant,
                fontFamily: 'monospace',
              ),
            ),
            if (_generatedConfig!.specializedModels.isNotEmpty) ...[
              const SizedBox(height: SpacingTokens.sm),
              Text(
                'Specialized: ${_generatedConfig!.specializedModels.length} models',
                style: TextStyles.bodyMedium.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  void _selectTemplate(AgentTemplate template) {
    setState(() {
      _selectedTemplate = template;
      _generatedConfig = null; // Clear any custom config
    });
    
    // Apply template to builder state
    final builderState = ref.read(agentBuilderStateProvider);
    builderState.applyTemplate(template);
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Applied ${template.name} template with optimized models'),
      ),
    );
  }

  void _applyConfiguration(AgentBuilderState builderState, AgentModelConfiguration config) {
    builderState.setModelConfiguration(config);
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Applied custom configuration with ${config.modelCount} models'),
      ),
    );
  }

  String _getCapabilityDisplayName(String capability) {
    switch (capability) {
      case 'reasoning': return 'Reasoning';
      case 'coding': return 'Code';
      case 'vision': return 'Vision';
      case 'creative': return 'Creative';
      case 'analysis': return 'Analysis';
      case 'support': return 'Support';
      case 'tools': return 'Tools';
      case 'math': return 'Math';
      default: return capability;
    }
  }
}
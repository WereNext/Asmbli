import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/models/model_config.dart';
import '../../../../core/services/business/agent_business_service.dart';
import '../../../../core/services/model_config_service.dart';
import '../../models/dspy_agent_builder_state.dart';

/// Provider for the DSPy agent builder state
final dspyAgentBuilderStateProvider = ChangeNotifierProvider<DspyAgentBuilderState>((ref) {
  return DspyAgentBuilderState();
});

/// New DSPy-focused Agent Builder Screen
///
/// Features:
/// - 6-step wizard (vs 8 in legacy)
/// - DSPy-native configuration (agent types, reasoning patterns)
/// - Template quick-start
/// - Clean, modern UI
class DspyAgentBuilderScreen extends ConsumerStatefulWidget {
  final String? agentId;

  const DspyAgentBuilderScreen({super.key, this.agentId});

  @override
  ConsumerState<DspyAgentBuilderScreen> createState() => _DspyAgentBuilderScreenState();
}

class _DspyAgentBuilderScreenState extends ConsumerState<DspyAgentBuilderScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Initialize for editing if agentId provided
    if (widget.agentId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadAgentForEditing();
      });
    }
  }

  Future<void> _loadAgentForEditing() async {
    try {
      if (!ServiceLocator.instance.isRegistered<AgentBusinessService>()) {
        debugPrint('AgentBusinessService not registered - skipping edit load');
        return;
      }
      final agentService = ServiceLocator.instance.get<AgentBusinessService>();
      final result = await agentService.getAgentDetails(widget.agentId!);
      if (result.isSuccess && mounted) {
        ref.read(dspyAgentBuilderStateProvider).startEditing(widget.agentId!, result.data!);
      }
    } catch (e) {
      debugPrint('Failed to load agent for editing: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ThemeColors(context);
    final state = ref.watch(dspyAgentBuilderStateProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.5,
            colors: [
              colors.backgroundGradientStart,
              colors.backgroundGradientMiddle,
              colors.backgroundGradientEnd,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(state, colors),
              _buildStepIndicator(state, colors),
              Expanded(
                child: _buildContent(state, colors),
              ),
              _buildFooter(state, colors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(DspyAgentBuilderState state, ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.close, color: colors.onSurface),
            onPressed: () => _handleClose(state),
          ),
          const SizedBox(width: SpacingTokens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.isEditing ? 'Edit Agent' : 'Create New Agent',
                  style: TextStyles.pageTitle.copyWith(color: colors.onSurface),
                ),
                Text(
                  'Powered by DSPy',
                  style: TextStyles.caption.copyWith(color: colors.primary),
                ),
              ],
            ),
          ),
          // Template selector button
          if (!state.isEditing && state.currentStep == DspyBuilderStep.basicInfo)
            TextButton.icon(
              icon: Icon(Icons.flash_on, color: colors.accent),
              label: Text(
                'Use Template',
                style: TextStyles.bodyMedium.copyWith(color: colors.accent),
              ),
              onPressed: () => _showTemplateSelector(state, colors),
            ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(DspyAgentBuilderState state, ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.lg),
      child: Row(
        children: DspyBuilderStep.values.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          final isActive = state.currentStepIndex == index;
          final isCompleted = state.currentStepIndex > index;

          return Expanded(
            child: GestureDetector(
              onTap: () => _goToStep(state, index),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (index > 0)
                        Expanded(
                          child: Container(
                            height: 2,
                            color: isCompleted ? colors.primary : colors.border,
                          ),
                        ),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isActive
                              ? colors.primary
                              : isCompleted
                                  ? colors.primary.withValues(alpha: 0.2)
                                  : colors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isActive || isCompleted ? colors.primary : colors.border,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: isCompleted
                              ? Icon(Icons.check, size: 16, color: colors.primary)
                              : Text(
                                  '${index + 1}',
                                  style: TextStyles.bodySmall.copyWith(
                                    color: isActive ? colors.onPrimary : colors.onSurfaceVariant,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      if (index < DspyBuilderStep.values.length - 1)
                        Expanded(
                          child: Container(
                            height: 2,
                            color: isCompleted ? colors.primary : colors.border,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: SpacingTokens.xs),
                  Text(
                    DspyAgentBuilderState.getStepTitle(step),
                    style: TextStyles.caption.copyWith(
                      color: isActive ? colors.primary : colors.onSurfaceVariant,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildContent(DspyAgentBuilderState state, ThemeColors colors) {
    return PageView(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      onPageChanged: (index) {
        state.setCurrentStep(DspyBuilderStep.values[index]);
      },
      children: [
        _buildBasicInfoStep(state, colors),
        _buildAgentConfigStep(state, colors),
        _buildSystemPromptStep(state, colors),
        _buildToolsAndContextStep(state, colors),
        _buildModelSelectionStep(state, colors),
        _buildReviewStep(state, colors),
      ],
    );
  }

  Widget _buildFooter(DspyAgentBuilderState state, ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (state.canGoBack)
            AsmblButton.secondary(
              text: 'Previous',
              icon: Icons.arrow_back,
              onPressed: () => _previousStep(state),
            )
          else
            const SizedBox(width: 100),

          if (state.isLastStep)
            AsmblButton.primary(
              text: state.isEditing ? 'Update Agent' : 'Create Agent',
              icon: Icons.check,
              onPressed: state.isConfigurationValid ? () => _createAgent(state) : null,
            )
          else
            AsmblButton.primary(
              text: 'Next',
              icon: Icons.arrow_forward,
              onPressed: state.isStepValid ? () => _nextStep(state) : null,
            ),
        ],
      ),
    );
  }

  // ============ STEP BUILDERS ============

  Widget _buildBasicInfoStep(DspyAgentBuilderState state, ThemeColors colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(SpacingTokens.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            'Basic Information',
            'Give your agent a name and describe what it does',
            Icons.info_outline,
            colors,
          ),
          const SizedBox(height: SpacingTokens.xl),

          // Name field
          Text('Agent Name *', style: TextStyles.labelMedium.copyWith(color: colors.onSurface)),
          const SizedBox(height: SpacingTokens.sm),
          TextField(
            decoration: InputDecoration(
              hintText: 'e.g., Research Assistant, Code Reviewer',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(BorderRadiusTokens.md)),
              filled: true,
              fillColor: colors.surface,
            ),
            controller: TextEditingController(text: state.name)
              ..selection = TextSelection.collapsed(offset: state.name.length),
            onChanged: state.setName,
          ),
          const SizedBox(height: SpacingTokens.lg),

          // Description field
          Text('Description', style: TextStyles.labelMedium.copyWith(color: colors.onSurface)),
          const SizedBox(height: SpacingTokens.sm),
          TextField(
            decoration: InputDecoration(
              hintText: 'Describe what this agent does...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(BorderRadiusTokens.md)),
              filled: true,
              fillColor: colors.surface,
            ),
            controller: TextEditingController(text: state.description)
              ..selection = TextSelection.collapsed(offset: state.description.length),
            onChanged: state.setDescription,
            maxLines: 3,
          ),
          const SizedBox(height: SpacingTokens.lg),

          // Category dropdown
          Text('Category', style: TextStyles.labelMedium.copyWith(color: colors.onSurface)),
          const SizedBox(height: SpacingTokens.sm),
          DropdownButtonFormField<String>(
            value: state.category,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(BorderRadiusTokens.md)),
              filled: true,
              fillColor: colors.surface,
            ),
            items: ['General', 'Research', 'Business', 'Creative', 'Development', 'Operations']
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (value) => state.setCategory(value ?? 'General'),
          ),

          // Validation errors
          if (state.getStepErrors(DspyBuilderStep.basicInfo).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: SpacingTokens.md),
              child: Text(
                state.getStepErrors(DspyBuilderStep.basicInfo).join('\n'),
                style: TextStyles.bodySmall.copyWith(color: colors.error),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAgentConfigStep(DspyAgentBuilderState state, ThemeColors colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(SpacingTokens.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            'Agent Configuration',
            'Choose how your agent thinks and acts',
            Icons.psychology,
            colors,
          ),
          const SizedBox(height: SpacingTokens.xl),

          // Agent Type selector
          Text('Agent Type', style: TextStyles.labelMedium.copyWith(color: colors.onSurface)),
          const SizedBox(height: SpacingTokens.sm),
          _buildAgentTypeSelector(state, colors),
          const SizedBox(height: SpacingTokens.xl),

          // Reasoning Pattern (shown only for reasoning/react types)
          if (state.agentType != DspyAgentType.chat) ...[
            Text('Reasoning Pattern', style: TextStyles.labelMedium.copyWith(color: colors.onSurface)),
            const SizedBox(height: SpacingTokens.sm),
            _buildReasoningPatternSelector(state, colors),
            const SizedBox(height: SpacingTokens.xl),
          ],

          // Max Iterations slider
          if (state.agentType == DspyAgentType.react || state.agentType == DspyAgentType.reasoning) ...[
            Text('Max Iterations: ${state.maxIterations}', style: TextStyles.labelMedium.copyWith(color: colors.onSurface)),
            const SizedBox(height: SpacingTokens.sm),
            Slider(
              value: state.maxIterations.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              label: '${state.maxIterations}',
              onChanged: (value) => state.setMaxIterations(value.toInt()),
            ),
            Text(
              'Number of reasoning steps before providing an answer',
              style: TextStyles.caption.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: SpacingTokens.lg),
          ],

          // Tree of Thought branches (only for ToT)
          if (state.reasoningPattern == DspyReasoningPattern.treeOfThought) ...[
            Text('Exploration Branches: ${state.treeOfThoughtBranches}',
                style: TextStyles.labelMedium.copyWith(color: colors.onSurface)),
            const SizedBox(height: SpacingTokens.sm),
            Slider(
              value: state.treeOfThoughtBranches.toDouble(),
              min: 2,
              max: 5,
              divisions: 3,
              label: '${state.treeOfThoughtBranches}',
              onChanged: (value) => state.setTreeOfThoughtBranches(value.toInt()),
            ),
            Text(
              'Number of alternative paths to explore at each step',
              style: TextStyles.caption.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAgentTypeSelector(DspyAgentBuilderState state, ThemeColors colors) {
    final types = [
      (DspyAgentType.react, 'ReAct', 'Reasoning + Action with tools', Icons.engineering),
      (DspyAgentType.reasoning, 'Reasoning', 'Deep thinking without tools', Icons.lightbulb_outline),
      (DspyAgentType.chat, 'Chat', 'Simple conversational agent', Icons.chat_bubble_outline),
      (DspyAgentType.rag, 'RAG', 'Document-based Q&A', Icons.article_outlined),
    ];

    return Wrap(
      spacing: SpacingTokens.md,
      runSpacing: SpacingTokens.md,
      children: types.map((type) {
        final isSelected = state.agentType == type.$1;
        return GestureDetector(
          onTap: () => state.setAgentType(type.$1),
          child: Container(
            width: 160,
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
              children: [
                Icon(
                  type.$4,
                  color: isSelected ? colors.primary : colors.onSurfaceVariant,
                  size: 32,
                ),
                const SizedBox(height: SpacingTokens.sm),
                Text(
                  type.$2,
                  style: TextStyles.bodyMedium.copyWith(
                    color: isSelected ? colors.primary : colors.onSurface,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: SpacingTokens.xs),
                Text(
                  type.$3,
                  style: TextStyles.caption.copyWith(color: colors.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildReasoningPatternSelector(DspyAgentBuilderState state, ThemeColors colors) {
    final patterns = [
      (DspyReasoningPattern.basic, 'Basic', 'Direct answer'),
      (DspyReasoningPattern.chainOfThought, 'Chain of Thought', 'Step-by-step reasoning'),
      (DspyReasoningPattern.treeOfThought, 'Tree of Thought', 'Explore multiple paths'),
    ];

    return Column(
      children: patterns.map((pattern) {
        final isSelected = state.reasoningPattern == pattern.$1;
        return RadioListTile<DspyReasoningPattern>(
          value: pattern.$1,
          groupValue: state.reasoningPattern,
          onChanged: (value) => state.setReasoningPattern(value!),
          title: Text(pattern.$2, style: TextStyles.bodyMedium.copyWith(color: colors.onSurface)),
          subtitle: Text(pattern.$3, style: TextStyles.caption.copyWith(color: colors.onSurfaceVariant)),
          activeColor: colors.primary,
          contentPadding: EdgeInsets.zero,
        );
      }).toList(),
    );
  }

  Widget _buildSystemPromptStep(DspyAgentBuilderState state, ThemeColors colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(SpacingTokens.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            'System Prompt',
            'Define your agent\'s behavior and personality',
            Icons.edit_note,
            colors,
          ),
          const SizedBox(height: SpacingTokens.xl),

          // System prompt field
          Text('System Prompt *', style: TextStyles.labelMedium.copyWith(color: colors.onSurface)),
          const SizedBox(height: SpacingTokens.sm),
          TextField(
            decoration: InputDecoration(
              hintText: 'You are a helpful assistant that...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(BorderRadiusTokens.md)),
              filled: true,
              fillColor: colors.surface,
            ),
            controller: TextEditingController(text: state.systemPrompt)
              ..selection = TextSelection.collapsed(offset: state.systemPrompt.length),
            onChanged: state.setSystemPrompt,
            maxLines: 8,
          ),
          const SizedBox(height: SpacingTokens.md),
          Text(
            'Tip: Be specific about the agent\'s role, expertise, and how it should respond.',
            style: TextStyles.caption.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: SpacingTokens.xl),

          // Personality field (optional)
          Text('Personality (optional)', style: TextStyles.labelMedium.copyWith(color: colors.onSurface)),
          const SizedBox(height: SpacingTokens.sm),
          TextField(
            decoration: InputDecoration(
              hintText: 'e.g., Professional and concise, Friendly and encouraging',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(BorderRadiusTokens.md)),
              filled: true,
              fillColor: colors.surface,
            ),
            controller: TextEditingController(text: state.personality)
              ..selection = TextSelection.collapsed(offset: state.personality.length),
            onChanged: state.setPersonality,
          ),

          // Validation errors
          if (state.getStepErrors(DspyBuilderStep.systemPrompt).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: SpacingTokens.md),
              child: Text(
                state.getStepErrors(DspyBuilderStep.systemPrompt).join('\n'),
                style: TextStyles.bodySmall.copyWith(color: colors.error),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToolsAndContextStep(DspyAgentBuilderState state, ThemeColors colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(SpacingTokens.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            'Tools & Context',
            'Give your agent capabilities and knowledge',
            Icons.build_outlined,
            colors,
          ),
          const SizedBox(height: SpacingTokens.xl),

          // Tool selector
          Text('Available Tools', style: TextStyles.labelMedium.copyWith(color: colors.onSurface)),
          const SizedBox(height: SpacingTokens.sm),
          if (state.agentType == DspyAgentType.chat)
            Text(
              'Chat agents don\'t use tools. Switch to ReAct for tool usage.',
              style: TextStyles.bodySmall.copyWith(color: colors.onSurfaceVariant, fontStyle: FontStyle.italic),
            )
          else
            Wrap(
              spacing: SpacingTokens.sm,
              runSpacing: SpacingTokens.sm,
              children: DspyTool.builtInTools.map((tool) {
                final isSelected = state.selectedToolIds.contains(tool.id);
                return FilterChip(
                  label: Text(tool.name),
                  selected: isSelected,
                  onSelected: (_) => state.toggleTool(tool.id),
                  avatar: Icon(
                    _getToolIcon(tool.id),
                    size: 18,
                    color: isSelected ? colors.onPrimary : colors.onSurfaceVariant,
                  ),
                  selectedColor: colors.primary,
                  checkmarkColor: colors.onPrimary,
                  labelStyle: TextStyles.bodySmall.copyWith(
                    color: isSelected ? colors.onPrimary : colors.onSurface,
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: SpacingTokens.xl),

          // Context documents section
          Text('Context Documents', style: TextStyles.labelMedium.copyWith(color: colors.onSurface)),
          const SizedBox(height: SpacingTokens.sm),
          Container(
            padding: const EdgeInsets.all(SpacingTokens.lg),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              children: [
                Icon(Icons.upload_file, size: 48, color: colors.onSurfaceVariant),
                const SizedBox(height: SpacingTokens.sm),
                Text(
                  'Drag documents here or click to upload',
                  style: TextStyles.bodyMedium.copyWith(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: SpacingTokens.md),
                AsmblButton.secondary(
                  text: 'Upload Documents',
                  icon: Icons.add,
                  onPressed: () {
                    // TODO: Implement document upload
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Document upload coming soon')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: SpacingTokens.sm),
          Text(
            'Documents will be processed for RAG-based question answering.',
            style: TextStyles.caption.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildModelSelectionStep(DspyAgentBuilderState state, ThemeColors colors) {
    final readyModels = ref.watch(readyModelConfigsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(SpacingTokens.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            'Model Selection',
            'Choose the AI model to power your agent',
            Icons.memory,
            colors,
          ),
          const SizedBox(height: SpacingTokens.xl),

          // Dynamic model selection from ModelConfigService
          Text('Available Models', style: TextStyles.labelMedium.copyWith(color: colors.onSurface)),
          const SizedBox(height: SpacingTokens.sm),

          if (readyModels.isEmpty)
            _buildNoModelsAvailable(colors)
          else
            _buildDynamicModelGrid(state, colors, readyModels),

          const SizedBox(height: SpacingTokens.xl),

          // Temperature slider
          Text('Temperature: ${state.temperature.toStringAsFixed(1)}',
              style: TextStyles.labelMedium.copyWith(color: colors.onSurface)),
          const SizedBox(height: SpacingTokens.sm),
          Slider(
            value: state.temperature,
            min: 0.0,
            max: 2.0,
            divisions: 20,
            label: state.temperature.toStringAsFixed(1),
            onChanged: state.setTemperature,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Precise', style: TextStyles.caption.copyWith(color: colors.onSurfaceVariant)),
              Text('Creative', style: TextStyles.caption.copyWith(color: colors.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: SpacingTokens.xl),

          // Max tokens slider
          Text('Max Tokens: ${state.maxTokens}',
              style: TextStyles.labelMedium.copyWith(color: colors.onSurface)),
          const SizedBox(height: SpacingTokens.sm),
          Slider(
            value: state.maxTokens.toDouble(),
            min: 256,
            max: 8192,
            divisions: 31,
            label: '${state.maxTokens}',
            onChanged: (value) => state.setMaxTokens(value.toInt()),
          ),
          Text(
            'Maximum length of agent responses',
            style: TextStyles.caption.copyWith(color: colors.onSurfaceVariant),
          ),

          // DSPy model string preview
          const SizedBox(height: SpacingTokens.xl),
          Container(
            padding: const EdgeInsets.all(SpacingTokens.md),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Icon(Icons.code, size: 20, color: colors.primary),
                const SizedBox(width: SpacingTokens.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('DSPy Model String', style: TextStyles.caption.copyWith(color: colors.onSurfaceVariant)),
                      Text(
                        state.dspyModelString,
                        style: TextStyles.bodyMedium.copyWith(
                          fontFamily: 'monospace',
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoModelsAvailable(ThemeColors colors) {
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
            'No Models Available',
            style: TextStyles.cardTitle.copyWith(color: colors.warning),
          ),
          const SizedBox(height: SpacingTokens.sm),
          Text(
            'Configure at least one model in Settings to continue.\n'
            'You can add API keys for cloud models or install local models via Ollama.',
            style: TextStyles.bodyMedium.copyWith(color: colors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicModelGrid(DspyAgentBuilderState state, ThemeColors colors, List<ModelConfig> models) {
    // Group models by local vs API
    final localModels = models.where((m) => m.isLocal).toList();
    final apiModels = models.where((m) => m.isApi).toList();

    // Group API models by provider
    final apiByProvider = <String, List<ModelConfig>>{};
    for (final model in apiModels) {
      apiByProvider.putIfAbsent(model.provider, () => []).add(model);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Local models
        if (localModels.isNotEmpty) ...[
          _buildModelProviderHeader('Ollama (Local)', colors, isLocal: true),
          Wrap(
            spacing: SpacingTokens.sm,
            runSpacing: SpacingTokens.sm,
            children: localModels.map((m) => _buildModelChip(state, colors, m)).toList(),
          ),
          const SizedBox(height: SpacingTokens.lg),
        ],

        // API models by provider
        ...apiByProvider.entries.map((entry) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildModelProviderHeader(entry.key, colors),
            Wrap(
              spacing: SpacingTokens.sm,
              runSpacing: SpacingTokens.sm,
              children: entry.value.map((m) => _buildModelChip(state, colors, m)).toList(),
            ),
            const SizedBox(height: SpacingTokens.lg),
          ],
        )),
      ],
    );
  }

  Widget _buildModelProviderHeader(String provider, ThemeColors colors, {bool isLocal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.sm),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.sm, vertical: 4),
            decoration: BoxDecoration(
              color: _getProviderColor(provider, isLocal).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              provider,
              style: TextStyles.bodySmall.copyWith(
                color: _getProviderColor(provider, isLocal),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (isLocal) ...[
            const SizedBox(width: SpacingTokens.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.xs, vertical: 2),
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
    );
  }

  Widget _buildModelChip(DspyAgentBuilderState state, ThemeColors colors, ModelConfig model) {
    final isSelected = state.modelId == model.model;

    return GestureDetector(
      onTap: () {
        // Update both provider and model ID
        final provider = model.isLocal ? 'local' : model.provider.toLowerCase();
        state.setModelProvider(provider);
        state.setModelId(model.model);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.md, vertical: SpacingTokens.sm),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary.withValues(alpha: 0.1) : colors.surface,
          borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
          border: Border.all(
            color: isSelected ? colors.primary : colors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Icon(Icons.check_circle, color: colors.primary, size: 16)
            else
              Icon(Icons.circle_outlined, color: colors.onSurfaceVariant, size: 16),
            const SizedBox(width: SpacingTokens.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  model.name,
                  style: TextStyles.bodyMedium.copyWith(
                    color: isSelected ? colors.primary : colors.onSurface,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                Text(
                  model.model,
                  style: TextStyles.caption.copyWith(
                    color: colors.onSurfaceVariant,
                    fontFamily: 'monospace',
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            if (model.isLocal && model.modelSize != null) ...[
              const SizedBox(width: SpacingTokens.sm),
              Text(
                model.displaySize,
                style: TextStyles.caption.copyWith(
                  color: colors.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
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

  Widget _buildReviewStep(DspyAgentBuilderState state, ThemeColors colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(SpacingTokens.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            'Review & Create',
            'Review your agent configuration before creating',
            Icons.check_circle_outline,
            colors,
          ),
          const SizedBox(height: SpacingTokens.xl),

          // Summary cards
          _buildReviewCard('Basic Info', [
            ('Name', state.name),
            ('Description', state.description.isNotEmpty ? state.description : '(none)'),
            ('Category', state.category),
          ], colors),

          _buildReviewCard('Agent Configuration', [
            ('Type', state.agentType.name.toUpperCase()),
            ('Reasoning Pattern', _getReasoningPatternName(state.reasoningPattern)),
            ('Max Iterations', '${state.maxIterations}'),
            if (state.reasoningPattern == DspyReasoningPattern.treeOfThought)
              ('Branches', '${state.treeOfThoughtBranches}'),
          ], colors),

          _buildReviewCard('Model', [
            ('Provider', state.modelProvider),
            ('Model', state.modelId),
            ('DSPy String', state.dspyModelString),
            ('Temperature', state.temperature.toStringAsFixed(1)),
            ('Max Tokens', '${state.maxTokens}'),
          ], colors),

          _buildReviewCard('Tools & Context', [
            ('Tools', state.selectedToolIds.isNotEmpty
                ? state.selectedToolIds.join(', ')
                : '(none)'),
            ('Documents', state.contextDocumentIds.isNotEmpty
                ? '${state.contextDocumentIds.length} documents'
                : '(none)'),
          ], colors),

          // Validation errors
          if (state.getAllValidationErrors().isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: SpacingTokens.lg),
              padding: const EdgeInsets.all(SpacingTokens.md),
              decoration: BoxDecoration(
                color: colors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
                border: Border.all(color: colors.error),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.error_outline, color: colors.error, size: 20),
                      const SizedBox(width: SpacingTokens.sm),
                      Text('Please fix the following:', style: TextStyles.bodyMedium.copyWith(color: colors.error)),
                    ],
                  ),
                  const SizedBox(height: SpacingTokens.sm),
                  ...state.getAllValidationErrors().map((error) => Padding(
                    padding: const EdgeInsets.only(left: SpacingTokens.lg),
                    child: Text('• $error', style: TextStyles.bodySmall.copyWith(color: colors.error)),
                  )),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ============ HELPERS ============

  Widget _buildStepHeader(String title, String subtitle, IconData icon, ThemeColors colors) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(SpacingTokens.sm),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
          ),
          child: Icon(icon, color: colors.primary, size: 28),
        ),
        const SizedBox(width: SpacingTokens.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyles.titleLarge.copyWith(color: colors.onSurface)),
              Text(subtitle, style: TextStyles.bodyMedium.copyWith(color: colors.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewCard(String title, List<(String, String)> items, ThemeColors colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: SpacingTokens.lg),
      padding: const EdgeInsets.all(SpacingTokens.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyles.cardTitle.copyWith(color: colors.primary)),
          const SizedBox(height: SpacingTokens.md),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: SpacingTokens.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: Text(item.$1, style: TextStyles.bodySmall.copyWith(color: colors.onSurfaceVariant)),
                ),
                Expanded(
                  child: Text(item.$2, style: TextStyles.bodyMedium.copyWith(color: colors.onSurface)),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  IconData _getToolIcon(String toolId) {
    switch (toolId) {
      case 'calculator':
        return Icons.calculate;
      case 'json_parser':
        return Icons.data_object;
      case 'web_search':
        return Icons.search;
      case 'code_executor':
        return Icons.code;
      default:
        return Icons.extension;
    }
  }

  String _getReasoningPatternName(DspyReasoningPattern pattern) {
    switch (pattern) {
      case DspyReasoningPattern.basic:
        return 'Basic';
      case DspyReasoningPattern.chainOfThought:
        return 'Chain of Thought';
      case DspyReasoningPattern.treeOfThought:
        return 'Tree of Thought';
    }
  }

  // ============ ACTIONS ============

  void _goToStep(DspyAgentBuilderState state, int index) {
    if (index <= state.currentStepIndex) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      state.setCurrentStep(DspyBuilderStep.values[index]);
    }
  }

  void _nextStep(DspyAgentBuilderState state) {
    if (state.nextStep()) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep(DspyAgentBuilderState state) {
    if (state.previousStep()) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _handleClose(DspyAgentBuilderState state) {
    if (state.name.isNotEmpty || state.systemPrompt.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard changes?'),
          content: const Text('You have unsaved changes. Are you sure you want to discard them?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                state.reset();
                context.go('/agents');
              },
              child: const Text('Discard'),
            ),
          ],
        ),
      );
    } else {
      state.reset();
      context.go('/agents');
    }
  }

  Future<void> _createAgent(DspyAgentBuilderState state) async {
    final errors = state.getAllValidationErrors();
    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fix errors: ${errors.join(', ')}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      if (!ServiceLocator.instance.isRegistered<AgentBusinessService>()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service not available. Please restart the app.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      final agentService = ServiceLocator.instance.get<AgentBusinessService>();
      final agentName = state.name;

      if (state.isEditing) {
        final agent = state.toAgent();
        final result = await agentService.updateAgent(agent: agent);
        if (result.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Agent "$agentName" updated successfully!')),
          );
        } else {
          throw Exception(result.error);
        }
      } else {
        // Use business service's createAgent method
        final dspyConfig = state.toDspyExecutionConfig();
        final result = await agentService.createAgent(
          name: state.name,
          description: state.description,
          capabilities: [state.category],
          modelId: state.dspyModelString,
          configuration: {
            'systemPrompt': state.systemPrompt,
            'personality': state.personality,
            'temperature': state.temperature,
            'maxTokens': state.maxTokens,
            ...dspyConfig,
          },
        );
        if (result.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Agent "$agentName" created successfully!')),
          );
        } else {
          throw Exception(result.error);
        }
      }

      state.reset();
      context.go('/agents');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating agent: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showTemplateSelector(DspyAgentBuilderState state, ThemeColors colors) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(BorderRadiusTokens.xl)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(SpacingTokens.lg),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.md),
                  Text(
                    'Choose a Template',
                    style: TextStyles.titleLarge.copyWith(color: colors.onSurface),
                  ),
                  Text(
                    'Start with a pre-configured agent',
                    style: TextStyles.bodyMedium.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(SpacingTokens.lg),
                children: DspyAgentBuilderState.templates.entries.map((entry) {
                  final template = entry.value;
                  return Card(
                    margin: const EdgeInsets.only(bottom: SpacingTokens.md),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: colors.primary.withValues(alpha: 0.1),
                        child: Icon(
                          _getTemplateIcon(entry.key),
                          color: colors.primary,
                        ),
                      ),
                      title: Text(template['name'] as String),
                      subtitle: Text(template['description'] as String),
                      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: colors.onSurfaceVariant),
                      onTap: () {
                        state.applyTemplate(entry.key);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Applied ${template['name']} template')),
                        );
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTemplateIcon(String templateId) {
    switch (templateId) {
      case 'business_analyst':
        return Icons.analytics;
      case 'design_assistant':
        return Icons.palette;
      case 'coding_agent':
        return Icons.code;
      case 'research_assistant':
        return Icons.science;
      default:
        return Icons.smart_toy;
    }
  }
}

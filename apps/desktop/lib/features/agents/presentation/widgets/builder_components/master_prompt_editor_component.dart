import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/design_system/design_system.dart';
import '../../../models/agent_builder_state.dart';
import '../../screens/agent_builder_screen.dart';

/// Master Prompt Editor Component - Dashboard-style prompt crafting with templates
class MasterPromptEditorComponent extends ConsumerStatefulWidget {
  const MasterPromptEditorComponent({super.key});

  @override
  ConsumerState<MasterPromptEditorComponent> createState() =>
      _MasterPromptEditorComponentState();
}

class _MasterPromptEditorComponentState
    extends ConsumerState<MasterPromptEditorComponent> {
  final _systemPromptController = TextEditingController();
  final _personalityController = TextEditingController();
  final _toneController = TextEditingController();
  final _expertiseController = TextEditingController();

  String _selectedTemplate = 'custom';

  // Enhanced template data with icons and categories
  final List<_PromptTemplate> _promptTemplates = [
    const _PromptTemplate(
      id: 'custom',
      name: 'Custom Prompt',
      description: 'Start from scratch with a custom prompt',
      icon: Icons.edit_note,
      category: 'General',
      prompt: '',
      color: Colors.grey,
    ),
    const _PromptTemplate(
      id: 'research_assistant',
      name: 'Research Assistant',
      description: 'Gather, analyze, and synthesize information',
      icon: Icons.search,
      category: 'Analysis',
      prompt: '''You are a highly capable research assistant specialized in gathering, analyzing, and synthesizing information from various sources.

Your core capabilities include:
- Conducting thorough research using available tools
- Analyzing data and identifying key insights
- Synthesizing complex information into clear summaries
- Fact-checking and verifying information accuracy
- Providing well-structured, evidence-based responses

Always cite your sources and be transparent about the limitations of your research.''',
      color: Colors.blue,
    ),
    const _PromptTemplate(
      id: 'code_reviewer',
      name: 'Code Reviewer',
      description: 'Review code for quality, security, and best practices',
      icon: Icons.rate_review,
      category: 'Development',
      prompt: '''You are an expert code reviewer with deep knowledge of software engineering best practices.

Your responsibilities include:
- Reviewing code for bugs, security issues, and performance problems
- Ensuring adherence to coding standards and conventions
- Suggesting improvements for maintainability and readability
- Providing constructive feedback with specific examples
- Identifying potential edge cases and error conditions

Focus on being thorough but constructive in your reviews.''',
      color: Colors.green,
    ),
    const _PromptTemplate(
      id: 'data_analyst',
      name: 'Data Analyst',
      description: 'Extract insights from complex datasets',
      icon: Icons.analytics,
      category: 'Analysis',
      prompt: '''You are a skilled data analyst who excels at extracting insights from complex datasets.

Your expertise covers:
- Data cleaning and preprocessing
- Statistical analysis and visualization
- Pattern recognition and trend identification
- Hypothesis testing and validation
- Clear communication of findings to stakeholders

Always explain your methodology and the reasoning behind your conclusions.''',
      color: Colors.purple,
    ),
    const _PromptTemplate(
      id: 'content_creator',
      name: 'Content Creator',
      description: 'Produce engaging, high-quality content',
      icon: Icons.create,
      category: 'Creative',
      prompt: '''You are a creative content specialist who produces engaging, high-quality content across various formats.

Your skills include:
- Writing compelling copy for different audiences
- Creating structured content outlines and strategies
- Adapting tone and style to match brand guidelines
- Optimizing content for specific platforms and purposes
- Ensuring accuracy and fact-checking all claims

Focus on creating valuable, original content that resonates with the target audience.''',
      color: Colors.orange,
    ),
    const _PromptTemplate(
      id: 'technical_writer',
      name: 'Technical Writer',
      description: 'Create clear, comprehensive documentation',
      icon: Icons.description,
      category: 'Documentation',
      prompt: '''You are a technical writer with expertise in creating clear, comprehensive documentation.

Your capabilities include:
- Writing API documentation and developer guides
- Creating user manuals and help systems
- Documenting processes and procedures
- Using plain language and accessibility principles
- Organizing information logically and clearly

Always prioritize clarity, accuracy, and user experience in documentation.''',
      color: Colors.teal,
    ),
    const _PromptTemplate(
      id: 'customer_support',
      name: 'Customer Support',
      description: 'Handle inquiries with empathy and efficiency',
      icon: Icons.support_agent,
      category: 'Support',
      prompt: '''You are a friendly and professional customer support specialist.

Your expertise includes:
- Active listening and empathetic communication
- Problem-solving and troubleshooting
- Providing accurate product and service information
- Resolving issues efficiently and professionally
- Maintaining positive customer relationships

Always be patient, understanding, and solution-focused in your interactions.''',
      color: Colors.amber,
    ),
    const _PromptTemplate(
      id: 'task_executor',
      name: 'Task Executor',
      description: 'Complete tasks efficiently using available tools',
      icon: Icons.task_alt,
      category: 'General',
      prompt: '''You are a helpful task agent that uses tools to complete tasks efficiently.

Your approach includes:
- Breaking down complex tasks into manageable steps
- Using available tools when needed
- Explaining your reasoning before taking action
- Validating results and handling errors gracefully
- Providing clear summaries of completed work

Focus on accuracy and thoroughness in task completion.''',
      color: Colors.indigo,
    ),
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final builderState = ref.read(agentBuilderStateProvider);
      _systemPromptController.text = builderState.systemPrompt;
      _personalityController.text = builderState.personality;
      _toneController.text = builderState.tone;
      _expertiseController.text = builderState.expertise;
    });
  }

  @override
  void dispose() {
    _systemPromptController.dispose();
    _personalityController.dispose();
    _toneController.dispose();
    _expertiseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ThemeColors(context);
    final builderState = ref.watch(agentBuilderStateProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero section
          _buildHeroSection(colors),

          const SizedBox(height: SpacingTokens.xl),

          // Main content - responsive layout
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 1000) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left column - Templates + Personality
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          _buildTemplatePickerCard(colors),
                          const SizedBox(height: SpacingTokens.lg),
                          _buildPersonalityCard(builderState, colors),
                        ],
                      ),
                    ),
                    const SizedBox(width: SpacingTokens.lg),
                    // Right column - Prompt Editor
                    Expanded(
                      flex: 3,
                      child: _buildPromptEditorCard(builderState, colors),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildTemplatePickerCard(colors),
                    const SizedBox(height: SpacingTokens.lg),
                    _buildPromptEditorCard(builderState, colors),
                    const SizedBox(height: SpacingTokens.lg),
                    _buildPersonalityCard(builderState, colors),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(ThemeColors colors) {
    final selectedTemplate = _promptTemplates.firstWhere(
      (t) => t.id == _selectedTemplate,
      orElse: () => _promptTemplates.first,
    );

    return Container(
      padding: const EdgeInsets.all(SpacingTokens.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary.withValues(alpha: 0.1),
            colors.accent.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(BorderRadiusTokens.xl),
        border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(SpacingTokens.sm),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.15),
                        borderRadius:
                            BorderRadius.circular(BorderRadiusTokens.md),
                      ),
                      child: Icon(
                        Icons.edit_note,
                        color: colors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: SpacingTokens.md),
                    Text(
                      'Master Prompt Configuration',
                      style: TextStyles.pageTitle.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SpacingTokens.sm),
                Text(
                  'Define your agent\'s behavior, personality, and core instructions. Choose a template or craft a custom prompt.',
                  style: TextStyles.bodyMedium.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: SpacingTokens.xl),
          // Quick stats
          Row(
            children: [
              _buildQuickStat(
                colors,
                icon: Icons.text_snippet,
                label: 'Templates',
                value: '${_promptTemplates.length}',
                color: colors.primary,
              ),
              const SizedBox(width: SpacingTokens.lg),
              _buildQuickStat(
                colors,
                icon: Icons.text_fields,
                label: 'Characters',
                value: '${_systemPromptController.text.length}',
                color: colors.success,
              ),
              const SizedBox(width: SpacingTokens.lg),
              _buildQuickStat(
                colors,
                icon: Icons.category,
                label: 'Using',
                value: selectedTemplate.name.split(' ').first,
                color: Color(selectedTemplate.color.value),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(
    ThemeColors colors, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.md,
        vertical: SpacingTokens.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: SpacingTokens.xs),
          Text(
            value,
            style: TextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.onSurface,
            ),
          ),
          Text(
            label,
            style: TextStyles.caption.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplatePickerCard(ThemeColors colors) {
    // Group templates by category
    final categories = <String, List<_PromptTemplate>>{};
    for (final template in _promptTemplates) {
      categories.putIfAbsent(template.category, () => []).add(template);
    }

    return Container(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BorderRadiusTokens.xl),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.onSurface.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dashboard, color: colors.primary, size: 20),
              const SizedBox(width: SpacingTokens.sm),
              Text(
                'Prompt Templates',
                style: TextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.sm,
                  vertical: SpacingTokens.xs,
                ),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
                ),
                child: Text(
                  '${_promptTemplates.length} available',
                  style: TextStyles.caption.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.md),

          // Template grid by category
          ...categories.entries.map((entry) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: SpacingTokens.sm),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 16,
                        decoration: BoxDecoration(
                          color: _getCategoryColor(entry.key, colors),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: SpacingTokens.sm),
                      Text(
                        entry.key,
                        style: TextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(width: SpacingTokens.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: SpacingTokens.xs,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceVariant,
                          borderRadius:
                              BorderRadius.circular(BorderRadiusTokens.xs),
                        ),
                        child: Text(
                          '${entry.value.length}',
                          style: TextStyles.caption.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: SpacingTokens.sm,
                  runSpacing: SpacingTokens.sm,
                  children: entry.value
                      .map((template) => _buildTemplateCard(colors, template))
                      .toList(),
                ),
                const SizedBox(height: SpacingTokens.md),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTemplateCard(ThemeColors colors, _PromptTemplate template) {
    final isSelected = _selectedTemplate == template.id;
    final templateColor = Color(template.color.value);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTemplate = template.id;
            if (template.id != 'custom') {
              _systemPromptController.text = template.prompt;
              ref
                  .read(agentBuilderStateProvider)
                  .updateSystemPrompt(template.prompt);
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 160,
          padding: const EdgeInsets.all(SpacingTokens.md),
          decoration: BoxDecoration(
            color:
                isSelected ? templateColor.withValues(alpha: 0.1) : colors.surface,
            borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
            border: Border.all(
              color: isSelected ? templateColor : colors.border,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: templateColor.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(SpacingTokens.xs),
                    decoration: BoxDecoration(
                      color: templateColor.withValues(alpha: 0.15),
                      borderRadius:
                          BorderRadius.circular(BorderRadiusTokens.sm),
                    ),
                    child: Icon(
                      template.icon,
                      size: 18,
                      color: templateColor,
                    ),
                  ),
                  const Spacer(),
                  if (isSelected)
                    Icon(
                      Icons.check_circle,
                      size: 18,
                      color: templateColor,
                    ),
                ],
              ),
              const SizedBox(height: SpacingTokens.sm),
              Text(
                template.name,
                style: TextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: SpacingTokens.xxs),
              Text(
                template.description,
                style: TextStyles.caption.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalityCard(
      AgentBuilderState builderState, ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BorderRadiusTokens.xl),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.onSurface.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology, color: colors.accent, size: 20),
              const SizedBox(width: SpacingTokens.sm),
              Text(
                'Personality & Tone',
                style: TextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.sm),
          Text(
            'Fine-tune how your agent communicates and presents itself.',
            style: TextStyles.bodySmall.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: SpacingTokens.lg),

          // Personality traits with icons
          _buildPersonalityField(
            icon: Icons.person,
            label: 'Personality',
            controller: _personalityController,
            hint: 'e.g., Professional, Friendly, Analytical',
            onChanged: builderState.updatePersonality,
            colors: colors,
          ),

          const SizedBox(height: SpacingTokens.md),

          _buildPersonalityField(
            icon: Icons.record_voice_over,
            label: 'Tone',
            controller: _toneController,
            hint: 'e.g., Conversational, Formal, Enthusiastic',
            onChanged: builderState.updateTone,
            colors: colors,
          ),

          const SizedBox(height: SpacingTokens.md),

          _buildPersonalityField(
            icon: Icons.school,
            label: 'Expertise Level',
            controller: _expertiseController,
            hint: 'e.g., Expert, Beginner-friendly, Academic',
            onChanged: builderState.updateExpertise,
            colors: colors,
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalityField({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required String hint,
    required Function(String) onChanged,
    required ThemeColors colors,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: colors.onSurfaceVariant),
            const SizedBox(width: SpacingTokens.xs),
            Text(
              label,
              style: TextStyles.bodySmall.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: SpacingTokens.xs),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
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
            fillColor: colors.inputBackground,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.md,
              vertical: SpacingTokens.sm,
            ),
          ),
          style: TextStyles.bodySmall.copyWith(color: colors.onSurface),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildPromptEditorCard(
      AgentBuilderState builderState, ThemeColors colors) {
    final selectedTemplate = _promptTemplates.firstWhere(
      (t) => t.id == _selectedTemplate,
      orElse: () => _promptTemplates.first,
    );

    return Container(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BorderRadiusTokens.xl),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.onSurface.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.code, color: colors.primary, size: 20),
              const SizedBox(width: SpacingTokens.sm),
              Text(
                'System Prompt',
                style: TextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              // Character count badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.sm,
                  vertical: SpacingTokens.xs,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.text_fields,
                        size: 14, color: colors.onSurfaceVariant),
                    const SizedBox(width: SpacingTokens.xs),
                    Text(
                      '${_systemPromptController.text.length} chars',
                      style: TextStyles.caption.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: SpacingTokens.md),

          // Selected template indicator
          if (_selectedTemplate != 'custom')
            Container(
              padding: const EdgeInsets.all(SpacingTokens.md),
              margin: const EdgeInsets.only(bottom: SpacingTokens.md),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(selectedTemplate.color.value).withValues(alpha: 0.1),
                    Color(selectedTemplate.color.value).withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
                border: Border.all(
                    color: Color(selectedTemplate.color.value)
                        .withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(SpacingTokens.sm),
                    decoration: BoxDecoration(
                      color: Color(selectedTemplate.color.value)
                          .withValues(alpha: 0.15),
                      borderRadius:
                          BorderRadius.circular(BorderRadiusTokens.sm),
                    ),
                    child: Icon(
                      selectedTemplate.icon,
                      color: Color(selectedTemplate.color.value),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: SpacingTokens.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Using Template',
                          style: TextStyles.caption.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          selectedTemplate.name,
                          style: TextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close,
                        size: 18, color: colors.onSurfaceVariant),
                    onPressed: () {
                      setState(() {
                        _selectedTemplate = 'custom';
                      });
                    },
                    tooltip: 'Switch to custom',
                  ),
                ],
              ),
            ),

          // Prompt editor
          Container(
            height: 350,
            decoration: BoxDecoration(
              border: Border.all(color: colors.border),
              borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
              color: colors.inputBackground,
            ),
            child: TextField(
              controller: _systemPromptController,
              maxLines: null,
              expands: true,
              decoration: const InputDecoration(
                hintText:
                    'Define your agent\'s core behavior, capabilities, and instructions...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(SpacingTokens.md),
              ),
              style: TextStyles.bodyMedium.copyWith(
                color: colors.onSurface,
                fontFamily: 'monospace',
                height: 1.5,
              ),
              onChanged: (value) {
                builderState.updateSystemPrompt(value);
                setState(() {}); // Update character count
              },
            ),
          ),

          const SizedBox(height: SpacingTokens.md),

          // Prompt tips
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
                    Icon(Icons.lightbulb_outline, color: colors.accent, size: 16),
                    const SizedBox(width: SpacingTokens.xs),
                    Text(
                      'Prompt Writing Tips',
                      style: TextStyles.bodySmall.copyWith(
                        color: colors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SpacingTokens.sm),
                Wrap(
                  spacing: SpacingTokens.md,
                  runSpacing: SpacingTokens.xs,
                  children: [
                    _buildTipChip(colors, 'Be specific about role'),
                    _buildTipChip(colors, 'Include examples'),
                    _buildTipChip(colors, 'Define edge cases'),
                    _buildTipChip(colors, 'Specify response format'),
                  ],
                ),
              ],
            ),
          ),

          if (builderState
                  .validationErrors[AgentBuilderStep.masterPrompt]?.isNotEmpty ==
              true)
            _buildValidationErrors(builderState, colors),
        ],
      ),
    );
  }

  Widget _buildTipChip(ThemeColors colors, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.sm,
        vertical: SpacingTokens.xs,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 12, color: colors.success),
          const SizedBox(width: SpacingTokens.xs),
          Text(
            text,
            style: TextStyles.caption.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValidationErrors(
      AgentBuilderState builderState, ThemeColors colors) {
    final errors =
        builderState.validationErrors[AgentBuilderStep.masterPrompt] ?? [];

    return Container(
      margin: const EdgeInsets.only(top: SpacingTokens.md),
      padding: const EdgeInsets.all(SpacingTokens.md),
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
        border: Border.all(color: colors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: colors.error, size: 20),
              const SizedBox(width: SpacingTokens.sm),
              Text(
                'Please fix the following:',
                style: TextStyles.bodySmall.copyWith(
                  color: colors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.xs),
          ...errors.map((error) => Padding(
                padding: const EdgeInsets.only(left: SpacingTokens.lg),
                child: Text(
                  '• $error',
                  style: TextStyles.bodySmall.copyWith(color: colors.error),
                ),
              )),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category, ThemeColors colors) {
    switch (category.toLowerCase()) {
      case 'general':
        return colors.primary;
      case 'analysis':
        return colors.info;
      case 'development':
        return colors.success;
      case 'creative':
        return colors.accent;
      case 'documentation':
        return colors.warning;
      case 'support':
        return Colors.amber;
      default:
        return colors.primary;
    }
  }
}

/// Data class for prompt templates
class _PromptTemplate {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final String category;
  final String prompt;
  final Color color;

  const _PromptTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
    required this.prompt,
    required this.color,
  });
}

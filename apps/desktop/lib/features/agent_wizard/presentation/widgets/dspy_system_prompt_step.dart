import 'package:flutter/material.dart';
import '../../../../core/design_system/design_system.dart';
import '../../models/dspy_agent_wizard_state.dart';

/// Step 4: System Prompt
///
/// Configure the master system prompt that defines agent behavior.
class DspySystemPromptStep extends StatefulWidget {
  final DspyAgentWizardState wizardState;
  final VoidCallback onChanged;

  const DspySystemPromptStep({
    super.key,
    required this.wizardState,
    required this.onChanged,
  });

  @override
  State<DspySystemPromptStep> createState() => _DspySystemPromptStepState();
}

class _DspySystemPromptStepState extends State<DspySystemPromptStep> {
  late TextEditingController _promptController;
  String? _selectedTemplate;

  // Prompt templates
  static const _templates = {
    'research': _PromptTemplate(
      name: 'Research Assistant',
      icon: Icons.science,
      prompt: '''You are a meticulous research assistant. Your role is to:
- Find accurate, well-sourced information
- Synthesize findings into clear summaries
- Always cite your sources
- Acknowledge uncertainty when appropriate
- Ask clarifying questions when needed''',
    ),
    'code': _PromptTemplate(
      name: 'Code Assistant',
      icon: Icons.code,
      prompt: '''You are an expert software engineer. Your role is to:
- Write clean, maintainable code
- Follow best practices and design patterns
- Explain your reasoning and approach
- Consider edge cases and error handling
- Suggest improvements when appropriate''',
    ),
    'analyst': _PromptTemplate(
      name: 'Data Analyst',
      icon: Icons.analytics,
      prompt: '''You are a data analyst expert. Your role is to:
- Analyze data with statistical rigor
- Identify patterns and insights
- Present findings clearly with visualizations
- Recommend data-driven decisions
- Validate assumptions and methodology''',
    ),
    'writer': _PromptTemplate(
      name: 'Content Writer',
      icon: Icons.edit_note,
      prompt: '''You are a skilled content writer. Your role is to:
- Create engaging, well-structured content
- Adapt tone and style to the audience
- Research topics thoroughly before writing
- Optimize for clarity and readability
- Follow brand guidelines and best practices''',
    ),
    'support': _PromptTemplate(
      name: 'Customer Support',
      icon: Icons.support_agent,
      prompt: '''You are a helpful customer support agent. Your role is to:
- Respond with empathy and professionalism
- Resolve issues efficiently and thoroughly
- Escalate complex issues appropriately
- Follow up to ensure satisfaction
- Document interactions clearly''',
    ),
    'custom': _PromptTemplate(
      name: 'Custom',
      icon: Icons.tune,
      prompt: '',
    ),
  };

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController(text: widget.wizardState.systemPrompt);
    _promptController.addListener(_onPromptChanged);

    // Detect if current prompt matches a template
    _selectedTemplate = _detectTemplate(widget.wizardState.systemPrompt);
  }

  @override
  void dispose() {
    _promptController.removeListener(_onPromptChanged);
    _promptController.dispose();
    super.dispose();
  }

  void _onPromptChanged() {
    widget.wizardState.setSystemPrompt(_promptController.text);
    widget.onChanged();
  }

  String? _detectTemplate(String prompt) {
    if (prompt.isEmpty) return null;
    for (final entry in _templates.entries) {
      if (entry.value.prompt == prompt) {
        return entry.key;
      }
    }
    return 'custom';
  }

  void _selectTemplate(String key) {
    setState(() {
      _selectedTemplate = key;
      if (key != 'custom') {
        _promptController.text = _templates[key]!.prompt;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = ThemeColors(context);

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
              _buildTemplates(context, colors),
              const SizedBox(height: SpacingTokens.xxl),
              _buildPromptEditor(context, colors),
              const SizedBox(height: SpacingTokens.lg),
              _buildTips(context, colors),
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
        Text('System Prompt', style: TextStyles.pageTitle),
        const SizedBox(height: SpacingTokens.sm),
        Text(
          'Define how your agent should behave. The system prompt sets the personality, expertise, and boundaries for your AI agent.',
          style: TextStyles.bodyMedium.copyWith(
            color: ThemeColors(context).onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildTemplates(BuildContext context, ThemeColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_fix_high, color: colors.primary, size: 20),
            const SizedBox(width: SpacingTokens.sm),
            Text('Quick Start Templates', style: TextStyles.cardTitle),
          ],
        ),
        const SizedBox(height: SpacingTokens.md),
        Wrap(
          spacing: SpacingTokens.sm,
          runSpacing: SpacingTokens.sm,
          children: _templates.entries.map((entry) {
            final isSelected = _selectedTemplate == entry.key;
            return _buildTemplateChip(
              context,
              colors,
              entry.key,
              entry.value,
              isSelected,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTemplateChip(
    BuildContext context,
    ThemeColors colors,
    String key,
    _PromptTemplate template,
    bool isSelected,
  ) {
    return Material(
      color: isSelected ? colors.primary.withValues(alpha: 0.1) : colors.surface,
      borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
      child: InkWell(
        onTap: () => _selectTemplate(key),
        borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.md,
            vertical: SpacingTokens.sm,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? colors.primary : colors.border,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                template.icon,
                size: 18,
                color: isSelected ? colors.primary : colors.onSurfaceVariant,
              ),
              const SizedBox(width: SpacingTokens.sm),
              Text(
                template.name,
                style: TextStyles.bodyMedium.copyWith(
                  color: isSelected ? colors.primary : colors.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromptEditor(BuildContext context, ThemeColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.psychology, color: colors.primary, size: 20),
            const SizedBox(width: SpacingTokens.sm),
            Text('Master Prompt', style: TextStyles.cardTitle),
            const Spacer(),
            Text(
              '${_promptController.text.length} characters',
              style: TextStyles.caption.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: SpacingTokens.md),
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
          ),
          child: TextField(
            controller: _promptController,
            maxLines: 12,
            style: TextStyles.bodyMedium.copyWith(
              color: colors.onSurface,
              height: 1.5,
            ),
            decoration: InputDecoration(
              hintText: 'Describe your agent\'s role, expertise, and behavior...',
              hintStyle: TextStyles.bodyMedium.copyWith(
                color: colors.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(SpacingTokens.lg),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTips(BuildContext context, ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.md),
      decoration: BoxDecoration(
        color: colors.info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
        border: Border.all(color: colors.info.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: colors.info, size: 18),
              const SizedBox(width: SpacingTokens.sm),
              Text(
                'Tips for effective prompts',
                style: TextStyles.labelMedium.copyWith(color: colors.info),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.sm),
          Text(
            '- Be specific about the agent\'s role and expertise\n'
            '- Define clear boundaries and limitations\n'
            '- Include examples of desired behavior\n'
            '- Specify the tone and communication style\n'
            '- Add guidelines for handling edge cases',
            style: TextStyles.bodySmall.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _PromptTemplate {
  final String name;
  final IconData icon;
  final String prompt;

  const _PromptTemplate({
    required this.name,
    required this.icon,
    required this.prompt,
  });
}

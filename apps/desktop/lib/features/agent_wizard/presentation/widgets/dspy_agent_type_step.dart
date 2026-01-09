import 'package:flutter/material.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/models/dspy_types.dart';
import '../../models/dspy_agent_wizard_state.dart';

/// Step 2: Agent Type Selection
///
/// Select between DSPy agent types:
/// - ReAct Agent (tool-using)
/// - Code Agent (code generation)
/// - Reasoning Agent (pure reasoning)
///
/// And reasoning patterns:
/// - Basic
/// - Chain of Thought
/// - Tree of Thought
class DspyAgentTypeStep extends StatelessWidget {
  final DspyAgentWizardState wizardState;
  final VoidCallback onChanged;

  const DspyAgentTypeStep({
    super.key,
    required this.wizardState,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
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
              _buildAgentTypeSection(context),
              const SizedBox(height: SpacingTokens.xxl),
              _buildReasoningPatternSection(context),
              const SizedBox(height: SpacingTokens.lg),
              _buildInfoBox(context),
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
        Text('Agent Type', style: TextStyles.pageTitle),
        const SizedBox(height: SpacingTokens.sm),
        Text(
          'Choose how your agent will work. Different types are best for different tasks.',
          style: TextStyles.bodyMedium.copyWith(
            color: ThemeColors(context).onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildAgentTypeSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.smart_toy, color: ThemeColors(context).primary, size: 20),
            const SizedBox(width: SpacingTokens.sm),
            Text('Agent Type', style: TextStyles.cardTitle),
          ],
        ),
        const SizedBox(height: SpacingTokens.md),
        ...DspyAgentType.values.map((type) => _buildAgentTypeCard(context, type)),
      ],
    );
  }

  Widget _buildAgentTypeCard(BuildContext context, DspyAgentType type) {
    final isSelected = wizardState.agentType == type;
    final colors = ThemeColors(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.sm),
      child: InkWell(
        onTap: () {
          wizardState.setAgentType(type);
          onChanged();
        },
        borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
        child: Container(
          padding: const EdgeInsets.all(SpacingTokens.md),
          decoration: BoxDecoration(
            color: isSelected ? colors.primary.withValues(alpha: 0.1) : colors.surface,
            border: Border.all(
              color: isSelected ? colors.primary : colors.border,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getTypeColor(type).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
                ),
                child: Icon(
                  _getTypeIcon(type),
                  color: _getTypeColor(type),
                  size: 24,
                ),
              ),
              const SizedBox(width: SpacingTokens.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.displayName,
                      style: TextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      type.description,
                      style: TextStyles.bodySmall.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      type.details,
                      style: TextStyles.bodySmall.copyWith(
                        color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: colors.primary, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReasoningPatternSection(BuildContext context) {
    // Only show reasoning pattern for non-react agents or as additional config
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.psychology, color: ThemeColors(context).primary, size: 20),
            const SizedBox(width: SpacingTokens.sm),
            Text('Thinking Style', style: TextStyles.cardTitle),
          ],
        ),
        const SizedBox(height: SpacingTokens.sm),
        Text(
          'How carefully your agent thinks before responding',
          style: TextStyles.bodySmall.copyWith(
            color: ThemeColors(context).onSurfaceVariant,
          ),
        ),
        const SizedBox(height: SpacingTokens.md),
        Wrap(
          spacing: SpacingTokens.sm,
          runSpacing: SpacingTokens.sm,
          children: DspyReasoningPattern.values
              .map((pattern) => _buildPatternChip(context, pattern))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildPatternChip(BuildContext context, DspyReasoningPattern pattern) {
    final isSelected = wizardState.reasoningPattern == pattern;
    final colors = ThemeColors(context);

    return InkWell(
      onTap: () {
        wizardState.setReasoningPattern(pattern);
        onChanged();
      },
      borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.md,
          vertical: SpacingTokens.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary : colors.surface,
          border: Border.all(
            color: isSelected ? colors.primary : colors.border,
          ),
          borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getPatternIcon(pattern),
                  size: 16,
                  color: isSelected ? colors.onPrimary : colors.onSurface,
                ),
                const SizedBox(width: SpacingTokens.xs),
                Text(
                  pattern.displayName,
                  style: TextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isSelected ? colors.onPrimary : colors.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              pattern.description,
              style: TextStyles.bodySmall.copyWith(
                fontSize: 11,
                color: isSelected
                    ? colors.onPrimary.withValues(alpha: 0.8)
                    : colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBox(BuildContext context) {
    final colors = ThemeColors(context);
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.md),
      decoration: BoxDecoration(
        color: colors.info.withValues(alpha: 0.1),
        border: Border.all(color: colors.info.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline, color: colors.info, size: 20),
          const SizedBox(width: SpacingTokens.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Which type should I choose?',
                  style: TextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.info,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '• Task Agent: Best for most use cases - can browse, search, and use tools\n'
                  '• Code Agent: Specialized for writing and reviewing code\n'
                  '• Thinking Agent: For analysis, planning, and complex reasoning',
                  style: TextStyles.bodySmall.copyWith(
                    color: colors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(DspyAgentType type) {
    switch (type) {
      case DspyAgentType.react:
        return Colors.deepOrange;
      case DspyAgentType.code:
        return Colors.blueGrey;
      case DspyAgentType.reasoning:
        return Colors.purple;
    }
  }

  IconData _getTypeIcon(DspyAgentType type) {
    switch (type) {
      case DspyAgentType.react:
        return Icons.smart_toy;
      case DspyAgentType.code:
        return Icons.code;
      case DspyAgentType.reasoning:
        return Icons.psychology;
    }
  }

  IconData _getPatternIcon(DspyReasoningPattern pattern) {
    switch (pattern) {
      case DspyReasoningPattern.basic:
        return Icons.flash_on;
      case DspyReasoningPattern.chainOfThought:
        return Icons.format_list_numbered;
      case DspyReasoningPattern.treeOfThought:
        return Icons.account_tree;
    }
  }
}

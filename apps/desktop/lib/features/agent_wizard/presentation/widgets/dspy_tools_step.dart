import 'package:flutter/material.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/models/dspy_types.dart';
import '../../models/dspy_agent_wizard_state.dart';

/// Step 4: Tools & Capabilities
///
/// Configure the tools and settings available to the agent.
class DspyToolsStep extends StatelessWidget {
  final DspyAgentWizardState wizardState;
  final VoidCallback onChanged;

  const DspyToolsStep({
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
              if (wizardState.agentType == DspyAgentType.react) ...[
                _buildBuiltinTools(context),
                const SizedBox(height: SpacingTokens.xxl),
              ],
              _buildAgentParameters(context),
              const SizedBox(height: SpacingTokens.lg),
              _buildValidationStatus(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colors = ThemeColors(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tools & Capabilities', style: TextStyles.pageTitle),
        const SizedBox(height: SpacingTokens.sm),
        Text(
          wizardState.agentType == DspyAgentType.react
              ? 'Add tools and configure how your agent works.'
              : wizardState.agentType == DspyAgentType.code
                  ? 'Configure how your code agent works.'
                  : 'Configure how your agent thinks.',
          style: TextStyles.bodyMedium.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildBuiltinTools(BuildContext context) {
    final colors = ThemeColors(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.build, color: colors.primary, size: 20),
            const SizedBox(width: SpacingTokens.sm),
            Text('Built-in Tools', style: TextStyles.cardTitle),
          ],
        ),
        const SizedBox(height: SpacingTokens.sm),
        Text(
          'Enable capabilities your agent can use',
          style: TextStyles.bodySmall.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: SpacingTokens.md),
        _buildToolCard(
          context,
          tool: DspyBuiltinTools.calculator,
          icon: Icons.calculate,
          isSelected: wizardState.selectedTools
              .any((t) => t.name == 'calculator'),
        ),
        const SizedBox(height: SpacingTokens.sm),
        _buildToolCard(
          context,
          tool: DspyBuiltinTools.jsonParser,
          icon: Icons.data_object,
          isSelected: wizardState.selectedTools
              .any((t) => t.name == 'json_parser'),
        ),
      ],
    );
  }

  Widget _buildToolCard(
    BuildContext context, {
    required DspyTool tool,
    required IconData icon,
    required bool isSelected,
  }) {
    final colors = ThemeColors(context);

    return InkWell(
      onTap: () {
        if (isSelected) {
          wizardState.removeTool(tool.name);
        } else {
          wizardState.addTool(tool);
        }
        onChanged();
      },
      borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
      child: Container(
        padding: const EdgeInsets.all(SpacingTokens.md),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primary.withValues(alpha: 0.1)
              : colors.surface,
          border: Border.all(
            color: isSelected ? colors.primary : colors.border,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? colors.primary.withValues(alpha: 0.2)
                    : colors.surfaceVariant,
                borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
              ),
              child: Icon(
                icon,
                color: isSelected ? colors.primary : colors.onSurfaceVariant,
                size: 20,
              ),
            ),
            const SizedBox(width: SpacingTokens.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tool.name,
                    style: TextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tool.description,
                    style: TextStyles.bodySmall.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Checkbox(
              value: isSelected,
              onChanged: (value) {
                if (value == true) {
                  wizardState.addTool(tool);
                } else {
                  wizardState.removeTool(tool.name);
                }
                onChanged();
              },
              activeColor: colors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgentParameters(BuildContext context) {
    final colors = ThemeColors(context);

    return AsmblCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings, color: colors.primary, size: 20),
              const SizedBox(width: SpacingTokens.sm),
              Text('Behavior Settings', style: TextStyles.cardTitle),
            ],
          ),
          const SizedBox(height: SpacingTokens.sm),
          Text(
            'Configure how the agent operates',
            style: TextStyles.bodySmall.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: SpacingTokens.lg),

          // Max Iterations (for ReAct agents)
          if (wizardState.agentType == DspyAgentType.react) ...[
            _buildSliderParameter(
              context,
              label: 'Maximum Steps',
              description:
                  'How many attempts the agent gets to complete a task',
              value: wizardState.maxIterations.toDouble(),
              min: 1,
              max: 20,
              divisions: 19,
              displayValue: _getStepsLabel(wizardState.maxIterations),
              onChanged: (value) {
                wizardState.setMaxIterations(value.round());
                onChanged();
              },
            ),
            const SizedBox(height: SpacingTokens.lg),
          ],

          // Num Branches (for Tree of Thought)
          if (wizardState.reasoningPattern ==
              DspyReasoningPattern.treeOfThought) ...[
            _buildSliderParameter(
              context,
              label: 'Exploration Paths',
              description: 'How many different approaches to consider before answering',
              value: wizardState.numBranches.toDouble(),
              min: 2,
              max: 5,
              divisions: 3,
              displayValue: _getBranchesLabel(wizardState.numBranches),
              onChanged: (value) {
                wizardState.setNumBranches(value.round());
                onChanged();
              },
            ),
            const SizedBox(height: SpacingTokens.lg),
          ],

          // Confidence threshold (for decision routing)
          _buildSliderParameter(
            context,
            label: 'Answer Quality',
            description:
                'How confident the agent should be before giving an answer',
            value: wizardState.minConfidence,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            displayValue: _getConfidenceLabel(wizardState.minConfidence),
            onChanged: (value) {
              wizardState.setMinConfidence(value);
              onChanged();
            },
          ),
          const SizedBox(height: SpacingTokens.lg),
          _buildConfidenceExplanation(context),
        ],
      ),
    );
  }

  Widget _buildConfidenceExplanation(BuildContext context) {
    final colors = ThemeColors(context);
    final confidence = wizardState.minConfidence;

    return Container(
      padding: const EdgeInsets.all(SpacingTokens.md),
      decoration: BoxDecoration(
        color: colors.info.withValues(alpha: 0.1),
        border: Border.all(color: colors.info.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user, color: colors.info, size: 18),
              const SizedBox(width: SpacingTokens.sm),
              Text(
                'Human Verification',
                style: TextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.info,
                ),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.sm),
          Text(
            _getHumanVerificationExplanation(confidence),
            style: TextStyles.bodySmall.copyWith(
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: SpacingTokens.md),
          _buildConfidenceLevelIndicators(context),
        ],
      ),
    );
  }

  Widget _buildConfidenceLevelIndicators(BuildContext context) {
    final colors = ThemeColors(context);
    final confidence = wizardState.minConfidence;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What this means:',
          style: TextStyles.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: SpacingTokens.sm),
        _buildLevelRow(
          context,
          icon: Icons.speed,
          label: 'Relaxed (0-39%)',
          description: 'Agent acts quickly with minimal hesitation',
          isActive: confidence < 0.4,
          color: Colors.green,
        ),
        const SizedBox(height: SpacingTokens.xs),
        _buildLevelRow(
          context,
          icon: Icons.balance,
          label: 'Moderate (40-59%)',
          description: 'Balanced speed and accuracy',
          isActive: confidence >= 0.4 && confidence < 0.6,
          color: Colors.blue,
        ),
        const SizedBox(height: SpacingTokens.xs),
        _buildLevelRow(
          context,
          icon: Icons.security,
          label: 'Careful (60-79%)',
          description: 'May request human review for uncertain tasks',
          isActive: confidence >= 0.6 && confidence < 0.8,
          color: Colors.orange,
        ),
        const SizedBox(height: SpacingTokens.xs),
        _buildLevelRow(
          context,
          icon: Icons.verified,
          label: 'Strict (80-100%)',
          description: 'Frequently asks for human verification',
          isActive: confidence >= 0.8,
          color: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildLevelRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String description,
    required bool isActive,
    required Color color,
  }) {
    final colors = ThemeColors(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.sm,
        vertical: SpacingTokens.xs,
      ),
      decoration: BoxDecoration(
        color: isActive ? color.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
        border: isActive ? Border.all(color: color.withValues(alpha: 0.4)) : null,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: isActive ? color : colors.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(width: SpacingTokens.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyles.bodySmall.copyWith(
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    color: isActive ? color : colors.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  description,
                  style: TextStyles.bodySmall.copyWith(
                    fontSize: 11,
                    color: isActive ? colors.onSurface : colors.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          if (isActive)
            Icon(Icons.check_circle, size: 16, color: color),
        ],
      ),
    );
  }

  String _getHumanVerificationExplanation(double confidence) {
    if (confidence < 0.4) {
      return 'Your agent will work independently and make decisions quickly. '
          'It will rarely pause to ask for your input, making it ideal for '
          'straightforward tasks where speed matters more than perfect accuracy.';
    } else if (confidence < 0.6) {
      return 'Your agent balances autonomy with caution. It will work independently '
          'on clear tasks but may ask for guidance on ambiguous situations. '
          'A good default for most use cases.';
    } else if (confidence < 0.8) {
      return 'Your agent will be cautious and may send verification requests '
          'to your inbox when it\'s unsure. Check the notification bell in the '
          'navigation bar for pending approvals. Good for important tasks.';
    } else {
      return 'Your agent will frequently request human verification before '
          'taking action. Expect regular notifications in your inbox. '
          'Best for critical tasks where mistakes are costly.';
    }
  }

  Widget _buildSliderParameter(
    BuildContext context, {
    required String label,
    required String description,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String displayValue,
    required ValueChanged<double> onChanged,
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
                displayValue,
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

  String _getStepsLabel(int steps) {
    if (steps <= 3) return '$steps (Quick)';
    if (steps <= 7) return '$steps (Standard)';
    if (steps <= 12) return '$steps (Thorough)';
    return '$steps (Exhaustive)';
  }

  String _getBranchesLabel(int branches) {
    switch (branches) {
      case 2:
        return '2 (Focused)';
      case 3:
        return '3 (Balanced)';
      case 4:
        return '4 (Broad)';
      case 5:
        return '5 (Comprehensive)';
      default:
        return '$branches';
    }
  }

  String _getConfidenceLabel(double confidence) {
    final percent = (confidence * 100).round();
    if (confidence < 0.4) return '$percent% (Relaxed)';
    if (confidence < 0.6) return '$percent% (Moderate)';
    if (confidence < 0.8) return '$percent% (Careful)';
    return '$percent% (Strict)';
  }

  Widget _buildValidationStatus(BuildContext context) {
    final colors = ThemeColors(context);
    final error = wizardState.getStepError(3);

    if (error != null) {
      return Container(
        padding: const EdgeInsets.all(SpacingTokens.md),
        decoration: BoxDecoration(
          color: colors.error.withValues(alpha: 0.1),
          border: Border.all(color: colors.error.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
        ),
        child: Row(
          children: [
            Icon(Icons.warning, color: colors.error, size: 20),
            const SizedBox(width: SpacingTokens.sm),
            Expanded(
              child: Text(
                error,
                style: TextStyles.bodySmall.copyWith(color: colors.error),
              ),
            ),
          ],
        ),
      );
    }

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configuration Complete',
                  style: TextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.success,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getConfigSummary(),
                  style: TextStyles.bodySmall.copyWith(color: colors.onSurface),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getConfigSummary() {
    final parts = <String>[];

    parts.add('Type: ${wizardState.agentType.displayName}');
    parts.add('Style: ${wizardState.reasoningPattern.displayName}');

    if (wizardState.agentType == DspyAgentType.react) {
      parts.add('Tools: ${wizardState.selectedTools.length}');
      parts.add('Steps: ${wizardState.maxIterations}');
    }

    if (wizardState.reasoningPattern == DspyReasoningPattern.treeOfThought) {
      parts.add('Paths: ${wizardState.numBranches}');
    }

    return parts.join(' • ');
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:agent_engine_core/models/agent.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/models/agent_template.dart';
import '../../../../core/services/agent_template_service.dart';
import '../../../../providers/agent_provider.dart';
import '../../models/dspy_agent_wizard_state.dart';
import '../widgets/dspy_agent_type_step.dart';
import '../widgets/dspy_model_step.dart';
import '../widgets/dspy_tools_step.dart';
import '../widgets/dspy_system_prompt_step.dart';
import '../widgets/dspy_deploy_step.dart';

/// DSPy-aligned Agent Wizard
///
/// A 6-step wizard that creates agents with configurations that
/// map directly to DSPy backend concepts:
///
/// 1. Agent Basics (name, description)
/// 2. Agent Type (ReAct, Code, Reasoning) + Reasoning Pattern
/// 3. Model Selection (Claude, GPT, Ollama)
/// 4. System Prompt (master prompt defining agent behavior)
/// 5. Tools & Capabilities (for ReAct agents)
/// 6. Deploy & Test (validate against DSPy backend)
class DspyAgentWizardScreen extends ConsumerStatefulWidget {
  final String? templateId;

  const DspyAgentWizardScreen({
    super.key,
    this.templateId,
  });

  @override
  ConsumerState<DspyAgentWizardScreen> createState() =>
      _DspyAgentWizardScreenState();
}

class _DspyAgentWizardScreenState extends ConsumerState<DspyAgentWizardScreen> {
  late DspyAgentWizardState _wizardState;
  final AgentTemplateService _templateService = AgentTemplateService();
  int _currentStep = 0;
  final PageController _pageController = PageController();

  static const _stepTitles = [
    'Agent Basics',
    'Agent Type',
    'Model Selection',
    'System Prompt',
    'Tools & Capabilities',
    'Deploy & Test',
  ];

  @override
  void initState() {
    super.initState();
    _wizardState = DspyAgentWizardState();

    // Load template if provided
    if (widget.templateId != null) {
      final template = _templateService.getTemplateById(widget.templateId!);
      if (template != null) {
        _wizardState.loadFromTemplate(template);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _wizardState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ThemeColors(context);

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
              _buildHeader(context),
              _buildStepIndicator(context),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) {
                    setState(() => _currentStep = index);
                  },
                  children: [
                    _buildBasicsStep(context),
                    DspyAgentTypeStep(
                      wizardState: _wizardState,
                      onChanged: () => setState(() {}),
                    ),
                    DspyModelStep(
                      wizardState: _wizardState,
                      onChanged: () => setState(() {}),
                    ),
                    DspySystemPromptStep(
                      wizardState: _wizardState,
                      onChanged: () => setState(() {}),
                    ),
                    DspyToolsStep(
                      wizardState: _wizardState,
                      onChanged: () => setState(() {}),
                    ),
                    DspyDeployStep(
                      wizardState: _wizardState,
                      onChanged: () => setState(() {}),
                      onDeploy: _deployAgent,
                    ),
                  ],
                ),
              ),
              _buildNavigationButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colors = ThemeColors(context);

    return Container(
      padding: const EdgeInsets.all(SpacingTokens.md),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colors.border),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _showExitConfirmation(context),
            tooltip: 'Cancel',
          ),
          const SizedBox(width: SpacingTokens.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create Agent',
                style: TextStyles.pageTitle.copyWith(fontSize: 18),
              ),
              Text(
                'Step ${_currentStep + 1} of ${_stepTitles.length}: ${_stepTitles[_currentStep]}',
                style: TextStyles.bodySmall.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(BuildContext context) {
    final colors = ThemeColors(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.xxl,
        vertical: SpacingTokens.md,
      ),
      child: Row(
        children: List.generate(_stepTitles.length, (index) {
          final isActive = index == _currentStep;
          final isCompleted = index < _currentStep;
          final isValid = _wizardState.isStepValid(index);

          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? colors.success
                        : isActive
                            ? colors.primary
                            : colors.surfaceVariant,
                    shape: BoxShape.circle,
                    border: isActive
                        ? Border.all(color: colors.primary, width: 2)
                        : null,
                  ),
                  child: Center(
                    child: isCompleted
                        ? Icon(Icons.check, size: 16, color: colors.onPrimary)
                        : Text(
                            '${index + 1}',
                            style: TextStyles.bodySmall.copyWith(
                              color: isActive
                                  ? colors.onPrimary
                                  : colors.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                if (index < _stepTitles.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(
                          horizontal: SpacingTokens.xs),
                      color: isCompleted
                          ? colors.success
                          : colors.surfaceVariant,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  String? _selectedTemplateId;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  Widget _buildBasicsStep(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero section with title and quick stats
          _buildHeroSection(context),

          const SizedBox(height: SpacingTokens.xl),

          // Main content in two columns on wide screens
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 900) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left column - Template picker
                    Expanded(
                      flex: 3,
                      child: _buildTemplatePickerCard(context),
                    ),
                    const SizedBox(width: SpacingTokens.lg),
                    // Right column - Agent details form
                    Expanded(
                      flex: 2,
                      child: _buildAgentDetailsCard(context),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildTemplatePickerCard(context),
                    const SizedBox(height: SpacingTokens.lg),
                    _buildAgentDetailsCard(context),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    final colors = ThemeColors(context);
    final templates = _templateService.getAllTemplates();

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
                        borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
                      ),
                      child: Icon(
                        Icons.auto_awesome,
                        color: colors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: SpacingTokens.md),
                    Text(
                      'Create Your Agent',
                      style: TextStyles.pageTitle.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SpacingTokens.sm),
                Text(
                  'Choose a template to get started quickly, or build from scratch with full customization.',
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
                context,
                icon: Icons.category,
                label: 'Templates',
                value: '${templates.length}',
                color: colors.primary,
              ),
              const SizedBox(width: SpacingTokens.lg),
              _buildQuickStat(
                context,
                icon: Icons.folder,
                label: 'Categories',
                value: '${_templateService.getCategories().length}',
                color: colors.success,
              ),
              const SizedBox(width: SpacingTokens.lg),
              _buildQuickStat(
                context,
                icon: Icons.smart_toy,
                label: 'Agent Types',
                value: '3',
                color: colors.accent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final colors = ThemeColors(context);

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

  Widget _buildTemplatePickerCard(BuildContext context) {
    final colors = ThemeColors(context);
    final templates = _templateService.getAllTemplates();
    final categories = _templateService.getCategories();

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
          // Header with dropdown
          Row(
            children: [
              Icon(Icons.dashboard, color: colors.primary, size: 20),
              const SizedBox(width: SpacingTokens.sm),
              Text(
                'Choose a Template',
                style: TextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              // Template dropdown for quick selection
              Container(
                constraints: const BoxConstraints(maxWidth: 250),
                child: DropdownButtonFormField<String>(
                  value: _selectedTemplateId,
                  decoration: InputDecoration(
                    hintText: 'Quick select...',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: SpacingTokens.sm,
                      vertical: SpacingTokens.xs,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
                    ),
                    filled: true,
                    fillColor: colors.inputBackground,
                    isDense: true,
                  ),
                  isExpanded: true,
                  items: [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text(
                        'Start from scratch',
                        style: TextStyles.bodySmall.copyWith(
                          fontStyle: FontStyle.italic,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    ...templates.map((template) => DropdownMenuItem<String>(
                      value: template.id,
                      child: Row(
                        children: [
                          Icon(template.icon, size: 16, color: colors.primary),
                          const SizedBox(width: SpacingTokens.xs),
                          Flexible(
                            child: Text(
                              template.name,
                              style: TextStyles.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                  onChanged: (String? templateId) {
                    setState(() {
                      _selectedTemplateId = templateId;
                    });
                    if (templateId != null) {
                      final template = _templateService.getTemplateById(templateId);
                      if (template != null) {
                        _wizardState.loadFromTemplate(template);
                        _nameController.text = _wizardState.agentName;
                        _descriptionController.text = _wizardState.agentDescription;
                      }
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.md),

          // Template grid by category
          ...categories.map((category) {
            final categoryTemplates = templates
                .where((t) => t.category == category)
                .toList();
            if (categoryTemplates.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: SpacingTokens.sm),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 16,
                        decoration: BoxDecoration(
                          color: _getCategoryColor(category, colors),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: SpacingTokens.sm),
                      Text(
                        category,
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
                          borderRadius: BorderRadius.circular(BorderRadiusTokens.xs),
                        ),
                        child: Text(
                          '${categoryTemplates.length}',
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
                  children: categoryTemplates.map((template) =>
                    _buildTemplateCard(context, template)
                  ).toList(),
                ),
                const SizedBox(height: SpacingTokens.md),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTemplateCard(BuildContext context, AgentTemplate template) {
    final colors = ThemeColors(context);
    final isSelected = _selectedTemplateId == template.id;
    final categoryColor = _getCategoryColor(template.category, colors);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTemplateId = template.id;
          });
          _wizardState.loadFromTemplate(template);
          _nameController.text = _wizardState.agentName;
          _descriptionController.text = _wizardState.agentDescription;
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 180,
          padding: const EdgeInsets.all(SpacingTokens.md),
          decoration: BoxDecoration(
            color: isSelected
                ? categoryColor.withValues(alpha: 0.1)
                : colors.surface,
            borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
            border: Border.all(
              color: isSelected ? categoryColor : colors.border,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected ? [
              BoxShadow(
                color: categoryColor.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ] : null,
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
                      color: categoryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
                    ),
                    child: Icon(
                      template.icon,
                      size: 18,
                      color: categoryColor,
                    ),
                  ),
                  const Spacer(),
                  if (isSelected)
                    Icon(
                      Icons.check_circle,
                      size: 18,
                      color: categoryColor,
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
              const SizedBox(height: SpacingTokens.sm),
              // Agent type badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.xs,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(BorderRadiusTokens.xs),
                ),
                child: Text(
                  template.agentType.name.toUpperCase(),
                  style: TextStyles.caption.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAgentDetailsCard(BuildContext context) {
    final colors = ThemeColors(context);

    // Sync controllers with wizard state
    if (_nameController.text != _wizardState.agentName) {
      _nameController.text = _wizardState.agentName;
    }
    if (_descriptionController.text != _wizardState.agentDescription) {
      _descriptionController.text = _wizardState.agentDescription;
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
              Icon(Icons.edit_note, color: colors.primary, size: 20),
              const SizedBox(width: SpacingTokens.sm),
              Text(
                'Agent Details',
                style: TextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.lg),

          // Selected template indicator
          if (_selectedTemplateId != null)
            _buildSelectedTemplateIndicator(context),

          if (_selectedTemplateId != null)
            const SizedBox(height: SpacingTokens.lg),

          // Name field
          Text(
            'Agent Name',
            style: TextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: SpacingTokens.sm),
          TextField(
            controller: _nameController,
            onChanged: _wizardState.setAgentName,
            decoration: InputDecoration(
              hintText: 'e.g., Research Assistant, Code Helper',
              prefixIcon: Icon(Icons.smart_toy, color: colors.onSurfaceVariant),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
              ),
              filled: true,
              fillColor: colors.inputBackground,
            ),
          ),

          const SizedBox(height: SpacingTokens.lg),

          // Description field
          Text(
            'Description',
            style: TextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: SpacingTokens.sm),
          TextField(
            controller: _descriptionController,
            onChanged: _wizardState.setAgentDescription,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'What does this agent do? How should it behave?',
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
              ),
              filled: true,
              fillColor: colors.inputBackground,
            ),
          ),

          const SizedBox(height: SpacingTokens.lg),

          // Validation status
          if (_wizardState.getStepError(0) != null)
            Container(
              padding: const EdgeInsets.all(SpacingTokens.md),
              decoration: BoxDecoration(
                color: colors.warning.withValues(alpha: 0.1),
                border: Border.all(color: colors.warning.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: colors.warning, size: 20),
                  const SizedBox(width: SpacingTokens.sm),
                  Expanded(
                    child: Text(
                      _wizardState.getStepError(0)!,
                      style: TextStyles.bodySmall.copyWith(color: colors.warning),
                    ),
                  ),
                ],
              ),
            )
          else if (_wizardState.isStepValid(0))
            Container(
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
                  Text(
                    'Ready to proceed to next step',
                    style: TextStyles.bodySmall.copyWith(color: colors.success),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectedTemplateIndicator(BuildContext context) {
    final colors = ThemeColors(context);
    final template = _templateService.getTemplateById(_selectedTemplateId!);
    if (template == null) return const SizedBox.shrink();

    final categoryColor = _getCategoryColor(template.category, colors);

    return Container(
      padding: const EdgeInsets.all(SpacingTokens.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            categoryColor.withValues(alpha: 0.1),
            categoryColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
        border: Border.all(color: categoryColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(SpacingTokens.sm),
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
            ),
            child: Icon(template.icon, color: categoryColor, size: 20),
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
                  template.name,
                  style: TextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: colors.onSurfaceVariant),
            onPressed: () {
              setState(() {
                _selectedTemplateId = null;
              });
              _wizardState.reset();
              _nameController.clear();
              _descriptionController.clear();
            },
            tooltip: 'Clear template',
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category, ThemeColors colors) {
    switch (category.toLowerCase()) {
      case 'task completion':
        return colors.primary;
      case 'design & creative':
        return colors.accent;
      case 'development':
        return colors.info;
      case 'analysis & research':
        return colors.success;
      case 'support & communication':
        return colors.warning;
      case 'specialized':
        return colors.primary;
      default:
        return colors.primary;
    }
  }

  Widget _buildNavigationButtons(BuildContext context) {
    final colors = ThemeColors(context);
    final canGoBack = _currentStep > 0;
    final canGoForward =
        _currentStep < _stepTitles.length - 1 && _wizardState.isStepValid(_currentStep);

    return Container(
      padding: const EdgeInsets.all(SpacingTokens.md),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (canGoBack)
            AsmblButton.secondary(
              text: 'Back',
              onPressed: _goBack,
              icon: Icons.arrow_back,
            )
          else
            const SizedBox(width: 100),
          if (_currentStep < _stepTitles.length - 1)
            AsmblButton.primary(
              text: 'Next',
              onPressed: canGoForward ? _goForward : null,
              icon: Icons.arrow_forward,
            ),
        ],
      ),
    );
  }

  void _goBack() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goForward() {
    if (_currentStep < _stepTitles.length - 1 &&
        _wizardState.isStepValid(_currentStep)) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _deployAgent() async {
    final config = _wizardState.buildAgentConfig();

    // Convert DspyAgentConfig to Agent model for storage
    final agent = Agent(
      id: config.id,
      name: config.name,
      description: config.description,
      capabilities: config.getCapabilities(),
      configuration: config.toAgentConfiguration(),
      status: AgentStatus.idle,
    );

    try {
      // Save via AgentNotifier (persists to Hive storage)
      await ref.read(agentNotifierProvider.notifier).createAgent(agent);

      // Show success and navigate back
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Agent "${config.name}" created successfully!'),
            backgroundColor: ThemeColors(context).success,
          ),
        );
        context.go(AppRoutes.agents);
      }
    } catch (e) {
      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create agent: $e'),
            backgroundColor: ThemeColors(context).error,
          ),
        );
      }
    }
  }

  void _showExitConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text(
          'Are you sure you want to cancel? Your progress will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Editing'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go(AppRoutes.agents);
            },
            child: Text(
              'Discard',
              style: TextStyle(color: ThemeColors(context).error),
            ),
          ),
        ],
      ),
    );
  }
}

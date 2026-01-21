import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/design_system/design_system.dart';
import '../../core/constants/routes.dart';

/// Controlled onboarding flow for users to add ingredients and configure their AI agent
class ControlledOnboardingFlow extends ConsumerStatefulWidget {
  final int? selectedAgentType;
  final Function(OnboardingData)? onComplete;

  const ControlledOnboardingFlow({
    super.key,
    this.selectedAgentType,
    this.onComplete,
  });

  @override
  ConsumerState<ControlledOnboardingFlow> createState() => _ControlledOnboardingFlowState();
}

class _ControlledOnboardingFlowState extends ConsumerState<ControlledOnboardingFlow> {
  int _currentStep = 0;
  final PageController _pageController = PageController();
  
  // Step 1: Ingredients (docs/research)
  final List<IngredientItem> _ingredients = [];
  String _researchTopic = '';
  
  // Step 2: Model selection and reasoning
  String? _selectedModel;
  String? _reasoningStyle;
  int _modelTabIndex = 0; // 0: Local, 1: Cloud
  
  // Step 3: Tools selection
  List<String> _selectedTools = [];
  
  // Step 4: Confidence configuration
  double _confidenceThreshold = 0.8;
  bool _humanVerificationEnabled = true;
  
  // Step 5: Flow completion options
  String? _flowType;
  Map<String, dynamic> _flowOptions = {};

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ThemeColors(context);

    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.5,
          colors: [
            colors.backgroundGradientStart,
            colors.backgroundGradientMiddle,
            colors.backgroundGradientEnd,
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // Header with progress
              _buildHeader(colors),
              
              // Two-column layout
              Expanded(
                child: Row(
                  children: [
                    // Left column - Step navigation and overview
                    Container(
                      width: 320,
                      padding: const EdgeInsets.all(SpacingTokens.xl),
                      decoration: BoxDecoration(
                        color: colors.surface.withOpacity(0.5),
                        border: Border(right: BorderSide(color: colors.border)),
                      ),
                      child: _buildStepNavigation(colors),
                    ),
                    
                    // Right column - Step content
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildIngredientsStep(colors),
                          _buildModelSelectionStep(colors),
                          _buildToolsSelectionStep(colors),
                          _buildConfidenceStep(colors),
                          _buildFlowOptionsStep(colors),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Navigation controls
              _buildNavigationControls(colors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepNavigation(ThemeColors colors) {
    final steps = [
      StepInfo('Add Ingredients', 'Documents & research topics', Icons.upload_file),
      StepInfo('Select Model', 'AI model & reasoning style', Icons.psychology),
      StepInfo('Choose Tools', 'Integration & workflow tools', Icons.integration_instructions),
      StepInfo('Set Confidence', 'Thresholds & verification', Icons.verified),
      StepInfo('Configure Flow', 'Completion criteria', Icons.flag),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Agent summary
        Container(
          padding: const EdgeInsets.all(SpacingTokens.lg),
          decoration: BoxDecoration(
            color: colors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
            border: Border.all(color: colors.primary.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Icon(_getAgentIcon(), color: colors.primary, size: 32),
              const SizedBox(height: SpacingTokens.sm),
              Text(
                _getAgentName(),
                style: TextStyles.bodyLarge.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        
        const SizedBox(height: SpacingTokens.xl),
        
        // Step navigation
        Text(
          'Configuration Steps',
          style: TextStyles.bodyLarge.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: SpacingTokens.md),
        
        Expanded(
          child: ListView.builder(
            itemCount: steps.length,
            itemBuilder: (context, index) {
              final step = steps[index];
              final isActive = index == _currentStep;
              final isCompleted = index < _currentStep;
              
              return Container(
                margin: const EdgeInsets.only(bottom: SpacingTokens.sm),
                child: GestureDetector(
                  onTap: () => _jumpToStep(index),
                  child: Container(
                    padding: const EdgeInsets.all(SpacingTokens.md),
                    decoration: BoxDecoration(
                      color: isActive 
                          ? colors.primary.withOpacity(0.1)
                          : isCompleted 
                              ? colors.success.withOpacity(0.05)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
                      border: Border.all(
                        color: isActive 
                            ? colors.primary
                            : isCompleted 
                                ? colors.success
                                : colors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isActive 
                                ? colors.primary
                                : isCompleted 
                                    ? colors.success
                                    : colors.onSurfaceVariant.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
                          ),
                          child: Icon(
                            isCompleted ? Icons.check : step.icon,
                            size: 16,
                            color: isActive || isCompleted 
                                ? colors.surface 
                                : colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: SpacingTokens.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                step.title,
                                style: TextStyles.bodyMedium.copyWith(
                                  color: isActive 
                                      ? colors.primary
                                      : isCompleted 
                                          ? colors.success
                                          : colors.onSurface,
                                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                                ),
                              ),
                              Text(
                                step.subtitle,
                                style: TextStyles.bodySmall.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        
        // Current step summary
        if (_currentStep < 4) ...[
          const SizedBox(height: SpacingTokens.lg),
          Container(
            padding: const EdgeInsets.all(SpacingTokens.md),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Progress',
                  style: TextStyles.bodySmall.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: SpacingTokens.sm),
                Text(
                  _getStepSummary(),
                  style: TextStyles.bodySmall.copyWith(color: colors.onSurface),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHeader(ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      decoration: BoxDecoration(
        color: colors.surface.withOpacity(0.8),
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            onPressed: () {
              if (!mounted) return;
              context.go(AppRoutes.demoOnboarding);
            },
            icon: Icon(Icons.arrow_back, color: colors.onSurface),
            tooltip: 'Back to Agent Selection',
          ),
          
          const SizedBox(width: SpacingTokens.md),
          
          // Title
          Text(
            'Agent Configuration',
            style: TextStyles.pageTitle.copyWith(color: colors.onSurface),
          ),
          
          const Spacer(),

          // Progress indicator (simplified)
          Text(
            'Step ${_currentStep + 1} of 5',
            style: TextStyles.bodyMedium.copyWith(color: colors.onSurfaceVariant),
          ),

          const SizedBox(width: SpacingTokens.md),

          // Theme toggle
          const ThemeToggle(),
        ],
      ),
    );
  }

  Widget _buildIngredientsStep(ThemeColors colors) {
    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step title and description
          Text(
            _getIngredientsTitle(),
            style: TextStyles.sectionTitle.copyWith(color: colors.onSurface),
          ),
          const SizedBox(height: SpacingTokens.sm),
          Text(
            _getIngredientsDescription(),
            style: TextStyles.bodyMedium.copyWith(color: colors.onSurfaceVariant),
          ),
          
          const SizedBox(height: SpacingTokens.xl),
          
          // Upload documents section
          Row(
            children: [
              Expanded(
                child: _buildUploadOption(
                  _getUploadDocumentsTitle(),
                  _getUploadDocumentsSubtitle(),
                  _getUploadDocumentsIcon(),
                  () => _showDocumentUpload(),
                  colors,
                ),
              ),
              const SizedBox(width: SpacingTokens.lg),
              Expanded(
                child: _buildUploadOption(
                  _getResearchTopicTitle(),
                  _getResearchTopicSubtitle(),
                  Icons.search,
                  () => _showResearchTopicDialog(),
                  colors,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: SpacingTokens.xl),
          
          // Added ingredients list
          if (_ingredients.isNotEmpty || _researchTopic.isNotEmpty) ...[
            Text(
              'Your Ingredients',
              style: TextStyles.bodyLarge.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: SpacingTokens.md),
            Expanded(
              child: ListView(
                children: [
                  // Research topic
                  if (_researchTopic.isNotEmpty)
                    _buildIngredientCard(
                      IngredientItem(
                        type: IngredientType.research,
                        title: 'Research: $_researchTopic',
                        subtitle: 'AI will research this topic',
                        icon: Icons.search,
                      ),
                      colors,
                    ),
                  
                  // Uploaded documents
                  ..._ingredients.map((ingredient) => 
                    _buildIngredientCard(ingredient, colors)
                  ),
                ],
              ),
            ),
          ] else ...[
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.upload_outlined,
                      size: 64,
                      color: colors.onSurfaceVariant.withOpacity(0.5),
                    ),
                    const SizedBox(height: SpacingTokens.lg),
                    Text(
                      'No ingredients added yet',
                      style: TextStyles.bodyLarge.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      'Add documents or research topics to get started',
                      style: TextStyles.bodyMedium.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModelSelectionStep(ThemeColors colors) {
    // Separate models by local and cloud
    final localModels = [
      ModelOption('Gemma3 27B', 'Privacy-focused local processing', 'ollama'),
      ModelOption('Deepseek R1 8B', 'Fast local reasoning model', 'ollama'),
      ModelOption('GPT-OSS 20B', 'OpenAI open-source, runs on laptops (16GB)', 'openai'),
      ModelOption('Llama 3.2', 'Fast local inference for quick tasks (3B)', 'meta'),
      ModelOption('Phi-3 Mini', 'Code completion & small scripts (3.8B)', 'microsoft'),
      ModelOption('Qwen2.5-Coder', 'Specialized for code generation & debugging', 'alibaba'),
      ModelOption('Mistral 7B', 'Balanced performance for general tasks', 'mistral'),
      ModelOption('StableLM 2', 'Creative writing & content generation', 'stability'),
      ModelOption('Orca 2', 'Teaching & step-by-step explanations (13B)', 'microsoft'),
    ];

    final cloudModels = [
      ModelOption('Claude 4.5 Sonnet', 'Best for complex reasoning and analysis', 'anthropic'),
      ModelOption('GPT-4 Turbo', 'Great for general tasks and creativity', 'openai'),
      ModelOption('GPT-4o', 'Multimodal with vision & faster responses', 'openai'),
      ModelOption('Gemini 1.5 Pro', 'Google\'s flagship with 1M token context', 'google'),
      ModelOption('Kimi K2', 'Best for multilingual tasks & long context', 'moonshot'),
      ModelOption('Yi-34B', 'Complex reasoning & bilingual tasks', '01ai'),
    ];

    final currentModels = _modelTabIndex == 0 ? localModels : cloudModels;

    // Get model-specific reasoning styles
    final reasoningStyles = _getReasoningStylesForModel(_selectedModel);

    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose Your AI Model & Reasoning Style',
            style: TextStyles.sectionTitle.copyWith(color: colors.onSurface),
          ),
          const SizedBox(height: SpacingTokens.sm),
          Text(
            'Select the AI model and reasoning approach that best fits your task.',
            style: TextStyles.bodyMedium.copyWith(color: colors.onSurfaceVariant),
          ),
          
          const SizedBox(height: SpacingTokens.xl),
          
          // Side-by-side layout for model and reasoning
          Expanded(
            child: Row(
              children: [
                // Left side - Model selection
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Model',
                        style: TextStyles.bodyLarge.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: SpacingTokens.md),
                      
                      // Local/Cloud tabs
                      Container(
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildTabButton(
                                'Local',
                                Icons.computer,
                                _modelTabIndex == 0,
                                () => setState(() {
                                  _modelTabIndex = 0;
                                  _selectedModel = null; // Reset selection when switching tabs
                                  _reasoningStyle = null;
                                }),
                                colors,
                              ),
                            ),
                            Expanded(
                              child: _buildTabButton(
                                'Cloud',
                                Icons.cloud,
                                _modelTabIndex == 1,
                                () => setState(() {
                                  _modelTabIndex = 1;
                                  _selectedModel = null; // Reset selection when switching tabs
                                  _reasoningStyle = null;
                                }),
                                colors,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: SpacingTokens.sm),
                      
                      // Tab context info
                      Container(
                        padding: const EdgeInsets.all(SpacingTokens.sm),
                        decoration: BoxDecoration(
                          color: _modelTabIndex == 0 ? colors.success.withOpacity(0.05) : colors.accent.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
                          border: Border.all(
                            color: _modelTabIndex == 0 ? colors.success.withOpacity(0.2) : colors.accent.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _modelTabIndex == 0 ? Icons.security : Icons.speed,
                              size: 14,
                              color: _modelTabIndex == 0 ? colors.success : colors.accent,
                            ),
                            const SizedBox(width: SpacingTokens.xs),
                            Expanded(
                              child: Text(
                                _modelTabIndex == 0 
                                    ? 'Private processing on your device'
                                    : 'High-performance cloud inference',
                                style: TextStyles.bodySmall.copyWith(
                                  color: _modelTabIndex == 0 ? colors.success : colors.accent,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: SpacingTokens.md),
                      
                      Expanded(
                        child: ListView.builder(
                          itemCount: currentModels.length,
                          physics: const BouncingScrollPhysics(),
                          itemBuilder: (context, index) {
                            final model = currentModels[index];
                            final isSelected = _selectedModel == model.name;
                            final isEasterEgg = _modelTabIndex == 0 && index >= 6; // Local models after 6th are easter eggs
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: SpacingTokens.sm),
                              child: _buildSelectionCard(
                                model.name,
                                model.description,
                                _getModelIcon(model),
                                isSelected,
                                () => setState(() {
                                  _selectedModel = model.name;
                                  // Reset reasoning style when changing models
                                  _reasoningStyle = null;
                                }),
                                colors,
                                isEasterEgg: isEasterEgg,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: SpacingTokens.xl),
                
                // Right side - Reasoning style
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reasoning Style',
                        style: TextStyles.bodyLarge.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: SpacingTokens.md),
                      
                      Expanded(
                        child: GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 1,
                            crossAxisSpacing: SpacingTokens.md,
                            mainAxisSpacing: SpacingTokens.md,
                            childAspectRatio: 2.5,
                          ),
                          itemCount: reasoningStyles.length,
                          itemBuilder: (context, index) {
                            final style = reasoningStyles[index];
                            final isSelected = _reasoningStyle == style.name;
                            final isEasterEgg = index >= 4; // Reasoning styles after the first 4 are easter eggs
                            
                            return _buildReasoningCard(style, isSelected, colors, isEasterEgg: isEasterEgg);
                          },
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

  Widget _buildToolsSelectionStep(ThemeColors colors) {
    final toolCategories = _getToolCategories();

    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Which tools should we integrate?',
            style: TextStyles.sectionTitle.copyWith(color: colors.onSurface),
          ),
          const SizedBox(height: SpacingTokens.sm),
          Text(
            'Select the tools your agent will work with to maximize productivity.',
            style: TextStyles.bodyMedium.copyWith(color: colors.onSurfaceVariant),
          ),
          
          const SizedBox(height: SpacingTokens.xl),
          
          Expanded(
            child: ListView.builder(
              itemCount: toolCategories.length,
              itemBuilder: (context, categoryIndex) {
                final category = toolCategories[categoryIndex];
                return Container(
                  margin: const EdgeInsets.only(bottom: SpacingTokens.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: TextStyles.bodyLarge.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: SpacingTokens.md),
                      
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: SpacingTokens.md,
                          mainAxisSpacing: SpacingTokens.md,
                          childAspectRatio: 2.5,
                        ),
                        itemCount: category.tools.length,
                        itemBuilder: (context, toolIndex) {
                          final tool = category.tools[toolIndex];
                          final isSelected = _selectedTools.contains(tool.name);
                          
                          return GestureDetector(
                            onTap: () => _toggleTool(tool.name),
                            child: Container(
                              padding: const EdgeInsets.all(SpacingTokens.sm),
                              decoration: BoxDecoration(
                                color: isSelected ? colors.primary.withOpacity(0.1) : colors.surface,
                                borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
                                border: Border.all(
                                  color: isSelected ? colors.primary : colors.border,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    tool.icon,
                                    size: 20,
                                    color: isSelected ? colors.primary : colors.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: SpacingTokens.xs),
                                  Expanded(
                                    child: Text(
                                      tool.name,
                                      style: TextStyles.bodySmall.copyWith(
                                        color: isSelected ? colors.primary : colors.onSurface,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(Icons.check_circle, color: colors.primary, size: 16),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceStep(ThemeColors colors) {
    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Configure Confidence & Verification',
            style: TextStyles.sectionTitle.copyWith(color: colors.onSurface),
          ),
          const SizedBox(height: SpacingTokens.sm),
          Text(
            'Set how confident the AI should be before taking actions, and when to ask for human verification.',
            style: TextStyles.bodyMedium.copyWith(color: colors.onSurfaceVariant),
          ),
          
          const SizedBox(height: SpacingTokens.xl),
          
          // Confidence threshold
          Container(
            padding: const EdgeInsets.all(SpacingTokens.lg),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.psychology, color: colors.primary, size: 20),
                    const SizedBox(width: SpacingTokens.sm),
                    Text(
                      'Confidence Threshold',
                      style: TextStyles.bodyLarge.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SpacingTokens.md),
                Text(
                  'AI will ask for help when confidence falls below ${(_confidenceThreshold * 100).toInt()}%',
                  style: TextStyles.bodyMedium.copyWith(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: SpacingTokens.lg),
                
                // Confidence slider
                Row(
                  children: [
                    Text(
                      '50%',
                      style: TextStyles.bodySmall.copyWith(color: colors.onSurfaceVariant),
                    ),
                    Expanded(
                      child: Slider(
                        value: _confidenceThreshold,
                        min: 0.5,
                        max: 0.95,
                        divisions: 9,
                        activeColor: colors.primary,
                        inactiveColor: colors.border,
                        onChanged: (value) {
                          setState(() => _confidenceThreshold = value);
                        },
                      ),
                    ),
                    Text(
                      '95%',
                      style: TextStyles.bodySmall.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: SpacingTokens.lg),
          
          // Human verification toggle
          Container(
            padding: const EdgeInsets.all(SpacingTokens.lg),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Icon(Icons.verified_user, color: colors.accent, size: 20),
                const SizedBox(width: SpacingTokens.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Human Verification',
                        style: TextStyles.bodyLarge.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Require human approval for important actions',
                        style: TextStyles.bodyMedium.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _humanVerificationEnabled,
                  onChanged: (value) {
                    setState(() => _humanVerificationEnabled = value);
                  },
                  activeColor: colors.primary,
                ),
              ],
            ),
          ),
          
          const Spacer(),
          
          // Preview settings
          Container(
            padding: const EdgeInsets.all(SpacingTokens.lg),
            decoration: BoxDecoration(
              color: colors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
              border: Border.all(color: colors.primary.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configuration Preview',
                  style: TextStyles.bodyLarge.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: SpacingTokens.sm),
                Text(
                  '• AI will request help at ${(_confidenceThreshold * 100).toInt()}% confidence or lower\n'
                  '• Human verification: ${_humanVerificationEnabled ? 'Enabled' : 'Disabled'}\n'
                  '• Model: ${_selectedModel ?? 'Not selected'}\n'
                  '• Reasoning: ${_reasoningStyle ?? 'Not selected'}',
                  style: TextStyles.bodyMedium.copyWith(color: colors.onSurface),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowOptionsStep(ThemeColors colors) {
    final flowTypes = _getFlowOptions();

    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How should we complete this task?',
            style: TextStyles.sectionTitle.copyWith(color: colors.onSurface),
          ),
          const SizedBox(height: SpacingTokens.sm),
          Text(
            'Choose what the AI should deliver and how to know when the task is complete.',
            style: TextStyles.bodyMedium.copyWith(color: colors.onSurfaceVariant),
          ),
          
          const SizedBox(height: SpacingTokens.lg),

          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: SpacingTokens.md,
                mainAxisSpacing: SpacingTokens.md,
                childAspectRatio: 1.6, // Compact cards to fit content without extra whitespace
              ),
              itemCount: flowTypes.length,
              itemBuilder: (context, index) {
                final flowType = flowTypes[index];
                final isSelected = _flowType == flowType.name;

                return GestureDetector(
                  onTap: () => setState(() => _flowType = flowType.name),
                  child: Container(
                    padding: const EdgeInsets.all(SpacingTokens.md),
                    decoration: BoxDecoration(
                      color: isSelected ? colors.primary.withOpacity(0.1) : colors.surface,
                      borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
                      border: Border.all(
                        color: isSelected ? colors.primary : colors.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icon and deliverable type badge
                        Row(
                          children: [
                            Icon(
                              flowType.icon,
                              size: 28,
                              color: isSelected ? colors.primary : colors.onSurfaceVariant,
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: SpacingTokens.sm,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? colors.primary.withOpacity(0.2)
                                    : colors.onSurfaceVariant.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
                              ),
                              child: Text(
                                flowType.deliverableType,
                                style: TextStyles.bodySmall.copyWith(
                                  color: isSelected ? colors.primary : colors.onSurfaceVariant,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: SpacingTokens.sm),

                        // Title
                        Text(
                          flowType.name,
                          style: TextStyles.bodyMedium.copyWith(
                            color: isSelected ? colors.primary : colors.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),

                        // Estimated time with icon
                        Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 12,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              flowType.estimatedTime,
                              style: TextStyles.bodySmall.copyWith(
                                color: colors.onSurfaceVariant,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: SpacingTokens.xs),

                        // Description
                        Text(
                          flowType.description,
                          style: TextStyles.bodySmall.copyWith(
                            color: colors.onSurfaceVariant,
                            fontSize: 11,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        // Key features with checkmark bullets
                        if (flowType.keyFeatures.isNotEmpty) ...[
                          const SizedBox(height: SpacingTokens.xs),
                          ...flowType.keyFeatures.take(2).map((feature) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 11,
                                  color: isSelected ? colors.primary : colors.success.withOpacity(0.6),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    feature,
                                    style: TextStyles.bodySmall.copyWith(
                                      color: colors.onSurfaceVariant,
                                      fontSize: 10,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          )),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationControls(ThemeColors colors) {
    final canGoNext = _canProceedToNextStep();
    
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.xl),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          // Back button
          if (_currentStep > 0)
            AsmblButton.secondary(
              text: 'Back',
              onPressed: _goToPreviousStep,
              icon: Icons.arrow_back,
            )
          else
            const SizedBox.shrink(),
          
          const Spacer(),
          
          // Next/Complete button
          AsmblButton.primary(
            text: _currentStep == 4 ? 'Complete Setup' : 'Next',
            onPressed: canGoNext ? _goToNextStep : null,
            icon: _currentStep == 4 ? Icons.check : Icons.arrow_forward,
          ),
        ],
      ),
    );
  }

  Widget _buildUploadOption(String title, String subtitle, IconData icon, VoidCallback onTap, ThemeColors colors) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(SpacingTokens.lg),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 48, color: colors.primary),
            const SizedBox(height: SpacingTokens.md),
            Text(
              title,
              style: TextStyles.bodyLarge.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SpacingTokens.sm),
            Text(
              subtitle,
              style: TextStyles.bodySmall.copyWith(color: colors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientCard(IngredientItem ingredient, ThemeColors colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: SpacingTokens.sm),
      padding: const EdgeInsets.all(SpacingTokens.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(ingredient.icon, color: colors.primary, size: 20),
          const SizedBox(width: SpacingTokens.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ingredient.title,
                  style: TextStyles.bodyMedium.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (ingredient.subtitle.isNotEmpty)
                  Text(
                    ingredient.subtitle,
                    style: TextStyles.bodySmall.copyWith(color: colors.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _removeIngredient(ingredient),
            icon: Icon(Icons.close, color: colors.onSurfaceVariant, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, IconData icon, bool isSelected, VoidCallback onTap, ThemeColors colors) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: SpacingTokens.sm,
          horizontal: SpacingTokens.md,
        ),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? colors.surface : colors.onSurface,
            ),
            const SizedBox(width: SpacingTokens.xs),
            Text(
              label,
              style: TextStyles.bodyMedium.copyWith(
                color: isSelected ? colors.surface : colors.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionCard(String title, String subtitle, IconData icon, bool isSelected, VoidCallback onTap, ThemeColors colors, {bool isEasterEgg = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(SpacingTokens.md),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary.withOpacity(0.1) : 
                 isEasterEgg ? colors.accent.withOpacity(0.05) : colors.surface,
          borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
          border: Border.all(
            color: isSelected ? colors.primary : 
                   isEasterEgg ? colors.accent.withOpacity(0.3) : colors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? colors.primary : colors.onSurfaceVariant,
              size: 24,
            ),
            const SizedBox(width: SpacingTokens.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyles.bodyMedium.copyWith(
                      color: isSelected ? colors.primary : colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyles.bodySmall.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: colors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildReasoningCard(ReasoningOption option, bool isSelected, ThemeColors colors, {bool isEasterEgg = false}) {
    return GestureDetector(
      onTap: () => setState(() => _reasoningStyle = option.name),
      child: Container(
        padding: const EdgeInsets.all(SpacingTokens.md),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary.withOpacity(0.1) : 
                 isEasterEgg ? colors.accent.withOpacity(0.05) : colors.surface,
          borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
          border: Border.all(
            color: isSelected ? colors.primary : 
                   isEasterEgg ? colors.accent.withOpacity(0.3) : colors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              option.icon,
              color: isSelected ? colors.primary : colors.onSurfaceVariant,
              size: 24,
            ),
            const SizedBox(height: SpacingTokens.xs),
            Text(
              option.name,
              style: TextStyles.bodyMedium.copyWith(
                color: isSelected ? colors.primary : colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              option.description,
              style: TextStyles.bodySmall.copyWith(color: colors.onSurfaceVariant),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  bool _canProceedToNextStep() {
    switch (_currentStep) {
      case 0: // Ingredients step
        return _ingredients.isNotEmpty || _researchTopic.isNotEmpty;
      case 1: // Model selection step
        return _selectedModel != null && _reasoningStyle != null;
      case 2: // Tools selection step
        return _selectedTools.isNotEmpty;
      case 3: // Confidence step
        return true; // Always can proceed (has defaults)
      case 4: // Flow options step
        return _flowType != null;
      default:
        return false;
    }
  }

  void _goToNextStep() {
    if (!mounted) return;
    if (_currentStep < 4) {
      setState(() => _currentStep++);
      if (mounted) {
        _pageController.animateToPage(
          _currentStep,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else {
      _completeOnboarding();
    }
  }

  void _goToPreviousStep() {
    if (!mounted) return;
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      if (mounted) {
        _pageController.animateToPage(
          _currentStep,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _completeOnboarding() {
    if (!mounted) return;
    final data = OnboardingData(
      ingredients: _ingredients,
      researchTopic: _researchTopic,
      selectedModel: _selectedModel!,
      reasoningStyle: _reasoningStyle!,
      selectedTools: _selectedTools,
      confidenceThreshold: _confidenceThreshold,
      humanVerificationEnabled: _humanVerificationEnabled,
      flowType: _flowType!,
      flowOptions: _flowOptions,
    );

    widget.onComplete?.call(data);
  }

  void _showDocumentUpload() {
    // Mock document upload - in real implementation would open file picker
    List<IngredientItem> mockDocs;

    switch (widget.selectedAgentType) {
      case 0: // Business Analyst
        mockDocs = [
          IngredientItem(
            type: IngredientType.document,
            title: 'Q4 Sales Report.pdf',
            subtitle: '2.3 MB • PDF Document',
            icon: Icons.picture_as_pdf,
          ),
          IngredientItem(
            type: IngredientType.document,
            title: 'Financial Analysis.xlsx',
            subtitle: '1.8 MB • Excel Spreadsheet',
            icon: Icons.table_chart,
          ),
        ];
        break;

      case 1: // Operations Manager
        mockDocs = [
          IngredientItem(
            type: IngredientType.document,
            title: 'Team Schedule.xlsx',
            subtitle: '1.1 MB • Excel Spreadsheet',
            icon: Icons.table_chart,
          ),
          IngredientItem(
            type: IngredientType.document,
            title: 'Process Workflow.pdf',
            subtitle: '0.8 MB • Process Documentation',
            icon: Icons.picture_as_pdf,
          ),
        ];
        break;

      case 2: // Coding Agent
        mockDocs = [
          IngredientItem(
            type: IngredientType.document,
            title: 'e-commerce-app/',
            subtitle: '124 files • React + Node.js',
            icon: Icons.folder,
          ),
          IngredientItem(
            type: IngredientType.document,
            title: 'api-spec.yaml',
            subtitle: '2.1 MB • OpenAPI Specification',
            icon: Icons.api,
          ),
          IngredientItem(
            type: IngredientType.document,
            title: 'requirements.md',
            subtitle: '156 KB • Technical Requirements',
            icon: Icons.description,
          ),
        ];
        break;

      default:
        mockDocs = [
          IngredientItem(
            type: IngredientType.document,
            title: 'Document.pdf',
            subtitle: '1.0 MB • PDF Document',
            icon: Icons.picture_as_pdf,
          ),
        ];
    }

    if (mounted) {
      setState(() {
        _ingredients.addAll(mockDocs);
      });
    }
  }

  void _showResearchTopicDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text(_getResearchTopicTitle()),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: _getResearchTopicPlaceholder(),
              border: const OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                Navigator.pop(context);
                if (mounted) {
                  setState(() => _researchTopic = text);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _removeIngredient(IngredientItem ingredient) {
    if (!mounted) return;
    setState(() {
      _ingredients.remove(ingredient);
      if (ingredient.type == IngredientType.research) {
        _researchTopic = '';
      }
    });
  }

  IconData _getAgentIcon() {
    switch (widget.selectedAgentType) {
      case 0: return Icons.analytics; // Business Analyst
      case 1: return Icons.schedule; // Operations Manager
      case 2: return Icons.code; // Coding Agent
      default: return Icons.auto_awesome;
    }
  }

  IconData _getModelIcon(ModelOption model) {
    // Check if it's a local model
    if (model.provider == 'ollama' || 
        model.name.contains('(Local)') || 
        model.name.contains('GPT-OSS') ||
        ['meta', 'microsoft', 'alibaba', 'mistral', 'stability'].contains(model.provider)) {
      return Icons.computer;
    }
    // Cloud models
    return Icons.cloud;
  }

  List<ReasoningOption> _getReasoningStylesForModel(String? modelName) {
    if (modelName == null) {
      // Default reasoning styles when no model is selected
      return [
        ReasoningOption('Analytical', 'Step-by-step logical breakdown', Icons.analytics),
        ReasoningOption('Creative', 'Innovative and exploratory approach', Icons.lightbulb),
        ReasoningOption('Systematic', 'Methodical and thorough analysis', Icons.list_alt),
        ReasoningOption('Intuitive', 'Pattern recognition and insights', Icons.psychology),
      ];
    }

    // Model-specific reasoning styles
    if (modelName.contains('Coder') || modelName.contains('Phi-3')) {
      // Coding models
      return [
        ReasoningOption('Test-Driven', 'Write tests first, then implement', Icons.check_circle),
        ReasoningOption('Refactoring-First', 'Clean code through iterative improvement', Icons.autorenew),
        ReasoningOption('Documentation-Led', 'Clear docs guide the implementation', Icons.description),
        ReasoningOption('Performance-Focused', 'Optimize for speed and efficiency', Icons.speed),
        ReasoningOption('Security-First', 'Prioritize secure coding practices', Icons.security),
      ];
    } else if (modelName.contains('StableLM') || modelName.contains('Creative')) {
      // Creative models
      return [
        ReasoningOption('Narrative Flow', 'Story-driven content creation', Icons.auto_stories),
        ReasoningOption('Brainstorming', 'Generate many ideas rapidly', Icons.bubble_chart),
        ReasoningOption('Iterative Refinement', 'Polish through multiple drafts', Icons.loop),
        ReasoningOption('Genre-Specific', 'Follow established style patterns', Icons.style),
      ];
    } else if (modelName.contains('Orca')) {
      // Teaching models
      return [
        ReasoningOption('Socratic Method', 'Guide through questions', Icons.question_answer),
        ReasoningOption('Step-by-Step', 'Break down complex concepts', Icons.format_list_numbered),
        ReasoningOption('Example-Driven', 'Learn through concrete examples', Icons.lightbulb_outline),
        ReasoningOption('Scaffolding', 'Build on prior knowledge', Icons.stairs),
      ];
    } else if (modelName.contains('Kimi') || modelName.contains('Yi')) {
      // Multilingual models
      return [
        ReasoningOption('Cross-Cultural', 'Consider cultural contexts', Icons.language),
        ReasoningOption('Translation-First', 'Preserve meaning across languages', Icons.translate),
        ReasoningOption('Comparative', 'Analyze linguistic differences', Icons.compare),
        ReasoningOption('Localization', 'Adapt for regional audiences', Icons.map),
      ];
    } else if (modelName.contains('GPT-4o')) {
      // Multimodal model
      return [
        ReasoningOption('Visual Analysis', 'Understand images and diagrams', Icons.image),
        ReasoningOption('Cross-Modal', 'Connect visual and textual information', Icons.compare_arrows),
        ReasoningOption('Rapid Iteration', 'Quick refinements and adjustments', Icons.speed),
        ReasoningOption('Creative Vision', 'Generate visual concepts', Icons.palette),
      ];
    } else if (modelName.contains('Gemini')) {
      // Google's model with huge context
      return [
        ReasoningOption('Long Context', 'Process entire codebases or documents', Icons.article),
        ReasoningOption('Comprehensive', 'Analyze all aspects thoroughly', Icons.view_comfy),
        ReasoningOption('Research Mode', 'Deep dive into topics', Icons.search),
        ReasoningOption('Structured Output', 'Organize complex information', Icons.table_chart),
      ];
    } else if (modelName.contains('GPT-OSS')) {
      // OpenAI's open source models
      return [
        ReasoningOption('Tool Master', 'Expert at web search & code execution', Icons.build_circle),
        ReasoningOption('Competition Mode', 'Solve complex problems efficiently', Icons.emoji_events),
        ReasoningOption('Local First', 'Privacy-preserving on-device reasoning', Icons.lock),
        ReasoningOption('Agentic Flow', 'Chain multiple tasks autonomously', Icons.account_tree),
      ];
    } else if (modelName.contains('Claude') || modelName.contains('GPT-4')) {
      // Advanced general models
      return [
        ReasoningOption('Analytical', 'Deep logical analysis', Icons.analytics),
        ReasoningOption('Creative Synthesis', 'Combine ideas innovatively', Icons.merge_type),
        ReasoningOption('First Principles', 'Break down to fundamentals', Icons.science),
        ReasoningOption('Systems Thinking', 'Consider interconnections', Icons.hub),
        ReasoningOption('Ethical Reasoning', 'Consider moral implications', Icons.balance),
      ];
    } else {
      // Default reasoning styles
      return [
        ReasoningOption('Analytical', 'Step-by-step logical breakdown', Icons.analytics),
        ReasoningOption('Creative', 'Innovative and exploratory approach', Icons.lightbulb),
        ReasoningOption('Systematic', 'Methodical and thorough analysis', Icons.list_alt),
        ReasoningOption('Intuitive', 'Pattern recognition and insights', Icons.psychology),
        ReasoningOption('Pragmatic', 'Focus on practical solutions', Icons.build),
      ];
    }
  }

  String _getAgentName() {
    switch (widget.selectedAgentType) {
      case 0: return 'Business Analyst AI';
      case 1: return 'Operations Manager AI';
      case 2: return 'Coding Agent AI';
      default: return 'AI Agent';
    }
  }

  String _getIngredientsTitle() {
    switch (widget.selectedAgentType) {
      case 0: return 'What data should we analyze?';
      case 1: return 'What operations should we optimize?';
      case 2: return 'What should we build?';
      default: return 'What are we working on?';
    }
  }

  String _getIngredientsDescription() {
    switch (widget.selectedAgentType) {
      case 0: return 'Add business data, reports, or research topics for comprehensive analysis and insights.';
      case 1: return 'Add schedules, processes, or operational data to streamline and optimize workflows.';
      case 2: return 'Add codebase, requirements, or technical specs to build applications and features.';
      default: return 'Add documents, data sources, or research topics for AI analysis.';
    }
  }

  void _jumpToStep(int stepIndex) {
    if (!mounted) return;
    // Only allow jumping to completed steps or the next step
    if (stepIndex <= _currentStep || stepIndex == _currentStep + 1) {
      setState(() => _currentStep = stepIndex);
      if (mounted) {
        _pageController.animateToPage(
          stepIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  String _getUploadDocumentsTitle() {
    switch (widget.selectedAgentType) {
      case 0: return 'Upload Business Data';
      case 1: return 'Upload Operation Files';
      case 2: return 'Upload Code & Docs';
      default: return 'Upload Documents';
    }
  }

  String _getUploadDocumentsSubtitle() {
    switch (widget.selectedAgentType) {
      case 0: return 'Sales reports, financial data, market analysis';
      case 1: return 'Schedules, process docs, team resources';
      case 2: return 'Codebase, requirements, API specs';
      default: return 'PDFs, Word docs, spreadsheets, etc.';
    }
  }

  IconData _getUploadDocumentsIcon() {
    switch (widget.selectedAgentType) {
      case 0: return Icons.analytics;
      case 1: return Icons.schedule;
      case 2: return Icons.code;
      default: return Icons.upload_file;
    }
  }

  String _getResearchTopicTitle() {
    switch (widget.selectedAgentType) {
      case 0: return 'Market Research';
      case 1: return 'Process Research';
      case 2: return 'Technical Research';
      default: return 'Research Topic';
    }
  }

  String _getResearchTopicSubtitle() {
    switch (widget.selectedAgentType) {
      case 0: return 'Industry trends, competitor analysis, market data';
      case 1: return 'Best practices, optimization strategies, tools';
      case 2: return 'Framework comparisons, architecture patterns, libraries';
      default: return 'Let AI research a specific topic for you';
    }
  }

  String _getResearchTopicPlaceholder() {
    switch (widget.selectedAgentType) {
      case 0: return 'e.g., "Q1 2024 SaaS market trends and competitor analysis"';
      case 1: return 'e.g., "Best practices for team scheduling optimization in remote environments"';
      case 2: return 'e.g., "Comparing React vs Vue.js performance for real-time applications"';
      default: return 'e.g., "Latest trends in AI automation"';
    }
  }

  List<ToolCategory> _getToolCategories() {
    switch (widget.selectedAgentType) {
      case 0: // Business Analyst
        return [
          ToolCategory('Analytics & BI', [
            ToolOption('Tableau', Icons.analytics),
            ToolOption('Power BI', Icons.dashboard),
            ToolOption('Looker', Icons.insights),
            ToolOption('Mixpanel', Icons.track_changes),
            ToolOption('Amplitude', Icons.show_chart),
            ToolOption('Google Analytics', Icons.trending_up),
          ]),
          ToolCategory('Data Sources', [
            ToolOption('Salesforce', Icons.cloud),
            ToolOption('HubSpot', Icons.hub),
            ToolOption('PostgreSQL', Icons.storage),
            ToolOption('MongoDB', Icons.account_tree),
            ToolOption('Snowflake', Icons.cloud_sync),
            ToolOption('BigQuery', Icons.query_stats),
          ]),
          ToolCategory('Reporting', [
            ToolOption('Excel', Icons.table_chart),
            ToolOption('Google Sheets', Icons.grid_on),
            ToolOption('Jupyter', Icons.code),
            ToolOption('R Studio', Icons.functions),
            ToolOption('Notion', Icons.description),
            ToolOption('Airtable', Icons.view_list),
          ]),
        ];
        
      case 1: // Operations Manager
        return [
          ToolCategory('Project Management', [
            ToolOption('Linear', Icons.linear_scale),
            ToolOption('Jira', Icons.bug_report),
            ToolOption('Asana', Icons.task),
            ToolOption('Monday.com', Icons.calendar_today),
            ToolOption('ClickUp', Icons.check_circle),
            ToolOption('Notion', Icons.description),
          ]),
          ToolCategory('Communication', [
            ToolOption('Slack', Icons.chat),
            ToolOption('Microsoft Teams', Icons.groups),
            ToolOption('Discord', Icons.forum),
            ToolOption('Zoom', Icons.video_call),
            ToolOption('Calendar', Icons.event),
            ToolOption('Gmail', Icons.email),
          ]),
          ToolCategory('Automation', [
            ToolOption('Zapier', Icons.link),
            ToolOption('Make.com', Icons.settings_ethernet),
            ToolOption('GitHub Actions', Icons.play_arrow),
            ToolOption('Jenkins', Icons.build),
            ToolOption('Docker', Icons.developer_board),
            ToolOption('Kubernetes', Icons.cloud_queue),
          ]),
        ];

      case 2: // Coding Agent
        return [
          ToolCategory('Development Tools', [
            ToolOption('VS Code', Icons.edit_note),
            ToolOption('GitHub', Icons.code),
            ToolOption('GitLab', Icons.merge_type),
            ToolOption('Bitbucket', Icons.source),
            ToolOption('IntelliJ IDEA', Icons.psychology),
            ToolOption('Vim', Icons.terminal),
          ]),
          ToolCategory('Testing & CI/CD', [
            ToolOption('Jest', Icons.check_circle_outline),
            ToolOption('Cypress', Icons.web),
            ToolOption('GitHub Actions', Icons.play_arrow),
            ToolOption('Jenkins', Icons.build),
            ToolOption('CircleCI', Icons.refresh),
            ToolOption('Travis CI', Icons.verified),
          ]),
          ToolCategory('Monitoring & Analytics', [
            ToolOption('Datadog', Icons.monitor_heart),
            ToolOption('New Relic', Icons.analytics),
            ToolOption('Sentry', Icons.bug_report),
            ToolOption('LogRocket', Icons.video_library),
            ToolOption('Prometheus', Icons.show_chart),
            ToolOption('Grafana', Icons.dashboard),
          ]),
          ToolCategory('Package Management', [
            ToolOption('npm', Icons.inventory_2),
            ToolOption('Yarn', Icons.category),
            ToolOption('pnpm', Icons.speed),
            ToolOption('Docker Hub', Icons.developer_board),
            ToolOption('PyPI', Icons.code),
            ToolOption('Maven', Icons.archive),
          ]),
          // Easter egg tools for fun
          ToolCategory('Legendary Tools', [
            ToolOption('Neovim BTW', Icons.terminal),
            ToolOption('Emacs OS', Icons.desktop_mac),
            ToolOption('Stack Overflow', Icons.help),
            ToolOption('Coffee', Icons.local_cafe),
            ToolOption('Rubber Duck', Icons.pets),
            ToolOption('XKCD Comics', Icons.mood),
          ]),
        ];
        
      default:
        return [
          ToolCategory('Popular Tools', [
            ToolOption('Slack', Icons.chat),
            ToolOption('Notion', Icons.description),
            ToolOption('Linear', Icons.linear_scale),
            ToolOption('Figma', Icons.design_services),
          ]),
        ];
    }
  }

  void _toggleTool(String toolName) {
    if (!mounted) return;
    setState(() {
      if (_selectedTools.contains(toolName)) {
        _selectedTools.remove(toolName);
      } else {
        _selectedTools.add(toolName);
      }
    });
  }

  List<FlowOption> _getFlowOptions() {
    switch (widget.selectedAgentType) {
      case 0: // Business Analyst
        return [
          FlowOption(
            'Analysis Report',
            'Generate comprehensive data analysis and insights',
            Icons.analytics,
            estimatedTime: '3-5 min',
            keyFeatures: ['Sales trends', 'Revenue forecasts', 'Customer retention'],
            deliverableType: 'Interactive Report',
          ),
          FlowOption(
            'Interactive Dashboard',
            'Create live dashboard artifact with visualizations',
            Icons.dashboard,
            estimatedTime: '5-7 min',
            keyFeatures: ['Real-time charts', 'KPI tracking', 'Data filtering'],
            deliverableType: 'Live Dashboard',
          ),
          FlowOption(
            'Decision Support',
            'Provide actionable recommendations for stakeholders',
            Icons.lightbulb,
            estimatedTime: '4-6 min',
            keyFeatures: ['Strategic insights', 'Risk analysis', 'Action items'],
            deliverableType: 'Decision Guide',
          ),
          FlowOption(
            'Continuous Monitoring',
            'Ongoing analysis with automated alerts',
            Icons.notifications,
            estimatedTime: '6-8 min',
            keyFeatures: ['Anomaly detection', 'Threshold alerts', 'Weekly reports'],
            deliverableType: 'Monitoring System',
          ),
        ];

      case 1: // Operations Manager
        return [
          FlowOption(
            'Automation Playbook',
            'Generate workflow automation artifacts',
            Icons.auto_awesome,
            estimatedTime: '4-6 min',
            keyFeatures: ['Process maps', 'Task automation', 'Integration guides'],
            deliverableType: 'Automation Guide',
          ),
          FlowOption(
            'Process Documentation',
            'Create comprehensive operational procedures',
            Icons.list_alt,
            estimatedTime: '5-7 min',
            keyFeatures: ['SOPs', 'Workflow diagrams', 'Best practices'],
            deliverableType: 'Documentation Set',
          ),
          FlowOption(
            'Performance Dashboard',
            'Live metrics and KPI tracking artifact',
            Icons.speed,
            estimatedTime: '5-8 min',
            keyFeatures: ['Team capacity', 'Schedule efficiency', 'Resource utilization'],
            deliverableType: 'Metrics Dashboard',
          ),
          FlowOption(
            'Continuous Optimization',
            'Ongoing process improvement and alerts',
            Icons.trending_up,
            estimatedTime: '6-9 min',
            keyFeatures: ['Performance tracking', 'Bottleneck alerts', 'Optimization recommendations'],
            deliverableType: 'Optimization Engine',
          ),
        ];

      case 2: // Coding Agent
        return [
          FlowOption(
            'Refactor Codebase',
            'Modernize and optimize existing code',
            Icons.autorenew,
            estimatedTime: '6-10 min',
            keyFeatures: ['Code cleanup', 'Performance optimization', 'Best practices'],
            deliverableType: 'Refactored Code',
          ),
          FlowOption(
            'API Development',
            'Create REST/GraphQL APIs with documentation',
            Icons.api,
            estimatedTime: '7-11 min',
            keyFeatures: ['API endpoints', 'OpenAPI docs', 'Authentication'],
            deliverableType: 'API Service',
          ),
          FlowOption(
            'Test Suite Creation',
            'Generate comprehensive unit and integration tests',
            Icons.check_circle,
            estimatedTime: '5-8 min',
            keyFeatures: ['Unit tests', 'Integration tests', 'Coverage reports'],
            deliverableType: 'Test Suite',
          ),
          FlowOption(
            'DevOps Pipeline',
            'Setup CI/CD with monitoring and deployment',
            Icons.account_tree,
            estimatedTime: '8-12 min',
            keyFeatures: ['GitHub Actions', 'Auto-deploy', 'Health checks'],
            deliverableType: 'CI/CD Pipeline',
          ),
          FlowOption(
            'Code Review Assistant',
            'Continuous code review and optimization',
            Icons.rate_review,
            estimatedTime: '4-7 min',
            keyFeatures: ['Static analysis', 'Security checks', 'Code suggestions'],
            deliverableType: 'Review System',
          ),
        ];

      default:
        return [
          FlowOption(
            'Analysis Report',
            'Generate comprehensive analysis and insights',
            Icons.analytics,
            estimatedTime: '3-5 min',
            keyFeatures: ['Data analysis', 'Trend identification', 'Insights'],
            deliverableType: 'Report',
          ),
          FlowOption(
            'Action Plan',
            'Create executable action items and next steps',
            Icons.checklist,
            estimatedTime: '4-6 min',
            keyFeatures: ['Task breakdown', 'Priorities', 'Timeline'],
            deliverableType: 'Action Plan',
          ),
          FlowOption(
            'Decision Support',
            'Provide recommendations for decision making',
            Icons.lightbulb,
            estimatedTime: '4-6 min',
            keyFeatures: ['Options analysis', 'Risk assessment', 'Recommendations'],
            deliverableType: 'Decision Guide',
          ),
          FlowOption(
            'Continuous Monitoring',
            'Ongoing analysis and alerts',
            Icons.notifications,
            estimatedTime: '5-7 min',
            keyFeatures: ['Alerts', 'Tracking', 'Reports'],
            deliverableType: 'Monitoring',
          ),
        ];
    }
  }

  String _getStepSummary() {
    switch (_currentStep) {
      case 0:
        return _ingredients.isEmpty && _researchTopic.isEmpty
            ? 'Add your documents or research topics to get started'
            : '${_ingredients.length} documents${_researchTopic.isNotEmpty ? ' + research topic' : ''} added';
      case 1:
        return _selectedModel == null || _reasoningStyle == null
            ? 'Select your AI model and reasoning approach'
            : 'Using $_selectedModel with $_reasoningStyle style';
      case 2:
        return _selectedTools.isEmpty
            ? 'Choose tools for integration and workflow'
            : '${_selectedTools.length} tools selected';
      case 3:
        return 'Confidence threshold: ${(_confidenceThreshold * 100).toInt()}%${_humanVerificationEnabled ? ', Human verification enabled' : ''}';
      case 4:
        return _flowType == null
            ? 'Choose how your agent should complete tasks'
            : 'Flow type: $_flowType';
      default:
        return '';
    }
  }
}

// Data models
class OnboardingData {
  final List<IngredientItem> ingredients;
  final String researchTopic;
  final String selectedModel;
  final String reasoningStyle;
  final List<String> selectedTools;
  final double confidenceThreshold;
  final bool humanVerificationEnabled;
  final String flowType;
  final Map<String, dynamic> flowOptions;

  OnboardingData({
    required this.ingredients,
    required this.researchTopic,
    required this.selectedModel,
    required this.reasoningStyle,
    required this.selectedTools,
    required this.confidenceThreshold,
    required this.humanVerificationEnabled,
    required this.flowType,
    required this.flowOptions,
  });
}

enum IngredientType { document, research }

class IngredientItem {
  final IngredientType type;
  final String title;
  final String subtitle;
  final IconData icon;

  IngredientItem({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IngredientItem &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          title == other.title;

  @override
  int get hashCode => type.hashCode ^ title.hashCode;
}

class ModelOption {
  final String name;
  final String description;
  final String provider;

  ModelOption(this.name, this.description, this.provider);
}

class ReasoningOption {
  final String name;
  final String description;
  final IconData icon;

  ReasoningOption(this.name, this.description, this.icon);
}

class FlowOption {
  final String name;
  final String description;
  final IconData icon;
  final String estimatedTime;
  final List<String> keyFeatures;
  final String deliverableType;

  FlowOption(
    this.name,
    this.description,
    this.icon, {
    this.estimatedTime = '~5 min',
    this.keyFeatures = const [],
    this.deliverableType = 'Artifact',
  });
}

class StepInfo {
  final String title;
  final String subtitle;
  final IconData icon;

  StepInfo(this.title, this.subtitle, this.icon);
}

class ToolCategory {
  final String name;
  final List<ToolOption> tools;

  ToolCategory(this.name, this.tools);
}

class ToolOption {
  final String name;
  final IconData icon;

  ToolOption(this.name, this.icon);
}
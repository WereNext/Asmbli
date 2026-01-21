import 'package:flutter/material.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import '../core/design_system/design_system.dart';
import '../core/constants/routes.dart';

/// Onboarding screen for demo that lets users select an agent type
class DemoOnboarding extends StatefulWidget {
  const DemoOnboarding({super.key});

  @override
  State<DemoOnboarding> createState() => _DemoOnboardingState();
}

class _DemoOnboardingState extends State<DemoOnboarding> 
    with TickerProviderStateMixin {
  
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  
  int _currentStep = 0;
  int? _selectedAgent;
  int _currentFeatureIndex = 0;
  
  final PageController _pageController = PageController();
  
  final List<AgentTemplate> _agentTemplates = [
    AgentTemplate(
      id: 0,
      name: 'Business Analyst',
      icon: Icons.analytics,
      color: const Color(0xFF4ECDC4),
      description: 'Transform data into insights with AI-powered analysis',
      features: [
        'Real-time data visualization',
        'Predictive analytics',
        'Automated reporting',
        'Trend identification',
      ],
      tooltips: [
        'Watch how confidence monitoring prevents hallucinations',
        'See multi-model consensus in action',
        'Experience seamless tool integration',
      ],
    ),
    AgentTemplate(
      id: 1,
      name: 'Operations Manager',
      icon: Icons.schedule,
      color: const Color(0xFF4E5DC0),
      description: 'Streamline operations with intelligent scheduling and notifications',
      features: [
        'Smart scheduling optimization',
        'Automated notifications',
        'Resource allocation',
        'Operational monitoring',
      ],
      tooltips: [
        'Experience intelligent operations automation',
        'See smart scheduling and notifications in action',
        'Optimize resources and workflows',
      ],
    ),
    AgentTemplate(
      id: 2,
      name: 'Coding Agent',
      icon: Icons.code,
      color: const Color(0xFF9B59B6),
      description: 'AI pair programming with real-time code generation and git integration',
      features: [
        'Intelligent code generation',
        'Git workflow automation',
        'Live preview & testing',
        'Code review assistance',
      ],
      tooltips: [
        'Experience AI-powered development workflows',
        'See code generation with git integration',
        'Watch live preview updates as you code',
      ],
    ),
  ];
  
  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));
    
    _fadeController.forward();
    _scaleController.forward();
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _slideController.dispose();
    _pageController.dispose();
    super.dispose();
  }
  
  void _selectAgent(int index) {
    final agent = _agentTemplates[index];

    showDialog(
      context: context,
      builder: (context) => _AgentCapabilityModal(
        agent: agent,
        onStartBuilding: () {
          Navigator.of(context).pop();
          context.go('${AppRoutes.controlledOnboarding}?agentType=$index');
        },
        onChooseDifferent: () {
          Navigator.of(context).pop();
        },
      ),
    );
  }
  
  void _nextStep() {
    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
      });
      
      _slideController.forward().then((_) {
        if (_currentStep == 2) {
          // Start feature showcase
          _slideController.reset();
          _showcaseFeatures();
        }
      });
    }
  }
  
  void _showcaseFeatures() async {
    if (_selectedAgent == null) return;
    
    final features = _agentTemplates[_selectedAgent!].features;
    
    for (int i = 0; i < features.length; i++) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        setState(() {
          _currentFeatureIndex = i;
        });
        _slideController.forward().then((_) {
          _slideController.reset();
        });
      }
    }
    
    // Show launch button after all features
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() {
        _currentStep = 3;
      });
    }
  }
  
  void _launchDemo() {
    if (_selectedAgent == null) return;
    
    print('🚀 Launching demo for agent type: $_selectedAgent');
    
    // Navigate to unified demo with selected agent context using GoRouter
    context.go('${AppRoutes.demoUnified}?agentType=$_selectedAgent');
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
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              FadeTransition(
                opacity: _fadeAnimation,
                child: _buildCurrentStep(colors),
              ),
              // Theme toggle in top-right corner
              Positioned(
                top: SpacingTokens.lg,
                right: SpacingTokens.lg,
                child: const ThemeToggle(),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildCurrentStep(ThemeColors colors) {
    switch (_currentStep) {
      case 0:
        return _buildWelcomeStep(colors);
      case 1:
        return _buildAgentSelectionStep(colors);
      case 2:
        return _buildFeatureShowcaseStep(colors);
      case 3:
        return _buildLaunchStep(colors);
      default:
        return _buildWelcomeStep(colors);
    }
  }
  
  Widget _buildWelcomeStep(ThemeColors colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildHeader(colors),
          const SizedBox(height: SpacingTokens.xxl),
          Text(
            'Let\'s explore what AI agents can do for you',
            style: TextStyles.bodyLarge.copyWith(
              color: colors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: SpacingTokens.xxl),
          AsmblButton.primary(
            text: 'Get Started',
            onPressed: _nextStep,
            icon: Icons.arrow_forward,
          ),
        ],
      ),
    );
  }
  
  Widget _buildAgentSelectionStep(ThemeColors colors) {
    return Column(
      children: [
        const SizedBox(height: SpacingTokens.xxl),
        Text(
          'Choose Your AI Agent',
          style: TextStyles.pageTitle.copyWith(
            color: colors.onSurface,
            fontSize: 28,
          ),
        ),
        const SizedBox(height: SpacingTokens.md),
        Text(
          'Each agent specializes in different capabilities',
          style: TextStyles.bodyLarge.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: SpacingTokens.xxl),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: SpacingTokens.xl,
                runSpacing: SpacingTokens.xl,
                children: _agentTemplates.map((template) => 
                  _buildSimpleAgentCard(template, colors)
                ).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildFeatureShowcaseStep(ThemeColors colors) {
    if (_selectedAgent == null) return Container();
    
    final agent = _agentTemplates[_selectedAgent!];
    final currentFeature = agent.features[_currentFeatureIndex];
    
    return SlideTransition(
      position: _slideAnimation,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: agent.color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                agent.icon,
                size: 40,
                color: agent.color,
              ),
            ),
            const SizedBox(height: SpacingTokens.xl),
            Text(
              agent.name,
              style: TextStyles.pageTitle.copyWith(
                color: colors.onSurface,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: SpacingTokens.xxl),
            Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(SpacingTokens.xl),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(BorderRadiusTokens.xl),
                border: Border.all(color: agent.color, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: agent.color.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: agent.color,
                    size: 32,
                  ),
                  const SizedBox(height: SpacingTokens.lg),
                  Text(
                    currentFeature,
                    style: TextStyles.sectionTitle.copyWith(
                      color: colors.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLaunchStep(ThemeColors colors) {
    if (_selectedAgent == null) return Container();
    
    final agent = _agentTemplates[_selectedAgent!];
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [agent.color, colors.accent],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: agent.color.withOpacity(0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              Icons.rocket_launch,
              size: 50,
              color: colors.surface,
            ),
          ),
          const SizedBox(height: SpacingTokens.xxl),
          Text(
            'Ready to Launch!',
            style: TextStyles.pageTitle.copyWith(
              color: colors.onSurface,
              fontSize: 32,
            ),
          ),
          const SizedBox(height: SpacingTokens.md),
          Text(
            'Your ${agent.name} is configured and ready to go',
            style: TextStyles.bodyLarge.copyWith(
              color: colors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: SpacingTokens.xxl),
          AsmblButton.primary(
            text: 'Launch ${agent.name}',
            onPressed: _launchDemo,
            icon: Icons.play_arrow,
          ),
        ],
      ),
    );
  }
  
  Widget _buildSimpleAgentCard(AgentTemplate template, ThemeColors colors) {
    return GestureDetector(
      onTap: () => _selectAgent(template.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 250,
        height: 320, // Increased height to prevent overflow
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(BorderRadiusTokens.xl),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(SpacingTokens.lg), // Reduced padding
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min, // Prevent overflow
            children: [
              Container(
                width: 56, // Slightly smaller icon
                height: 56,
                decoration: BoxDecoration(
                  color: template.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
                ),
                child: Icon(
                  template.icon,
                  size: 28,
                  color: template.color,
                ),
              ),
              const SizedBox(height: SpacingTokens.md), // Reduced spacing
              Flexible(
                child: Text(
                  template.name,
                  style: TextStyles.sectionTitle.copyWith(
                    color: colors.onSurface,
                    fontSize: 18, // Slightly smaller font
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: SpacingTokens.sm), // Reduced spacing
              Flexible(
                child: Text(
                  template.description,
                  style: TextStyles.bodyMedium.copyWith(
                    color: colors.onSurfaceVariant,
                    fontSize: 13, // Smaller description font
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: SpacingTokens.md), // Reduced spacing
              AsmblButton.outline(
                text: 'Select',
                onPressed: () => _selectAgent(template.id),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader(ThemeColors colors) {
    return Column(
      children: [
        // Logo placeholder
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colors.primary, colors.accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: colors.primary.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            Icons.auto_awesome,
            size: 40,
            color: colors.surface,
          ),
        ),
        
        const SizedBox(height: SpacingTokens.lg),
        
        Text(
          'Welcome to Asmbli',
          style: TextStyles.pageTitle.copyWith(
            color: colors.onSurface,
            fontSize: 32,
          ),
        ),
        
        const SizedBox(height: SpacingTokens.sm),
        
        Text(
          'Experience the future of AI agent collaboration',
          style: TextStyles.bodyLarge.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
  
}

class AgentTemplate {
  final int id;
  final String name;
  final IconData icon;
  final Color color;
  final String description;
  final List<String> features;
  final List<String> tooltips;

  const AgentTemplate({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.description,
    required this.features,
    required this.tooltips,
  });
}

/// Modal that shows agent capabilities with progressive disclosure
class _AgentCapabilityModal extends StatefulWidget {
  final AgentTemplate agent;
  final VoidCallback onStartBuilding;
  final VoidCallback onChooseDifferent;

  const _AgentCapabilityModal({
    required this.agent,
    required this.onStartBuilding,
    required this.onChooseDifferent,
  });

  @override
  State<_AgentCapabilityModal> createState() => _AgentCapabilityModalState();
}

class _AgentCapabilityModalState extends State<_AgentCapabilityModal> {
  int _expandedSection = 0; // 0 = capabilities, 1 = steps, 2 = experience

  @override
  Widget build(BuildContext context) {
    final colors = ThemeColors(context);

    // Get capabilities for this agent
    final capabilities = _getCapabilitiesForAgent(widget.agent.id);
    final wizardSteps = _getWizardSteps();

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 700,
          maxHeight: 600,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(BorderRadiusTokens.xl),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _buildHeader(colors),

            // Content - Scrollable expandable sections
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.xxl,
                  vertical: SpacingTokens.lg,
                ),
                child: Column(
                  children: [
                    // Section 1: What This Agent Can Do
                    _buildExpandableSection(
                      colors: colors,
                      sectionIndex: 0,
                      title: 'What This Agent Can Do',
                      icon: Icons.auto_awesome,
                      content: _buildCapabilitiesList(colors, capabilities),
                    ),
                    const SizedBox(height: SpacingTokens.lg),

                    // Section 2: Configuration Steps
                    _buildExpandableSection(
                      colors: colors,
                      sectionIndex: 1,
                      title: 'Configuration Steps',
                      icon: Icons.settings,
                      content: _buildWizardStepsList(colors, wizardSteps),
                    ),
                    const SizedBox(height: SpacingTokens.lg),

                    // Section 3: What You'll Experience
                    _buildExpandableSection(
                      colors: colors,
                      sectionIndex: 2,
                      title: "What You'll Experience",
                      icon: Icons.lightbulb_outline,
                      content: _buildExperienceList(colors),
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            _buildFooter(colors),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeColors colors) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            widget.agent.color.withOpacity(0.2),
            widget.agent.color.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(BorderRadiusTokens.xl),
          topRight: Radius.circular(BorderRadiusTokens.xl),
        ),
      ),
      padding: const EdgeInsets.all(SpacingTokens.xxl),
      child: Row(
        children: [
          // Agent Icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: widget.agent.color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
            ),
            child: Icon(
              widget.agent.icon,
              size: 28,
              color: widget.agent.color,
            ),
          ),
          const SizedBox(width: SpacingTokens.lg),

          // Agent Name & Description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.agent.name,
                  style: TextStyles.sectionTitle.copyWith(
                    color: colors.onSurface,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: SpacingTokens.xs),
                Text(
                  widget.agent.description,
                  style: TextStyles.bodyMedium.copyWith(
                    color: colors.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Close Button
          IconButton(
            icon: Icon(Icons.close, color: colors.onSurfaceVariant),
            onPressed: widget.onChooseDifferent,
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableSection({
    required ThemeColors colors,
    required int sectionIndex,
    required String title,
    required IconData icon,
    required Widget content,
  }) {
    final isExpanded = _expandedSection == sectionIndex;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
        border: Border.all(
          color: isExpanded ? widget.agent.color : colors.border,
          width: isExpanded ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          // Clickable Header
          InkWell(
            onTap: () {
              setState(() {
                _expandedSection = sectionIndex;
              });
            },
            borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
            child: Padding(
              padding: const EdgeInsets.all(SpacingTokens.lg),
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: isExpanded ? widget.agent.color : colors.onSurfaceVariant,
                    size: 20,
                  ),
                  const SizedBox(width: SpacingTokens.md),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyles.cardTitle.copyWith(
                        color: isExpanded ? colors.onSurface : colors.onSurfaceVariant,
                        fontWeight: isExpanded ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),

          // Expandable Content
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: isExpanded
                ? Padding(
                    padding: const EdgeInsets.only(
                      left: SpacingTokens.lg,
                      right: SpacingTokens.lg,
                      bottom: SpacingTokens.lg,
                    ),
                    child: content,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildCapabilitiesList(
    ThemeColors colors,
    List<AgentCapability> capabilities,
  ) {
    return Column(
      children: capabilities.map((capability) {
        return Padding(
          padding: const EdgeInsets.only(bottom: SpacingTokens.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                capability.icon,
                size: 20,
                color: widget.agent.color,
              ),
              const SizedBox(width: SpacingTokens.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      capability.title,
                      style: TextStyles.bodyMedium.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: SpacingTokens.xs),
                    Text(
                      capability.description,
                      style: TextStyles.bodySmall.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWizardStepsList(
    ThemeColors colors,
    List<WizardStepInfo> steps,
  ) {
    return Column(
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: SpacingTokens.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step Number Badge
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: widget.agent.color.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.agent.color,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyles.bodySmall.copyWith(
                      color: widget.agent.color,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: SpacingTokens.md),

              // Icon
              Icon(
                step.icon,
                size: 20,
                color: widget.agent.color,
              ),
              const SizedBox(width: SpacingTokens.md),

              // Title & Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: TextStyles.bodyMedium.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: SpacingTokens.xs),
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
        );
      }),
    );
  }

  Widget _buildExperienceList(ThemeColors colors) {
    final experiences = [
      'Interactive demo walkthrough with real-time agent responses',
      'See how confidence monitoring prevents hallucinations',
      'Experience seamless tool integration and workflow automation',
    ];

    return Column(
      children: experiences.map((experience) {
        return Padding(
          padding: const EdgeInsets.only(bottom: SpacingTokens.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_circle,
                size: 20,
                color: widget.agent.color,
              ),
              const SizedBox(width: SpacingTokens.md),
              Expanded(
                child: Text(
                  experience,
                  style: TextStyles.bodyMedium.copyWith(
                    color: colors.onSurface,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFooter(ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.xxl),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colors.border),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          AsmblButton.secondary(
            text: 'Choose Different Agent',
            onPressed: widget.onChooseDifferent,
          ),
          AsmblButton.primary(
            text: 'Start Building',
            onPressed: widget.onStartBuilding,
            icon: Icons.arrow_forward,
          ),
        ],
      ),
    );
  }

  // Get capabilities based on agent type
  List<AgentCapability> _getCapabilitiesForAgent(int agentId) {
    switch (agentId) {
      case 0: // Business Analyst
        return [
          const AgentCapability(
            icon: Icons.analytics,
            title: 'Data Analysis & Insights',
            description: 'Transform raw data into actionable insights with AI-powered analytics',
          ),
          const AgentCapability(
            icon: Icons.dashboard,
            title: 'Interactive Dashboards',
            description: 'Create real-time visualizations and monitoring dashboards',
          ),
          const AgentCapability(
            icon: Icons.lightbulb,
            title: 'Strategic Recommendations',
            description: 'Get AI-driven recommendations based on data patterns',
          ),
          const AgentCapability(
            icon: Icons.notifications_active,
            title: 'Automated Monitoring',
            description: 'Set up intelligent alerts for key metrics and anomalies',
          ),
          const AgentCapability(
            icon: Icons.trending_up,
            title: 'Predictive Analytics',
            description: 'Forecast trends and identify opportunities before they emerge',
          ),
        ];
      case 1: // Operations Manager
        return [
          const AgentCapability(
            icon: Icons.schedule,
            title: 'Smart Scheduling',
            description: 'Optimize schedules and resource allocation intelligently',
          ),
          const AgentCapability(
            icon: Icons.auto_awesome,
            title: 'Workflow Automation',
            description: 'Automate repetitive tasks and streamline operations',
          ),
          const AgentCapability(
            icon: Icons.speed,
            title: 'Performance Tracking',
            description: 'Monitor and optimize operational efficiency in real-time',
          ),
          const AgentCapability(
            icon: Icons.warning_amber,
            title: 'Proactive Alerts',
            description: 'Get notified of issues before they become critical',
          ),
          const AgentCapability(
            icon: Icons.integration_instructions,
            title: 'Tool Integration',
            description: 'Connect with your existing tools and workflows seamlessly',
          ),
        ];
      case 2: // Coding Agent
        return [
          const AgentCapability(
            icon: Icons.code,
            title: 'Intelligent Code Generation',
            description: 'Generate high-quality code with AI-powered suggestions',
          ),
          const AgentCapability(
            icon: Icons.check_circle,
            title: 'Automated Testing',
            description: 'Create comprehensive tests automatically for your code',
          ),
          const AgentCapability(
            icon: Icons.commit,
            title: 'Git Workflow Automation',
            description: 'Streamline version control with intelligent git operations',
          ),
          const AgentCapability(
            icon: Icons.rocket_launch,
            title: 'CI/CD Pipeline Setup',
            description: 'Configure continuous integration and deployment pipelines',
          ),
          const AgentCapability(
            icon: Icons.security,
            title: 'Code Quality & Security',
            description: 'Ensure best practices and security standards automatically',
          ),
        ];
      default:
        // Fallback - should never reach here with proper agent IDs
        return [];
    }
  }

  // Get wizard steps (same for all agents)
  List<WizardStepInfo> _getWizardSteps() {
    return const [
      WizardStepInfo(
        icon: Icons.upload_file,
        title: 'Add Ingredients',
        subtitle: 'Upload documents or add research topics',
      ),
      WizardStepInfo(
        icon: Icons.psychology,
        title: 'Select Model',
        subtitle: 'Choose AI model and reasoning style (local or cloud)',
      ),
      WizardStepInfo(
        icon: Icons.build,
        title: 'Choose Tools',
        subtitle: 'Select integration and workflow tools',
      ),
      WizardStepInfo(
        icon: Icons.tune,
        title: 'Set Confidence',
        subtitle: 'Configure thresholds and human verification',
      ),
      WizardStepInfo(
        icon: Icons.settings_applications,
        title: 'Configure Flow',
        subtitle: 'Define deliverables and completion criteria',
      ),
    ];
  }
}

/// Data model for agent capabilities
class AgentCapability {
  final IconData icon;
  final String title;
  final String description;

  const AgentCapability({
    required this.icon,
    required this.title,
    required this.description,
  });
}

/// Data model for wizard step information
class WizardStepInfo {
  final IconData icon;
  final String title;
  final String subtitle;

  const WizardStepInfo({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}
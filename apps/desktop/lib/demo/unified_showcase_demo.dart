import 'package:flutter/material.dart';
import 'dart:async';
import '../core/design_system/design_system.dart';
import 'components/enhanced_ai_reasoning_simulator.dart';
import 'components/confidence_indicator.dart';
import 'components/demo_container.dart';
import 'components/asmbli_demo_chat.dart';
import 'components/demo_completion_celebration.dart';
import 'components/task_completion_review.dart';
import 'components/demo_code_editor.dart';
import 'models/demo_models.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/routes.dart';

/// Workspace artifact model for additive demo interactions
class WorkspaceArtifact {
  final String id;
  final String type; // 'analysis', 'chart', 'schedule', 'code', 'dashboard'
  final String title;
  final Widget content;
  final DateTime timestamp;
  final int
      agentType; // 0: Business Analyst, 1: Operations Manager, 2: Coding Agent

  WorkspaceArtifact({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.timestamp,
    required this.agentType,
  });
}

/// Unified showcase demo combining all key Asmbli features
///
/// Features demonstrated:
/// - Multi-agent orchestration (sales, support, analytics, design)
/// - Real-time confidence monitoring and intervention
/// - Canvas integration for visual outputs
/// - MCP tool integration
/// - Conversational UI with context awareness
class UnifiedShowcaseDemo extends StatefulWidget {
  final int? selectedAgentType;
  final String? selectedDeliverable;
  final double confidenceThreshold;
  final bool humanVerificationEnabled;

  const UnifiedShowcaseDemo({
    super.key,
    this.selectedAgentType,
    this.selectedDeliverable,
    this.confidenceThreshold = 0.8,
    this.humanVerificationEnabled = true,
  });

  @override
  State<UnifiedShowcaseDemo> createState() => _UnifiedShowcaseDemoState();
}

class _UnifiedShowcaseDemoState extends State<UnifiedShowcaseDemo>
    with TickerProviderStateMixin {
  // Demo scenario stages
  int _currentStage = 0;
  final List<DemoStage> _stages = [
    DemoStage(
      title: 'Multi-Agent Task Delegation',
      description: 'Watch AI agents collaborate on a complex project',
      icon: Icons.hub,
      duration: const Duration(seconds: 30),
    ),
    DemoStage(
      title: 'Confidence Monitoring & Intervention',
      description:
          'See how Asmbli handles uncertainty and requests human input',
      icon: Icons.psychology,
      duration: const Duration(seconds: 25),
    ),
    DemoStage(
      title: 'Visual Design Generation',
      description: 'From conversation to live UI in seconds',
      icon: Icons.palette,
      duration: const Duration(seconds: 35),
    ),
    DemoStage(
      title: 'MCP Tool Integration',
      description: 'External tools working seamlessly with agents',
      icon: Icons.extension,
      duration: const Duration(seconds: 20),
    ),
  ];

  // Demo control
  bool _isPlaying =
      false; // Start paused - user controls progression via chat interactions
  Timer? _stageTimer;

  // Active agents in the demo
  final Map<String, AgentInfo> _activeAgents = {
    'analyst': AgentInfo(
      name: 'Business Analyst AI',
      icon: Icons.analytics,
      color: const Color(0xFFFFE66D),
      confidence: 0.95,
    ),
    'operations-manager': AgentInfo(
      name: 'Operations Manager AI',
      icon: Icons.schedule,
      color: const Color(0xFF4ECDC4),
      confidence: 0.94,
    ),
    'coder': AgentInfo(
      name: 'Coding Agent',
      icon: Icons.code,
      color: const Color(0xFF9B59B6),
      confidence: 0.92,
    ),
  };

  bool _showCanvas = false;
  bool _interventionActive = false;
  int _canvasStage = 0; // 0: empty, 1: wireframe, 2: styled, 3: interactive
  bool _showCompletionScreen = false;
  bool _demoCompleted = false;

  // Action context tracking
  String? _currentActionContext;
  List<String> _actionHistory = [];

  // Additive artifact system - each demo action adds to this list
  List<WorkspaceArtifact> _workspaceArtifacts = [];
  final ScrollController _workspaceScrollController = ScrollController();

  // Excalidraw canvas state
  final GlobalKey _excalidrawKey = GlobalKey();
  bool _canvasHasContent = false;
  String? _currentDrawingData;

  // Verification modal state
  VerificationRequest? _currentVerification;
  EnhancedVerificationRequest? _currentEnhancedVerification;
  bool _showVerificationModal = false;
  bool _showChatInModal = false;
  late AnimationController _modalController;
  late Animation<double> _modalAnimation;

  // Code editor state
  bool _showCodeEditor = false;

  // Helper to get coding agent deliverable type for dynamic content
  String get _codingDeliverableType {
    final d = widget.selectedDeliverable?.toLowerCase() ?? '';
    if (d.contains('refactor')) return 'refactor';
    if (d.contains('api')) return 'api';
    if (d.contains('test')) return 'test';
    if (d.contains('ci') || d.contains('cd') || d.contains('devops') || d.contains('pipeline')) return 'devops';
    if (d.contains('review')) return 'review';
    return 'refactor'; // default
  }

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _customizeForAgentType();
    // _startDemo() removed - demo is now fully chat-driven without automatic progression
  }

  void _initializeAnimations() {
    _modalController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _modalAnimation = CurvedAnimation(
      parent: _modalController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _stageTimer?.cancel();
    _modalController.dispose();
    super.dispose();
  }

  void _customizeForAgentType() {
    // Reset all canvas and editor states to initial state
    _canvasStage = 0;
    _showCanvas = false;
    _showCodeEditor = false;
    _currentActionContext = null;
    _actionHistory.clear();

    // Customize demo based on selected agent type
    switch (widget.selectedAgentType) {
      case 0: // Business Analyst
        _activeAgents['analyst']!.confidence = 0.98;
        _stages[0] = DemoStage(
          title: 'Data Analysis & Insights',
          description: 'Watch AI transform raw data into actionable insights',
          icon: Icons.analytics,
          duration: const Duration(seconds: 30),
        );
        break;
      case 1: // Operations Manager
        _activeAgents['operations-manager']!.confidence = 0.94;
        _stages[0] = DemoStage(
          title: 'Smart Operations Automation',
          description:
              'Intelligent scheduling, notifications, and resource optimization',
          icon: Icons.schedule,
          duration: const Duration(seconds: 35),
        );
        break;
      case 2: // Coding Agent
        _showCodeEditor = false; // Will be shown when user starts coding
        _activeAgents['coder'] = AgentInfo(
          name: 'Coding Agent',
          icon: Icons.code,
          color: const Color(0xFF9B59B6),
          confidence: 0.92,
        );
        _stages[0] = DemoStage(
          title: 'AI-Powered Development',
          description: 'Intelligent code generation with git integration',
          icon: Icons.code,
          duration: const Duration(seconds: 35),
        );
        break;
    }
  }

  void _startDemo() {
    // Start with a gentle delay, then begin smooth progression
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _progressToNextStage();
    });
  }

  void _progressToNextStage() {
    // Timer-based progression disabled - demo is now fully chat-driven
    // User interactions in the chat trigger canvas updates directly via _handleCanvasUpdate
    // This method is kept for compatibility but does nothing
  }

  void _handleCanvasUpdate(String stage, {String? actionContext}) {
    debugPrint(
        '🔄 _handleCanvasUpdate called with stage: $stage, actionContext: $actionContext');
    debugPrint('🔄 Current agent type: ${widget.selectedAgentType}');
    debugPrint(
        '🔄 Current _currentActionContext before: $_currentActionContext');

    if (mounted) {
      setState(() {
        // Track action context - this is the KEY state that drives workspace rendering
        if (actionContext != null) {
          _currentActionContext = actionContext;
          _actionHistory.add(actionContext);
          debugPrint('🔄 Set _currentActionContext to: $_currentActionContext');

          // Create additive artifacts based on agent type and stage
          _createArtifactForStage(stage, actionContext);
        }

        // Handle agent-specific state changes
        if (widget.selectedAgentType == 2) {
          // Coding Agent
          switch (stage) {
            case 'show_editor':
              _showCodeEditor = true;
              debugPrint('🔄 Set _showCodeEditor = true');
              break;
            case 'git_commit':
              // Code editor will handle git commit animation
              debugPrint('🔄 Handling git_commit stage');
              break;
          }
        }

        // For other agents, log the stage for debugging
        debugPrint(
            '🔄 Stage handled: $stage for agent type ${widget.selectedAgentType}');
      });

      // Auto-scroll to bottom to show new artifact
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_workspaceScrollController.hasClients) {
          _workspaceScrollController.animateTo(
            _workspaceScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });

      debugPrint('🔄 setState completed, UI should rebuild now');
    }
  }

  void _createArtifactForStage(String stage, String actionContext) {
    final colors = ThemeColors(context);
    final timestamp = DateTime.now();
    final agentType = widget.selectedAgentType ?? 0;

    Widget artifactContent;
    String artifactTitle;
    String artifactType;

    // Create artifacts based on agent type and stage
    if (agentType == 0) {
      // Business Analyst
      switch (stage) {
        case 'data_analysis':
          artifactType = 'analysis';
          artifactTitle = 'Sales Data Analysis';
          artifactContent = _buildDataAnalysisArtifact(colors);
          break;
        case 'report_generated':
          artifactType = 'report';
          artifactTitle = 'Executive Summary Report';
          artifactContent = _buildReportArtifact(colors);
          break;
        case 'dashboard_deployed':
          artifactType = 'dashboard';
          artifactTitle = 'Live Analytics Dashboard';
          artifactContent = _buildDashboardArtifact(colors);
          break;
        // Follow-up artifacts
        case 'retention_analysis':
          artifactType = 'analysis';
          artifactTitle = actionContext;
          artifactContent = _buildFollowUpArtifact(colors,
              'Customer retention analysis with Q1 forecasting complete. Enterprise segment shows strongest performance with 94% retention.');
          break;
        case 'competitive_analysis':
          artifactType = 'analysis';
          artifactTitle = actionContext;
          artifactContent = _buildFollowUpArtifact(colors,
              'Competitive landscape mapped. Positioned to capture 30% market share by Q3 with strategic enterprise focus.');
          break;
        case 'channel_performance':
          artifactType = 'analysis';
          artifactTitle = actionContext;
          artifactContent = _buildFollowUpArtifact(colors,
              'Marketing channels analyzed. Content marketing and partner referrals identified as top performers with highest LTV.');
          break;
        default:
          return;
      }
    } else if (agentType == 1) {
      // Operations Manager
      switch (stage) {
        case 'schedule_analysis':
          artifactType = 'analysis';
          artifactTitle = 'Schedule Conflict Analysis';
          artifactContent = _buildScheduleAnalysisArtifact(colors);
          break;
        case 'schedule_optimized':
          artifactType = 'schedule';
          artifactTitle = 'Optimized Schedule';
          artifactContent = _buildOptimizedScheduleArtifact(colors);
          break;
        case 'monitoring_active':
          artifactType = 'monitoring';
          artifactTitle = 'Real-Time Monitoring';
          artifactContent = _buildMonitoringArtifact(colors);
          break;
        // Follow-up artifacts
        case 'automation_added':
          artifactType = 'automation';
          artifactTitle = actionContext;
          artifactContent = _buildFollowUpArtifact(colors,
              'Automated reminders configured for weekly team reviews. PM system integration active with Jira/Asana sync.');
          break;
        case 'alerts_configured':
          artifactType = 'alerts';
          artifactTitle = actionContext;
          artifactContent = _buildFollowUpArtifact(colors,
              'Capacity monitoring system deployed. Real-time alerts trigger at 90% capacity with predictive warnings 48hrs in advance.');
          break;
        case 'metrics_dashboard':
          artifactType = 'dashboard';
          artifactTitle = actionContext;
          artifactContent = _buildFollowUpArtifact(colors,
              'Performance tracking dashboard live. Schedule efficiency improved 18%, team idle time reduced 34%.');
          break;
        default:
          return;
      }
    } else if (agentType == 2) {
      // Coding Agent
      switch (stage) {
        case 'show_editor':
          artifactType = 'code';
          artifactTitle = 'Code Generation';
          artifactContent = _buildCodeEditorArtifact(colors);
          break;
        case 'code_updated':
          artifactType = 'code';
          artifactTitle = 'Code Refinement';
          artifactContent = _buildCodeUpdateArtifact(colors);
          break;
        case 'git_commit':
          artifactType = 'git';
          artifactTitle = 'Git Commit';
          artifactContent = _buildGitCommitArtifact(colors);
          break;
        // Follow-up artifacts
        case 'tests_added':
          artifactType = 'tests';
          artifactTitle = actionContext;
          artifactContent = _buildFollowUpArtifact(colors,
              'Comprehensive test suite added. Coverage increased from 62% to 98%. All 24 new tests passing.');
          break;
        case 'caching_implemented':
          artifactType = 'optimization';
          artifactTitle = actionContext;
          artifactContent = _buildFollowUpArtifact(colors,
              'Intelligent caching deployed. API calls reduced 78%, page load time improved from 2.1s to 0.4s (80% faster).');
          break;
        case 'cicd_configured':
          artifactType = 'cicd';
          artifactTitle = actionContext;
          artifactContent = _buildFollowUpArtifact(colors,
              'CI/CD pipeline configured with GitHub Actions. Automated testing, security scans, and zero-downtime deployments active.');
          break;
        case 'code_followup':
          // Generic follow-up for all coding agent deliverable types
          artifactType = 'code';
          artifactTitle = actionContext;
          artifactContent = _buildCodingFollowUpArtifact(colors, actionContext);
          break;
        default:
          return;
      }
    } else {
      return;
    }

    // Add the artifact to the list
    final artifact = WorkspaceArtifact(
      id: 'artifact_${timestamp.millisecondsSinceEpoch}',
      type: artifactType,
      title: artifactTitle,
      content: artifactContent,
      timestamp: timestamp,
      agentType: agentType,
    );

    _workspaceArtifacts.add(artifact);
    debugPrint(
        '✅ Added artifact: $artifactTitle (${_workspaceArtifacts.length} total)');
  }

  // Generic follow-up artifact builder
  Widget _buildFollowUpArtifact(ThemeColors colors, String summary) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: colors.success, size: 20),
              const SizedBox(width: SpacingTokens.sm),
              Text(
                'Enhancement Complete',
                style:
                    TextStyles.sectionTitle.copyWith(color: colors.onSurface),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.md),
          Container(
            padding: const EdgeInsets.all(SpacingTokens.md),
            decoration: BoxDecoration(
              color: colors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
              border: Border.all(color: colors.success.withValues(alpha: 0.3)),
            ),
            child: Text(
              summary,
              style: TextStyles.bodyMedium.copyWith(color: colors.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  // Coding agent follow-up artifact builder with code snippet
  Widget _buildCodingFollowUpArtifact(ThemeColors colors, String actionContext) {
    // Get summary and code sample based on action context
    final config = _getCodingFollowUpConfig(actionContext);

    return Container(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: colors.success, size: 20),
              const SizedBox(width: SpacingTokens.sm),
              Expanded(
                child: Text(
                  config['title'] as String,
                  style: TextStyles.sectionTitle.copyWith(color: colors.onSurface),
                ),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.md),
          Container(
            padding: const EdgeInsets.all(SpacingTokens.md),
            decoration: BoxDecoration(
              color: colors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
              border: Border.all(color: colors.success.withValues(alpha: 0.3)),
            ),
            child: Text(
              config['summary'] as String,
              style: TextStyles.bodyMedium.copyWith(color: colors.onSurface),
            ),
          ),
          const SizedBox(height: SpacingTokens.md),
          // Code snippet preview
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(SpacingTokens.md),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.code, size: 14, color: colors.primary),
                    const SizedBox(width: SpacingTokens.xs),
                    Text(
                      config['filename'] as String,
                      style: TextStyles.bodySmall.copyWith(
                        color: Colors.grey[400],
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SpacingTokens.sm),
                Text(
                  config['code'] as String,
                  style: TextStyles.bodySmall.copyWith(
                    color: Colors.grey[300],
                    fontFamily: 'monospace',
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, String> _getCodingFollowUpConfig(String actionContext) {
    final context = actionContext.toLowerCase();

    // Unit tests / Test suite
    if (context.contains('test')) {
      return {
        'title': 'Tests Added Successfully',
        'summary': 'Test coverage increased to 95%. All 18 new tests passing with full edge case coverage.',
        'filename': 'api.test.ts',
        'code': '''describe('API Client', () => {
  it('handles retry on failure', async () => {
    const result = await fetchWithRetry('/api/data');
    expect(result.status).toBe(200);
  });
});''',
      };
    }

    // Documentation
    if (context.contains('document') || context.contains('api patterns')) {
      return {
        'title': 'Documentation Generated',
        'summary': 'OpenAPI spec created with all endpoints documented. JSDoc comments added to all public methods.',
        'filename': 'openapi.yaml',
        'code': '''paths:
  /api/users:
    get:
      summary: List all users
      responses:
        200:
          description: User list''',
      };
    }

    // Migration guide
    if (context.contains('migration')) {
      return {
        'title': 'Migration Guide Created',
        'summary': 'Step-by-step migration guide with breaking changes documented and upgrade scripts included.',
        'filename': 'MIGRATION.md',
        'code': '''# Migration Guide v2.0

## Breaking Changes
- fetchData() now returns Promise<Result>
- Retry logic is automatic (3 attempts)

## Upgrade Steps
1. Update import paths...''',
      };
    }

    // Rate limiting
    if (context.contains('rate limit')) {
      return {
        'title': 'Rate Limiting Configured',
        'summary': 'Rate limiting middleware active. 100 requests/minute per IP with Redis-backed quota tracking.',
        'filename': 'middleware/rateLimit.ts',
        'code': '''export const rateLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 100,
  store: new RedisStore({ client }),
  message: 'Too many requests'
});''',
      };
    }

    // API versioning
    if (context.contains('versioning')) {
      return {
        'title': 'API Versioning Configured',
        'summary': 'URL-based versioning implemented. v1 and v2 routes coexist with automatic deprecation headers.',
        'filename': 'routes/index.ts',
        'code': '''app.use('/api/v1', v1Routes);
app.use('/api/v2', v2Routes);

// Deprecation middleware
app.use('/api/v1', (req, res, next) => {
  res.set('Deprecation', 'true');
  next();
});''',
      };
    }

    // Postman collection
    if (context.contains('postman')) {
      return {
        'title': 'Postman Collection Generated',
        'summary': 'Postman collection exported with 47 requests, environment variables, and pre-request scripts.',
        'filename': 'postman_collection.json',
        'code': '''{
  "info": { "name": "User API" },
  "item": [
    { "name": "Auth", "item": [...] },
    { "name": "Users", "item": [...] }
  ]
}''',
      };
    }

    // Snapshot tests
    if (context.contains('snapshot')) {
      return {
        'title': 'Snapshot Tests Added',
        'summary': '32 snapshot tests created for all React components. Jest configured for automatic updates.',
        'filename': 'Button.test.tsx',
        'code': '''it('renders primary button', () => {
  const tree = renderer
    .create(<Button variant="primary">Click</Button>)
    .toJSON();
  expect(tree).toMatchSnapshot();
});''',
      };
    }

    // Test data factories
    if (context.contains('factories') || context.contains('fixtures')) {
      return {
        'title': 'Test Factories Created',
        'summary': 'Factory functions created for all models with realistic fake data using Faker.js.',
        'filename': 'factories/user.factory.ts',
        'code': '''export const userFactory = Factory.define<User>(() => ({
  id: faker.string.uuid(),
  email: faker.internet.email(),
  name: faker.person.fullName(),
  createdAt: faker.date.past()
}));''',
      };
    }

    // Parallel tests
    if (context.contains('parallel')) {
      return {
        'title': 'Parallel Execution Configured',
        'summary': 'Tests now run in parallel across 4 workers. CI time reduced from 8min to 2.5min (68% faster).',
        'filename': 'jest.config.js',
        'code': '''module.exports = {
  maxWorkers: '50%',
  testRunner: 'jest-circus',
  workerIdleMemoryLimit: '512MB',
  cache: true
};''',
      };
    }

    // Slack notifications
    if (context.contains('slack')) {
      return {
        'title': 'Slack Notifications Active',
        'summary': 'Deployment alerts configured for #dev-ops channel with success/failure status and commit details.',
        'filename': '.github/workflows/notify.yml',
        'code': '''- name: Slack Notification
  uses: 8398a7/action-slack@v3
  with:
    status: \${{ job.status }}
    channel: '#dev-ops'
    fields: repo,commit,author''',
      };
    }

    // Rollback procedures
    if (context.contains('rollback')) {
      return {
        'title': 'Rollback Procedures Added',
        'summary': 'Automated rollback on health check failure. One-click manual rollback via GitHub Actions.',
        'filename': '.github/workflows/rollback.yml',
        'code': '''on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Version to rollback to'
jobs:
  rollback:
    runs-on: ubuntu-latest
    steps:
      - run: kubectl rollout undo deployment/app''',
      };
    }

    // Blue-green deployment
    if (context.contains('blue-green') || context.contains('zero downtime')) {
      return {
        'title': 'Blue-Green Deployment Configured',
        'summary': 'Zero-downtime deployments active. Traffic shifts gradually with automatic rollback on errors.',
        'filename': 'deploy.yml',
        'code': '''strategy:
  blueGreen:
    activeService: app-active
    previewService: app-preview
    autoPromotionEnabled: false
    scaleDownDelaySeconds: 30''',
      };
    }

    // Custom lint rules
    if (context.contains('lint')) {
      return {
        'title': 'Custom Lint Rules Added',
        'summary': '12 custom ESLint rules enforcing team coding standards. Auto-fix enabled for 8 rules.',
        'filename': 'eslint-rules/no-magic-numbers.js',
        'code': '''module.exports = {
  create(context) {
    return {
      Literal(node) {
        if (typeof node.value === 'number') {
          context.report({ node, message: 'Use named constant' });
        }
      }
    };
  }
};''',
      };
    }

    // CODEOWNERS
    if (context.contains('codeowners')) {
      return {
        'title': 'CODEOWNERS Configured',
        'summary': 'Automatic reviewer assignment active. 5 teams mapped to their code ownership areas.',
        'filename': '.github/CODEOWNERS',
        'code': '''# Default reviewers
* @team-leads

# Frontend team
/src/components/ @frontend-team
/src/pages/ @frontend-team

# Backend team
/api/ @backend-team''',
      };
    }

    // Branch protection
    if (context.contains('branch protection')) {
      return {
        'title': 'Branch Protection Rules Set',
        'summary': 'Main branch protected. Required: 2 approvals, passing CI, up-to-date branch, signed commits.',
        'filename': 'Repository Settings',
        'code': '''Branch: main
✓ Require pull request reviews (2)
✓ Require status checks to pass
✓ Require branches to be up to date
✓ Require signed commits
✓ Include administrators''',
      };
    }

    // Default fallback
    return {
      'title': 'Enhancement Complete',
      'summary': 'Changes successfully implemented and verified.',
      'filename': 'changes.diff',
      'code': '''+ Added new functionality
+ Updated configuration
+ Tests passing''',
    };
  }

  // Business Analyst artifact builders
  Widget _buildDataAnalysisArtifact(ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: colors.success, size: 20),
              const SizedBox(width: SpacingTokens.sm),
              Text(
                'Sales Data Loaded',
                style:
                    TextStyles.sectionTitle.copyWith(color: colors.onSurface),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.md),
          _buildDataRow('Q4 Total Revenue', '\$3.2M', colors.success, colors),
          _buildDataRow('Q4 Customer Count', '2,847', colors.primary, colors),
          _buildDataRow('Average Deal Size', '\$45K', colors.accent, colors),
          _buildDataRow('Conversion Rate', '18.5%', colors.success, colors),
          _buildDataRow(
              'Top Product', 'Enterprise Suite', colors.primary, colors),
        ],
      ),
    );
  }

  Widget _buildReportArtifact(ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description, color: colors.primary, size: 20),
              const SizedBox(width: SpacingTokens.sm),
              Text(
                'Executive Summary Report',
                style:
                    TextStyles.sectionTitle.copyWith(color: colors.onSurface),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.md),
          _buildReportSection('Key Findings',
              'Strong Q4 performance with 15% revenue growth', colors),
          _buildReportSection(
              'Recommendations', 'Expand enterprise sales team by 30%', colors),
          _buildReportSection(
              'Action Items', 'Launch customer retention program', colors),
          _buildReportSection(
              'Q1 Forecast', 'Projected +25% revenue growth', colors),
        ],
      ),
    );
  }

  Widget _buildDashboardArtifact(ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.dashboard, size: 48, color: colors.success),
          const SizedBox(height: SpacingTokens.md),
          Text(
            'Live Analytics Dashboard',
            style: TextStyles.sectionTitle.copyWith(color: colors.onSurface),
          ),
          const SizedBox(height: SpacingTokens.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.md,
              vertical: SpacingTokens.sm,
            ),
            decoration: BoxDecoration(
              color: colors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: SpacingTokens.sm),
                Text(
                  'Real-time Updates Active',
                  style: TextStyles.bodyMedium.copyWith(color: colors.success),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Operations Manager artifact builders
  Widget _buildScheduleAnalysisArtifact(ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: colors.primary, size: 20),
              const SizedBox(width: SpacingTokens.sm),
              Text(
                'Schedule Analysis',
                style:
                    TextStyles.sectionTitle.copyWith(color: colors.onSurface),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.md),
          _buildConflictItem(
              'Resource Conflict',
              'Team A & B both scheduled for Conference Room 1',
              colors.warning,
              colors),
          _buildConflictItem('Overallocation', 'Sarah Johnson: 120% capacity',
              colors.error, colors),
          _buildConflictItem(
              'Gap Detected',
              '2-hour idle time for Dev Team on Tuesday',
              colors.accent,
              colors),
        ],
      ),
    );
  }

  Widget _buildOptimizedScheduleArtifact(ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: colors.success, size: 20),
              const SizedBox(width: SpacingTokens.sm),
              Text(
                'Optimized Schedule',
                style:
                    TextStyles.sectionTitle.copyWith(color: colors.onSurface),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.md),
          _buildTimelineItem('9:00 AM', 'Team Standup', 'All hands', colors),
          _buildTimelineItem('9:30 AM', 'Dev Team Sprint', 'Dev Team', colors),
          _buildTimelineItem(
              '10:30 AM', 'Design Review', 'Product Team', colors),
          _buildTimelineItem('2:00 PM', 'Sprint Planning', 'All hands', colors),
          _buildTimelineItem(
              '4:00 PM', 'Client Presentation', 'Sales Team', colors),
        ],
      ),
    );
  }

  Widget _buildMonitoringArtifact(ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sensors, size: 48, color: colors.success),
          const SizedBox(height: SpacingTokens.md),
          Text(
            'Real-Time Monitoring Active',
            style: TextStyles.sectionTitle.copyWith(color: colors.onSurface),
          ),
          const SizedBox(height: SpacingTokens.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.md,
              vertical: SpacingTokens.sm,
            ),
            decoration: BoxDecoration(
              color: colors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: SpacingTokens.sm),
                Text(
                  'Live Updates: 62% Team Load, +28% Efficiency',
                  style: TextStyles.bodyMedium.copyWith(color: colors.success),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Coding Agent artifact builders
  Widget _buildCodeEditorArtifact(ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: colors.success, size: 20),
              const SizedBox(width: SpacingTokens.sm),
              Text(
                'Codebase Analyzed',
                style: TextStyles.sectionTitle.copyWith(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.md),
          Container(
            padding: const EdgeInsets.all(SpacingTokens.md),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D2D),
              borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
              border: Border.all(color: const Color(0xFF3C3C3C)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAnalysisRow('Files analyzed', '47', Colors.white),
                _buildAnalysisRow('Issues found', '12', colors.warning),
                _buildAnalysisRow('Optimization opportunities', '8', colors.primary),
                _buildAnalysisRow('Code coverage', '62%', colors.accent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SpacingTokens.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyles.bodySmall.copyWith(color: Colors.grey[400]),
          ),
          Text(
            value,
            style: TextStyles.bodyMedium.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeUpdateArtifact(ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: colors.success, size: 20),
              const SizedBox(width: SpacingTokens.sm),
              Text(
                'Changes Implemented',
                style: TextStyles.sectionTitle.copyWith(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.md),
          Container(
            padding: const EdgeInsets.all(SpacingTokens.md),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D2D),
              borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
              border: Border.all(color: const Color(0xFF3C3C3C)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDiffLine('+ Added error handling with retry logic', true, colors),
                _buildDiffLine('+ Implemented input validation', true, colors),
                _buildDiffLine('+ Added TypeScript types', true, colors),
                _buildDiffLine('- Removed deprecated methods', false, colors),
              ],
            ),
          ),
          const SizedBox(height: SpacingTokens.sm),
          Row(
            children: [
              Icon(Icons.insert_drive_file, size: 14, color: Colors.grey[500]),
              const SizedBox(width: SpacingTokens.xs),
              Text(
                '4 files changed, 127 insertions(+), 23 deletions(-)',
                style: TextStyles.bodySmall.copyWith(color: Colors.grey[500]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiffLine(String text, bool isAddition, ThemeColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        style: TextStyles.bodySmall.copyWith(
          color: isAddition ? const Color(0xFF4EC9B0) : const Color(0xFFCE9178),
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _buildGitCommitArtifact(ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: colors.success, size: 20),
              const SizedBox(width: SpacingTokens.sm),
              Text(
                'Committed to Repository',
                style: TextStyles.sectionTitle.copyWith(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.md),
          Container(
            padding: const EdgeInsets.all(SpacingTokens.md),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D2D),
              borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
              border: Border.all(color: const Color(0xFF3C3C3C)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: SpacingTokens.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colors.success.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
                      ),
                      child: Text(
                        'feat',
                        style: TextStyles.bodySmall.copyWith(
                          color: colors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: SpacingTokens.sm),
                    Expanded(
                      child: Text(
                        'Add error handling and retry logic to API client',
                        style: TextStyles.bodyMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SpacingTokens.md),
                Row(
                  children: [
                    Icon(Icons.commit, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: SpacingTokens.xs),
                    Text(
                      'abc1234',
                      style: TextStyles.bodySmall.copyWith(
                        color: colors.primary,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: SpacingTokens.lg),
                    Text(
                      '4 files',
                      style: TextStyles.bodySmall.copyWith(color: Colors.grey[500]),
                    ),
                    const SizedBox(width: SpacingTokens.sm),
                    Text(
                      '+127',
                      style: TextStyles.bodySmall.copyWith(color: const Color(0xFF4EC9B0)),
                    ),
                    const SizedBox(width: SpacingTokens.xs),
                    Text(
                      '-23',
                      style: TextStyles.bodySmall.copyWith(color: const Color(0xFFCE9178)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDemoCompletion() {
    if (mounted && !_demoCompleted) {
      setState(() {
        _demoCompleted = true;
        _showCompletionScreen = true;
      });
    }
  }

  void _handleVerificationRequest(VerificationRequest request) {
    setState(() {
      _currentVerification = request;
      _showVerificationModal = true;
    });
    _modalController.forward();
  }

  void _handleEnhancedVerificationRequest(EnhancedVerificationRequest request) {
    setState(() {
      _currentEnhancedVerification = request;
      _showVerificationModal = true;
      _showChatInModal = false;
    });
    _modalController.forward();
  }

  void _toggleModalChat() {
    setState(() {
      _showChatInModal = !_showChatInModal;
    });
  }

  void _approveVerification() {
    _modalController.reverse().then((_) {
      setState(() {
        _showVerificationModal = false;
        _showChatInModal = false;
      });
      _currentVerification?.onApprove();
      _currentVerification = null;
      _currentEnhancedVerification = null;
    });
  }

  void _rejectVerification() {
    _modalController.reverse().then((_) {
      setState(() {
        _showVerificationModal = false;
        _showChatInModal = false;
      });
      _currentVerification?.onReject();
      _currentVerification = null;
      _currentEnhancedVerification = null;
    });
  }

  void _selectAction(ProposedAction action) {
    _modalController.reverse().then((_) {
      setState(() {
        _showVerificationModal = false;
        _showChatInModal = false;
      });
      action.onSelect();
      _currentEnhancedVerification = null;
    });
  }

  void _handleDemoRestart() {
    setState(() {
      _showCompletionScreen = false;
      _demoCompleted = false;
      _currentStage = 0;
      _canvasStage = 0;
      _showCanvas = false;
      _interventionActive = false;
      _isPlaying = true;

      // Reset agent confidences
      _activeAgents.forEach((key, agent) {
        agent.confidence = _getInitialConfidence(key);
      });
    });

    // Restart the demo
    _startDemo();
  }

  double _getInitialConfidence(String agentKey) {
    switch (agentKey) {
      case 'operations-manager':
        return 0.94;
      case 'designer':
        return 0.88;
      case 'analyst':
        return 0.95;
      default:
        return 0.90;
    }
  }

  double _getCurrentAgentConfidence() {
    // Get confidence for the current agent type
    switch (widget.selectedAgentType) {
      case 0:
        return _activeAgents['analyst']?.confidence ?? 0.95;
      case 1:
        return _activeAgents['operations-manager']?.confidence ?? 0.94;
      case 2:
        return _activeAgents['coder']?.confidence ?? 0.92;
      default:
        return 0.90;
    }
  }

  Widget _buildConfidenceBanner(ThemeColors colors, int confidencePercent,
      int thresholdPercent, bool isBelowThreshold) {
    final bannerColor = isBelowThreshold ? colors.warning : colors.success;
    final bannerIcon =
        isBelowThreshold ? Icons.warning_amber_rounded : Icons.check_circle;

    return Container(
      padding: const EdgeInsets.all(SpacingTokens.md),
      decoration: BoxDecoration(
        color: bannerColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
        border: Border.all(color: bannerColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(bannerIcon, color: bannerColor, size: 20),
          const SizedBox(width: SpacingTokens.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'AI Confidence: ',
                      style: TextStyles.bodyMedium.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                    Text(
                      '$confidencePercent%',
                      style: TextStyles.bodyMedium.copyWith(
                        color: bannerColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: SpacingTokens.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: SpacingTokens.xs,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colors.onSurfaceVariant.withOpacity(0.1),
                        borderRadius:
                            BorderRadius.circular(BorderRadiusTokens.sm),
                      ),
                      child: Text(
                        'Threshold: $thresholdPercent%',
                        style: TextStyles.bodySmall.copyWith(
                          color: colors.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SpacingTokens.xs),
                // Confidence bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
                  child: Stack(
                    children: [
                      // Background
                      Container(
                        height: 6,
                        width: double.infinity,
                        color: colors.border,
                      ),
                      // Threshold marker
                      Positioned(
                        left: 0,
                        right: 0,
                        child: FractionallySizedBox(
                          widthFactor: thresholdPercent / 100,
                          alignment: Alignment.centerLeft,
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(
                                  color: colors.onSurface.withOpacity(0.5),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Confidence fill
                      FractionallySizedBox(
                        widthFactor: confidencePercent / 100,
                        alignment: Alignment.centerLeft,
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: bannerColor,
                            borderRadius:
                                BorderRadius.circular(BorderRadiusTokens.sm),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isBelowThreshold) ...[
                  const SizedBox(height: SpacingTokens.xs),
                  Text(
                    'Human verification requested - confidence below your threshold',
                    style: TextStyles.bodySmall.copyWith(
                      color: bannerColor,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<CompletionMetric> _getCompletionMetrics() {
    switch (widget.selectedAgentType) {
      case 0: // Business Analyst
        return [
          CompletionMetric(
            label: 'Data Analyzed',
            value: '3.2M',
            icon: Icons.analytics,
            isHighlight: true,
          ),
          CompletionMetric(
            label: 'Insights Generated',
            value: '12',
            icon: Icons.lightbulb,
          ),
          CompletionMetric(
            label: 'Time Saved',
            value: '4.5 hrs',
            icon: Icons.timer,
          ),
          CompletionMetric(
            label: 'Accuracy',
            value: '98%',
            icon: Icons.verified,
            isHighlight: true,
          ),
        ];
      case 1: // Operations Manager
        return [
          CompletionMetric(
            label: 'Tasks Optimized',
            value: '24',
            icon: Icons.task_alt,
            isHighlight: true,
          ),
          CompletionMetric(
            label: 'Efficiency Gain',
            value: '+23%',
            icon: Icons.trending_up,
          ),
          CompletionMetric(
            label: 'Conflicts Resolved',
            value: '3',
            icon: Icons.check_circle,
          ),
          CompletionMetric(
            label: 'Time Saved',
            value: '6.2 hrs',
            icon: Icons.access_time,
            isHighlight: true,
          ),
        ];
      case 2: // Coding Agent
        return [
          CompletionMetric(
            label: 'Code Generated',
            value: '1.2k lines',
            icon: Icons.code,
            isHighlight: true,
          ),
          CompletionMetric(
            label: 'Test Coverage',
            value: '95%',
            icon: Icons.check_circle_outline,
          ),
          CompletionMetric(
            label: 'Build Time',
            value: '45s',
            icon: Icons.speed,
          ),
          CompletionMetric(
            label: 'Git Commits',
            value: '12',
            icon: Icons.history,
            isHighlight: true,
          ),
        ];
      default:
        return [];
    }
  }

  void _triggerConfidenceDemo() {
    // Realistic confidence scenario based on agent type
    final targetAgent = _getTargetAgentForDemo();
    if (targetAgent != null) {
      // Start with good confidence, then simulate a challenge
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _activeAgents[targetAgent]!.confidence = 0.65; // Moderate concern
            _interventionActive = false; // Keep it optional, not forced
          });
        }
      });

      // Recovery after showing the confidence monitoring
      Future.delayed(const Duration(seconds: 8), () {
        if (mounted) {
          setState(() {
            _activeAgents[targetAgent]!.confidence =
                0.92; // Recovered confidence
            _interventionActive = false;
          });
        }
      });
    }
  }

  Duration _getStageDelay(int stage) {
    // Shorter, more engaging timings
    switch (stage) {
      case 1:
        return const Duration(seconds: 12); // Confidence demo
      case 2:
        return const Duration(seconds: 15); // Feature showcase
      case 3:
        return const Duration(seconds: 10); // Final wrap-up
      default:
        return const Duration(seconds: 8);
    }
  }

  String? _getTargetAgentForDemo() {
    switch (widget.selectedAgentType) {
      case 0:
        return 'analyst'; // Business analyst confidence scenarios
      case 1:
        return 'operations-manager'; // Operations optimization scenarios
      case 2:
        return 'coder'; // Code generation and testing scenarios
      default:
        return 'analyst';
    }
  }

  AgentInfo _getAgentInfoForType() {
    switch (widget.selectedAgentType) {
      case 0:
        return AgentInfo(
          name: 'Business Analyst AI',
          icon: Icons.analytics,
          color: const Color(0xFFFFE66D),
          confidence: 0.95,
        );
      case 1:
        return AgentInfo(
          name: 'Operations Manager AI',
          icon: Icons.schedule,
          color: const Color(0xFF4ECDC4),
          confidence: 0.94,
        );
      case 2:
        return AgentInfo(
          name: 'Coding Agent',
          icon: Icons.code,
          color: const Color(0xFF9B59B6),
          confidence: 0.92,
        );
      default:
        return _activeAgents.values.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ThemeColors(context);

    // Show completion screen when demo is done
    if (_showCompletionScreen) {
      final agentInfo = _getAgentInfoForType();
      return DemoContainer(
        scenario: 'unified-showcase',
        title: 'Asmbli Demo',
        icon: Icons.auto_awesome,
        customContent: DemoCompletionCelebration(
          agentName: agentInfo.name,
          agentIcon: agentInfo.icon,
          agentColor: agentInfo.color,
          metrics: _getCompletionMetrics(),
          onRestart: _handleDemoRestart,
          onExploreMore: () {
            context.go(AppRoutes.agents);
          },
        ),
      );
    }

    return DemoContainer(
      scenario: 'unified-showcase',
      title: 'Asmbli Demo',
      icon: Icons.auto_awesome,
      customContent: Column(
        children: [
          // Stage indicator
          _buildStageIndicator(colors),

          // Main content area
          Expanded(
            child: Row(
              children: [
                // Chat sidebar (left side)
                Container(
                  width: 400,
                  margin: const EdgeInsets.only(
                    left: SpacingTokens.md,
                    top: SpacingTokens.md,
                    bottom: SpacingTokens.md,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    children: [
                      _buildAgentBar(colors),
                      Expanded(
                        child: AsmblDemoChat(
                          scenario: _getScenarioForSelectedAgent(),
                          deliverable: widget.selectedDeliverable,
                          confidenceThreshold: widget.confidenceThreshold,
                          onInterventionNeeded: (_) {
                            setState(() => _interventionActive = true);
                          },
                          onCanvasUpdate: (stage, {String? actionContext}) {
                            _handleCanvasUpdate(stage,
                                actionContext: actionContext);
                          },
                          onDemoComplete: _showDemoCompletion,
                          onVerificationNeeded: _handleVerificationRequest,
                          onEnhancedVerificationNeeded:
                              _handleEnhancedVerificationRequest,
                        ),
                      ),
                    ],
                  ),
                ),

                // Main content area (right side)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(SpacingTokens.md),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius:
                          BorderRadius.circular(BorderRadiusTokens.lg),
                      border: Border.all(color: colors.border),
                    ),
                    child: Stack(
                      children: [
                        // Canvas or workspace
                        if (!_showCodeEditor)
                          _showCanvas
                              ? _buildCanvasArea(colors)
                              : _buildMainWorkspace(colors),

                        // Code editor overlay
                        if (_showCodeEditor)
                          DemoCodeEditor(
                            onClose: () {
                              setState(() => _showCodeEditor = false);
                            },
                            actionContext: _currentActionContext,
                            deliverableType: _codingDeliverableType,
                          ),

                        // Verification modal overlay
                        if (_showVerificationModal)
                          _buildVerificationModal(colors),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // AI analysis status bar (bottom)
          if (_currentStage > 0) _buildAnalysisStatusBar(colors),
        ],
      ),
    );
  }

  Widget _buildStageIndicator(ThemeColors colors) {
    // Progress bar removed - demo is now fully chat-driven without staged progression
    return const SizedBox.shrink();
  }

  Widget _buildAgentBar(ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.md),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Text(
            'Active Agents',
            style: TextStyles.bodySmall.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: SpacingTokens.md),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _activeAgents.entries.map((entry) {
                  final agent = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(right: SpacingTokens.sm),
                    padding: const EdgeInsets.symmetric(
                      horizontal: SpacingTokens.sm,
                      vertical: SpacingTokens.xs,
                    ),
                    decoration: BoxDecoration(
                      color: agent.color.withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(BorderRadiusTokens.sm),
                      border: Border.all(
                        color: agent.confidence < 0.7
                            ? colors.warning
                            : agent.color.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(agent.icon, size: 16, color: agent.color),
                        const SizedBox(width: SpacingTokens.xs),
                        Text(
                          agent.name,
                          style: TextStyles.bodySmall.copyWith(
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(width: SpacingTokens.sm),
                        AnimatedConfidenceIndicator(
                          confidence: agent.confidence,
                          inline: true,
                          showLabel: false,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvasArea(ThemeColors colors) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(SpacingTokens.md),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          child: Row(
            children: [
              Icon(Icons.design_services, size: 20, color: colors.primary),
              const SizedBox(width: SpacingTokens.sm),
              Text(
                'Live Design Canvas',
                style: TextStyles.bodyLarge.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_currentActionContext != null) ...[
                const SizedBox(width: SpacingTokens.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SpacingTokens.sm,
                    vertical: SpacingTokens.xs,
                  ),
                  decoration: BoxDecoration(
                    color: colors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
                    border: Border.all(color: colors.accent, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.touch_app,
                        size: 14,
                        color: colors.accent,
                      ),
                      const SizedBox(width: SpacingTokens.xs),
                      Text(
                        'Selected: $_currentActionContext',
                        style: TextStyles.bodySmall.copyWith(
                          color: colors.accent,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.sm,
                  vertical: SpacingTokens.xs,
                ),
                decoration: BoxDecoration(
                  color: colors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.success,
                      ),
                    ),
                    const SizedBox(width: SpacingTokens.xs),
                    Text(
                      'Live Preview',
                      style: TextStyles.bodySmall.copyWith(
                        color: colors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _buildExcalidrawCanvas(colors),
        ),
      ],
    );
  }

  Widget _buildMockDesign(ThemeColors colors) {
    switch (_canvasStage) {
      case 0:
        return _buildEmptyCanvas(colors);
      case 1:
        return _buildWireframeStage(colors);
      case 2:
        return _buildStyledStage(colors);
      case 3:
        return _buildInteractiveStage(colors);
      default:
        return _buildEmptyCanvas(colors);
    }
  }

  Widget _buildEmptyCanvas(ThemeColors colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.design_services,
            size: 64,
            color: colors.onSurfaceVariant.withOpacity(0.3),
          ),
          const SizedBox(height: SpacingTokens.lg),
          Text(
            'Canvas Ready',
            style: TextStyles.bodyLarge.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          Text(
            'AI will generate designs here',
            style: TextStyles.bodySmall.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWireframeStage(ThemeColors colors) {
    return Container(
      margin: const EdgeInsets.all(SpacingTokens.lg),
      child: Column(
        children: [
          // Wireframe header
          Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              border: Border.all(color: colors.onSurfaceVariant, width: 2),
              borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
            ),
            child: Center(
              child: Text(
                'Header (Wireframe)',
                style: TextStyles.bodySmall.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ),

          const SizedBox(height: SpacingTokens.md),

          // Wireframe content
          Expanded(
            child: Column(
              children: [
                // Navigation wireframe
                Container(
                  width: double.infinity,
                  height: 30,
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: colors.onSurfaceVariant,
                        style: BorderStyle.solid),
                    borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
                  ),
                  child: Row(
                    children: List.generate(
                      3,
                      (index) => Expanded(
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            border: Border.all(color: colors.onSurfaceVariant),
                          ),
                          child: Center(
                            child: Text(
                              'Nav ${index + 1}',
                              style: TextStyles.bodySmall.copyWith(
                                color: colors.onSurfaceVariant,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: SpacingTokens.md),

                // Content wireframes
                ...List.generate(
                    2,
                    (index) => Container(
                          width: double.infinity,
                          height: 60,
                          margin:
                              const EdgeInsets.only(bottom: SpacingTokens.sm),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: colors.onSurfaceVariant,
                                style: BorderStyle.solid),
                            borderRadius:
                                BorderRadius.circular(BorderRadiusTokens.sm),
                          ),
                          child: Center(
                            child: Text(
                              'Content Block ${index + 1}',
                              style: TextStyles.bodySmall.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyledStage(ThemeColors colors) {
    return Container(
      margin: const EdgeInsets.all(SpacingTokens.lg),
      child: Column(
        children: [
          // Styled header
          Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors.primary, colors.accent],
              ),
              borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
            ),
            child: Center(
              child: Text(
                'Project Dashboard',
                style: TextStyles.bodyLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          const SizedBox(height: SpacingTokens.md),

          // Styled navigation
          Container(
            width: double.infinity,
            height: 40,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                _buildNavItem('Overview', true, colors),
                _buildNavItem('Tasks', false, colors),
                _buildNavItem('Team', false, colors),
              ],
            ),
          ),

          const SizedBox(height: SpacingTokens.md),

          // Styled content cards
          Expanded(
            child: Column(
              children: [
                // Stats card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(SpacingTokens.lg),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
                    border: Border.all(color: colors.border),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.trending_up, color: colors.success, size: 24),
                      const SizedBox(width: SpacingTokens.sm),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Project Progress',
                            style: TextStyles.bodyMedium.copyWith(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '78% Complete',
                            style: TextStyles.bodySmall.copyWith(
                              color: colors.success,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: SpacingTokens.md),

                // Task list card
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(SpacingTokens.lg),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius:
                          BorderRadius.circular(BorderRadiusTokens.lg),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recent Tasks',
                          style: TextStyles.bodyMedium.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.sm),
                        ...List.generate(
                            3,
                            (index) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: SpacingTokens.xs),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: index == 0
                                              ? colors.success
                                              : colors.primary,
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                        child: index == 0
                                            ? Icon(Icons.check,
                                                size: 12, color: Colors.white)
                                            : null,
                                      ),
                                      const SizedBox(width: SpacingTokens.sm),
                                      Text(
                                        'Task ${index + 1}',
                                        style: TextStyles.bodySmall.copyWith(
                                          color: colors.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveStage(ThemeColors colors) {
    return Container(
      margin: const EdgeInsets.all(SpacingTokens.lg),
      child: Column(
        children: [
          // Interactive header with button
          Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors.primary, colors.accent],
              ),
              borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.md),
              child: Row(
                children: [
                  Text(
                    'Project Dashboard',
                    style: TextStyles.bodyLarge.copyWith(
                      color: Colors.white,
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
                      color: Colors.white.withOpacity(0.2),
                      borderRadius:
                          BorderRadius.circular(BorderRadiusTokens.sm),
                    ),
                    child: Text(
                      '+ Add Task',
                      style: TextStyles.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: SpacingTokens.md),

          // Interactive content
          Expanded(
            child: Column(
              children: [
                // Interactive stats row
                Row(
                  children: [
                    Expanded(
                        child: _buildInteractiveStatCard(
                            'Active', '12', colors.primary, colors)),
                    const SizedBox(width: SpacingTokens.sm),
                    Expanded(
                        child: _buildInteractiveStatCard(
                            'Completed', '24', colors.success, colors)),
                    const SizedBox(width: SpacingTokens.sm),
                    Expanded(
                        child: _buildInteractiveStatCard(
                            'Overdue', '3', colors.warning, colors)),
                  ],
                ),

                const SizedBox(height: SpacingTokens.md),

                // Interactive modal demo
                Expanded(
                  child: Stack(
                    children: [
                      // Background content
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(SpacingTokens.lg),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius:
                              BorderRadius.circular(BorderRadiusTokens.lg),
                          border: Border.all(color: colors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Task Management',
                              style: TextStyles.bodyMedium.copyWith(
                                color: colors.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: SpacingTokens.sm),
                            ...List.generate(
                                3,
                                (index) => Container(
                                      margin: const EdgeInsets.only(
                                          bottom: SpacingTokens.xs),
                                      child: Text(
                                        '• Task ${index + 1} details...',
                                        style: TextStyles.bodySmall.copyWith(
                                          color: colors.onSurfaceVariant,
                                        ),
                                      ),
                                    )),
                          ],
                        ),
                      ),

                      // Modal overlay
                      Container(
                        color: Colors.black.withOpacity(0.3),
                        child: Center(
                          child: Container(
                            width: 200,
                            padding: const EdgeInsets.all(SpacingTokens.lg),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius:
                                  BorderRadius.circular(BorderRadiusTokens.lg),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add_task,
                                  color: colors.primary,
                                  size: 32,
                                ),
                                const SizedBox(height: SpacingTokens.sm),
                                Text(
                                  'Add New Task',
                                  style: TextStyles.bodyMedium.copyWith(
                                    color: colors.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: SpacingTokens.sm),
                                Text(
                                  'Interactive modal generated by AI',
                                  style: TextStyles.bodySmall.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: SpacingTokens.md),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: SpacingTokens.sm,
                                        vertical: SpacingTokens.xs,
                                      ),
                                      decoration: BoxDecoration(
                                        border:
                                            Border.all(color: colors.border),
                                        borderRadius: BorderRadius.circular(
                                            BorderRadiusTokens.sm),
                                      ),
                                      child: Text(
                                        'Cancel',
                                        style: TextStyles.bodySmall.copyWith(
                                          color: colors.onSurface,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: SpacingTokens.sm,
                                        vertical: SpacingTokens.xs,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.primary,
                                        borderRadius: BorderRadius.circular(
                                            BorderRadiusTokens.sm),
                                      ),
                                      child: Text(
                                        'Add',
                                        style: TextStyles.bodySmall.copyWith(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
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

  Widget _buildNavItem(String label, bool isActive, ThemeColors colors) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.symmetric(vertical: SpacingTokens.xs),
        decoration: BoxDecoration(
          color: isActive ? colors.primary.withOpacity(0.1) : null,
          borderRadius: BorderRadius.circular(BorderRadiusTokens.xs),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyles.bodySmall.copyWith(
              color: isActive ? colors.primary : colors.onSurfaceVariant,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInteractiveStatCard(
      String label, String value, Color accentColor, ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyles.sectionTitle.copyWith(
              color: accentColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: SpacingTokens.xs),
          Text(
            label,
            style: TextStyles.bodySmall.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _getAnalysisType() {
    // Adapt analysis type based on selected agent and current stage
    if (widget.selectedAgentType != null) {
      switch (widget.selectedAgentType!) {
        case 0:
          return 'document'; // Business Analyst
        case 1:
          return 'design'; // Design Assistant
        case 2:
          return 'operations'; // Operations Manager
      }
    }

    switch (_currentStage) {
      case 0:
        return 'orchestration';
      case 1:
        return 'confidence';
      case 2:
        return 'design';
      case 3:
        return 'integration';
      default:
        return 'general';
    }
  }

  double _getBaseConfidence() {
    // Agent-specific base confidence levels
    switch (widget.selectedAgentType) {
      case 0:
        return 0.92; // Business Analyst - high confidence with data
      case 1:
        return 0.94; // Operations Manager - high operational efficiency
      case 2:
        return 0.90; // Coding Agent - high confidence with code generation
      default:
        return 0.80;
    }
  }

  String _getActiveModelName() {
    switch (_currentStage) {
      case 0:
        return 'Claude 4.5 Sonnet';
      case 1:
        return 'Multi-model consensus';
      case 2:
        return 'GPT-4 Vision';
      case 3:
        return 'Specialized MCP Agent';
      default:
        return 'Claude 4.5 Sonnet';
    }
  }

  String _getScenarioForSelectedAgent() {
    if (widget.selectedAgentType != null) {
      switch (widget.selectedAgentType!) {
        case 0:
          return 'business-analyst';
        case 1:
          return 'operations-manager';
        case 2:
          return 'coding-agent';
      }
    }
    return 'unified-demo';
  }

  Widget _buildMainWorkspace(ThemeColors colors) {
    return Column(
      children: [
        // Workspace header
        Container(
          padding: const EdgeInsets.all(SpacingTokens.lg),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          child: Row(
            children: [
              Icon(_getWorkspaceIcon(), color: colors.primary, size: 24),
              const SizedBox(width: SpacingTokens.sm),
              Text(
                _getWorkspaceTitle(),
                style: TextStyles.sectionTitle.copyWith(
                  color: colors.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.sm,
                  vertical: SpacingTokens.xs,
                ),
                decoration: BoxDecoration(
                  color: colors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
                ),
                child: Text(
                  'Live Demo',
                  style: TextStyles.bodySmall.copyWith(
                    color: colors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Main workspace content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(SpacingTokens.xl),
            child: _buildWorkspaceContent(colors),
          ),
        ),
      ],
    );
  }

  IconData _getWorkspaceIcon() {
    // Use deliverable-specific icon if available
    if (widget.selectedDeliverable != null) {
      final deliverable = widget.selectedDeliverable!.toLowerCase();

      if (deliverable.contains('dashboard')) return Icons.dashboard;
      if (deliverable.contains('report')) return Icons.description;
      if (deliverable.contains('prototype')) return Icons.touch_app;
      if (deliverable.contains('application') ||
          deliverable.contains('generate application'))
        return Icons.rocket_launch;
      if (deliverable.contains('documentation')) return Icons.article;
      if (deliverable.contains('playbook')) return Icons.auto_awesome;
      if (deliverable.contains('api')) return Icons.api;
      if (deliverable.contains('pipeline')) return Icons.account_tree;
      if (deliverable.contains('test')) return Icons.check_circle;
      if (deliverable.contains('refactor')) return Icons.autorenew;
      if (deliverable.contains('monitoring')) return Icons.notifications;
      if (deliverable.contains('optimization')) return Icons.trending_up;
      if (deliverable.contains('support') || deliverable.contains('decision'))
        return Icons.lightbulb;
      if (deliverable.contains('design system')) return Icons.design_services;
      if (deliverable.contains('review')) return Icons.rate_review;
    }

    // Fallback to agent-based icons
    switch (widget.selectedAgentType) {
      case 0:
        return Icons.analytics; // Business Analyst
      case 1:
        return Icons.palette; // Design Assistant
      case 2:
        return Icons.dashboard; // Operations Manager
      default:
        return Icons.dashboard;
    }
  }

  String _getWorkspaceTitle() {
    // Use deliverable-specific title if available
    if (widget.selectedDeliverable != null) {
      final deliverable = widget.selectedDeliverable!;

      // Return deliverable name directly
      if (deliverable.contains('Dashboard')) return deliverable;
      if (deliverable.contains('Report')) return deliverable;
      if (deliverable.contains('Prototype')) return deliverable;
      if (deliverable.contains('Application')) return deliverable;
      if (deliverable.contains('Documentation')) return deliverable;
      if (deliverable.contains('Playbook')) return deliverable;
      if (deliverable.contains('Pipeline')) return deliverable;
      if (deliverable.contains('API')) return '$deliverable Project';

      // Fallback: show the deliverable name
      return deliverable;
    }

    // Fallback to agent-based titles
    switch (widget.selectedAgentType) {
      case 0:
        return 'Analytics Dashboard';
      case 1:
        return 'Design Workspace';
      case 2:
        return 'Operations Dashboard';
      default:
        return 'AI Workspace';
    }
  }

  Widget _buildWorkspaceContent(ThemeColors colors) {
    return Row(
      children: [
        // Main workspace content
        Expanded(
          flex: 3,
          child: _buildAgentWorkspace(colors),
        ),

        // Action history sidebar
        if (_actionHistory.isNotEmpty) ...[
          const SizedBox(width: SpacingTokens.lg),
          Container(
            width: 280,
            child: _buildActionHistoryPanel(colors),
          ),
        ],
      ],
    );
  }

  Widget _buildAgentWorkspace(ThemeColors colors) {
    // If we have artifacts, display them in an additive scrollable list
    if (_workspaceArtifacts.isNotEmpty) {
      return _buildAdditiveArtifactsView(colors);
    }

    // Otherwise show empty workspace based on agent type
    switch (widget.selectedAgentType) {
      case 0: // Business Analyst
        return _buildEmptyAnalyticsWorkspace(colors);
      case 1: // Operations Manager
        return _buildEmptyOperationsWorkspace(colors);
      case 2: // Coding Agent
        return _buildEmptyCodingWorkspace(colors);
      default:
        return _buildDefaultWorkspace(colors);
    }
  }

  Widget _buildAdditiveArtifactsView(ThemeColors colors) {
    // Use dark theme for coding agent (type 2)
    final isCodingAgent = widget.selectedAgentType == 2;
    final cardBgColor = isCodingAgent ? const Color(0xFF1E1E1E) : colors.surface;
    final headerBgColor = isCodingAgent
        ? const Color(0xFF252526)
        : colors.primary.withValues(alpha: 0.1);
    final textColor = isCodingAgent ? Colors.white : colors.onSurface;
    final subtextColor = isCodingAgent ? Colors.grey[400]! : colors.onSurfaceVariant;
    final borderColor = isCodingAgent ? const Color(0xFF3C3C3C) : colors.border;

    return Container(
      color: isCodingAgent ? const Color(0xFF1E1E1E) : null,
      child: ListView.separated(
        controller: _workspaceScrollController,
        padding: const EdgeInsets.all(SpacingTokens.lg),
        itemCount: _workspaceArtifacts.length,
        separatorBuilder: (context, index) =>
            const SizedBox(height: SpacingTokens.xl),
        itemBuilder: (context, index) {
          final artifact = _workspaceArtifacts[index];
          return Container(
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Artifact header with timestamp
                Container(
                  padding: const EdgeInsets.all(SpacingTokens.md),
                  decoration: BoxDecoration(
                    color: headerBgColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(BorderRadiusTokens.lg),
                      topRight: Radius.circular(BorderRadiusTokens.lg),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getArtifactIcon(artifact.type),
                        color: colors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: SpacingTokens.sm),
                      Expanded(
                        child: Text(
                          artifact.title,
                          style: TextStyles.bodyMedium.copyWith(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        _formatTimestamp(artifact.timestamp),
                        style: TextStyles.bodySmall.copyWith(
                          color: subtextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                // Artifact content
                artifact.content,
            ],
          ),
        );
      },
      ),
    );
  }

  IconData _getArtifactIcon(String type) {
    switch (type) {
      case 'analysis':
        return Icons.analytics;
      case 'chart':
        return Icons.bar_chart;
      case 'schedule':
        return Icons.schedule;
      case 'code':
        return Icons.code;
      case 'dashboard':
        return Icons.dashboard;
      case 'report':
        return Icons.description;
      case 'monitoring':
        return Icons.sensors;
      case 'git':
        return Icons.commit;
      case 'automation':
        return Icons.auto_awesome;
      case 'alerts':
        return Icons.notifications_active;
      case 'tests':
        return Icons.check_circle;
      case 'optimization':
        return Icons.speed;
      case 'cicd':
        return Icons.rocket_launch;
      default:
        return Icons.article;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildEmptyAnalyticsWorkspace(ThemeColors colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart,
              size: 64, color: colors.primary.withValues(alpha: 0.5)),
          const SizedBox(height: SpacingTokens.md),
          Text(
            'Ready for Analysis',
            style:
                TextStyles.bodyLarge.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: SpacingTokens.sm),
          Text(
            'Choose an action to begin',
            style:
                TextStyles.bodyMedium.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyOperationsWorkspace(ThemeColors colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.schedule,
              size: 64, color: colors.primary.withValues(alpha: 0.5)),
          const SizedBox(height: SpacingTokens.md),
          Text(
            'Ready for Optimization',
            style:
                TextStyles.bodyLarge.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: SpacingTokens.sm),
          Text(
            'Choose an action to begin',
            style:
                TextStyles.bodyMedium.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCodingWorkspace(ThemeColors colors) {
    // Get deliverable-specific content
    final deliverable = widget.selectedDeliverable?.toLowerCase() ?? '';
    final workspaceConfig = _getCodingWorkspaceConfig(deliverable);

    return Container(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mock IDE header bar
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.md,
              vertical: SpacingTokens.sm,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(BorderRadiusTokens.lg),
                topRight: Radius.circular(BorderRadiusTokens.lg),
              ),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Icon(workspaceConfig['icon'] as IconData,
                    size: 16, color: colors.primary),
                const SizedBox(width: SpacingTokens.sm),
                Text(
                  workspaceConfig['title'] as String,
                  style: TextStyles.bodyMedium.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                // Mock tab buttons
                ...['Files', 'Search', 'Git'].map((tab) => Padding(
                  padding: const EdgeInsets.only(left: SpacingTokens.sm),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SpacingTokens.sm,
                      vertical: SpacingTokens.xs,
                    ),
                    decoration: BoxDecoration(
                      color: tab == 'Files'
                          ? colors.primary.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
                    ),
                    child: Text(
                      tab,
                      style: TextStyles.bodySmall.copyWith(
                        color: tab == 'Files'
                            ? colors.primary
                            : colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                )),
              ],
            ),
          ),

          // Main content area
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E), // Dark editor background
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(BorderRadiusTokens.lg),
                  bottomRight: Radius.circular(BorderRadiusTokens.lg),
                ),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  // File tree sidebar
                  Container(
                    width: 200,
                    padding: const EdgeInsets.all(SpacingTokens.md),
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: colors.border.withValues(alpha: 0.3)),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EXPLORER',
                          style: TextStyles.bodySmall.copyWith(
                            color: Colors.grey[500],
                            fontSize: 10,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.md),
                        ...(workspaceConfig['files'] as List<Map<String, dynamic>>).map((file) =>
                          _buildMockFileItem(
                            file['name'] as String,
                            file['icon'] as IconData,
                            file['indent'] as int? ?? 0,
                            colors,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Code preview area
                  Expanded(
                    child: Column(
                      children: [
                        // File tabs
                        Container(
                          height: 35,
                          padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.sm),
                          decoration: BoxDecoration(
                            color: const Color(0xFF252526),
                            border: Border(
                              bottom: BorderSide(color: colors.border.withValues(alpha: 0.3)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: SpacingTokens.md,
                                  vertical: SpacingTokens.xs,
                                ),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1E1E1E),
                                  border: Border(
                                    top: BorderSide(color: Color(0xFF007ACC), width: 2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      workspaceConfig['mainFileIcon'] as IconData,
                                      size: 14,
                                      color: _getFileIconColor(workspaceConfig['mainFile'] as String),
                                    ),
                                    const SizedBox(width: SpacingTokens.xs),
                                    Text(
                                      workspaceConfig['mainFile'] as String,
                                      style: TextStyles.bodySmall.copyWith(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Code content with "waiting" state
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  workspaceConfig['icon'] as IconData,
                                  size: 48,
                                  color: colors.primary.withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: SpacingTokens.md),
                                Text(
                                  workspaceConfig['waitingMessage'] as String,
                                  style: TextStyles.bodyMedium.copyWith(
                                    color: Colors.grey[400],
                                  ),
                                ),
                                const SizedBox(height: SpacingTokens.sm),
                                Text(
                                  'Start the workflow to see AI-generated code',
                                  style: TextStyles.bodySmall.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getCodingWorkspaceConfig(String deliverable) {
    if (deliverable.contains('refactor')) {
      return {
        'icon': Icons.autorenew,
        'title': 'Refactoring Workspace',
        'mainFile': 'legacy_code.js',
        'mainFileIcon': Icons.javascript,
        'waitingMessage': 'Ready to analyze and refactor code',
        'files': [
          {'name': 'src/', 'icon': Icons.folder, 'indent': 0},
          {'name': 'legacy_code.js', 'icon': Icons.javascript, 'indent': 1},
          {'name': 'utils.js', 'icon': Icons.javascript, 'indent': 1},
          {'name': 'helpers/', 'icon': Icons.folder, 'indent': 1},
          {'name': 'tests/', 'icon': Icons.folder, 'indent': 0},
          {'name': 'package.json', 'icon': Icons.settings, 'indent': 0},
        ],
      };
    } else if (deliverable.contains('api')) {
      return {
        'icon': Icons.api,
        'title': 'API Development Workspace',
        'mainFile': 'routes.ts',
        'mainFileIcon': Icons.code,
        'waitingMessage': 'Ready to design and implement API',
        'files': [
          {'name': 'src/', 'icon': Icons.folder, 'indent': 0},
          {'name': 'routes/', 'icon': Icons.folder, 'indent': 1},
          {'name': 'routes.ts', 'icon': Icons.code, 'indent': 2},
          {'name': 'controllers/', 'icon': Icons.folder, 'indent': 1},
          {'name': 'middleware/', 'icon': Icons.folder, 'indent': 1},
          {'name': 'models/', 'icon': Icons.folder, 'indent': 1},
          {'name': 'openapi.yaml', 'icon': Icons.description, 'indent': 0},
        ],
      };
    } else if (deliverable.contains('test')) {
      return {
        'icon': Icons.check_circle_outline,
        'title': 'Test Suite Workspace',
        'mainFile': 'app.test.ts',
        'mainFileIcon': Icons.code,
        'waitingMessage': 'Ready to generate test coverage',
        'files': [
          {'name': '__tests__/', 'icon': Icons.folder, 'indent': 0},
          {'name': 'unit/', 'icon': Icons.folder, 'indent': 1},
          {'name': 'app.test.ts', 'icon': Icons.code, 'indent': 2},
          {'name': 'integration/', 'icon': Icons.folder, 'indent': 1},
          {'name': 'e2e/', 'icon': Icons.folder, 'indent': 1},
          {'name': 'jest.config.js', 'icon': Icons.settings, 'indent': 0},
          {'name': 'coverage/', 'icon': Icons.folder, 'indent': 0},
        ],
      };
    } else if (deliverable.contains('ci') || deliverable.contains('cd') ||
               deliverable.contains('devops') || deliverable.contains('pipeline')) {
      return {
        'icon': Icons.rocket_launch,
        'title': 'DevOps Pipeline Workspace',
        'mainFile': 'ci.yml',
        'mainFileIcon': Icons.settings,
        'waitingMessage': 'Ready to configure CI/CD pipeline',
        'files': [
          {'name': '.github/', 'icon': Icons.folder, 'indent': 0},
          {'name': 'workflows/', 'icon': Icons.folder, 'indent': 1},
          {'name': 'ci.yml', 'icon': Icons.settings, 'indent': 2},
          {'name': 'deploy.yml', 'icon': Icons.settings, 'indent': 2},
          {'name': 'Dockerfile', 'icon': Icons.inventory_2, 'indent': 0},
          {'name': 'docker-compose.yml', 'icon': Icons.settings, 'indent': 0},
          {'name': '.env.example', 'icon': Icons.lock, 'indent': 0},
        ],
      };
    } else if (deliverable.contains('review')) {
      return {
        'icon': Icons.rate_review,
        'title': 'Code Review Workspace',
        'mainFile': '.eslintrc.js',
        'mainFileIcon': Icons.settings,
        'waitingMessage': 'Ready to analyze code quality',
        'files': [
          {'name': '.eslintrc.js', 'icon': Icons.settings, 'indent': 0},
          {'name': '.prettierrc', 'icon': Icons.settings, 'indent': 0},
          {'name': 'tsconfig.json', 'icon': Icons.settings, 'indent': 0},
          {'name': 'src/', 'icon': Icons.folder, 'indent': 0},
          {'name': 'components/', 'icon': Icons.folder, 'indent': 1},
          {'name': 'services/', 'icon': Icons.folder, 'indent': 1},
          {'name': 'REVIEW_CHECKLIST.md', 'icon': Icons.checklist, 'indent': 0},
        ],
      };
    }

    // Default refactor workspace
    return {
      'icon': Icons.code,
      'title': 'Code Workspace',
      'mainFile': 'index.js',
      'mainFileIcon': Icons.javascript,
      'waitingMessage': 'Ready for code generation',
      'files': [
        {'name': 'src/', 'icon': Icons.folder, 'indent': 0},
        {'name': 'index.js', 'icon': Icons.javascript, 'indent': 1},
        {'name': 'package.json', 'icon': Icons.settings, 'indent': 0},
      ],
    };
  }

  Widget _buildMockFileItem(String name, IconData icon, int indent, ThemeColors colors) {
    return Padding(
      padding: EdgeInsets.only(
        left: indent * 12.0,
        bottom: SpacingTokens.xs,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: icon == Icons.folder
                ? const Color(0xFFDCB67A)
                : _getFileIconColor(name),
          ),
          const SizedBox(width: SpacingTokens.xs),
          Expanded(
            child: Text(
              name,
              style: TextStyles.bodySmall.copyWith(
                color: Colors.grey[300],
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Color _getFileIconColor(String fileName) {
    if (fileName.endsWith('.ts') || fileName.endsWith('.tsx')) {
      return const Color(0xFF3178C6); // TypeScript blue
    } else if (fileName.endsWith('.js') || fileName.endsWith('.jsx')) {
      return const Color(0xFFF7DF1E); // JavaScript yellow
    } else if (fileName.endsWith('.json') || fileName.endsWith('.yaml') || fileName.endsWith('.yml')) {
      return const Color(0xFFCB171E); // Config red
    } else if (fileName.endsWith('.md')) {
      return const Color(0xFF519ABA); // Markdown blue
    } else if (fileName.startsWith('.') || fileName.contains('config')) {
      return const Color(0xFF6D8086); // Config gray
    }
    return const Color(0xFF89D185); // Default green
  }

  Widget _buildActionHistoryPanel(ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.md),
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
              Icon(
                Icons.history,
                size: 16,
                color: colors.accent,
              ),
              const SizedBox(width: SpacingTokens.xs),
              Text(
                'Decision History',
                style: TextStyles.bodyMedium.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.md),
          Expanded(
            child: ListView.builder(
              itemCount: _actionHistory.length,
              itemBuilder: (context, index) {
                final action = _actionHistory[index];
                final isLatest = index == _actionHistory.length - 1;

                return Container(
                  margin: const EdgeInsets.only(bottom: SpacingTokens.sm),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isLatest
                              ? colors.accent
                              : colors.onSurfaceVariant,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: SpacingTokens.sm),
                      Expanded(
                        child: Text(
                          action,
                          style: TextStyles.bodySmall.copyWith(
                            color: isLatest
                                ? colors.accent
                                : colors.onSurfaceVariant,
                            fontWeight:
                                isLatest ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
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

  Widget _buildAnalyticsWorkspace(ThemeColors colors) {
    // Change content based on selected action
    String displayMode = 'initial';
    if (_currentActionContext != null) {
      if (_currentActionContext!.contains('Sales Data') ||
          _currentActionContext!.contains('Access')) {
        displayMode = 'data_loaded';
      } else if (_currentActionContext!.contains('Report') ||
          _currentActionContext!.contains('Generate')) {
        displayMode = 'report_view';
      } else if (_currentActionContext!.contains('Automation') ||
          _currentActionContext!.contains('Deploy')) {
        displayMode = 'dashboard_live';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Metrics cards row - update values based on mode
        Row(
          children: [
            Expanded(
                child: _buildMetricCard(
                    'Revenue',
                    displayMode == 'initial' ? '—' : '\$3.2M',
                    displayMode == 'initial' ? '—' : '+15%',
                    colors.success,
                    colors)),
            const SizedBox(width: SpacingTokens.md),
            Expanded(
                child: _buildMetricCard(
                    'Customers',
                    displayMode == 'initial' ? '—' : '2,847',
                    displayMode == 'initial' ? '—' : '+22%',
                    colors.primary,
                    colors)),
            const SizedBox(width: SpacingTokens.md),
            Expanded(
                child: _buildMetricCard(
                    'Avg Deal',
                    displayMode == 'initial' ? '—' : '\$45K',
                    displayMode == 'initial' ? '—' : '+8%',
                    colors.accent,
                    colors)),
          ],
        ),

        const SizedBox(height: SpacingTokens.xl),

        // Chart/content area - changes based on mode
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
              border: Border.all(color: colors.border),
            ),
            child: _buildAnalyticsContent(displayMode, colors),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsContent(String mode, ThemeColors colors) {
    switch (mode) {
      case 'data_loaded':
        return Padding(
          padding: const EdgeInsets.all(SpacingTokens.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle, color: colors.success, size: 20),
                  const SizedBox(width: SpacingTokens.sm),
                  Text(
                    'Sales Data Loaded',
                    style: TextStyles.sectionTitle
                        .copyWith(color: colors.onSurface),
                  ),
                ],
              ),
              const SizedBox(height: SpacingTokens.lg),
              Expanded(
                child: ListView(
                  children: [
                    _buildDataRow(
                        'Q4 Total Revenue', '\$3.2M', colors.success, colors),
                    _buildDataRow(
                        'Q4 Customer Count', '2,847', colors.primary, colors),
                    _buildDataRow(
                        'Average Deal Size', '\$45K', colors.accent, colors),
                    _buildDataRow(
                        'Conversion Rate', '18.5%', colors.success, colors),
                    _buildDataRow('Top Product', 'Enterprise Suite',
                        colors.primary, colors),
                  ],
                ),
              ),
            ],
          ),
        );
      case 'report_view':
        return Padding(
          padding: const EdgeInsets.all(SpacingTokens.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.description, color: colors.primary, size: 20),
                  const SizedBox(width: SpacingTokens.sm),
                  Text(
                    'Executive Summary Report',
                    style: TextStyles.sectionTitle
                        .copyWith(color: colors.onSurface),
                  ),
                ],
              ),
              const SizedBox(height: SpacingTokens.lg),
              Expanded(
                child: ListView(
                  children: [
                    _buildReportSection(
                        'Key Findings',
                        'Strong Q4 performance with 15% revenue growth',
                        colors),
                    _buildReportSection('Recommendations',
                        'Expand enterprise sales team by 30%', colors),
                    _buildReportSection('Action Items',
                        'Launch customer retention program', colors),
                    _buildReportSection(
                        'Q1 Forecast', 'Projected +25% revenue growth', colors),
                  ],
                ),
              ),
            ],
          ),
        );
      case 'dashboard_live':
        return Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.dashboard, size: 64, color: colors.success),
                  const SizedBox(height: SpacingTokens.md),
                  Text(
                    'Live Analytics Dashboard',
                    style:
                        TextStyles.pageTitle.copyWith(color: colors.onSurface),
                  ),
                  const SizedBox(height: SpacingTokens.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SpacingTokens.md,
                      vertical: SpacingTokens.sm,
                    ),
                    decoration: BoxDecoration(
                      color: colors.success.withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(BorderRadiusTokens.md),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: colors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: SpacingTokens.sm),
                        Text(
                          'Real-time Updates Active',
                          style: TextStyles.bodyMedium
                              .copyWith(color: colors.success),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      default:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bar_chart,
                  size: 64, color: colors.primary.withOpacity(0.5)),
              const SizedBox(height: SpacingTokens.md),
              Text(
                'Ready for Analysis',
                style: TextStyles.bodyLarge
                    .copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: SpacingTokens.sm),
              Text(
                'Choose an action to begin',
                style: TextStyles.bodyMedium
                    .copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildDataRow(
      String label, String value, Color accentColor, ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.md),
      margin: const EdgeInsets.only(bottom: SpacingTokens.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyles.bodyMedium.copyWith(color: colors.onSurface),
          ),
          Text(
            value,
            style: TextStyles.bodyLarge.copyWith(
              color: accentColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportSection(String title, String content, ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.md),
      margin: const EdgeInsets.only(bottom: SpacingTokens.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyles.bodyMedium.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: SpacingTokens.xs),
          Text(
            content,
            style: TextStyles.bodyMedium.copyWith(color: colors.onSurface),
          ),
        ],
      ),
    );
  }

  Widget _buildCodingWorkspace(ThemeColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Coding tools header
        Row(
          children: [
            _buildToolButton('Git', Icons.merge_type, colors),
            const SizedBox(width: SpacingTokens.sm),
            _buildToolButton('Terminal', Icons.terminal, colors),
            const SizedBox(width: SpacingTokens.sm),
            _buildToolButton('Tests', Icons.check_circle_outline, colors),
            const SizedBox(width: SpacingTokens.sm),
            _buildToolButton('Deploy', Icons.rocket_launch, colors),
          ],
        ),

        const SizedBox(height: SpacingTokens.xl),

        // Code editor placeholder
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
              border: Border.all(
                  color: colors.border, style: BorderStyle.solid, width: 2),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.code,
                      size: 64, color: colors.primary.withOpacity(0.5)),
                  const SizedBox(height: SpacingTokens.md),
                  Text(
                    'Code Workspace',
                    style: TextStyles.bodyLarge
                        .copyWith(color: colors.onSurfaceVariant),
                  ),
                  Text(
                    'AI-generated code will appear here',
                    style: TextStyles.bodySmall
                        .copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOperationsWorkspace(ThemeColors colors) {
    // Change content based on selected action
    String displayMode = 'initial';
    String tasksCount = '—';
    String teamLoad = '—';
    String efficiency = '—';

    if (_currentActionContext != null) {
      if (_currentActionContext!.contains('Analysis') ||
          _currentActionContext!.contains('Proceed')) {
        displayMode = 'analyzing';
        tasksCount = '24';
        teamLoad = '78%';
        efficiency = '—';
      } else if (_currentActionContext!.contains('Apply') ||
          _currentActionContext!.contains('Implement')) {
        displayMode = 'optimized';
        tasksCount = '24';
        teamLoad = '65%';
        efficiency = '+23%';
      } else if (_currentActionContext!.contains('Monitoring') ||
          _currentActionContext!.contains('Deploy')) {
        displayMode = 'live_monitoring';
        tasksCount = '22';
        teamLoad = '62%';
        efficiency = '+28%';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status indicators - update values based on mode
        Row(
          children: [
            Expanded(
                child: _buildStatusCard('Active Tasks', tasksCount,
                    Icons.task_alt, colors.primary, colors)),
            const SizedBox(width: SpacingTokens.md),
            Expanded(
                child: _buildStatusCard(
                    'Team Load',
                    teamLoad,
                    Icons.group,
                    displayMode == 'optimized' ||
                            displayMode == 'live_monitoring'
                        ? colors.success
                        : colors.warning,
                    colors)),
            const SizedBox(width: SpacingTokens.md),
            Expanded(
                child: _buildStatusCard('Efficiency', efficiency,
                    Icons.trending_up, colors.success, colors)),
          ],
        ),

        const SizedBox(height: SpacingTokens.xl),

        // Operations content - changes based on mode
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(SpacingTokens.lg),
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
              border: Border.all(color: colors.border),
            ),
            child: _buildOperationsContent(displayMode, colors),
          ),
        ),
      ],
    );
  }

  Widget _buildOperationsContent(String mode, ThemeColors colors) {
    switch (mode) {
      case 'analyzing':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: colors.primary, size: 20),
                const SizedBox(width: SpacingTokens.sm),
                Text(
                  'Schedule Analysis',
                  style:
                      TextStyles.sectionTitle.copyWith(color: colors.onSurface),
                ),
              ],
            ),
            const SizedBox(height: SpacingTokens.md),
            Expanded(
              child: ListView(
                children: [
                  _buildConflictItem(
                      'Resource Conflict',
                      'Team A & B both scheduled for Conference Room 1',
                      colors.warning,
                      colors),
                  _buildConflictItem('Overallocation',
                      'Sarah Johnson: 120% capacity', colors.error, colors),
                  _buildConflictItem(
                      'Gap Detected',
                      '2-hour idle time for Dev Team on Tuesday',
                      colors.accent,
                      colors),
                ],
              ),
            ),
          ],
        );
      case 'optimized':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: colors.success, size: 20),
                const SizedBox(width: SpacingTokens.sm),
                Text(
                  'Optimized Schedule',
                  style:
                      TextStyles.sectionTitle.copyWith(color: colors.onSurface),
                ),
              ],
            ),
            const SizedBox(height: SpacingTokens.md),
            Expanded(
              child: ListView(
                children: [
                  _buildTimelineItem(
                      '9:00 AM', 'Team Standup', 'All hands', colors),
                  _buildTimelineItem(
                      '9:30 AM', 'Dev Team Sprint', 'Dev Team', colors),
                  _buildTimelineItem(
                      '10:30 AM', 'Design Review', 'Product Team', colors),
                  _buildTimelineItem(
                      '2:00 PM', 'Sprint Planning', 'All hands', colors),
                  _buildTimelineItem(
                      '4:00 PM', 'Client Presentation', 'Sales Team', colors),
                ],
              ),
            ),
          ],
        );
      case 'live_monitoring':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.monitor_heart, color: colors.success, size: 20),
                const SizedBox(width: SpacingTokens.sm),
                Text(
                  'Live Performance Monitoring',
                  style:
                      TextStyles.sectionTitle.copyWith(color: colors.onSurface),
                ),
                const Spacer(),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: SpacingTokens.xs),
                Text(
                  'Active',
                  style: TextStyles.bodySmall.copyWith(color: colors.success),
                ),
              ],
            ),
            const SizedBox(height: SpacingTokens.md),
            Expanded(
              child: ListView(
                children: [
                  _buildMetricRow(
                      'Task Completion Rate', '94%', colors.success, colors),
                  _buildMetricRow('Average Response Time', '1.2 hrs',
                      colors.success, colors),
                  _buildMetricRow(
                      'Resource Utilization', '62%', colors.success, colors),
                  _buildMetricRow(
                      'On-Time Delivery', '98%', colors.success, colors),
                ],
              ),
            ),
          ],
        );
      default:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.schedule,
                  size: 64, color: colors.primary.withOpacity(0.5)),
              const SizedBox(height: SpacingTokens.md),
              Text(
                'Ready for Optimization',
                style: TextStyles.bodyLarge
                    .copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: SpacingTokens.sm),
              Text(
                'Choose an action to begin',
                style: TextStyles.bodyMedium
                    .copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildConflictItem(
      String type, String description, Color accentColor, ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.md),
      margin: const EdgeInsets.only(bottom: SpacingTokens.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
        border: Border.all(color: accentColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: accentColor, size: 20),
          const SizedBox(width: SpacingTokens.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type,
                  style: TextStyles.bodyMedium.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: TextStyles.bodySmall
                      .copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(
      String label, String value, Color accentColor, ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.md),
      margin: const EdgeInsets.only(bottom: SpacingTokens.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyles.bodyMedium.copyWith(color: colors.onSurface),
          ),
          Text(
            value,
            style: TextStyles.bodyLarge.copyWith(
              color: accentColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultWorkspace(ThemeColors colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome,
              size: 64, color: colors.primary.withOpacity(0.5)),
          const SizedBox(height: SpacingTokens.md),
          Text(
            'AI Workspace',
            style: TextStyles.pageTitle.copyWith(color: colors.onSurface),
          ),
          Text(
            'Your AI assistant is ready to help',
            style:
                TextStyles.bodyMedium.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, String change,
      Color accentColor, ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style:
                TextStyles.bodySmall.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: SpacingTokens.xs),
          Text(
            value,
            style: TextStyles.pageTitle.copyWith(color: colors.onSurface),
          ),
          const SizedBox(height: SpacingTokens.xs),
          Text(
            change,
            style: TextStyles.bodySmall.copyWith(
              color: accentColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton(String label, IconData icon, ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.md,
        vertical: SpacingTokens.sm,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colors.primary),
          const SizedBox(width: SpacingTokens.xs),
          Text(
            label,
            style: TextStyles.bodySmall.copyWith(color: colors.onSurface),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String label, String value, IconData icon,
      Color accentColor, ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: accentColor, size: 24),
          const SizedBox(height: SpacingTokens.sm),
          Text(
            value,
            style: TextStyles.sectionTitle.copyWith(color: colors.onSurface),
          ),
          Text(
            label,
            style:
                TextStyles.bodySmall.copyWith(color: colors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(
      String time, String title, String team, ThemeColors colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: SpacingTokens.md),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: colors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: SpacingTokens.md),
          Expanded(
            child: Row(
              children: [
                Text(
                  time,
                  style: TextStyles.bodySmall.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: SpacingTokens.md),
                Expanded(
                  child: Text(
                    title,
                    style:
                        TextStyles.bodyMedium.copyWith(color: colors.onSurface),
                  ),
                ),
                Text(
                  team,
                  style: TextStyles.bodySmall
                      .copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationModal(ThemeColors colors) {
    return Container(
      color: Colors.black.withOpacity(0.6),
      child: Center(
        child: ScaleTransition(
          scale: _modalAnimation,
          child: TweenAnimationBuilder<double>(
            duration: const Duration(seconds: 2),
            tween: Tween(begin: 0.0, end: 1.0),
            onEnd: () {
              // Restart glow animation
              if (mounted) setState(() {});
            },
            builder: (context, glowValue, child) {
              return Container(
                margin: const EdgeInsets.all(SpacingTokens.xxl),
                constraints: BoxConstraints(
                  maxWidth: _showChatInModal ? 800 : 600,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(BorderRadiusTokens.xl),
                  border: Border.all(
                    color: colors.primary.withOpacity(0.6),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                    // Pulsing glow effect
                    BoxShadow(
                      color: colors.primary.withOpacity(0.4 * glowValue),
                      blurRadius: 30 * glowValue,
                      spreadRadius: 5 * glowValue,
                    ),
                    BoxShadow(
                      color: colors.primary.withOpacity(0.2 * glowValue),
                      blurRadius: 50 * glowValue,
                      spreadRadius: 10 * glowValue,
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: _currentEnhancedVerification != null
                ? _buildEnhancedVerificationContent(colors)
                : _buildSimpleVerificationContent(colors),
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleVerificationContent(ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 1000),
                tween: Tween(begin: 0.8, end: 1.2),
                onEnd: () {
                  // Restart icon pulse animation
                  if (mounted) setState(() {});
                },
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colors.primary.withOpacity(0.3),
                            blurRadius: 8 * scale,
                            spreadRadius: 2 * scale,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.verified_user_outlined,
                        color: colors.primary,
                        size: 24,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: SpacingTokens.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Human Verification Required',
                      style: TextStyles.sectionTitle.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Container(
                      width: 40,
                      height: 3,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 800),
                        tween: Tween(begin: 0.0, end: 1.0),
                        onEnd: () {
                          if (mounted) setState(() {});
                        },
                        builder: (context, progress, child) {
                          return Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                stops: [0.0, progress, 1.0],
                                colors: [
                                  colors.primary.withOpacity(0.3),
                                  colors.primary,
                                  colors.primary.withOpacity(0.3),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.lg),
          Container(
            padding: const EdgeInsets.all(SpacingTokens.md),
            decoration: BoxDecoration(
              color: colors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
              border: Border.all(color: colors.primary.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Proposed Action: ${_currentVerification?.action ?? ""}',
                  style: TextStyles.bodyMedium.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: SpacingTokens.sm),
                Text(
                  _currentVerification?.details ?? '',
                  style: TextStyles.bodyMedium.copyWith(
                    color: colors.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: SpacingTokens.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: AsmblButton.secondary(
                  text: 'Reject',
                  onPressed: _rejectVerification,
                  icon: Icons.close,
                ),
              ),
              const SizedBox(width: SpacingTokens.md),
              Flexible(
                child: AsmblButton.primary(
                  text: 'Approve',
                  onPressed: _approveVerification,
                  icon: Icons.check,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedVerificationContent(ThemeColors colors) {
    if (_showChatInModal) {
      return _buildChatInterface(colors);
    }

    // Get current agent confidence for display
    final currentConfidence = _getCurrentAgentConfidence();
    final thresholdPercent = (widget.confidenceThreshold * 100).toInt();
    final confidencePercent = (currentConfidence * 100).toInt();
    final isBelowThreshold = currentConfidence < widget.confidenceThreshold;

    return Container(
      padding: const EdgeInsets.all(SpacingTokens.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header (non-scrollable)
          Row(
            children: [
              Icon(
                Icons.psychology,
                color: colors.primary,
                size: 24,
              ),
              const SizedBox(width: SpacingTokens.sm),
              Expanded(
                child: Text(
                  _currentEnhancedVerification?.title ?? 'AI Decision Required',
                  style: TextStyles.sectionTitle.copyWith(
                    color: colors.onSurface,
                  ),
                ),
              ),
              IconButton(
                onPressed: _toggleModalChat,
                icon: Icon(
                  Icons.chat,
                  color: colors.onSurfaceVariant,
                  size: 20,
                ),
                tooltip: 'Chat with AI',
              ),
            ],
          ),

          const SizedBox(height: SpacingTokens.md),

          // Scrollable content area
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Confidence indicator banner
                  _buildConfidenceBanner(colors, confidencePercent,
                      thresholdPercent, isBelowThreshold),

                  const SizedBox(height: SpacingTokens.lg),

                  // Situation description
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(SpacingTokens.md),
                    decoration: BoxDecoration(
                      color: colors.background,
                      borderRadius:
                          BorderRadius.circular(BorderRadiusTokens.md),
                      border: Border.all(color: colors.border),
                    ),
                    child: Text(
                      _currentEnhancedVerification?.situation ?? '',
                      style: TextStyles.bodyMedium.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                  ),

                  const SizedBox(height: SpacingTokens.lg),

                  // Code diff section (for coding agent)
                  if (_currentEnhancedVerification?.codeBefore != null ||
                      _currentEnhancedVerification?.codeAfter != null) ...[
                    Text(
                      'Code Changes',
                      style: TextStyles.bodyLarge.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: SpacingTokens.md),

                    // Before/After code comparison - use Column layout for better fit
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Before code
                        if (_currentEnhancedVerification?.codeBefore != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(SpacingTokens.sm),
                                decoration: BoxDecoration(
                                  color: colors.error.withOpacity(0.1),
                                  borderRadius: const BorderRadius.only(
                                    topLeft:
                                        Radius.circular(BorderRadiusTokens.md),
                                    topRight:
                                        Radius.circular(BorderRadiusTokens.md),
                                  ),
                                  border: Border.all(
                                      color: colors.error.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.remove_circle_outline,
                                        size: 16, color: colors.error),
                                    const SizedBox(width: SpacingTokens.xs),
                                    Text(
                                      'Before',
                                      style: TextStyles.bodySmall.copyWith(
                                        color: colors.error,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: double.infinity,
                                constraints:
                                    const BoxConstraints(maxHeight: 120),
                                padding: const EdgeInsets.all(SpacingTokens.md),
                                decoration: BoxDecoration(
                                  color: colors.surface,
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft:
                                        Radius.circular(BorderRadiusTokens.md),
                                    bottomRight:
                                        Radius.circular(BorderRadiusTokens.md),
                                  ),
                                  border: Border.all(color: colors.border),
                                ),
                                child: SingleChildScrollView(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Text(
                                      _currentEnhancedVerification!.codeBefore!,
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 11,
                                        color: colors.onSurface,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                        if (_currentEnhancedVerification?.codeBefore != null &&
                            _currentEnhancedVerification?.codeAfter != null)
                          const SizedBox(height: SpacingTokens.md),

                        // After code
                        if (_currentEnhancedVerification?.codeAfter != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(SpacingTokens.sm),
                                decoration: BoxDecoration(
                                  color: colors.success.withOpacity(0.1),
                                  borderRadius: const BorderRadius.only(
                                    topLeft:
                                        Radius.circular(BorderRadiusTokens.md),
                                    topRight:
                                        Radius.circular(BorderRadiusTokens.md),
                                  ),
                                  border: Border.all(
                                      color: colors.success.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.add_circle_outline,
                                        size: 16, color: colors.success),
                                    const SizedBox(width: SpacingTokens.xs),
                                    Text(
                                      'After',
                                      style: TextStyles.bodySmall.copyWith(
                                        color: colors.success,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: double.infinity,
                                constraints:
                                    const BoxConstraints(maxHeight: 120),
                                padding: const EdgeInsets.all(SpacingTokens.md),
                                decoration: BoxDecoration(
                                  color: colors.surface,
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft:
                                        Radius.circular(BorderRadiusTokens.md),
                                    bottomRight:
                                        Radius.circular(BorderRadiusTokens.md),
                                  ),
                                  border: Border.all(color: colors.border),
                                ),
                                child: SingleChildScrollView(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Text(
                                      _currentEnhancedVerification!.codeAfter!,
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 11,
                                        color: colors.onSurface,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),

                    const SizedBox(height: SpacingTokens.lg),
                  ],

                  // Proposed actions
                  Text(
                    'Proposed Actions',
                    style: TextStyles.bodyLarge.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: SpacingTokens.md),

                  ...(_currentEnhancedVerification?.proposedActions ?? []).map(
                    (action) => Container(
                      margin: const EdgeInsets.only(bottom: SpacingTokens.sm),
                      child: _buildActionCard(action, colors),
                    ),
                  ),

                  const SizedBox(height: SpacingTokens.lg),

                  // Chat button
                  AsmblButton.outline(
                    text: 'Discuss with AI',
                    onPressed: _toggleModalChat,
                    icon: Icons.chat,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(ProposedAction action, ThemeColors colors) {
    return GestureDetector(
      onTap: () => _selectAction(action),
      child: Container(
        padding: const EdgeInsets.all(SpacingTokens.md),
        decoration: BoxDecoration(
          color: action.isRecommended
              ? colors.primary.withOpacity(0.05)
              : colors.surface,
          borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
          border: Border.all(
            color: action.isRecommended ? colors.primary : colors.border,
            width: action.isRecommended ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              action.icon,
              color: action.color ??
                  (action.isRecommended
                      ? colors.primary
                      : colors.onSurfaceVariant),
              size: 24,
            ),
            const SizedBox(width: SpacingTokens.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        action.title,
                        style: TextStyles.bodyMedium.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (action.isRecommended) ...[
                        const SizedBox(width: SpacingTokens.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: SpacingTokens.xs,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius:
                                BorderRadius.circular(BorderRadiusTokens.xs),
                          ),
                          child: Text(
                            'RECOMMENDED',
                            style: TextStyles.bodySmall.copyWith(
                              color: colors.surface,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: SpacingTokens.xs),
                  Text(
                    action.description,
                    style: TextStyles.bodySmall.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatInterface(ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Column(
        children: [
          // Chat header
          Row(
            children: [
              IconButton(
                onPressed: _toggleModalChat,
                icon: Icon(
                  Icons.arrow_back,
                  color: colors.onSurfaceVariant,
                ),
              ),
              Icon(
                Icons.chat,
                color: colors.primary,
                size: 24,
              ),
              const SizedBox(width: SpacingTokens.sm),
              Expanded(
                child: Text(
                  'Discuss Decision',
                  style: TextStyles.sectionTitle.copyWith(
                    color: colors.onSurface,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: SpacingTokens.lg),

          // Chat messages area
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(SpacingTokens.md),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildChatMessage(
                    'AI Assistant',
                    'I\'ve analyzed the situation. Here\'s what I found: The current approach has some risks but also potential benefits. What specific concerns do you have?',
                    true,
                    colors,
                  ),
                  const SizedBox(height: SpacingTokens.md),
                  _buildChatMessage(
                    'You',
                    'What are the main risks with option 2?',
                    false,
                    colors,
                  ),
                  const SizedBox(height: SpacingTokens.md),
                  _buildChatMessage(
                    'AI Assistant',
                    'The main risks include potential data inconsistency during the migration phase and temporary performance degradation. However, the long-term benefits outweigh these short-term challenges.',
                    true,
                    colors,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: SpacingTokens.md),

          // Chat input
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SpacingTokens.md,
                    vertical: SpacingTokens.sm,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
                    border: Border.all(color: colors.border),
                  ),
                  child: Text(
                    'Type your question...',
                    style: TextStyles.bodyMedium.copyWith(
                      color: colors.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: SpacingTokens.sm),
              Container(
                padding: const EdgeInsets.all(SpacingTokens.sm),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
                ),
                child: Icon(
                  Icons.send,
                  color: colors.surface,
                  size: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChatMessage(
      String sender, String message, bool isAI, ThemeColors colors) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: isAI ? colors.primary : colors.accent,
          child: Icon(
            isAI ? Icons.smart_toy : Icons.person,
            size: 16,
            color: colors.surface,
          ),
        ),
        const SizedBox(width: SpacingTokens.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sender,
                style: TextStyles.bodySmall.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: SpacingTokens.xs),
              Text(
                message,
                style: TextStyles.bodyMedium.copyWith(
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExcalidrawCanvas(ThemeColors colors) {
    // Dynamic agent output display - shows what the agent is creating
    return Container(
      margin: const EdgeInsets.all(SpacingTokens.md),
      padding: const EdgeInsets.all(SpacingTokens.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
        border: Border.all(color: colors.border),
      ),
      child: _buildAgentOutputDisplay(colors),
    );
  }

  Widget _buildAgentOutputDisplay(ThemeColors colors) {
    // Show output based on deliverable type and current actions
    final deliverable = widget.selectedDeliverable;

    if (_actionHistory.isEmpty) {
      return _buildEmptyOutputState(colors);
    }

    // Determine output type based on deliverable
    if (deliverable != null) {
      if (deliverable.contains('Dashboard')) {
        return _buildDashboardOutput(colors);
      } else if (deliverable.contains('Report')) {
        return _buildReportOutput(colors);
      } else if (deliverable.contains('Application') ||
          deliverable.contains('Code')) {
        return _buildCodeOutput(colors);
      } else if (deliverable.contains('Documentation')) {
        return _buildDocumentationOutput(colors);
      } else if (deliverable.contains('Playbook') ||
          deliverable.contains('Process')) {
        return _buildPlaybookOutput(colors);
      }
    }

    // Fallback: generic output based on agent type
    switch (widget.selectedAgentType) {
      case 0: // Business Analyst
        return _buildDashboardOutput(colors);
      case 1: // Operations Manager
        return _buildPlaybookOutput(colors);
      case 2: // Coding Agent
        return _buildCodeOutput(colors);
      default:
        return _buildEmptyOutputState(colors);
    }
  }

  Widget _buildEmptyOutputState(ThemeColors colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.output_outlined,
            size: 64,
            color: colors.onSurfaceVariant.withOpacity(0.3),
          ),
          const SizedBox(height: SpacingTokens.lg),
          Text(
            'Agent Output',
            style: TextStyles.sectionTitle.copyWith(color: colors.onSurface),
          ),
          const SizedBox(height: SpacingTokens.sm),
          Text(
            'AI will generate deliverables here',
            style:
                TextStyles.bodyMedium.copyWith(color: colors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardOutput(ThemeColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Icon(Icons.dashboard, color: colors.primary, size: 20),
            const SizedBox(width: SpacingTokens.sm),
            Text(
              widget.selectedDeliverable ?? 'Analytics Dashboard',
              style: TextStyles.sectionTitle.copyWith(color: colors.onSurface),
            ),
          ],
        ),
        const SizedBox(height: SpacingTokens.lg),
        // Metrics grid
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: SpacingTokens.md,
            crossAxisSpacing: SpacingTokens.md,
            childAspectRatio: 2,
            children: [
              _buildMetricCard(
                  'Total Revenue', '\$2.4M', '+18%', colors.success, colors),
              _buildMetricCard(
                  'Active Users', '12.5K', '+12%', colors.primary, colors),
              _buildMetricCard(
                  'Conversion Rate', '24.8%', '+5%', colors.accent, colors),
              _buildMetricCard(
                  'Avg Session', '8m 32s', '+2%', colors.success, colors),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReportOutput(ThemeColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.description, color: colors.primary, size: 20),
            const SizedBox(width: SpacingTokens.sm),
            Text(
              widget.selectedDeliverable ?? 'Analysis Report',
              style: TextStyles.sectionTitle.copyWith(color: colors.onSurface),
            ),
          ],
        ),
        const SizedBox(height: SpacingTokens.lg),
        Expanded(
          child: ListView(
            children: [
              _buildReportSection(
                  'Executive Summary',
                  'Key findings from data analysis show strong growth trends across all metrics...',
                  colors),
              _buildReportSection('Key Metrics',
                  'Revenue: +18% | Users: +12% | Engagement: +15%', colors),
              _buildReportSection(
                  'Recommendations',
                  '1. Expand into new markets\n2. Optimize conversion funnel\n3. Increase engagement initiatives',
                  colors),
              _buildReportSection(
                  'Next Steps',
                  'Schedule follow-up meeting to discuss implementation timeline',
                  colors),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCodeOutput(ThemeColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.code, color: colors.primary, size: 20),
            const SizedBox(width: SpacingTokens.sm),
            Text(
              widget.selectedDeliverable ?? 'Application Code',
              style: TextStyles.sectionTitle.copyWith(color: colors.onSurface),
            ),
          ],
        ),
        const SizedBox(height: SpacingTokens.lg),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(SpacingTokens.md),
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
              border: Border.all(color: colors.border),
            ),
            child: ListView(
              children: [
                _buildCodeBlock(
                    'app.dart', 'Main application entry point', colors),
                _buildCodeBlock(
                    'api_service.dart', 'API integration layer', colors),
                _buildCodeBlock(
                    'auth_controller.dart', 'Authentication logic', colors),
                _buildCodeBlock(
                    'dashboard_screen.dart', 'Dashboard UI', colors),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentationOutput(ThemeColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.article, color: colors.primary, size: 20),
            const SizedBox(width: SpacingTokens.sm),
            Text(
              widget.selectedDeliverable ?? 'Documentation',
              style: TextStyles.sectionTitle.copyWith(color: colors.onSurface),
            ),
          ],
        ),
        const SizedBox(height: SpacingTokens.lg),
        Expanded(
          child: ListView(
            children: [
              _buildDocSection('Getting Started',
                  'Installation and setup instructions...', colors),
              _buildDocSection('API Reference',
                  'Complete API documentation with examples...', colors),
              _buildDocSection('Best Practices',
                  'Recommended patterns and approaches...', colors),
              _buildDocSection(
                  'Troubleshooting', 'Common issues and solutions...', colors),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaybookOutput(ThemeColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome, color: colors.primary, size: 20),
            const SizedBox(width: SpacingTokens.sm),
            Text(
              widget.selectedDeliverable ?? 'Automation Playbook',
              style: TextStyles.sectionTitle.copyWith(color: colors.onSurface),
            ),
          ],
        ),
        const SizedBox(height: SpacingTokens.lg),
        Expanded(
          child: ListView(
            children: [
              _buildPlaybookStep(
                  '1. Schedule Optimization',
                  'Automated team scheduling with conflict resolution',
                  true,
                  colors),
              _buildPlaybookStep('2. Notification System',
                  'Real-time alerts for project milestones', true, colors),
              _buildPlaybookStep('3. Resource Allocation',
                  'Smart distribution of team resources', false, colors),
              _buildPlaybookStep('4. Performance Monitoring',
                  'Continuous tracking of operational metrics', false, colors),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCodeBlock(
      String filename, String description, ThemeColors colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: SpacingTokens.sm),
      padding: const EdgeInsets.all(SpacingTokens.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.insert_drive_file, size: 16, color: colors.primary),
          const SizedBox(width: SpacingTokens.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  filename,
                  style: TextStyles.bodyMedium.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: TextStyles.bodySmall
                      .copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocSection(String title, String content, ThemeColors colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: SpacingTokens.md),
      padding: const EdgeInsets.all(SpacingTokens.md),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyles.bodyLarge.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: SpacingTokens.xs),
          Text(
            content,
            style:
                TextStyles.bodyMedium.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaybookStep(
      String title, String description, bool completed, ThemeColors colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: SpacingTokens.sm),
      padding: const EdgeInsets.all(SpacingTokens.md),
      decoration: BoxDecoration(
        color: completed ? colors.success.withOpacity(0.05) : colors.background,
        borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
        border: Border.all(color: completed ? colors.success : colors.border),
      ),
      child: Row(
        children: [
          Icon(
            completed ? Icons.check_circle : Icons.radio_button_unchecked,
            color: completed ? colors.success : colors.onSurfaceVariant,
            size: 20,
          ),
          const SizedBox(width: SpacingTokens.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyles.bodyMedium.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: TextStyles.bodySmall
                      .copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _triggerWireframeGeneration() {
    debugPrint(
        '🎯 _triggerWireframeGeneration called, _canvasStage: $_canvasStage');
    debugPrint(
        '🎯 _excalidrawKey.currentState: ${_excalidrawKey.currentState}');

    // Add wireframe elements based on canvas stage
    if (_excalidrawKey.currentState != null) {
      debugPrint(
          '🎯 Canvas state exists, calling addWireframeTemplate for stage $_canvasStage');
      switch (_canvasStage) {
        case 1: // Wireframe stage
          (_excalidrawKey.currentState as dynamic).addWireframeTemplate();
          break;
        case 2: // Styled stage - could add more elements
          // Future: Add styled elements programmatically
          (_excalidrawKey.currentState as dynamic).addWireframeTemplate();
          break;
        case 3: // Interactive stage - could add interactive elements
          // Future: Add interactive annotations
          (_excalidrawKey.currentState as dynamic).addWireframeTemplate();
          break;
      }
    } else {
      debugPrint(
          '❌ Cannot trigger wireframe generation - canvas state is null');
    }
  }

  Widget _buildAnalysisStatusBar(ThemeColors colors) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.lg),
        child: Row(
          children: [
            // Analysis type indicator
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: SpacingTokens.sm,
                vertical: SpacingTokens.xs,
              ),
              decoration: BoxDecoration(
                color: colors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.psychology,
                    size: 16,
                    color: colors.primary,
                  ),
                  const SizedBox(width: SpacingTokens.xs),
                  Text(
                    'AI Analysis: ${_getAnalysisType()}',
                    style: TextStyles.bodySmall.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: SpacingTokens.md),

            // Current step
            Text(
              'Stage ${_currentStage + 1}/${_stages.length}',
              style: TextStyles.bodySmall.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),

            const Spacer(),

            // Model info
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.memory,
                  size: 14,
                  color: colors.accent,
                ),
                const SizedBox(width: SpacingTokens.xs),
                Text(
                  _getActiveModelName(),
                  style: TextStyles.bodySmall.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            const SizedBox(width: SpacingTokens.md),

            // Confidence indicator
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: SpacingTokens.sm,
                vertical: SpacingTokens.xs,
              ),
              decoration: BoxDecoration(
                color: _getBaseConfidence() > 0.9
                    ? colors.success.withOpacity(0.1)
                    : colors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _getBaseConfidence() > 0.9
                          ? colors.success
                          : colors.warning,
                    ),
                  ),
                  const SizedBox(width: SpacingTokens.xs),
                  Text(
                    '${(_getBaseConfidence() * 100).toStringAsFixed(0)}%',
                    style: TextStyles.bodySmall.copyWith(
                      color: _getBaseConfidence() > 0.9
                          ? colors.success
                          : colors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DemoStage {
  final String title;
  final String description;
  final IconData icon;
  final Duration duration;

  const DemoStage({
    required this.title,
    required this.description,
    required this.icon,
    required this.duration,
  });
}

class AgentInfo {
  final String name;
  final IconData icon;
  final Color color;
  double confidence;

  AgentInfo({
    required this.name,
    required this.icon,
    required this.color,
    required this.confidence,
  });
}

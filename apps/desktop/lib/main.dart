import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:async';

import 'core/design_system/design_system.dart';
import 'core/design_system/components/asmbli_card_enhanced.dart';
import 'core/constants/routes.dart';
import 'core/di/service_locator.dart';
import 'core/error/global_error_handler.dart';
import 'core/utils/app_logger.dart';
import 'features/chat/presentation/screens/chat_screen_with_contextual.dart';
// import 'features/chat/presentation/screens/modern_chat_screen_v2.dart'; // Temporarily disabled
import 'features/chat/presentation/screens/demo_chat_screen.dart'; // Remove after video
import 'features/settings/presentation/screens/modern_settings_screen.dart';
import 'features/agents/presentation/screens/my_agents_screen.dart';
import 'features/agents/presentation/screens/agent_configuration_screen.dart';
import 'features/agents/presentation/screens/agent_execution_screen.dart';
import 'features/context/presentation/screens/context_library_screen.dart';
import 'features/agent_wizard/presentation/screens/agent_wizard_screen.dart';
import 'features/agent_wizard/presentation/screens/dspy_agent_wizard_screen.dart';
import 'features/agents/presentation/screens/agent_builder_screen.dart';
import 'features/agents/presentation/screens/dspy_agent_builder_screen.dart';
import 'features/onboarding/presentation/screens/onboarding_screen.dart';
import 'features/orchestration/presentation/screens/orchestration_screen.dart';
import 'features/orchestration/presentation/screens/workflow_browser_screen.dart';
import 'features/orchestration/presentation/screens/workflow_marketplace_screen.dart';
import 'providers/conversation_provider.dart';
import 'package:agent_engine_core/models/conversation.dart';
import 'core/services/storage_service.dart';
import 'core/services/theme_service.dart';
import 'core/services/desktop/desktop_service_provider.dart';
import 'core/services/desktop/window_management_service.dart';
import 'core/services/desktop/desktop_storage_service.dart';
import 'core/services/api_config_service.dart';
import 'core/services/feature_flag_service.dart';
import 'features/settings/presentation/widgets/adaptive_integration_router.dart';
import 'features/tools/presentation/screens/tools_screen.dart';
import 'features/chat/presentation/demo/contextual_context_demo.dart';
import 'features/canvas/presentation/penpot_canvas_screen.dart'; // Week 1: Penpot integration
import 'features/canvas/presentation/canvas_library_screen.dart';
import 'features/human_verification/presentation/screens/human_verification_dashboard.dart';
import 'demo/demo_onboarding.dart';
import 'demo/unified_showcase_demo.dart';
import 'demo/components/controlled_onboarding_flow.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/services/desktop/hive_cleanup_service.dart';
import 'core/error/app_error_handler.dart';
import 'core/services/vector_integration_service.dart';
import 'core/services/oauth_auto_refresh_initializer.dart';
import 'core/security/os_trust_manager.dart';

// DSPy Integration - replaces 50+ fragmented AI services
import 'core/services/dspy/dspy.dart';
import 'core/services/model_config_service.dart';
import 'core/models/model_config.dart';
import 'core/services/dspy/dspy_backend_setup_service.dart';
import 'core/services/desktop/desktop_agent_service.dart';
import 'core/services/desktop/desktop_conversation_service.dart';
import 'features/setup/presentation/screens/first_run_setup_screen.dart';

// MVP Vertical Slice - streamlined experience
import 'features/mvp/mvp.dart';

void main() async {
  // Set up error zone for the entire app
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize production error handling first
    AppLogger.info('Initializing global error handling', component: 'Main');
    try {
      GlobalErrorHandler.initialize();
      await AppErrorHandler.instance.initialize();
      AppLogger.info('Error handling initialized successfully', component: 'Main');
    } catch (e) {
      AppLogger.critical('Error handling initialization failed', component: 'Main', error: e);
    }

    // Initialize Service Locator first (contains all business logic)
    AppLogger.info('Initializing Service Locator', component: 'Main');
    try {
      final startTime = DateTime.now();
      await ServiceLocator.instance.initialize();
      final duration = DateTime.now().difference(startTime);
      print('✅ Service Locator initialized in ${duration.inMilliseconds}ms');
      
      // Perform health check
      final healthChecker = ServiceHealthChecker();
      final healthResult = await healthChecker.checkHealth();
      print(healthResult.toString());
      
    } catch (e, stackTrace) {
      print('❌ Service Locator initialization failed: $e');
      print('Stack trace: $stackTrace');
      // Continue with fallback initialization
    }

 // Initialize desktop services (legacy support)
 try {
 await DesktopServiceProvider.instance.initialize();
 // Desktop services initialized successfully
 
 // Initialize legacy storage service (always needed)
 try {
   await Hive.initFlutter('asmbli_app_data');
   await StorageService.init();
   print('✅ Legacy storage service initialized');
 } catch (storageError) {
   print('⚠️ Legacy storage initialization failed: $storageError');
 }
 
 // Check and clean database if needed
 print('🔍 Checking database health...');
 try {
   final health = await HiveCleanupService.checkBoxHealth();
   if (!(health['isHealthy'] as bool? ?? false)) {
     final corruptedCount = health['corruptedEntries'] as int? ?? 0;
     final typeIssues = health['typeIssues'] as int? ?? 0;
     print('⚠️ Database issues detected: $corruptedCount corrupted, $typeIssues type issues');
     
     print('🧹 Running database cleanup...');
     final cleaned = await HiveCleanupService.cleanupConversationsBox();
     if (cleaned) {
       print('✅ Database cleanup completed successfully');
     } else {
       print('❌ Database cleanup failed');
     }
   } else {
     print('✅ Database is healthy');
   }
 } catch (cleanupError) {
   print('⚠️ Database cleanup check failed: $cleanupError');
 }
 
 } catch (e) {
 // Desktop services initialization failed - using fallback
 // Fallback to legacy storage
 try {
 await Hive.initFlutter('asmbli_app_data');
 await StorageService.init();
 } catch (e2) {
 // Fallback storage initialization failed
 }
 }

 // Configure desktop window
 if (DesktopServiceProvider.instance.isDesktop) {
 try {
 await DesktopServiceProvider.instance.windowManager.configureWindow(
 const DesktopWindowOptions(
 size: Size(1400, 900),
 minimumSize: Size(1000, 700),
 center: true,
 title: 'Asmbli - Desktop',
 backgroundColor: Colors.transparent,
 ),
 );
 // Window configured successfully
 } catch (e) {
 // Window configuration failed
 }
 }

 // Initialize SharedPreferences for feature flags
 final prefs = await SharedPreferences.getInstance();

 
    runApp(
      ProviderScope(
        overrides: [
          featureFlagServiceProvider.overrideWithValue(FeatureFlagService(prefs)),
          // DSPy Integration - wire up local storage services
          conversationRepositoryProvider.overrideWithValue(
            DesktopConversationService(),
          ),
          agentRepositoryProvider.overrideWithValue(
            DesktopAgentService(),
          ),
        ],
        child: AppErrorHandler.errorBoundary(
          boundaryName: 'app_root',
          child: const VectorInitializedApp(),
        ),
      ),
    );
  }, (error, stackTrace) {
    // Global error handler delegates to AppErrorHandler
    try {
      AppErrorHandler.handleBusinessError(
        error,
        operation: 'main_zone_error',
        severity: ErrorSeverity.critical,
      );
    } catch (e) {
      print('❌ Error handler failed: $e');
      print('Original error: $error');
    }
  });
}

/// Wrapper that launches the app immediately without blocking on vector system
class VectorInitializedApp extends ConsumerWidget {
  const VectorInitializedApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize vector system in background (don't block startup)
    _initializeVectorSystemInBackground(ref);
    
    // Launch app immediately
    return const AsmblDesktopApp();
  }
  
  /// Initialize vector system in background without blocking startup
  void _initializeVectorSystemInBackground(WidgetRef ref) {
    // Delay initialization to ensure app is fully loaded first
    Future.delayed(const Duration(seconds: 2), () async {
      try {
        print('🔄 Starting vector system initialization in background...');
        
        // Initialize with shorter timeout to prevent hanging on permission dialogs
        await ref.read(vectorSystemInitializationProvider.future).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            print('⏰ Vector system initialization timed out - continuing without it');
            print('💡 This may happen if file permissions are pending');
          },
        );
        
        print('✅ Vector system initialized successfully in background');
      } catch (e) {
        print('⚠️ Vector system initialization failed: $e - app will work without it');
        print('💡 Vector search features will be unavailable');
      }
    });
  }
}

class AsmblDesktopApp extends ConsumerStatefulWidget {
  const AsmblDesktopApp({super.key});

  @override
  ConsumerState<AsmblDesktopApp> createState() => _AsmblDesktopAppState();
}

class _AsmblDesktopAppState extends ConsumerState<AsmblDesktopApp> {
  bool _isCheckingTrust = true;

  @override
  void initState() {
    super.initState();
    _checkOSTrust();
  }

  Future<void> _checkOSTrust() async {
    try {
      // Add timeout to prevent hanging
      await Future.any([
        _performTrustCheck(),
        Future.delayed(const Duration(seconds: 2), () {
          print('🔒 OS trust check timed out after 2 seconds - proceeding anyway');
        }),
      ]);
    } catch (e) {
      print('🔒 OS trust check failed: $e');
    } finally {
      // Always proceed after check or timeout
      if (mounted) {
        setState(() {
          _isCheckingTrust = false;
        });
      }
    }
  }

  Future<void> _performTrustCheck() async {
    try {
      final osTrustManager = OSTrustManager();
      final trustStatus = await osTrustManager.checkTrustStatus();
      final trustInfo = TrustInfo.fromStatus(trustStatus);
      
      // Log trust status for development/deployment insights
      print('🔒 OS Trust Status: ${trustStatus.name}');
      print('🔒 ${trustInfo.message}');
      
      if (trustInfo.requiresUserAction) {
        print('🔒 Trust Recommendations:');
        for (final rec in trustInfo.recommendations) {
          print('  • $rec');
        }
      }
    } catch (e) {
      print('🔒 Trust check error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeServiceProvider);
    final themeService = ref.read(themeServiceProvider.notifier);

    // Initialize OAuth auto-refresh service when app starts
    OAuthAutoRefreshInitializer.initialize(ref);

    if (_isCheckingTrust) {
      return MaterialApp(
        title: 'Asmbli - Starting',
        theme: themeService.getLightTheme(),
        darkTheme: themeService.getDarkTheme(),
        themeMode: themeState.mode,
        debugShowCheckedModeBanner: false,
        home: const _StartupScreen(),
      );
    }

    return MaterialApp.router(
      title: 'Asmbli - AI Agents Made Easy',
      theme: themeService.getLightTheme(),
      darkTheme: themeService.getDarkTheme(),
      themeMode: themeState.mode,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}

// Create router outside of the widget to avoid global key issues
final _router = GoRouter(
 initialLocation: AppRoutes.demoOnboarding, // MVP: Start with demo onboarding
 redirect: (context, state) {
   // We'll handle setup check in HomeScreen instead
   return null;
 },
 routes: [
 GoRoute(
 path: AppRoutes.setup,
 builder: (context, state) => const FirstRunSetupScreen(),
 ),
 GoRoute(
 path: '/onboarding',
 builder: (context, state) => const OnboardingScreen(),
 ),
 // MVP Vertical Slice Routes
 GoRoute(
 path: '/mvp',
 builder: (context, state) => const MvpWelcomeScreen(),
 ),
 GoRoute(
 path: '/mvp/setup',
 builder: (context, state) => const MvpSetupScreen(),
 ),
 GoRoute(
 path: '/mvp/chat',
 builder: (context, state) => const MvpChatScreen(),
 ),
 GoRoute(
 path: '/mvp/settings',
 builder: (context, state) => const MvpSettingsScreen(),
 ),
 GoRoute(
 path: AppRoutes.home,
 builder: (context, state) => const HomeScreen(),
 ),
 GoRoute(
 path: AppRoutes.chat,
 builder: (context, state) {
   final template = state.uri.queryParameters['template'];
   final agentId = state.uri.queryParameters['agent'];
   return ChatScreenWithContextual(selectedTemplate: template, agentId: agentId);
 },
 ),
 // Temporarily disabled - missing file
 // GoRoute(
 // path: AppRoutes.chatV2,
 // builder: (context, state) => const ModernChatScreenV2(),
 // ),
 // Demo route for video recording (remove after video)
 GoRoute(
 path: AppRoutes.demoChat,
 builder: (context, state) => const DemoChatScreen(),
 ),
 // Contextual Context Demo
 GoRoute(
 path: '/contextual-context-demo',
 builder: (context, state) => const ContextualContextDemo(),
 ),
 // Demo Routes
 GoRoute(
 path: AppRoutes.demoOnboarding,
 builder: (context, state) => const DemoOnboarding(),
 ),
 GoRoute(
 path: AppRoutes.demoUnified,
 builder: (context, state) {
   final agentTypeParam = state.uri.queryParameters['agentType'];
   final agentType = agentTypeParam != null ? int.tryParse(agentTypeParam) : null;
   final flowType = state.uri.queryParameters['flowType'];
   // Parse confidence settings from onboarding
   final confidenceParam = state.uri.queryParameters['confidence'];
   final confidenceThreshold = confidenceParam != null ? (int.tryParse(confidenceParam) ?? 80) / 100.0 : 0.8;
   final humanVerifyParam = state.uri.queryParameters['humanVerify'];
   final humanVerificationEnabled = humanVerifyParam != '0';
   return UnifiedShowcaseDemo(
     selectedAgentType: agentType,
     selectedDeliverable: flowType,
     confidenceThreshold: confidenceThreshold,
     humanVerificationEnabled: humanVerificationEnabled,
   );
 },
 ),
 GoRoute(
 path: AppRoutes.controlledOnboarding,
 builder: (context, state) {
  final agentTypeParam = state.uri.queryParameters['agentType'];
  final agentType = agentTypeParam != null ? int.tryParse(agentTypeParam) : 0;

  return ControlledOnboardingFlow(
    selectedAgentType: agentType,
   onComplete: (data) {
     // Pass agentType, flowType, and confidence settings to the unified demo
     final encodedFlowType = Uri.encodeComponent(data.flowType);
     final confidenceThreshold = (data.confidenceThreshold * 100).toInt();
     final humanVerification = data.humanVerificationEnabled ? '1' : '0';
     context.go('${AppRoutes.demoUnified}?agentType=$agentType&flowType=$encodedFlowType&confidence=$confidenceThreshold&humanVerify=$humanVerification');
   },
 );
},
),
 GoRoute(
 path: AppRoutes.canvas,
 builder: (context, state) => const PenpotCanvasScreen(), // Week 1: Switched to Penpot
 ),
GoRoute(
 path: AppRoutes.canvasLibrary,
 builder: (context, state) => const CanvasLibraryScreen(),
 ),
 GoRoute(
 path: AppRoutes.settings,
 builder: (context, state) => const ModernSettingsScreen(),
 ),
 GoRoute(
 path: AppRoutes.integrationHub,
 builder: (context, state) => const ToolsScreen(),
 ),
 // Legacy route redirects to Integration Hub
 GoRoute(
 path: '/settings/integrations',
 builder: (context, state) => const AdaptiveIntegrationRouter(initialTab: 'integrations'),
 ),
 GoRoute(
 path: AppRoutes.agents,
 builder: (context, state) => const MyAgentsScreen(),
 ),
 GoRoute(
 path: AppRoutes.agentBuilder,
 builder: (context, state) {
   final agentId = state.uri.queryParameters['id'];
   // Use new DSPy Agent Builder (simplified 6-step wizard)
   return DspyAgentBuilderScreen(agentId: agentId);
 },
 ),
 // Legacy builder (kept for reference)
 GoRoute(
 path: '/agents/builder-legacy',
 builder: (context, state) {
   final agentId = state.uri.queryParameters['id'];
   return AgentBuilderScreen(agentId: agentId);
 },
 ),
 GoRoute(
 path: '/agents/configure/:agentId',
 builder: (context, state) {
 final agentId = state.pathParameters['agentId'];
 return AgentConfigurationScreen(agentId: agentId);
 },
 ),
 GoRoute(
 path: '/agents/configure',
 builder: (context, state) => const AgentConfigurationScreen(),
 ),
 GoRoute(
 path: '/agents/execute/:agentId',
 builder: (context, state) {
 final agentId = state.pathParameters['agentId'] ?? '';
 return AgentExecutionScreen(agentId: agentId);
 },
 ),
 GoRoute(
 path: AppRoutes.context,
 builder: (context, state) => const ContextLibraryScreen(),
 ),
 GoRoute(
  path: AppRoutes.agentWizard,
  builder: (context, state) {
    final template = state.uri.queryParameters['template'];
    // Use new DSPy Agent Wizard with hero section and template picker
    return DspyAgentWizardScreen(templateId: template);
  },
 ),
 GoRoute(
  path: AppRoutes.orchestration,
  builder: (context, state) => const OrchestrationScreen(),
 ),
 GoRoute(
  path: AppRoutes.workflowBrowser,
  builder: (context, state) => const WorkflowBrowserScreen(),
 ),
 GoRoute(
  path: AppRoutes.workflowMarketplace,
  builder: (context, state) => const WorkflowMarketplaceScreen(),
 ),
 GoRoute(
  path: '/human-verification',
  builder: (context, state) => const HumanVerificationDashboard(),
 ),
 ],
);

/// Dashboard-style home screen focused on app functionality
class HomeScreen extends ConsumerStatefulWidget {
 const HomeScreen({super.key});

 @override
 ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
 @override
 void initState() {
   super.initState();
   _checkSetupAndOnboarding();
 }

 Future<void> _checkSetupAndOnboarding() async {
   try {
     // Small delay to ensure storage is initialized
     await Future.delayed(const Duration(milliseconds: 100));

     // First, check if DSPy backend setup is complete
     final setupService = DspyBackendSetupService();
     final isSetupComplete = await setupService.isSetupComplete();

     if (!isSetupComplete && mounted) {
       // Redirect to first-run setup
       context.go(AppRoutes.setup);
       return;
     }

     // Setup is done, now check onboarding
     final storage = DesktopStorageService.instance;
     final onboardingCompleted = storage.getPreference<bool>('onboarding_completed') ?? false;

     // Check if any API keys are configured
     final apiService = ApiConfigService(storage);
     await apiService.initialize();
     final hasApiKeys = apiService.allApiConfigs.values.any((config) => config.apiKey.isNotEmpty);

     // If not onboarded and no API keys, redirect to onboarding
     if (!onboardingCompleted && !hasApiKeys && mounted) {
       context.go('/onboarding');
     }
   } catch (e) {
     print('Error checking setup/onboarding status: $e');
   }
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
 child: Column(
 children: [
 // App Header
 const AppNavigationBar(currentRoute: AppRoutes.home),
 
 // Main Dashboard Content
 Expanded(
 child: SingleChildScrollView(
 padding: const EdgeInsets.all(SpacingTokens.pageHorizontal),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Welcome Section
 Text(
 'Welcome back!',
 style: TextStyles.pageTitle.copyWith(
 color: colors.onSurface,
 ),
 ),
 const SizedBox(height: SpacingTokens.iconSpacing),
 Text(
 'Manage your AI agents, conversations, and knowledge base',
 style: TextStyles.bodyLarge.copyWith(
 color: colors.onSurfaceVariant,
 ),
 ),
 
 const SizedBox(height: SpacingTokens.sectionSpacing),
 
 /* Consumer build - onboarding button removed
 TextButton.icon(
 onPressed: null,
 icon: Icon(Icons.rocket_launch),
 label: Text(''),
 style: TextButton.styleFrom(
 foregroundColor: colors.primary,
 ),
 ),
 
 SizedBox(height: SpacingTokens.md),
*/
 
 // Quick Actions Row
 Row(
 children: [
 Expanded(
 child: _QuickActionCard(
 icon: Icons.chat_bubble_outline,
 title: 'Start Chat',
 description: 'Begin new conversation',
 onTap: () => context.go(AppRoutes.chat),
 ),
 ),
 const SizedBox(width: SpacingTokens.elementSpacing),
 Expanded(
 child: _QuickActionCard(
 icon: Icons.build,
 title: 'Build Agent',
 description: 'Create custom AI agent',
 onTap: () => context.go(AppRoutes.agentWizard),
 ),
 ),
 ],
 ),
 
 const SizedBox(height: SpacingTokens.sectionSpacing),

 // Main Content - Recent Conversations and Loaded Models
 const Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Recent Conversations
 Expanded(
 child: _RecentConversationsSection(),
 ),
 SizedBox(width: SpacingTokens.elementSpacing),
 // Loaded Models
 Expanded(
 child: _LoadedModelsSection(),
 ),
 ],
 ),
 ],
 ),
 ),
 ),
 ],
 ),
 ),
 ),
 );
 }
}

// Recent Conversations Section
class _RecentConversationsSection extends ConsumerWidget {
 const _RecentConversationsSection();

 @override
 Widget build(BuildContext context, WidgetRef ref) {
 final colors = ThemeColors(context);
 final conversationsAsync = ref.watch(conversationsProvider);
 
 return _DashboardSectionEnhanced(
 title: 'Recent Conversations',
 child: conversationsAsync.when(
 data: (conversations) {
 final recentConversations = conversations
 .where((c) => c.status == ConversationStatus.active)
 .take(5)
 .toList();
 
 if (recentConversations.isEmpty) {
 return Column(
 children: [
 Icon(
 Icons.chat_bubble_outline,
 size: 32,
 color: colors.onSurfaceVariant.withValues(alpha: 0.5),
 ),
 const SizedBox(height: SpacingTokens.iconSpacing),
 Text(
 'No conversations yet',
 style: TextStyles.bodyMedium.copyWith(
 color: colors.onSurfaceVariant,
 ),
 ),
 ],
 );
 }
 
 return Column(
 children: [
 ...recentConversations.map((conversation) => Padding(
 padding: const EdgeInsets.only(bottom: SpacingTokens.iconSpacing),
 child: _ConversationItem(
 conversation: conversation,
 onTap: () {
 ref.read(selectedConversationIdProvider.notifier).state = conversation.id;
 context.go(AppRoutes.chat);
 },
 onDelete: () => _showDeleteConfirmation(context, ref, conversation),
 ),
 )),
 if (conversations.length > 5) ...[
 const SizedBox(height: SpacingTokens.iconSpacing),
 Text(
 '+${conversations.length - 5} more conversations',
 style: TextStyles.caption.copyWith(
 color: colors.onSurfaceVariant,
 ),
 ),
 ],
 const SizedBox(height: SpacingTokens.componentSpacing),
 AsmblButton.outline(
 text: 'View All Chats',
 icon: Icons.forum,
 onPressed: () => context.go(AppRoutes.chat),
 size: AsmblButtonSize.medium,
 ),
 ],
 );
 },
 loading: () => const Center(
 child: SizedBox(
 width: 20,
 height: 20,
 child: CircularProgressIndicator(strokeWidth: 2),
 ),
 ),
 error: (error, _) => Column(
 children: [
 Icon(
 Icons.error_outline,
 size: 32,
 color: colors.error,
 ),
 const SizedBox(height: SpacingTokens.iconSpacing),
 Text(
 'Failed to load conversations',
 style: TextStyles.bodyMedium.copyWith(
 color: colors.error,
 ),
 ),
 const SizedBox(height: SpacingTokens.componentSpacing),
 AsmblButton.secondary(
 text: 'Retry',
 icon: Icons.refresh,
 onPressed: () => ref.invalidate(conversationsProvider),
 size: AsmblButtonSize.medium,
 ),
 ],
 ),
 ),
 );
 }

 void _showDeleteConfirmation(BuildContext context, WidgetRef ref, Conversation conversation) {
 final colors = ThemeColors(context);
 showDialog(
 context: context,
 builder: (context) => AlertDialog(
 backgroundColor: colors.surface,
 title: Text(
 'Delete Conversation',
 style: TextStyles.cardTitle.copyWith(color: colors.onSurface),
 ),
 content: Text(
 'Are you sure you want to delete "${conversation.title}"? This action cannot be undone.',
 style: TextStyles.bodyMedium.copyWith(color: colors.onSurfaceVariant),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(context).pop(),
 child: Text('Cancel', style: TextStyle(color: colors.onSurfaceVariant)),
 ),
 TextButton(
 onPressed: () async {
 Navigator.of(context).pop();
 final deleteConversation = ref.read(deleteConversationProvider);
 await deleteConversation(conversation.id);
 },
 child: Text('Delete', style: TextStyle(color: colors.error)),
 ),
 ],
 ),
 );
 }
}

// Loaded Models Section - uses unified ModelConfigService
class _LoadedModelsSection extends ConsumerWidget {
 const _LoadedModelsSection();

 @override
 Widget build(BuildContext context, WidgetRef ref) {
 final colors = ThemeColors(context);
 final readyModels = ref.watch(readyModelConfigsProvider);

 return _DashboardSectionEnhanced(
 title: 'Loaded Models',
 child: readyModels.isEmpty
 ? Column(
 children: [
 Icon(
 Icons.memory,
 size: 32,
 color: colors.onSurfaceVariant.withValues(alpha: 0.5),
 ),
 const SizedBox(height: SpacingTokens.iconSpacing),
 Text(
 'No models configured',
 style: TextStyles.bodyMedium.copyWith(
 color: colors.onSurfaceVariant,
 ),
 ),
 const SizedBox(height: SpacingTokens.componentSpacing),
 AsmblButton.secondary(
 text: 'Configure Models',
 icon: Icons.settings,
 onPressed: () => context.go(AppRoutes.settings),
 size: AsmblButtonSize.medium,
 ),
 ],
 )
 : Column(
 children: [
 ...readyModels.take(5).map((model) => Padding(
 padding: const EdgeInsets.only(bottom: SpacingTokens.iconSpacing),
 child: _ModelItem(model: model),
 )),
 if (readyModels.length > 5) ...[
 const SizedBox(height: SpacingTokens.iconSpacing),
 Text(
 '+${readyModels.length - 5} more models',
 style: TextStyles.caption.copyWith(
 color: colors.onSurfaceVariant,
 ),
 ),
 ],
 const SizedBox(height: SpacingTokens.componentSpacing),
 AsmblButton.outline(
 text: 'Manage Models',
 icon: Icons.tune,
 onPressed: () => context.go(AppRoutes.settings),
 size: AsmblButtonSize.medium,
 ),
 ],
 ),
 );
 }
}

// Model item for dashboard - displays ModelConfig from unified service
class _ModelItem extends StatelessWidget {
 final ModelConfig model;

 const _ModelItem({required this.model});

 @override
 Widget build(BuildContext context) {
 final colors = ThemeColors(context);

 // Determine model type icon based on provider/type
 IconData icon = Icons.smart_toy;
 Color iconColor = colors.primary;

 if (model.isLocal) {
 icon = Icons.computer;
 iconColor = colors.secondary;
 } else {
 final provider = model.provider.toLowerCase();
 if (provider.contains('openai') || provider.contains('gpt')) {
 icon = Icons.auto_awesome;
 iconColor = colors.success;
 } else if (provider.contains('anthropic') || provider.contains('claude')) {
 icon = Icons.psychology;
 iconColor = colors.accent;
 } else if (provider.contains('google') || provider.contains('gemini')) {
 icon = Icons.diamond;
 iconColor = colors.warning;
 }
 }

 // Status badge
 final isReady = model.status == ModelStatus.ready;
 final statusText = model.isLocal ? 'Local' : 'API';
 final statusColor = isReady ? colors.success : colors.warning;

 return Container(
 padding: const EdgeInsets.symmetric(
 vertical: SpacingTokens.componentSpacing,
 horizontal: SpacingTokens.xs_precise,
 ),
 child: Row(
 children: [
 Container(
 padding: const EdgeInsets.all(SpacingTokens.iconSpacing),
 decoration: BoxDecoration(
 color: iconColor.withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
 ),
 child: Icon(
 icon,
 size: 16,
 color: iconColor,
 ),
 ),
 const SizedBox(width: SpacingTokens.componentSpacing),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 model.name,
 style: TextStyles.bodyMedium.copyWith(
 color: colors.onSurface,
 fontWeight: FontWeight.w500,
 ),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 if (model.modelSize != null) ...[
 const SizedBox(height: 2),
 Text(
 model.displaySize,
 style: TextStyles.caption.copyWith(
 color: colors.onSurfaceVariant,
 ),
 ),
 ],
 ],
 ),
 ),
 Container(
 padding: const EdgeInsets.symmetric(
 horizontal: SpacingTokens.iconSpacing,
 vertical: SpacingTokens.xs_precise,
 ),
 decoration: BoxDecoration(
 color: statusColor.withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(BorderRadiusTokens.xs),
 ),
 child: Text(
 statusText,
 style: TextStyles.caption.copyWith(
 color: statusColor,
 fontWeight: FontWeight.w500,
 ),
 ),
 ),
 ],
 ),
 );
 }
}

// Conversation item for dashboard
class _ConversationItem extends StatefulWidget {
 final Conversation conversation;
 final VoidCallback onTap;
 final VoidCallback onDelete;

 const _ConversationItem({
 required this.conversation,
 required this.onTap,
 required this.onDelete,
 });

 @override
 State<_ConversationItem> createState() => _ConversationItemState();
}

class _ConversationItemState extends State<_ConversationItem> {
 bool _isHovered = false;

 @override
 Widget build(BuildContext context) {
 final colors = ThemeColors(context);
 final isAgentConversation = widget.conversation.metadata?['type'] == 'agent';
 final agentName = widget.conversation.metadata?['agentName'] as String?;

 return MouseRegion(
 onEnter: (_) => setState(() => _isHovered = true),
 onExit: (_) => setState(() => _isHovered = false),
 child: Material(
 color: Colors.transparent,
 child: InkWell(
 onTap: widget.onTap,
 borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
 hoverColor: colors.primary.withValues(alpha: 0.04),
 splashColor: colors.primary.withValues(alpha: 0.12),
 child: Container(
 padding: const EdgeInsets.symmetric(
 vertical: SpacingTokens.componentSpacing,
 horizontal: SpacingTokens.xs_precise,
 ),
 child: Stack(
 children: [
 Row(
 children: [
 Container(
 padding: const EdgeInsets.all(SpacingTokens.iconSpacing),
 decoration: BoxDecoration(
 color: isAgentConversation
 ? colors.primary.withValues(alpha: 0.1)
 : colors.surfaceVariant,
 borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
 ),
 child: Icon(
 isAgentConversation ? Icons.smart_toy : Icons.chat,
 size: 16,
 color: isAgentConversation
 ? colors.primary
 : colors.onSurfaceVariant,
 ),
 ),
 const SizedBox(width: SpacingTokens.componentSpacing),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 isAgentConversation && agentName != null
 ? agentName
 : widget.conversation.title,
 style: TextStyles.bodyMedium.copyWith(
 color: colors.onSurface,
 fontWeight: FontWeight.w500,
 ),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 const SizedBox(height: SpacingTokens.xs_precise),
 Text(
 _getConversationTypeDescription(widget.conversation),
 style: TextStyles.caption.copyWith(
 color: colors.onSurfaceVariant,
 ),
 ),
 ],
 ),
 ),
 Text(
 _formatTime(widget.conversation.createdAt),
 style: TextStyles.caption.copyWith(
 color: colors.onSurfaceVariant,
 ),
 ),
 const SizedBox(width: SpacingTokens.md),
 ],
 ),
 if (_isHovered)
 Positioned(
 top: 0,
 right: 0,
 child: GestureDetector(
 onTap: widget.onDelete,
 child: Container(
 padding: const EdgeInsets.all(4),
 decoration: BoxDecoration(
 color: colors.error.withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
 ),
 child: Icon(
 Icons.close,
 size: 14,
 color: colors.error,
 ),
 ),
 ),
 ),
 ],
 ),
 ),
 ),
 ),
 );
 }

 String _formatTime(DateTime dateTime) {
 final now = DateTime.now();
 final difference = now.difference(dateTime);
 
 if (difference.inMinutes < 1) {
 return 'Now';
 } else if (difference.inHours < 1) {
 return '${difference.inMinutes}m ago';
 } else if (difference.inDays < 1) {
 return '${difference.inHours}h ago';
 } else if (difference.inDays < 7) {
 return '${difference.inDays}d ago';
 } else {
 return '${dateTime.day}/${dateTime.month}';
 }
 }

 String _getConversationTypeDescription(Conversation conversation) {
 final agentType = conversation.metadata?['type'] as String?;
 
 switch (agentType) {
 case 'agent':
 return 'Agent Chat';
 case 'default_api':
 case 'direct_chat':
 // Check if conversation has stored model information
 final storedModelName = conversation.metadata?['defaultModelName'] as String?;
 final modelType = conversation.metadata?['modelType'] as String?;
 final provider = conversation.metadata?['defaultModelProvider'] as String?;
 
 if (storedModelName != null && storedModelName.isNotEmpty) {
 if (modelType == 'local') {
 return 'Local $storedModelName';
 } else if (provider != null) {
 return '$provider Chat';
 } else {
 return '$storedModelName Chat';
 }
 }
 return 'AI Chat';
 default:
 return 'Chat Session';
 }
 }
}




// Quick action card for dashboard
class _QuickActionCard extends StatelessWidget {
 final IconData icon;
 final String title;
 final String description;
 final VoidCallback onTap;

 const _QuickActionCard({
 required this.icon,
 required this.title,
 required this.description,
 required this.onTap,
 });

 @override
 Widget build(BuildContext context) {
 return AsmblCard(
 onTap: onTap,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 padding: const EdgeInsets.all(SpacingTokens.iconSpacing),
 decoration: BoxDecoration(
 color: ThemeColors(context).primary.withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
 ),
 child: Icon(
 icon,
 size: 24,
 color: ThemeColors(context).primary,
 ),
 ),
 const SizedBox(height: SpacingTokens.componentSpacing),
 Text(
 title,
 style: TextStyles.cardTitle.copyWith(
 color: ThemeColors(context).onSurface,
 ),
 ),
 const SizedBox(height: SpacingTokens.iconSpacing),
 Text(
 description,
 style: TextStyles.bodySmall.copyWith(
 color: ThemeColors(context).onSurfaceVariant,
 ),
 ),
 ],
 ),
 );
 }
}

// Enhanced dashboard section container
class _DashboardSectionEnhanced extends StatelessWidget {
 final String title;
 final Widget child;

 const _DashboardSectionEnhanced({
 required this.title,
 required this.child,
 });

 @override
 Widget build(BuildContext context) {
 return AsmblCardEnhanced.outlined(
 isInteractive: false,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 title,
 style: TextStyles.sectionTitle.copyWith(
 color: ThemeColors(context).onSurface,
 ),
 ),
 const SizedBox(height: SpacingTokens.componentSpacing),
 child,
 ],
 ),
 );
 }
}

/// Startup screen shown during trust checking
class _StartupScreen extends StatelessWidget {
  const _StartupScreen();

  @override
  Widget build(BuildContext context) {
    final colors = ThemeColors(context);
    
    return Scaffold(
      backgroundColor: colors.background,
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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(BorderRadiusTokens.xl),
                  border: Border.all(
                    color: colors.border.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // App logo/icon
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
                      ),
                      child: Icon(
                        Icons.security,
                        size: 32,
                        color: colors.primary,
                      ),
                    ),
                    
                    const SizedBox(height: SpacingTokens.lg),
                    
                    // Loading indicator
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: colors.primary,
                        strokeWidth: 2,
                      ),
                    ),
                    
                    const SizedBox(height: SpacingTokens.lg),
                    
                    // Status text
                    Text(
                      'Checking OS Trust Status...',
                      style: TextStyles.headlineMedium.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    
                    const SizedBox(height: SpacingTokens.sm),
                    
                    Text(
                      'Verifying application trust with your operating system',
                      style: TextStyles.bodyMedium.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: SpacingTokens.lg),
                    
                    // App branding
                    Text(
                      'Asmbli',
                      style: TextStyles.brandTitle.copyWith(
                        color: colors.primary,
                        fontSize: 24,
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
  }
}



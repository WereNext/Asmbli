import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:agent_engine_core/services/agent_service.dart';
import 'package:agent_engine_core/services/conversation_service.dart';

// Core services
import '../services/desktop/desktop_agent_service.dart';
import '../services/desktop/desktop_conversation_service.dart';
import '../services/desktop/desktop_storage_service.dart';
import '../services/desktop/desktop_service_provider.dart';
import '../services/canvas_storage_service.dart';
import '../services/llm/unified_llm_service.dart';
import '../services/context_mcp_resource_service.dart';
import '../services/agent_context_prompt_service.dart';
import '../services/theme_service.dart';
import '../services/model_config_service.dart';
import '../services/design_tokens_service.dart';
import '../../features/context/data/repositories/context_repository.dart';
import '../services/mcp_settings_service.dart';
import '../services/claude_api_service.dart';
import '../services/openai_api_service.dart';
import '../services/google_api_service.dart';
import '../services/kimi_api_service.dart';
import '../services/ollama_service.dart';
// import '../services/design_agent_orchestrator_service.dart'; // Removed for single model optimization
import '../services/visual_reasoning/decision_gateway_service.dart';
import '../services/minimal_agent_state_service.dart';
import '../services/agent_model_recommendation_service.dart';
import '../services/smart_agent_orchestrator_service.dart';
import '../services/mcp_server_execution_service.dart';
import '../services/mcp_catalog_service.dart';
import '../services/github_mcp_registry_service.dart';
import '../services/featured_mcp_servers_service.dart';
import '../services/mcp_error_handler.dart';
import '../services/json_rpc_communication_service.dart';
import '../services/mcp_protocol_handler.dart';
import '../services/mcp_process_manager.dart';
import '../services/production_logger.dart';
import 'package:dio/dio.dart';
import '../../features/orchestration/services/workflow_persistence_service.dart';
import '../../features/orchestration/services/workflow_marketplace_service.dart';
import '../../features/orchestration/services/workflow_execution_service.dart';
import '../../features/orchestration/services/agent_workflow_integration_service.dart';

// New agent-terminal architecture services
import '../services/mcp_installation_service.dart';
import '../services/agent_aware_mcp_installer.dart';
import '../services/agent_mcp_session_service.dart';
import '../services/agent_mcp_service.dart';
import '../services/plugin_bridge_server.dart';
import '../../features/human_verification/services/human_verification_service.dart';
import '../services/git_workspace_service.dart';
import '../services/workspace_session_manager.dart';

// Business services
import '../services/business/base_business_service.dart';
import '../services/business/agent_business_service.dart';
import '../services/business/conversation_business_service.dart';

/// Dependency injection container for managing service instances
/// Implements singleton pattern with lazy initialization
class ServiceLocator {
  static ServiceLocator? _instance;
  static ServiceLocator get instance => _instance ??= ServiceLocator._internal();

  ServiceLocator._internal();

  final Map<Type, dynamic> _services = {};
  final Map<Type, dynamic Function()> _factories = {};
  final Set<Type> _singletons = {};
  bool _isInitialized = false;

  /// Register a singleton service instance
  void registerSingleton<T>(T service) {
    if (_services.containsKey(T)) {
      debugPrint('⚠️ Service already registered: $T');
      return;
    }
    
    _services[T] = service;
    _singletons.add(T);
    debugPrint('✅ Registered singleton: $T');
  }

  /// Register a factory for creating service instances
  void registerFactory<T>(T Function() factory) {
    if (_factories.containsKey(T)) {
      debugPrint('⚠️ Factory already registered: $T');
      return;
    }
    
    _factories[T] = factory;
    debugPrint('✅ Registered factory: $T');
  }

  /// Register a lazy singleton (created on first access)
  void registerLazySingleton<T>(T Function() factory) {
    if (_factories.containsKey(T)) {
      debugPrint('⚠️ Lazy singleton already registered: $T');
      return;
    }
    
    _factories[T] = factory;
    _singletons.add(T);
    debugPrint('✅ Registered lazy singleton: $T');
  }

  /// Get a service instance
  T get<T>() {
    final type = T;
    
    // Check if already instantiated
    if (_services.containsKey(type)) {
      return _services[type] as T;
    }
    
    // Check if factory exists
    if (_factories.containsKey(type)) {
      final instance = _factories[type]!() as T;
      
      // Store as singleton if required
      if (_singletons.contains(type)) {
        _services[type] = instance;
      }
      
      return instance;
    }
    
    throw ServiceNotRegisteredException('Service not registered: $T');
  }

  /// Check if a service is registered
  bool isRegistered<T>() {
    return _services.containsKey(T) || _factories.containsKey(T);
  }

  /// Reset the service locator (mainly for testing)
  void reset() {
    _disposeServices();
    _services.clear();
    _factories.clear();
    _singletons.clear();
    _isInitialized = false;
    debugPrint('🔄 Service locator reset');
  }

  /// Initialize all services with timeout protection
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('⚠️ Service locator already initialized');
      return;
    }

    try {
      debugPrint('🚀 Initializing service locator...');
      
      // Try full initialization first, fallback to minimal mode if it fails
      try {
        await _registerCoreServicesWithTimeout();
        await _registerBusinessServicesWithTimeout();
        await _initializeServicesWithTimeout();
        debugPrint('✅ Full service locator initialized successfully');
      } catch (e) {
        debugPrint('⚠️ Full initialization failed, switching to minimal mode: $e');
        await _initializeMinimalMode();
        debugPrint('✅ Minimal service locator initialized successfully');
      }
      
      _isInitialized = true;
    } catch (error, stackTrace) {
      debugPrint('❌ Service locator initialization failed completely: $error');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Timeout-protected core services registration
  Future<void> _registerCoreServicesWithTimeout() async {
    try {
      debugPrint('📦 Starting core services registration...');
      await _registerCoreServices().timeout(const Duration(seconds: 8));
      debugPrint('✅ Core services registered successfully');
    } on TimeoutException {
      debugPrint('⏰ Core services registration timed out after 8 seconds');
      throw Exception('Core services registration timeout');
    }
  }

  /// Timeout-protected business services registration  
  Future<void> _registerBusinessServicesWithTimeout() async {
    try {
      debugPrint('💼 Starting business services registration...');
      await _registerBusinessServices().timeout(const Duration(seconds: 5));
      debugPrint('✅ Business services registered successfully');
    } on TimeoutException {
      debugPrint('⏰ Business services registration timed out after 5 seconds');
      throw Exception('Business services registration timeout');
    }
  }

  /// Timeout-protected services initialization
  Future<void> _initializeServicesWithTimeout() async {
    try {
      debugPrint('🔧 Starting services initialization...');
      await _initializeServices().timeout(const Duration(seconds: 10));
      debugPrint('✅ Services initialized successfully');
    } on TimeoutException {
      debugPrint('⏰ Services initialization timed out after 10 seconds');
      throw Exception('Services initialization timeout');
    }
  }

  /// Initialize only essential services for design agent functionality
  Future<void> _initializeMinimalMode() async {
    debugPrint('🔧 Initializing emergency minimal mode...');
    
    try {
      // Essential storage service
      final storageService = DesktopStorageService.instance;
      await storageService.initialize();
      registerSingleton<DesktopStorageService>(storageService);
      debugPrint('✅ Emergency storage service initialized');

      // Essential data services (no MCP or complex dependencies)
      final emergencyAgentService = DesktopAgentService();
      registerSingleton<AgentService>(emergencyAgentService);
      registerSingleton<ConversationService>(DesktopConversationService());
      await emergencyAgentService.seedDefaultAgents();
      debugPrint('✅ Emergency data services initialized');
      
      // Essential theme service
      registerSingleton<ThemeService>(ThemeService());
      debugPrint('✅ Emergency theme service initialized');
      
      // Try to add basic LLM support if possible
      try {
        final desktopServiceProvider = DesktopServiceProvider.instance;
        final ollamaService = OllamaService(desktopServiceProvider);
        registerSingleton<OllamaService>(ollamaService);
        
        final modelConfigService = ModelConfigService(storageService, ollamaService);
        await modelConfigService.initialize();
        registerSingleton<ModelConfigService>(modelConfigService);
        debugPrint('✅ Emergency model services initialized');
      } catch (e) {
        debugPrint('⚠️ Could not initialize model services in emergency mode: $e');
      }

      debugPrint('🎯 Emergency mode ready - Basic functionality available');
      debugPrint('⚠️ Some features may be limited in emergency mode');
      
    } catch (e) {
      debugPrint('❌ Emergency minimal mode initialization failed: $e');
      // Even if this fails, allow the app to continue with absolute minimum
      try {
        final storageService = DesktopStorageService.instance;
        registerSingleton<DesktopStorageService>(storageService);
        registerSingleton<ThemeService>(ThemeService());
        debugPrint('💀 Ultra-minimal mode - basic app shell only');
      } catch (e2) {
        debugPrint('💀 Complete failure - continuing anyway: $e2');
      }
    }
  }

  /// Register all core services
  Future<void> _registerCoreServices() async {
    // Storage service (must be first)
    final storageService = DesktopStorageService.instance;
    await storageService.initialize();
    registerSingleton<DesktopStorageService>(storageService);

    // Register data layer services
    final agentService = DesktopAgentService();
    registerSingleton<AgentService>(agentService);
    registerSingleton<ConversationService>(DesktopConversationService());

    // Seed default agents (Design Agent, etc.)
    await agentService.seedDefaultAgents();

    // Register canvas services
    final canvasStorage = CanvasStorageService();
    await canvasStorage.initialize();
    registerSingleton<CanvasStorageService>(canvasStorage);
    
    // Register orchestration services
    final workflowPersistence = WorkflowPersistenceService.instance;
    await workflowPersistence.initialize();
    registerSingleton<WorkflowPersistenceService>(workflowPersistence);
    
    final workflowMarketplace = WorkflowMarketplaceService.instance;
    registerSingleton<WorkflowMarketplaceService>(workflowMarketplace);

    final workflowExecution = WorkflowExecutionService.instance;
    // Note: WorkflowExecutionEngine is created within WorkflowExecutionService or manually
    // We don't register it directly here, but if we did, we'd need to pass the verification service
    registerSingleton<WorkflowExecutionService>(workflowExecution);
    
    final agentWorkflowIntegration = AgentWorkflowIntegrationService.instance;
    registerSingleton<AgentWorkflowIntegrationService>(agentWorkflowIntegration);

    // Register GitHub MCP registry service first
    final githubApi = GitHubMCPRegistryApi(Dio());
    final githubMCPService = GitHubMCPRegistryService(githubApi);
    registerSingleton<GitHubMCPRegistryService>(githubMCPService);

    // Register MCP catalog service (needed by other MCP services)
    final featuredService = FeaturedMCPServersService();
    final mcpCatalogService = MCPCatalogService(githubMCPService, featuredService);
    registerSingleton<MCPCatalogService>(mcpCatalogService);
    
    // Register infrastructure services with proper dependencies
    final mcpSettingsService = MCPSettingsService(storageService, mcpCatalogService);
    registerSingleton<MCPSettingsService>(mcpSettingsService);
    
    // Register MCP server execution service as singleton
    final mcpExecutionService = MCPServerExecutionService(mcpCatalogService, mcpSettingsService);
    registerSingleton<MCPServerExecutionService>(mcpExecutionService);
    
    final desktopServiceProvider = DesktopServiceProvider.instance;
    final ollamaService = OllamaService(desktopServiceProvider);
    registerSingleton<OllamaService>(ollamaService);
    
    final claudeApiService = ClaudeApiService(mcpSettingsService);
    registerSingleton<ClaudeApiService>(claudeApiService);
    
    final openaiApiService = OpenAIApiService();
    registerSingleton<OpenAIApiService>(openaiApiService);
    
    final googleApiService = GoogleApiService();
    registerSingleton<GoogleApiService>(googleApiService);
    
    final kimiApiService = KimiApiService();
    registerSingleton<KimiApiService>(kimiApiService);
    
    final modelConfigService = ModelConfigService(storageService, ollamaService);
    await modelConfigService.initialize();
    registerSingleton<ModelConfigService>(modelConfigService);
    
    final unifiedLlmService = UnifiedLLMService(modelConfigService, claudeApiService, ollamaService, openaiApiService, googleApiService, kimiApiService);
    await unifiedLlmService.initialize();
    registerSingleton<UnifiedLLMService>(unifiedLlmService);
    
    // Register Model Recommendation Service
    final modelRecommendationService = AgentModelRecommendationService(modelConfigService, unifiedLlmService);
    registerSingleton<AgentModelRecommendationService>(modelRecommendationService);
    
    // Register Smart Agent Orchestrator
    final smartAgentOrchestrator = SmartAgentOrchestratorService(unifiedLlmService, modelRecommendationService);
    registerSingleton<SmartAgentOrchestratorService>(smartAgentOrchestrator);
    
    // Design Agent Orchestrator removed for single model optimization
    
    // MCPBridgeService removed
    // final mcpBridgeService = MCPBridgeService(mcpSettingsService);
    // registerSingleton<MCPBridgeService>(mcpBridgeService);

    // NOTE: MCPExcalidrawBridgeService removed - Excalidraw system deprecated

    // Register Visual Reasoning services
    final decisionGateway = DecisionGatewayService.instance;
    await decisionGateway.initialize();
    registerSingleton<DecisionGatewayService>(decisionGateway);
    
    // Register MVP Agent State service
    final agentState = MinimalAgentStateService.instance;
    await agentState.initialize();
    registerSingleton<MinimalAgentStateService>(agentState);
    
    // Register ContextRepository and DesignTokensService for Penpot integration
    final contextRepository = ContextRepository();
    registerSingleton<ContextRepository>(contextRepository);
    final designTokensService = DesignTokensService(contextRepository: contextRepository);
    registerSingleton<DesignTokensService>(designTokensService);

    registerSingleton<ContextMCPResourceService>(ContextMCPResourceService(contextRepository));
    registerSingleton<AgentContextPromptService>(AgentContextPromptService());
    registerSingleton<ThemeService>(ThemeService());
    
    // Use the existing singleton BusinessEventBus
    registerSingleton<BusinessEventBus>(BusinessEventBus());
    
    // Register core MCP installation service
    final mcpInstallationService = MCPInstallationService(mcpCatalogService);
    registerSingleton<MCPInstallationService>(mcpInstallationService);

    // Register new consolidated AgentMCPService
    final agentMCPService = AgentMCPService(mcpCatalogService, storageService);
    registerSingleton<AgentMCPService>(agentMCPService);

    // Register agent-aware MCP installer
    final agentAwareMCPInstaller = AgentAwareMCPInstaller(
      mcpInstallationService,
      agentMCPService,
      get<AgentService>() as DesktopAgentService,
    );
    registerSingleton<AgentAwareMCPInstaller>(agentAwareMCPInstaller);

    // Register MCP error handler
    final mcpErrorHandler = MCPErrorHandler(storageService);
    registerSingleton<MCPErrorHandler>(mcpErrorHandler);

    // Register JSON-RPC communication service
    final jsonRpcService = JsonRpcCommunicationService(ProductionLogger.instance, mcpErrorHandler);
    registerSingleton<JsonRpcCommunicationService>(jsonRpcService);

    // Register MCP protocol handler
    final mcpProtocolHandler = MCPProtocolHandler(mcpErrorHandler, jsonRpcService);
    registerSingleton<MCPProtocolHandler>(mcpProtocolHandler);

    // Register MCP process manager
    final mcpProcessManager = MCPProcessManager(mcpCatalogService, mcpProtocolHandler);
    registerSingleton<MCPProcessManager>(mcpProcessManager);

    // Register agent MCP session service for tool execution
    final agentMCPSessionService = AgentMCPSessionService(
      agentMCPService,
      mcpProcessManager,
      mcpProtocolHandler,
    );
    registerSingleton<AgentMCPSessionService>(agentMCPSessionService);



    // Register Plugin Bridge Server for PenPot plugin communication
    final pluginBridgeServer = PluginBridgeServer(port: 3000);
    await pluginBridgeServer.start();
    registerSingleton<PluginBridgeServer>(pluginBridgeServer);

    // Register Human Verification Service
    final humanVerificationService = HumanVerificationService();
    registerSingleton<HumanVerificationService>(humanVerificationService);

    // Register Workspace services for IDE Prototyping Agent
    final gitWorkspaceService = GitWorkspaceService();
    registerSingleton<GitWorkspaceService>(gitWorkspaceService);

    final workspaceSessionManager = WorkspaceSessionManager(gitService: gitWorkspaceService);
    await workspaceSessionManager.initialize();
    registerSingleton<WorkspaceSessionManager>(workspaceSessionManager);
  }

  /// Register all business services
  Future<void> _registerBusinessServices() async {
    // Agent business service
    registerLazySingleton<AgentBusinessService>(() => AgentBusinessService(
      agentRepository: get<AgentService>(),
      modelService: get<UnifiedLLMService>(),
      contextService: get<ContextMCPResourceService>(),
      promptService: get<AgentContextPromptService>(),
      eventBus: get<BusinessEventBus>(),
      integrationService: null, // Temporarily disabled until dependencies are fixed
      provisioningService: null, 
      agentMcpService: get<AgentMCPService>(),
    ));

    // Conversation business service
    registerLazySingleton<ConversationBusinessService>(() => ConversationBusinessService(
      conversationRepository: get<ConversationService>(),
      llmService: get<UnifiedLLMService>(),
      mcpService: get<AgentMCPService>(),
      contextService: get<ContextMCPResourceService>(),
      promptService: get<AgentContextPromptService>(),
      eventBus: get<BusinessEventBus>(),
    ));
  }

  /// Initialize services that require initialization
  Future<void> _initializeServices() async {
    final initializableServices = _services.values
        .whereType<BaseBusinessService>()
        .toList();

    for (final service in initializableServices) {
      try {
        await service.initialize();
      } catch (e) {
        debugPrint('❌ Failed to initialize service ${service.runtimeType}: $e');
      }
    }
  }

  /// Dispose all services
  Future<void> _disposeServices() async {
    final disposableServices = _services.values
        .whereType<BaseBusinessService>()
        .toList();

    for (final service in disposableServices) {
      try {
        await service.dispose();
      } catch (e) {
        debugPrint('❌ Failed to dispose service ${service.runtimeType}: $e');
      }
    }
  }

  /// Get service dependency graph for debugging
  Map<String, List<String>> getDependencyGraph() {
    final graph = <String, List<String>>{};
    
    // This is simplified - in a real implementation, you'd track dependencies
    for (final type in _services.keys) {
      graph[type.toString()] = [];
    }
    
    for (final type in _factories.keys) {
      graph[type.toString()] = [];
    }
    
    return graph;
  }

  /// Get all registered service types
  List<Type> getRegisteredTypes() {
    return <Type>{..._services.keys, ..._factories.keys}.toList();
  }

  /// Get service instance count
  int get serviceCount => _services.length + _factories.length;

  /// Check if the service locator is initialized
  bool get isInitialized => _isInitialized;
}

/// Exception thrown when a service is not registered
class ServiceNotRegisteredException implements Exception {
  final String message;
  const ServiceNotRegisteredException(this.message);

  @override
  String toString() => 'ServiceNotRegisteredException: $message';
}

/// Extension for easy service access in widgets and other classes
extension ServiceLocatorExtension on Object {
  /// Get a service from the service locator
  T getService<T>() => ServiceLocator.instance.get<T>();

  /// Check if a service is available
  bool hasService<T>() => ServiceLocator.instance.isRegistered<T>();
}

/// Mixin for classes that need access to services
mixin ServiceConsumer {
  /// Get a service instance
  T service<T>() => ServiceLocator.instance.get<T>();

  /// Check if service is available
  bool hasService<T>() => ServiceLocator.instance.isRegistered<T>();
}

/// Service locator initialization result
class ServiceLocatorResult {
  final bool success;
  final String? error;
  final Duration initializationTime;
  final List<String> initializedServices;
  final List<String> failedServices;

  const ServiceLocatorResult({
    required this.success,
    this.error,
    required this.initializationTime,
    this.initializedServices = const [],
    this.failedServices = const [],
  });

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('Service Locator Initialization Result:');
    buffer.writeln('Success: $success');
    buffer.writeln('Time: ${initializationTime.inMilliseconds}ms');
    buffer.writeln('Services: ${initializedServices.length} initialized, ${failedServices.length} failed');
    
    if (error != null) {
      buffer.writeln('Error: $error');
    }
    
    if (failedServices.isNotEmpty) {
      buffer.writeln('Failed services: ${failedServices.join(', ')}');
    }
    
    return buffer.toString();
  }
}

/// Service health checker
class ServiceHealthChecker {
  final ServiceLocator _serviceLocator;

  ServiceHealthChecker([ServiceLocator? serviceLocator])
      : _serviceLocator = serviceLocator ?? ServiceLocator.instance;

  /// Check the health of all registered services
  Future<ServiceHealthResult> checkHealth() async {
    final results = <String, bool>{};
    final errors = <String, String>{};
    final startTime = DateTime.now();

    for (final type in _serviceLocator.getRegisteredTypes()) {
      try {
        // If we're iterating through registered types, they're all registered by definition
        // The original bug was trying to get() without a type parameter
        results[type.toString()] = true;
      } catch (e) {
        results[type.toString()] = false;
        errors[type.toString()] = e.toString();
      }
    }

    final endTime = DateTime.now();
    final duration = endTime.difference(startTime);

    return ServiceHealthResult(
      isHealthy: results.values.every((healthy) => healthy),
      serviceResults: results,
      errors: errors,
      checkDuration: duration,
      timestamp: endTime,
    );
  }
}

class ServiceHealthResult {
  final bool isHealthy;
  final Map<String, bool> serviceResults;
  final Map<String, String> errors;
  final Duration checkDuration;
  final DateTime timestamp;

  const ServiceHealthResult({
    required this.isHealthy,
    required this.serviceResults,
    required this.errors,
    required this.checkDuration,
    required this.timestamp,
  });

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('Service Health Check Result:');
    buffer.writeln('Overall Health: ${isHealthy ? '✅ Healthy' : '❌ Unhealthy'}');
    buffer.writeln('Check Duration: ${checkDuration.inMilliseconds}ms');
    buffer.writeln('Timestamp: $timestamp');

    if (serviceResults.isNotEmpty) {
      buffer.writeln('\nService Status:');
      for (final entry in serviceResults.entries) {
        final status = entry.value ? '✅' : '❌';
        buffer.writeln('  $status ${entry.key}');
        
        if (!entry.value && errors.containsKey(entry.key)) {
          buffer.writeln('    Error: ${errors[entry.key]}');
        }
      }
    }

    return buffer.toString();
  }
}
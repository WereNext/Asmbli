import 'dart:async';
import 'package:agent_engine_core/models/agent.dart';
import 'package:agent_engine_core/services/agent_service.dart';
import 'package:uuid/uuid.dart';
import 'base_business_service.dart';
import '../../../features/context/data/models/context_document.dart' as context;
import '../llm/unified_llm_service.dart';
import '../context_mcp_resource_service.dart';
import '../agent_context_prompt_service.dart';
import '../agent_mcp_integration_service.dart';
import '../agent_terminal_provisioning_service.dart';
import '../agent_mcp_service.dart';
import '../production_logger.dart';
import '../../models/mcp_tool_info.dart';
import '../../models/mcp_tool_result.dart';

/// Business service for agent management
/// Encapsulates all business logic related to agents
class AgentBusinessService extends BaseBusinessService {
  final AgentService _agentRepository;
  final UnifiedLLMService _modelService;
  final ContextMCPResourceService _contextService;
  final AgentContextPromptService _promptService;
  final BusinessEventBus _eventBus;
  final AgentMCPIntegrationService? _integrationService;
  final AgentTerminalProvisioningService? _provisioningService;
  final AgentMCPService? _agentMcpService;

  AgentBusinessService({
    required AgentService agentRepository,
    required UnifiedLLMService modelService,
    required ContextMCPResourceService contextService,
    required AgentContextPromptService promptService,
    BusinessEventBus? eventBus,
    AgentMCPIntegrationService? integrationService,
    AgentTerminalProvisioningService? provisioningService,
    AgentMCPService? agentMcpService,
  })  : _agentRepository = agentRepository,
        _modelService = modelService,
        _contextService = contextService,
        _promptService = promptService,
        _eventBus = eventBus ?? BusinessEventBus(),
        _integrationService = integrationService,
        _provisioningService = provisioningService,
        _agentMcpService = agentMcpService;

  /// Log error (compatibility method)
  void logError(String message, dynamic error) {
    print('AgentBusinessService Error: $message - $error');
  }

  /// Creates a new agent with full validation and configuration
  Future<BusinessResult<Agent>> createAgent({
    required String name,
    required String description,
    required List<String> capabilities,
    required String modelId,
    List<String> mcpServers = const [],
    List<String> contextDocs = const [],
    Map<String, dynamic> configuration = const {},
  }) async {
    return handleBusinessOperation('createAgent', () async {
      // Validate input parameters
      validateRequired({
        'name': name,
        'description': description,
        'capabilities': capabilities,
        'modelId': modelId,
      });

      // Additional business validation
      final validationResult = await _validateAgentCreation(
        name: name,
        modelId: modelId,
        mcpServers: mcpServers,
      );

      if (!validationResult.isValid) {
        return BusinessResult.failure(validationResult.error!);
      }

      // Create the agent entity
      final agent = Agent(
        id: const Uuid().v4(),
        name: name.trim(),
        description: description.trim(),
        capabilities: capabilities,
        status: AgentStatus.idle,
        configuration: {
          'modelId': modelId,
          'version': '1.0',
          'creator': 'agent_business_service',
          'mcpServers': mcpServers,
          'contextDocuments': contextDocs,
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
          ...configuration,
        },
      );

      // Generate context-aware system prompt
      final systemPrompt = await _generateSystemPrompt(
        agent: agent,
        contextDocs: await _getContextDocuments(agent.configuration['contextDocumentIds'] as List<String>? ?? []),
        mcpServers: mcpServers,
      );

      // Update agent with generated prompt
      final agentWithPrompt = agent.copyWith(
        configuration: {
          ...agent.configuration,
          'systemPrompt': systemPrompt,
          'promptGenerated': true,
        },
      );

      // Configure MCP servers for the agent
      await _configureMCPServers(agentWithPrompt, mcpServers);

      // Set up context resources
      await _setupContextResources(agentWithPrompt, contextDocs);

      // Persist the agent
      final createdAgent = await _agentRepository.createAgent(agentWithPrompt);

      // Create agent terminal with automatic provisioning (if service available)
      if (_provisioningService != null) {
        try {
          // Add timeout to prevent hanging during terminal provisioning
          await _provisioningService!.provisionTerminalForAgent(
            createdAgent.id,
            requiredMCPServers: mcpServers,
          ).timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception(
                'Terminal provisioning timed out. This may be due to file system '
                'permission issues or slow disk I/O on macOS.'
              );
            },
          );
          
          // Update agent configuration to indicate terminal is ready
          final agentWithTerminal = createdAgent.copyWith(
            configuration: {
              ...createdAgent.configuration,
              'terminalReady': true,
              'terminalCreatedAt': DateTime.now().toIso8601String(),
              'terminalProvisioned': true,
            },
          );
          
          // Update the persisted agent
          await _agentRepository.updateAgent(agentWithTerminal);
          
          // Publish event with terminal-enabled agent
          _eventBus.publish(EntityCreatedEvent(agentWithTerminal));
          
          return BusinessResult.success(agentWithTerminal);
        } catch (e) {
          // Log terminal creation failure but don't fail agent creation
          logError('Failed to provision terminal for agent ${createdAgent.id}', e);
          
          // Update agent to indicate terminal creation failed
          final agentWithError = createdAgent.copyWith(
            configuration: {
              ...createdAgent.configuration,
              'terminalReady': false,
              'terminalError': e.toString(),
              'terminalProvisioned': false,
            },
          );
          
          await _agentRepository.updateAgent(agentWithError);
          
          // Still return success - agent was created, just without terminal
          _eventBus.publish(EntityCreatedEvent(agentWithError));
          return BusinessResult.success(agentWithError);
        }
      }
      
      // Fallback: use legacy integration service if available
      else if (_integrationService != null) {
        try {
          await _integrationService!.createAgentWithTerminal(
            createdAgent.id,
            defaultMCPServers: mcpServers,
          );
          
          // Update agent configuration to indicate terminal is ready
          final agentWithTerminal = createdAgent.copyWith(
            configuration: {
              ...createdAgent.configuration,
              'terminalReady': true,
              'terminalCreatedAt': DateTime.now().toIso8601String(),
            },
          );
          
          // Update the persisted agent
          await _agentRepository.updateAgent(agentWithTerminal);
          
          // Publish event with terminal-enabled agent
          _eventBus.publish(EntityCreatedEvent(agentWithTerminal));
          
          return BusinessResult.success(agentWithTerminal);
        } catch (e) {
          // Log terminal creation failure but don't fail agent creation
          logError('Failed to create terminal for agent ${createdAgent.id}', e);
          
          // Update agent to indicate terminal creation failed
          final agentWithError = createdAgent.copyWith(
            configuration: {
              ...createdAgent.configuration,
              'terminalReady': false,
              'terminalError': e.toString(),
            },
          );
          
          await _agentRepository.updateAgent(agentWithError);
          
          // Still return success - agent was created, just without terminal
          _eventBus.publish(EntityCreatedEvent(agentWithError));
          return BusinessResult.success(agentWithError);
        }
      }

      // Fallback: agent created without new terminal system
      _eventBus.publish(EntityCreatedEvent(createdAgent));
      return BusinessResult.success(createdAgent);
    });
  }

  /// Updates an existing agent
  Future<BusinessResult<Agent>> updateAgent({
    required Agent agent,
    String? name,
    String? description,
    List<String>? capabilities,
    String? modelId,
    List<String>? mcpServers,
    List<String>? contextDocs,
    Map<String, dynamic>? configuration,
  }) async {
    return handleBusinessOperation('updateAgent', () async {
      validateRequired({'agent': agent});

      // Create updated agent
      final updatedAgent = agent.copyWith(
        name: name?.trim() ?? agent.name,
        description: description?.trim() ?? agent.description,
        capabilities: capabilities ?? agent.capabilities,
        configuration: {
          ...agent.configuration,
          if (modelId != null) 'modelId': modelId,
          'updatedAt': DateTime.now().toIso8601String(),
          if (configuration != null) ...configuration,
        },
      );

      // Validate the update
      final validationResult = await _validateAgentUpdate(updatedAgent);
      if (!validationResult.isValid) {
        return BusinessResult.failure(validationResult.error!);
      }

      // Update MCP configuration if changed
      if (mcpServers != null) {
        await _configureMCPServers(updatedAgent, mcpServers);
      }

      // Update context resources if changed
      if (contextDocs != null) {
        await _setupContextResources(updatedAgent, contextDocs);
      }

      // Regenerate system prompt if significant changes
      if (_requiresPromptRegeneration(agent, updatedAgent)) {
        final newPrompt = await _generateSystemPrompt(
          agent: updatedAgent,
          contextDocs: await _getContextDocuments(updatedAgent.configuration['contextDocumentIds'] as List<String>? ?? []),
          mcpServers: mcpServers ?? _getMCPServersFromMetadata(agent),
        );

        final agentWithNewPrompt = updatedAgent.copyWith(
          configuration: {
            ...updatedAgent.configuration,
            'systemPrompt': newPrompt,
            'promptRegenerated': DateTime.now().toIso8601String(),
          },
        );

        final result = await _agentRepository.updateAgent(agentWithNewPrompt);
        _eventBus.publish(EntityUpdatedEvent(result));
        return BusinessResult.success(result);
      } else {
        final result = await _agentRepository.updateAgent(updatedAgent);
        _eventBus.publish(EntityUpdatedEvent(result));
        return BusinessResult.success(result);
      }
    });
  }

  /// Activates an agent and ensures all dependencies are ready
  Future<BusinessResult<Agent>> activateAgent(String agentId) async {
    return handleBusinessOperation('activateAgent', () async {
      validateRequired({'agentId': agentId});

      final agent = await _agentRepository.getAgent(agentId);

      // Validate agent can be activated
      final validationResult = await _validateAgentActivation(agent);
      if (!validationResult.isValid) {
        return BusinessResult.failure(validationResult.error!);
      }

      // Ensure model is ready
      await _ensureModelReady(agent.configuration['modelId']);

      // Ensure MCP servers are running
      final mcpServers = _getMCPServersFromMetadata(agent);
      await _ensureMCPServersReady(mcpServers);

      // Activate the agent
      final activatedAgent = agent.copyWith(
        status: AgentStatus.active,
        configuration: {
          ...agent.configuration,
          'updatedAt': DateTime.now().toIso8601String(),
          'activatedAt': DateTime.now().toIso8601String(),
        },
      );

      final result = await _agentRepository.updateAgent(activatedAgent);
      _eventBus.publish(EntityUpdatedEvent(result));

      return BusinessResult.success(result);
    });
  }

  /// Deactivates an agent and cleans up resources
  Future<BusinessResult<Agent>> deactivateAgent(String agentId) async {
    return handleBusinessOperation('deactivateAgent', () async {
      validateRequired({'agentId': agentId});

      final agent = await _agentRepository.getAgent(agentId);

      // Clean up agent resources
      await _cleanupAgentResources(agent);

      // Deactivate the agent
      final deactivatedAgent = agent.copyWith(
        status: AgentStatus.idle,
        configuration: {
          ...agent.configuration,
          'updatedAt': DateTime.now().toIso8601String(),
          'deactivatedAt': DateTime.now().toIso8601String(),
        },
      );

      final result = await _agentRepository.updateAgent(deactivatedAgent);
      _eventBus.publish(EntityUpdatedEvent(result));

      return BusinessResult.success(result);
    });
  }

  /// Deletes an agent and all associated resources
  Future<BusinessResult<void>> deleteAgent(String agentId) async {
    return handleBusinessOperation('deleteAgent', () async {
      validateRequired({'agentId': agentId});

      final agent = await _agentRepository.getAgent(agentId);

      // Validate agent can be deleted
      final validationResult = await _validateAgentDeletion(agent);
      if (!validationResult.isValid) {
        return BusinessResult.failure(validationResult.error!);
      }

      // Clean up all agent resources
      await _cleanupAgentResources(agent);

      // Delete the agent
      await _agentRepository.deleteAgent(agentId);

      // Publish event
      _eventBus.publish(EntityDeletedEvent<Agent>(agentId));

      return BusinessResult.success(null);
    });
  }

  /// Gets all agents with optional filtering
  Future<BusinessResult<List<Agent>>> getAgents({
    AgentStatus? status,
    String? modelId,
    List<String>? capabilities,
  }) async {
    return handleBusinessOperation('getAgents', () async {
      final allAgents = await _agentRepository.listAgents();

      // Apply filters
      var filteredAgents = allAgents;

      if (status != null) {
        filteredAgents = filteredAgents.where((a) => a.status == status).toList();
      }

      if (modelId != null) {
        filteredAgents = filteredAgents.where((a) => a.configuration['modelId'] == modelId).toList();
      }

      if (capabilities != null && capabilities.isNotEmpty) {
        filteredAgents = filteredAgents
            .where((a) => capabilities.every((cap) => a.capabilities.contains(cap)))
            .toList();
      }

      return BusinessResult.success(filteredAgents);
    });
  }

  /// Gets a specific agent by ID with full details
  Future<BusinessResult<Agent>> getAgentDetails(String agentId) async {
    return handleBusinessOperation('getAgentDetails', () async {
      validateRequired({'agentId': agentId});

      final agent = await _agentRepository.getAgent(agentId);

      return BusinessResult.success(agent);
    });
  }

  /// Restore terminals for all agents on application restart
  Future<BusinessResult<List<String>>> restoreAgentTerminals() async {
    return handleBusinessOperation('restoreAgentTerminals', () async {
      if (_provisioningService == null) {
        return BusinessResult.failure('Terminal provisioning service not available');
      }

      final agents = await _agentRepository.listAgents();
      final restoredAgents = <String>[];
      final failedAgents = <String>[];

      for (final agent in agents) {
        // Only restore terminals for agents that had them before
        final hadTerminal = agent.configuration['terminalReady'] == true ||
                           agent.configuration['terminalProvisioned'] == true;
        
        if (hadTerminal) {
          try {
            await _provisioningService!.restoreTerminalForAgent(agent.id);
            restoredAgents.add(agent.id);
            
            // Update agent to indicate terminal was restored
            final updatedAgent = agent.copyWith(
              configuration: {
                ...agent.configuration,
                'terminalRestored': true,
                'terminalRestoredAt': DateTime.now().toIso8601String(),
              },
            );
            await _agentRepository.updateAgent(updatedAgent);
            
          } catch (e) {
            logError('Failed to restore terminal for agent ${agent.id}', e);
            failedAgents.add(agent.id);
            
            // Update agent to indicate restoration failed
            final updatedAgent = agent.copyWith(
              configuration: {
                ...agent.configuration,
                'terminalRestored': false,
                'terminalRestoreError': e.toString(),
              },
            );
            await _agentRepository.updateAgent(updatedAgent);
          }
        }
      }

      ProductionLogger.instance.info(
        'Terminal restoration completed',
        data: {
          'restored_count': restoredAgents.length,
          'failed_count': failedAgents.length,
          'restored_agents': restoredAgents,
          'failed_agents': failedAgents,
        },
        category: 'agent_business',
      );

      return BusinessResult.success(restoredAgents);
    });
  }

  /// Get terminal provisioning status for agent
  ProvisioningStatus? getAgentTerminalStatus(String agentId) {
    return _provisioningService?.getProvisioningStatus(agentId);
  }

  /// Execute MCP tool for agent
  Future<BusinessResult<MCPToolResult>> executeAgentTool({
    required String agentId,
    required String serverId,
    required String toolName,
    required Map<String, dynamic> parameters,
    Duration? timeout,
  }) async {
    return handleBusinessOperation('executeAgentTool', () async {
      validateRequired({
        'agentId': agentId,
        'serverId': serverId,
        'toolName': toolName,
        'parameters': parameters,
      });

      // Validate agent exists and is active
      final agent = await _agentRepository.getAgent(agentId);
      if (agent.status != AgentStatus.active) {
        return BusinessResult.failure('Agent must be active to execute tools');
      }

      // Execute the tool via agent MCP service
      if (_agentMcpService != null) {
        // Execute the tool via agent MCP service
        final mcpResult = await _agentMcpService!.executeTool(
          toolName,
          parameters,
          agentId: agentId,
          serverId: serverId,
          timeout: timeout,
        );

        // Convert to MCPToolResult format expected by business layer
        final result = MCPToolResult(
          agentId: agentId,
          serverId: serverId.isNotEmpty ? serverId : 'direct-mcp',
          toolName: toolName,
          success: mcpResult.success,
          result: mcpResult.result,
          error: mcpResult.error,
          executionTime: mcpResult.executionTime,
          timestamp: mcpResult.timestamp,
        );

        // Log the execution
        ProductionLogger.instance.info(
          'Agent tool execution completed via agent MCP service',
          data: {
            'agent_id': agentId,
            'tool_name': toolName,
            'success': result.success,
            'execution_time_ms': result.executionTime.inMilliseconds,
          },
          category: 'agent_business',
        );

        return BusinessResult.success(result);
      } else {
        return BusinessResult.failure('No MCP service available for tool execution');
      }
    });
  }

  /// Get available tools for agent
  Future<BusinessResult<List<MCPToolInfo>>> getAgentTools(String agentId) async {
    return handleBusinessOperation('getAgentTools', () async {
      validateRequired({'agentId': agentId});

      // Try agent MCP service
      if (_agentMcpService != null) {
        final mcpTools = await _agentMcpService!.getAvailableTools(agentId: agentId);

        // Convert MCPToolDefinition to MCPToolInfo format
        final tools = mcpTools.map((tool) => MCPToolInfo(
          serverId: 'agent-mcp-${tool.name}',
          name: tool.name,
          description: tool.description,
          parameters: tool.parameters,
        )).toList();

        return BusinessResult.success(tools);
      } else {
        return BusinessResult.failure('No MCP service available for tool discovery');
      }
    });
  }

  /// Setup credentials for agent's MCP server
  Future<BusinessResult<void>> setupAgentCredentials({
    required String agentId,
    required String serverId,
    required Map<String, String> credentials,
  }) async {
    return handleBusinessOperation('setupAgentCredentials', () async {
      validateRequired({
        'agentId': agentId,
        'serverId': serverId,
        'credentials': credentials,
      });

      // Credentials setup moved to installation service
      /*
      if (_communicationBridge == null) {
        return BusinessResult.failure('MCP communication bridge not available');
      }

      await _communicationBridge!.setupCredentialsForAgent(
        agentId,
        serverId,
        credentials,
      );
      */

      return BusinessResult.success(null);
    });
  }



  // Private helper methods

  Future<ValidationResult> _validateAgentCreation({
    required String name,
    required String modelId,
    required List<String> mcpServers,
  }) async {
    // Check if agent name is unique
    final existingAgents = await _agentRepository.listAgents();
    if (existingAgents.any((a) => a.name.toLowerCase() == name.toLowerCase())) {
      return ValidationResult(
        isValid: false,
        error: 'Agent name "$name" already exists',
      );
    }

    // Validate model exists and is configured
    // Allow DSPy model IDs (format: provider/model-name) as they're handled by DSPy backend
    final isDspyModelId = _isDspyModelId(modelId);
    if (!isDspyModelId && !_modelService.isModelAvailable(modelId)) {
      return ValidationResult(
        isValid: false,
        error: 'Model "$modelId" is not available',
      );
    }

    // Validate MCP servers exist
    // Skipped validation for now as we rely on integration service to handle installation failures
    /*
    for (final serverId in mcpServers) {
      if (!await _mcpService.isServerConfigured(serverId)) {
        return ValidationResult(
          isValid: false,
          error: 'MCP server "$serverId" is not configured',
        );
      }
    }
    */

    return const ValidationResult(isValid: true);
  }

  Future<ValidationResult> _validateAgentUpdate(Agent agent) async {
    // Basic validation - agent exists
    if (agent.id.isEmpty) {
      return const ValidationResult(
        isValid: false,
        error: 'Agent ID cannot be empty',
      );
    }

    return const ValidationResult(isValid: true);
  }

  Future<ValidationResult> _validateAgentActivation(Agent agent) async {
    if (agent.status == AgentStatus.active) {
      return const ValidationResult(
        isValid: false,
        error: 'Agent is already active',
      );
    }

    return const ValidationResult(isValid: true);
  }

  Future<ValidationResult> _validateAgentDeletion(Agent agent) async {
    if (agent.status == AgentStatus.active) {
      return const ValidationResult(
        isValid: false,
        error: 'Cannot delete active agent. Deactivate first.',
      );
    }

    return const ValidationResult(isValid: true);
  }

  /// Check if modelId should skip strict local validation
  /// DSPy models and Ollama models are handled by their respective backends
  bool _isDspyModelId(String modelId) {
    // DSPy model IDs use provider/model format (e.g., anthropic/claude-3-sonnet)
    const dspyProviders = [
      'anthropic/',
      'openai/',
      'google/',
      'ollama/',
      'groq/',
      'together/',
      'anyscale/',
      'mistral/',
      'cohere/',
    ];
    if (dspyProviders.any((prefix) => modelId.startsWith(prefix))) {
      return true;
    }

    // Also allow Ollama model IDs (format: model:tag) and display names
    // Examples: "gemma3:4b", "llama3:8b", "Gemma3 4.3B", "Llama 3 8B"
    if (modelId.contains(':')) {
      return true; // Ollama model ID format
    }

    // Check for common Ollama model name patterns (display names)
    final lowerModelId = modelId.toLowerCase();
    const ollamaModelPatterns = [
      'gemma', 'llama', 'mistral', 'phi', 'qwen', 'codellama',
      'vicuna', 'deepseek', 'openchat', 'neural', 'dolphin',
      'wizardcoder', 'starcoder', 'codestral', 'command-r',
    ];
    if (ollamaModelPatterns.any((pattern) => lowerModelId.contains(pattern))) {
      return true;
    }

    return false;
  }

  Future<String> _generateSystemPrompt({
    required Agent agent,
    required List<context.ContextDocument> contextDocs,
    required List<String> mcpServers,
  }) async {
    return _promptService.createContextAwarePrompt(
      agentName: agent.name,
      agentDescription: agent.description,
      personality: 'Professional',
      expertise: agent.capabilities.join(', '),
      capabilities: agent.capabilities,
      mcpServers: mcpServers,
      contextDocs: contextDocs,
    );
  }

  Future<void> _configureMCPServers(Agent agent, List<String> mcpServers) async {
    if (_integrationService != null) {
      for (final serverId in mcpServers) {
        try {
          await _integrationService!.installMCPServerForAgent(agent.id, serverId);
        } catch (e) {
          logError('Failed to install MCP server $serverId for agent ${agent.id}', e);
        }
      }
    }
  }

  Future<void> _setupContextResources(Agent agent, List<String> contextDocs) async {
    await _contextService.assignContextToAgent(agent.id, contextDocs);
  }

  Future<void> _ensureModelReady(String modelId) async {
    await _modelService.initializeModel(modelId);
  }

  Future<void> _ensureMCPServersReady(List<String> mcpServers) async {
    // Managed by integration service / terminal manager
  }

  Future<void> _cleanupAgentResources(Agent agent) async {
    final mcpServers = _getMCPServersFromMetadata(agent);
    if (_integrationService != null) {
      for (final serverId in mcpServers) {
        try {
          await _integrationService!.removeMCPServerFromAgent(agent.id, serverId);
        } catch (e) {
          logError('Failed to remove MCP server $serverId for agent ${agent.id}', e);
        }
      }
    }

    // Cleanup provisioning service resources
    if (_provisioningService != null) {
      await _provisioningService!.removeAgentConfiguration(agent.id);
    }
  }

  bool _requiresPromptRegeneration(Agent oldAgent, Agent newAgent) {
    return oldAgent.name != newAgent.name ||
           oldAgent.description != newAgent.description ||
           !_listEquals(oldAgent.capabilities, newAgent.capabilities);
  }

  List<String> _getMCPServersFromMetadata(Agent agent) {
    final mcpServers = agent.configuration['mcpServers'];
    if (mcpServers is List) {
      return List<String>.from(mcpServers);
    }
    return [];
  }

  List<context.ContextDocument> _getContextDocsFromMetadata(Agent agent) {
    // Extract context documents from agent metadata
    // TODO: Implement proper deserialization when fromMap method is available
    return [];
  }

  /// Get context documents from list of IDs
  Future<List<context.ContextDocument>> _getContextDocuments(List<String> contextDocumentIds) async {
    if (contextDocumentIds.isEmpty) return [];
    
    try {
      // Get context documents from context service
      final contextDocs = <context.ContextDocument>[];
      for (final id in contextDocumentIds) {
        try {
          // TODO: Fix when getDocument method is available
          // final doc = await _contextService.getDocument(id);
          // if (doc != null) contextDocs.add(doc);
        } catch (e) {
          print('⚠️ Failed to load context document $id: $e');
        }
      }
      return contextDocs;
    } catch (e) {
      print('❌ Error loading context documents: $e');
      return [];
    }
  }

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class ValidationResult {
  final bool isValid;
  final String? error;

  const ValidationResult({
    required this.isValid,
    this.error,
  });
}
/// DSPy-Powered Agent Service
///
/// This is a UNIFIED agent service that replaces:
/// - AgentBusinessService
/// - SmartAgentOrchestratorService
/// - AgentMCPIntegrationService
/// - AgentTerminalProvisioningService
/// - StatefulAgentExecutor
/// - And 10+ other fragmented agent services
///
/// All agent logic now flows through DSPy.

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_engine_core/models/agent.dart';
import 'package:agent_engine_core/services/agent_service.dart';
import 'package:uuid/uuid.dart';

import 'dspy_service.dart';
import 'dspy_client.dart';

/// Agent execution mode
enum AgentExecutionMode {
  /// Simple chat - no tools, no reasoning
  chat,

  /// Chain of thought - step-by-step reasoning
  chainOfThought,

  /// ReAct - reasoning + tool use
  react,

  /// Tree of thought - explore multiple paths
  treeOfThought,

  /// RAG - answer from documents
  rag,
}

/// Result of agent execution
class AgentExecutionResult {
  final String answer;
  final bool success;
  final AgentExecutionMode mode;
  final double confidence;
  final String? reasoning;
  final List<AgentExecutionStep> steps;
  final Map<String, dynamic> metadata;
  final Duration executionTime;

  AgentExecutionResult({
    required this.answer,
    required this.success,
    required this.mode,
    required this.confidence,
    this.reasoning,
    this.steps = const [],
    this.metadata = const {},
    required this.executionTime,
  });
}

/// A step in agent execution
class AgentExecutionStep {
  final int iteration;
  final String thought;
  final String action;
  final String? observation;

  AgentExecutionStep({
    required this.iteration,
    required this.thought,
    required this.action,
    this.observation,
  });

  factory AgentExecutionStep.fromDspy(DspyAgentStep step) {
    return AgentExecutionStep(
      iteration: step.iteration,
      thought: step.thought,
      action: step.action,
      observation: step.observation,
    );
  }
}

/// Tool definition for agents
/// Now supports MCP tools with server_id for routing
class AgentTool {
  final String name;
  final String description;
  final Map<String, dynamic>? parameters;
  /// MCP server ID that provides this tool (null for built-in tools)
  final String? serverId;
  /// JSON Schema for the tool's input parameters
  final Map<String, dynamic>? inputSchema;

  const AgentTool({
    required this.name,
    required this.description,
    this.parameters,
    this.serverId,
    this.inputSchema,
  });

  /// Whether this is an MCP-backed tool
  bool get isMcpTool => serverId != null;

  /// Convert to DSPy API format
  Map<String, dynamic> toMap() => {
    'name': name,
    'description': description,
    if (serverId != null) 'server_id': serverId,
    if (inputSchema != null) 'input_schema': inputSchema,
  };

  /// Create from MCP tool definition
  factory AgentTool.fromMcpTool({
    required String name,
    required String description,
    required String serverId,
    Map<String, dynamic>? inputSchema,
  }) {
    return AgentTool(
      name: name,
      description: description,
      serverId: serverId,
      inputSchema: inputSchema,
    );
  }
}

/// Predefined tools that map to DSPy backend
class PredefinedTools {
  static const calculator = AgentTool(
    name: 'calculator',
    description: 'Evaluate mathematical expressions',
  );

  static const jsonParser = AgentTool(
    name: 'json_parser',
    description: 'Parse and format JSON data',
  );

  static const webSearch = AgentTool(
    name: 'web_search',
    description: 'Search the web for information',
  );

  static const codeExecutor = AgentTool(
    name: 'code_executor',
    description: 'Execute Python code',
  );

  static List<AgentTool> get all => [
    calculator,
    jsonParser,
    webSearch,
    codeExecutor,
  ];
}

/// Unified agent service powered by DSPy
///
/// Usage:
/// ```dart
/// final agentService = ref.watch(dspyAgentServiceProvider);
///
/// // Simple execution
/// final result = await agentService.execute(
///   agentId: 'my-agent',
///   task: 'Calculate the compound interest on $1000 at 5% for 3 years',
///   mode: AgentExecutionMode.react,
/// );
/// print(result.answer);
/// print(result.steps); // See reasoning steps
/// ```
class DspyAgentService {
  final AgentService _repository;
  final DspyService _dspy;

  DspyAgentService({
    required AgentService repository,
    required DspyService dspy,
  })  : _repository = repository,
        _dspy = dspy;

  // ============== Agent CRUD ==============

  /// Create a new agent
  Future<Agent> createAgent({
    required String name,
    required String description,
    List<String> capabilities = const [],
    AgentExecutionMode defaultMode = AgentExecutionMode.react,
    List<AgentTool> tools = const [],
    Map<String, dynamic> config = const {},
  }) async {
    final agent = Agent(
      id: const Uuid().v4(),
      name: name,
      description: description,
      capabilities: capabilities,
      status: AgentStatus.idle,
      configuration: {
        'defaultMode': defaultMode.name,
        'tools': tools.map((t) => t.name).toList(),
        'backend': 'dspy',
        'createdAt': DateTime.now().toIso8601String(),
        ...config,
      },
    );

    await _repository.createAgent(agent);
    return agent;
  }

  /// Get all agents
  Future<List<Agent>> getAgents() => _repository.listAgents();

  /// Get agent by ID
  Future<Agent> getAgent(String id) => _repository.getAgent(id);

  /// Update an agent
  Future<void> updateAgent(Agent agent) => _repository.updateAgent(agent);

  /// Delete an agent
  Future<void> deleteAgent(String id) => _repository.deleteAgent(id);

  // ============== Agent Execution ==============

  /// Execute an agent task
  ///
  /// This is the main entry point for running agent tasks.
  /// It routes to the appropriate DSPy endpoint based on mode.
  Future<AgentExecutionResult> execute({
    required String agentId,
    required String task,
    AgentExecutionMode? mode,
    List<AgentTool>? tools,
    List<String>? documentIds,
    int? maxIterations,
  }) async {
    final startTime = DateTime.now();

    // Get agent configuration (may not exist)
    Agent? agent;
    try {
      agent = await _repository.getAgent(agentId);
    } catch (_) {
      // Agent not found - use defaults
    }

    // Use agent config or provided overrides
    final agentMode = mode ?? _getDefaultMode(agent);
    final agentTools = tools ?? _getAgentTools(agent);
    final iterations = maxIterations ?? _getMaxIterations(agent);
    final branches = _getNumBranches(agent);

    try {
      switch (agentMode) {
        case AgentExecutionMode.chat:
          return await _executeChat(task, startTime);

        case AgentExecutionMode.chainOfThought:
          return await _executeChainOfThought(task, startTime);

        case AgentExecutionMode.react:
          return await _executeReact(task, agentTools, iterations, startTime);

        case AgentExecutionMode.treeOfThought:
          return await _executeTreeOfThought(task, startTime, numBranches: branches);

        case AgentExecutionMode.rag:
          return await _executeRag(task, documentIds ?? [], startTime);
      }
    } catch (e) {
      return AgentExecutionResult(
        answer: 'Error executing task: $e',
        success: false,
        mode: agentMode,
        confidence: 0.0,
        executionTime: DateTime.now().difference(startTime),
        metadata: {'error': e.toString()},
      );
    }
  }

  /// Execute with automatic mode selection based on task
  Future<AgentExecutionResult> executeAuto({
    required String agentId,
    required String task,
    List<String>? documentIds,
  }) async {
    // Simple heuristics for mode selection
    final mode = _inferMode(task, documentIds);
    return execute(
      agentId: agentId,
      task: task,
      mode: mode,
      documentIds: documentIds,
    );
  }

  // ============== Private Execution Methods ==============

  Future<AgentExecutionResult> _executeChat(String task, DateTime startTime) async {
    final response = await _dspy.chat(task);

    return AgentExecutionResult(
      answer: response.response,
      success: true,
      mode: AgentExecutionMode.chat,
      confidence: response.confidence ?? 0.8,
      executionTime: DateTime.now().difference(startTime),
      metadata: {'model': response.model},
    );
  }

  Future<AgentExecutionResult> _executeChainOfThought(String task, DateTime startTime) async {
    final response = await _dspy.chainOfThought(task);

    return AgentExecutionResult(
      answer: response.answer,
      success: true,
      mode: AgentExecutionMode.chainOfThought,
      confidence: response.confidence,
      reasoning: response.reasoning,
      executionTime: DateTime.now().difference(startTime),
      metadata: {'model': response.model},
    );
  }

  Future<AgentExecutionResult> _executeReact(
    String task,
    List<AgentTool> tools,
    int maxIterations,
    DateTime startTime,
  ) async {
    final response = await _dspy.executeAgent(
      task,
      tools: tools.map((t) => t.toMap()).toList(),
      maxIterations: maxIterations,
    );

    return AgentExecutionResult(
      answer: response.answer,
      success: response.success,
      mode: AgentExecutionMode.react,
      confidence: response.success ? 0.9 : 0.3,
      steps: response.steps.map((s) => AgentExecutionStep.fromDspy(s)).toList(),
      executionTime: DateTime.now().difference(startTime),
      metadata: {
        'model': response.model,
        'iterations': response.iterationsUsed,
      },
    );
  }

  Future<AgentExecutionResult> _executeTreeOfThought(
    String task,
    DateTime startTime, {
    int numBranches = 3,
  }) async {
    final response = await _dspy.treeOfThought(task, numBranches: numBranches);

    return AgentExecutionResult(
      answer: response.answer,
      success: true,
      mode: AgentExecutionMode.treeOfThought,
      confidence: response.confidence,
      reasoning: response.reasoning,
      executionTime: DateTime.now().difference(startTime),
      metadata: {
        'model': response.model,
        'branches': response.branches,
      },
    );
  }

  Future<AgentExecutionResult> _executeRag(
    String task,
    List<String> documentIds,
    DateTime startTime,
  ) async {
    final response = await _dspy.queryDocuments(
      task,
      documentIds: documentIds.isNotEmpty ? documentIds : null,
      includeCitations: true,
    );

    return AgentExecutionResult(
      answer: response.answer,
      success: true,
      mode: AgentExecutionMode.rag,
      confidence: response.confidence,
      executionTime: DateTime.now().difference(startTime),
      metadata: {
        'model': response.model,
        'sources': response.sources.map((s) => {
          'title': s.title,
          'relevance': s.relevanceScore,
        }).toList(),
        'passages_used': response.passagesUsed,
      },
    );
  }

  // ============== Helpers ==============

  AgentExecutionMode _getDefaultMode(Agent? agent) {
    if (agent == null) return AgentExecutionMode.react;

    // Check for new DSPy configuration format
    final dspyConfig = agent.configuration['dspy'] as Map<String, dynamic>?;
    if (dspyConfig != null) {
      final agentType = dspyConfig['agentType'] as String?;
      final reasoningPattern = dspyConfig['reasoningPattern'] as String?;

      // Map DSPy agent type to execution mode
      switch (agentType) {
        case 'react':
          return AgentExecutionMode.react;
        case 'code':
          return AgentExecutionMode.chainOfThought; // Code uses CoT reasoning
        case 'reasoning':
          // Check reasoning pattern
          switch (reasoningPattern) {
            case 'treeOfThought':
              return AgentExecutionMode.treeOfThought;
            case 'chainOfThought':
              return AgentExecutionMode.chainOfThought;
            default:
              return AgentExecutionMode.chat;
          }
      }
    }

    // Fallback to legacy format
    final modeStr = agent.configuration['defaultMode'] as String?;
    if (modeStr == null) return AgentExecutionMode.react;

    return AgentExecutionMode.values.firstWhere(
      (m) => m.name == modeStr,
      orElse: () => AgentExecutionMode.react,
    );
  }

  List<AgentTool> _getAgentTools(Agent? agent) {
    if (agent == null) return [PredefinedTools.calculator];

    // Check for new DSPy tools format
    final dspyTools = agent.configuration['dspyTools'] as List<dynamic>?;
    if (dspyTools != null && dspyTools.isNotEmpty) {
      return dspyTools.map((toolJson) {
        final tool = toolJson as Map<String, dynamic>;
        return AgentTool(
          name: tool['name'] as String,
          description: tool['description'] as String? ?? 'Tool',
          parameters: tool['config'] as Map<String, dynamic>?,
        );
      }).toList();
    }

    // Fallback to legacy format
    final toolNames = agent.configuration['tools'] as List<dynamic>?;
    if (toolNames == null) return [PredefinedTools.calculator];

    return toolNames
        .map((name) => PredefinedTools.all.firstWhere(
              (t) => t.name == name,
              orElse: () => AgentTool(name: name as String, description: 'Custom tool'),
            ))
        .toList();
  }

  /// Get max iterations from agent config
  int _getMaxIterations(Agent? agent) {
    if (agent == null) return 5;

    final dspyConfig = agent.configuration['dspy'] as Map<String, dynamic>?;
    if (dspyConfig != null) {
      return dspyConfig['maxIterations'] as int? ?? 5;
    }

    return agent.configuration['maxIterations'] as int? ?? 5;
  }

  /// Get number of branches for Tree of Thought
  int _getNumBranches(Agent? agent) {
    if (agent == null) return 3;

    final dspyConfig = agent.configuration['dspy'] as Map<String, dynamic>?;
    if (dspyConfig != null) {
      return dspyConfig['numBranches'] as int? ?? 3;
    }

    return 3;
  }

  AgentExecutionMode _inferMode(String task, List<String>? documentIds) {
    final lowerTask = task.toLowerCase();

    // RAG if documents provided
    if (documentIds != null && documentIds.isNotEmpty) {
      return AgentExecutionMode.rag;
    }

    // Math/calculation -> ReAct with calculator
    if (lowerTask.contains('calculate') ||
        lowerTask.contains('compute') ||
        RegExp(r'\d+\s*[\+\-\*\/]\s*\d+').hasMatch(task)) {
      return AgentExecutionMode.react;
    }

    // Comparison/decision -> Tree of thought
    if (lowerTask.contains('compare') ||
        lowerTask.contains('pros and cons') ||
        lowerTask.contains('should i') ||
        lowerTask.contains('vs')) {
      return AgentExecutionMode.treeOfThought;
    }

    // Complex reasoning -> Chain of thought
    if (lowerTask.contains('explain') ||
        lowerTask.contains('why') ||
        lowerTask.contains('how does') ||
        lowerTask.contains('step by step')) {
      return AgentExecutionMode.chainOfThought;
    }

    // Default to chat for simple queries
    return AgentExecutionMode.chat;
  }
}

// ============== Riverpod Providers ==============

/// Provider for the agent repository (local storage)
/// Uses DesktopAgentService for persistence
final agentRepositoryProvider = Provider<AgentService>((ref) {
  // This will be replaced with the actual service in main.dart provider overrides
  throw UnimplementedError(
    'Provide agentRepositoryProvider override in ProviderScope'
  );
});

/// Provider for DSPy agent service
final dspyAgentServiceProvider = Provider<DspyAgentService>((ref) {
  final dspy = ref.watch(dspyServiceProvider);
  final repository = ref.watch(agentRepositoryProvider);

  return DspyAgentService(
    repository: repository,
    dspy: dspy,
  );
});

/// Provider for current agent execution state
final agentExecutionStateProvider = StateNotifierProvider<AgentExecutionNotifier, AgentExecutionState>((ref) {
  final agentService = ref.watch(dspyAgentServiceProvider);
  return AgentExecutionNotifier(agentService);
});

/// State for agent execution
class AgentExecutionState {
  final bool isExecuting;
  final AgentExecutionResult? lastResult;
  final String? currentTask;
  final String? error;

  const AgentExecutionState({
    this.isExecuting = false,
    this.lastResult,
    this.currentTask,
    this.error,
  });

  AgentExecutionState copyWith({
    bool? isExecuting,
    AgentExecutionResult? lastResult,
    String? currentTask,
    String? error,
  }) {
    return AgentExecutionState(
      isExecuting: isExecuting ?? this.isExecuting,
      lastResult: lastResult ?? this.lastResult,
      currentTask: currentTask,
      error: error,
    );
  }
}

/// Notifier for agent execution
class AgentExecutionNotifier extends StateNotifier<AgentExecutionState> {
  final DspyAgentService _agentService;

  AgentExecutionNotifier(this._agentService) : super(const AgentExecutionState());

  /// Execute a task
  Future<AgentExecutionResult> execute({
    required String agentId,
    required String task,
    AgentExecutionMode? mode,
  }) async {
    state = state.copyWith(
      isExecuting: true,
      currentTask: task,
      error: null,
    );

    try {
      final result = await _agentService.execute(
        agentId: agentId,
        task: task,
        mode: mode,
      );

      state = state.copyWith(
        isExecuting: false,
        lastResult: result,
        currentTask: null,
      );

      return result;
    } catch (e) {
      state = state.copyWith(
        isExecuting: false,
        error: e.toString(),
        currentTask: null,
      );
      rethrow;
    }
  }

  /// Reset state
  void reset() {
    state = const AgentExecutionState();
  }
}

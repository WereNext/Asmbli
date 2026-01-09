/// DSPy Type Definitions
///
/// These types map to DSPy Python framework modules and concepts.
/// Reference: https://dspy.ai/
///
/// Official DSPy Modules Used:
/// - dspy.Predict - Basic prediction (our "basic" pattern)
/// - dspy.ChainOfThought - Step-by-step reasoning (official)
/// - dspy.ReAct - Tool-using agents (official, signature + tools + max_iters)
/// - dspy.ProgramOfThought - Code generation (requires Deno)
///
/// Custom Modules (built on DSPy primitives):
/// - TreeOfThoughtModule - Multi-path reasoning (custom, uses ChainOfThought internally)
/// - CodeAgent - Code generation without Deno requirement (custom)
library;

/// Agent types available in DSPy backend
enum DspyAgentType {
  /// ReAct Agent - Uses official dspy.ReAct
  /// API: dspy.ReAct(signature="question -> answer", tools=[...], max_iters=10)
  /// Best for: Tasks requiring tool use, multi-step problem solving
  react(
    'Task Agent',
    'Complete tasks by browsing, searching, and using tools',
    'Best for: research, web tasks, file management, and multi-step work',
  ),

  /// Code Agent - Code generation with optional execution
  /// Uses: dspy.ChainOfThought with CodeSignature (custom)
  /// Best for: Code generation, programming tasks
  code(
    'Code Agent',
    'Write, review, and explain code',
    'Best for: programming, debugging, code review, and technical docs',
  ),

  /// Reasoning Agent - Pure reasoning without tools
  /// Uses: dspy.ChainOfThought or dspy.Predict
  /// Best for: Analysis, Q&A, reasoning tasks
  reasoning(
    'Thinking Agent',
    'Analyze, plan, and reason through complex problems',
    'Best for: analysis, planning, Q&A, and logical reasoning',
  );

  const DspyAgentType(this.displayName, this.description, this.details);

  final String displayName;
  final String description;
  final String details;
}

/// Reasoning patterns available in DSPy
enum DspyReasoningPattern {
  /// Basic - Uses official dspy.Predict
  /// API: dspy.Predict("question -> answer")
  basic(
    'Quick',
    'Fast, direct answers',
    'basic',
  ),

  /// Chain of Thought - Uses official dspy.ChainOfThought
  /// API: dspy.ChainOfThought(signature, rationale_field=None)
  /// "Teaches the LM to think step-by-step before committing to response"
  chainOfThought(
    'Step-by-Step',
    'Thinks through each step before answering',
    'chain_of_thought',
  ),

  /// Tree of Thought - Custom multi-path reasoning
  /// Built on: dspy.ChainOfThought (explores multiple approaches)
  /// Note: Not an official DSPy module, but uses official primitives
  treeOfThought(
    'Thorough',
    'Considers multiple approaches to find the best answer',
    'tree_of_thought',
  );

  const DspyReasoningPattern(this.displayName, this.description, this.backendValue);

  final String displayName;
  final String description;
  final String backendValue;
}

/// LLM models supported by DSPy backend
enum DspyModel {
  // Anthropic Models
  claude3Opus('anthropic/claude-3-opus', 'Claude 3 Opus', 'anthropic', 'Most capable, best for complex tasks'),
  claude3Sonnet('anthropic/claude-3-sonnet', 'Claude 3.5 Sonnet', 'anthropic', 'Balanced performance and speed'),
  claude3Haiku('anthropic/claude-3-haiku', 'Claude 3 Haiku', 'anthropic', 'Fast and efficient'),

  // OpenAI Models
  gpt4('openai/gpt-4', 'GPT-4', 'openai', 'Strong reasoning capabilities'),
  gpt4Turbo('openai/gpt-4-turbo', 'GPT-4 Turbo', 'openai', 'Faster GPT-4 variant'),
  gpt35Turbo('openai/gpt-3.5-turbo', 'GPT-3.5 Turbo', 'openai', 'Fast and cost-effective'),

  // Google Models
  geminiPro('google/gemini-pro', 'Gemini Pro', 'google', 'Google\'s advanced model'),

  // Local Models (via Ollama)
  ollamaLlama('ollama/llama2', 'Llama 2 (Local)', 'ollama', 'Run locally via Ollama'),
  ollamaMistral('ollama/mistral', 'Mistral (Local)', 'ollama', 'Run locally via Ollama'),
  ollamaCodeLlama('ollama/codellama', 'Code Llama (Local)', 'ollama', 'Code-focused local model');

  const DspyModel(this.modelId, this.displayName, this.provider, this.description);

  final String modelId;
  final String displayName;
  final String provider;
  final String description;

  /// Check if this model requires an API key
  bool get requiresApiKey => provider != 'ollama';

  /// Get the API key environment variable name
  String? get apiKeyEnvVar {
    switch (provider) {
      case 'anthropic':
        return 'ANTHROPIC_API_KEY';
      case 'openai':
        return 'OPENAI_API_KEY';
      case 'google':
        return 'GOOGLE_API_KEY';
      default:
        return null;
    }
  }
}

/// Tool definition that maps to DSPy Tool class
/// Maps to: dspy-backend/src/modules/agents.py -> Tool
class DspyTool {
  final String name;
  final String description;
  final DspyToolType type;
  final Map<String, dynamic> config;

  const DspyTool({
    required this.name,
    required this.description,
    required this.type,
    this.config = const {},
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'type': type.name,
    'config': config,
  };

  factory DspyTool.fromJson(Map<String, dynamic> json) => DspyTool(
    name: json['name'] as String,
    description: json['description'] as String,
    type: DspyToolType.values.firstWhere(
      (t) => t.name == json['type'],
      orElse: () => DspyToolType.custom,
    ),
    config: json['config'] as Map<String, dynamic>? ?? {},
  );
}

/// Types of tools available
enum DspyToolType {
  /// Built-in calculator tool
  calculator('Calculator', 'Evaluate mathematical expressions'),

  /// Built-in JSON parser
  jsonParser('JSON Parser', 'Parse and format JSON data'),

  /// MCP-provided tool (filesystem, git, etc.)
  mcp('MCP Tool', 'Tool provided by MCP server'),

  /// Custom tool definition
  custom('Custom', 'User-defined tool');

  const DspyToolType(this.displayName, this.description);

  final String displayName;
  final String description;
}

/// Built-in tools available in DSPy backend
class DspyBuiltinTools {
  static const calculator = DspyTool(
    name: 'calculator',
    description: 'Evaluate mathematical expressions like "2 + 2" or "sqrt(16)"',
    type: DspyToolType.calculator,
  );

  static const jsonParser = DspyTool(
    name: 'json_parser',
    description: 'Parse and format JSON data',
    type: DspyToolType.jsonParser,
  );

  static List<DspyTool> get all => [calculator, jsonParser];
}

/// Agent configuration that maps to DSPy backend request
class DspyAgentConfig {
  final String id;
  final String name;
  final String description;
  final DspyAgentType agentType;
  final DspyReasoningPattern reasoningPattern;
  final String modelId; // Dynamic model ID from ModelConfigService
  final List<DspyTool> tools;
  final int maxIterations;
  final int numBranches; // For Tree of Thought
  final double minConfidence; // For Decision routing
  final Map<String, dynamic> modelParameters;

  const DspyAgentConfig({
    required this.id,
    required this.name,
    required this.description,
    required this.agentType,
    required this.reasoningPattern,
    required this.modelId,
    this.tools = const [],
    this.maxIterations = 5,
    this.numBranches = 3,
    this.minConfidence = 0.7,
    this.modelParameters = const {},
  });

  /// Convert to backend request format
  Map<String, dynamic> toBackendRequest(String task) {
    return {
      'task': task,
      'model': modelId,
      'tools': tools.map((t) => t.toJson()).toList(),
      'max_iterations': maxIterations,
      'pattern': reasoningPattern.backendValue,
      'num_branches': numBranches,
    };
  }

  /// Create from JSON
  factory DspyAgentConfig.fromJson(Map<String, dynamic> json) {
    return DspyAgentConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      agentType: DspyAgentType.values.firstWhere(
        (t) => t.name == json['agentType'],
        orElse: () => DspyAgentType.react,
      ),
      reasoningPattern: DspyReasoningPattern.values.firstWhere(
        (p) => p.name == json['reasoningPattern'],
        orElse: () => DspyReasoningPattern.chainOfThought,
      ),
      modelId: json['model'] as String? ?? 'claude-3-sonnet-20240229',
      tools: (json['tools'] as List<dynamic>?)
          ?.map((t) => DspyTool.fromJson(t as Map<String, dynamic>))
          .toList() ?? [],
      maxIterations: json['maxIterations'] as int? ?? 5,
      numBranches: json['numBranches'] as int? ?? 3,
      minConfidence: json['minConfidence'] as double? ?? 0.7,
      modelParameters: json['modelParameters'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'agentType': agentType.name,
    'reasoningPattern': reasoningPattern.name,
    'model': modelId,
    'tools': tools.map((t) => t.toJson()).toList(),
    'maxIterations': maxIterations,
    'numBranches': numBranches,
    'minConfidence': minConfidence,
    'modelParameters': modelParameters,
  };

  DspyAgentConfig copyWith({
    String? id,
    String? name,
    String? description,
    DspyAgentType? agentType,
    DspyReasoningPattern? reasoningPattern,
    String? modelId,
    List<DspyTool>? tools,
    int? maxIterations,
    int? numBranches,
    double? minConfidence,
    Map<String, dynamic>? modelParameters,
  }) {
    return DspyAgentConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      agentType: agentType ?? this.agentType,
      reasoningPattern: reasoningPattern ?? this.reasoningPattern,
      modelId: modelId ?? this.modelId,
      tools: tools ?? this.tools,
      maxIterations: maxIterations ?? this.maxIterations,
      numBranches: numBranches ?? this.numBranches,
      minConfidence: minConfidence ?? this.minConfidence,
      modelParameters: modelParameters ?? this.modelParameters,
    );
  }

  /// Convert to the core Agent model for storage
  /// This bridges the DSPy config to the existing agent persistence system
  Map<String, dynamic> toAgentConfiguration() {
    final now = DateTime.now().toIso8601String();
    return {
      // Model configuration
      'modelId': modelId,
      'modelProvider': _getProviderFromModelId(modelId),
      'temperature': modelParameters['temperature'] ?? 0.4,
      'maxTokens': modelParameters['max_tokens'] ?? 2000,

      // DSPy-specific configuration
      'dspy': {
        'agentType': agentType.name,
        'reasoningPattern': reasoningPattern.name,
        'maxIterations': maxIterations,
        'numBranches': numBranches,
        'minConfidence': minConfidence,
      },

      // Tools (MCP servers extracted for compatibility)
      'selectedTools': tools
          .where((t) => t.type == DspyToolType.mcp)
          .map((t) => t.name)
          .toList(),
      'dspyTools': tools.map((t) => t.toJson()).toList(),

      // Category based on agent type
      'category': _getCategoryFromAgentType(),

      // Timestamps
      'createdAt': now,
      'updatedAt': now,

      // Flags for DSPy backend
      'useDspyBackend': true,
      'dspyEnabled': true,
    };
  }

  String _getCategoryFromAgentType() {
    switch (agentType) {
      case DspyAgentType.react:
        return 'Task Completion';
      case DspyAgentType.code:
        return 'Development';
      case DspyAgentType.reasoning:
        return 'Reasoning';
    }
  }

  /// Infer provider from model ID string
  String _getProviderFromModelId(String id) {
    final lower = id.toLowerCase();
    if (lower.contains('claude') || lower.contains('anthropic')) {
      return 'Anthropic';
    } else if (lower.contains('gpt') || lower.contains('openai')) {
      return 'OpenAI';
    } else if (lower.contains('gemini') || lower.contains('google')) {
      return 'Google';
    } else {
      return 'Local'; // Assume local/Ollama for unknown models
    }
  }

  /// Get capabilities list based on agent type and tools
  List<String> getCapabilities() {
    final capabilities = <String>[];

    // Add agent type capability
    switch (agentType) {
      case DspyAgentType.react:
        capabilities.add('task_execution');
        capabilities.add('tool_use');
        break;
      case DspyAgentType.code:
        capabilities.add('code_generation');
        capabilities.add('code_explanation');
        break;
      case DspyAgentType.reasoning:
        capabilities.add('reasoning');
        capabilities.add('analysis');
        break;
    }

    // Add reasoning pattern capability
    switch (reasoningPattern) {
      case DspyReasoningPattern.chainOfThought:
        capabilities.add('step_by_step_reasoning');
        break;
      case DspyReasoningPattern.treeOfThought:
        capabilities.add('multi_path_reasoning');
        break;
      case DspyReasoningPattern.basic:
        break;
    }

    // Add tool capabilities
    for (final tool in tools) {
      if (tool.type == DspyToolType.calculator) {
        capabilities.add('math');
      } else if (tool.type == DspyToolType.mcp) {
        capabilities.add('mcp_${tool.name}');
      }
    }

    return capabilities;
  }
}

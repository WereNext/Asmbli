import 'dspy_types.dart';

/// DSPy Block Types - Visual blocks that map directly to DSPy modules
///
/// Each block type here has a 1:1 mapping to a DSPy backend concept:
/// - ChainOfThought -> dspy.ChainOfThought
/// - TreeOfThought -> TreeOfThoughtModule
/// - ReActAgent -> ReActAgent with tools
/// - RAGQuery -> RAGModule
/// - Decision -> DecisionModule
/// - Tool -> Tool class
/// - Input/Output -> Workflow boundaries

/// Block types that directly map to DSPy modules
enum DspyBlockType {
  /// Input block - Entry point for workflow
  /// Defines the question/task that starts the workflow
  input(
    'Input',
    'Workflow entry point',
    '#4CAF50', // Green
    'play_arrow',
  ),

  /// Chain of Thought - Step-by-step reasoning
  /// Maps to: ChainOfThoughtModule
  chainOfThought(
    'Chain of Thought',
    'Step-by-step reasoning before answering',
    '#9C27B0', // Purple
    'psychology',
  ),

  /// Tree of Thought - Multi-branch exploration
  /// Maps to: TreeOfThoughtModule
  treeOfThought(
    'Tree of Thought',
    'Explore multiple approaches, synthesize best',
    '#3F51B5', // Indigo
    'account_tree',
  ),

  /// ReAct Agent - Reasoning + Acting with tools
  /// Maps to: ReActAgent
  reactAgent(
    'ReAct Agent',
    'Tool-using agent with think-act-observe loop',
    '#FF5722', // Deep Orange
    'smart_toy',
  ),

  /// RAG Query - Retrieve and generate
  /// Maps to: RAGModule
  ragQuery(
    'RAG Query',
    'Retrieve documents and generate answer',
    '#2196F3', // Blue
    'search',
  ),

  /// Decision - Confidence-based routing
  /// Maps to: DecisionModule
  decision(
    'Decision',
    'Route based on confidence threshold',
    '#FF9800', // Orange
    'call_split',
  ),

  /// Tool - Callable function
  /// Maps to: Tool class
  tool(
    'Tool',
    'Execute a specific tool/function',
    '#00BCD4', // Cyan
    'build',
  ),

  /// Code Generation
  /// Maps to: CodeAgent
  codeGen(
    'Code Generation',
    'Generate and optionally execute code',
    '#607D8B', // Blue Grey
    'code',
  ),

  /// Output block - Exit point for workflow
  /// Returns the final result
  output(
    'Output',
    'Workflow exit point with result',
    '#4CAF50', // Green
    'check_circle',
  );

  const DspyBlockType(
    this.displayName,
    this.description,
    this.color,
    this.icon,
  );

  final String displayName;
  final String description;
  final String color;
  final String icon;
}

/// Position on the visual canvas
class BlockPosition {
  final double x;
  final double y;

  const BlockPosition({required this.x, required this.y});

  BlockPosition copyWith({double? x, double? y}) =>
      BlockPosition(x: x ?? this.x, y: y ?? this.y);

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  factory BlockPosition.fromJson(Map<String, dynamic> json) =>
      BlockPosition(x: json['x'] as double, y: json['y'] as double);
}

/// A visual block in the DSPy workflow
class DspyBlock {
  final String id;
  final DspyBlockType type;
  final String label;
  final BlockPosition position;
  final DspyBlockConfig config;

  const DspyBlock({
    required this.id,
    required this.type,
    required this.label,
    required this.position,
    required this.config,
  });

  DspyBlock copyWith({
    String? id,
    DspyBlockType? type,
    String? label,
    BlockPosition? position,
    DspyBlockConfig? config,
  }) {
    return DspyBlock(
      id: id ?? this.id,
      type: type ?? this.type,
      label: label ?? this.label,
      position: position ?? this.position,
      config: config ?? this.config,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'label': label,
    'position': position.toJson(),
    'config': config.toJson(),
  };

  factory DspyBlock.fromJson(Map<String, dynamic> json) {
    final type = DspyBlockType.values.firstWhere(
      (t) => t.name == json['type'],
      orElse: () => DspyBlockType.chainOfThought,
    );
    return DspyBlock(
      id: json['id'] as String,
      type: type,
      label: json['label'] as String,
      position: BlockPosition.fromJson(json['position'] as Map<String, dynamic>),
      config: DspyBlockConfig.fromJson(json['config'] as Map<String, dynamic>, type),
    );
  }

  /// Get default size based on block type
  double get width {
    switch (type) {
      case DspyBlockType.reactAgent:
      case DspyBlockType.treeOfThought:
        return 180.0;
      case DspyBlockType.decision:
        return 160.0;
      default:
        return 140.0;
    }
  }

  double get height {
    switch (type) {
      case DspyBlockType.reactAgent:
        return 80.0;
      default:
        return 60.0;
    }
  }
}

/// Configuration for a DSPy block - varies by type
abstract class DspyBlockConfig {
  Map<String, dynamic> toJson();

  factory DspyBlockConfig.fromJson(Map<String, dynamic> json, DspyBlockType type) {
    switch (type) {
      case DspyBlockType.input:
        return InputBlockConfig.fromJson(json);
      case DspyBlockType.chainOfThought:
        return ChainOfThoughtBlockConfig.fromJson(json);
      case DspyBlockType.treeOfThought:
        return TreeOfThoughtBlockConfig.fromJson(json);
      case DspyBlockType.reactAgent:
        return ReActBlockConfig.fromJson(json);
      case DspyBlockType.ragQuery:
        return RAGBlockConfig.fromJson(json);
      case DspyBlockType.decision:
        return DecisionBlockConfig.fromJson(json);
      case DspyBlockType.tool:
        return ToolBlockConfig.fromJson(json);
      case DspyBlockType.codeGen:
        return CodeGenBlockConfig.fromJson(json);
      case DspyBlockType.output:
        return OutputBlockConfig.fromJson(json);
    }
  }

  factory DspyBlockConfig.defaultFor(DspyBlockType type) {
    switch (type) {
      case DspyBlockType.input:
        return const InputBlockConfig();
      case DspyBlockType.chainOfThought:
        return const ChainOfThoughtBlockConfig();
      case DspyBlockType.treeOfThought:
        return const TreeOfThoughtBlockConfig();
      case DspyBlockType.reactAgent:
        return const ReActBlockConfig();
      case DspyBlockType.ragQuery:
        return const RAGBlockConfig();
      case DspyBlockType.decision:
        return const DecisionBlockConfig();
      case DspyBlockType.tool:
        return const ToolBlockConfig(toolName: 'calculator');
      case DspyBlockType.codeGen:
        return const CodeGenBlockConfig();
      case DspyBlockType.output:
        return const OutputBlockConfig();
    }
  }
}

/// Input block config
class InputBlockConfig implements DspyBlockConfig {
  final String variableName;
  final String description;

  const InputBlockConfig({
    this.variableName = 'question',
    this.description = 'The input question or task',
  });

  @override
  Map<String, dynamic> toJson() => {
    'variableName': variableName,
    'description': description,
  };

  factory InputBlockConfig.fromJson(Map<String, dynamic> json) => InputBlockConfig(
    variableName: json['variableName'] as String? ?? 'question',
    description: json['description'] as String? ?? 'The input question or task',
  );
}

/// Chain of Thought config
/// Maps to: ChainOfThoughtModule
class ChainOfThoughtBlockConfig implements DspyBlockConfig {
  final String signatureInput;
  final String signatureOutput;

  const ChainOfThoughtBlockConfig({
    this.signatureInput = 'question',
    this.signatureOutput = 'answer',
  });

  @override
  Map<String, dynamic> toJson() => {
    'signatureInput': signatureInput,
    'signatureOutput': signatureOutput,
  };

  factory ChainOfThoughtBlockConfig.fromJson(Map<String, dynamic> json) =>
      ChainOfThoughtBlockConfig(
        signatureInput: json['signatureInput'] as String? ?? 'question',
        signatureOutput: json['signatureOutput'] as String? ?? 'answer',
      );
}

/// Tree of Thought config
/// Maps to: TreeOfThoughtModule(num_branches=N)
class TreeOfThoughtBlockConfig implements DspyBlockConfig {
  final int numBranches;
  final List<String> approaches;

  const TreeOfThoughtBlockConfig({
    this.numBranches = 3,
    this.approaches = const [
      'straightforward solution',
      'creative approach',
      'robust and scalable solution',
    ],
  });

  @override
  Map<String, dynamic> toJson() => {
    'numBranches': numBranches,
    'approaches': approaches,
  };

  factory TreeOfThoughtBlockConfig.fromJson(Map<String, dynamic> json) =>
      TreeOfThoughtBlockConfig(
        numBranches: json['numBranches'] as int? ?? 3,
        approaches: (json['approaches'] as List<dynamic>?)
            ?.cast<String>() ?? const ['straightforward', 'creative', 'robust'],
      );
}

/// ReAct Agent config
/// Maps to: ReActAgent(tools=[], max_iterations=N)
class ReActBlockConfig implements DspyBlockConfig {
  final int maxIterations;
  final List<String> toolIds; // References to tool blocks or built-in tools

  const ReActBlockConfig({
    this.maxIterations = 5,
    this.toolIds = const ['calculator', 'json_parser'],
  });

  @override
  Map<String, dynamic> toJson() => {
    'maxIterations': maxIterations,
    'toolIds': toolIds,
  };

  factory ReActBlockConfig.fromJson(Map<String, dynamic> json) => ReActBlockConfig(
    maxIterations: json['maxIterations'] as int? ?? 5,
    toolIds: (json['toolIds'] as List<dynamic>?)?.cast<String>() ?? const [],
  );
}

/// RAG Query config
/// Maps to: RAGModule(num_passages=N)
class RAGBlockConfig implements DspyBlockConfig {
  final int numPassages;
  final bool includeCitations;

  const RAGBlockConfig({
    this.numPassages = 5,
    this.includeCitations = true,
  });

  @override
  Map<String, dynamic> toJson() => {
    'numPassages': numPassages,
    'includeCitations': includeCitations,
  };

  factory RAGBlockConfig.fromJson(Map<String, dynamic> json) => RAGBlockConfig(
    numPassages: json['numPassages'] as int? ?? 5,
    includeCitations: json['includeCitations'] as bool? ?? true,
  );
}

/// Decision block config
/// Maps to: DecisionModule(min_confidence=N)
class DecisionBlockConfig implements DspyBlockConfig {
  final double confidenceThreshold;
  final String highConfidenceOutput;
  final String lowConfidenceOutput;

  const DecisionBlockConfig({
    this.confidenceThreshold = 0.7,
    this.highConfidenceOutput = 'high_confidence',
    this.lowConfidenceOutput = 'low_confidence',
  });

  @override
  Map<String, dynamic> toJson() => {
    'confidenceThreshold': confidenceThreshold,
    'highConfidenceOutput': highConfidenceOutput,
    'lowConfidenceOutput': lowConfidenceOutput,
  };

  factory DecisionBlockConfig.fromJson(Map<String, dynamic> json) =>
      DecisionBlockConfig(
        confidenceThreshold: json['confidenceThreshold'] as double? ?? 0.7,
        highConfidenceOutput: json['highConfidenceOutput'] as String? ?? 'high_confidence',
        lowConfidenceOutput: json['lowConfidenceOutput'] as String? ?? 'low_confidence',
      );
}

/// Tool block config
/// Maps to: Tool(name, description, func)
class ToolBlockConfig implements DspyBlockConfig {
  final String toolName;
  final String? customDescription;
  final DspyToolType toolType;

  const ToolBlockConfig({
    required this.toolName,
    this.customDescription,
    this.toolType = DspyToolType.calculator,
  });

  @override
  Map<String, dynamic> toJson() => {
    'toolName': toolName,
    'customDescription': customDescription,
    'toolType': toolType.name,
  };

  factory ToolBlockConfig.fromJson(Map<String, dynamic> json) => ToolBlockConfig(
    toolName: json['toolName'] as String? ?? 'calculator',
    customDescription: json['customDescription'] as String?,
    toolType: DspyToolType.values.firstWhere(
      (t) => t.name == json['toolType'],
      orElse: () => DspyToolType.calculator,
    ),
  );
}

/// Code Generation block config
/// Maps to: CodeAgent(execute_python=bool)
class CodeGenBlockConfig implements DspyBlockConfig {
  final String language;
  final bool executeCode;

  const CodeGenBlockConfig({
    this.language = 'python',
    this.executeCode = false,
  });

  @override
  Map<String, dynamic> toJson() => {
    'language': language,
    'executeCode': executeCode,
  };

  factory CodeGenBlockConfig.fromJson(Map<String, dynamic> json) => CodeGenBlockConfig(
    language: json['language'] as String? ?? 'python',
    executeCode: json['executeCode'] as bool? ?? false,
  );
}

/// Output block config
class OutputBlockConfig implements DspyBlockConfig {
  final String variableName;
  final bool includeReasoning;

  const OutputBlockConfig({
    this.variableName = 'result',
    this.includeReasoning = true,
  });

  @override
  Map<String, dynamic> toJson() => {
    'variableName': variableName,
    'includeReasoning': includeReasoning,
  };

  factory OutputBlockConfig.fromJson(Map<String, dynamic> json) => OutputBlockConfig(
    variableName: json['variableName'] as String? ?? 'result',
    includeReasoning: json['includeReasoning'] as bool? ?? true,
  );
}

/// Connection between blocks
class DspyBlockConnection {
  final String id;
  final String sourceBlockId;
  final String targetBlockId;
  final String? sourcePin;
  final String? targetPin;

  const DspyBlockConnection({
    required this.id,
    required this.sourceBlockId,
    required this.targetBlockId,
    this.sourcePin,
    this.targetPin,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceBlockId': sourceBlockId,
    'targetBlockId': targetBlockId,
    'sourcePin': sourcePin,
    'targetPin': targetPin,
  };

  factory DspyBlockConnection.fromJson(Map<String, dynamic> json) =>
      DspyBlockConnection(
        id: json['id'] as String,
        sourceBlockId: json['sourceBlockId'] as String,
        targetBlockId: json['targetBlockId'] as String,
        sourcePin: json['sourcePin'] as String?,
        targetPin: json['targetPin'] as String?,
      );
}

/// Complete DSPy workflow
class DspyWorkflow {
  final String id;
  final String name;
  final String? description;
  final DspyModel model;
  final List<DspyBlock> blocks;
  final List<DspyBlockConnection> connections;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DspyWorkflow({
    required this.id,
    required this.name,
    this.description,
    required this.model,
    required this.blocks,
    required this.connections,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DspyWorkflow.empty() {
    final now = DateTime.now();
    return DspyWorkflow(
      id: 'workflow_${now.millisecondsSinceEpoch}',
      name: 'New DSPy Workflow',
      model: DspyModel.claude3Sonnet,
      blocks: [],
      connections: [],
      createdAt: now,
      updatedAt: now,
    );
  }

  DspyWorkflow copyWith({
    String? id,
    String? name,
    String? description,
    DspyModel? model,
    List<DspyBlock>? blocks,
    List<DspyBlockConnection>? connections,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DspyWorkflow(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      model: model ?? this.model,
      blocks: blocks ?? this.blocks,
      connections: connections ?? this.connections,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'model': model.modelId,
    'blocks': blocks.map((b) => b.toJson()).toList(),
    'connections': connections.map((c) => c.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory DspyWorkflow.fromJson(Map<String, dynamic> json) {
    return DspyWorkflow(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      model: DspyModel.values.firstWhere(
        (m) => m.modelId == json['model'],
        orElse: () => DspyModel.claude3Sonnet,
      ),
      blocks: (json['blocks'] as List<dynamic>)
          .map((b) => DspyBlock.fromJson(b as Map<String, dynamic>))
          .toList(),
      connections: (json['connections'] as List<dynamic>)
          .map((c) => DspyBlockConnection.fromJson(c as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// Validate workflow structure
  bool get isValid {
    final hasInput = blocks.any((b) => b.type == DspyBlockType.input);
    final hasOutput = blocks.any((b) => b.type == DspyBlockType.output);
    return hasInput && hasOutput;
  }

  /// Get input block
  DspyBlock? get inputBlock =>
      blocks.where((b) => b.type == DspyBlockType.input).firstOrNull;

  /// Get output blocks
  List<DspyBlock> get outputBlocks =>
      blocks.where((b) => b.type == DspyBlockType.output).toList();
}

import 'package:flutter/material.dart';
import 'dspy_types.dart';

/// Unified Agent Template that maps directly to DSPy backend
///
/// This template combines:
/// - Rich content (system prompts, example tasks)
/// - DSPy execution configuration (agent type, reasoning pattern)
/// - Tool/MCP integration
class AgentTemplate {
  final String id;
  final String name;
  final String description;
  final String category;
  final IconData icon;

  // DSPy Backend Configuration (required for execution)
  final DspyAgentType agentType;
  final DspyReasoningPattern reasoningPattern;
  final DspyModel defaultModel;
  final double temperature;
  final int maxTokens;
  final int maxIterations;
  final int numBranches; // For Tree of Thought
  final double minConfidence; // For decision routing

  // Rich Content
  final String systemPrompt;
  final List<String> exampleTasks;
  final List<String> capabilities;
  final String primaryCapability;

  // Tools & MCP
  final List<DspyTool> suggestedTools;
  final List<String> suggestedMCPServers;

  // Legacy fields (kept for backward compatibility)
  final Map<String, String>? recommendedModels;
  final EstimatedUsage estimatedTokenUsage;

  const AgentTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.icon,
    // DSPy config with sensible defaults
    this.agentType = DspyAgentType.react,
    this.reasoningPattern = DspyReasoningPattern.chainOfThought,
    this.defaultModel = DspyModel.claude3Sonnet,
    this.temperature = 0.4,
    this.maxTokens = 2000,
    this.maxIterations = 5,
    this.numBranches = 3,
    this.minConfidence = 0.7,
    // Rich content
    this.systemPrompt = '',
    this.exampleTasks = const [],
    this.capabilities = const [],
    this.primaryCapability = '',
    // Tools
    this.suggestedTools = const [],
    this.suggestedMCPServers = const [],
    // Legacy
    this.recommendedModels,
    this.estimatedTokenUsage = EstimatedUsage.medium,
  });

  /// Build DSPy agent configuration from this template
  DspyAgentConfig toDspyConfig({String? customName, String? customDescription}) {
    final id = _generateAgentId();

    // Convert MCP servers to tools
    final mcpTools = suggestedMCPServers.map((serverId) => DspyTool(
          name: serverId,
          description: 'MCP tool: $serverId',
          type: DspyToolType.mcp,
        ));

    final allTools = [...suggestedTools, ...mcpTools];

    return DspyAgentConfig(
      id: id,
      name: customName ?? name,
      description: customDescription ?? description,
      agentType: agentType,
      reasoningPattern: reasoningPattern,
      modelId: defaultModel.modelId,
      tools: allTools,
      maxIterations: maxIterations,
      numBranches: numBranches,
      minConfidence: minConfidence,
      modelParameters: {
        'temperature': temperature,
        'max_tokens': maxTokens,
        'system_prompt': systemPrompt,
      },
    );
  }

  /// Legacy method - Create an agent configuration from this template
  Map<String, dynamic> toAgentConfiguration() {
    return {
      'type': 'templated_agent',
      'templateId': id,
      'capabilities': capabilities,
      'primaryCapability': primaryCapability,
      'modelConfiguration': {
        'primaryModelId': defaultModel.modelId,
        'capabilities': capabilities,
      },
      'systemPrompt': systemPrompt,
      'suggestedMCPTools': suggestedMCPServers,
      'estimatedTokenUsage': estimatedTokenUsage.name,
      // DSPy specific
      'dspy': {
        'agentType': agentType.name,
        'reasoningPattern': reasoningPattern.name,
        'maxIterations': maxIterations,
        'numBranches': numBranches,
        'minConfidence': minConfidence,
        'temperature': temperature,
        'maxTokens': maxTokens,
      },
      'useDspyBackend': true,
    };
  }

  /// Generate a unique agent ID
  String _generateAgentId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final nameSlug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-');
    return '$nameSlug-$timestamp';
  }

  /// Get display name for the primary model
  String get primaryModelDisplayName => defaultModel.displayName;

  /// Check if template uses tools
  bool get hasTools => suggestedTools.isNotEmpty || suggestedMCPServers.isNotEmpty;

  /// Get count of specialized models (legacy compatibility)
  int get specializedModelCount => 0;

  /// Check if template uses multiple models (legacy compatibility)
  bool get isMultiModel => false;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgentTemplate &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  /// Copy with modifications
  AgentTemplate copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    IconData? icon,
    DspyAgentType? agentType,
    DspyReasoningPattern? reasoningPattern,
    DspyModel? defaultModel,
    double? temperature,
    int? maxTokens,
    int? maxIterations,
    int? numBranches,
    double? minConfidence,
    String? systemPrompt,
    List<String>? exampleTasks,
    List<String>? capabilities,
    String? primaryCapability,
    List<DspyTool>? suggestedTools,
    List<String>? suggestedMCPServers,
    EstimatedUsage? estimatedTokenUsage,
  }) {
    return AgentTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      icon: icon ?? this.icon,
      agentType: agentType ?? this.agentType,
      reasoningPattern: reasoningPattern ?? this.reasoningPattern,
      defaultModel: defaultModel ?? this.defaultModel,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      maxIterations: maxIterations ?? this.maxIterations,
      numBranches: numBranches ?? this.numBranches,
      minConfidence: minConfidence ?? this.minConfidence,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      exampleTasks: exampleTasks ?? this.exampleTasks,
      capabilities: capabilities ?? this.capabilities,
      primaryCapability: primaryCapability ?? this.primaryCapability,
      suggestedTools: suggestedTools ?? this.suggestedTools,
      suggestedMCPServers: suggestedMCPServers ?? this.suggestedMCPServers,
      estimatedTokenUsage: estimatedTokenUsage ?? this.estimatedTokenUsage,
    );
  }
}

/// Estimated token usage levels for templates
enum EstimatedUsage {
  low,
  medium,
  high,
}

extension EstimatedUsageExtension on EstimatedUsage {
  String get displayName {
    switch (this) {
      case EstimatedUsage.low:
        return 'Low';
      case EstimatedUsage.medium:
        return 'Medium';
      case EstimatedUsage.high:
        return 'High';
    }
  }

  Color get color {
    switch (this) {
      case EstimatedUsage.low:
        return Colors.green;
      case EstimatedUsage.medium:
        return Colors.orange;
      case EstimatedUsage.high:
        return Colors.red;
    }
  }
}

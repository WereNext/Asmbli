import 'package:flutter/foundation.dart';
import '../../../core/models/dspy_types.dart';
import '../../../core/models/agent_template.dart';
import '../../../core/models/model_config.dart';

/// DSPy-aligned Agent Wizard State
///
/// This state model directly maps to DSPy backend concepts.
/// Every field here corresponds to a real parameter in the DSPy API.
class DspyAgentWizardState extends ChangeNotifier {
  // ===== Step 1: Agent Basics =====
  String _agentName = '';
  String _agentDescription = '';

  // ===== Step 2: Agent Type =====
  DspyAgentType _agentType = DspyAgentType.react;
  DspyReasoningPattern _reasoningPattern = DspyReasoningPattern.chainOfThought;

  // ===== Step 3: Model Selection =====
  // Using dynamic model selection via ModelConfigService
  String _selectedModelId = ''; // Model identifier (e.g., "claude-3-sonnet", "gemma3:4b")
  ModelConfig? _selectedModelConfig; // Full model config for display
  double _temperature = 0.4;
  int _maxTokens = 2000;

  // ===== Step 4: Tools & Capabilities =====
  List<DspyTool> _selectedTools = [];
  int _maxIterations = 5;
  int _numBranches = 3; // For Tree of Thought
  double _minConfidence = 0.7; // For Decision routing

  // ===== Step 5: MCP Integration (optional) =====
  List<String> _selectedMCPServers = [];
  Map<String, Map<String, String>> _mcpServerConfigs = {};

  // ===== System Prompt (from template) =====
  String _systemPrompt = '';

  // ===== Validation & Deployment =====
  bool _isValidated = false;
  String? _deploymentError;

  // ==================== Getters ====================

  // Step 1
  String get agentName => _agentName;
  String get agentDescription => _agentDescription;

  // Step 2
  DspyAgentType get agentType => _agentType;
  DspyReasoningPattern get reasoningPattern => _reasoningPattern;

  // Step 3
  String get selectedModelId => _selectedModelId;
  ModelConfig? get selectedModelConfig => _selectedModelConfig;
  double get temperature => _temperature;
  int get maxTokens => _maxTokens;

  // Step 4
  List<DspyTool> get selectedTools => List.unmodifiable(_selectedTools);
  int get maxIterations => _maxIterations;
  int get numBranches => _numBranches;
  double get minConfidence => _minConfidence;

  // Step 5
  List<String> get selectedMCPServers => List.unmodifiable(_selectedMCPServers);
  Map<String, Map<String, String>> get mcpServerConfigs =>
      Map.unmodifiable(_mcpServerConfigs);

  // System Prompt
  String get systemPrompt => _systemPrompt;

  // Validation
  bool get isValidated => _isValidated;
  String? get deploymentError => _deploymentError;

  // ==================== Setters ====================

  // Step 1: Agent Basics
  void setAgentName(String name) {
    _agentName = name;
    notifyListeners();
  }

  void setAgentDescription(String description) {
    _agentDescription = description;
    notifyListeners();
  }

  // Step 2: Agent Type
  void setAgentType(DspyAgentType type) {
    _agentType = type;
    // Update reasoning pattern based on agent type
    if (type == DspyAgentType.react) {
      // ReAct agents use iterative reasoning
      _reasoningPattern = DspyReasoningPattern.chainOfThought;
    } else if (type == DspyAgentType.code) {
      // Code agents typically use chain of thought
      _reasoningPattern = DspyReasoningPattern.chainOfThought;
    }
    notifyListeners();
  }

  void setReasoningPattern(DspyReasoningPattern pattern) {
    _reasoningPattern = pattern;
    notifyListeners();
  }

  // Step 3: Model Selection
  void setSelectedModelId(String modelId) {
    _selectedModelId = modelId;
    notifyListeners();
  }

  void setSelectedModelConfig(ModelConfig? config) {
    _selectedModelConfig = config;
    if (config != null) {
      _selectedModelId = config.model;
    }
    notifyListeners();
  }

  void setTemperature(double temp) {
    _temperature = temp.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setMaxTokens(int tokens) {
    _maxTokens = tokens.clamp(100, 8000);
    notifyListeners();
  }

  // Step 4: Tools & Capabilities
  void addTool(DspyTool tool) {
    if (!_selectedTools.any((t) => t.name == tool.name)) {
      _selectedTools = [..._selectedTools, tool];
      notifyListeners();
    }
  }

  void removeTool(String toolName) {
    _selectedTools = _selectedTools.where((t) => t.name != toolName).toList();
    notifyListeners();
  }

  void setMaxIterations(int iterations) {
    _maxIterations = iterations.clamp(1, 20);
    notifyListeners();
  }

  void setNumBranches(int branches) {
    _numBranches = branches.clamp(2, 5);
    notifyListeners();
  }

  void setMinConfidence(double confidence) {
    _minConfidence = confidence.clamp(0.0, 1.0);
    notifyListeners();
  }

  // Step 5: MCP Integration
  void addMCPServer(String serverId) {
    if (!_selectedMCPServers.contains(serverId)) {
      _selectedMCPServers = [..._selectedMCPServers, serverId];
      notifyListeners();
    }
  }

  void removeMCPServer(String serverId) {
    _selectedMCPServers =
        _selectedMCPServers.where((id) => id != serverId).toList();
    _mcpServerConfigs.remove(serverId);
    notifyListeners();
  }

  void setMCPServerConfig(String serverId, Map<String, String> config) {
    _mcpServerConfigs = {..._mcpServerConfigs, serverId: config};
    notifyListeners();
  }

  // System Prompt
  void setSystemPrompt(String prompt) {
    _systemPrompt = prompt;
    notifyListeners();
  }

  // Validation
  void setValidated(bool validated) {
    _isValidated = validated;
    notifyListeners();
  }

  void setDeploymentError(String? error) {
    _deploymentError = error;
    notifyListeners();
  }

  // ==================== Validation ====================

  bool isStepValid(int step) {
    switch (step) {
      case 0: // Agent Basics
        return _agentName.trim().isNotEmpty &&
            _agentDescription.trim().isNotEmpty;
      case 1: // Agent Type
        return true; // Always valid - has defaults
      case 2: // Model Selection
        return true; // Always valid - has defaults
      case 3: // System Prompt
        return true; // Always valid - prompt is optional
      case 4: // Tools & Capabilities
        // ReAct agents should have at least one tool
        if (_agentType == DspyAgentType.react && _selectedTools.isEmpty) {
          return false;
        }
        return true;
      case 5: // Deploy
        return isStepValid(0) && isStepValid(1) && isStepValid(2) && isStepValid(3) && isStepValid(4);
      default:
        return false;
    }
  }

  bool get isValid => isStepValid(5);

  String? getStepError(int step) {
    switch (step) {
      case 0:
        if (_agentName.trim().isEmpty) return 'Agent name is required';
        if (_agentDescription.trim().isEmpty) return 'Description is required';
        return null;
      case 4:
        if (_agentType == DspyAgentType.react && _selectedTools.isEmpty) {
          return 'ReAct agents need at least one tool';
        }
        return null;
      default:
        return null;
    }
  }

  // ==================== Build Config ====================

  /// Build the final DSPy agent configuration
  DspyAgentConfig buildAgentConfig() {
    final id = _generateAgentId();

    // Convert MCP servers to tools
    final mcpTools = _selectedMCPServers.map((serverId) => DspyTool(
          name: serverId,
          description: 'MCP tool: $serverId',
          type: DspyToolType.mcp,
          config: _mcpServerConfigs[serverId] ?? {},
        ));

    final allTools = [..._selectedTools, ...mcpTools];

    return DspyAgentConfig(
      id: id,
      name: _agentName,
      description: _agentDescription,
      agentType: _agentType,
      reasoningPattern: _reasoningPattern,
      modelId: _selectedModelId.isNotEmpty ? _selectedModelId : 'claude-3-sonnet-20240229',
      tools: allTools,
      maxIterations: _maxIterations,
      numBranches: _numBranches,
      minConfidence: _minConfidence,
      modelParameters: {
        'temperature': _temperature,
        'max_tokens': _maxTokens,
        'system_prompt': _systemPrompt,
      },
    );
  }

  /// Generate a unique agent ID
  String _generateAgentId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final nameSlug =
        _agentName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-');
    return '$nameSlug-$timestamp';
  }

  // ==================== Reset ====================

  void reset() {
    _agentName = '';
    _agentDescription = '';
    _agentType = DspyAgentType.react;
    _reasoningPattern = DspyReasoningPattern.chainOfThought;
    _selectedModelId = '';
    _selectedModelConfig = null;
    _temperature = 0.4;
    _maxTokens = 2000;
    _selectedTools = [];
    _maxIterations = 5;
    _numBranches = 3;
    _minConfidence = 0.7;
    _selectedMCPServers = [];
    _mcpServerConfigs = {};
    _systemPrompt = '';
    _isValidated = false;
    _deploymentError = null;
    notifyListeners();
  }

  // ==================== Load from Template ====================

  /// Load wizard state from a unified AgentTemplate
  void loadFromTemplate(AgentTemplate template) {
    _agentName = template.name;
    _agentDescription = template.description;
    _agentType = template.agentType;
    _reasoningPattern = template.reasoningPattern;
    // Use model ID from template's default model
    _selectedModelId = template.defaultModel.modelId;
    _selectedModelConfig = null; // Will be set when user visits model step
    _temperature = template.temperature;
    _maxTokens = template.maxTokens;
    _selectedTools = List.from(template.suggestedTools);
    _maxIterations = template.maxIterations;
    _numBranches = template.numBranches;
    _minConfidence = template.minConfidence;
    _selectedMCPServers = List.from(template.suggestedMCPServers);
    _systemPrompt = template.systemPrompt;
    notifyListeners();
  }
}

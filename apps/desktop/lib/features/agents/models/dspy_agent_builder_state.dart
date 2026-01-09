import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show IconData;
import 'package:agent_engine_core/models/agent.dart';

/// DSPy Agent Types - maps to execution modes
enum DspyAgentType {
  react,       // ReAct agent with tools and reasoning
  reasoning,   // Reasoning-only (CoT, ToT)
  chat,        // Simple chat (no tools or reasoning)
  rag,         // Document-based QA
}

/// DSPy Reasoning Patterns
enum DspyReasoningPattern {
  basic,           // Direct answer
  chainOfThought,  // Step-by-step reasoning
  treeOfThought,   // Multiple branch exploration
}

/// Available tools for DSPy agents
class DspyTool {
  final String id;
  final String name;
  final String description;
  final IconData? icon;
  final bool isBuiltIn;

  const DspyTool({
    required this.id,
    required this.name,
    required this.description,
    this.icon,
    this.isBuiltIn = true,
  });

  static const List<DspyTool> builtInTools = [
    DspyTool(
      id: 'calculator',
      name: 'Calculator',
      description: 'Evaluate mathematical expressions',
      isBuiltIn: true,
    ),
    DspyTool(
      id: 'json_parser',
      name: 'JSON Parser',
      description: 'Parse and manipulate JSON data',
      isBuiltIn: true,
    ),
    DspyTool(
      id: 'web_search',
      name: 'Web Search',
      description: 'Search the internet for information',
      isBuiltIn: true,
    ),
    DspyTool(
      id: 'code_executor',
      name: 'Code Executor',
      description: 'Execute Python code snippets',
      isBuiltIn: true,
    ),
  ];
}

/// Simplified wizard steps for DSPy agent creation
enum DspyBuilderStep {
  basicInfo,        // Name, description
  agentConfig,      // Agent type, reasoning pattern, iterations
  systemPrompt,     // Master prompt
  toolsAndContext,  // Tools and documents
  modelSelection,   // Model and parameters
  review,           // Final review
}

/// DSPy-focused agent builder state
class DspyAgentBuilderState extends ChangeNotifier {
  // Builder state
  DspyBuilderStep _currentStep = DspyBuilderStep.basicInfo;
  bool _isEditing = false;
  String? _editingAgentId;

  // Step 1: Basic Info
  String _name = '';
  String _description = '';
  String _category = 'General';

  // Step 2: Agent Configuration (DSPy-specific)
  DspyAgentType _agentType = DspyAgentType.react;
  DspyReasoningPattern _reasoningPattern = DspyReasoningPattern.chainOfThought;
  int _maxIterations = 5;
  int _treeOfThoughtBranches = 3;

  // Step 3: System Prompt
  String _systemPrompt = '';
  String _personality = '';

  // Step 4: Tools & Context
  List<String> _selectedToolIds = [];
  List<String> _contextDocumentIds = [];

  // Step 5: Model Selection
  String _modelProvider = 'anthropic';
  String _modelId = 'claude-sonnet-4-20250514';
  double _temperature = 0.7;
  int _maxTokens = 2048;

  // Validation
  Map<DspyBuilderStep, List<String>> _validationErrors = {};

  // ============ GETTERS ============

  DspyBuilderStep get currentStep => _currentStep;
  bool get isEditing => _isEditing;
  String? get editingAgentId => _editingAgentId;
  int get currentStepIndex => DspyBuilderStep.values.indexOf(_currentStep);
  int get totalSteps => DspyBuilderStep.values.length;

  // Basic Info
  String get name => _name;
  String get description => _description;
  String get category => _category;

  // Agent Config
  DspyAgentType get agentType => _agentType;
  DspyReasoningPattern get reasoningPattern => _reasoningPattern;
  int get maxIterations => _maxIterations;
  int get treeOfThoughtBranches => _treeOfThoughtBranches;

  // System Prompt
  String get systemPrompt => _systemPrompt;
  String get personality => _personality;

  // Tools & Context
  List<String> get selectedToolIds => List.unmodifiable(_selectedToolIds);
  List<String> get contextDocumentIds => List.unmodifiable(_contextDocumentIds);

  // Model
  String get modelProvider => _modelProvider;
  String get modelId => _modelId;
  double get temperature => _temperature;
  int get maxTokens => _maxTokens;

  /// Get the full model string for DSPy (e.g., "anthropic/claude-sonnet-4-20250514")
  String get dspyModelString => '$_modelProvider/$_modelId';

  // Validation
  bool get isStepValid => !_validationErrors.containsKey(_currentStep);
  bool get isConfigurationValid => _validationErrors.isEmpty;
  List<String> getStepErrors(DspyBuilderStep step) => _validationErrors[step] ?? [];

  // ============ SETTERS ============

  void setName(String value) {
    _name = value;
    _validateCurrentStep();
    notifyListeners();
  }

  void setDescription(String value) {
    _description = value;
    notifyListeners();
  }

  void setCategory(String value) {
    _category = value;
    notifyListeners();
  }

  void setAgentType(DspyAgentType type) {
    _agentType = type;
    // Auto-set reasonable defaults based on agent type
    if (type == DspyAgentType.chat) {
      _maxIterations = 1;
    } else if (type == DspyAgentType.react) {
      _maxIterations = 5;
    }
    _validateCurrentStep();
    notifyListeners();
  }

  void setReasoningPattern(DspyReasoningPattern pattern) {
    _reasoningPattern = pattern;
    notifyListeners();
  }

  void setMaxIterations(int value) {
    _maxIterations = value.clamp(1, 10);
    notifyListeners();
  }

  void setTreeOfThoughtBranches(int value) {
    _treeOfThoughtBranches = value.clamp(2, 5);
    notifyListeners();
  }

  void setSystemPrompt(String value) {
    _systemPrompt = value;
    _validateCurrentStep();
    notifyListeners();
  }

  void setPersonality(String value) {
    _personality = value;
    notifyListeners();
  }

  void toggleTool(String toolId) {
    if (_selectedToolIds.contains(toolId)) {
      _selectedToolIds.remove(toolId);
    } else {
      _selectedToolIds.add(toolId);
    }
    notifyListeners();
  }

  void addContextDocument(String documentId) {
    if (!_contextDocumentIds.contains(documentId)) {
      _contextDocumentIds.add(documentId);
      notifyListeners();
    }
  }

  void removeContextDocument(String documentId) {
    _contextDocumentIds.remove(documentId);
    notifyListeners();
  }

  void setModelProvider(String provider) {
    _modelProvider = provider;
    // Reset model ID when provider changes
    _modelId = _getDefaultModelForProvider(provider);
    _validateCurrentStep();
    notifyListeners();
  }

  void setModelId(String modelId) {
    _modelId = modelId;
    _validateCurrentStep();
    notifyListeners();
  }

  void setTemperature(double value) {
    _temperature = value.clamp(0.0, 2.0);
    notifyListeners();
  }

  void setMaxTokens(int value) {
    _maxTokens = value.clamp(256, 8192);
    notifyListeners();
  }

  // ============ NAVIGATION ============

  void setCurrentStep(DspyBuilderStep step) {
    _currentStep = step;
    _validateCurrentStep();
    notifyListeners();
  }

  bool nextStep() {
    _validateCurrentStep();
    if (!isStepValid) return false;

    const steps = DspyBuilderStep.values;
    final currentIndex = steps.indexOf(_currentStep);
    if (currentIndex < steps.length - 1) {
      _currentStep = steps[currentIndex + 1];
      notifyListeners();
      return true;
    }
    return false;
  }

  bool previousStep() {
    const steps = DspyBuilderStep.values;
    final currentIndex = steps.indexOf(_currentStep);
    if (currentIndex > 0) {
      _currentStep = steps[currentIndex - 1];
      notifyListeners();
      return true;
    }
    return false;
  }

  bool get canGoBack => currentStepIndex > 0;
  bool get canGoNext => currentStepIndex < totalSteps - 1 && isStepValid;
  bool get isLastStep => currentStepIndex == totalSteps - 1;

  // ============ TEMPLATES ============

  /// Pre-configured agent templates
  static final Map<String, Map<String, dynamic>> templates = {
    'business_analyst': {
      'name': 'Business Analyst',
      'description': 'Analyzes data and provides business insights',
      'category': 'Business',
      'agentType': DspyAgentType.react,
      'reasoningPattern': DspyReasoningPattern.chainOfThought,
      'maxIterations': 5,
      'tools': ['calculator', 'json_parser'],
      'systemPrompt': 'You are a business analyst expert. Analyze data, identify trends, and provide actionable insights. Use tools to calculate metrics and parse data as needed.',
    },
    'design_assistant': {
      'name': 'Design Assistant',
      'description': 'Helps with design decisions and feedback',
      'category': 'Creative',
      'agentType': DspyAgentType.reasoning,
      'reasoningPattern': DspyReasoningPattern.treeOfThought,
      'maxIterations': 3,
      'treeOfThoughtBranches': 3,
      'tools': [],
      'systemPrompt': 'You are a design expert. Provide thoughtful feedback on design decisions, considering multiple perspectives and approaches. Explore different design alternatives before recommending a solution.',
    },
    'coding_agent': {
      'name': 'Coding Agent',
      'description': 'Writes and debugs code',
      'category': 'Development',
      'agentType': DspyAgentType.react,
      'reasoningPattern': DspyReasoningPattern.chainOfThought,
      'maxIterations': 7,
      'tools': ['code_executor', 'json_parser'],
      'systemPrompt': 'You are an expert programmer. Write clean, efficient code and debug issues systematically. Test your code before providing the final solution.',
    },
    'research_assistant': {
      'name': 'Research Assistant',
      'description': 'Searches and synthesizes information',
      'category': 'Research',
      'agentType': DspyAgentType.rag,
      'reasoningPattern': DspyReasoningPattern.chainOfThought,
      'maxIterations': 3,
      'tools': ['web_search'],
      'systemPrompt': 'You are a research assistant. Find relevant information, synthesize findings, and provide well-sourced answers. Cite your sources when possible.',
    },
  };

  void applyTemplate(String templateId) {
    final template = templates[templateId];
    if (template == null) return;

    _name = template['name'] as String;
    _description = template['description'] as String;
    _category = template['category'] as String;
    _agentType = template['agentType'] as DspyAgentType;
    _reasoningPattern = template['reasoningPattern'] as DspyReasoningPattern;
    _maxIterations = template['maxIterations'] as int;
    if (template.containsKey('treeOfThoughtBranches')) {
      _treeOfThoughtBranches = template['treeOfThoughtBranches'] as int;
    }
    _selectedToolIds = List<String>.from(template['tools'] as List);
    _systemPrompt = template['systemPrompt'] as String;

    _validateAll();
    notifyListeners();
  }

  // ============ EDITING ============

  void startEditing(String agentId, Agent agent) {
    _isEditing = true;
    _editingAgentId = agentId;
    _populateFromAgent(agent);
    notifyListeners();
  }

  void _populateFromAgent(Agent agent) {
    _name = agent.name;
    _description = agent.description;
    _category = agent.capabilities.isNotEmpty ? agent.capabilities.first : 'General';
    // Parse other fields from agent.configuration map
    final config = agent.configuration;
    if (config.containsKey('systemPrompt')) {
      _systemPrompt = config['systemPrompt'] as String? ?? '';
    }
    if (config.containsKey('personality')) {
      _personality = config['personality'] as String? ?? '';
    }
    if (config.containsKey('agentType')) {
      final typeStr = config['agentType'] as String?;
      if (typeStr != null) {
        _agentType = DspyAgentType.values.firstWhere(
          (e) => e.name == typeStr,
          orElse: () => DspyAgentType.react,
        );
      }
    }
    if (config.containsKey('reasoningPattern')) {
      final patternStr = config['reasoningPattern'] as String?;
      if (patternStr != null) {
        _reasoningPattern = DspyReasoningPattern.values.firstWhere(
          (e) => e.name == patternStr,
          orElse: () => DspyReasoningPattern.chainOfThought,
        );
      }
    }
    if (config.containsKey('maxIterations')) {
      _maxIterations = config['maxIterations'] as int? ?? 5;
    }
    if (config.containsKey('temperature')) {
      _temperature = (config['temperature'] as num?)?.toDouble() ?? 0.7;
    }
    if (config.containsKey('maxTokens')) {
      _maxTokens = config['maxTokens'] as int? ?? 2048;
    }
    _validateAll();
  }

  void startNewAgent() {
    _isEditing = false;
    _editingAgentId = null;
    reset();
  }

  // ============ VALIDATION ============

  void _validateCurrentStep() {
    final errors = <String>[];

    switch (_currentStep) {
      case DspyBuilderStep.basicInfo:
        if (_name.trim().isEmpty) {
          errors.add('Agent name is required');
        }
        if (_name.length > 50) {
          errors.add('Name must be 50 characters or less');
        }
        break;

      case DspyBuilderStep.agentConfig:
        // Agent config is always valid (has defaults)
        break;

      case DspyBuilderStep.systemPrompt:
        if (_systemPrompt.trim().isEmpty) {
          errors.add('System prompt is required');
        }
        break;

      case DspyBuilderStep.toolsAndContext:
        // Tools and context are optional
        break;

      case DspyBuilderStep.modelSelection:
        if (_modelId.isEmpty) {
          errors.add('Please select a model');
        }
        break;

      case DspyBuilderStep.review:
        // Review step validates everything
        _validateAll();
        return;
    }

    if (errors.isNotEmpty) {
      _validationErrors[_currentStep] = errors;
    } else {
      _validationErrors.remove(_currentStep);
    }
  }

  void _validateAll() {
    _validationErrors.clear();

    // Basic Info
    if (_name.trim().isEmpty) {
      _validationErrors[DspyBuilderStep.basicInfo] = ['Agent name is required'];
    }

    // System Prompt
    if (_systemPrompt.trim().isEmpty) {
      _validationErrors[DspyBuilderStep.systemPrompt] = ['System prompt is required'];
    }

    // Model
    if (_modelId.isEmpty) {
      _validationErrors[DspyBuilderStep.modelSelection] = ['Please select a model'];
    }
  }

  List<String> getAllValidationErrors() {
    _validateAll();
    final allErrors = <String>[];
    for (final stepErrors in _validationErrors.values) {
      allErrors.addAll(stepErrors);
    }
    return allErrors;
  }

  // ============ CREATE AGENT ============

  /// Convert state to Agent model for persistence
  Agent toAgent() {
    return Agent(
      id: _editingAgentId ?? 'agent_${DateTime.now().millisecondsSinceEpoch}',
      name: _name,
      description: _description,
      capabilities: [_category],
      status: AgentStatus.idle,
      configuration: {
        'systemPrompt': _systemPrompt,
        'model': dspyModelString,
        'temperature': _temperature,
        'agentType': _agentType.name,
        'reasoningPattern': _reasoningPattern.name,
        'maxIterations': _maxIterations,
        'treeOfThoughtBranches': _treeOfThoughtBranches,
        'selectedToolIds': _selectedToolIds,
        'contextDocumentIds': _contextDocumentIds,
        'personality': _personality,
        'maxTokens': _maxTokens,
        'dspyModel': dspyModelString,
        'createdWith': 'dspy_builder',
      },
    );
  }

  /// Convert to DSPy execution request format
  Map<String, dynamic> toDspyExecutionConfig() {
    return {
      'model': dspyModelString,
      'agent_type': _agentType.name,
      'reasoning_pattern': _reasoningPattern.name,
      'max_iterations': _maxIterations,
      'tree_of_thought_branches': _treeOfThoughtBranches,
      'tools': _selectedToolIds,
      'document_ids': _contextDocumentIds,
      'temperature': _temperature,
      'max_tokens': _maxTokens,
      'system_prompt': _systemPrompt,
    };
  }

  // ============ RESET ============

  void reset() {
    _currentStep = DspyBuilderStep.basicInfo;
    _isEditing = false;
    _editingAgentId = null;

    _name = '';
    _description = '';
    _category = 'General';

    _agentType = DspyAgentType.react;
    _reasoningPattern = DspyReasoningPattern.chainOfThought;
    _maxIterations = 5;
    _treeOfThoughtBranches = 3;

    _systemPrompt = '';
    _personality = '';

    _selectedToolIds = [];
    _contextDocumentIds = [];

    _modelProvider = 'anthropic';
    _modelId = 'claude-sonnet-4-20250514';
    _temperature = 0.7;
    _maxTokens = 2048;

    _validationErrors = {};

    notifyListeners();
  }

  // ============ HELPERS ============

  String _getDefaultModelForProvider(String provider) {
    switch (provider) {
      case 'anthropic':
        return 'claude-sonnet-4-20250514';
      case 'openai':
        return 'gpt-4o';
      case 'google':
        return 'gemini-1.5-pro';
      case 'local':
        return 'gemma3:4b';
      default:
        return 'gpt-4o';
    }
  }

  /// Get step title for display
  static String getStepTitle(DspyBuilderStep step) {
    switch (step) {
      case DspyBuilderStep.basicInfo:
        return 'Basic Info';
      case DspyBuilderStep.agentConfig:
        return 'Agent Configuration';
      case DspyBuilderStep.systemPrompt:
        return 'System Prompt';
      case DspyBuilderStep.toolsAndContext:
        return 'Tools & Context';
      case DspyBuilderStep.modelSelection:
        return 'Model Selection';
      case DspyBuilderStep.review:
        return 'Review & Create';
    }
  }

  /// Get step subtitle for display
  static String getStepSubtitle(DspyBuilderStep step) {
    switch (step) {
      case DspyBuilderStep.basicInfo:
        return 'Name and describe your agent';
      case DspyBuilderStep.agentConfig:
        return 'Choose reasoning type and iterations';
      case DspyBuilderStep.systemPrompt:
        return 'Define agent behavior and personality';
      case DspyBuilderStep.toolsAndContext:
        return 'Select tools and knowledge sources';
      case DspyBuilderStep.modelSelection:
        return 'Choose the AI model to power your agent';
      case DspyBuilderStep.review:
        return 'Review settings before creating';
    }
  }
}

import 'package:flutter/foundation.dart';
import 'package:agent_engine_core/models/agent.dart';
import '../../../core/models/mcp_catalog_entry.dart';
import '../../../core/models/agent_template.dart';
import '../../../core/services/agent_model_recommendation_service.dart';

/// Enumeration for different builder modes
enum AgentBuilderMode {
  wizard,     // Step-by-step guided flow
  template,   // Starting from a template
}

/// Enumeration for builder steps in wizard mode
enum AgentBuilderStep {
  basicInfo,      // Name, description, category
  masterPrompt,   // Advanced prompt configuration
  tools,          // MCP server selection
  context,        // Knowledge/context documents
  modelConfig,    // Model settings
  reasoningFlows, // Visual reasoning workflows
  testing,        // Live testing
  review,         // Final review before creation
}

/// Central state model for the dynamic agent builder
class AgentBuilderState extends ChangeNotifier {
  // Builder configuration
  AgentBuilderMode _mode = AgentBuilderMode.wizard;
  AgentBuilderStep _currentStep = AgentBuilderStep.basicInfo;
  bool _isEditing = false;
  String? _editingAgentId;

  // Basic Information
  String _name = '';
  String _description = '';
  String _category = 'Research';
  List<String> _capabilities = [];

  // Master Prompt Configuration
  String _systemPrompt = '';
  String _personality = 'Professional and helpful';
  String _tone = 'Friendly and approachable';
  String _expertise = 'General knowledge';
  final Map<String, String> _promptTemplates = {};
  bool _useAdvancedPrompt = false;

  // Tool Selection
  List<MCPCatalogEntry> _recommendedTools = [];
  List<String> _selectedToolIds = [];
  List<MCPCatalogEntry> _selectedTools = [];
  Map<String, Map<String, String>> _toolConfigurations = {};

  // Context/Knowledge
  List<String> _contextDocuments = [];
  List<String> _knowledgeFiles = [];
  final Map<String, dynamic> _contextSettings = {};

  // Model Configuration
  String _modelProvider = 'OpenAI';
  String _modelName = 'gpt-4o';
  String _performanceTier = 'Balanced';
  String _selectedModel = 'gemma3:4b';
  double _temperature = 0.7;
  double _topP = 1.0;
  int _maxTokens = 2048;
  bool _enableMemory = true;
  bool _enableWebSearch = false;
  bool _enableCodeExecution = false;

  // Enhanced Model Configuration
  AgentTemplate? _appliedTemplate;
  AgentModelConfiguration? _modelConfiguration;
  String _modelSelectionMode = 'template';
  List<String> _selectedCapabilities = [];

  // Reasoning Flows
  List<String> _reasoningWorkflowIds = [];
  String? _defaultReasoningWorkflowId;
  bool _enableReasoningFlows = false;

  // Testing
  List<Map<String, String>> _testConversations = [];
  bool _isTestingMode = false;

  // Validation
  Map<AgentBuilderStep, List<String>> _validationErrors = {};
  bool _hasUnsavedChanges = false;

  // Getters
  AgentBuilderMode get mode => _mode;
  AgentBuilderStep get currentStep => _currentStep;
  bool get isEditing => _isEditing;
  String? get editingAgentId => _editingAgentId;

  String get name => _name;
  String get description => _description;
  String get category => _category;
  List<String> get capabilities => List.unmodifiable(_capabilities);

  String get systemPrompt => _systemPrompt;
  String get personality => _personality;
  String get tone => _tone;
  String get expertise => _expertise;
  Map<String, String> get promptTemplates => Map.unmodifiable(_promptTemplates);
  bool get useAdvancedPrompt => _useAdvancedPrompt;

  List<MCPCatalogEntry> get recommendedTools => List.unmodifiable(_recommendedTools);
  List<String> get selectedToolIds => List.unmodifiable(_selectedToolIds);
  List<MCPCatalogEntry> get selectedTools => List.unmodifiable(_selectedTools);
  Map<String, Map<String, String>> get toolConfigurations => Map.unmodifiable(_toolConfigurations);

  List<String> get contextDocuments => List.unmodifiable(_contextDocuments);
  List<String> get knowledgeFiles => List.unmodifiable(_knowledgeFiles);
  Map<String, dynamic> get contextSettings => Map.unmodifiable(_contextSettings);

  String get modelProvider => _modelProvider;
  String get modelName => _modelName;
  String get performanceTier => _performanceTier;
  String get selectedModel => _selectedModel;
  String? get selectedModelId => _selectedModel;
  double get temperature => _temperature;
  double get topP => _topP;
  int get maxTokens => _maxTokens;
  bool get enableMemory => _enableMemory;
  bool get enableWebSearch => _enableWebSearch;
  bool get enableCodeExecution => _enableCodeExecution;

  // Enhanced Model Configuration Getters
  AgentTemplate? get appliedTemplate => _appliedTemplate;
  AgentModelConfiguration? get modelConfiguration => _modelConfiguration;
  String get modelSelectionMode => _modelSelectionMode;
  List<String> get selectedCapabilities => List.unmodifiable(_selectedCapabilities);
  bool get isMultiModelAgent => _modelConfiguration?.isMultiModel ?? false;
  int get configuredModelCount => _modelConfiguration?.modelCount ?? 1;

  List<String> get reasoningWorkflowIds => List.unmodifiable(_reasoningWorkflowIds);
  String? get defaultReasoningWorkflowId => _defaultReasoningWorkflowId;
  bool get enableReasoningFlows => _enableReasoningFlows;

  List<Map<String, String>> get testConversations => List.unmodifiable(_testConversations);
  bool get isTestingMode => _isTestingMode;

  Map<AgentBuilderStep, List<String>> get validationErrors => Map.unmodifiable(_validationErrors);
  bool get hasUnsavedChanges => _hasUnsavedChanges;

  // State Management
  void setMode(AgentBuilderMode mode) {
    _mode = mode;
    notifyListeners();
  }

  void setCurrentStep(AgentBuilderStep step) {
    _currentStep = step;
    _runValidation();
    notifyListeners();
  }

  void nextStep() {
    const steps = AgentBuilderStep.values;
    final currentIndex = steps.indexOf(_currentStep);
    if (currentIndex < steps.length - 1) {
      _currentStep = steps[currentIndex + 1];
      _runValidation();
      notifyListeners();
    }
  }

  void previousStep() {
    const steps = AgentBuilderStep.values;
    final currentIndex = steps.indexOf(_currentStep);
    if (currentIndex > 0) {
      _currentStep = steps[currentIndex - 1];
      _runValidation();
      notifyListeners();
    }
  }

  /// Internal validation helper that doesn't notify listeners
  void _runValidation() {
    _validateStepSilent(AgentBuilderStep.basicInfo);
    _validateStepSilent(AgentBuilderStep.masterPrompt);
    _validateStepSilent(AgentBuilderStep.modelConfig);
  }

  /// Validate step without calling notifyListeners
  void _validateStepSilent(AgentBuilderStep step) {
    final errors = <String>[];

    switch (step) {
      case AgentBuilderStep.basicInfo:
        if (_name.trim().isEmpty) {
          errors.add('Agent name is required');
        }
        break;
      case AgentBuilderStep.masterPrompt:
        if (_systemPrompt.trim().isEmpty) {
          errors.add('Master prompt is required');
        }
        break;
      case AgentBuilderStep.modelConfig:
        if (_selectedModel.isEmpty) {
          errors.add('Please select a model');
        }
        break;
      default:
        break;
    }

    if (errors.isNotEmpty) {
      _validationErrors[step] = errors;
    } else {
      _validationErrors.remove(step);
    }
  }

  void startEditing(String agentId, Agent agent) {
    _isEditing = true;
    _editingAgentId = agentId;
    _populateFromAgent(agent);
    notifyListeners();
  }

  void startNewAgent() {
    _isEditing = false;
    _editingAgentId = null;
    _reset();
    notifyListeners();
  }

  // Basic Information Updates
  void updateName(String name) {
    _name = name;
    _markDirty();
    _validateStep(AgentBuilderStep.basicInfo);
  }

  void updateDescription(String description) {
    _description = description;
    _markDirty();
    _validateStep(AgentBuilderStep.basicInfo);
  }

  void updateCategory(String category) {
    _category = category;
    _markDirty();
    _validateStep(AgentBuilderStep.basicInfo);
    notifyListeners(); // Notify for category change to update recommendations
  }

  void updateCapabilities(List<String> capabilities) {
    _capabilities = List.from(capabilities);
    _markDirty();
  }

  // Master Prompt Updates
  void updateSystemPrompt(String prompt) {
    _systemPrompt = prompt;
    _markDirty();
    _validateStep(AgentBuilderStep.masterPrompt);
  }

  void updatePersonality(String personality) {
    _personality = personality;
    _markDirty();
    _regenerateSystemPrompt();
  }

  void updateTone(String tone) {
    _tone = tone;
    _markDirty();
    _regenerateSystemPrompt();
  }

  void updateExpertise(String expertise) {
    _expertise = expertise;
    _markDirty();
    _regenerateSystemPrompt();
  }

  void setUseAdvancedPrompt(bool useAdvanced) {
    _useAdvancedPrompt = useAdvanced;
    _markDirty();
    if (!useAdvanced) {
      _regenerateSystemPrompt();
    }
  }

  // Tool Selection Updates
  void updateRecommendedTools(List<MCPCatalogEntry> tools) {
    _recommendedTools = List.from(tools);
    notifyListeners();
  }

  void toggleTool(String toolId) {
    if (_selectedToolIds.contains(toolId)) {
      _selectedToolIds.remove(toolId);
      _selectedTools.removeWhere((tool) => tool.id == toolId);
      _toolConfigurations.remove(toolId);
    } else {
      _selectedToolIds.add(toolId);
      // Try to find the tool in recommended tools to add to selected tools
      MCPCatalogEntry? tool;
      try {
        tool = _recommendedTools.firstWhere(
          (t) => t.id == toolId,
        );
      } catch (e) {
        tool = null;
      }
      if (tool != null) {
        _selectedTools.add(tool);
      }
    }
    _markDirty();
    _validateStep(AgentBuilderStep.tools);
  }

  void toggleToolWithEntry(MCPCatalogEntry tool) {
    if (_selectedToolIds.contains(tool.id)) {
      _selectedToolIds.remove(tool.id);
      _selectedTools.removeWhere((t) => t.id == tool.id);
      _toolConfigurations.remove(tool.id);
    } else {
      _selectedToolIds.add(tool.id);
      if (!_selectedTools.any((t) => t.id == tool.id)) {
        _selectedTools.add(tool);
      }
    }
    _markDirty();
    _validateStep(AgentBuilderStep.tools);
  }

  void updateToolConfiguration(String toolId, Map<String, String> config) {
    _toolConfigurations[toolId] = Map.from(config);
    _markDirty();
  }

  // Context Updates
  void addContextDocument(String documentPath) {
    if (!_contextDocuments.contains(documentPath)) {
      _contextDocuments.add(documentPath);
      _markDirty();
    }
  }

  void removeContextDocument(String documentPath) {
    _contextDocuments.remove(documentPath);
    _markDirty();
  }

  void addKnowledgeFile(String filePath) {
    if (!_knowledgeFiles.contains(filePath)) {
      _knowledgeFiles.add(filePath);
      _markDirty();
    }
  }

  void removeKnowledgeFile(String filePath) {
    _knowledgeFiles.remove(filePath);
    _markDirty();
  }

  // Model Configuration Updates
  void updateSelectedModel(String model) {
    _selectedModel = model;
    _markDirty();
    _validateStep(AgentBuilderStep.modelConfig);
  }

  void updateModelProvider(String provider) {
    _modelProvider = provider;
    _markDirty();
    _validateStep(AgentBuilderStep.modelConfig);
  }

  void updateModelName(String model) {
    _modelName = model;
    _markDirty();
    _validateStep(AgentBuilderStep.modelConfig);
  }

  void updatePerformanceTier(String tier) {
    _performanceTier = tier;
    _markDirty();
    _validateStep(AgentBuilderStep.modelConfig);
  }

  void updateTemperature(double temperature) {
    _temperature = temperature;
    _markDirty();
  }

  void updateTopP(double topP) {
    _topP = topP;
    _markDirty();
  }

  void updateMaxTokens(int maxTokens) {
    _maxTokens = maxTokens;
    _markDirty();
  }

  void updateEnableMemory(bool enable) {
    _enableMemory = enable;
    _markDirty();
  }

  void updateEnableWebSearch(bool enable) {
    _enableWebSearch = enable;
    _markDirty();
  }

  void updateEnableCodeExecution(bool enable) {
    _enableCodeExecution = enable;
    _markDirty();
  }

  // Reasoning Flows Updates
  void updateEnableReasoningFlows(bool enable) {
    _enableReasoningFlows = enable;
    _markDirty();
    _validateStep(AgentBuilderStep.reasoningFlows);
  }

  void addReasoningWorkflow(String workflowId) {
    if (!_reasoningWorkflowIds.contains(workflowId)) {
      _reasoningWorkflowIds.add(workflowId);
      _markDirty();
      _validateStep(AgentBuilderStep.reasoningFlows);
    }
  }

  void removeReasoningWorkflow(String workflowId) {
    _reasoningWorkflowIds.remove(workflowId);
    if (_defaultReasoningWorkflowId == workflowId) {
      _defaultReasoningWorkflowId = null;
    }
    _markDirty();
    _validateStep(AgentBuilderStep.reasoningFlows);
  }

  void setDefaultReasoningWorkflow(String? workflowId) {
    _defaultReasoningWorkflowId = workflowId;
    if (workflowId != null && !_reasoningWorkflowIds.contains(workflowId)) {
      _reasoningWorkflowIds.add(workflowId);
    }
    _markDirty();
  }

  // Testing
  void enterTestingMode() {
    _isTestingMode = true;
    notifyListeners();
  }

  void exitTestingMode() {
    _isTestingMode = false;
    notifyListeners();
  }

  void addTestConversation(String message, String response) {
    _testConversations.add({
      'message': message,
      'response': response,
      'timestamp': DateTime.now().toIso8601String(),
    });
    notifyListeners();
  }

  void clearTestConversations() {
    _testConversations.clear();
    notifyListeners();
  }

  // Validation
  void _validateStep(AgentBuilderStep step) {
    final errors = <String>[];

    switch (step) {
      case AgentBuilderStep.basicInfo:
        if (_name.trim().isEmpty) errors.add('Name is required');
        if (_description.trim().isEmpty) errors.add('Description is required');
        if (_category.trim().isEmpty) errors.add('Category is required');
        break;
      case AgentBuilderStep.masterPrompt:
        if (_useAdvancedPrompt && _systemPrompt.trim().isEmpty) {
          errors.add('System prompt is required when using advanced mode');
        }
        break;
      case AgentBuilderStep.tools:
        // Tools are optional, but we could add minimum requirements
        break;
      case AgentBuilderStep.context:
        // Context is optional
        break;
      case AgentBuilderStep.reasoningFlows:
        if (_enableReasoningFlows && _reasoningWorkflowIds.isEmpty) {
          errors.add('At least one reasoning workflow is required when reasoning flows are enabled');
        }
        break;
      case AgentBuilderStep.modelConfig:
        if (!isEnhancedConfigurationValid()) {
          errors.add('Model configuration is required');
        }
        if (_selectedModel.trim().isEmpty) errors.add('Model selection is required');
        if (_temperature < 0 || _temperature > 2) errors.add('Temperature must be between 0 and 2');
        if (_maxTokens < 1) errors.add('Max tokens must be greater than 0');
        break;
      case AgentBuilderStep.testing:
      case AgentBuilderStep.review:
        // No specific validation for these steps
        break;
    }

    if (errors.isNotEmpty) {
      _validationErrors[step] = errors;
    } else {
      _validationErrors.remove(step);
    }
    notifyListeners();
  }

  bool isStepValid(AgentBuilderStep step) {
    return !_validationErrors.containsKey(step);
  }

  List<String> getAllValidationErrors() {
    final allErrors = <String>[];
    for (final stepErrors in _validationErrors.values) {
      allErrors.addAll(stepErrors);
    }
    return allErrors;
  }

  bool get isValid {
    // Check existing validation state without modifying it
    // Use validateAll() to trigger validation before checking
    return _validationErrors.isEmpty;
  }

  bool get isConfigurationValid {
    // Check existing validation state without modifying it
    // Use validateAll() to trigger validation before checking
    return _validationErrors.isEmpty;
  }

  /// Explicitly validate all steps - call this on user actions, not during build
  void validateAll() {
    _runValidation();
    notifyListeners();
  }

  // Agent Creation
  Agent toAgent() {
    return Agent(
      id: _editingAgentId ?? 'agent_${DateTime.now().millisecondsSinceEpoch}',
      name: _name,
      description: _description,
      capabilities: _capabilities.isNotEmpty ? _capabilities : _getCapabilitiesFromCategory(_category),
      status: AgentStatus.idle,
      configuration: {
        'category': _category,
        'modelProvider': _modelProvider,
        'modelName': _modelName,
        'performanceTier': _performanceTier,
        'modelId': _selectedModel,
        'temperature': _temperature,
        'topP': _topP,
        'maxTokens': _maxTokens,
        'enableMemory': _enableMemory,
        'enableWebSearch': _enableWebSearch,
        'enableCodeExecution': _enableCodeExecution,
        'systemPrompt': _generateFinalSystemPrompt(),
        'personality': _personality,
        'tone': _tone,
        'expertise': _expertise,
        'useAdvancedPrompt': _useAdvancedPrompt,
        'selectedTools': _selectedToolIds,
        'toolConfigurations': _toolConfigurations,
        'contextDocuments': _contextDocuments,
        'knowledgeFiles': _knowledgeFiles,
        'enableReasoningFlows': _enableReasoningFlows,
        'reasoningWorkflowIds': _reasoningWorkflowIds,
        'defaultReasoningWorkflowId': _defaultReasoningWorkflowId,
        'createdAt': DateTime.now().toIso8601String(),
        'lastModified': DateTime.now().toIso8601String(),
        'builderVersion': '2.0',
      },
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': _mode.toString(),
      'currentStep': _currentStep.toString(),
      'isEditing': _isEditing,
      'editingAgentId': _editingAgentId,
      'name': _name,
      'description': _description,
      'category': _category,
      'capabilities': _capabilities,
      'systemPrompt': _systemPrompt,
      'personality': _personality,
      'tone': _tone,
      'expertise': _expertise,
      'promptTemplates': _promptTemplates,
      'useAdvancedPrompt': _useAdvancedPrompt,
      'recommendedTools': _recommendedTools.map((tool) => tool.toJson()).toList(),
      'selectedToolIds': _selectedToolIds,
      'selectedTools': _selectedTools.map((tool) => tool.toJson()).toList(),
      'toolConfigurations': _toolConfigurations,
      'contextDocuments': _contextDocuments,
      'knowledgeFiles': _knowledgeFiles,
      'contextSettings': _contextSettings,
      'enableReasoningFlows': _enableReasoningFlows,
      'reasoningWorkflowIds': _reasoningWorkflowIds,
      'defaultReasoningWorkflowId': _defaultReasoningWorkflowId,
      'modelProvider': _modelProvider,
      'modelName': _modelName,
      'performanceTier': _performanceTier,
      'selectedModel': _selectedModel,
      'temperature': _temperature,
      'topP': _topP,
      'maxTokens': _maxTokens,
      'enableMemory': _enableMemory,
      'enableWebSearch': _enableWebSearch,
      'enableCodeExecution': _enableCodeExecution,
      'testConversations': _testConversations,
      'isTestingMode': _isTestingMode,
      'validationErrors': _validationErrors.map((key, value) => MapEntry(key.toString(), value)),
      'hasUnsavedChanges': _hasUnsavedChanges,
    };
  }

  // Private Methods
  void _markDirty() {
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  void _reset() {
    _name = '';
    _description = '';
    _category = 'Research';
    _capabilities = [];
    _systemPrompt = '';
    _personality = 'Professional and helpful';
    _tone = 'Friendly and approachable';
    _expertise = 'General knowledge';
    _useAdvancedPrompt = false;
    _selectedToolIds = [];
    _selectedTools = [];
    _toolConfigurations = {};
    _contextDocuments = [];
    _knowledgeFiles = [];
    _enableReasoningFlows = false;
    _reasoningWorkflowIds = [];
    _defaultReasoningWorkflowId = null;
    _modelProvider = 'OpenAI';
    _modelName = 'gpt-4o';
    _performanceTier = 'Balanced';
    _selectedModel = 'gemma3:4b';
    _temperature = 0.7;
    _topP = 1.0;
    _maxTokens = 2048;
    _enableMemory = true;
    _enableWebSearch = false;
    _enableCodeExecution = false;
    _testConversations = [];
    _isTestingMode = false;
    _validationErrors = {};
    _hasUnsavedChanges = false;
    _currentStep = AgentBuilderStep.basicInfo;
  }

  void _populateFromAgent(Agent agent) {
    _name = agent.name;
    _description = agent.description;
    _capabilities = List.from(agent.capabilities);

    final config = agent.configuration ?? {};
    _category = config['category'] ?? 'Research';
    _modelProvider = config['modelProvider'] ?? 'OpenAI';
    _modelName = config['modelName'] ?? 'gpt-4o';
    _performanceTier = config['performanceTier'] ?? 'Balanced';
    _selectedModel = config['modelId'] ?? 'gemma3:4b';
    _temperature = (config['temperature'] ?? 0.7).toDouble();
    _topP = (config['topP'] ?? 1.0).toDouble();
    _maxTokens = config['maxTokens'] ?? 2048;
    _enableMemory = config['enableMemory'] ?? true;
    _enableWebSearch = config['enableWebSearch'] ?? false;
    _enableCodeExecution = config['enableCodeExecution'] ?? false;
    _systemPrompt = config['systemPrompt'] ?? '';
    _personality = config['personality'] ?? 'Professional and helpful';
    _tone = config['tone'] ?? 'Friendly and approachable';
    _expertise = config['expertise'] ?? 'General knowledge';
    _useAdvancedPrompt = config['useAdvancedPrompt'] ?? false;
    _selectedToolIds = List<String>.from(config['selectedTools'] ?? []);
    _toolConfigurations = Map<String, Map<String, String>>.from(
      config['toolConfigurations'] ?? {}
    );
    _contextDocuments = List<String>.from(config['contextDocuments'] ?? []);
    _knowledgeFiles = List<String>.from(config['knowledgeFiles'] ?? []);
    _enableReasoningFlows = config['enableReasoningFlows'] ?? false;
    _reasoningWorkflowIds = List<String>.from(config['reasoningWorkflowIds'] ?? []);
    _defaultReasoningWorkflowId = config['defaultReasoningWorkflowId'];

    _hasUnsavedChanges = false;
  }

  void _regenerateSystemPrompt() {
    if (!_useAdvancedPrompt) {
      _systemPrompt = _generateFinalSystemPrompt();
      notifyListeners();
    }
  }

  String _generateFinalSystemPrompt() {
    if (_useAdvancedPrompt && _systemPrompt.isNotEmpty) {
      return _systemPrompt;
    }

    // Generate system prompt based on personality, tone, and expertise
    final buffer = StringBuffer();

    buffer.writeln('You are an AI assistant with the following characteristics:');
    buffer.writeln('- Personality: $_personality');
    buffer.writeln('- Communication tone: $_tone');
    buffer.writeln('- Area of expertise: $_expertise');
    buffer.writeln('- Category specialization: $_category');

    if (_description.isNotEmpty) {
      buffer.writeln('\nYour role: $_description');
    }

    if (_capabilities.isNotEmpty) {
      buffer.writeln('\nYour key capabilities include:');
      for (final capability in _capabilities) {
        buffer.writeln('- $capability');
      }
    }

    if (_selectedToolIds.isNotEmpty) {
      buffer.writeln('\nYou have access to the following tools: ${_selectedToolIds.join(', ')}');
    }

    buffer.writeln('\nAlways maintain your specified personality and tone while helping users achieve their goals.');

    return buffer.toString();
  }

  List<String> _getCapabilitiesFromCategory(String category) {
    switch (category) {
      case 'Research': return ['research', 'analysis', 'citation', 'fact-checking'];
      case 'Development': return ['coding', 'debugging', 'code-review', 'testing'];
      case 'Data Analysis': return ['data-analysis', 'statistics', 'reporting', 'visualization'];
      case 'Writing': return ['content-creation', 'editing', 'proofreading', 'seo'];
      case 'Automation': return ['automation', 'scripting', 'workflow-management'];
      case 'DevOps': return ['infrastructure', 'deployment', 'monitoring', 'ci-cd'];
      default: return ['general-assistance', 'problem-solving'];
    }
  }

  void markSaved() {
    _hasUnsavedChanges = false;
    notifyListeners();
  }

  // Simple setter methods for enhanced model configuration
  void setName(String name) {
    updateName(name);
  }

  void setDescription(String description) {
    updateDescription(description);
  }

  void setCategory(String category) {
    updateCategory(category);
  }

  void setSystemPrompt(String prompt) {
    updateSystemPrompt(prompt);
  }

  // Enhanced Model Configuration Methods

  /// Apply a template to the builder state
  void applyTemplate(AgentTemplate template) {
    _appliedTemplate = template;
    _modelConfiguration = null; // Clear any custom configuration
    _modelSelectionMode = 'template';
    
    // Apply template settings to existing fields
    setName(template.name);
    setDescription(template.description);
    setCategory(template.category);
    setSystemPrompt(template.systemPrompt);
    _selectedCapabilities = List.from(template.capabilities);
    
    // Set the primary model as the selected model for backward compatibility
    final primaryModel = template.recommendedModels?[template.primaryCapability];
    if (primaryModel != null) {
      setSelectedModelId(primaryModel);
    }
    
    _hasUnsavedChanges = true;
    notifyListeners();
  }
  
  /// Set custom model configuration
  void setModelConfiguration(AgentModelConfiguration config) {
    _modelConfiguration = config;
    _appliedTemplate = null; // Clear any template
    _modelSelectionMode = 'custom';
    _selectedCapabilities = List.from(config.capabilities);
    
    // Set the primary model as the selected model for backward compatibility
    setSelectedModelId(config.primaryModelId);
    
    _hasUnsavedChanges = true;
    notifyListeners();
  }
  
  /// Set selected model ID
  void setSelectedModelId(String modelId) {
    _selectedModel = modelId;
    _hasUnsavedChanges = true;
    notifyListeners();
  }
  
  /// Set model selection mode
  void setModelSelectionMode(String mode) {
    _modelSelectionMode = mode;
    
    // Clear configurations when switching modes
    if (mode != 'template') {
      _appliedTemplate = null;
    }
    if (mode != 'custom') {
      _modelConfiguration = null;
    }
    
    _hasUnsavedChanges = true;
    notifyListeners();
  }
  
  /// Set selected capabilities
  void setSelectedCapabilities(List<String> capabilities) {
    _selectedCapabilities = List.from(capabilities);
    _hasUnsavedChanges = true;
    notifyListeners();
  }
  
  /// Get the model ID for a specific capability
  String? getModelForCapability(String capability) {
    if (_modelConfiguration != null) {
      return _modelConfiguration!.getModelForCapability(capability);
    }
    if (_appliedTemplate != null) {
      return _appliedTemplate!.recommendedModels?[capability];
    }
    return selectedModel; // Fallback to single model
  }
  
  /// Build the final agent configuration including enhanced model settings
  Map<String, dynamic> buildEnhancedAgentConfiguration() {
    final baseConfig = {
      'modelId': selectedModel,
      'temperature': temperature,
      'maxTokens': maxTokens,
      'enableMemory': enableMemory,
      'enableWebSearch': enableWebSearch,
      'enableCodeExecution': enableCodeExecution,
      'mcpServers': selectedToolIds,
      'contextDocuments': contextDocuments,
      'reasoningWorkflows': reasoningWorkflowIds,
    };
    
    // Add enhanced configuration
    if (_appliedTemplate != null) {
      baseConfig.addAll(_appliedTemplate!.toAgentConfiguration().cast<String, Object>());
    } else if (_modelConfiguration != null) {
      baseConfig['modelConfiguration'] = {
        'primaryModelId': _modelConfiguration!.primaryModelId,
        'specializedModels': _modelConfiguration!.specializedModels,
        'capabilities': _modelConfiguration!.capabilities,
        'recommendations': _modelConfiguration!.recommendations,
      };
      baseConfig['type'] = 'multi_model_agent';
      baseConfig['capabilities'] = _selectedCapabilities;
    } else {
      // Simple single model configuration
      baseConfig['type'] = 'single_model_agent';
      baseConfig['capabilities'] = _selectedCapabilities;
    }
    
    return baseConfig;
  }
  
  /// Validate enhanced configuration
  bool isEnhancedConfigurationValid() {
    switch (_modelSelectionMode) {
      case 'template':
        return _appliedTemplate != null;
      case 'custom':
        return _modelConfiguration != null && _selectedCapabilities.isNotEmpty;
      case 'simple':
        return selectedModel.isNotEmpty;
      default:
        return false;
    }
  }
  
  /// Get display information for the current configuration
  String getConfigurationSummary() {
    if (_appliedTemplate != null) {
      final modelCount = _appliedTemplate!.isMultiModel
          ? (_appliedTemplate!.recommendedModels?.length ?? 0)
          : 1;
      return '${_appliedTemplate!.name} template with $modelCount model${modelCount > 1 ? 's' : ''}';
    } else if (_modelConfiguration != null) {
      return 'Custom configuration with ${_modelConfiguration!.modelCount} model${_modelConfiguration!.modelCount > 1 ? 's' : ''}';
    } else {
      return 'Single model: $selectedModel';
    }
  }
}
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/model_config.dart';
import 'api_config_service.dart';
import 'ollama_service.dart';
import 'desktop/desktop_storage_service.dart';
import 'desktop/desktop_service_provider.dart';

/// Extended service for managing both API and local model configurations
class ModelConfigService extends ApiConfigService {
  final OllamaService _ollamaService;
  final DesktopStorageService _storageService;
  final Map<String, ModelConfig> _localModels = {};
  final Map<String, ModelConfig> _availableModels = {};
  bool _isInitialized = false;

  ModelConfigService(
    this._storageService, 
    this._ollamaService,
  ) : super(_storageService);

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    print('DEBUG: ModelConfigService.initialize() called');
    
    // Initialize base API config service
    await super.initialize();
    
    // Load local models and available models
    await _loadLocalModels();
    await _loadAvailableModels();
    
    // Initialize Ollama service
    try {
      print('DEBUG: Initializing Ollama service...');
      await _ollamaService.initialize();
      print('DEBUG: Ollama service initialized, calling sync...');
      await _syncWithOllama();
      print('DEBUG: Ollama sync completed');
    } catch (e) {
      print('Failed to initialize Ollama service: $e');
      // Continue without local models
    }
    
    _isInitialized = true;
    print('DEBUG: ModelConfigService initialization complete');
  }

  /// Migrate existing ApiConfigs to ModelConfigs
  Future<void> migrateFromApiConfigs() async {
    final apiConfigs = super.allApiConfigs;
    
    for (final entry in apiConfigs.entries) {
      // Convert ApiConfig to ModelConfig
      final modelConfig = ModelConfig.fromApiConfig(entry.value);
      
      // Update the base config with the converted model
      await super.setApiConfig(entry.key, modelConfig);
    }
  }

  /// Get all model configurations (API + local)
  Map<String, ModelConfig> get allModelConfigs {
    final allConfigs = <String, ModelConfig>{};
    
    // Add API models (converted to ModelConfig)
    for (final entry in super.allApiConfigs.entries) {
      if (entry.value is ModelConfig) {
        allConfigs[entry.key] = entry.value as ModelConfig;
      } else {
        // Convert ApiConfig to ModelConfig on the fly
        allConfigs[entry.key] = ModelConfig.fromApiConfig(entry.value);
      }
    }
    
    // Add local models
    allConfigs.addAll(_localModels);
    
    return allConfigs;
  }

  /// Get only API model configurations
  Map<String, ModelConfig> get apiModelConfigs {
    return Map.fromEntries(
      allModelConfigs.entries.where((entry) => entry.value.isApi),
    );
  }

  /// Get only local model configurations
  Map<String, ModelConfig> get localModelConfigs {
    return Map.fromEntries(
      allModelConfigs.entries.where((entry) => entry.value.isLocal),
    );
  }

  /// Get available models for download
  Map<String, ModelConfig> get availableModelConfigs => Map.from(_availableModels);

  /// Get default model configuration
  ModelConfig? get defaultModelConfig {
    // First check if there's a default local model set
    final defaultLocalId = _storageService.getPreference<String>('default_local_model');
    if (defaultLocalId != null) {
      final localModel = getModelConfig(defaultLocalId);
      if (localModel != null && localModel.isConfigured) {
        return localModel;
      }
    }
    
    // Second priority: any ready local model (prefer local over API)
    final readyLocalModels = localModelConfigs.values
        .where((model) => model.status == ModelStatus.ready)
        .toList();
    if (readyLocalModels.isNotEmpty) {
      print('🤖 Auto-selecting local model: ${readyLocalModels.first.name}');
      return readyLocalModels.first;
    }
    
    // Last resort: API default (only if no local models available)
    final defaultId = super.defaultApiConfigId;
    if (defaultId != null) {
      return getModelConfig(defaultId);
    }
    
    return null;
  }

  /// Get model configuration by ID
  ModelConfig? getModelConfig(String id) {
    return allModelConfigs[id];
  }

  /// Add or update a local model configuration
  Future<void> addLocalModel(ModelConfig model) async {
    if (!model.isLocal) {
      throw ArgumentError('Only local models can be added via addLocalModel');
    }
    
    _localModels[model.id] = model;
    await _saveLocalModels();
  }

  /// Remove a local model configuration
  Future<void> removeLocalModel(String modelId) async {
    final model = _localModels[modelId];
    if (model == null) return;
    
    // Remove from Ollama if installed
    if (model.status == ModelStatus.ready && model.ollamaModelId != null) {
      try {
        await _ollamaService.removeModel(model.ollamaModelId!);
      } catch (e) {
        print('Failed to remove model from Ollama: $e');
      }
    }
    
    _localModels.remove(modelId);
    await _saveLocalModels();
  }

  /// Download a local model
  Future<void> downloadModel(
    String modelId, {
    Function(double)? onProgress,
  }) async {
    final model = _availableModels[modelId] ?? _localModels[modelId];
    if (model == null || model.downloadUrl == null) {
      throw ArgumentError('Model not found or no download URL: $modelId');
    }

    // Update status to downloading
    final downloadingModel = model.copyWith(
      status: ModelStatus.downloading,
      downloadProgress: 0.0,
    );
    _localModels[modelId] = downloadingModel;
    await _saveLocalModels();

    try {
      // Download via Ollama
      await _ollamaService.downloadModel(
        model.downloadUrl!,
        onProgress: (progress) {
          // Update progress
          final progressModel = downloadingModel.copyWith(
            downloadProgress: progress,
          );
          _localModels[modelId] = progressModel;
          onProgress?.call(progress);
        },
      );

      // Update status to ready
      final readyModel = downloadingModel.copyWith(
        status: ModelStatus.ready,
        downloadProgress: 1.0,
      );
      _localModels[modelId] = readyModel;
      await _saveLocalModels();
      
    } catch (e) {
      // Update status to error
      final errorModel = downloadingModel.copyWith(
        status: ModelStatus.error,
        downloadProgress: null,
      );
      _localModels[modelId] = errorModel;
      await _saveLocalModels();
      rethrow;
    }
  }

  /// Set default model configuration
  Future<void> setDefaultModel(String modelId) async {
    final model = getModelConfig(modelId);
    if (model == null) {
      throw ArgumentError('Model not found: $modelId');
    }

    if (model.isApi) {
      // Use existing API config logic
      await super.setDefaultApiConfig(modelId);
    } else {
      // For local models, we need to handle this differently
      // Since ApiConfigService doesn't know about local models,
      // we'll store the default local model ID separately
      await _storageService.setPreference('default_local_model', modelId);
    }
  }

  /// Get recommended model for a given task type
  ModelConfig? getRecommendedModel(String taskType) {
    final allConfigs = allModelConfigs.values.where((m) => m.isConfigured);
    
    switch (taskType.toLowerCase()) {
      case 'reasoning':
      case 'math':
        // Prefer QwQ for reasoning tasks
        return allConfigs
            .where((m) => m.capabilities.contains('reasoning') || m.capabilities.contains('thinking'))
            .firstOrNull;
      
      case 'code':
      case 'programming':
        // Prefer API models for complex coding, local coder models for simple tasks
        final apiCodeModels = allConfigs.where((m) => m.isApi && m.isConfigured);
        if (apiCodeModels.isNotEmpty) {
          return apiCodeModels.first;
        }
        return allConfigs.where((m) => m.capabilities.contains('code')).firstOrNull;
      
      case 'chat':
      case 'general':
      default:
        // Prefer local models for general chat
        final localModels = allConfigs.where((m) => m.isLocal && m.status == ModelStatus.ready);
        if (localModels.isNotEmpty) {
          return localModels.first;
        }
        // Fallback to API models
        return allConfigs.where((m) => m.isApi && m.isConfigured).firstOrNull;
    }
  }

  /// Sync local models with Ollama installation
  Future<void> _syncWithOllama() async {
    try {
      final installedModels = await _ollamaService.getInstalledModels();
      print('DEBUG: Ollama installed models: ${installedModels.map((m) => '${m.name} (${m.ollamaModelId})').join(', ')}');

      // Build set of Ollama model IDs for quick lookup
      final installedOllamaIds = installedModels
          .map((m) => m.ollamaModelId)
          .toSet();

      // Remove local models that are no longer in Ollama
      final modelsToRemove = <String>[];
      for (final entry in _localModels.entries) {
        final model = entry.value;
        if (model.isLocal &&
            model.ollamaModelId != null &&
            !installedOllamaIds.contains(model.ollamaModelId)) {
          print('DEBUG: Removing deleted model ${model.name} (${model.ollamaModelId})');
          modelsToRemove.add(entry.key);
        }
      }

      // Remove deleted models
      for (final modelId in modelsToRemove) {
        _localModels.remove(modelId);
      }

      // Update existing models or add new ones
      for (final installedModel in installedModels) {
        // Update existing local model or add new one
        final existingModel = _localModels.values
            .where((m) => m.ollamaModelId == installedModel.ollamaModelId)
            .firstOrNull;

        if (existingModel != null) {
          // Update status to ready
          print('DEBUG: Updating existing model ${existingModel.name} to ready');
          _localModels[existingModel.id] = existingModel.copyWith(
            status: ModelStatus.ready,
            modelSize: installedModel.modelSize,
          );
        } else {
          // Add newly discovered model
          print('DEBUG: Adding new discovered model ${installedModel.name}');
          _localModels[installedModel.id] = installedModel;
        }
      }

      print('DEBUG: Ollama sync completed');
      await _saveLocalModels();
    } catch (e) {
      print('Failed to sync with Ollama: $e');
    }
  }

  /// Load local models from storage
  Future<void> _loadLocalModels() async {
    try {
      final data = _storageService.getPreference<String>('local_models');
      if (data != null) {
        final Map<String, dynamic> modelsJson = json.decode(data);
        
        for (final entry in modelsJson.entries) {
          try {
            _localModels[entry.key] = ModelConfig.fromJson(entry.value);
          } catch (e) {
            print('Failed to parse local model ${entry.key}: $e');
          }
        }
      }
    } catch (e) {
      print('Failed to load local models: $e');
    }
  }

  /// Save local models to storage
  Future<void> _saveLocalModels() async {
    try {
      final Map<String, dynamic> modelsJson = {};
      
      for (final entry in _localModels.entries) {
        modelsJson[entry.key] = entry.value.toJson();
      }
      
      await _storageService.setPreference('local_models', json.encode(modelsJson));
    } catch (e) {
      print('Failed to save local models: $e');
    }
  }

  /// Load available models for download
  Future<void> _loadAvailableModels() async {
    final availableModels = _ollamaService.getAvailableModels();
    
    for (final model in availableModels) {
      _availableModels[model.id] = model;
    }
  }

  /// Check if a model is currently being downloaded
  bool isModelDownloading(String modelId) {
    final model = _localModels[modelId];
    return model?.status == ModelStatus.downloading;
  }

  /// Get download progress for a model
  double? getDownloadProgress(String modelId) {
    final model = _localModels[modelId];
    return model?.downloadProgress;
  }

  /// Get models by capability
  List<ModelConfig> getModelsByCapability(String capability) {
    return allModelConfigs.values
        .where((model) => model.capabilities.contains(capability))
        .toList();
  }

  /// Get ready models (configured API models or downloaded local models)
  List<ModelConfig> getReadyModels() {
    return allModelConfigs.values
        .where((model) => model.isConfigured)
        .toList();
  }

  /// Reset all configurations to defaults (removes hardcoded entries)
  @override
  Future<void> resetToDefaults() async {
    await super.resetToDefaults();
    _localModels.clear();
    await _saveLocalModels();
    print('✅ All model configurations reset to defaults');
  }
}

// Extension to add firstOrNull helper
extension IterableExtension<T> on Iterable<T> {
  T? get firstOrNull {
    if (isEmpty) return null;
    return first;
  }
}

// Riverpod provider for model config service
final modelConfigServiceProvider = Provider<ModelConfigService>((ref) {
  final storageService = ref.read(desktopStorageServiceProvider);
  final ollamaService = ref.read(ollamaServiceProvider);
  final service = ModelConfigService(storageService, ollamaService);
  
  // Initialize the service
  service.initialize().catchError((e) {
    print('Failed to initialize model config service: $e');
  });
  
  return service;
});

// State notifier for model configurations
class ModelConfigsNotifier extends StateNotifier<Map<String, ModelConfig>> {
  final ModelConfigService _service;
  bool _isInitialized = false;
  
  ModelConfigsNotifier(this._service) : super({}) {
    _loadConfigs();
  }
  
  Future<void> _loadConfigs() async {
    if (_isInitialized) return;
    
    try {
      await _service.initialize();
      state = _service.allModelConfigs;
      _isInitialized = true;
    } catch (e) {
      print('Failed to load model configs: $e');
      _isInitialized = true;
    }
  }
  
  Future<void> addModel(ModelConfig model) async {
    if (model.isLocal) {
      await _service.addLocalModel(model);
    } else {
      // Convert back to ApiConfig for the base service
      final apiConfig = ApiConfig(
        id: model.id,
        name: model.name,
        provider: model.provider,
        model: model.model,
        apiKey: model.apiKey,
        baseUrl: model.baseUrl,
        isDefault: model.isDefault,
        enabled: model.enabled,
        settings: model.settings,
      );
      await _service.setApiConfig(model.id, apiConfig);
    }
    state = _service.allModelConfigs;
  }
  
  Future<void> removeModel(String modelId) async {
    final model = _service.getModelConfig(modelId);
    if (model == null) return;
    
    if (model.isLocal) {
      await _service.removeLocalModel(modelId);
    } else {
      await _service.removeApiConfig(modelId);
    }
    state = _service.allModelConfigs;
  }
  
  Future<void> setDefault(String modelId) async {
    await _service.setDefaultModel(modelId);
    state = _service.allModelConfigs;
  }
  
  Future<void> downloadModel(String modelId, {Function(double)? onProgress}) async {
    await _service.downloadModel(modelId, onProgress: onProgress);
    state = _service.allModelConfigs;
  }
  
  Future<void> refresh() async {
    await _service._syncWithOllama();
    state = _service.allModelConfigs;
  }
}

// Provider for model configs state notifier
final modelConfigsProvider = StateNotifierProvider<ModelConfigsNotifier, Map<String, ModelConfig>>((ref) {
  final service = ref.watch(modelConfigServiceProvider);
  return ModelConfigsNotifier(service);
});

// Provider for all model configs
final allModelConfigsProvider = Provider<Map<String, ModelConfig>>((ref) {
  return ref.watch(modelConfigsProvider);
});

// Provider for API model configs only
final apiModelConfigsProvider = Provider<Map<String, ModelConfig>>((ref) {
  final allConfigs = ref.watch(modelConfigsProvider);
  return Map.fromEntries(
    allConfigs.entries.where((entry) => entry.value.isApi),
  );
});

// Provider for local model configs only
final localModelConfigsProvider = Provider<Map<String, ModelConfig>>((ref) {
  final allConfigs = ref.watch(modelConfigsProvider);
  return Map.fromEntries(
    allConfigs.entries.where((entry) => entry.value.isLocal),
  );
});

// Provider for default model config
final defaultModelConfigProvider = Provider<ModelConfig?>((ref) {
  final service = ref.watch(modelConfigServiceProvider);
  return service.defaultModelConfig;
});

// Provider for available models for download
final availableModelConfigsProvider = Provider<Map<String, ModelConfig>>((ref) {
  final service = ref.watch(modelConfigServiceProvider);
  return service.availableModelConfigs;
});

// Provider for ready models - derives from reactive modelConfigsProvider state
final readyModelConfigsProvider = Provider<List<ModelConfig>>((ref) {
  final allConfigs = ref.watch(modelConfigsProvider);
  return allConfigs.values
      .where((model) => model.isConfigured)
      .toList();
});

// Provider for currently selected model (for chat)
final selectedModelProvider = StateProvider<ModelConfig?>((ref) {
  // Try default model first
  final defaultModel = ref.watch(defaultModelConfigProvider);
  if (defaultModel != null) {
    return defaultModel;
  }
  
  // If no default set, use the first available configured model
  final allModels = ref.watch(allModelConfigsProvider);
  final configuredModels = allModels.values.where((model) => model.isConfigured).toList();
  
  return configuredModels.isNotEmpty ? configuredModels.first : null;
});
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/model_config.dart';
import './llm/unified_llm_service.dart';
import './llm/llm_provider.dart';
import './model_config_service.dart';

/// Service for managing quick chat models - small, fast models pre-loaded for instant responses
///
/// This service identifies and preloads lightweight local models specifically for
/// agentless quick chats, eliminating cold start delays.
///
/// Quick chat models criteria:
/// - Local Ollama models only (no API calls)
/// - Parameter size <= 10B (fast inference)
/// - Pre-loaded and kept in memory
///
/// Examples: llama3.2:3b, deepseek-r1:8b, gemma2:2b
class QuickChatModelService {
  final ModelConfigService _modelConfigService;
  final UnifiedLLMService _llmService;

  // Quick chat model selection strategy
  static const int maxParameterSize = 10; // Max 10B parameters for quick models
  static const Duration keepAliveTime = Duration(hours: 2); // Keep in memory for 2 hours

  final Map<String, QuickChatModelStatus> _quickModels = {};
  final StreamController<List<QuickChatModelStatus>> _statusController =
      StreamController<List<QuickChatModelStatus>>.broadcast();

  String? _preferredQuickModel;

  QuickChatModelService({
    required ModelConfigService modelConfigService,
    required UnifiedLLMService llmService,
  })  : _modelConfigService = modelConfigService,
        _llmService = llmService;

  /// Stream of quick chat model status updates
  Stream<List<QuickChatModelStatus>> get statusStream => _statusController.stream;

  /// Get current list of quick chat models
  List<QuickChatModelStatus> get quickModels => _quickModels.values.toList();

  /// Get the preferred quick chat model (smallest, fastest)
  String? get preferredQuickModel => _preferredQuickModel;

  /// Initialize quick chat models - scan and identify suitable models
  Future<void> initialize() async {
    debugPrint('🚀 Initializing Quick Chat Model Service...');

    // Get all local models
    final allModels = _modelConfigService.allModelConfigs.values
        .where((model) => model.isLocal && model.isConfigured)
        .toList();

    if (allModels.isEmpty) {
      debugPrint('⚠️ No local models found for quick chat');
      return;
    }

    // Identify quick chat candidates (small, fast models)
    final quickChatCandidates = _identifyQuickChatModels(allModels);

    if (quickChatCandidates.isEmpty) {
      debugPrint('⚠️ No suitable quick chat models found (all models > ${maxParameterSize}B)');
      return;
    }

    debugPrint('📋 Found ${quickChatCandidates.length} quick chat model candidates:');
    for (final model in quickChatCandidates) {
      debugPrint('  • ${model.name} (${_extractParameterSize(model)}B)');
    }

    // Initialize status tracking
    for (final model in quickChatCandidates) {
      _quickModels[model.id] = QuickChatModelStatus(
        modelId: model.id,
        modelName: model.name,
        parameterSize: _extractParameterSize(model),
        status: QuickChatState.identified,
        identifiedAt: DateTime.now(),
      );
    }

    // Select preferred model (smallest first)
    _selectPreferredModel();

    _notifyStatusUpdate();
    debugPrint('✅ Quick Chat Model Service initialized');
  }

  /// Pre-load quick chat models to eliminate cold starts
  Future<void> preloadQuickModels() async {
    if (_quickModels.isEmpty) {
      debugPrint('⚠️ No quick chat models to preload');
      return;
    }

    debugPrint('🔥 Pre-loading ${_quickModels.length} quick chat models...');

    // Preload preferred model first (highest priority)
    if (_preferredQuickModel != null) {
      await _preloadSingleModel(_preferredQuickModel!);
    }

    // Preload other quick models in parallel (lower priority)
    final otherModels = _quickModels.keys
        .where((id) => id != _preferredQuickModel)
        .toList();

    final futures = <Future>[];
    for (int i = 0; i < otherModels.length; i++) {
      futures.add(
        Future.delayed(
          Duration(seconds: 2 + i), // Stagger by 2 seconds to avoid overwhelming
          () => _preloadSingleModel(otherModels[i]),
        ),
      );
    }

    await Future.wait(futures);

    final readyCount = _quickModels.values.where((s) => s.isReady).length;
    debugPrint('✅ Quick chat models preloaded: $readyCount ready');
  }

  /// Get the best quick chat model for instant responses
  String? getBestQuickChatModel() {
    // Return preferred model if ready
    if (_preferredQuickModel != null) {
      final status = _quickModels[_preferredQuickModel];
      if (status?.isReady ?? false) {
        return _preferredQuickModel;
      }
    }

    // Fallback: return any ready quick model
    final readyModel = _quickModels.values
        .where((s) => s.isReady)
        .toList()
        ..sort((a, b) => a.parameterSize.compareTo(b.parameterSize));

    return readyModel.isNotEmpty ? readyModel.first.modelId : null;
  }

  /// Check if quick chat models are ready
  bool get hasReadyQuickModel => _quickModels.values.any((s) => s.isReady);

  /// Identify quick chat models from all available models
  List<ModelConfig> _identifyQuickChatModels(List<ModelConfig> allModels) {
    return allModels.where((model) {
      // Must be local
      if (!model.isLocal) return false;

      // Extract parameter size
      final paramSize = _extractParameterSize(model);

      // Must be <= maxParameterSize (e.g., 10B)
      return paramSize > 0 && paramSize <= maxParameterSize;
    }).toList()
      ..sort((a, b) {
        // Sort by parameter size (smallest first)
        final sizeA = _extractParameterSize(a);
        final sizeB = _extractParameterSize(b);
        return sizeA.compareTo(sizeB);
      });
  }

  /// Extract parameter size from model config (in billions)
  double _extractParameterSize(ModelConfig model) {
    // Extract from model name or ollamaModelId
    // Examples: "llama3.2:3b" -> 3, "Llama3.2 3.2B" -> 3.2, "mistral-small3.1:latest" -> needs name lookup

    // Try ollamaModelId first (most accurate)
    if (model.ollamaModelId != null && model.ollamaModelId!.isNotEmpty) {
      final match = RegExp(r'(\d+\.?\d*)[bB]').firstMatch(model.ollamaModelId!.toLowerCase());
      if (match != null) {
        return double.tryParse(match.group(1)!) ?? 0;
      }
    }

    // Fallback: extract from model name
    // Look for patterns like "3.2B", "8B", "3b", "3.2 B"
    final nameMatch = RegExp(r'(\d+\.?\d*)\s*[bB]').firstMatch(model.name);
    if (nameMatch != null) {
      return double.tryParse(nameMatch.group(1)!) ?? 0;
    }

    return 0;
  }

  /// Select the preferred quick chat model (smallest, fastest)
  void _selectPreferredModel() {
    if (_quickModels.isEmpty) return;

    // Sort by parameter size (smallest first)
    final sorted = _quickModels.values.toList()
      ..sort((a, b) => a.parameterSize.compareTo(b.parameterSize));

    _preferredQuickModel = sorted.first.modelId;
    debugPrint('✅ Preferred quick chat model: ${sorted.first.modelName} (${sorted.first.parameterSize}B)');
  }

  /// Preload a single quick chat model
  Future<void> _preloadSingleModel(String modelId) async {
    final model = _modelConfigService.getModelConfig(modelId);
    if (model == null) {
      debugPrint('⚠️ Quick chat model $modelId not found');
      return;
    }

    final startTime = DateTime.now();

    try {
      debugPrint('🔥 Pre-loading quick chat model: ${model.name}...');

      // Update status to preloading
      _quickModels[modelId] = _quickModels[modelId]!.copyWith(
        status: QuickChatState.preloading,
        preloadStartedAt: DateTime.now(),
      );
      _notifyStatusUpdate();

      // Send minimal warmup request with keep_alive
      await _llmService.chat(
        message: 'Hi',
        modelId: modelId,
        context: const ChatContext(
          messages: [],
          systemPrompt: 'You are a helpful assistant. Respond briefly.',
          metadata: {
            'isQuickChatWarmup': true,
            'maxTokens': 3,
          },
        ),
      );

      final duration = DateTime.now().difference(startTime);

      // Update status to ready
      _quickModels[modelId] = _quickModels[modelId]!.copyWith(
        status: QuickChatState.ready,
        preloadCompletedAt: DateTime.now(),
        preloadDuration: duration,
        lastUsedAt: DateTime.now(),
      );

      debugPrint('✅ Quick chat model ${model.name} ready in ${duration.inMilliseconds}ms');
    } catch (e) {
      debugPrint('❌ Failed to preload quick chat model ${model.name}: $e');

      _quickModels[modelId] = _quickModels[modelId]!.copyWith(
        status: QuickChatState.error,
        error: e.toString(),
        preloadCompletedAt: DateTime.now(),
      );
    }

    _notifyStatusUpdate();
  }

  /// Mark a quick model as recently used (updates keep-alive)
  void markAsUsed(String modelId) {
    final status = _quickModels[modelId];
    if (status != null) {
      _quickModels[modelId] = status.copyWith(
        lastUsedAt: DateTime.now(),
      );
      _notifyStatusUpdate();
    }
  }

  void _notifyStatusUpdate() {
    _statusController.add(_quickModels.values.toList());
  }

  void dispose() {
    _statusController.close();
  }
}

/// Status of a quick chat model
class QuickChatModelStatus {
  final String modelId;
  final String modelName;
  final double parameterSize;
  final QuickChatState status;
  final DateTime identifiedAt;
  final DateTime? preloadStartedAt;
  final DateTime? preloadCompletedAt;
  final Duration? preloadDuration;
  final DateTime? lastUsedAt;
  final String? error;

  const QuickChatModelStatus({
    required this.modelId,
    required this.modelName,
    required this.parameterSize,
    required this.status,
    required this.identifiedAt,
    this.preloadStartedAt,
    this.preloadCompletedAt,
    this.preloadDuration,
    this.lastUsedAt,
    this.error,
  });

  bool get isReady => status == QuickChatState.ready;
  bool get isPreloading => status == QuickChatState.preloading;
  bool get hasError => status == QuickChatState.error;

  QuickChatModelStatus copyWith({
    QuickChatState? status,
    DateTime? preloadStartedAt,
    DateTime? preloadCompletedAt,
    Duration? preloadDuration,
    DateTime? lastUsedAt,
    String? error,
  }) {
    return QuickChatModelStatus(
      modelId: modelId,
      modelName: modelName,
      parameterSize: parameterSize,
      status: status ?? this.status,
      identifiedAt: identifiedAt,
      preloadStartedAt: preloadStartedAt ?? this.preloadStartedAt,
      preloadCompletedAt: preloadCompletedAt ?? this.preloadCompletedAt,
      preloadDuration: preloadDuration ?? this.preloadDuration,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      error: error ?? this.error,
    );
  }
}

enum QuickChatState {
  identified, // Model identified as quick chat candidate
  preloading, // Currently pre-loading
  ready, // Preloaded and ready for instant responses
  error, // Preload failed
}

/// Provider for quick chat model service
final quickChatModelServiceProvider = Provider<QuickChatModelService>((ref) {
  final service = QuickChatModelService(
    modelConfigService: ref.read(modelConfigServiceProvider),
    llmService: ref.read(unifiedLLMServiceProvider),
  );

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

/// Provider for quick chat model status stream
final quickChatModelStatusProvider = StreamProvider<List<QuickChatModelStatus>>((ref) {
  final service = ref.read(quickChatModelServiceProvider);
  return service.statusStream;
});

/// Provider to check if quick chat is ready
final isQuickChatReadyProvider = Provider<bool>((ref) {
  final statusAsync = ref.watch(quickChatModelStatusProvider);

  return statusAsync.maybeWhen(
    data: (statuses) => statuses.any((s) => s.isReady),
    orElse: () => false,
  );
});

/// Provider to get the best quick chat model
final bestQuickChatModelProvider = Provider<String?>((ref) {
  final service = ref.read(quickChatModelServiceProvider);
  return service.getBestQuickChatModel();
});

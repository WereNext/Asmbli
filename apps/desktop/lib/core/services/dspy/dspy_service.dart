/// DSPy Service - High-level integration with Asmbli
///
/// This service wraps the DspyClient and integrates with the
/// existing Asmbli architecture (Riverpod, ServiceLocator, etc.)
///
/// This is the service you use in your Flutter widgets and providers.
library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dspy_client.dart';

// ============== Configuration ==============

/// Configuration for DSPy service
class DspyConfig {
  final String backendUrl;
  final Duration timeout;
  final String? defaultModel;
  final bool autoReconnect;

  const DspyConfig({
    this.backendUrl = 'http://localhost:8000',
    this.timeout = const Duration(seconds: 60),
    this.defaultModel,
    this.autoReconnect = true,
  });

  /// Development config
  static const development = DspyConfig(
    backendUrl: 'http://localhost:8000',
    timeout: Duration(seconds: 60),
    autoReconnect: true,
  );

  /// Production config - update with your deployed URL
  static DspyConfig production(String url) => DspyConfig(
        backendUrl: url,
        timeout: const Duration(seconds: 30),
        autoReconnect: true,
      );
}

// ============== Service State ==============

/// State of the DSPy service
enum DspyServiceStatus {
  disconnected,
  connecting,
  connected,
  error,
}

/// Full state including available models
class DspyServiceState {
  final DspyServiceStatus status;
  final List<String> availableModels;
  final int documentsIndexed;
  final String? errorMessage;
  final DateTime? lastCheck;

  const DspyServiceState({
    this.status = DspyServiceStatus.disconnected,
    this.availableModels = const [],
    this.documentsIndexed = 0,
    this.errorMessage,
    this.lastCheck,
  });

  DspyServiceState copyWith({
    DspyServiceStatus? status,
    List<String>? availableModels,
    int? documentsIndexed,
    String? errorMessage,
    DateTime? lastCheck,
  }) {
    return DspyServiceState(
      status: status ?? this.status,
      availableModels: availableModels ?? this.availableModels,
      documentsIndexed: documentsIndexed ?? this.documentsIndexed,
      errorMessage: errorMessage,
      lastCheck: lastCheck ?? this.lastCheck,
    );
  }

  bool get isConnected => status == DspyServiceStatus.connected;
  bool get hasError => status == DspyServiceStatus.error;
}

// ============== Main Service ==============

/// High-level DSPy service for Asmbli integration
///
/// Example usage in a widget:
/// ```dart
/// class MyWidget extends ConsumerWidget {
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     final dspy = ref.watch(dspyServiceProvider);
///     final state = ref.watch(dspyStateProvider);
///
///     if (!state.isConnected) {
///       return Text('DSPy not connected');
///     }
///
///     return ElevatedButton(
///       onPressed: () async {
///         final response = await dspy.chat('Hello!');
///         print(response.response);
///       },
///       child: Text('Chat'),
///     );
///   }
/// }
/// ```
class DspyService {
  final DspyConfig config;
  late final DspyClient _client;

  DspyServiceState _state = const DspyServiceState();
  final _stateController = StreamController<DspyServiceState>.broadcast();

  /// Stream of state changes
  Stream<DspyServiceState> get stateStream => _stateController.stream;

  /// Current state
  DspyServiceState get state => _state;

  DspyService({DspyConfig? config}) : config = config ?? DspyConfig.development {
    _client = DspyClient(
      baseUrl: this.config.backendUrl,
      timeout: this.config.timeout,
    );
  }

  // ============== Connection Management ==============

  /// Initialize and connect to the backend
  Future<bool> connect() async {
    _updateState(_state.copyWith(status: DspyServiceStatus.connecting));

    try {
      final health = await _client.healthCheck();

      _updateState(_state.copyWith(
        status: DspyServiceStatus.connected,
        availableModels: health.modelsAvailable,
        documentsIndexed: health.documentsIndexed,
        lastCheck: DateTime.now(),
        errorMessage: null,
      ));

      return true;
    } catch (e) {
      _updateState(_state.copyWith(
        status: DspyServiceStatus.error,
        errorMessage: e.toString(),
        lastCheck: DateTime.now(),
      ));
      return false;
    }
  }

  /// Check if backend is available
  Future<bool> isAvailable() => _client.isAvailable();

  /// Refresh connection state
  Future<void> refresh() async {
    await connect();
  }

  // ============== Chat ==============

  /// Send a chat message
  Future<DspyChatResponse> chat(
    String message, {
    String? model,
    String? systemPrompt,
    double temperature = 0.7,
  }) async {
    _ensureConnected();
    return _client.chat(
      message,
      model: model ?? config.defaultModel,
      systemPrompt: systemPrompt,
      temperature: temperature,
    );
  }

  // ============== RAG ==============

  /// Query documents using RAG
  Future<DspyRagResponse> queryDocuments(
    String question, {
    List<String>? documentIds,
    int numPassages = 5,
    bool includeCitations = true,
    String? model,
  }) async {
    _ensureConnected();
    return _client.ragQuery(
      question,
      documentIds: documentIds,
      numPassages: numPassages,
      includeCitations: includeCitations,
      model: model ?? config.defaultModel,
    );
  }

  /// Upload a document for RAG
  Future<DspyDocumentResponse> uploadDocument(
    String title,
    String content, {
    Map<String, dynamic>? metadata,
  }) async {
    _ensureConnected();
    final response = await _client.uploadDocument(title, content, metadata: metadata);

    // Update state with new document count
    _updateState(_state.copyWith(
      documentsIndexed: _state.documentsIndexed + 1,
    ));

    return response;
  }

  /// List all documents
  Future<List<Map<String, dynamic>>> listDocuments() async {
    _ensureConnected();
    return _client.listDocuments();
  }

  /// Delete a document
  Future<void> deleteDocument(String documentId) async {
    _ensureConnected();
    await _client.deleteDocument(documentId);

    // Update state
    _updateState(_state.copyWith(
      documentsIndexed: (_state.documentsIndexed - 1).clamp(0, 999999),
    ));
  }

  // ============== Agent ==============

  /// Execute a ReAct agent
  ///
  /// [tools] - Tool definitions. For MCP tools, include server_id.
  /// [flutterCallbackUrl] - Callback URL for MCP tool execution (default: http://localhost:3000)
  Future<DspyAgentResponse> executeAgent(
    String task, {
    List<Map<String, dynamic>>? tools,
    int maxIterations = 5,
    String? model,
    String? agentId,
    String? flutterCallbackUrl,
  }) async {
    _ensureConnected();

    // Check if any tools are MCP tools (have server_id)
    final hasMcpTools = tools?.any((t) => t.containsKey('server_id')) ?? false;

    // If we have MCP tools, ensure we have a callback URL
    final callbackUrl = hasMcpTools
        ? (flutterCallbackUrl ?? 'http://localhost:3000')
        : null;

    return _client.executeAgent(
      task,
      tools: tools,
      maxIterations: maxIterations,
      model: model ?? config.defaultModel,
      agentId: agentId,
      flutterCallbackUrl: callbackUrl,
    );
  }

  /// Execute an agent with streaming updates via SSE
  ///
  /// Returns a Stream of [DspyStreamEvent] with real-time updates:
  /// - status: Status messages (thinking, calling tool, etc.)
  /// - tool_call: When agent calls a tool
  /// - tool_result: Results from tool execution
  /// - step: Complete reasoning steps
  /// - error: If something goes wrong
  /// - done: Final result with answer
  ///
  /// Example usage in a widget:
  /// ```dart
  /// StreamBuilder<DspyStreamEvent>(
  ///   stream: dspyService.streamAgent('Search for X', tools: mcpTools),
  ///   builder: (context, snapshot) {
  ///     if (!snapshot.hasData) return CircularProgressIndicator();
  ///     final event = snapshot.data!;
  ///     if (event.type == DspyStreamEventType.status) {
  ///       return Text(event.statusMessage ?? '');
  ///     }
  ///     // ... handle other events
  ///   },
  /// )
  /// ```
  Stream<DspyStreamEvent> streamAgent(
    String task, {
    List<Map<String, dynamic>>? tools,
    int maxIterations = 5,
    String? model,
    String? agentId,
    String? conversationId,
    String? flutterCallbackUrl,
  }) {
    _ensureConnected();

    // Check if any tools are MCP tools (have server_id)
    final hasMcpTools = tools?.any((t) => t.containsKey('server_id')) ?? false;

    // If we have MCP tools, ensure we have a callback URL
    final callbackUrl = hasMcpTools
        ? (flutterCallbackUrl ?? 'http://localhost:3000')
        : null;

    return _client.streamAgent(
      task,
      tools: tools,
      maxIterations: maxIterations,
      model: model ?? config.defaultModel,
      agentId: agentId,
      conversationId: conversationId,
      flutterCallbackUrl: callbackUrl,
    );
  }

  // ============== Reasoning ==============

  /// Apply chain-of-thought reasoning
  Future<DspyReasoningResponse> chainOfThought(
    String question, {
    String? model,
  }) async {
    _ensureConnected();
    return _client.reason(
      question,
      pattern: DspyReasoningPattern.chainOfThought,
      model: model ?? config.defaultModel,
    );
  }

  /// Apply tree-of-thought reasoning
  Future<DspyReasoningResponse> treeOfThought(
    String question, {
    int numBranches = 3,
    String? model,
  }) async {
    _ensureConnected();
    return _client.reason(
      question,
      pattern: DspyReasoningPattern.treeOfThought,
      numBranches: numBranches,
      model: model ?? config.defaultModel,
    );
  }

  /// Generic reasoning with pattern selection
  Future<DspyReasoningResponse> reason(
    String question, {
    DspyReasoningPattern pattern = DspyReasoningPattern.chainOfThought,
    int numBranches = 3,
    String? model,
  }) async {
    _ensureConnected();
    return _client.reason(
      question,
      pattern: pattern,
      numBranches: numBranches,
      model: model ?? config.defaultModel,
    );
  }

  // ============== Code ==============

  /// Generate code
  Future<Map<String, dynamic>> generateCode(
    String task, {
    String language = 'python',
    bool execute = false,
    String? model,
  }) async {
    _ensureConnected();
    return _client.generateCode(
      task,
      language: language,
      execute: execute,
      model: model ?? config.defaultModel,
    );
  }

  // ============== Helpers ==============

  void _ensureConnected() {
    if (!_state.isConnected) {
      throw DspyException('Not connected to DSPy backend. Call connect() first.');
    }
  }

  void _updateState(DspyServiceState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  /// Dispose resources
  void dispose() {
    _client.dispose();
    _stateController.close();
  }
}

// ============== Riverpod Providers ==============

/// Configuration provider - override this to change backend URL
final dspyConfigProvider = Provider<DspyConfig>((ref) {
  // In production, you'd load this from environment or settings
  return DspyConfig.development;
});

/// Main DSPy service provider
final dspyServiceProvider = Provider<DspyService>((ref) {
  final config = ref.watch(dspyConfigProvider);
  final service = DspyService(config: config);

  // Auto-connect
  service.connect();

  // Cleanup on dispose
  ref.onDispose(() => service.dispose());

  return service;
});

/// State provider for reactive UI updates
final dspyStateProvider = StreamProvider<DspyServiceState>((ref) {
  final service = ref.watch(dspyServiceProvider);
  return service.stateStream;
});

/// Convenience provider for connection status
final dspyIsConnectedProvider = Provider<bool>((ref) {
  final state = ref.watch(dspyStateProvider);
  return state.valueOrNull?.isConnected ?? false;
});

/// Available models provider
final dspyAvailableModelsProvider = Provider<List<String>>((ref) {
  final state = ref.watch(dspyStateProvider);
  return state.valueOrNull?.availableModels ?? [];
});

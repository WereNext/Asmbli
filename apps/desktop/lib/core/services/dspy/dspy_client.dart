/// DSPy Backend Client
///
/// This is the Dart client that calls the DSPy Python backend.
/// This is REAL code that actually works - not theoretical.
///
/// Usage:
///   final client = DspyClient(baseUrl: 'http://localhost:8000');
///   final response = await client.chat('What is 2 + 2?');
///   print(response.response); // "4"
library;

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

// ============== Response Models ==============

/// Response from chat endpoint
class DspyChatResponse {
  final String response;
  final String model;
  final String? reasoning;
  final double? confidence;

  DspyChatResponse({
    required this.response,
    required this.model,
    this.reasoning,
    this.confidence,
  });

  factory DspyChatResponse.fromJson(Map<String, dynamic> json) {
    return DspyChatResponse(
      response: json['response'] as String,
      model: json['model'] as String,
      reasoning: json['reasoning'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble(),
    );
  }
}

/// A source document from RAG
class DspyRagSource {
  final String documentId;
  final String title;
  final String excerpt;
  final double relevanceScore;

  DspyRagSource({
    required this.documentId,
    required this.title,
    required this.excerpt,
    required this.relevanceScore,
  });

  factory DspyRagSource.fromJson(Map<String, dynamic> json) {
    return DspyRagSource(
      documentId: json['document_id'] as String,
      title: json['title'] as String,
      excerpt: json['excerpt'] as String,
      relevanceScore: (json['relevance_score'] as num).toDouble(),
    );
  }
}

/// Response from RAG query endpoint
class DspyRagResponse {
  final String answer;
  final List<DspyRagSource> sources;
  final double confidence;
  final String model;
  final int passagesUsed;

  DspyRagResponse({
    required this.answer,
    required this.sources,
    required this.confidence,
    required this.model,
    required this.passagesUsed,
  });

  factory DspyRagResponse.fromJson(Map<String, dynamic> json) {
    return DspyRagResponse(
      answer: json['answer'] as String,
      sources: (json['sources'] as List)
          .map((s) => DspyRagSource.fromJson(s as Map<String, dynamic>))
          .toList(),
      confidence: (json['confidence'] as num).toDouble(),
      model: json['model'] as String,
      passagesUsed: json['passages_used'] as int,
    );
  }
}

/// A step in agent execution
class DspyAgentStep {
  final int iteration;
  final String thought;
  final String action;
  final String? observation;

  DspyAgentStep({
    required this.iteration,
    required this.thought,
    required this.action,
    this.observation,
  });

  factory DspyAgentStep.fromJson(Map<String, dynamic> json) {
    return DspyAgentStep(
      iteration: json['iteration'] as int,
      thought: json['thought'] as String,
      action: json['action'] as String,
      observation: json['observation'] as String?,
    );
  }
}

/// Response from agent execution
class DspyAgentResponse {
  final String answer;
  final bool success;
  final List<DspyAgentStep> steps;
  final int iterationsUsed;
  final String model;

  DspyAgentResponse({
    required this.answer,
    required this.success,
    required this.steps,
    required this.iterationsUsed,
    required this.model,
  });

  factory DspyAgentResponse.fromJson(Map<String, dynamic> json) {
    return DspyAgentResponse(
      answer: json['answer'] as String,
      success: json['success'] as bool,
      steps: (json['steps'] as List)
          .map((s) => DspyAgentStep.fromJson(s as Map<String, dynamic>))
          .toList(),
      iterationsUsed: json['iterations_used'] as int,
      model: json['model'] as String,
    );
  }
}

/// Response from reasoning endpoint
class DspyReasoningResponse {
  final String answer;
  final String reasoning;
  final double confidence;
  final String patternUsed;
  final String model;
  final List<Map<String, dynamic>>? branches;

  DspyReasoningResponse({
    required this.answer,
    required this.reasoning,
    required this.confidence,
    required this.patternUsed,
    required this.model,
    this.branches,
  });

  factory DspyReasoningResponse.fromJson(Map<String, dynamic> json) {
    return DspyReasoningResponse(
      answer: json['answer'] as String,
      reasoning: json['reasoning'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      patternUsed: json['pattern_used'] as String,
      model: json['model'] as String,
      branches: json['branches'] != null
          ? (json['branches'] as List)
              .map((b) => b as Map<String, dynamic>)
              .toList()
          : null,
    );
  }
}

/// Health check response
class DspyHealthResponse {
  final String status;
  final String version;
  final List<String> modelsAvailable;
  final String vectorDbStatus;
  final int documentsIndexed;

  DspyHealthResponse({
    required this.status,
    required this.version,
    required this.modelsAvailable,
    required this.vectorDbStatus,
    required this.documentsIndexed,
  });

  factory DspyHealthResponse.fromJson(Map<String, dynamic> json) {
    return DspyHealthResponse(
      status: json['status'] as String,
      version: json['version'] as String,
      modelsAvailable: (json['models_available'] as List).cast<String>(),
      vectorDbStatus: json['vector_db_status'] as String,
      documentsIndexed: json['documents_indexed'] as int,
    );
  }

  bool get isHealthy => status == 'healthy';
}

// ============== SSE Streaming Models ==============

/// Types of events in agent streaming
enum DspyStreamEventType {
  status,     // Agent status update (thinking, calling tool, etc.)
  token,      // Text token for streaming response
  toolCall,   // Agent is calling a tool
  toolResult, // Tool returned a result
  step,       // Complete reasoning step
  error,      // Error occurred
  done,       // Agent finished
}

/// A streaming event from the agent
class DspyStreamEvent {
  final DspyStreamEventType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  DspyStreamEvent({
    required this.type,
    required this.data,
    required this.timestamp,
  });

  factory DspyStreamEvent.fromJson(Map<String, dynamic> json) {
    final eventStr = json['event'] as String;
    DspyStreamEventType type;
    switch (eventStr) {
      case 'status':
        type = DspyStreamEventType.status;
        break;
      case 'token':
        type = DspyStreamEventType.token;
        break;
      case 'tool_call':
        type = DspyStreamEventType.toolCall;
        break;
      case 'tool_result':
        type = DspyStreamEventType.toolResult;
        break;
      case 'step':
        type = DspyStreamEventType.step;
        break;
      case 'error':
        type = DspyStreamEventType.error;
        break;
      case 'done':
        type = DspyStreamEventType.done;
        break;
      default:
        type = DspyStreamEventType.status;
    }

    return DspyStreamEvent(
      type: type,
      data: json['data'] as Map<String, dynamic>? ?? {},
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
    );
  }

  /// Get status message if this is a status event
  String? get statusMessage => type == DspyStreamEventType.status
      ? data['message'] as String?
      : null;

  /// Get tool name if this is a tool_call event
  String? get toolName => type == DspyStreamEventType.toolCall
      ? data['tool'] as String?
      : null;

  /// Get final answer if this is a done event
  String? get answer => type == DspyStreamEventType.done
      ? data['answer'] as String?
      : null;

  /// Check if this is a final event
  bool get isDone => type == DspyStreamEventType.done;

  /// Check if this is an error event
  bool get isError => type == DspyStreamEventType.error;

  /// Get error message if this is an error event
  String? get errorMessage => type == DspyStreamEventType.error
      ? data['error'] as String?
      : null;
}

/// Document upload response
class DspyDocumentResponse {
  final String documentId;
  final String title;
  final int chunksCreated;
  final String message;

  DspyDocumentResponse({
    required this.documentId,
    required this.title,
    required this.chunksCreated,
    required this.message,
  });

  factory DspyDocumentResponse.fromJson(Map<String, dynamic> json) {
    return DspyDocumentResponse(
      documentId: json['document_id'] as String,
      title: json['title'] as String,
      chunksCreated: json['chunks_created'] as int,
      message: json['message'] as String,
    );
  }
}

// ============== Reasoning Patterns ==============

enum DspyReasoningPattern {
  basic,
  chainOfThought,
  treeOfThought,
  react,
}

extension DspyReasoningPatternExtension on DspyReasoningPattern {
  String get value {
    switch (this) {
      case DspyReasoningPattern.basic:
        return 'basic';
      case DspyReasoningPattern.chainOfThought:
        return 'chain_of_thought';
      case DspyReasoningPattern.treeOfThought:
        return 'tree_of_thought';
      case DspyReasoningPattern.react:
        return 'react';
    }
  }
}

// ============== Exceptions ==============

/// Exception thrown when DSPy backend call fails
class DspyException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic originalError;

  DspyException(this.message, {this.statusCode, this.originalError});

  @override
  String toString() => 'DspyException: $message (status: $statusCode)';
}

// ============== Main Client ==============

/// Client for the DSPy Python backend
///
/// This client handles all communication with the DSPy backend,
/// providing a clean Dart API for AI operations.
class DspyClient {
  final String baseUrl;
  final http.Client _client;
  final Duration timeout;

  DspyClient({
    required this.baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 60),
  }) : _client = client ?? http.Client();

  // ============== Health ==============

  /// Check if the backend is healthy
  Future<DspyHealthResponse> healthCheck() async {
    final response = await _get('/health');
    return DspyHealthResponse.fromJson(response);
  }

  /// Check if backend is reachable
  Future<bool> isAvailable() async {
    try {
      final health = await healthCheck();
      return health.isHealthy;
    } catch (e) {
      return false;
    }
  }

  // ============== Chat ==============

  /// Simple chat - send a message, get a response
  Future<DspyChatResponse> chat(
    String message, {
    String? model,
    String? systemPrompt,
    double temperature = 0.7,
  }) async {
    final response = await _post('/chat', {
      'message': message,
      if (model != null) 'model': model,
      if (systemPrompt != null) 'system_prompt': systemPrompt,
      'temperature': temperature,
    });
    return DspyChatResponse.fromJson(response);
  }

  // ============== RAG ==============

  /// Query documents using RAG
  Future<DspyRagResponse> ragQuery(
    String question, {
    List<String>? documentIds,
    int numPassages = 5,
    bool includeCitations = true,
    String? model,
  }) async {
    final response = await _post('/rag/query', {
      'question': question,
      if (documentIds != null) 'document_ids': documentIds,
      'num_passages': numPassages,
      'include_citations': includeCitations,
      if (model != null) 'model': model,
    });
    return DspyRagResponse.fromJson(response);
  }

  /// Upload a document for RAG
  Future<DspyDocumentResponse> uploadDocument(
    String title,
    String content, {
    Map<String, dynamic>? metadata,
  }) async {
    final response = await _post('/documents/upload', {
      'title': title,
      'content': content,
      if (metadata != null) 'metadata': metadata,
    });
    return DspyDocumentResponse.fromJson(response);
  }

  /// List all documents
  Future<List<Map<String, dynamic>>> listDocuments() async {
    final response = await _get('/documents');
    return (response['documents'] as List).cast<Map<String, dynamic>>();
  }

  /// Delete a document
  Future<void> deleteDocument(String documentId) async {
    await _delete('/documents/$documentId');
  }

  // ============== Agent ==============

  /// Execute a ReAct agent
  ///
  /// [tools] - List of tool definitions. Each tool should have:
  ///   - 'name': Tool name
  ///   - 'description': Tool description
  ///   - 'server_id' (optional): MCP server ID if this is an MCP tool
  ///   - 'input_schema' (optional): JSON Schema for tool parameters
  ///
  /// [flutterCallbackUrl] - URL for Flutter to receive MCP tool execution callbacks.
  ///   Required if any tools have a server_id (are MCP tools).
  ///   Typically 'http://localhost:3000' (Plugin Bridge Server).
  Future<DspyAgentResponse> executeAgent(
    String task, {
    List<Map<String, dynamic>>? tools,
    int maxIterations = 5,
    String? model,
    String? agentId,
    String? flutterCallbackUrl,
  }) async {
    final response = await _post('/agent/execute', {
      'task': task,
      if (tools != null) 'tools': tools,
      'max_iterations': maxIterations,
      if (model != null) 'model': model,
      if (agentId != null) 'agent_id': agentId,
      if (flutterCallbackUrl != null) 'flutter_callback_url': flutterCallbackUrl,
    });
    return DspyAgentResponse.fromJson(response);
  }

  /// Execute an agent with streaming updates via SSE
  ///
  /// Returns a Stream of [DspyStreamEvent] that emits:
  /// - status: Status messages (thinking, calling tool, etc.)
  /// - tool_call: When agent calls a tool
  /// - tool_result: Results from tool execution
  /// - step: Complete reasoning steps
  /// - error: If something goes wrong
  /// - done: Final result with answer
  ///
  /// Example usage:
  /// ```dart
  /// await for (final event in client.streamAgent('Search for X')) {
  ///   if (event.type == DspyStreamEventType.status) {
  ///     print('Status: ${event.statusMessage}');
  ///   } else if (event.isDone) {
  ///     print('Done: ${event.answer}');
  ///   }
  /// }
  /// ```
  Stream<DspyStreamEvent> streamAgent(
    String task, {
    List<Map<String, dynamic>>? tools,
    int maxIterations = 5,
    String? model,
    String? agentId,
    String? conversationId,
    String? flutterCallbackUrl,
  }) async* {
    final uri = Uri.parse('$baseUrl/agent/stream');

    final body = {
      'task': task,
      if (tools != null) 'tools': tools,
      'max_iterations': maxIterations,
      if (model != null) 'model': model,
      if (agentId != null) 'agent_id': agentId,
      if (conversationId != null) 'conversation_id': conversationId,
      if (flutterCallbackUrl != null) 'flutter_callback_url': flutterCallbackUrl,
    };

    try {
      final request = http.Request('POST', uri);
      request.headers['Content-Type'] = 'application/json';
      request.headers['Accept'] = 'text/event-stream';
      request.body = jsonEncode(body);

      final streamedResponse = await _client.send(request);

      if (streamedResponse.statusCode != 200) {
        throw DspyException(
          'Stream request failed',
          statusCode: streamedResponse.statusCode,
        );
      }

      // Parse SSE stream
      String buffer = '';
      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        buffer += chunk;

        // Process complete events (ending with double newline)
        while (buffer.contains('\n\n')) {
          final eventEnd = buffer.indexOf('\n\n');
          final eventData = buffer.substring(0, eventEnd);
          buffer = buffer.substring(eventEnd + 2);

          // Parse SSE format: "data: {...}"
          for (final line in eventData.split('\n')) {
            if (line.startsWith('data: ')) {
              final jsonStr = line.substring(6); // Remove "data: " prefix
              try {
                final json = jsonDecode(jsonStr) as Map<String, dynamic>;
                yield DspyStreamEvent.fromJson(json);
              } catch (e) {
                // Skip malformed JSON
                continue;
              }
            }
          }
        }
      }
    } on TimeoutException {
      yield DspyStreamEvent(
        type: DspyStreamEventType.error,
        data: {'error': 'Stream timed out'},
        timestamp: DateTime.now(),
      );
    } catch (e) {
      if (e is DspyException) {
        yield DspyStreamEvent(
          type: DspyStreamEventType.error,
          data: {'error': e.message},
          timestamp: DateTime.now(),
        );
      } else {
        yield DspyStreamEvent(
          type: DspyStreamEventType.error,
          data: {'error': 'Network error: $e'},
          timestamp: DateTime.now(),
        );
      }
    }
  }

  // ============== Reasoning ==============

  /// Apply structured reasoning
  Future<DspyReasoningResponse> reason(
    String question, {
    DspyReasoningPattern pattern = DspyReasoningPattern.chainOfThought,
    int numBranches = 3,
    String? model,
  }) async {
    final response = await _post('/reasoning', {
      'question': question,
      'pattern': pattern.value,
      'num_branches': numBranches,
      if (model != null) 'model': model,
    });
    return DspyReasoningResponse.fromJson(response);
  }

  // ============== Code Generation ==============

  /// Generate code for a task
  Future<Map<String, dynamic>> generateCode(
    String task, {
    String language = 'python',
    bool execute = false,
    String? model,
  }) async {
    final uri = Uri.parse('$baseUrl/code/generate').replace(queryParameters: {
      'task': task,
      'language': language,
      'execute': execute.toString(),
      if (model != null) 'model': model,
    });

    final response = await _client
        .post(uri, headers: {'Content-Type': 'application/json'})
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw DspyException(
        'Code generation failed',
        statusCode: response.statusCode,
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ============== HTTP Helpers ==============

  Future<Map<String, dynamic>> _get(String path) async {
    try {
      final response = await _client
          .get(
            Uri.parse('$baseUrl$path'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(timeout);

      if (response.statusCode != 200) {
        throw DspyException(
          'Request failed: ${response.body}',
          statusCode: response.statusCode,
        );
      }

      return jsonDecode(response.body) as Map<String, dynamic>;
    } on TimeoutException {
      throw DspyException('Request timed out');
    } catch (e) {
      if (e is DspyException) rethrow;
      throw DspyException('Network error', originalError: e);
    }
  }

  Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(timeout);

      if (response.statusCode != 200) {
        throw DspyException(
          'Request failed: ${response.body}',
          statusCode: response.statusCode,
        );
      }

      return jsonDecode(response.body) as Map<String, dynamic>;
    } on TimeoutException {
      throw DspyException('Request timed out');
    } catch (e) {
      if (e is DspyException) rethrow;
      throw DspyException('Network error', originalError: e);
    }
  }

  Future<void> _delete(String path) async {
    try {
      final response = await _client
          .delete(
            Uri.parse('$baseUrl$path'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(timeout);

      if (response.statusCode != 200) {
        throw DspyException(
          'Delete failed: ${response.body}',
          statusCode: response.statusCode,
        );
      }
    } on TimeoutException {
      throw DspyException('Request timed out');
    } catch (e) {
      if (e is DspyException) rethrow;
      throw DspyException('Network error', originalError: e);
    }
  }

  /// Dispose the client
  void dispose() {
    _client.close();
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/mvp_message.dart';
import '../models/mvp_settings.dart';

/// Simplified LLM service for MVP - direct API calls without DSPy overhead
class MvpLlmService {
  final String? openAiApiKey;
  final String? anthropicApiKey;
  final String ollamaBaseUrl;
  final bool ollamaEnabled;

  MvpLlmService({
    this.openAiApiKey,
    this.anthropicApiKey,
    this.ollamaBaseUrl = 'http://localhost:11434',
    this.ollamaEnabled = false,
  });

  /// Check if service is configured with at least one provider
  bool get isConfigured =>
      (openAiApiKey?.isNotEmpty ?? false) ||
      (anthropicApiKey?.isNotEmpty ?? false) ||
      ollamaEnabled;

  /// Get available providers based on configuration
  List<String> get availableProviders {
    final providers = <String>[];
    if (openAiApiKey?.isNotEmpty ?? false) providers.add('openai');
    if (anthropicApiKey?.isNotEmpty ?? false) providers.add('anthropic');
    if (ollamaEnabled) providers.add('ollama');
    return providers;
  }

  /// Get list of available Ollama models
  Future<List<String>> getOllamaModels() async {
    try {
      final response = await http.get(
        Uri.parse('$ollamaBaseUrl/api/tags'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = data['models'] as List? ?? [];
        return models.map<String>((m) => m['name'] as String).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Check if Ollama is running
  static Future<bool> checkOllamaRunning({String baseUrl = 'http://localhost:11434'}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/tags'),
      ).timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Send a chat message and get a response
  /// Returns a stream of content chunks for streaming display
  Stream<String> chat({
    required List<MvpMessage> messages,
    required MvpSettings settings,
    String? webSearchContext,
  }) async* {
    final provider = settings.selectedProvider;

    if (provider == 'openai' && (openAiApiKey?.isNotEmpty ?? false)) {
      yield* _chatOpenAI(
        messages: messages,
        settings: settings,
        webSearchContext: webSearchContext,
      );
    } else if (provider == 'anthropic' && (anthropicApiKey?.isNotEmpty ?? false)) {
      yield* _chatAnthropic(
        messages: messages,
        settings: settings,
        webSearchContext: webSearchContext,
      );
    } else if (provider == 'ollama' && ollamaEnabled) {
      yield* _chatOllama(
        messages: messages,
        settings: settings,
        webSearchContext: webSearchContext,
      );
    } else {
      throw MvpLlmException('No valid configuration for provider: $provider');
    }
  }

  /// Test API connection
  Future<MvpConnectionResult> testConnection(String provider) async {
    try {
      if (provider == 'openai') {
        if (openAiApiKey?.isEmpty ?? true) {
          return MvpConnectionResult.failure('OpenAI API key not configured');
        }

        final response = await http.get(
          Uri.parse('https://api.openai.com/v1/models'),
          headers: {
            'Authorization': 'Bearer $openAiApiKey',
          },
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          return MvpConnectionResult.success('Connected to OpenAI');
        } else if (response.statusCode == 401) {
          return MvpConnectionResult.failure('Invalid API key');
        } else {
          return MvpConnectionResult.failure('Connection failed: ${response.statusCode}');
        }
      } else if (provider == 'anthropic') {
        if (anthropicApiKey?.isEmpty ?? true) {
          return MvpConnectionResult.failure('Anthropic API key not configured');
        }

        // Anthropic doesn't have a simple test endpoint, so we send a minimal message
        final response = await http.post(
          Uri.parse('https://api.anthropic.com/v1/messages'),
          headers: {
            'x-api-key': anthropicApiKey!,
            'anthropic-version': '2023-06-01',
            'content-type': 'application/json',
          },
          body: jsonEncode({
            'model': 'claude-3-haiku-20240307',
            'max_tokens': 10,
            'messages': [{'role': 'user', 'content': 'Hi'}],
          }),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          return MvpConnectionResult.success('Connected to Anthropic');
        } else if (response.statusCode == 401) {
          return MvpConnectionResult.failure('Invalid API key');
        } else {
          return MvpConnectionResult.failure('Connection failed: ${response.statusCode}');
        }
      } else if (provider == 'ollama') {
        if (!ollamaEnabled) {
          return MvpConnectionResult.failure('Ollama not enabled');
        }

        final response = await http.get(
          Uri.parse('$ollamaBaseUrl/api/tags'),
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final models = data['models'] as List? ?? [];
          if (models.isEmpty) {
            return MvpConnectionResult.failure('Ollama running but no models installed. Run: ollama pull llama3.2');
          }
          return MvpConnectionResult.success('Connected to Ollama (${models.length} models available)');
        } else {
          return MvpConnectionResult.failure('Ollama connection failed: ${response.statusCode}');
        }
      }

      return MvpConnectionResult.failure('Unknown provider: $provider');
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused')) {
        if (provider == 'ollama') {
          return MvpConnectionResult.failure('Ollama not running. Start it with: ollama serve');
        }
        return MvpConnectionResult.failure('No internet connection');
      }
      if (e.toString().contains('TimeoutException')) {
        return MvpConnectionResult.failure('Connection timed out');
      }
      return MvpConnectionResult.failure('Connection error: $e');
    }
  }

  /// OpenAI streaming chat
  Stream<String> _chatOpenAI({
    required List<MvpMessage> messages,
    required MvpSettings settings,
    String? webSearchContext,
  }) async* {
    final systemMessage = webSearchContext != null
        ? '${settings.systemPrompt}\n\n---\nWeb Search Results:\n$webSearchContext'
        : settings.systemPrompt;

    final apiMessages = [
      {'role': 'system', 'content': systemMessage},
      ...messages.map((m) => {
        'role': m.role == MvpMessageRole.user ? 'user' : 'assistant',
        'content': m.content,
      }),
    ];

    final request = http.Request(
      'POST',
      Uri.parse('https://api.openai.com/v1/chat/completions'),
    );
    request.headers.addAll({
      'Authorization': 'Bearer $openAiApiKey',
      'Content-Type': 'application/json',
    });
    request.body = jsonEncode({
      'model': settings.selectedModel,
      'messages': apiMessages,
      'temperature': settings.temperature,
      'stream': true,
    });

    final response = await http.Client().send(request);

    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw MvpLlmException(_parseOpenAIError(response.statusCode, body));
    }

    await for (final chunk in response.stream.transform(utf8.decoder)) {
      for (final line in chunk.split('\n')) {
        if (line.startsWith('data: ') && !line.contains('[DONE]')) {
          try {
            final data = jsonDecode(line.substring(6));
            final content = data['choices']?[0]?['delta']?['content'];
            if (content != null && content.isNotEmpty) {
              yield content;
            }
          } catch (_) {
            // Skip malformed JSON
          }
        }
      }
    }
  }

  /// Anthropic streaming chat
  Stream<String> _chatAnthropic({
    required List<MvpMessage> messages,
    required MvpSettings settings,
    String? webSearchContext,
  }) async* {
    final systemMessage = webSearchContext != null
        ? '${settings.systemPrompt}\n\n---\nWeb Search Results:\n$webSearchContext'
        : settings.systemPrompt;

    final apiMessages = messages.map((m) => {
      'role': m.role == MvpMessageRole.user ? 'user' : 'assistant',
      'content': m.content,
    }).toList();

    final request = http.Request(
      'POST',
      Uri.parse('https://api.anthropic.com/v1/messages'),
    );
    request.headers.addAll({
      'x-api-key': anthropicApiKey!,
      'anthropic-version': '2023-06-01',
      'Content-Type': 'application/json',
    });
    request.body = jsonEncode({
      'model': settings.selectedModel,
      'system': systemMessage,
      'messages': apiMessages,
      'max_tokens': 4096,
      'stream': true,
    });

    final response = await http.Client().send(request);

    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw MvpLlmException(_parseAnthropicError(response.statusCode, body));
    }

    await for (final chunk in response.stream.transform(utf8.decoder)) {
      for (final line in chunk.split('\n')) {
        if (line.startsWith('data: ')) {
          try {
            final data = jsonDecode(line.substring(6));
            if (data['type'] == 'content_block_delta') {
              final content = data['delta']?['text'];
              if (content != null && content.isNotEmpty) {
                yield content;
              }
            }
          } catch (_) {
            // Skip malformed JSON
          }
        }
      }
    }
  }

  /// Ollama streaming chat (local LLM)
  Stream<String> _chatOllama({
    required List<MvpMessage> messages,
    required MvpSettings settings,
    String? webSearchContext,
  }) async* {
    final systemMessage = webSearchContext != null
        ? '${settings.systemPrompt}\n\n---\nWeb Search Results:\n$webSearchContext'
        : settings.systemPrompt;

    final apiMessages = [
      {'role': 'system', 'content': systemMessage},
      ...messages.map((m) => {
        'role': m.role == MvpMessageRole.user ? 'user' : 'assistant',
        'content': m.content,
      }),
    ];

    final request = http.Request(
      'POST',
      Uri.parse('$ollamaBaseUrl/api/chat'),
    );
    request.headers.addAll({
      'Content-Type': 'application/json',
    });
    request.body = jsonEncode({
      'model': settings.selectedModel,
      'messages': apiMessages,
      'stream': true,
      'options': {
        'temperature': settings.temperature,
      },
    });

    try {
      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        throw MvpLlmException(_parseOllamaError(response.statusCode, body));
      }

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        for (final line in chunk.split('\n')) {
          if (line.trim().isNotEmpty) {
            try {
              final data = jsonDecode(line);
              final content = data['message']?['content'];
              if (content != null && content.isNotEmpty) {
                yield content;
              }
            } catch (_) {
              // Skip malformed JSON
            }
          }
        }
      }
    } catch (e) {
      if (e is MvpLlmException) rethrow;
      if (e.toString().contains('Connection refused') ||
          e.toString().contains('SocketException')) {
        throw MvpLlmException('Ollama not running. Start it with: ollama serve');
      }
      throw MvpLlmException('Error connecting to Ollama: $e');
    }
  }

  String _parseOllamaError(int statusCode, String body) {
    if (statusCode == 404) {
      return 'Model not found. Pull it with: ollama pull <model-name>';
    }
    try {
      final json = jsonDecode(body);
      return json['error'] ?? 'Ollama error occurred';
    } catch (_) {
      return 'Error communicating with Ollama (status $statusCode)';
    }
  }

  String _parseOpenAIError(int statusCode, String body) {
    switch (statusCode) {
      case 401:
        return 'Invalid API key. Please check your OpenAI API key in settings.';
      case 429:
        return 'Rate limit exceeded. Please wait a moment and try again.';
      case 500:
      case 502:
      case 503:
        return 'OpenAI service is temporarily unavailable. Please try again later.';
      default:
        try {
          final json = jsonDecode(body);
          return json['error']?['message'] ?? 'Unknown error occurred';
        } catch (_) {
          return 'Error communicating with OpenAI (status $statusCode)';
        }
    }
  }

  String _parseAnthropicError(int statusCode, String body) {
    switch (statusCode) {
      case 401:
        return 'Invalid API key. Please check your Anthropic API key in settings.';
      case 429:
        return 'Rate limit exceeded. Please wait a moment and try again.';
      case 500:
      case 502:
      case 503:
        return 'Anthropic service is temporarily unavailable. Please try again later.';
      default:
        try {
          final json = jsonDecode(body);
          return json['error']?['message'] ?? 'Unknown error occurred';
        } catch (_) {
          return 'Error communicating with Anthropic (status $statusCode)';
        }
    }
  }
}

/// Result of a connection test
class MvpConnectionResult {
  final bool isSuccess;
  final String message;

  MvpConnectionResult._(this.isSuccess, this.message);

  factory MvpConnectionResult.success(String message) =>
      MvpConnectionResult._(true, message);

  factory MvpConnectionResult.failure(String message) =>
      MvpConnectionResult._(false, message);
}

/// LLM service exception with user-friendly message
class MvpLlmException implements Exception {
  final String message;
  MvpLlmException(this.message);

  @override
  String toString() => message;
}

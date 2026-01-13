import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Local proxy server for MVP that hides API keys from client code
///
/// This server runs locally and proxies requests to external APIs,
/// injecting the API keys server-side so they never touch the client.
///
/// Usage:
/// ```dart
/// final server = MvpProxyServer(
///   tavilyApiKey: 'tvly-xxx',
///   port: 8765,
/// );
/// await server.start();
/// // Now client can call http://localhost:8765/search instead of Tavily directly
/// ```
class MvpProxyServer {
  final String? tavilyApiKey;
  final int port;
  final int maxRequestsPerMinute;

  HttpServer? _server;
  final Map<String, List<DateTime>> _rateLimitMap = {};
  bool _isRunning = false;

  MvpProxyServer({
    this.tavilyApiKey,
    this.port = 8765,
    this.maxRequestsPerMinute = 10,
  });

  bool get isRunning => _isRunning;
  String get baseUrl => 'http://localhost:$port';

  /// Start the proxy server
  Future<void> start() async {
    if (_isRunning) return;

    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      _isRunning = true;
      print('🔐 MVP Proxy Server running at $baseUrl');

      _server!.listen(_handleRequest);
    } catch (e) {
      print('❌ Failed to start proxy server: $e');
      rethrow;
    }
  }

  /// Stop the proxy server
  Future<void> stop() async {
    if (!_isRunning) return;

    await _server?.close(force: true);
    _server = null;
    _isRunning = false;
    print('🛑 MVP Proxy Server stopped');
  }

  Future<void> _handleRequest(HttpRequest request) async {
    // Add CORS headers for local development
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type');

    // Handle preflight
    if (request.method == 'OPTIONS') {
      request.response.statusCode = 200;
      await request.response.close();
      return;
    }

    // Get client IP for rate limiting
    final clientIp = request.connectionInfo?.remoteAddress.address ?? 'unknown';

    try {
      switch (request.uri.path) {
        case '/health':
          await _handleHealth(request);
          break;
        case '/search':
          await _handleTavilySearch(request, clientIp);
          break;
        default:
          request.response.statusCode = 404;
          request.response.write(jsonEncode({'error': 'Not found'}));
      }
    } catch (e) {
      request.response.statusCode = 500;
      request.response.write(jsonEncode({'error': 'Internal server error'}));
    }

    await request.response.close();
  }

  Future<void> _handleHealth(HttpRequest request) async {
    request.response.statusCode = 200;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({
      'status': 'ok',
      'services': {
        'tavily': tavilyApiKey != null,
      },
    }));
  }

  Future<void> _handleTavilySearch(HttpRequest request, String clientIp) async {
    request.response.headers.contentType = ContentType.json;

    // Check rate limit
    if (!_checkRateLimit(clientIp)) {
      request.response.statusCode = 429;
      request.response.write(jsonEncode({
        'error': 'Rate limit exceeded',
        'message': 'Please wait before making more requests',
      }));
      return;
    }

    // Check API key
    if (tavilyApiKey == null || tavilyApiKey!.isEmpty) {
      request.response.statusCode = 503;
      request.response.write(jsonEncode({
        'error': 'Service unavailable',
        'message': 'Web search is not configured',
      }));
      return;
    }

    // Only allow POST
    if (request.method != 'POST') {
      request.response.statusCode = 405;
      request.response.write(jsonEncode({'error': 'Method not allowed'}));
      return;
    }

    try {
      // Parse request body
      final body = await utf8.decoder.bind(request).join();
      final requestData = jsonDecode(body) as Map<String, dynamic>;
      final query = requestData['query'] as String?;

      if (query == null || query.isEmpty) {
        request.response.statusCode = 400;
        request.response.write(jsonEncode({'error': 'Query is required'}));
        return;
      }

      // Forward to Tavily with API key
      final client = HttpClient();
      final tavilyRequest = await client.postUrl(
        Uri.parse('https://api.tavily.com/search'),
      );

      tavilyRequest.headers.contentType = ContentType.json;
      tavilyRequest.write(jsonEncode({
        'api_key': tavilyApiKey,
        'query': query,
        'search_depth': requestData['search_depth'] ?? 'basic',
        'include_answer': requestData['include_answer'] ?? true,
        'include_raw_content': requestData['include_raw_content'] ?? false,
        'max_results': requestData['max_results'] ?? 5,
      }));

      final tavilyResponse = await tavilyRequest.close();
      final responseBody = await utf8.decoder.bind(tavilyResponse).join();

      // Record successful request for rate limiting
      _recordRequest(clientIp);

      request.response.statusCode = tavilyResponse.statusCode;
      request.response.write(responseBody);

      client.close();
    } catch (e) {
      request.response.statusCode = 500;
      request.response.write(jsonEncode({
        'error': 'Proxy error',
        'message': e.toString(),
      }));
    }
  }

  bool _checkRateLimit(String clientIp) {
    final now = DateTime.now();
    final windowStart = now.subtract(const Duration(minutes: 1));

    // Clean up old entries
    _rateLimitMap[clientIp] = (_rateLimitMap[clientIp] ?? [])
        .where((time) => time.isAfter(windowStart))
        .toList();

    return (_rateLimitMap[clientIp]?.length ?? 0) < maxRequestsPerMinute;
  }

  void _recordRequest(String clientIp) {
    _rateLimitMap[clientIp] ??= [];
    _rateLimitMap[clientIp]!.add(DateTime.now());
  }
}

/// Singleton manager for the proxy server
class MvpProxyManager {
  static MvpProxyServer? _server;
  static bool _initializing = false;

  /// Get or create the proxy server instance
  static Future<MvpProxyServer> getServer({
    String? tavilyApiKey,
    int port = 8765,
  }) async {
    if (_server != null && _server!.isRunning) {
      return _server!;
    }

    // Prevent concurrent initialization
    if (_initializing) {
      // Wait for initialization to complete
      while (_initializing) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      if (_server != null) return _server!;
    }

    _initializing = true;
    try {
      _server = MvpProxyServer(
        tavilyApiKey: tavilyApiKey,
        port: port,
      );
      await _server!.start();
      return _server!;
    } finally {
      _initializing = false;
    }
  }

  /// Stop the server if running
  static Future<void> stop() async {
    await _server?.stop();
    _server = null;
  }

  /// Check if server is running
  static bool get isRunning => _server?.isRunning ?? false;

  /// Get base URL if running
  static String? get baseUrl => _server?.baseUrl;
}

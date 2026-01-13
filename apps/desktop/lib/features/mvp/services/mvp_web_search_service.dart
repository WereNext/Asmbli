import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/mvp_message.dart';
import 'mvp_rate_limiter.dart';

/// Web search service for MVP using Tavily API
///
/// Security features:
/// - Rate limiting to prevent abuse
/// - Supports proxy mode for API key protection
/// - Can use secure storage for API key retrieval
class MvpWebSearchService {
  final String? tavilyApiKey;
  final String? proxyBaseUrl;
  final bool useProxy;

  // Use global rate limiter for consistent limiting
  final MvpWebSearchRateLimiter _rateLimiter = MvpRateLimiters.webSearch;

  MvpWebSearchService({
    this.tavilyApiKey,
    this.proxyBaseUrl,
    this.useProxy = false,
  });

  bool get isConfigured {
    if (useProxy && proxyBaseUrl != null) {
      return true; // Proxy handles the API key
    }
    return tavilyApiKey?.isNotEmpty ?? false;
  }

  /// Search the web for a query
  /// Returns search results with sources
  Future<MvpSearchResult> search(String query) async {
    // Check rate limit first
    final rateLimitResult = _rateLimiter.checkAndRecord();
    if (!rateLimitResult.allowed) {
      return MvpSearchResult(
        content: '',
        sources: [],
        success: false,
        error: rateLimitResult.message ?? 'Rate limit exceeded',
        isRateLimited: true,
        retryAfter: rateLimitResult.waitTime,
      );
    }

    if (!isConfigured) {
      return MvpSearchResult(
        content: '',
        sources: [],
        success: false,
        error: 'Web search not configured',
      );
    }

    try {
      http.Response response;

      if (useProxy && proxyBaseUrl != null) {
        // Use local proxy - API key is handled server-side
        response = await http.post(
          Uri.parse('$proxyBaseUrl/search'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'query': query,
            'search_depth': 'basic',
            'include_answer': true,
            'include_raw_content': false,
            'max_results': 5,
          }),
        ).timeout(const Duration(seconds: 15));
      } else {
        // Direct API call
        response = await http.post(
          Uri.parse('https://api.tavily.com/search'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'api_key': tavilyApiKey,
            'query': query,
            'search_depth': 'basic',
            'include_answer': true,
            'include_raw_content': false,
            'max_results': 5,
          }),
        ).timeout(const Duration(seconds: 15));
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _parseSearchResponse(data, query);
      } else if (response.statusCode == 401) {
        return MvpSearchResult(
          content: '',
          sources: [],
          success: false,
          error: 'Invalid Tavily API key',
        );
      } else if (response.statusCode == 429) {
        return MvpSearchResult(
          content: '',
          sources: [],
          success: false,
          error: 'Tavily rate limit exceeded. Please try again later.',
          isRateLimited: true,
        );
      } else {
        return MvpSearchResult(
          content: '',
          sources: [],
          success: false,
          error: 'Search failed (status ${response.statusCode})',
        );
      }
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('TimeoutException')) {
        return MvpSearchResult(
          content: '',
          sources: [],
          success: false,
          error: 'No internet connection',
        );
      }
      return MvpSearchResult(
        content: '',
        sources: [],
        success: false,
        error: 'Search error: $e',
      );
    }
  }

  MvpSearchResult _parseSearchResponse(Map<String, dynamic> data, String query) {
    final results = data['results'] as List? ?? [];
    final sources = results.map<MvpSource>((r) => MvpSource(
      title: r['title'] as String? ?? 'Unknown',
      url: r['url'] as String? ?? '',
      snippet: r['content'] as String?,
    )).toList();

    final contextBuilder = StringBuffer();
    contextBuilder.writeln('Search Query: $query\n');

    final answer = data['answer'] as String?;
    if (answer != null && answer.isNotEmpty) {
      contextBuilder.writeln('Summary: $answer\n');
    }

    contextBuilder.writeln('Sources:');
    for (var i = 0; i < sources.length && i < 5; i++) {
      final source = sources[i];
      contextBuilder.writeln('\n[${i + 1}] ${source.title}');
      contextBuilder.writeln('URL: ${source.url}');
      if (source.snippet != null) {
        final snippet = source.snippet!.length > 300
            ? '${source.snippet!.substring(0, 300)}...'
            : source.snippet!;
        contextBuilder.writeln('Content: $snippet');
      }
    }

    return MvpSearchResult(
      content: contextBuilder.toString(),
      sources: sources,
      success: true,
    );
  }

  int get remainingRequests => _rateLimiter.remainingRequests;

  bool shouldSearch(String query) {
    final lowerQuery = query.toLowerCase();

    final currentInfoKeywords = [
      'latest', 'recent', 'current', 'today', 'this week', 'this month',
      'this year', '2024', '2025', '2026', 'news', 'update', 'development',
      'announce', 'release', 'launch', 'new', 'what happened',
      "what's happening", 'who won', 'price of', 'stock', 'weather',
      'score', 'result', 'election',
    ];

    for (final keyword in currentInfoKeywords) {
      if (lowerQuery.contains(keyword)) return true;
    }

    final topicsNeedingSearch = [
      'quantum computing', 'ai ', 'artificial intelligence', 'machine learning',
      'crypto', 'bitcoin', 'ethereum', 'spacex', 'tesla', 'openai',
      'anthropic', 'google', 'microsoft', 'apple', 'meta',
    ];

    for (final topic in topicsNeedingSearch) {
      if (lowerQuery.contains(topic)) {
        if (lowerQuery.contains('?') ||
            lowerQuery.startsWith('what') ||
            lowerQuery.startsWith('how') ||
            lowerQuery.startsWith('when') ||
            lowerQuery.startsWith('who') ||
            lowerQuery.startsWith('where') ||
            lowerQuery.startsWith('why') ||
            lowerQuery.startsWith('tell me')) {
          return true;
        }
      }
    }

    return false;
  }
}

class MvpSearchResult {
  final String content;
  final List<MvpSource> sources;
  final bool success;
  final String? error;
  final bool isRateLimited;
  final Duration? retryAfter;

  MvpSearchResult({
    required this.content,
    required this.sources,
    required this.success,
    this.error,
    this.isRateLimited = false,
    this.retryAfter,
  });
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/mvp_message.dart';

/// Web search service for MVP using Tavily API
/// Tavily is recommended for AI applications - has good free tier
/// Sign up at: https://tavily.com
class MvpWebSearchService {
  final String? tavilyApiKey;

  MvpWebSearchService({this.tavilyApiKey});

  bool get isConfigured => tavilyApiKey?.isNotEmpty ?? false;

  /// Search the web for a query
  /// Returns search results with sources
  Future<MvpSearchResult> search(String query) async {
    if (!isConfigured) {
      // Return empty result if not configured - web search is optional
      return MvpSearchResult(
        content: '',
        sources: [],
        success: false,
        error: 'Web search not configured',
      );
    }

    try {
      final response = await http.post(
        Uri.parse('https://api.tavily.com/search'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'api_key': tavilyApiKey,
          'query': query,
          'search_depth': 'basic',
          'include_answer': true,
          'include_raw_content': false,
          'max_results': 5,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Extract sources from results
        final results = data['results'] as List? ?? [];
        final sources = results.map<MvpSource>((r) => MvpSource(
          title: r['title'] as String? ?? 'Unknown',
          url: r['url'] as String? ?? '',
          snippet: r['content'] as String?,
        )).toList();

        // Build context string for LLM
        final contextBuilder = StringBuffer();
        contextBuilder.writeln('Search Query: $query\n');

        // Include Tavily's generated answer if available
        final answer = data['answer'] as String?;
        if (answer != null && answer.isNotEmpty) {
          contextBuilder.writeln('Summary: $answer\n');
        }

        // Include source snippets
        contextBuilder.writeln('Sources:');
        for (var i = 0; i < sources.length && i < 5; i++) {
          final source = sources[i];
          contextBuilder.writeln('\n[${ i + 1}] ${source.title}');
          contextBuilder.writeln('URL: ${source.url}');
          if (source.snippet != null) {
            // Truncate long snippets
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
      } else if (response.statusCode == 401) {
        return MvpSearchResult(
          content: '',
          sources: [],
          success: false,
          error: 'Invalid Tavily API key',
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

  /// Detect if a query likely needs web search
  /// This is a simple heuristic - could be improved with LLM classification
  bool shouldSearch(String query) {
    final lowerQuery = query.toLowerCase();

    // Keywords indicating need for current information
    final currentInfoKeywords = [
      'latest',
      'recent',
      'current',
      'today',
      'this week',
      'this month',
      'this year',
      '2024',
      '2025',
      '2026',
      'news',
      'update',
      'development',
      'announce',
      'release',
      'launch',
      'new',
      'what happened',
      'what\'s happening',
      'who won',
      'price of',
      'stock',
      'weather',
      'score',
      'result',
      'election',
    ];

    // Check for current info keywords
    for (final keyword in currentInfoKeywords) {
      if (lowerQuery.contains(keyword)) {
        return true;
      }
    }

    // Questions about specific topics that need current data
    final topicsNeedingSearch = [
      'quantum computing',
      'ai ',
      'artificial intelligence',
      'machine learning',
      'crypto',
      'bitcoin',
      'ethereum',
      'spacex',
      'tesla',
      'openai',
      'anthropic',
      'google',
      'microsoft',
      'apple',
      'meta',
    ];

    for (final topic in topicsNeedingSearch) {
      if (lowerQuery.contains(topic)) {
        // Only search if it seems like a question about recent events
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

/// Result of a web search
class MvpSearchResult {
  final String content;
  final List<MvpSource> sources;
  final bool success;
  final String? error;

  MvpSearchResult({
    required this.content,
    required this.sources,
    required this.success,
    this.error,
  });
}

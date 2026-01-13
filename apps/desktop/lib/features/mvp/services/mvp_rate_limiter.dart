import 'dart:collection';

/// Rate limiter for MVP API calls
/// Implements token bucket algorithm with configurable limits
class MvpRateLimiter {
  final int maxRequests;
  final Duration window;
  final Queue<DateTime> _requestTimestamps = Queue();

  MvpRateLimiter({
    this.maxRequests = 10,
    this.window = const Duration(minutes: 1),
  });

  /// Check if a request can proceed
  bool canMakeRequest() {
    _cleanupOldRequests();
    return _requestTimestamps.length < maxRequests;
  }

  /// Record a request (call after canMakeRequest returns true)
  void recordRequest() {
    _cleanupOldRequests();
    _requestTimestamps.addLast(DateTime.now());
  }

  /// Get remaining requests in current window
  int get remainingRequests {
    _cleanupOldRequests();
    return maxRequests - _requestTimestamps.length;
  }

  /// Get time until next request is available (if rate limited)
  Duration? get timeUntilNextRequest {
    _cleanupOldRequests();
    if (_requestTimestamps.length < maxRequests) {
      return null; // Not rate limited
    }

    final oldestRequest = _requestTimestamps.first;
    final windowEnd = oldestRequest.add(window);
    final now = DateTime.now();

    if (windowEnd.isAfter(now)) {
      return windowEnd.difference(now);
    }
    return null;
  }

  /// Reset the rate limiter
  void reset() {
    _requestTimestamps.clear();
  }

  void _cleanupOldRequests() {
    final cutoff = DateTime.now().subtract(window);
    while (_requestTimestamps.isNotEmpty &&
        _requestTimestamps.first.isBefore(cutoff)) {
      _requestTimestamps.removeFirst();
    }
  }
}

/// Rate limiter specifically for web search with appropriate defaults
class MvpWebSearchRateLimiter extends MvpRateLimiter {
  MvpWebSearchRateLimiter()
      : super(
          // Tavily free tier: 1000 requests/month ≈ 33/day ≈ 2/hour to be safe
          // Being conservative: 10 requests per minute max
          maxRequests: 10,
          window: const Duration(minutes: 1),
        );

  /// Rate limit result with user-friendly message
  RateLimitResult checkAndRecord() {
    if (!canMakeRequest()) {
      final waitTime = timeUntilNextRequest;
      return RateLimitResult(
        allowed: false,
        message: waitTime != null
            ? 'Rate limit reached. Please wait ${waitTime.inSeconds} seconds.'
            : 'Rate limit reached. Please try again shortly.',
        waitTime: waitTime,
      );
    }

    recordRequest();
    return RateLimitResult(
      allowed: true,
      remainingRequests: remainingRequests,
    );
  }
}

/// Result of a rate limit check
class RateLimitResult {
  final bool allowed;
  final String? message;
  final Duration? waitTime;
  final int? remainingRequests;

  RateLimitResult({
    required this.allowed,
    this.message,
    this.waitTime,
    this.remainingRequests,
  });
}

/// Global rate limiters for MVP
/// Use these singletons to ensure consistent rate limiting across the app
class MvpRateLimiters {
  static final webSearch = MvpWebSearchRateLimiter();

  // LLM rate limiter - more generous since users pay for API
  static final llm = MvpRateLimiter(
    maxRequests: 30,
    window: const Duration(minutes: 1),
  );

  /// Reset all rate limiters
  static void resetAll() {
    webSearch.reset();
    llm.reset();
  }
}

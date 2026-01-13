/// MVP Message model - simplified for vertical slice
class MvpMessage {
  final String id;
  final String content;
  final MvpMessageRole role;
  final DateTime timestamp;
  final List<MvpSource>? sources;
  final bool isStreaming;

  MvpMessage({
    required this.id,
    required this.content,
    required this.role,
    required this.timestamp,
    this.sources,
    this.isStreaming = false,
  });

  MvpMessage copyWith({
    String? id,
    String? content,
    MvpMessageRole? role,
    DateTime? timestamp,
    List<MvpSource>? sources,
    bool? isStreaming,
  }) {
    return MvpMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      role: role ?? this.role,
      timestamp: timestamp ?? this.timestamp,
      sources: sources ?? this.sources,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'role': role.name,
        'timestamp': timestamp.toIso8601String(),
        'sources': sources?.map((s) => s.toJson()).toList(),
      };

  factory MvpMessage.fromJson(Map<String, dynamic> json) => MvpMessage(
        id: json['id'] as String,
        content: json['content'] as String,
        role: MvpMessageRole.values.byName(json['role'] as String),
        timestamp: DateTime.parse(json['timestamp'] as String),
        sources: (json['sources'] as List?)
            ?.map((s) => MvpSource.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}

enum MvpMessageRole {
  user,
  assistant,
  system,
}

/// Source citation for web search results
class MvpSource {
  final String title;
  final String url;
  final String? snippet;

  MvpSource({
    required this.title,
    required this.url,
    this.snippet,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'url': url,
        'snippet': snippet,
      };

  factory MvpSource.fromJson(Map<String, dynamic> json) => MvpSource(
        title: json['title'] as String,
        url: json['url'] as String,
        snippet: json['snippet'] as String?,
      );
}

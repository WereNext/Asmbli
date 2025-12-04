import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/design_system.dart';
import 'rich_text_message_widget.dart';

/// Represents a streaming message state with optimized content caching
class StreamingMessageState {
  final String id;
  final String conversationId;
  final String initialMessage;
  final List<String> streamedTokens;
  final List<MCPToolResult> toolResults;
  final List<MCPResourceData> resourceData;
  final bool isComplete;
  final String? error;
  final String? processingStatus;
  final Map<String, dynamic> metadata;

  // Cached full content to avoid O(n²) string concatenation
  String? _cachedFullContent;
  int? _cachedTokenCount;

  StreamingMessageState({
    required this.id,
    required this.conversationId,
    required this.initialMessage,
    this.streamedTokens = const [],
    this.toolResults = const [],
    this.resourceData = const [],
    this.isComplete = false,
    this.error,
    this.processingStatus,
    this.metadata = const {},
  });

  StreamingMessageState copyWith({
    List<String>? streamedTokens,
    List<MCPToolResult>? toolResults,
    List<MCPResourceData>? resourceData,
    bool? isComplete,
    String? error,
    String? processingStatus,
    bool clearProcessingStatus = false,
    Map<String, dynamic>? metadata,
  }) {
    return StreamingMessageState(
      id: id,
      conversationId: conversationId,
      initialMessage: initialMessage,
      streamedTokens: streamedTokens ?? this.streamedTokens,
      toolResults: toolResults ?? this.toolResults,
      resourceData: resourceData ?? this.resourceData,
      isComplete: isComplete ?? this.isComplete,
      error: error ?? this.error,
      processingStatus: clearProcessingStatus ? null : (processingStatus ?? this.processingStatus),
      metadata: metadata ?? this.metadata,
    );
  }

  /// Optimized full content getter with StringBuffer caching
  /// Eliminates O(n²) complexity from repeated string concatenation
  String get fullContent {
    // Return cached result if token count hasn't changed
    if (_cachedFullContent != null && _cachedTokenCount == streamedTokens.length) {
      return _cachedFullContent!;
    }

    // Build full content using StringBuffer (O(n) instead of O(n²))
    if (streamedTokens.isEmpty) {
      _cachedFullContent = initialMessage;
    } else {
      final buffer = StringBuffer(initialMessage);
      for (final token in streamedTokens) {
        buffer.write(token);
      }
      _cachedFullContent = buffer.toString();
    }

    _cachedTokenCount = streamedTokens.length;
    return _cachedFullContent!;
  }
}

/// MCP Tool execution result for display
class MCPToolResult {
  final String serverId;
  final String toolName;
  final Map<String, dynamic> arguments;
  final dynamic result;
  final bool success;
  final String? error;
  final DateTime timestamp;

  const MCPToolResult({
    required this.serverId,
    required this.toolName,
    required this.arguments,
    required this.result,
    required this.success,
    this.error,
    required this.timestamp,
  });
}

/// MCP Resource data for display
class MCPResourceData {
  final String serverId;
  final String resourceUri;
  final String content;
  final bool success;
  final String? error;

  const MCPResourceData({
    required this.serverId,
    required this.resourceUri,
    required this.content,
    required this.success,
    this.error,
  });
}

/// Provider for managing streaming message states
class StreamingMessageNotifier extends StateNotifier<Map<String, StreamingMessageState>> {
  StreamingMessageNotifier() : super({});

  void startStreaming(String messageId, String conversationId, String initialMessage) {
    state = {
      ...state,
      messageId: StreamingMessageState(
        id: messageId,
        conversationId: conversationId,
        initialMessage: initialMessage,
      ),
    };
  }

  /// Add a batch of tokens (optimized for 50ms batches from streaming)
  /// This reduces state updates and UI rebuilds significantly
  void addStreamedToken(String messageId, String token) {
    final current = state[messageId];
    if (current != null) {
      // Instead of creating new list, we append the batch as a single token
      // This works with our new buffered streaming approach
      state = {
        ...state,
        messageId: current.copyWith(
          streamedTokens: [...current.streamedTokens, token],
        ),
      };
    }
  }

  void addToolResult(String messageId, MCPToolResult result) {
    final current = state[messageId];
    if (current != null) {
      state = {
        ...state,
        messageId: current.copyWith(
          toolResults: [...current.toolResults, result],
        ),
      };
    }
  }

  void addResourceData(String messageId, MCPResourceData data) {
    final current = state[messageId];
    if (current != null) {
      state = {
        ...state,
        messageId: current.copyWith(
          resourceData: [...current.resourceData, data],
        ),
      };
    }
  }

  /// Update the processing status message shown during streaming
  void updateProcessingStatus(String messageId, String status) {
    final current = state[messageId];
    if (current != null) {
      state = {
        ...state,
        messageId: current.copyWith(
          processingStatus: status,
        ),
      };
    }
  }

  void completeStreaming(String messageId, {String? error, Map<String, dynamic>? metadata}) {
    final current = state[messageId];
    if (current != null) {
      state = {
        ...state,
        messageId: current.copyWith(
          isComplete: true,
          error: error,
          metadata: metadata ?? {},
        ),
      };
    }
  }

  void removeStreamingMessage(String messageId) {
    state = Map.from(state)..remove(messageId);
  }
}

final streamingMessageProvider = StateNotifierProvider<StreamingMessageNotifier, Map<String, StreamingMessageState>>((ref) {
  return StreamingMessageNotifier();
});

/// Optimized provider that only watches a specific message
/// This prevents unnecessary rebuilds when other messages update
final streamingMessageStateProvider = Provider.family<StreamingMessageState?, String>((ref, messageId) {
  final allStates = ref.watch(streamingMessageProvider);
  return allStates[messageId];
});

/// Widget for displaying streaming messages with MCP integration
class StreamingMessageWidget extends ConsumerWidget {
  final String messageId;
  final String role;
  final VoidCallback? onComplete;

  const StreamingMessageWidget({
    super.key,
    required this.messageId,
    required this.role,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // OPTIMIZATION: Use family provider to only rebuild THIS message widget
    // when THIS specific message changes, not when ANY message changes
    final streamingState = ref.watch(streamingMessageStateProvider(messageId));

    if (streamingState == null) {
      return const SizedBox.shrink();
    }

    final isUser = role == 'user';

    return Container(
      margin: EdgeInsets.only(
        bottom: SpacingTokens.lg,
        left: isUser ? SpacingTokens.xxl : 0,
        right: isUser ? 0 : SpacingTokens.xxl,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _buildAvatar(context, isUser),
            const SizedBox(width: SpacingTokens.md),
          ],
          
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Main message bubble
                _buildMessageBubble(context, streamingState, isUser),
                
                // MCP tool results
                if (streamingState.toolResults.isNotEmpty)
                  _buildToolResults(context, streamingState.toolResults),
                
                // Resource data
                if (streamingState.resourceData.isNotEmpty)
                  _buildResourceData(context, streamingState.resourceData),
                
                // Streaming status
                if (!streamingState.isComplete)
                  _buildStreamingStatus(context, streamingState.processingStatus),
                
                // Error display
                if (streamingState.error != null)
                  _buildErrorDisplay(context, streamingState.error!),
              ],
            ),
          ),
          
          if (isUser) ...[
            const SizedBox(width: SpacingTokens.md),
            _buildAvatar(context, isUser),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, bool isUser) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: isUser 
        ? ThemeColors(context).primary.withValues(alpha: 0.1)
        : ThemeColors(context).primary,
      child: Icon(
        isUser ? Icons.person : Icons.smart_toy,
        size: 20,
        color: isUser 
          ? ThemeColors(context).primary
          : ThemeColors(context).onPrimary,
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, StreamingMessageState state, bool isUser) {
    final theme = Theme.of(context);
    
    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
      padding: const EdgeInsets.all(SpacingTokens.md),
      decoration: BoxDecoration(
        color: isUser 
          ? ThemeColors(context).primary.withValues(alpha: 0.1)
          : ThemeColors(context).surface,
        borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
        border: isUser 
          ? Border.all(color: ThemeColors(context).primary.withValues(alpha: 0.3))
          : Border.all(color: ThemeColors(context).border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Message content with streaming cursor
          _buildMessageContent(context, state, isUser),
          
          // Metadata (token count, processing time, etc.)
          if (state.metadata.isNotEmpty && state.isComplete)
            _buildMetadata(context, state.metadata),
        ],
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context, StreamingMessageState state, bool isUser) {
    print('DEBUG STREAMING: isComplete=${state.isComplete}, isUser=$isUser, contentLength=${state.fullContent.length}');
    print('DEBUG STREAMING: fullContent preview: ${state.fullContent.length > 50 ? state.fullContent.substring(0, 50) : state.fullContent}...');
    
    // If streaming is complete and it's an AI response, use rich text widget
    if (state.isComplete && !isUser && state.fullContent.isNotEmpty) {
      print('DEBUG STREAMING: Using RichTextMessageWidget');
      return RichTextMessageWidget(
        content: state.fullContent,
        isStreaming: false,
        isDarkTheme: Theme.of(context).brightness == Brightness.dark,
      );
    }
    
    print('DEBUG STREAMING: Using fallback RichText widget');
    
    // For streaming or user messages, use the current approach
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: state.fullContent,
            style: TextStyles.bodyMedium.copyWith(
              color: isUser 
                ? ThemeColors(context).primary
                : ThemeColors(context).onSurface,
            ),
          ),
          // Streaming cursor
          if (!state.isComplete)
            const WidgetSpan(
              child: AnimatedStreamingCursor(),
            ),
        ],
      ),
    );
  }

  Widget _buildToolResults(BuildContext context, List<MCPToolResult> toolResults) {
    return Container(
      margin: const EdgeInsets.only(top: SpacingTokens.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🔧 MCP Tool Results',
            style: TextStyles.caption.copyWith(
              color: ThemeColors(context).onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: SpacingTokens.xs),
          ...toolResults.map((result) => _buildSingleToolResult(context, result)),
        ],
      ),
    );
  }

  Widget _buildSingleToolResult(BuildContext context, MCPToolResult result) {
    return Container(
      margin: const EdgeInsets.only(bottom: SpacingTokens.xs),
      padding: const EdgeInsets.all(SpacingTokens.sm),
      decoration: BoxDecoration(
        color: result.success 
          ? ThemeColors(context).success.withValues(alpha: 0.1)
          : ThemeColors(context).error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
        border: Border.all(
          color: result.success 
            ? ThemeColors(context).success.withValues(alpha: 0.3)
            : ThemeColors(context).error.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                result.success ? Icons.check_circle_outline : Icons.error_outline,
                size: 16,
                color: result.success 
                  ? ThemeColors(context).success
                  : ThemeColors(context).error,
              ),
              const SizedBox(width: SpacingTokens.xs),
              Text(
                '${result.serverId}/${result.toolName}',
                style: TextStyles.caption.copyWith(
                  color: ThemeColors(context).onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                _formatTimestamp(result.timestamp),
                style: TextStyles.caption.copyWith(
                  color: ThemeColors(context).onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (result.success && result.result != null) ...[
            const SizedBox(height: SpacingTokens.xs),
            Text(
              _formatToolResult(result.result),
              style: TextStyles.caption.copyWith(
                color: ThemeColors(context).onSurfaceVariant,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (!result.success && result.error != null) ...[
            const SizedBox(height: SpacingTokens.xs),
            Text(
              result.error!,
              style: TextStyles.caption.copyWith(
                color: ThemeColors(context).error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResourceData(BuildContext context, List<MCPResourceData> resourceData) {
    return Container(
      margin: const EdgeInsets.only(top: SpacingTokens.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📄 Resource Data',
            style: TextStyles.caption.copyWith(
              color: ThemeColors(context).onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: SpacingTokens.xs),
          ...resourceData.map((data) => _buildSingleResourceData(context, data)),
        ],
      ),
    );
  }

  Widget _buildSingleResourceData(BuildContext context, MCPResourceData data) {
    return Container(
      margin: const EdgeInsets.only(bottom: SpacingTokens.xs),
      padding: const EdgeInsets.all(SpacingTokens.sm),
      decoration: BoxDecoration(
        color: ThemeColors(context).surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
        border: Border.all(color: ThemeColors(context).border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.description_outlined,
                size: 16,
                color: ThemeColors(context).onSurfaceVariant,
              ),
              const SizedBox(width: SpacingTokens.xs),
              Expanded(
                child: Text(
                  '${data.serverId}: ${data.resourceUri}',
                  style: TextStyles.caption.copyWith(
                    color: ThemeColors(context).onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.xs),
          Text(
            data.content.length > 200 ? '${data.content.substring(0, 200)}...' : data.content,
            style: TextStyles.caption.copyWith(
              color: ThemeColors(context).onSurfaceVariant,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStreamingStatus(BuildContext context, [String? status]) {
    final statusText = status ?? 'Processing with MCP servers...';
    return Container(
      margin: const EdgeInsets.only(top: SpacingTokens.xs),
      padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.sm, vertical: SpacingTokens.xs),
      decoration: BoxDecoration(
        color: ThemeColors(context).primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
        border: Border.all(
          color: ThemeColors(context).primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              color: ThemeColors(context).primary,
              strokeWidth: 2,
            ),
          ),
          const SizedBox(width: SpacingTokens.sm),
          Flexible(
            child: Text(
              statusText,
              style: TextStyles.caption.copyWith(
                color: ThemeColors(context).primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorDisplay(BuildContext context, String error) {
    return Container(
      margin: const EdgeInsets.only(top: SpacingTokens.sm),
      padding: const EdgeInsets.all(SpacingTokens.sm),
      decoration: BoxDecoration(
        color: ThemeColors(context).error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
        border: Border.all(color: ThemeColors(context).error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 16,
            color: ThemeColors(context).error,
          ),
          const SizedBox(width: SpacingTokens.xs),
          Expanded(
            child: Text(
              error,
              style: TextStyles.caption.copyWith(
                color: ThemeColors(context).error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadata(BuildContext context, Map<String, dynamic> metadata) {
    return Container(
      margin: const EdgeInsets.only(top: SpacingTokens.sm),
      padding: const EdgeInsets.all(SpacingTokens.xs),
      decoration: BoxDecoration(
        color: ThemeColors(context).surfaceVariant.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (metadata['toolsUsed'] != null) ...[
            Icon(
              Icons.build_outlined,
              size: 12,
              color: ThemeColors(context).onSurfaceVariant,
            ),
            const SizedBox(width: SpacingTokens.xs),
            Text(
              '${metadata['toolsUsed'].length} tools',
              style: TextStyles.caption.copyWith(
                color: ThemeColors(context).onSurfaceVariant,
                fontSize: 10,
              ),
            ),
            const SizedBox(width: SpacingTokens.sm),
          ],
          if (metadata['processingTime'] != null) ...[
            Icon(
              Icons.timer_outlined,
              size: 12,
              color: ThemeColors(context).onSurfaceVariant,
            ),
            const SizedBox(width: SpacingTokens.xs),
            Text(
              '${metadata['processingTime']}ms',
              style: TextStyles.caption.copyWith(
                color: ThemeColors(context).onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatToolResult(dynamic result) {
    if (result is String) {
      return result;
    } else if (result is Map) {
      return result.toString();
    } else if (result is List) {
      return '${result.length} items';
    }
    return result.toString();
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }
    return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}

/// Animated cursor for streaming text
class AnimatedStreamingCursor extends StatefulWidget {
  const AnimatedStreamingCursor({super.key});

  @override
  _AnimatedStreamingCursorState createState() => _AnimatedStreamingCursorState();
}

class _AnimatedStreamingCursorState extends State<AnimatedStreamingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 2,
          height: 16,
          margin: const EdgeInsets.only(left: 2),
          decoration: BoxDecoration(
            color: ThemeColors(context).primary.withValues(alpha: _animation.value),
            borderRadius: BorderRadius.circular(1),
          ),
        );
      },
    );
  }
}
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../models/mvp_message.dart';
import '../../models/mvp_settings.dart';
import '../../services/mvp_llm_service.dart';
import '../../services/mvp_storage_service.dart';
import '../../services/mvp_web_search_service.dart';
import '../widgets/mvp_message_bubble.dart';
import '../widgets/mvp_source_citation.dart';

/// MVP Chat Screen - Core conversational experience
class MvpChatScreen extends StatefulWidget {
  const MvpChatScreen({super.key});

  @override
  State<MvpChatScreen> createState() => _MvpChatScreenState();
}

class _MvpChatScreenState extends State<MvpChatScreen> {
  final _storage = MvpStorageService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  MvpLlmService? _llmService;
  MvpWebSearchService? _webSearchService;
  MvpSettings _settings = MvpSettings.defaults();
  List<MvpMessage> _messages = [];

  bool _initialized = false;
  bool _isLoading = false;
  bool _isSearching = false;
  String? _errorMessage;
  String _currentStreamingContent = '';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _storage.initialize();

    // Load settings and messages
    _settings = _storage.getSettings();
    _messages = _storage.getMessages();

    // Initialize services
    _llmService = MvpLlmService(
      openAiApiKey: _storage.getOpenAiApiKey(),
      anthropicApiKey: _storage.getAnthropicApiKey(),
    );
    _webSearchService = MvpWebSearchService(
      tavilyApiKey: _storage.getTavilyApiKey(),
    );

    setState(() => _initialized = true);

    // Scroll to bottom if there are messages
    if (_messages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isLoading) return;

    // Check if LLM is configured
    if (!(_llmService?.isConfigured ?? false)) {
      setState(() {
        _errorMessage = 'No API key configured. Please set up your API key in settings.';
      });
      return;
    }

    // Clear input and error
    _messageController.clear();
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    // Add user message
    final userMessage = MvpMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      role: MvpMessageRole.user,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
    });
    _scrollToBottom();

    try {
      // Check if we need web search
      String? webSearchContext;
      List<MvpSource>? sources;

      if (_settings.webSearchEnabled &&
          (_webSearchService?.isConfigured ?? false) &&
          _webSearchService!.shouldSearch(content)) {
        setState(() => _isSearching = true);

        final searchResult = await _webSearchService!.search(content);

        setState(() => _isSearching = false);

        if (searchResult.success) {
          webSearchContext = searchResult.content;
          sources = searchResult.sources;
        }
      }

      // Create placeholder for streaming response
      final assistantMessageId =
          '${DateTime.now().millisecondsSinceEpoch}_assistant';
      setState(() {
        _currentStreamingContent = '';
        _messages.add(MvpMessage(
          id: assistantMessageId,
          content: '',
          role: MvpMessageRole.assistant,
          timestamp: DateTime.now(),
          sources: sources,
          isStreaming: true,
        ));
      });
      _scrollToBottom();

      // Stream response
      await for (final chunk in _llmService!.chat(
        messages: _messages.where((m) => !m.isStreaming).toList(),
        settings: _settings,
        webSearchContext: webSearchContext,
      )) {
        _currentStreamingContent += chunk;
        setState(() {
          // Update the last message with new content
          final index = _messages.indexWhere((m) => m.id == assistantMessageId);
          if (index != -1) {
            _messages[index] = _messages[index].copyWith(
              content: _currentStreamingContent,
            );
          }
        });
        _scrollToBottom();
      }

      // Finalize message
      setState(() {
        final index = _messages.indexWhere((m) => m.id == assistantMessageId);
        if (index != -1) {
          _messages[index] = _messages[index].copyWith(
            isStreaming: false,
          );
        }
      });

      // Save messages
      await _storage.saveMessages(_messages);
    } on MvpLlmException catch (e) {
      setState(() {
        _errorMessage = e.message;
        // Remove the streaming message if it was added
        _messages.removeWhere((m) => m.isStreaming);
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
        _messages.removeWhere((m) => m.isStreaming);
      });
    } finally {
      setState(() {
        _isLoading = false;
        _isSearching = false;
        _currentStreamingContent = '';
      });
    }
  }

  Future<void> _clearConversation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Conversation'),
        content: const Text('Are you sure you want to clear all messages?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _storage.clearMessages();
      setState(() {
        _messages = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ThemeColors(context);

    if (!_initialized) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.5,
              colors: [
                colors.backgroundGradientStart,
                colors.backgroundGradientMiddle,
                colors.backgroundGradientEnd,
              ],
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    final isConfigured = _llmService?.isConfigured ?? false;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.5,
            colors: [
              colors.backgroundGradientStart,
              colors.backgroundGradientMiddle,
              colors.backgroundGradientEnd,
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _ChatHeader(
                agentName: _settings.agentName,
                onSettingsTap: () => context.go('/mvp/settings'),
                onClearTap: _messages.isNotEmpty ? _clearConversation : null,
              ),

              // Not configured banner
              if (!isConfigured)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(SpacingTokens.componentSpacing),
                  color: colors.warning.withValues(alpha: 0.1),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: colors.warning, size: 20),
                      const SizedBox(width: SpacingTokens.iconSpacing),
                      Expanded(
                        child: Text(
                          'No API key configured',
                          style: TextStyles.bodySmall.copyWith(
                            color: colors.warning,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go('/mvp/setup'),
                        child: Text(
                          'Set up',
                          style: TextStyles.bodySmall.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Messages area
              Expanded(
                child: _messages.isEmpty
                    ? _EmptyState(
                        onExampleTap: (text) {
                          _messageController.text = text;
                          _sendMessage();
                        },
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: SpacingTokens.pageHorizontal,
                          vertical: SpacingTokens.componentSpacing,
                        ),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              MvpMessageBubble(
                                message: message,
                                isStreaming: message.isStreaming,
                              ),
                              if (message.sources != null &&
                                  message.sources!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: SpacingTokens.iconSpacing,
                                    bottom: SpacingTokens.componentSpacing,
                                  ),
                                  child: MvpSourceCitation(
                                    sources: message.sources!,
                                  ),
                                ),
                              const SizedBox(height: SpacingTokens.componentSpacing),
                            ],
                          );
                        },
                      ),
              ),

              // Search indicator
              if (_isSearching)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SpacingTokens.pageHorizontal,
                    vertical: SpacingTokens.iconSpacing,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(width: SpacingTokens.iconSpacing),
                      Text(
                        'Searching the web...',
                        style: TextStyles.bodySmall.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

              // Error message
              if (_errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(SpacingTokens.componentSpacing),
                  margin: const EdgeInsets.symmetric(
                    horizontal: SpacingTokens.pageHorizontal,
                  ),
                  decoration: BoxDecoration(
                    color: colors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: colors.error, size: 20),
                      const SizedBox(width: SpacingTokens.iconSpacing),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyles.bodySmall.copyWith(
                            color: colors.error,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: colors.error, size: 16),
                        onPressed: () => setState(() => _errorMessage = null),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

              // Input area
              Container(
                padding: const EdgeInsets.all(SpacingTokens.componentSpacing),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        focusNode: _focusNode,
                        enabled: !_isLoading,
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        style: TextStyles.bodyMedium.copyWith(
                          color: colors.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Ask anything...',
                          hintStyle: TextStyles.bodyMedium.copyWith(
                            color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                          filled: true,
                          fillColor: colors.surface,
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(BorderRadiusTokens.lg),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: SpacingTokens.componentSpacing,
                            vertical: SpacingTokens.componentSpacing,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: SpacingTokens.iconSpacing),
                    IconButton(
                      onPressed: _isLoading ? null : _sendMessage,
                      icon: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.primary,
                              ),
                            )
                          : Icon(
                              Icons.send,
                              color: colors.primary,
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  final String agentName;
  final VoidCallback onSettingsTap;
  final VoidCallback? onClearTap;

  const _ChatHeader({
    required this.agentName,
    required this.onSettingsTap,
    this.onClearTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = ThemeColors(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.componentSpacing,
        vertical: SpacingTokens.iconSpacing,
      ),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.8),
        border: Border(
          bottom: BorderSide(color: colors.border.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(SpacingTokens.iconSpacing),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
            ),
            child: Icon(
              Icons.psychology_alt,
              size: 20,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: SpacingTokens.componentSpacing),
          Expanded(
            child: Text(
              agentName,
              style: TextStyles.sectionTitle.copyWith(
                color: colors.onSurface,
              ),
            ),
          ),
          if (onClearTap != null)
            IconButton(
              icon: Icon(Icons.delete_outline, color: colors.onSurfaceVariant),
              onPressed: onClearTap,
              tooltip: 'Clear conversation',
            ),
          IconButton(
            icon: Icon(Icons.settings, color: colors.onSurfaceVariant),
            onPressed: onSettingsTap,
            tooltip: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final void Function(String) onExampleTap;

  const _EmptyState({required this.onExampleTap});

  @override
  Widget build(BuildContext context) {
    final colors = ThemeColors(context);

    final examples = [
      'What are the latest developments in quantum computing?',
      'Explain machine learning in simple terms',
      'Help me plan a weekend trip to Paris',
    ];

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.pageHorizontal),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: colors.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: SpacingTokens.componentSpacing),
            Text(
              'Start a conversation',
              style: TextStyles.sectionTitle.copyWith(
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: SpacingTokens.iconSpacing),
            Text(
              'Try one of these examples:',
              style: TextStyles.bodySmall.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: SpacingTokens.sectionSpacing),
            ...examples.map((example) => Padding(
                  padding:
                      const EdgeInsets.only(bottom: SpacingTokens.iconSpacing),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onExampleTap(example),
                      borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxWidth: 400),
                        padding:
                            const EdgeInsets.all(SpacingTokens.componentSpacing),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius:
                              BorderRadius.circular(BorderRadiusTokens.sm),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              size: 16,
                              color: colors.primary,
                            ),
                            const SizedBox(width: SpacingTokens.iconSpacing),
                            Expanded(
                              child: Text(
                                example,
                                style: TextStyles.bodySmall.copyWith(
                                  color: colors.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

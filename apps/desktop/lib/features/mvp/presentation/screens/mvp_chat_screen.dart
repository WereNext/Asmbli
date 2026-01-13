import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/theme/color_schemes.dart';
import '../../../../main_mvp.dart';
import '../../models/mvp_message.dart';
import '../../models/mvp_settings.dart';
import '../../services/mvp_llm_service.dart';
import '../../services/mvp_storage_service.dart';
import '../../services/mvp_web_search_service.dart';
import '../widgets/mvp_message_bubble.dart';
import '../widgets/mvp_source_citation.dart';

/// MVP Chat Screen - Core conversational experience
class MvpChatScreen extends ConsumerStatefulWidget {
  const MvpChatScreen({super.key});

  @override
  ConsumerState<MvpChatScreen> createState() => _MvpChatScreenState();
}

class _MvpChatScreenState extends ConsumerState<MvpChatScreen> {
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
  bool _showSettingsPanel = false;
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

    // Get API keys from secure storage (async)
    final openAiKey = await _storage.getOpenAiApiKey();
    final anthropicKey = await _storage.getAnthropicApiKey();
    final tavilyKey = await _storage.getTavilyApiKey();

    // Check if proxy mode is enabled
    final useProxy = _storage.isProxyEnabled();

    // Check Ollama settings
    final ollamaEnabled = _storage.isOllamaEnabled();
    final ollamaBaseUrl = _storage.getOllamaBaseUrl();

    // Initialize services
    _llmService = MvpLlmService(
      openAiApiKey: openAiKey,
      anthropicApiKey: anthropicKey,
      ollamaEnabled: ollamaEnabled,
      ollamaBaseUrl: ollamaBaseUrl,
    );
    _webSearchService = MvpWebSearchService(
      tavilyApiKey: tavilyKey,
      useProxy: useProxy,
      proxyBaseUrl: useProxy ? 'http://localhost:8765' : null,
    );

    if (mounted) {
      setState(() => _initialized = true);
    }

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
          child: Row(
            children: [
              // Main chat area
              Expanded(
                child: Column(
                  children: [
                    // Header
                    _ChatHeader(
                      agentName: _settings.agentName,
                      onSettingsTap: () => setState(() => _showSettingsPanel = !_showSettingsPanel),
                      onClearTap: _messages.isNotEmpty ? _clearConversation : null,
                      settingsOpen: _showSettingsPanel,
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

              // Settings panel
              ClipRect(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  width: _showSettingsPanel ? 380 : 0,
                  child: _showSettingsPanel
                      ? _SettingsPanel(
                          settings: _settings,
                          onSettingsChanged: (newSettings) {
                            setState(() => _settings = newSettings);
                            _storage.saveSettings(newSettings);
                          },
                          onClose: () => setState(() => _showSettingsPanel = false),
                          onApiKeysPressed: () => context.go('/mvp/setup'),
                        )
                      : const SizedBox.shrink(),
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
  final bool settingsOpen;

  const _ChatHeader({
    required this.agentName,
    required this.onSettingsTap,
    this.onClearTap,
    this.settingsOpen = false,
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
            icon: Icon(
              settingsOpen ? Icons.close : Icons.settings,
              color: settingsOpen ? colors.primary : colors.onSurfaceVariant,
            ),
            onPressed: onSettingsTap,
            tooltip: settingsOpen ? 'Close settings' : 'Settings',
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

/// Slide-out settings panel
class _SettingsPanel extends ConsumerStatefulWidget {
  final MvpSettings settings;
  final ValueChanged<MvpSettings> onSettingsChanged;
  final VoidCallback onClose;
  final VoidCallback onApiKeysPressed;

  const _SettingsPanel({
    required this.settings,
    required this.onSettingsChanged,
    required this.onClose,
    required this.onApiKeysPressed,
  });

  @override
  ConsumerState<_SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends ConsumerState<_SettingsPanel> {
  late TextEditingController _agentNameController;
  late TextEditingController _systemPromptController;

  @override
  void initState() {
    super.initState();
    _agentNameController = TextEditingController(text: widget.settings.agentName);
    _systemPromptController = TextEditingController(text: widget.settings.systemPrompt);
  }

  @override
  void dispose() {
    _agentNameController.dispose();
    _systemPromptController.dispose();
    super.dispose();
  }

  void _updateSettings(MvpSettings Function(MvpSettings) update) {
    widget.onSettingsChanged(update(widget.settings));
  }

  @override
  Widget build(BuildContext context) {
    final colors = ThemeColors(context);
    final themeState = ref.watch(mvpThemeProvider);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          left: BorderSide(color: colors.border),
        ),
      ),
      child: Column(
        children: [
          // Panel header
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.componentSpacing,
              vertical: SpacingTokens.iconSpacing,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: colors.border.withValues(alpha: 0.5)),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Settings',
                  style: TextStyles.sectionTitle.copyWith(
                    color: colors.onSurface,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: colors.onSurfaceVariant),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),

          // Scrollable settings content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(SpacingTokens.componentSpacing),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Agent Identity
                  _PanelSection(
                    title: 'Agent Identity',
                    children: [
                      _PanelField(
                        label: 'Name',
                        child: TextField(
                          controller: _agentNameController,
                          onChanged: (value) {
                            _updateSettings((s) => s.copyWith(
                              agentName: value.isEmpty ? MvpSettings.defaultAgentName : value,
                            ));
                          },
                          style: TextStyles.bodySmall.copyWith(color: colors.onSurface),
                          decoration: _inputDecoration(colors, 'Research Assistant'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: SpacingTokens.componentSpacing),

                  // Appearance
                  _PanelSection(
                    title: 'Appearance',
                    children: [
                      _PanelField(
                        label: 'Theme',
                        child: Wrap(
                          spacing: SpacingTokens.xs_precise,
                          runSpacing: SpacingTokens.xs_precise,
                          children: [
                            _MiniThemeChip(
                              icon: Icons.wb_sunny,
                              isSelected: themeState.mode == ThemeMode.light,
                              onTap: () => ref.read(mvpThemeProvider.notifier).setThemeMode(ThemeMode.light),
                            ),
                            _MiniThemeChip(
                              icon: Icons.nightlight_round,
                              isSelected: themeState.mode == ThemeMode.dark,
                              onTap: () => ref.read(mvpThemeProvider.notifier).setThemeMode(ThemeMode.dark),
                            ),
                            _MiniThemeChip(
                              icon: Icons.auto_mode,
                              isSelected: themeState.mode == ThemeMode.system,
                              onTap: () => ref.read(mvpThemeProvider.notifier).setThemeMode(ThemeMode.system),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: SpacingTokens.iconSpacing),
                      _PanelField(
                        label: 'Color Scheme',
                        child: Wrap(
                          spacing: SpacingTokens.xs_precise,
                          runSpacing: SpacingTokens.xs_precise,
                          children: AppColorSchemes.all.map((scheme) {
                            final isSelected = themeState.colorScheme == scheme.id;
                            return Tooltip(
                              message: scheme.name,
                              child: InkWell(
                                onTap: () => ref.read(mvpThemeProvider.notifier).setColorScheme(scheme.id),
                                borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
                                    border: Border.all(
                                      color: isSelected ? colors.primary : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: scheme.colors.map((c) => Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: c,
                                        shape: BoxShape.circle,
                                      ),
                                    )).toList(),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: SpacingTokens.componentSpacing),

                  // Model settings
                  _PanelSection(
                    title: 'Model',
                    children: [
                      _TemperatureControl(
                        value: widget.settings.temperature,
                        onChanged: (value) {
                          _updateSettings((s) => s.copyWith(temperature: value));
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: SpacingTokens.componentSpacing),

                  // Features
                  _PanelSection(
                    title: 'Features',
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Web Search',
                            style: TextStyles.bodySmall.copyWith(color: colors.onSurface),
                          ),
                          Switch(
                            value: widget.settings.webSearchEnabled,
                            onChanged: (value) {
                              _updateSettings((s) => s.copyWith(webSearchEnabled: value));
                            },
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: SpacingTokens.componentSpacing),

                  // API Keys button
                  _PanelSection(
                    title: 'API Keys',
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: AsmblButton.outline(
                          text: 'Manage API Keys',
                          icon: Icons.key,
                          onPressed: widget.onApiKeysPressed,
                          size: AsmblButtonSize.small,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: SpacingTokens.sectionSpacing),

                  // System Prompt (expandable)
                  _PanelSection(
                    title: 'System Prompt',
                    children: [
                      TextField(
                        controller: _systemPromptController,
                        onChanged: (value) {
                          _updateSettings((s) => s.copyWith(
                            systemPrompt: value.isEmpty ? MvpSettings.defaultSystemPrompt : value,
                          ));
                        },
                        maxLines: 4,
                        style: TextStyles.caption.copyWith(color: colors.onSurface),
                        decoration: _inputDecoration(colors, 'You are a helpful AI assistant...'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(ThemeColors colors, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyles.bodySmall.copyWith(
        color: colors.onSurfaceVariant.withValues(alpha: 0.5),
      ),
      filled: true,
      fillColor: colors.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.iconSpacing,
        vertical: SpacingTokens.iconSpacing,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
        borderSide: BorderSide(color: colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
        borderSide: BorderSide(color: colors.primary, width: 2),
      ),
    );
  }
}

class _PanelSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _PanelSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colors = ThemeColors(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyles.caption.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: SpacingTokens.iconSpacing),
        ...children,
      ],
    );
  }
}

class _PanelField extends StatelessWidget {
  final String label;
  final Widget child;

  const _PanelField({
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = ThemeColors(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyles.caption.copyWith(
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

class _MiniThemeChip extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _MiniThemeChip({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = ThemeColors(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
      child: Container(
        padding: const EdgeInsets.all(SpacingTokens.iconSpacing),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
          border: Border.all(
            color: isSelected ? colors.primary : colors.border,
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: isSelected ? colors.primary : colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _TemperatureControl extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _TemperatureControl({
    required this.value,
    required this.onChanged,
  });

  String _getTemperatureLabel(double temp) {
    if (temp <= 0.2) return 'Precise';
    if (temp <= 0.4) return 'Focused';
    if (temp <= 0.6) return 'Balanced';
    if (temp <= 0.8) return 'Creative';
    return 'Wild';
  }

  String _getTemperatureDescription(double temp) {
    if (temp <= 0.2) return 'Factual, deterministic responses';
    if (temp <= 0.4) return 'Consistent, reliable answers';
    if (temp <= 0.6) return 'Mix of accuracy and creativity';
    if (temp <= 0.8) return 'More varied, imaginative output';
    return 'Maximum creativity and randomness';
  }

  Color _getTemperatureColor(double temp, ThemeColors colors) {
    if (temp <= 0.3) return colors.info;
    if (temp <= 0.6) return colors.success;
    if (temp <= 0.8) return colors.warning;
    return colors.error;
  }

  @override
  Widget build(BuildContext context) {
    final colors = ThemeColors(context);
    final label = _getTemperatureLabel(value);
    final description = _getTemperatureDescription(value);
    final tempColor = _getTemperatureColor(value, colors);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with value and label
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Temperature',
              style: TextStyles.caption.copyWith(color: colors.onSurface),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: tempColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
              ),
              child: Text(
                '$label (${value.toStringAsFixed(1)})',
                style: TextStyles.caption.copyWith(
                  color: tempColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Slider with gradient track
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 6,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            activeTrackColor: tempColor,
            inactiveTrackColor: colors.border,
            thumbColor: tempColor,
            overlayColor: tempColor.withValues(alpha: 0.2),
          ),
          child: Slider(
            value: value,
            min: 0.0,
            max: 1.0,
            divisions: 10,
            onChanged: onChanged,
          ),
        ),

        // Scale labels
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Precise',
                style: TextStyles.caption.copyWith(
                  color: colors.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
              Text(
                'Creative',
                style: TextStyles.caption.copyWith(
                  color: colors.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),

        // Description
        Text(
          description,
          style: TextStyles.caption.copyWith(
            color: colors.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

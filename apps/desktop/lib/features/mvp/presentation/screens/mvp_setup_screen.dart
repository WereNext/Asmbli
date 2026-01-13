import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/design_system/design_system.dart';
import '../../services/mvp_llm_service.dart';
import '../../services/mvp_storage_service.dart';

/// MVP Setup Screen - Configure API keys with connection testing
class MvpSetupScreen extends StatefulWidget {
  const MvpSetupScreen({super.key});

  @override
  State<MvpSetupScreen> createState() => _MvpSetupScreenState();
}

class _MvpSetupScreenState extends State<MvpSetupScreen> {
  final _storage = MvpStorageService();
  final _openAiController = TextEditingController();
  final _anthropicController = TextEditingController();

  String _selectedProvider = 'openai';
  bool _isLoading = false;
  bool _isTesting = false;
  String? _testResult;
  bool _testSuccess = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _storage.initialize();

    // Load existing keys if any
    final openAi = _storage.getOpenAiApiKey();
    final anthropic = _storage.getAnthropicApiKey();

    if (openAi != null && openAi.isNotEmpty) {
      _openAiController.text = openAi;
      _selectedProvider = 'openai';
    }
    if (anthropic != null && anthropic.isNotEmpty) {
      _anthropicController.text = anthropic;
      if (openAi == null || openAi.isEmpty) {
        _selectedProvider = 'anthropic';
      }
    }

    setState(() => _initialized = true);
  }

  @override
  void dispose() {
    _openAiController.dispose();
    _anthropicController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final apiKey = _selectedProvider == 'openai'
        ? _openAiController.text.trim()
        : _anthropicController.text.trim();

    if (apiKey.isEmpty) {
      setState(() {
        _testResult = 'Please enter an API key first';
        _testSuccess = false;
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final llmService = MvpLlmService(
      openAiApiKey: _selectedProvider == 'openai' ? apiKey : null,
      anthropicApiKey: _selectedProvider == 'anthropic' ? apiKey : null,
    );

    final result = await llmService.testConnection(_selectedProvider);

    setState(() {
      _isTesting = false;
      _testResult = result.message;
      _testSuccess = result.isSuccess;
    });
  }

  Future<void> _saveAndContinue() async {
    setState(() => _isLoading = true);

    try {
      // Save API keys
      if (_openAiController.text.trim().isNotEmpty) {
        await _storage.saveOpenAiApiKey(_openAiController.text.trim());
      }
      if (_anthropicController.text.trim().isNotEmpty) {
        await _storage.saveAnthropicApiKey(_anthropicController.text.trim());
      }

      // Update settings with selected provider
      final settings = _storage.getSettings();
      await _storage.saveSettings(settings.copyWith(
        selectedProvider: _selectedProvider,
        selectedModel:
            _selectedProvider == 'openai' ? 'gpt-4o' : 'claude-3-5-sonnet-20241022',
      ));

      // Mark setup as complete
      await _storage.setSetupComplete(true);

      if (mounted) {
        context.go('/mvp/chat');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openApiKeyPage(String provider) async {
    final url = provider == 'openai'
        ? Uri.parse('https://platform.openai.com/api-keys')
        : Uri.parse('https://console.anthropic.com/settings/keys');

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
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
          child: Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Padding(
                  padding: const EdgeInsets.all(SpacingTokens.pageHorizontal),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back button
                      IconButton(
                        onPressed: () => context.go('/mvp'),
                        icon: Icon(Icons.arrow_back, color: colors.onSurface),
                      ),

                      const SizedBox(height: SpacingTokens.componentSpacing),

                      // Title
                      Text(
                        'Connect Your AI',
                        style: TextStyles.pageTitle.copyWith(
                          color: colors.onSurface,
                        ),
                      ),

                      const SizedBox(height: SpacingTokens.iconSpacing),

                      Text(
                        'Choose your AI provider and enter your API key',
                        style: TextStyles.bodyMedium.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),

                      const SizedBox(height: SpacingTokens.sectionSpacing),

                      // Provider selection
                      Text(
                        'AI Provider',
                        style: TextStyles.sectionTitle.copyWith(
                          color: colors.onSurface,
                        ),
                      ),

                      const SizedBox(height: SpacingTokens.componentSpacing),

                      // OpenAI option
                      _ProviderOption(
                        title: 'OpenAI',
                        subtitle: 'GPT-4o and other models',
                        isSelected: _selectedProvider == 'openai',
                        onTap: () => setState(() => _selectedProvider = 'openai'),
                      ),

                      const SizedBox(height: SpacingTokens.iconSpacing),

                      // Anthropic option
                      _ProviderOption(
                        title: 'Anthropic',
                        subtitle: 'Claude 3.5 Sonnet and other models',
                        isSelected: _selectedProvider == 'anthropic',
                        onTap: () => setState(() => _selectedProvider = 'anthropic'),
                      ),

                      const SizedBox(height: SpacingTokens.sectionSpacing),

                      // API Key input
                      Row(
                        children: [
                          Text(
                            'API Key',
                            style: TextStyles.sectionTitle.copyWith(
                              color: colors.onSurface,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => _openApiKeyPage(_selectedProvider),
                            child: Text(
                              'Get API key',
                              style: TextStyles.bodySmall.copyWith(
                                color: colors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: SpacingTokens.iconSpacing),

                      if (_selectedProvider == 'openai')
                        _ApiKeyField(
                          controller: _openAiController,
                          hint: 'sk-...',
                          onChanged: (_) => setState(() {
                            _testResult = null;
                          }),
                        )
                      else
                        _ApiKeyField(
                          controller: _anthropicController,
                          hint: 'sk-ant-...',
                          onChanged: (_) => setState(() {
                            _testResult = null;
                          }),
                        ),

                      const SizedBox(height: SpacingTokens.componentSpacing),

                      // Test connection button and result
                      Row(
                        children: [
                          AsmblButton.outline(
                            text: _isTesting ? 'Testing...' : 'Test Connection',
                            icon: _isTesting ? null : Icons.check_circle_outline,
                            onPressed: _isTesting ? null : _testConnection,
                            size: AsmblButtonSize.small,
                          ),
                          const SizedBox(width: SpacingTokens.componentSpacing),
                          if (_testResult != null)
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(
                                    _testSuccess ? Icons.check_circle : Icons.error,
                                    size: 16,
                                    color: _testSuccess ? colors.success : colors.error,
                                  ),
                                  const SizedBox(width: SpacingTokens.iconSpacing),
                                  Expanded(
                                    child: Text(
                                      _testResult!,
                                      style: TextStyles.bodySmall.copyWith(
                                        color: _testSuccess
                                            ? colors.success
                                            : colors.error,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: SpacingTokens.sectionSpacing * 2),

                      // Continue button
                      SizedBox(
                        width: double.infinity,
                        child: AsmblButton.primary(
                          text: _isLoading ? 'Saving...' : 'Continue',
                          icon: _isLoading ? null : Icons.arrow_forward,
                          onPressed: _isLoading ? null : _saveAndContinue,
                          size: AsmblButtonSize.large,
                        ),
                      ),

                      const SizedBox(height: SpacingTokens.componentSpacing),

                      // Skip option
                      Center(
                        child: TextButton(
                          onPressed: () => context.go('/mvp/chat'),
                          child: Text(
                            'Skip for now',
                            style: TextStyles.bodySmall.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProviderOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _ProviderOption({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = ThemeColors(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
        child: Container(
          padding: const EdgeInsets.all(SpacingTokens.componentSpacing),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
            border: Border.all(
              color: isSelected ? colors.primary : colors.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? colors.primary : colors.border,
                    width: 2,
                  ),
                  color: isSelected ? colors.primary : Colors.transparent,
                ),
                child: isSelected
                    ? Icon(
                        Icons.check,
                        size: 14,
                        color: colors.onPrimary,
                      )
                    : null,
              ),
              const SizedBox(width: SpacingTokens.componentSpacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyles.bodyMedium.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyles.caption.copyWith(
                        color: colors.onSurfaceVariant,
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

class _ApiKeyField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  const _ApiKeyField({
    required this.controller,
    required this.hint,
    this.onChanged,
  });

  @override
  State<_ApiKeyField> createState() => _ApiKeyFieldState();
}

class _ApiKeyFieldState extends State<_ApiKeyField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final colors = ThemeColors(context);

    return TextField(
      controller: widget.controller,
      obscureText: _obscured,
      onChanged: widget.onChanged,
      style: TextStyles.bodyMedium.copyWith(
        color: colors.onSurface,
        fontFamily: 'monospace',
      ),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: TextStyles.bodyMedium.copyWith(
          color: colors.onSurfaceVariant.withValues(alpha: 0.5),
          fontFamily: 'monospace',
        ),
        filled: true,
        fillColor: colors.surface,
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
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                _obscured ? Icons.visibility : Icons.visibility_off,
                color: colors.onSurfaceVariant,
              ),
              onPressed: () => setState(() => _obscured = !_obscured),
            ),
            IconButton(
              icon: Icon(Icons.paste, color: colors.onSurfaceVariant),
              onPressed: () async {
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                if (data?.text != null) {
                  widget.controller.text = data!.text!;
                  widget.onChanged?.call(data.text!);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

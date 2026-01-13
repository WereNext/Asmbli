import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/theme/color_schemes.dart';
import '../../../../main_mvp.dart';
import '../../models/mvp_settings.dart';
import '../../services/mvp_llm_service.dart';
import '../../services/mvp_storage_service.dart';

/// MVP Settings Screen - Customize agent behavior
class MvpSettingsScreen extends ConsumerStatefulWidget {
  const MvpSettingsScreen({super.key});

  @override
  ConsumerState<MvpSettingsScreen> createState() => _MvpSettingsScreenState();
}

class _MvpSettingsScreenState extends ConsumerState<MvpSettingsScreen> {
  final _storage = MvpStorageService();
  final _agentNameController = TextEditingController();
  final _systemPromptController = TextEditingController();

  MvpSettings _settings = MvpSettings.defaults();
  bool _initialized = false;
  bool _hasChanges = false;
  bool _hasOpenAiKey = false;
  bool _hasAnthropicKey = false;
  bool _ollamaEnabled = false;
  bool _ollamaRunning = false;
  List<String> _ollamaModels = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _storage.initialize();
    _settings = _storage.getSettings();

    _agentNameController.text = _settings.agentName;
    _systemPromptController.text = _settings.systemPrompt;

    // Load API key availability from secure storage (async)
    final openAiKey = await _storage.getOpenAiApiKey();
    final anthropicKey = await _storage.getAnthropicApiKey();
    _hasOpenAiKey = openAiKey?.isNotEmpty ?? false;
    _hasAnthropicKey = anthropicKey?.isNotEmpty ?? false;

    // Check Ollama status
    _ollamaEnabled = _storage.isOllamaEnabled();
    _ollamaRunning = await MvpLlmService.checkOllamaRunning();
    if (_ollamaRunning) {
      final llm = MvpLlmService(ollamaEnabled: true);
      _ollamaModels = await llm.getOllamaModels();
    }

    setState(() => _initialized = true);
  }

  @override
  void dispose() {
    _agentNameController.dispose();
    _systemPromptController.dispose();
    super.dispose();
  }

  void _markChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  Future<void> _saveSettings() async {
    _settings = _settings.copyWith(
      agentName: _agentNameController.text.trim().isEmpty
          ? MvpSettings.defaultAgentName
          : _agentNameController.text.trim(),
      systemPrompt: _systemPromptController.text.trim().isEmpty
          ? MvpSettings.defaultSystemPrompt
          : _systemPromptController.text.trim(),
    );

    await _storage.saveSettings(_settings);

    setState(() => _hasChanges = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults'),
        content: const Text(
            'This will reset all settings to their default values. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _settings = MvpSettings.defaults();
      _agentNameController.text = _settings.agentName;
      _systemPromptController.text = _settings.systemPrompt;

      await _storage.saveSettings(_settings);

      setState(() => _hasChanges = false);
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
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.componentSpacing,
                  vertical: SpacingTokens.iconSpacing,
                ),
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.8),
                  border: Border(
                    bottom:
                        BorderSide(color: colors.border.withValues(alpha: 0.5)),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: colors.onSurface),
                      onPressed: () => context.go('/mvp/chat'),
                    ),
                    const SizedBox(width: SpacingTokens.iconSpacing),
                    Expanded(
                      child: Text(
                        'Settings',
                        style: TextStyles.sectionTitle.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                    if (_hasChanges)
                      AsmblButton.primary(
                        text: 'Save',
                        onPressed: _saveSettings,
                        size: AsmblButtonSize.small,
                      ),
                  ],
                ),
              ),

              // Settings content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(SpacingTokens.pageHorizontal),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Agent Identity section
                        _SectionHeader(title: 'Agent Identity'),
                        const SizedBox(height: SpacingTokens.componentSpacing),

                        _SettingsCard(
                          children: [
                            _SettingsField(
                              label: 'Agent Name',
                              child: TextField(
                                controller: _agentNameController,
                                onChanged: (_) => _markChanged(),
                                style: TextStyles.bodyMedium.copyWith(
                                  color: colors.onSurface,
                                ),
                                decoration: _inputDecoration(
                                  context,
                                  hint: 'Research Assistant',
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: SpacingTokens.sectionSpacing),

                        // Personality section
                        _SectionHeader(title: 'Personality'),
                        const SizedBox(height: SpacingTokens.componentSpacing),

                        _SettingsCard(
                          children: [
                            _SettingsField(
                              label: 'System Prompt',
                              description:
                                  'Customize how your agent behaves and responds',
                              child: TextField(
                                controller: _systemPromptController,
                                onChanged: (_) => _markChanged(),
                                maxLines: 6,
                                style: TextStyles.bodyMedium.copyWith(
                                  color: colors.onSurface,
                                ),
                                decoration: _inputDecoration(
                                  context,
                                  hint: 'You are a helpful AI assistant...',
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: SpacingTokens.sectionSpacing),

                        // Model section
                        _SectionHeader(title: 'Model'),
                        const SizedBox(height: SpacingTokens.componentSpacing),

                        _SettingsCard(
                          children: [
                            _SettingsField(
                              label: 'AI Provider',
                              child: _ProviderSelector(
                                value: _settings.selectedProvider,
                                onChanged: (provider) {
                                  setState(() {
                                    String defaultModel;
                                    if (provider == 'openai') {
                                      defaultModel = 'gpt-4o';
                                    } else if (provider == 'anthropic') {
                                      defaultModel = 'claude-3-5-sonnet-20241022';
                                    } else {
                                      // Ollama - use first available model or default
                                      defaultModel = _ollamaModels.isNotEmpty
                                          ? _ollamaModels.first
                                          : 'llama3.2';
                                    }
                                    _settings = _settings.copyWith(
                                      selectedProvider: provider,
                                      selectedModel: defaultModel,
                                    );
                                    _hasChanges = true;
                                  });
                                },
                                hasOpenAi: _hasOpenAiKey,
                                hasAnthropic: _hasAnthropicKey,
                                hasOllama: _ollamaEnabled && _ollamaRunning,
                              ),
                            ),
                            const Divider(height: SpacingTokens.sectionSpacing),
                            _SettingsField(
                              label: 'Model',
                              child: _ModelSelector(
                                provider: _settings.selectedProvider,
                                value: _settings.selectedModel,
                                ollamaModels: _ollamaModels,
                                onChanged: (model) {
                                  setState(() {
                                    _settings =
                                        _settings.copyWith(selectedModel: model);
                                    _hasChanges = true;
                                  });
                                },
                              ),
                            ),
                            const Divider(height: SpacingTokens.sectionSpacing),
                            _SettingsField(
                              label:
                                  'Temperature: ${_settings.temperature.toStringAsFixed(1)}',
                              description:
                                  'Lower = more focused, Higher = more creative',
                              child: Slider(
                                value: _settings.temperature,
                                min: 0.0,
                                max: 1.0,
                                divisions: 10,
                                onChanged: (value) {
                                  setState(() {
                                    _settings =
                                        _settings.copyWith(temperature: value);
                                    _hasChanges = true;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: SpacingTokens.sectionSpacing),

                        // Features section
                        _SectionHeader(title: 'Features'),
                        const SizedBox(height: SpacingTokens.componentSpacing),

                        _SettingsCard(
                          children: [
                            _SettingsField(
                              label: 'Web Search',
                              description:
                                  'Automatically search the web for current information',
                              child: Switch(
                                value: _settings.webSearchEnabled,
                                onChanged: (value) {
                                  setState(() {
                                    _settings = _settings.copyWith(
                                        webSearchEnabled: value);
                                    _hasChanges = true;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: SpacingTokens.sectionSpacing),

                        // Ollama section
                        _SectionHeader(title: 'Local AI (Ollama)'),
                        const SizedBox(height: SpacingTokens.componentSpacing),

                        _SettingsCard(
                          children: [
                            _SettingsField(
                              label: 'Enable Ollama',
                              description: _ollamaRunning
                                  ? 'Ollama is running (${_ollamaModels.length} models)'
                                  : 'Ollama not detected. Install from ollama.com',
                              child: Switch(
                                value: _ollamaEnabled,
                                onChanged: _ollamaRunning
                                    ? (value) async {
                                        await _storage.setOllamaEnabled(value);
                                        setState(() {
                                          _ollamaEnabled = value;
                                          _hasChanges = true;
                                        });
                                      }
                                    : null,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: SpacingTokens.sectionSpacing),

                        // Appearance section
                        _SectionHeader(title: 'Appearance'),
                        const SizedBox(height: SpacingTokens.componentSpacing),

                        _SettingsCard(
                          children: [
                            _SettingsField(
                              label: 'Theme Mode',
                              child: _ThemeModeSelector(
                                value: ref.watch(mvpThemeProvider).mode,
                                onChanged: (mode) {
                                  ref.read(mvpThemeProvider.notifier).setThemeMode(mode);
                                },
                              ),
                            ),
                            const Divider(height: SpacingTokens.sectionSpacing),
                            _SettingsField(
                              label: 'Color Scheme',
                              child: _ColorSchemeSelector(
                                value: ref.watch(mvpThemeProvider).colorScheme,
                                onChanged: (scheme) {
                                  ref.read(mvpThemeProvider.notifier).setColorScheme(scheme);
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: SpacingTokens.sectionSpacing),

                        // API Keys section
                        _SectionHeader(title: 'API Keys'),
                        const SizedBox(height: SpacingTokens.componentSpacing),

                        _SettingsCard(
                          children: [
                            _SettingsField(
                              label: 'Configure API Keys',
                              description: 'Add or update your AI provider API keys',
                              child: AsmblButton.outline(
                                text: 'Manage API Keys',
                                icon: Icons.key,
                                onPressed: () => context.go('/mvp/setup'),
                                size: AsmblButtonSize.small,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: SpacingTokens.sectionSpacing * 2),

                        // Reset button
                        Center(
                          child: TextButton(
                            onPressed: _resetToDefaults,
                            child: Text(
                              'Reset to Defaults',
                              style: TextStyles.bodySmall.copyWith(
                                color: colors.error,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: SpacingTokens.sectionSpacing),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(BuildContext context, {required String hint}) {
    final colors = ThemeColors(context);
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyles.bodyMedium.copyWith(
        color: colors.onSurfaceVariant.withValues(alpha: 0.5),
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
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final colors = ThemeColors(context);
    return Text(
      title,
      style: TextStyles.sectionTitle.copyWith(
        color: colors.onSurface,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final colors = ThemeColors(context);
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.componentSpacing),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _SettingsField extends StatelessWidget {
  final String label;
  final String? description;
  final Widget child;

  const _SettingsField({
    required this.label,
    this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = ThemeColors(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyles.bodyMedium.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      description!,
                      style: TextStyles.caption.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (child is Switch) child,
          ],
        ),
        if (child is! Switch) ...[
          const SizedBox(height: SpacingTokens.iconSpacing),
          child,
        ],
      ],
    );
  }
}

class _ProviderSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final bool hasOpenAi;
  final bool hasAnthropic;
  final bool hasOllama;

  const _ProviderSelector({
    required this.value,
    required this.onChanged,
    required this.hasOpenAi,
    required this.hasAnthropic,
    this.hasOllama = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ProviderChip(
                label: 'OpenAI',
                isSelected: value == 'openai',
                isAvailable: hasOpenAi,
                onTap: hasOpenAi ? () => onChanged('openai') : null,
              ),
            ),
            const SizedBox(width: SpacingTokens.iconSpacing),
            Expanded(
              child: _ProviderChip(
                label: 'Anthropic',
                isSelected: value == 'anthropic',
                isAvailable: hasAnthropic,
                onTap: hasAnthropic ? () => onChanged('anthropic') : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: SpacingTokens.iconSpacing),
        Row(
          children: [
            Expanded(
              child: _ProviderChip(
                label: 'Ollama (Local)',
                isSelected: value == 'ollama',
                isAvailable: hasOllama,
                onTap: hasOllama ? () => onChanged('ollama') : null,
              ),
            ),
            const Spacer(),
          ],
        ),
      ],
    );
  }
}

class _ProviderChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isAvailable;
  final VoidCallback? onTap;

  const _ProviderChip({
    required this.label,
    required this.isSelected,
    required this.isAvailable,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = ThemeColors(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.componentSpacing,
            vertical: SpacingTokens.iconSpacing,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? colors.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
            border: Border.all(
              color: isSelected
                  ? colors.primary
                  : isAvailable
                      ? colors.border
                      : colors.border.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSelected)
                Icon(Icons.check, size: 16, color: colors.primary),
              if (isSelected) const SizedBox(width: SpacingTokens.xs_precise),
              Text(
                label,
                style: TextStyles.bodySmall.copyWith(
                  color: isAvailable
                      ? (isSelected ? colors.primary : colors.onSurface)
                      : colors.onSurfaceVariant.withValues(alpha: 0.5),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (!isAvailable) ...[
                const SizedBox(width: SpacingTokens.xs_precise),
                Icon(
                  Icons.warning_amber,
                  size: 12,
                  color: colors.warning.withValues(alpha: 0.7),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ModelSelector extends StatelessWidget {
  final String provider;
  final String value;
  final ValueChanged<String> onChanged;
  final List<String> ollamaModels;

  const _ModelSelector({
    required this.provider,
    required this.value,
    required this.onChanged,
    this.ollamaModels = const [],
  });

  @override
  Widget build(BuildContext context) {
    final colors = ThemeColors(context);

    List<String> models;
    if (provider == 'openai') {
      models = ['gpt-4o', 'gpt-4o-mini', 'gpt-4-turbo', 'gpt-3.5-turbo'];
    } else if (provider == 'anthropic') {
      models = [
        'claude-3-5-sonnet-20241022',
        'claude-3-opus-20240229',
        'claude-3-haiku-20240307'
      ];
    } else {
      // Ollama models
      models = ollamaModels.isNotEmpty
          ? ollamaModels
          : ['llama3.2', 'llama3.1', 'mistral', 'codellama'];
    }

    return DropdownButtonFormField<String>(
      value: models.contains(value) ? value : models.first,
      items: models
          .map((model) => DropdownMenuItem(
                value: model,
                child: Text(
                  model,
                  style: TextStyles.bodyMedium.copyWith(
                    color: colors.onSurface,
                  ),
                ),
              ))
          .toList(),
      onChanged: (newValue) {
        if (newValue != null) onChanged(newValue);
      },
      decoration: InputDecoration(
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
      ),
    );
  }
}

class _ThemeModeSelector extends StatelessWidget {
  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  const _ThemeModeSelector({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ThemeModeChip(
            label: 'Light',
            icon: Icons.wb_sunny,
            isSelected: value == ThemeMode.light,
            onTap: () => onChanged(ThemeMode.light),
          ),
        ),
        const SizedBox(width: SpacingTokens.iconSpacing),
        Expanded(
          child: _ThemeModeChip(
            label: 'Dark',
            icon: Icons.nightlight_round,
            isSelected: value == ThemeMode.dark,
            onTap: () => onChanged(ThemeMode.dark),
          ),
        ),
        const SizedBox(width: SpacingTokens.iconSpacing),
        Expanded(
          child: _ThemeModeChip(
            label: 'System',
            icon: Icons.auto_mode,
            isSelected: value == ThemeMode.system,
            onTap: () => onChanged(ThemeMode.system),
          ),
        ),
      ],
    );
  }
}

class _ThemeModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeModeChip({
    required this.label,
    required this.icon,
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
        borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.iconSpacing,
            vertical: SpacingTokens.iconSpacing,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? colors.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
            border: Border.all(
              color: isSelected ? colors.primary : colors.border,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? colors.primary : colors.onSurfaceVariant,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyles.caption.copyWith(
                  color: isSelected ? colors.primary : colors.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorSchemeSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _ColorSchemeSelector({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final schemes = AppColorSchemes.all;

    return Wrap(
      spacing: SpacingTokens.iconSpacing,
      runSpacing: SpacingTokens.iconSpacing,
      children: schemes.map((scheme) {
        return _ColorSchemeChip(
          name: scheme.name,
          colors: scheme.colors,
          isSelected: value == scheme.id,
          onTap: () => onChanged(scheme.id),
        );
      }).toList(),
    );
  }
}

class _ColorSchemeChip extends StatelessWidget {
  final String name;
  final List<Color> colors;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorSchemeChip({
    required this.name,
    required this.colors,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final themeColors = ThemeColors(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
        child: Container(
          padding: const EdgeInsets.all(SpacingTokens.iconSpacing),
          decoration: BoxDecoration(
            color: isSelected
                ? themeColors.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
            border: Border.all(
              color: isSelected ? themeColors.primary : themeColors.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Color preview circles
              Row(
                children: colors.map((color) {
                  return Container(
                    width: 16,
                    height: 16,
                    margin: const EdgeInsets.only(right: 2),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: themeColors.border.withValues(alpha: 0.3),
                        width: 0.5,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(width: SpacingTokens.iconSpacing),
              Text(
                name,
                style: TextStyles.bodySmall.copyWith(
                  color: isSelected ? themeColors.primary : themeColors.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: SpacingTokens.xs_precise),
                Icon(
                  Icons.check,
                  size: 14,
                  color: themeColors.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

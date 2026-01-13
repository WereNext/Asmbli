import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../models/mvp_settings.dart';
import '../../services/mvp_storage_service.dart';

/// MVP Settings Screen - Customize agent behavior
class MvpSettingsScreen extends StatefulWidget {
  const MvpSettingsScreen({super.key});

  @override
  State<MvpSettingsScreen> createState() => _MvpSettingsScreenState();
}

class _MvpSettingsScreenState extends State<MvpSettingsScreen> {
  final _storage = MvpStorageService();
  final _agentNameController = TextEditingController();
  final _systemPromptController = TextEditingController();

  MvpSettings _settings = MvpSettings.defaults();
  bool _initialized = false;
  bool _hasChanges = false;

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
                                    _settings = _settings.copyWith(
                                      selectedProvider: provider,
                                      selectedModel: provider == 'openai'
                                          ? 'gpt-4o'
                                          : 'claude-3-5-sonnet-20241022',
                                    );
                                    _hasChanges = true;
                                  });
                                },
                                hasOpenAi:
                                    _storage.getOpenAiApiKey()?.isNotEmpty ??
                                        false,
                                hasAnthropic:
                                    _storage.getAnthropicApiKey()?.isNotEmpty ??
                                        false,
                              ),
                            ),
                            const Divider(height: SpacingTokens.sectionSpacing),
                            _SettingsField(
                              label: 'Model',
                              child: _ModelSelector(
                                provider: _settings.selectedProvider,
                                value: _settings.selectedModel,
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

  const _ProviderSelector({
    required this.value,
    required this.onChanged,
    required this.hasOpenAi,
    required this.hasAnthropic,
  });

  @override
  Widget build(BuildContext context) {
    final colors = ThemeColors(context);

    return Row(
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

  const _ModelSelector({
    required this.provider,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = ThemeColors(context);

    final models = provider == 'openai'
        ? ['gpt-4o', 'gpt-4o-mini', 'gpt-4-turbo', 'gpt-3.5-turbo']
        : [
            'claude-3-5-sonnet-20241022',
            'claude-3-opus-20240229',
            'claude-3-haiku-20240307'
          ];

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

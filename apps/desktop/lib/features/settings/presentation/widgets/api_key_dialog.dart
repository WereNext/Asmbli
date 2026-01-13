import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/services/mcp_settings_service.dart';
import '../../../../core/services/claude_api_service.dart';
import '../../../../core/services/api_config_service.dart';
import '../../../../core/models/model_config.dart';
import '../../../../core/services/model_config_service.dart';

class ApiKeyDialog extends ConsumerStatefulWidget {
  final ApiConfig? existingConfig;
  final DirectAPIConfig? existingDirectConfig; // For backward compatibility
  final ModelConfig? existingModelConfig; // New model config support

  const ApiKeyDialog({
    super.key,
    this.existingConfig,
    this.existingDirectConfig, // For backward compatibility
    this.existingModelConfig,
  });

  @override
  ConsumerState<ApiKeyDialog> createState() => _ApiKeyDialogState();
}

class _ApiKeyDialogState extends ConsumerState<ApiKeyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _apiKeyController = TextEditingController();
  
  String selectedProvider = 'Anthropic';
  String selectedModel = 'claude-4-5-sonnet-20250929';
  bool _isObscured = true;
  bool _isTesting = false;
  bool _isTestSuccessful = false;
  String? _testError;

  final Map<String, List<String>> _providerModels = {
    'Anthropic': [
      'claude-4-5-sonnet-20250929',  // Latest Sonnet 4.5 with enhanced coding capabilities (Sep 2025)
      'claude-4-1-opus-20250805',    // Latest Opus 4.1 for complex reasoning (Aug 2025)
      'claude-4-5-haiku-20251111',   // Latest Haiku 4.5 - fast & cost-effective (Nov 2025)
      'claude-4-sonnet-20250522',    // Sonnet 4 with 1M context support (May 2025)
      'claude-3-5-sonnet-20241022',  // Previous Sonnet 3.5 with enhanced capabilities
      'claude-3-5-haiku-20241022',   // Previous Haiku 3.5 - fast, efficient model
    ],
    'OpenAI': [
      'gpt-4.1',                     // Latest GPT-4.1 with improved coding & 1M context (2025)
      'gpt-4.1-mini',                // Fast, efficient GPT-4.1 mini variant
      'gpt-4.1-nano',                // Ultra-efficient GPT-4.1 nano
      'o3-pro',                      // Latest O3 Pro reasoning model (2025)
      'o4-mini',                     // O4-mini for fast reasoning (2025)
      'o1-preview',                  // O1 reasoning model preview
      'o1-mini',                     // Smaller O1 reasoning model
      'gpt-4o',                      // GPT-4 Omni (multimodal)
      'gpt-4o-mini',                 // Smaller, faster GPT-4o
    ],
    'Google': [
      'gemini-2.5-pro',              // Latest Gemini 2.5 Pro - most capable coding model (2025)
      'gemini-2.5-flash',            // Gemini 2.5 Flash with thinking capabilities (2025)
      'gemini-2.5-flash-lite',       // Fast, low-cost Gemini 2.5 variant
      'gemini-2.0-pro-experimental', // Gemini 2.0 Pro with 2M context (experimental)
      'gemini-2.0-flash',            // Gemini 2.0 Flash - generally available
      'gemini-2.0-flash-lite',       // Cost-optimized Gemini 2.0 Flash-Lite
      'gemini-1.5-pro',              // Previous generation Gemini Pro
      'gemini-pro-vision',           // Gemini with vision capabilities
    ],
    'Moonshot (Kimi)': [
      'moonshot-v1-auto',            // Auto-select model (8k/32k/128k) for cost optimization (2025)
      'kimi-k2-thinking',            // Latest K2 Thinking model with reasoning (Nov 2025)
      'kimi-k2-instruct-0905',      // K2 Instruct with 256K context (Sep 2025)
      'moonshot-v1-128k',            // Kimi 128K context model
      'moonshot-v1-32k',             // Kimi 32K context model
      'moonshot-v1-8k',              // Kimi 8K context model
    ],
  };

  @override
  void initState() {
    super.initState();
    
    // Check for all types of existing configs, prioritize ModelConfig
    if (widget.existingModelConfig != null) {
      final modelConfig = widget.existingModelConfig!;
      _nameController.text = modelConfig.name;
      _apiKeyController.text = modelConfig.apiKey ?? '';
      selectedProvider = modelConfig.provider;
      selectedModel = modelConfig.model;
    } else {
      // Fallback to legacy config types
      final config = widget.existingConfig ?? 
          (widget.existingDirectConfig != null 
              ? ApiConfig(
                  id: widget.existingDirectConfig!.id,
                  name: widget.existingDirectConfig!.name,
                  provider: widget.existingDirectConfig!.provider,
                  model: widget.existingDirectConfig!.model,
                  apiKey: widget.existingDirectConfig!.apiKey,
                  baseUrl: widget.existingDirectConfig!.baseUrl,
                  isDefault: widget.existingDirectConfig!.isDefault,
                  enabled: widget.existingDirectConfig!.enabled,
                ) 
              : null);
      
      if (config != null) {
        _nameController.text = config.name;
        _apiKeyController.text = config.apiKey;
        selectedProvider = config.provider;
        selectedModel = config.model;
      } else {
        _nameController.text = 'Default API Model';
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BorderRadiusTokens.xl),
      ),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(SpacingTokens.xxl),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.api,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: SpacingTokens.componentSpacing),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (widget.existingConfig != null || widget.existingDirectConfig != null) ? 'Edit API Configuration' : 'Add API Configuration',
                          style: TextStyles.pageTitle.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Configure your API key to enable real AI conversations',
                          style: TextStyles.bodyMedium.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      foregroundColor: theme.colorScheme.onSurfaceVariant,
                      overlayColor: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: SpacingTokens.sectionSpacing),
              
              // Configuration Name
              _buildTextField(
                label: 'Configuration Name',
                controller: _nameController,
                hintText: 'e.g., Claude Production',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a configuration name';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: SpacingTokens.elementSpacing),
              
              // Provider Selection
              _buildDropdown(
                label: 'Provider',
                value: selectedProvider,
                items: _providerModels.keys.toList(),
                onChanged: (value) {
                  setState(() {
                    selectedProvider = value!;
                    selectedModel = _providerModels[value]!.first;
                    _isTestSuccessful = false;
                    _testError = null;
                  });
                },
              ),
              
              const SizedBox(height: SpacingTokens.elementSpacing),
              
              // Model Selection
              _buildDropdown(
                label: 'Model',
                value: selectedModel,
                items: _providerModels[selectedProvider] ?? [],
                onChanged: (value) {
                  setState(() {
                    selectedModel = value!;
                    _isTestSuccessful = false;
                    _testError = null;
                  });
                },
              ),
              
              const SizedBox(height: SpacingTokens.elementSpacing),
              
              // API Key
              _buildApiKeyField(),
              
              const SizedBox(height: SpacingTokens.componentSpacing),
              
              // Test Connection
              _buildTestConnection(),
              
              const SizedBox(height: SpacingTokens.sectionSpacing),
              
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AsmblButton.secondary(
                    text: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: SpacingTokens.componentSpacing),
                  AsmblButton.primary(
                    text: (widget.existingConfig != null || widget.existingDirectConfig != null) ? 'Update' : 'Add',
                    onPressed: _saveApiConfig,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hintText,
    String? Function(String?)? validator,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyles.labelMedium.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
              borderSide: BorderSide(color: theme.colorScheme.outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
              borderSide: BorderSide(color: theme.colorScheme.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
              borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
            ),
            filled: true,
            fillColor: theme.colorScheme.surface,
          ),
          style: TextStyles.bodyMedium.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyles.labelMedium.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
              borderSide: BorderSide(color: theme.colorScheme.outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
              borderSide: BorderSide(color: theme.colorScheme.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
              borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
            ),
            filled: true,
            fillColor: theme.colorScheme.surface,
          ),
        ),
      ],
    );
  }

  Widget _buildApiKeyField() {
    return _buildTextField(
      label: 'API Key',
      controller: _apiKeyController,
      hintText: 'sk-ant-... (your API key)',
      obscureText: _isObscured,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter your API key';
        }
        if (selectedProvider == 'Anthropic' && !value.startsWith('sk-ant-')) {
          return 'Anthropic API keys should start with sk-ant-';
        }
        return null;
      },
      suffixIcon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => setState(() => _isObscured = !_isObscured),
            icon: Icon(_isObscured ? Icons.visibility : Icons.visibility_off),
            style: IconButton.styleFrom(
              overlayColor: ThemeColors(context).primary.withValues(alpha: 0.1),
            ),
          ),
          IconButton(
            onPressed: _pasteFromClipboard,
            icon: const Icon(Icons.paste),
            tooltip: 'Paste from clipboard',
            style: IconButton.styleFrom(
              overlayColor: ThemeColors(context).primary.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestConnection() {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.elementSpacing),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
        border: Border.all(
          color: _isTestSuccessful 
            ? ThemeColors(context).success.withValues(alpha: 0.5)
            : _testError != null 
              ? ThemeColors(context).error.withValues(alpha: 0.5)
              : theme.colorScheme.outline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_isTesting)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                  ),
                )
              else if (_isTestSuccessful)
                Icon(Icons.check_circle, color: ThemeColors(context).success, size: 16)
              else if (_testError != null)
                Icon(Icons.error, color: ThemeColors(context).error, size: 16)
              else
                Icon(Icons.info_outline, color: theme.colorScheme.onSurfaceVariant, size: 16),
              
              const SizedBox(width: 8),
              
              Text(
                _isTesting 
                  ? 'Testing connection...'
                  : _isTestSuccessful 
                    ? 'Connection successful!'
                    : _testError != null 
                      ? 'Connection failed'
                      : 'Test your API key',
                style: TextStyles.labelMedium.copyWith(
                  color: _isTestSuccessful 
                    ? ThemeColors(context).success
                    : _testError != null 
                      ? ThemeColors(context).error
                      : theme.colorScheme.onSurface,
                ),
              ),
              
              const Spacer(),
              
              AsmblButton.secondary(
                text: 'Test Connection',
                onPressed: _isTesting ? null : _testApiKey,
                size: AsmblButtonSize.small,
              ),
            ],
          ),
          
          if (_testError != null) ...[
            const SizedBox(height: 8),
            Text(
              _testError!,
              style: TextStyles.bodySmall.copyWith(
                color: ThemeColors(context).error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _apiKeyController.text = data!.text!;
      setState(() {
        _isTestSuccessful = false;
        _testError = null;
      });
    }
  }

  Future<void> _testApiKey() async {
    if (_apiKeyController.text.trim().isEmpty) {
      setState(() {
        _testError = 'Please enter an API key first';
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testError = null;
      _isTestSuccessful = false;
    });

    try {
      final claudeApiService = ref.read(claudeApiServiceProvider);
      final isValid = await claudeApiService.testApiKey(_apiKeyController.text.trim());
      
      setState(() {
        _isTesting = false;
        _isTestSuccessful = isValid;
        if (!isValid) {
          _testError = 'Invalid API key or insufficient permissions';
        }
      });
    } catch (e) {
      setState(() {
        _isTesting = false;
        _testError = e.toString();
      });
    }
  }

  Future<void> _saveApiConfig() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      final modelConfigsNotifier = ref.read(modelConfigsProvider.notifier);
      final currentConfigs = ref.read(modelConfigsProvider);
      
      // Get existing config ID from any source
      String? existingId;
      if (widget.existingModelConfig != null) {
        existingId = widget.existingModelConfig!.id;
      } else if (widget.existingConfig != null) {
        existingId = widget.existingConfig!.id;
      } else if (widget.existingDirectConfig != null) {
        existingId = widget.existingDirectConfig!.id;
      }
      
      final configId = existingId ?? 
          '${selectedProvider.toLowerCase()}-${DateTime.now().millisecondsSinceEpoch}';
      
      final modelConfig = ModelConfig(
        id: configId,
        name: _nameController.text.trim(),
        provider: selectedProvider,
        model: selectedModel,
        type: ModelType.api,
        apiKey: _apiKeyController.text.trim(),
        baseUrl: selectedProvider == 'Anthropic' 
          ? 'https://api.anthropic.com'
          : selectedProvider == 'OpenAI'
            ? 'https://api.openai.com'
            : selectedProvider == 'Google'
              ? 'https://generativelanguage.googleapis.com'
              : selectedProvider == 'Moonshot (Kimi)'
                ? 'https://api.moonshot.cn'
                : 'https://api.anthropic.com',
        isDefault: widget.existingModelConfig?.isDefault ?? 
                   widget.existingConfig?.isDefault ?? 
                   false, // Don't automatically set as default
        enabled: true,
        status: ModelStatus.ready, // API models are ready once configured
      );

      await modelConfigsNotifier.addModel(modelConfig);
      
      // Note: Users can manually set defaults through model management UI
      // No automatic default setting with multiple providers

      if (mounted) {
        Navigator.of(context).pop(true);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (widget.existingModelConfig != null || widget.existingConfig != null || widget.existingDirectConfig != null)
                ? 'AI model updated successfully!'
                : 'AI model added successfully!',
            ),
            backgroundColor: ThemeColors(context).success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save AI model: $e'),
            backgroundColor: ThemeColors(context).error,
          ),
        );
      }
    }
  }
}
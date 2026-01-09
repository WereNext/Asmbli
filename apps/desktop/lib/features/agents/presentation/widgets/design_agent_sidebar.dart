import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/models/agent_template.dart';
import '../../../../core/di/service_locator.dart';
// import '../../../../core/services/design_agent_orchestrator_service.dart'; // Removed for single model optimization
import '../../../../core/services/llm/unified_llm_service.dart';
import '../../../../core/services/llm/llm_provider.dart';
import '../../../../core/services/model_config_service.dart';
import '../../../../core/models/model_config.dart';
import 'package:agent_engine_core/models/agent.dart';

/// Agentic chat sidebar for design agents with plan/act modes and AI model display
class DesignAgentSidebar extends ConsumerStatefulWidget {
  final Agent agent;
  final Function(Map<String, dynamic>) onSpecUpdate;
  final Function(List<String>) onContextUpdate;
  
  // Canvas action callbacks for direct Excalidraw integration
  final Function(String elementType, String prompt)? onAddCanvasElement;
  final Function(String templateType)? onAddTemplate;
  final Function(String componentKey, String category)? onAddFlutterComponent;
  final Function(String templateType)? onAddFlutterScreenTemplate;
  final Function()? onGenerateCode;
  final Function()? onClearCanvas;
  final Function()? onCaptureCanvas;
  
  // MCP-powered message processing callback
  final Future<String> Function(String message)? onProcessMessage;
  
  const DesignAgentSidebar({
    super.key,
    required this.agent,
    required this.onSpecUpdate,
    required this.onContextUpdate,
    this.onAddCanvasElement,
    this.onAddTemplate,
    this.onAddFlutterComponent,
    this.onAddFlutterScreenTemplate,
    this.onGenerateCode,
    this.onClearCanvas,
    this.onCaptureCanvas,
    this.onProcessMessage,
  });

  @override
  ConsumerState<DesignAgentSidebar> createState() => _DesignAgentSidebarState();
}

class _DesignAgentSidebarState extends ConsumerState<DesignAgentSidebar> {
  // Agent mode and chat state
  String _agentMode = 'plan'; // 'plan' or 'act'
  final List<ChatMessage> _chatMessages = [];
  final TextEditingController _chatController = TextEditingController();
  
  // LLM service for single model approach
  final bool _isServiceAvailable = false;
  UnifiedLLMService? _llmService;
  
  // Model selection state
  List<ModelConfig> _availableModels = [];
  String? _selectedPlanModelId;
  String? _selectedActModelId;
  final bool _showModelSelector = false;
  
  // Basic spec state for context
  String _projectType = 'web_app';
  String _designPhase = 'concept';
  List<String> _selectedPlatforms = ['responsive_web'];
  
  // Context state
  final List<DesignContext> _contexts = [];
  final _contextController = TextEditingController();
  String _contextType = 'brand_guidelines';
  
  // Tab state for sidebar
  String _activeTab = 'chat'; // 'chat', 'specs'
  
  @override
  void initState() {
    super.initState();
    _initializeChat();
    _initializeLLMService();
  }
  
  Future<void> _initializeLLMService() async {
    try {
      debugPrint('🔍 Design agent: Loading LLM service...');
      _llmService = ServiceLocator.instance.get<UnifiedLLMService>();
      
      debugPrint('🔍 Design agent: Getting available providers...');
      final providers = _llmService!.getAvailableProviders();
      debugPrint('🔍 Design agent: Found ${providers.length} providers');
      
      // If no providers, try to access the ModelConfigService directly
      if (providers.isEmpty) {
        debugPrint('🔍 Design agent: No providers found, trying ModelConfigService...');
        try {
          final modelConfigService = ServiceLocator.instance.get<ModelConfigService>();
          debugPrint('🔍 Design agent: Got ModelConfigService, checking available models...');
          
          // Let's try to get the model configs directly
          final allModelConfigs = modelConfigService.allModelConfigs.values.toList();
          debugPrint('🔍 Design agent: ModelConfigService has ${allModelConfigs.length} models');
          
          setState(() {
            _availableModels = allModelConfigs;
            
            // Auto-select recommended models
            for (final model in _availableModels) {
              final modelName = (model.ollamaModelId ?? model.id).toLowerCase();
              debugPrint('🔍 Design agent: Checking model: $modelName (${model.name})');
              
              if (modelName.contains('deepseek') && modelName.contains('r1') && _selectedPlanModelId == null) {
                _selectedPlanModelId = model.id;
                debugPrint('🔍 Design agent: Selected plan model: ${model.id}');
              }
              if (modelName.contains('llava') && _selectedActModelId == null) {
                _selectedActModelId = model.id;
                debugPrint('🔍 Design agent: Selected act model: ${model.id}');
              }
            }
          });
          
        } catch (modelServiceError) {
          debugPrint('❌ Design agent: Error accessing ModelConfigService: $modelServiceError');
        }
      } else {
        final modelConfigs = providers.map((p) => p.modelConfig).toList();
        debugPrint('🔍 Design agent: Model configs: ${modelConfigs.map((m) => '${m.name} (${m.id})').join(', ')}');
        
        setState(() {
          _availableModels = modelConfigs;
          
          // Auto-select recommended models
          for (final model in _availableModels) {
            final modelName = (model.ollamaModelId ?? model.id).toLowerCase();
            debugPrint('🔍 Design agent: Checking model: $modelName');
            
            if (modelName.contains('deepseek') && modelName.contains('r1') && _selectedPlanModelId == null) {
              _selectedPlanModelId = model.id;
              debugPrint('🔍 Design agent: Selected plan model: ${model.id}');
            }
            if (modelName.contains('llava') && _selectedActModelId == null) {
              _selectedActModelId = model.id;
              debugPrint('🔍 Design agent: Selected act model: ${model.id}');
            }
          }
        });
      }
      
      debugPrint('🔍 Design agent: Available models loaded: ${_availableModels.length} models');
      debugPrint('🔍 Design agent: Auto-selected plan model: $_selectedPlanModelId');
      debugPrint('🔍 Design agent: Auto-selected act model: $_selectedActModelId');
      
    } catch (e) {
      debugPrint('❌ Design agent: Error loading LLM service: $e');
      debugPrint('❌ Design agent: Stack trace: ${e.toString()}');
    }
  }
  
  // Duplicate method removed

  @override
  void dispose() {
    _chatController.dispose();
    _contextController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final colors = ThemeColors(context);
    
    return Container(
      width: 400,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          left: BorderSide(color: colors.border),
        ),
      ),
      child: Column(
        children: [
          _buildAgentHeader(colors),
          // Mode selector removed - single model approach
          _buildAIModelInfo(colors),
          _buildContextPanel(colors),
          Expanded(
            child: _buildTabContent(colors),
          ),
          if (_activeTab == 'chat') _buildChatInput(colors),
        ],
      ),
    );
  }
  
  void _initializeChat() {
    _chatMessages.add(ChatMessage(
      message: "Hello! I'm your design agent with canvas tool calling.\n\n✨ **I can create visual elements directly on the canvas**\n🎨 Try: \"create a blue circle\" or \"add a dashboard wireframe\"\n\nWhat would you like to design?",
      isAgent: true,
      timestamp: DateTime.now(),
    ));
  }

  Widget _buildAgentHeader(ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.md,
        vertical: SpacingTokens.sm,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colors.border),
        ),
      ),
      child: Row(
        children: [
          // Compact agent avatar with status
          Stack(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colors.primary, colors.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.design_services,
                  color: colors.surface,
                  size: 16,
                ),
              ),
              // Status indicator
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colors.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.surface, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: SpacingTokens.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Design Agent',
                  style: TextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
                if (_isServiceAvailable)
                  Text(
                    '📱 Single Model • Tool Calling Ready',
                    style: TextStyles.caption.copyWith(
                      color: colors.success,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
          // Specs button
          Container(
            margin: const EdgeInsets.only(right: SpacingTokens.xs),
            child: Material(
              color: _activeTab == 'specs' ? colors.primary.withValues(alpha: 0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _activeTab = _activeTab == 'specs' ? 'chat' : 'specs';
                  });
                },
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SpacingTokens.sm,
                    vertical: SpacingTokens.xs,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.assignment,
                        size: 16,
                        color: _activeTab == 'specs' ? colors.primary : colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: SpacingTokens.xs),
                      Text(
                        'Specs',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: _activeTab == 'specs' ? FontWeight.w600 : FontWeight.w400,
                          color: _activeTab == 'specs' ? colors.primary : colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Clear chat button
          IconButton(
            icon: const Icon(Icons.clear_all, size: 16),
            onPressed: _clearChat,
            style: IconButton.styleFrom(
              foregroundColor: colors.onSurfaceVariant,
              padding: const EdgeInsets.all(SpacingTokens.xs),
            ),
            tooltip: 'Clear chat',
          ),
        ],
      ),
    );
  }
  
  Widget _buildCompactModeSelector(ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.md,
        vertical: SpacingTokens.sm,
      ),
      decoration: BoxDecoration(
        color: colors.background.withOpacity(0.3),
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Text(
            'Mode:',
            style: TextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(width: SpacingTokens.sm),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  _buildCompactModeButton(
                    'plan',
                    'Plan',
                    Icons.lightbulb_outline,
                    colors,
                  ),
                  _buildCompactModeButton(
                    'act',
                    'Act',
                    Icons.play_arrow,
                    colors,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactModeButton(
    String mode,
    String title,
    IconData icon,
    ThemeColors colors,
  ) {
    final isActive = _agentMode == mode;
    final modeColor = mode == 'plan' ? colors.primary : colors.accent;
    
    return Expanded(
      child: Material(
        color: isActive 
          ? modeColor.withOpacity(0.1)
          : Colors.transparent,
        borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
        child: InkWell(
          onTap: () {
            setState(() {
              _agentMode = mode;
            });
            // Mode change removed - single model approach
          },
          borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.xs,
              vertical: SpacingTokens.xs,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isActive ? modeColor : colors.onSurfaceVariant,
                  size: 14,
                ),
                const SizedBox(width: SpacingTokens.xs),
                Text(
                  title,
                  style: TextStyles.caption.copyWith(
                    color: isActive ? modeColor : colors.onSurface,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContextPanel(ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.md),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder_open, color: colors.accent, size: 16),
              const SizedBox(width: SpacingTokens.xs),
              Text(
                'Context (${_contexts.length})',
                style: TextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add, size: 16),
                onPressed: _showAddContextDialog,
                style: IconButton.styleFrom(
                  foregroundColor: colors.primary,
                  padding: const EdgeInsets.all(SpacingTokens.xs),
                ),
              ),
            ],
          ),
          
          if (_contexts.isEmpty) ...[
            const SizedBox(height: SpacingTokens.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(SpacingTokens.sm),
              decoration: BoxDecoration(
                color: colors.surface.withOpacity(0.5),
                borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
                border: Border.all(color: colors.border, style: BorderStyle.solid),
              ),
              child: Text(
                'No context added yet',
                style: TextStyles.caption.copyWith(
                  color: colors.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ] else ...[
            const SizedBox(height: SpacingTokens.sm),
            ...(_contexts.map((context) => _buildCompactContextItem(context, colors))),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactContextItem(DesignContext context, ThemeColors colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: SpacingTokens.xs),
      padding: const EdgeInsets.all(SpacingTokens.xs),
      decoration: BoxDecoration(
        color: colors.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: _getContextColor(context.type).withOpacity(0.1),
              borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
            ),
            child: Icon(
              _getContextIcon(context.type),
              size: 12,
              color: _getContextColor(context.type),
            ),
          ),
          const SizedBox(width: SpacingTokens.xs),
          Expanded(
            child: Text(
              context.name,
              style: TextStyles.caption.copyWith(
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 12),
            onPressed: () {
              setState(() {
                _contexts.remove(context);
              });
              _updateSpecifications();
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 20, height: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildAIModelInfo(ThemeColors colors) {
    if (!_isServiceAvailable) return const SizedBox.shrink();
    
    final modelId = widget.agent.configuration['modelConfiguration']['primaryModelId'] ?? 'local_llama3.1_8b';
    final modelName = _getHumanReadableModelName(modelId);
    final hasToolCalling = modelId.contains('llama3.1');
    
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.sm),
      decoration: BoxDecoration(
        color: colors.success.withOpacity(0.05),
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Icon(
            hasToolCalling ? Icons.build_circle : Icons.chat_bubble,
            color: colors.success,
            size: 16,
          ),
          const SizedBox(width: SpacingTokens.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  modelName,
                  style: TextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
                if (hasToolCalling)
                  Text(
                    'Canvas tool calling enabled',
                    style: TextStyles.caption.copyWith(
                      color: colors.success,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCompactModelDisplay(ThemeColors colors) {
    final planModelName = _getModelDisplayName(_selectedPlanModelId);
    final actModelName = _getModelDisplayName(_selectedActModelId);
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(SpacingTokens.md, 0, SpacingTokens.md, SpacingTokens.xs),
      child: Row(
        children: [
          // Plan model
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: colors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
                  ),
                  child: Icon(
                    Icons.lightbulb_outline,
                    size: 10,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: SpacingTokens.xs),
                Flexible(
                  child: Text(
                    planModelName,
                    style: TextStyles.caption.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: SpacingTokens.sm),
          // Act model  
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: colors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
                  ),
                  child: Icon(
                    Icons.remove_red_eye,
                    size: 10,
                    color: colors.accent,
                  ),
                ),
                const SizedBox(width: SpacingTokens.xs),
                Flexible(
                  child: Text(
                    actModelName,
                    style: TextStyles.caption.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildModelSelector(ThemeColors colors) {
    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Plan model selector
          Text(
            'Plan Mode Model:',
            style: TextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: SpacingTokens.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.sm),
            decoration: BoxDecoration(
              border: Border.all(color: colors.border),
              borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
            ),
            child: DropdownButton<String>(
              value: _selectedPlanModelId,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              style: TextStyles.caption.copyWith(color: colors.onSurface),
              items: _availableModels.map((model) {
                return DropdownMenuItem<String>(
                  value: model.id,
                  child: Text(
                    model.name,
                    style: TextStyles.caption,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedPlanModelId = value;
                });
                _updateAgentConfiguration();
              },
            ),
          ),
          const SizedBox(height: SpacingTokens.md),
          
          // Act model selector
          Text(
            'Act Mode Model:',
            style: TextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.accent,
            ),
          ),
          const SizedBox(height: SpacingTokens.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.sm),
            decoration: BoxDecoration(
              border: Border.all(color: colors.border),
              borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
            ),
            child: DropdownButton<String>(
              value: _selectedActModelId,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              style: TextStyles.caption.copyWith(color: colors.onSurface),
              items: _availableModels.map((model) {
                return DropdownMenuItem<String>(
                  value: model.id,
                  child: Text(
                    model.name,
                    style: TextStyles.caption,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedActModelId = value;
                });
                _updateAgentConfiguration();
              },
            ),
          ),
        ],
      ),
    );
  }
  
  String _getModelDisplayName(String? modelId) {
    if (modelId == null) return 'Not selected';
    
    try {
      final model = _availableModels.firstWhere((m) => m.id == modelId);
      return _formatModelName(model.name);
    } catch (e) {
      // Model not found in available models, return formatted model ID
      return _formatModelName(modelId);
    }
  }
  
  void _updateAgentConfiguration() {
    // Update agent configuration with selected models
    if (_selectedPlanModelId != null && _selectedActModelId != null) {
      final updatedConfig = Map<String, dynamic>.from(widget.agent.configuration ?? {});
      updatedConfig['modelConfiguration'] = {
        'primaryModelId': _selectedPlanModelId,
        'visionModelId': _selectedActModelId,
      };
      
      debugPrint('🔧 Updated agent configuration: Plan=$_selectedPlanModelId, Act=$_selectedActModelId');
      
      // Reinitialize orchestrator with new models
      // Service already initialized
    }
  }
  
  // Model refresh removed - single model approach
  Future<void> _checkModelStatus() async {
    debugPrint('🔄 Design agent: Refreshing models...');
    // Service already initialized
    
    if (_availableModels.isNotEmpty) {
      _addChatMessage('🔄 Refreshed model list: ${_availableModels.length} models available', true);
    } else {
      _addChatMessage('⚠️ No models found. Make sure Ollama is running with models installed.', true);
    }
  }

  Widget _buildChatInterface(ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.md),
      child: ListView.builder(
        itemCount: _chatMessages.length,
        itemBuilder: (context, index) {
          return _buildChatMessage(_chatMessages[index], colors);
        },
      ),
    );
  }

  Widget _buildChatMessage(ChatMessage message, ThemeColors colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: SpacingTokens.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: message.isAgent ? colors.primary : colors.accent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              message.isAgent ? Icons.auto_awesome : Icons.person,
              color: colors.surface,
              size: 16,
            ),
          ),
          const SizedBox(width: SpacingTokens.sm),
          
          // Message content
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(SpacingTokens.md),
              decoration: BoxDecoration(
                color: message.isAgent 
                  ? colors.surface
                  : colors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
                border: Border.all(
                  color: message.isAgent 
                    ? colors.border
                    : colors.primary.withOpacity(0.3),
                ),
              ),
              child: MarkdownBody(
                data: message.message,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyles.bodySmall.copyWith(
                    color: colors.onSurface,
                  ),
                  strong: TextStyles.bodySmall.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  em: TextStyles.bodySmall.copyWith(
                    color: colors.onSurface,
                    fontStyle: FontStyle.italic,
                  ),
                  code: TextStyles.bodySmall.copyWith(
                    color: colors.primary,
                    backgroundColor: colors.surface.withOpacity(0.1),
                    fontFamily: 'monospace',
                  ),
                  codeblockPadding: const EdgeInsets.all(SpacingTokens.sm),
                  codeblockDecoration: BoxDecoration(
                    color: colors.surface.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
                    border: Border.all(color: colors.border),
                  ),
                  listBullet: TextStyles.bodySmall.copyWith(
                    color: colors.primary,
                  ),
                  h1: TextStyles.sectionTitle.copyWith(
                    color: colors.onSurface,
                  ),
                  h2: TextStyles.cardTitle.copyWith(
                    color: colors.onSurface,
                  ),
                  h3: TextStyles.bodyMedium.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  blockquote: TextStyles.bodySmall.copyWith(
                    color: colors.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                  blockquoteDecoration: BoxDecoration(
                    border: Border(left: BorderSide(color: colors.primary, width: 3)),
                  ),
                ),
                selectable: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatInput(ThemeColors colors) {
    final hintText = _agentMode == 'plan' 
      ? 'Ask me to help plan, analyze, or strategize...'
      : 'Tell me what to create, modify, or execute...';
    
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.border)),
        color: colors.background,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
                  controller: _chatController,
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: TextStyles.bodySmall.copyWith(color: colors.onSurfaceVariant),
                    prefixIcon: Icon(
                      _agentMode == 'plan' ? Icons.lightbulb_outline : Icons.play_arrow,
                      size: 20,
                      color: _agentMode == 'plan' ? colors.primary : colors.accent,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
                      borderSide: BorderSide(
                        color: _agentMode == 'plan' ? colors.primary : colors.accent,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: SpacingTokens.md,
                      vertical: SpacingTokens.sm,
                    ),
                    filled: true,
                    fillColor: colors.surface,
                  ),
                  maxLines: 1,
                  onSubmitted: (value) => _sendMessage(),
                ),
              ),
              const SizedBox(width: SpacingTokens.sm),
              IconButton(
                onPressed: _sendMessage,
                icon: Icon(_agentMode == 'plan' ? Icons.psychology : Icons.send),
                style: IconButton.styleFrom(
                  backgroundColor: _agentMode == 'plan' ? colors.primary : colors.accent,
                  foregroundColor: colors.surface,
                  padding: const EdgeInsets.all(SpacingTokens.md),
                ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  
  String _formatModelName(String modelId) {
    // Clean up model names for display
    if (modelId.contains('deepseek-r1')) {
      return 'DeepSeek R1';
    } else if (modelId.contains('llava')) {
      return 'LLaVA Vision';
    } else if (modelId.contains('claude')) {
      return 'Claude';
    } else if (modelId.contains('gpt')) {
      return 'GPT-4';
    }
    return modelId.split('_').last.split(':').first;
  }

  void _addModeChangeMessage(String newMode) {
    final message = newMode == 'plan' 
      ? 'Switched to Planning Mode. I\'ll help you think through design strategies and create comprehensive plans.'
      : 'Switched to Action Mode. I\'ll take direct actions and create elements based on our collaborative planning.';
    
    Future.delayed(const Duration(milliseconds: 300), () {
      _addChatMessage(message, true);
    });
  }

  void _addChatMessage(String message, bool isAgent) {
    // Prevent duplicate messages (dynamic UX improvement)
    if (_chatMessages.isNotEmpty && 
        _chatMessages.last.message == message && 
        _chatMessages.last.isAgent == isAgent) {
      return; // Skip duplicate message
    }
    
    setState(() {
      _chatMessages.add(ChatMessage(
        message: message,
        isAgent: isAgent,
        timestamp: DateTime.now(),
      ));
    });
  }

  void _clearChat() {
    setState(() {
      _chatMessages.clear();
    });
    _initializeChat();
  }

  void _sendMessage() {
    final message = _chatController.text.trim();
    if (message.isEmpty) return;
    
    // Add user message
    _addChatMessage(message, false);
    _chatController.clear();
    
    // Add thinking indicator
    _addChatMessage('🤔 Thinking...', true);
    
    // Generate AI response based on mode
    _generateResponse(message);
  }
  
  Future<void> _generateResponse(String message) async {
    try {
      String response = '';
      
      // Use MCP-powered message processing
      if (widget.onProcessMessage != null) {
        response = await widget.onProcessMessage!(message);
      } else {
        // Fallback to simple chat response
        response = 'I can help you create visual elements on the canvas. Try asking me to create shapes, wireframes, or templates.';
      }
      
      // Remove thinking indicator and add real response
      setState(() {
        if (_chatMessages.isNotEmpty && _chatMessages.last.message == '🤔 Thinking...') {
          _chatMessages.removeLast();
        }
        _chatMessages.add(ChatMessage(
          message: response,
          isAgent: true,
          timestamp: DateTime.now(),
        ));
      });
      
      // Update spec based on conversation
      _updateSpecFromConversation(message);
    } catch (e) {
      // Remove thinking indicator and add error message
      setState(() {
        if (_chatMessages.isNotEmpty && _chatMessages.last.message == '🤔 Thinking...') {
          _chatMessages.removeLast();
        }
        _chatMessages.add(ChatMessage(
          message: '⚠️ Sorry, I encountered an error. Please try again.',
          isAgent: true,
          timestamp: DateTime.now(),
        ));
      });
      debugPrint('Error generating response: $e');
    }
  }

  Future<String> _generatePlanModeResponse(String message) async {
    if (!_isServiceAvailable || _llmService == null) {
      return _getFallbackPlanResponse(message);
    }
    
    try {
      // Use the direct LLM service with the selected model
      if (_llmService != null) {
        const systemPrompt = '''You are an expert UI/UX design planner. Your role is to:
1. Analyze design requirements and break them into clear, actionable steps
2. Consider user experience, accessibility, and modern design principles
3. Suggest appropriate design patterns and component structures
4. Plan the visual hierarchy and information architecture

Provide structured, detailed plans that can guide the implementation process.''';

        final projectContext = _buildProjectContext();
        final prompt = '''Create a comprehensive design plan for the following request:

User Request: $message

${projectContext.isNotEmpty ? 'Project Context: $projectContext\n' : ''}

Provide a structured plan including:
1. Design objectives and goals
2. Key UI components needed
3. Visual hierarchy and layout structure
4. Color scheme and typography recommendations
5. Interaction patterns and user flows
6. Accessibility considerations
7. Implementation phases''';
        
        final response = await _llmService!.chat(
          message: prompt,
          modelId: _selectedPlanModelId!,
          context: ChatContext(systemPrompt: systemPrompt),
        );
        
        return response.content;
      }
      
      return _getFallbackPlanResponse(message);
    } catch (e) {
      debugPrint('Error generating plan response: $e');
      return _getFallbackPlanResponse(message);
    }
  }
  
  String _buildProjectContext() {
    final contextParts = <String>[];
    
    contextParts.add('Project Type: $_projectType');
    contextParts.add('Design Phase: $_designPhase');
    contextParts.add('Platforms: ${_selectedPlatforms.join(', ')}');
    
    if (_contexts.isNotEmpty) {
      contextParts.add('Available Context:');
      for (final context in _contexts) {
        contextParts.add('- ${context.type}: ${context.name}');
      }
    }
    
    return contextParts.join('\n');
  }
  
  String _getFallbackPlanResponse(String message) {
    final lowerMessage = message.toLowerCase();
    
    if (lowerMessage.contains('dashboard') || lowerMessage.contains('admin')) {
      return 'For a dashboard design, let\'s plan the information architecture:\n\n• **Data Visualization**: What key metrics need prominent display?\n• **User Workflows**: Which actions should be most accessible?\n• **Content Hierarchy**: How should we organize different data types?\n\nWhat specific goals does this dashboard need to achieve?';
    } else if (lowerMessage.contains('mobile') || lowerMessage.contains('app')) {
      return 'Great! For mobile app planning, let\'s consider:\n\n• **User Journey**: What\'s the primary user flow?\n• **Touch Interactions**: Key gestures and touch targets\n• **Platform Guidelines**: iOS vs Android considerations\n• **Performance**: Loading states and offline capabilities\n\nWhat type of mobile experience are you envisioning?';
    } else if (lowerMessage.contains('website') || lowerMessage.contains('web')) {
      return 'For web design planning:\n\n• **Information Architecture**: How should content be structured?\n• **Responsive Strategy**: Desktop-first or mobile-first approach?\n• **User Goals**: What actions should users complete?\n• **Content Strategy**: What content drives conversions?\n\nLet\'s define the primary user journey first.';
    }
    
    return 'I\'m here to help you plan strategically. Let\'s think through:\n\n• **Project Goals**: What problem are we solving?\n• **User Needs**: Who are we designing for?\n• **Technical Constraints**: What limitations should we consider?\n• **Success Metrics**: How will we measure success?\n\nWhat aspect would you like to explore first?';
  }

  Future<String> _generateActModeResponse(String message) async {
    if (!_isServiceAvailable || _llmService == null) {
      return _getFallbackActResponse(message);
    }
    
    try {
      // Use the direct LLM service with the selected model for action-oriented tasks
      if (_llmService != null) {
        final lowerMessage = message.toLowerCase();
        
        String systemPrompt;
        String prompt;
        
        if (lowerMessage.contains('suggest') || lowerMessage.contains('recommend')) {
          systemPrompt = '''You are an expert design consultant specializing in actionable design recommendations. Provide specific, practical suggestions that can be immediately implemented.''';
          
          prompt = '''Based on the following context, provide 3-5 specific, actionable design suggestions:

User Request: $message

Project Context:
${_buildProjectContext()}

Available Design Context:
${_contexts.map((c) => '- ${c.type}: ${c.name}').join('\n')}

Provide creative, practical suggestions with clear implementation steps.''';
          
        } else if (lowerMessage.contains('generate') || lowerMessage.contains('implement') || lowerMessage.contains('code')) {
          systemPrompt = '''You are an expert frontend developer. Generate clean, maintainable code that follows best practices and includes proper accessibility attributes.''';
          
          prompt = '''Generate implementation code for the following request:

User Request: $message

Project Context:
${_buildProjectContext()}

Provide complete, production-ready code with:
- Proper component structure
- Responsive design implementation
- Accessibility attributes
- Comments for complex sections''';
          
        } else {
          systemPrompt = '''You are an expert design action agent. You take direct actions and provide specific, implementable solutions for design tasks.''';
          
          prompt = '''Provide a specific, actionable response to this design request:

User Request: $message

Project Context:
${_buildProjectContext()}

Focus on concrete actions and specific implementation details.''';
        }
        
        final response = await _llmService!.chat(
          message: prompt,
          modelId: _selectedActModelId!,
          context: ChatContext(systemPrompt: systemPrompt),
        );
        
        // Parse AI response for canvas actions
        _parseAndExecuteAIActions(response.content, message);
        
        return response.content;
      }
      
      return _getFallbackActResponse(message);
    } catch (e) {
      debugPrint('Error generating act response: $e');
      return _getFallbackActResponse(message);
    }
  }
  
  String _getFallbackActResponse(String message) {
    final lowerMessage = message.toLowerCase();
    
    if (lowerMessage.contains('create') || lowerMessage.contains('make')) {
      // Parse and execute canvas actions
      _executeCanvasActions(message, lowerMessage);
      return 'I\'ll create that design element for you based on our planning discussion. I\'m ready to take direct action on the canvas.\n\n**Action taken**: Creating the requested element with appropriate styling and positioning.';
    } else if (lowerMessage.contains('modify') || lowerMessage.contains('change')) {
      return 'I\'ll modify the existing design elements as requested. Using our established design strategy to ensure consistency.\n\n**Action taken**: Applied changes while maintaining design system principles.';
    } else if (lowerMessage.contains('analyze') || lowerMessage.contains('review')) {
      widget.onCaptureCanvas?.call();
      return 'I\'ll analyze the current canvas state and provide specific feedback based on our collaborative plan.\n\n**Visual Analysis**: Reviewing layout, typography, spacing, and alignment against our established design principles.';
    } else if (lowerMessage.contains('clear') || lowerMessage.contains('reset')) {
      widget.onClearCanvas?.call();
      return '🗑️ I\'ve cleared the canvas for you. Ready to start fresh with a new design!';
    } else if (lowerMessage.contains('generate code') || lowerMessage.contains('code generation')) {
      widget.onGenerateCode?.call();
      return '⚙️ I\'m generating code from your current wireframe. This will analyze the design and create implementation code.';
    }
    
    return 'I\'m ready to take direct action! I can:\n\n• **Create Elements**: Add components, layouts, or content\n• **Modify Designs**: Adjust existing elements\n• **Apply Styles**: Implement design system choices\n• **Generate Layouts**: Create structured wireframes\n• **Analyze Design**: Review current canvas state\n• **Generate Code**: Create implementation from wireframes\n\nWhat specific action would you like me to take?';
  }

  /// Parse user message and execute corresponding canvas actions
  void _executeCanvasActions(String originalMessage, String lowerMessage) {
    // Element creation actions
    if (lowerMessage.contains('button') || lowerMessage.contains('btn')) {
      widget.onAddCanvasElement?.call('rectangle', 'Button: ${_extractElementLabel(originalMessage, 'button')}');
    } else if (lowerMessage.contains('input') || lowerMessage.contains('textfield') || lowerMessage.contains('text field')) {
      widget.onAddCanvasElement?.call('input', 'Input Field: ${_extractElementLabel(originalMessage, 'input')}');
    } else if (lowerMessage.contains('header') || lowerMessage.contains('navigation')) {
      if (lowerMessage.contains('web') || lowerMessage.contains('website')) {
        widget.onAddTemplate?.call('web_header');
      } else {
        widget.onAddCanvasElement?.call('rectangle', 'Header: ${_extractElementLabel(originalMessage, 'header')}');
      }
    } else if (lowerMessage.contains('mobile') && (lowerMessage.contains('app') || lowerMessage.contains('screen'))) {
      widget.onAddTemplate?.call('mobile_app');
    } else if (lowerMessage.contains('dashboard') || lowerMessage.contains('admin')) {
      widget.onAddFlutterScreenTemplate?.call('dashboard');
    } else if (lowerMessage.contains('list') || lowerMessage.contains('table')) {
      widget.onAddFlutterScreenTemplate?.call('list');
    } else if (lowerMessage.contains('form') || lowerMessage.contains('registration') || lowerMessage.contains('signup')) {
      widget.onAddFlutterScreenTemplate?.call('form');
    } else if (lowerMessage.contains('card') || lowerMessage.contains('container')) {
      widget.onAddCanvasElement?.call('rectangle', 'Card: ${_extractElementLabel(originalMessage, 'card')}');
    } else if (lowerMessage.contains('icon')) {
      widget.onAddCanvasElement?.call('icon-home', 'Icon: ${_extractElementLabel(originalMessage, 'icon')}');
    } else if (lowerMessage.contains('arrow')) {
      widget.onAddCanvasElement?.call('arrow', 'Arrow connection');
    } else if (lowerMessage.contains('checkbox') || lowerMessage.contains('check box')) {
      widget.onAddCanvasElement?.call('checkbox', 'Checkbox: ${_extractElementLabel(originalMessage, 'checkbox')}');
    }
    
    // Flutter component actions  
    else if (lowerMessage.contains('flutter')) {
      if (lowerMessage.contains('appbar') || lowerMessage.contains('app bar')) {
        widget.onAddFlutterComponent?.call('appBar', 'material');
      } else if (lowerMessage.contains('fab') || lowerMessage.contains('floating action')) {
        widget.onAddFlutterComponent?.call('floatingActionButton', 'material');
      } else if (lowerMessage.contains('elevated button')) {
        widget.onAddFlutterComponent?.call('elevatedButton', 'material');
      } else if (lowerMessage.contains('text field')) {
        widget.onAddFlutterComponent?.call('textField', 'forms');
      } else if (lowerMessage.contains('column')) {
        widget.onAddFlutterComponent?.call('column', 'layout');
      } else if (lowerMessage.contains('row')) {
        widget.onAddFlutterComponent?.call('row', 'layout');
      } else if (lowerMessage.contains('stack')) {
        widget.onAddFlutterComponent?.call('stack', 'layout');
      }
    }
    
    // Default action
    else {
      widget.onAddCanvasElement?.call('rectangle', originalMessage);
    }
  }
  
  /// Extract meaningful label from user message for element naming
  String _extractElementLabel(String message, String elementType) {
    final lowerMessage = message.toLowerCase();
    final words = message.split(' ');
    
    // Find the element type position and extract context
    final elementIndex = words.indexWhere((word) => word.toLowerCase().contains(elementType));
    
    if (elementIndex != -1) {
      // Look for descriptive words around the element type
      final contextWords = <String>[];
      
      // Get words before the element type
      if (elementIndex > 0) {
        contextWords.addAll(words.take(elementIndex).where((word) => 
          !['create', 'add', 'make', 'a', 'an', 'the', 'some'].contains(word.toLowerCase())
        ));
      }
      
      // Get words after the element type
      if (elementIndex < words.length - 1) {
        contextWords.addAll(words.skip(elementIndex + 1).where((word) => 
          !['for', 'with', 'that', 'to', 'on', 'in'].contains(word.toLowerCase())
        ));
      }
      
      if (contextWords.isNotEmpty) {
        return contextWords.join(' ');
      }
    }
    
    // Return a default label based on element type
    return elementType.substring(0, 1).toUpperCase() + elementType.substring(1);
  }

  /// Parse AI response for actionable commands and execute them
  void _parseAndExecuteAIActions(String aiResponse, String originalMessage) {
    final lowerResponse = aiResponse.toLowerCase();
    final lowerMessage = originalMessage.toLowerCase();
    
    // Look for action indicators in AI response
    if (lowerResponse.contains('creating') || lowerResponse.contains('adding') || lowerResponse.contains('i\'ll create') || lowerResponse.contains('i will create')) {
      // Execute canvas actions based on original user message
      _executeCanvasActions(originalMessage, lowerMessage);
    }
    
    // Look for specific action commands in AI response
    if (lowerResponse.contains('[action:') && lowerResponse.contains(']')) {
      _executeAIActionCommands(aiResponse);
    }
    
    // Look for template suggestions in AI response
    if (lowerResponse.contains('mobile app template') || lowerResponse.contains('mobile template')) {
      widget.onAddTemplate?.call('mobile_app');
    } else if (lowerResponse.contains('web header template') || lowerResponse.contains('header template')) {
      widget.onAddTemplate?.call('web_header');
    } else if (lowerResponse.contains('dashboard template')) {
      widget.onAddFlutterScreenTemplate?.call('dashboard');
    }
  }

  /// Execute specific action commands found in AI response
  void _executeAIActionCommands(String aiResponse) {
    final actionRegex = RegExp(r'\[action:(.*?)\]', caseSensitive: false);
    final matches = actionRegex.allMatches(aiResponse);
    
    for (final match in matches) {
      final actionCommand = match.group(1)?.trim().toLowerCase();
      if (actionCommand == null) continue;
      
      final parts = actionCommand.split(':');
      final action = parts[0];
      final param = parts.length > 1 ? parts[1] : '';
      
      switch (action) {
        case 'add_element':
          if (param.isNotEmpty) {
            final elementParts = param.split(',');
            final elementType = elementParts[0].trim();
            final label = elementParts.length > 1 ? elementParts[1].trim() : elementType;
            widget.onAddCanvasElement?.call(elementType, label);
          }
          break;
        case 'add_template':
          if (param.isNotEmpty) {
            widget.onAddTemplate?.call(param.trim());
          }
          break;
        case 'add_flutter':
          if (param.isNotEmpty) {
            final componentParts = param.split(',');
            final componentKey = componentParts[0].trim();
            final category = componentParts.length > 1 ? componentParts[1].trim() : 'material';
            widget.onAddFlutterComponent?.call(componentKey, category);
          }
          break;
        case 'generate_code':
          widget.onGenerateCode?.call();
          break;
        case 'clear_canvas':
          widget.onClearCanvas?.call();
          break;
        case 'capture_canvas':
          widget.onCaptureCanvas?.call();
          break;
      }
    }
  }

  void _updateSpecFromConversation(String message) {
    final lowerMessage = message.toLowerCase();
    
    // Update project type based on conversation
    if (lowerMessage.contains('dashboard') && _projectType != 'dashboard') {
      setState(() {
        _projectType = 'dashboard';
        _designPhase = 'wireframe';
      });
      _notifySpecUpdate();
    } else if (lowerMessage.contains('mobile') || lowerMessage.contains('app')) {
      setState(() {
        _projectType = 'mobile_app';
        _selectedPlatforms = ['ios', 'android'];
      });
      _notifySpecUpdate();
    } else if (lowerMessage.contains('ecommerce') || lowerMessage.contains('shop')) {
      setState(() {
        _projectType = 'e_commerce';
      });
      _notifySpecUpdate();
    }
  }

  void _notifySpecUpdate() {
    final spec = {
      'projectType': _projectType,
      'designPhase': _designPhase,
      'platforms': _selectedPlatforms,
      'requirements': {},
      'contexts': _contexts.map((c) => c.toMap()).toList(),
    };
    widget.onSpecUpdate(spec);
    widget.onContextUpdate(_contexts.map((c) => c.path ?? c.name).toList());
  }

  // Context management methods
  void _showAddContextDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final colors = ThemeColors(context);
        return AlertDialog(
          title: const Text('Add Design Context'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _contextType,
                decoration: const InputDecoration(
                  labelText: 'Context Type',
                  border: OutlineInputBorder(),
                ),
                items: {
                  'brand_guidelines': 'Brand Guidelines',
                  'design_system': 'Design System',
                  'competitor_analysis': 'Competitor Analysis',
                  'user_personas': 'User Personas',
                  'style_reference': 'Style Reference',
                  'color_palette': 'Color Palette',
                  'typography': 'Typography Rules',
                  'component_library': 'Component Library',
                  'constraints': 'Technical Constraints',
                }.entries.map((entry) {
                  return DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _contextType = value);
                  }
                },
              ),
              const SizedBox(height: SpacingTokens.md),
              TextField(
                controller: _contextController,
                decoration: const InputDecoration(
                  labelText: 'Context Name',
                  hintText: 'e.g., Brand Colors, Logo Guidelines',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_contextController.text.isNotEmpty) {
                  _addContext();
                  _contextController.clear();
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }



  Color _getContextColor(String type) {
    final colors = ThemeColors(context);
    final colorMap = {
      'brand_guidelines': colors.primary,
      'design_system': colors.accent,
      'competitor_analysis': colors.warning,
      'user_personas': colors.success,
      'style_reference': colors.primary,
      'color_palette': colors.accent,
      'typography': colors.onSurface,
      'component_library': colors.primary,
      'constraints': colors.error,
    };
    return colorMap[type] ?? colors.onSurfaceVariant;
  }


  // Tab Content
  Widget _buildTabContent(ThemeColors colors) {
    switch (_activeTab) {
      case 'chat':
        return _buildChatInterface(colors);
      case 'specs':
        return _buildSpecsPanel(colors);
      default:
        return _buildChatInterface(colors);
    }
  }

  // Specs Panel - Project specifications view
  Widget _buildSpecsPanel(ThemeColors colors) {
    // Always show the interactive specs creator interface
    return _buildSpecsCreator(colors);
  }

  Widget _buildSpecsViewer(ThemeColors colors) {
    final config = widget.agent.configuration ?? {};
    
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.md),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Project Specifications',
                  style: TextStyles.cardTitle.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 16),
                  onPressed: () {
                    // Switch to chat tab for editing
                    setState(() {
                      _activeTab = 'chat';
                    });
                  },
                  style: IconButton.styleFrom(
                    foregroundColor: colors.primary,
                    padding: const EdgeInsets.all(SpacingTokens.xs),
                  ),
                ),
              ],
            ),
            const SizedBox(height: SpacingTokens.lg),
            
            _buildSpecField(
              'Project Type',
              _projectType.replaceAll('_', ' ').toUpperCase(),
              Icons.category,
              colors,
            ),
            const SizedBox(height: SpacingTokens.md),
            
            _buildSpecField(
              'Design Phase',
              _designPhase.replaceAll('_', ' ').toUpperCase(),
              Icons.timeline,
              colors,
            ),
            const SizedBox(height: SpacingTokens.md),
            
            _buildSpecField(
              'Target Platforms',
              _selectedPlatforms.join(', '),
              Icons.devices,
              colors,
            ),
            const SizedBox(height: SpacingTokens.md),
            
            _buildSpecField(
              'Design Context',
              '${_contexts.length} items',
              Icons.folder,
              colors,
            ),
            
            if (_contexts.isNotEmpty) ...[
              const SizedBox(height: SpacingTokens.lg),
              Text(
                'Context Items',
                style: TextStyles.bodyMedium.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: SpacingTokens.sm),
              ...(_contexts.map((context) => _buildCompactContextItem(context, colors))),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSpecField(String label, String value, IconData icon, ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(SpacingTokens.sm),
            decoration: BoxDecoration(
              color: colors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
            ),
            child: Icon(
              icon,
              size: 18,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: SpacingTokens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyles.caption.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: SpacingTokens.xs),
                Text(
                  value,
                  style: TextStyles.bodySmall.copyWith(
                    color: colors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecsCreator(ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.md),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.assignment, color: colors.primary, size: 20),
                const SizedBox(width: SpacingTokens.sm),
                Text(
                  'Project Specifications',
                  style: TextStyles.cardTitle.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: SpacingTokens.sm),
            Text(
              'Define your project requirements and design goals',
              style: TextStyles.bodySmall.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: SpacingTokens.lg),
            
            // Project Type Section
            _buildSpecSection(
              'Project Type',
              Icons.category,
              colors,
              child: Column(
                children: [
                  _buildSpecOption('Web Application', 'web_app', colors),
                  _buildSpecOption('Mobile App', 'mobile_app', colors),
                  _buildSpecOption('Desktop App', 'desktop_app', colors),
                  _buildSpecOption('Dashboard', 'dashboard', colors),
                ],
              ),
            ),
            
            const SizedBox(height: SpacingTokens.lg),
            
            // Design Phase Section
            _buildSpecSection(
              'Design Phase',
              Icons.timeline,
              colors,
              child: Column(
                children: [
                  _buildSpecOption('Concept', 'concept', colors, isPhase: true),
                  _buildSpecOption('Wireframes', 'wireframes', colors, isPhase: true),
                  _buildSpecOption('High-Fidelity', 'high_fidelity', colors, isPhase: true),
                  _buildSpecOption('Prototype', 'prototype', colors, isPhase: true),
                ],
              ),
            ),
            
            const SizedBox(height: SpacingTokens.lg),
            
            // Target Platforms Section
            _buildSpecSection(
              'Target Platforms',
              Icons.devices,
              colors,
              child: Column(
                children: [
                  _buildPlatformCheckbox('Responsive Web', 'responsive_web', colors),
                  _buildPlatformCheckbox('iOS', 'ios', colors),
                  _buildPlatformCheckbox('Android', 'android', colors),
                  _buildPlatformCheckbox('Desktop', 'desktop', colors),
                ],
              ),
            ),
            
            const SizedBox(height: SpacingTokens.lg),
            
            // Requirements Section
            _buildSpecSection(
              'Key Requirements',
              Icons.list_alt,
              colors,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Enter main project requirements...',
                      hintStyle: TextStyle(color: colors.onSurfaceVariant),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: colors.primary, width: 2),
                      ),
                      contentPadding: const EdgeInsets.all(SpacingTokens.md),
                    ),
                    maxLines: 3,
                    style: TextStyles.bodyMedium.copyWith(color: colors.onSurface),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: SpacingTokens.lg),
            
            // Design Context Section
            _buildSpecSection(
              'Design Context',
              Icons.palette,
              colors,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _contextController,
                    decoration: InputDecoration(
                      hintText: 'Add context item (e.g., brand colors, style guide)...',
                      hintStyle: TextStyle(color: colors.onSurfaceVariant),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: colors.primary, width: 2),
                      ),
                      contentPadding: const EdgeInsets.all(SpacingTokens.md),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.add, color: colors.primary),
                        onPressed: _addContext,
                      ),
                    ),
                    style: TextStyles.bodyMedium.copyWith(color: colors.onSurface),
                    onSubmitted: (_) => _addContext(),
                  ),
                  const SizedBox(height: SpacingTokens.sm),
                  DropdownButtonFormField<String>(
                    initialValue: _contextType,
                    decoration: InputDecoration(
                      labelText: 'Context Type',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: SpacingTokens.md,
                        vertical: SpacingTokens.sm,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'brand_guidelines', child: Text('Brand Guidelines')),
                      DropdownMenuItem(value: 'existing_design', child: Text('Existing Design')),
                      DropdownMenuItem(value: 'inspiration', child: Text('Design Inspiration')),
                      DropdownMenuItem(value: 'style_guide', child: Text('Style Guide')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _contextType = value;
                        });
                      }
                    },
                  ),
                  if (_contexts.isNotEmpty) ...[
                    const SizedBox(height: SpacingTokens.md),
                    ...(_contexts.map((context) => _buildContextItem(context, colors))),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: SpacingTokens.xl),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: AsmblButton.secondary(
                    text: 'Clear All',
                    icon: Icons.clear,
                    onPressed: _clearSpecs,
                  ),
                ),
                const SizedBox(width: SpacingTokens.md),
                Expanded(
                  child: AsmblButton.primary(
                    text: 'Save Specs',
                    icon: Icons.save,
                    onPressed: _saveSpecs,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods for the spec-driven design interface
  Widget _buildSpecSection(String title, IconData icon, ThemeColors colors, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: colors.primary, size: 16),
              const SizedBox(width: SpacingTokens.sm),
              Text(
                title,
                style: TextStyles.bodyMedium.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.md),
          child,
        ],
      ),
    );
  }

  Widget _buildSpecOption(String label, String value, ThemeColors colors, {bool isPhase = false}) {
    final isSelected = isPhase ? _designPhase == value : _projectType == value;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isPhase) {
            _designPhase = value;
          } else {
            _projectType = value;
          }
        });
        _updateSpecifications();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.sm,
          vertical: SpacingTokens.xs,
        ),
        margin: const EdgeInsets.only(bottom: SpacingTokens.xs),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? colors.primary : colors.border.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 16,
              color: isSelected ? colors.primary : colors.onSurfaceVariant,
            ),
            const SizedBox(width: SpacingTokens.sm),
            Text(
              label,
              style: TextStyles.bodySmall.copyWith(
                color: isSelected ? colors.primary : colors.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformCheckbox(String label, String value, ThemeColors colors) {
    final isSelected = _selectedPlatforms.contains(value);
    
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedPlatforms.remove(value);
          } else {
            _selectedPlatforms.add(value);
          }
        });
        _updateSpecifications();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.sm,
          vertical: SpacingTokens.xs,
        ),
        margin: const EdgeInsets.only(bottom: SpacingTokens.xs),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? colors.primary : colors.border.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_box : Icons.check_box_outline_blank,
              size: 16,
              color: isSelected ? colors.primary : colors.onSurfaceVariant,
            ),
            const SizedBox(width: SpacingTokens.sm),
            Text(
              label,
              style: TextStyles.bodySmall.copyWith(
                color: isSelected ? colors.primary : colors.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContextItem(DesignContext context, ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.sm),
      margin: const EdgeInsets.only(bottom: SpacingTokens.xs),
      decoration: BoxDecoration(
        color: colors.background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.border.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            _getContextIcon(context.type),
            size: 16,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(width: SpacingTokens.sm),
          Expanded(
            child: Text(
              context.name,
              style: TextStyles.bodySmall.copyWith(
                color: colors.onSurface,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 14),
            onPressed: () {
              setState(() {
                _contexts.remove(context);
              });
              _updateSpecifications();
            },
            style: IconButton.styleFrom(
              foregroundColor: colors.onSurfaceVariant,
              padding: EdgeInsets.zero,
              minimumSize: const Size(20, 20),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getContextIcon(String type) {
    switch (type) {
      case 'brand_guidelines':
        return Icons.business;
      case 'existing_design':
        return Icons.design_services;
      case 'inspiration':
        return Icons.lightbulb;
      case 'style_guide':
        return Icons.color_lens;
      default:
        return Icons.folder;
    }
  }

  void _addContext() {
    if (_contextController.text.trim().isNotEmpty) {
      setState(() {
        _contexts.add(DesignContext(
          name: _contextController.text.trim(),
          type: _contextType,
        ));
        _contextController.clear();
      });
      _updateSpecifications();
    }
  }

  void _clearSpecs() {
    setState(() {
      _projectType = 'web_app';
      _designPhase = 'concept';
      _selectedPlatforms = ['responsive_web'];
      _contexts.clear();
    });
    _updateSpecifications();
  }

  void _saveSpecs() {
    _updateSpecifications();
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Specifications saved successfully'),
          ],
        ),
        backgroundColor: ThemeColors(context).success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _updateSpecifications() {
    final specs = {
      'projectType': _projectType,
      'designPhase': _designPhase,
      'platforms': _selectedPlatforms,
      'contexts': _contexts.map((c) => c.toMap()).toList(),
      'lastUpdated': DateTime.now().toIso8601String(),
    };
    
    widget.onSpecUpdate(specs);
  }
  
  /// Get human-readable model name from technical model ID
  String _getHumanReadableModelName(String? modelId) {
    if (modelId == null) return 'Unknown Model';
    
    // Post-modern model name mapping with capabilities
    if (modelId.contains('llama3.1')) {
      return 'Llama3.1 8B (🛠️ Tool Calling)';
    } else if (modelId.contains('deepseek-r1')) {
      if (modelId.contains('32b')) {
        return 'DeepSeek R1 32B (🧠 Reasoning)';
      } else {
        return 'DeepSeek R1 8B (💭 Planning)';
      }
    } else if (modelId.contains('llava')) {
      return 'LLaVA 13B (👁️ Vision)';
    } else if (modelId.contains('mistral')) {
      return 'Mistral Small 3.1 (⚡ Fast)';
    } else if (modelId.contains('gemma')) {
      return 'Gemma3 27B (🔬 Analytical)';
    } else {
      // Fallback - extract readable name from ID
      final cleanId = modelId.replaceAll('local_', '').replaceAll('_', ' ');
      return cleanId.split(' ').map((word) => 
        word.isNotEmpty ? word[0].toUpperCase() + word.substring(1).toLowerCase() : word
      ).join(' ');
    }
  }
  
  /// Add contextual canvas feedback to make chat feel dynamic (Motiff/Figma pattern)
  String _addContextualCanvasFeedback(String response, String userMessage) {
    // Keep it simple - only add feedback for specific successful actions
    if (response.contains('created') || response.contains('added')) {
      return '$response\n\n🎨 *Try variations: different colors, sizes, or positions*';
    }
    return response;
  }
}

/// Data model for chat messages
class ChatMessage {
  final String message;
  final bool isAgent;
  final DateTime timestamp;

  ChatMessage({
    required this.message,
    required this.isAgent,
    required this.timestamp,
  });
}

/// Model for design context items
class DesignContext {
  final String name;
  final String type;
  final String? path;
  final Map<String, dynamic>? metadata;
  
  DesignContext({
    required this.name,
    required this.type,
    this.path,
    this.metadata,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      if (path != null) 'path': path,
      if (metadata != null) 'metadata': metadata,
    };
  }
}

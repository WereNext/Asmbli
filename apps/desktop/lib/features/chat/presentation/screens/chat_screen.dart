import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:agent_engine_core/models/conversation.dart' as core;
import 'dart:async';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/constants/routes.dart';
import '../../../../providers/conversation_provider.dart';
import '../../../../providers/artifact_parser_provider.dart';
// import '../../../../core/services/mcp_bridge_service.dart'; // REMOVED: MCPBridgeService deleted
import '../../../../core/services/mcp_settings_service.dart';
import '../../../../core/services/llm/unified_llm_service.dart';
import '../../../../core/services/llm/llm_provider.dart';
import '../../../../core/services/model_config_service.dart';
import '../../../../core/models/model_config.dart';
import '../../../../core/services/agent_context_prompt_service.dart';
import '../../../../core/services/model_warmup_service.dart';
import '../../../../core/services/quick_chat_model_service.dart';
import '../../../../core/services/dspy/dspy.dart';
import '../widgets/improved_conversation_sidebar.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/agent_deployment_section.dart';
import '../widgets/streaming_message_widget.dart';
import '../widgets/editable_conversation_title.dart';
import '../widgets/context_sidebar_section.dart';
import '../widgets/contextual_context_widget.dart';
import '../widgets/mcp_chat_integration.dart';
import '../widgets/animated_context_toolbar.dart';
import '../widgets/chat_tab_bar.dart';
import '../widgets/chat_status_bar.dart';
import '../widgets/artifacts/artifact_workspace.dart';
import '../components/model_warmup_status_indicator.dart';
import '../../../../core/services/mcp_process_manager.dart';
import '../../../../core/models/mcp_server_process.dart' as mcp_models;

/// Chat screen that matches the screenshot with collapsible sidebar and MCP servers
class ChatScreen extends ConsumerStatefulWidget {
 final String? selectedTemplate;
  
  const ChatScreen({super.key, this.selectedTemplate});

 @override
 ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
 final TextEditingController messageController = TextEditingController();
 
 @override
 void initState() {
 super.initState();
 _initializeServices();
 }
 
 Future<void> _initializeServices() async {
 try {
 // Services are initialized via Riverpod providers
 // No manual ServiceProvider needed - services auto-initialize when accessed
 
 // Start model warm-up process in background (non-blocking)
 _startModelWarmUpInBackground();
 } catch (e) {
 AppLogger.error('Service initialization failed', component: 'Chat', error: e);
 }
 }

 Future<void> _startModelWarmUpInBackground() async {
 try {
   AppLogger.info('Starting model warm-up for chat screen', component: 'Chat');

   // OPTIMIZATION: Initialize and preload quick chat models FIRST for instant responses
   debugPrint('🚀 Initializing Quick Chat service for instant agentless responses...');
   final quickChatService = ref.read(quickChatModelServiceProvider);

   // Initialize quick chat service (identifies small, fast models)
   await quickChatService.initialize();

   // Preload quick chat models in highest priority (run first)
   unawaited(quickChatService.preloadQuickModels());

   // Then warm up all other models in background (lower priority)
   final warmUpService = ref.read(modelWarmUpServiceProvider);
   unawaited(warmUpService.warmUpAllModels());

   AppLogger.info('Model warm-up started in background', component: 'Chat');
 } catch (e) {
   AppLogger.error('Model warm-up failed', component: 'Chat', error: e);
 }
 }



 @override
 Widget build(BuildContext context) {
 final theme = Theme.of(context);
 final isDark = theme.brightness == Brightness.dark;
 
 return Scaffold(
 body: Stack(
 children: [
 Container(
  decoration: BoxDecoration(
 gradient: RadialGradient(
 center: Alignment.topCenter,
 radius: 1.5,
 colors: [
 ThemeColors(context).backgroundGradientStart,
 ThemeColors(context).backgroundGradientMiddle,
 ThemeColors(context).backgroundGradientEnd,
 ],
 stops: const [0.0, 0.6, 1.0],
 ),
 ),
 child: SafeArea(
 child: Column(
 children: [
 // Header
 const AppNavigationBar(currentRoute: AppRoutes.chat),

 // Firefox-style Tab Bar
 ChatTabBar(
   onNewChat: () => _startNewDirectChat(),
 ),

 // Status Bar (slim, fixed, replaces floating dock)
 ChatStatusBar(
   conversationId: ref.watch(selectedConversationIdProvider),
 ),

 // Main Content - Full width chat area
 Expanded(
 child: _buildChatArea(context),
 ),
 ],
 ),
 ),
 ),

 // Model warm-up notification (removed blocking overlay)
 ],
 ),
 );
 }

 Widget _buildChatHeader(ThemeData theme) {
 final selectedConversationId = ref.watch(selectedConversationIdProvider);
 
 if (selectedConversationId == null) {
 // No conversation selected - show default
 return Container(
 padding: const EdgeInsets.all(SpacingTokens.elementSpacing),
 child: Row(
 children: [
 Text(
 'Let\'s Talk',
 style: GoogleFonts.fustat(
  fontWeight: FontWeight.w600,
 color: theme.colorScheme.onSurface,
 ),
 ),
 const Spacer(),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: theme.colorScheme.surfaceContainerHighest,
 borderRadius: BorderRadius.circular(12),
 ),
 child: Text(
 'Select a conversation',
 style: GoogleFonts.fustat(
  color: theme.colorScheme.onSurfaceVariant,
 ),
 ),
 ),
 ],
 ),
 );
 }

 return ref.watch(conversationProvider(selectedConversationId)).when(
 data: (conversation) {
 final isAgent = conversation.metadata?['type'] == 'agent';
 final isDefaultApi = conversation.metadata?['type'] == 'default_api';
 
 return Container(
 padding: const EdgeInsets.all(SpacingTokens.elementSpacing),
 child: Row(
 children: [
 // Conversation type icon
 Container(
 padding: const EdgeInsets.all(6),
 decoration: BoxDecoration(
 color: _getConversationTypeColor(conversation, theme).withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Icon(
 _getConversationTypeIcon(conversation),
 size: 18,
 color: _getConversationTypeColor(conversation, theme),
 ),
 ),
 const SizedBox(width: 12),
 
 // Conversation title and info
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 EditableConversationTitle(
 conversation: conversation,
 style: GoogleFonts.fustat(
  fontWeight: FontWeight.w600,
 color: theme.colorScheme.onSurface,
 ),
 ),
 if (isAgent) ...[
 const SizedBox(height: 2),
 Row(
 children: [
 Text(
 conversation.metadata?['agentName'] ?? 'Agent',
 style: GoogleFonts.fustat(
  color: theme.colorScheme.onSurfaceVariant,
 fontStyle: FontStyle.italic,
 ),
 ),
 const SizedBox(width: 8),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
 decoration: BoxDecoration(
 color: theme.colorScheme.surfaceContainerHighest,
 borderRadius: BorderRadius.circular(4),
 ),
 child: Text(
 '${(conversation.metadata?['mcpServers'] as List?)?.length ?? 0} MCP',
 style: GoogleFonts.fustat(
  color: theme.colorScheme.onSurfaceVariant,
 fontWeight: FontWeight.w500,
 ),
 ),
 ),
 ],
 ),
 ],
 ],
 ),
 ),
 
 // API Provider badge
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: _getConversationTypeColor(conversation, theme).withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(
 color: _getConversationTypeColor(conversation, theme).withValues(alpha: 0.3),
 ),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(
 _getConversationIcon(conversation),
 size: 12,
 color: _getConversationTypeColor(conversation, theme),
 ),
 const SizedBox(width: 4),
 Text(
 _getConversationBadgeText(conversation),
 style: GoogleFonts.fustat(
  fontWeight: FontWeight.w500,
 color: _getConversationTypeColor(conversation, theme),
 ),
 ),
 ],
 ),
 ),
 
 // Agent status indicator for agent conversations
 if (isAgent) ...[
 const SizedBox(width: 8),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
 decoration: BoxDecoration(
 color: ThemeColors(context).success.withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(8),
 border: Border.all(
 color: ThemeColors(context).success.withValues(alpha: 0.3),
 ),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Container(
 width: 6,
 height: 6,
 decoration: BoxDecoration(
 color: ThemeColors(context).success,
 shape: BoxShape.circle,
 ),
 ),
 const SizedBox(width: 4),
 Text(
 'ACTIVE',
 style: GoogleFonts.fustat(
  fontWeight: FontWeight.w600,
 color: ThemeColors(context).success,
 ),
 ),
 ],
 ),
 ),
 ],

 // Priming status indicator for all conversations
 const SizedBox(width: 8),
 _buildPrimingStatusIndicator(context, conversation),
 ],
 ),
 );
 },
 loading: () => Container(
 padding: const EdgeInsets.all(SpacingTokens.elementSpacing),
 child: Row(
 children: [
 SizedBox(
 width: 16,
 height: 16,
 child: CircularProgressIndicator(
 strokeWidth: 2,
 valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
 ),
 ),
 const SizedBox(width: 12),
 Text(
 'Loading conversation...',
 style: GoogleFonts.fustat(
  color: theme.colorScheme.onSurfaceVariant,
 ),
 ),
 ],
 ),
 ),
 error: (error, stack) => Container(
 padding: const EdgeInsets.all(SpacingTokens.elementSpacing),
 child: Text(
 'Error loading conversation',
 style: GoogleFonts.fustat(
  color: theme.colorScheme.error,
 ),
 ),
 ),
 );
 }


 /// Build Model Selector for sidebar - no default model references
 Widget _buildModelSelector(BuildContext context) {
   final theme = Theme.of(context);
   final modelConfigService = ref.watch(modelConfigServiceProvider);
   final selectedConversationId = ref.watch(selectedConversationIdProvider);
   
   // Use conversation-specific model or fallback to global
   final selectedModel = selectedConversationId != null
       ? ref.watch(conversationModelProvider(selectedConversationId))
       : ref.watch(selectedModelProvider);
   
   // Get all configured models (both local and API)
   final configuredModels = modelConfigService.allModelConfigs.values
       .where((model) => model.isConfigured)
       .toList();
       
   return Padding(
     padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.elementSpacing),
     child: Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         // Section Header
         Padding(
           padding: const EdgeInsets.only(left: 4, bottom: 8),
           child: Text(
             selectedModel?.isLocal == true ? 'Local Model' : 'Cloud Model',
             style: GoogleFonts.fustat(
                             fontWeight: FontWeight.w500,
               color: theme.colorScheme.onSurfaceVariant,
             ),
           ),
         ),
         
         // Model Selection Card
         AsmblCard(
           child: Container(
             width: double.infinity,
             padding: const EdgeInsets.all(SpacingTokens.md),
             child: configuredModels.isEmpty
                 ? _buildNoModelsState(context)
                 : _buildModelDropdown(context, configuredModels, selectedModel),
           ),
         ),
       ],
     ),
   );
 }
 
 /// Build no models configured state
 Widget _buildNoModelsState(BuildContext context) {
   final theme = Theme.of(context);
   return Column(
     children: [
       Icon(
         Icons.model_training_outlined,
         size: 32,
         color: theme.colorScheme.onSurfaceVariant,
       ),
       const SizedBox(height: SpacingTokens.sm),
       Text(
         'No Models Configured',
         style: TextStyles.bodyMedium.copyWith(
           color: theme.colorScheme.onSurface,
           fontWeight: FontWeight.w500,
         ),
       ),
       const SizedBox(height: SpacingTokens.xs),
       Text(
         'Add AI models in Settings',
         style: TextStyles.bodySmall.copyWith(
           color: theme.colorScheme.onSurfaceVariant,
         ),
         textAlign: TextAlign.center,
       ),
     ],
   );
 }
 
 /// Build model dropdown
 Widget _buildModelDropdown(BuildContext context, List<ModelConfig> models, ModelConfig? selectedModel) {
   final theme = Theme.of(context);
   
   return Column(
     crossAxisAlignment: CrossAxisAlignment.start,
     children: [
       // Current Selection Display
       if (false && selectedModel != null) ...[
         Row(
           children: [
             Icon(
               selectedModel.isLocal ? Icons.computer : Icons.cloud,
               size: 16,
               color: selectedModel.isLocal
                   ? ThemeColors(context).accent
                   : ThemeColors(context).primary,
             ),
             const SizedBox(width: SpacingTokens.xs),
             Expanded(
               child: Text(
                 selectedModel.name,
                 style: TextStyles.bodyMedium.copyWith(
                   color: theme.colorScheme.onSurface,
                   fontWeight: FontWeight.w500,
                 ),
               ),
             ),
             if (selectedModel.isLocal)
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                 decoration: BoxDecoration(
                   color: ThemeColors(context).accent.withValues(alpha: 0.1),
                   borderRadius: BorderRadius.circular(4),
                 ),
                 child: Text(
                   'LOCAL',
                   style: TextStyle(
                                         fontWeight: FontWeight.w600,
                     color: ThemeColors(context).accent,
                   ),
                 ),
               ),
           ],
         ),
         const SizedBox(height: SpacingTokens.sm),
       ] else if (false) ...[
         Text(
           'Select a model to chat',
           style: TextStyles.bodyMedium.copyWith(
             color: theme.colorScheme.onSurfaceVariant,
           ),
         ),
         const SizedBox(height: SpacingTokens.sm),
       ],
       
       // Dropdown
       DropdownButtonFormField<String>(
         value: selectedModel?.id,
         decoration: InputDecoration(
           contentPadding: const EdgeInsets.symmetric(
             horizontal: SpacingTokens.sm,
             vertical: SpacingTokens.sm, // Increased from xs to sm for better text space
           ),
           border: OutlineInputBorder(
             borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
             borderSide: BorderSide(color: theme.colorScheme.outline),
           ),
           focusedBorder: OutlineInputBorder(
             borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
             borderSide: BorderSide(color: ThemeColors(context).primary),
           ),
         ),
         selectedItemBuilder: (context) {
           return models.map<Widget>((model) {
             return Container(
               alignment: Alignment.centerLeft,
               constraints: const BoxConstraints(minHeight: 40),
               child: Text(
                 model.name,
                 style: TextStyles.bodyMedium.copyWith(
                   color: theme.colorScheme.onSurface,
                   fontWeight: FontWeight.w500,
                 ),
                 maxLines: 1,
                 overflow: TextOverflow.ellipsis,
               ),
             );
           }).toList();
         },
         hint: Text(
           'Choose model...',
           style: TextStyles.bodyMedium.copyWith(
             color: theme.colorScheme.onSurfaceVariant,
           ),
         ),
         isExpanded: true,
         items: models.map((model) => DropdownMenuItem<String>(
           value: model.id,
           child: Container(
             height: 56, // Increased height to prevent cramping
             child: Row(
               children: [
                 Icon(
                   model.isLocal ? Icons.computer : Icons.cloud,
                   size: 16, // Slightly larger icon
                   color: model.isLocal
                       ? ThemeColors(context).accent
                       : ThemeColors(context).primary,
                 ),
                 const SizedBox(width: SpacingTokens.sm), // Increased spacing
                 Expanded(
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       Text(
                         model.name,
                         style: TextStyles.bodyMedium.copyWith(
                           color: theme.colorScheme.onSurface,
                           fontWeight: FontWeight.w500,
                         ),
                         maxLines: 1,
                         overflow: TextOverflow.ellipsis,
                       ),
                       if (model.provider.isNotEmpty && !model.isLocal)
                         Text(
                           model.provider,
                           style: TextStyles.bodySmall.copyWith(
                             color: theme.colorScheme.onSurfaceVariant,
                             fontSize: 11,
                           ),
                         ),
                     ],
                   ),
                 ),
                 
                 const SizedBox(width: SpacingTokens.sm), // More space before badges
                 
                 // Status indicators row
                 Row(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     // Warm-up status indicator
                     Consumer(
                       builder: (context, ref, _) {
                         final isReady = ref.watch(isModelReadyProvider(model.id));
                         return Container(
                           width: 8,
                           height: 8,
                           decoration: BoxDecoration(
                             color: isReady 
                               ? ThemeColors(context).success
                               : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                             shape: BoxShape.circle,
                           ),
                         );
                       },
                     ),
                     if (model.isLocal) ...[
                       const SizedBox(width: SpacingTokens.sm),
                       Container(
                         padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                         decoration: BoxDecoration(
                           color: ThemeColors(context).accent.withValues(alpha: 0.15),
                           borderRadius: BorderRadius.circular(8),
                         ),
                         child: Text(
                           'LOCAL',
                           style: TextStyle(
                             fontSize: 9,
                             fontWeight: FontWeight.w600,
                             color: ThemeColors(context).accent,
                           ),
                         ),
                       ),
                     ] else if (model.provider.isNotEmpty) ...[
                       const SizedBox(width: SpacingTokens.sm),
                       Container(
                         padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                         decoration: BoxDecoration(
                           color: ThemeColors(context).primary.withValues(alpha: 0.15),
                           borderRadius: BorderRadius.circular(8),
                         ),
                         child: Text(
                           model.provider.toUpperCase(),
                           style: TextStyle(
                             fontSize: 9,
                             fontWeight: FontWeight.w600,
                             color: ThemeColors(context).primary,
                           ),
                         ),
                       ),
                     ],
                   ],
                 ),
               ],
             ),
           ),
         )).toList(),
         onChanged: (String? modelId) {
           final currentConversationId = ref.read(selectedConversationIdProvider);
           if (modelId != null && currentConversationId != null) {
             final service = ref.read(modelConfigServiceProvider);
             final model = service.allModelConfigs[modelId];
             if (model != null) {
               // Set model for specific conversation
               final setConversationModel = ref.read(setConversationModelProvider);
               setConversationModel(currentConversationId, model);
             }
           }
         },
       ),
     ],
   );
 }

 Color _getConversationTypeColor(core.Conversation conversation, ThemeData theme) {
 final metadata = conversation.metadata;
 final type = metadata?['type'] as String?;
 final modelType = metadata?['modelType'] as String?;
 
 switch (type) {
 case 'agent':
 return ThemeColors(context).primary;
 case 'default_api':
 case 'direct_chat':
   // Use different colors for local vs API models
   if (modelType == 'local') {
     return ThemeColors(context).accent; // Use accent color for local models
   } else {
     return theme.colorScheme.onSurfaceVariant; // API models
   }
 default:
 return theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7);
 }
 }

 IconData _getConversationTypeIcon(core.Conversation conversation) {
 final type = conversation.metadata?['type'] as String?;
 final selectedModel = ref.read(conversationModelProvider(conversation.id)) 
     ?? ref.read(selectedModelProvider);
 
 switch (type) {
 case 'agent':
 return Icons.smart_toy;
 case 'default_api':
 case 'direct_chat':
 // Show appropriate icon based on current selected model
 if (selectedModel?.isLocal == true) {
 return Icons.computer; // Local model icon
 } else {
 return Icons.cloud; // Cloud/API model icon
 }
 default:
 return Icons.chat;
 }
 }

 /// Get appropriate icon for conversation badge based on model type
 IconData _getConversationIcon(core.Conversation conversation) {
 final metadata = conversation.metadata;
 final modelType = metadata?['modelType'] as String?;
 final type = metadata?['type'] as String?;
 
 if (type == 'agent') {
   return Icons.smart_toy;
 }
 
 if (modelType == 'local') {
   return Icons.storage; // Local storage icon for local models
 } else if (modelType == 'api') {
   return Icons.cloud; // Cloud icon for API models
 }
 
 // Fallback: check the conversation-specific selected model
 final conversationModel = ref.read(conversationModelProvider(conversation.id));
 if (conversationModel?.isLocal == true) {
   return Icons.storage; // Local storage icon for local models
 }
 
 return Icons.cloud; // Default to cloud icon
 }

 /// Get contextual text for conversation badge
 String _getConversationBadgeText(core.Conversation conversation) {
 final metadata = conversation.metadata;
 final type = metadata?['type'] as String?;
 
 if (type == 'agent') {
   return 'Agent';
 }
 
 // Use the conversation's stored model type for consistency with icon logic
 final modelType = metadata?['modelType'] as String?;
 if (modelType == 'local') {
   return 'Local';
 } else if (modelType == 'api') {
   return 'Cloud';
 }
 
 // Fallback: check the conversation-specific selected model
 final conversationModel = ref.read(conversationModelProvider(conversation.id));
 if (conversationModel?.isLocal == true) {
   return 'Local';
 }
 
 return 'Cloud';
 }

 // Sidebar removed for minimal chat UI - keeping method for future gradual restoration
 Widget _buildSidebar(BuildContext context) {
 final theme = Theme.of(context);
 return Container(
 decoration: BoxDecoration(
 color: theme.colorScheme.surface.withValues(alpha: 0.7),
 border: Border(right: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3))),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Sidebar Header (fixed)
 Padding(
 padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.elementSpacing),
 child: Row(
 children: [
 Flexible(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 '🤖 Your AI Assistant',
 style: GoogleFonts.fustat(
  fontWeight: FontWeight.w600,
 color: theme.colorScheme.onSurface,
 ),
 overflow: TextOverflow.visible,
 softWrap: true,
 ),
 Text(
 'See what your assistant knows & can help with',
 style: GoogleFonts.fustat(
  color: theme.colorScheme.onSurfaceVariant,
  fontSize: 12,
 ),
 overflow: TextOverflow.visible,
 softWrap: true,
 ),
 ],
 ),
 ),
 const SizedBox(width: SpacingTokens.componentSpacing),
 // Collapse button removed - sidebars not used in minimal UI
 IconButton(
 onPressed: () {}, // No-op
 icon: const Icon(Icons.chevron_left, size: 20),
 style: IconButton.styleFrom(
 foregroundColor: theme.colorScheme.onSurfaceVariant,
 ),
 ),
 ],
 ),
 ),
 
 // Scrollable content
 Expanded(
 child: SingleChildScrollView(
 padding: const EdgeInsets.only(bottom: SpacingTokens.elementSpacing),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Active Agent Context
 _buildActiveAgentContext(context),
 
 const SizedBox(height: SpacingTokens.sectionSpacing),
 
 // Model Selection Section - Right below AI Assistant
 _buildModelSelector(context),
 
 const SizedBox(height: SpacingTokens.sectionSpacing),
 
 // Agent Loader Section - Wrapped in Flexible to prevent overflow
 const AgentLoaderSection(),
                  
                  const SizedBox(height: SpacingTokens.elementSpacing),

                  // Context Documents Section - Works for both Agent and Direct API conversations
                  const ContextSidebarSection(),
 
 const SizedBox(height: SpacingTokens.sectionSpacing),
 
 // Agent Tools & MCP Status (Only shown for agent conversations)
 _buildAgentToolsContext(context),
 
 ],
 ),
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildChatArea(BuildContext context) {
 final theme = Theme.of(context);
 return Container(
 decoration: const BoxDecoration(
 color: Colors.transparent,
 ),
 child: Column(
 children: [
 // Note: Chat header removed - info now in tab bar and status bar

 // MCP Contextual Recommendations (minimal)
 _buildMCPRecommendations(context),

 // Messages Area or Empty State with Artifact Workspace Overlay
 Expanded(
 child: Stack(
 children: [
 _buildMessagesArea(context),
 // Artifact workspace overlay for OS-like windows
 const ArtifactWorkspace(),
 ],
 ),
 ),
 
 // Input Area
 Container(
 padding: const EdgeInsets.all(SpacingTokens.elementSpacing),
 child: Row(
 children: [
 Expanded(
 child: Container(
 decoration: BoxDecoration(
 color: theme.colorScheme.surface.withValues(alpha: 0.8),
 borderRadius: BorderRadius.circular(8),
 border: Border.all(color: theme.colorScheme.outline),
 ),
 child: KeyboardListener(
 focusNode: FocusNode(),
 onKeyEvent: (KeyEvent event) {
 if (event is KeyDownEvent) {
 final isEnterPressed = event.logicalKey == LogicalKeyboardKey.enter;
 final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
 
 if (isEnterPressed && isShiftPressed) {
 // Shift+Enter: send message
 _sendMessage();
 return;
 }
 // Enter alone: let TextField handle naturally for new line
 }
 },
 child: TextField(
 controller: messageController,
 decoration: InputDecoration(
 hintText: 'Type your message... (Shift+Enter to send, Enter for new line)',
 hintStyle: GoogleFonts.fustat(
  color: theme.colorScheme.onSurfaceVariant,
 ),
 border: InputBorder.none,
 contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
 ),
 style: GoogleFonts.fustat(
  color: theme.colorScheme.onSurface,
 ),
 maxLines: 5,
 minLines: 1,
 keyboardType: TextInputType.multiline,
 textInputAction: TextInputAction.newline,
 onChanged: (value) => setState(() {}), // Trigger rebuild for send button state
 ),
 ),
 ),
 ),
 const SizedBox(width: SpacingTokens.componentSpacing),
 Container(
 decoration: BoxDecoration(
 color: messageController.text.trim().isNotEmpty && !ref.watch(isLoadingProvider)
 ? ThemeColors(context).primary
 : theme.colorScheme.surface,
 borderRadius: BorderRadius.circular(8),
 border: Border.all(
 color: messageController.text.trim().isNotEmpty && !ref.watch(isLoadingProvider)
 ? ThemeColors(context).primary
 : theme.colorScheme.outline,
 ),
 ),
 child: IconButton(
 onPressed: messageController.text.trim().isNotEmpty && !ref.watch(isLoadingProvider)
 ? _sendMessage
 : null,
 icon: ref.watch(isLoadingProvider) 
 ? const SizedBox(
 width: 16,
 height: 16,
 child: CircularProgressIndicator(
 strokeWidth: 2,
 valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
 ),
 )
 : const Icon(Icons.send, size: 18),
 style: IconButton.styleFrom(
 foregroundColor: messageController.text.trim().isNotEmpty && !ref.watch(isLoadingProvider)
? Colors.white
: theme.colorScheme.onSurfaceVariant,
 padding: const EdgeInsets.all(12),
 ),
 ),
 ),
 ],
 ),
 ),

 // Note: Floating toolbar removed - replaced by fixed ChatTabBar + ChatStatusBar above
 ],
 ),
 );
 }

 Widget _buildEmptyState(BuildContext context) {
 final theme = Theme.of(context);
 return Center(
 child: Container(
 constraints: const BoxConstraints(maxWidth: 400),
 child: Column(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 // Robot icon
 Container(
 width: 64,
 height: 64,
 decoration: BoxDecoration(
 color: theme.colorScheme.surfaceContainerHighest,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: theme.colorScheme.outline),
 ),
 child: Icon(
 Icons.smart_toy_outlined,
 size: 32,
 color: theme.colorScheme.onSurfaceVariant,
 ),
 ),
 
 const SizedBox(height: SpacingTokens.textSectionSpacing),
 
 // Start a Conversation
 Text(
 'LLM Chat',
 style: GoogleFonts.fustat(
  fontWeight: FontWeight.w600,
 color: theme.colorScheme.onSurface,
 ),
 ),
 
 const SizedBox(height: SpacingTokens.componentSpacing),
 
 // Description
 Text(
 'Chat with AI using any of your configured models.\nAdd context documents for better help, or load an agent\nfrom the sidebar for enhanced capabilities.',
 style: GoogleFonts.fustat(
  color: theme.colorScheme.onSurfaceVariant,
 height: 1.5,
 ),
 textAlign: TextAlign.center,
 ),

 const SizedBox(height: SpacingTokens.sectionSpacing),

 // Start New Chat Button
 AsmblButton.primary(
   text: 'Start New Chat',
   icon: Icons.chat_bubble_outline,
   onPressed: () async {
     await _startNewDirectChat();
   },
 ),
 ],
 ),
 ),
 );
 }

 Widget _buildMessagesArea(BuildContext context) {
 final selectedConversationId = ref.watch(selectedConversationIdProvider);
 
 if (selectedConversationId == null) {
 return _buildEmptyState(context);
 }
 
 return _buildMessagesList(context, selectedConversationId);
 }
 
 Widget _buildMessagesList(BuildContext context, String conversationId) {
 final messagesAsync = ref.watch(messagesProvider(conversationId));

 // Activate artifact parser listener for this conversation
 ref.watch(artifactParseListenerProvider(conversationId));

 return messagesAsync.when(
 data: (messages) {
 if (messages.isEmpty) {
 return _buildEmptyConversationState(context);
 }
 
 final theme = Theme.of(context);
 final colorScheme = theme.colorScheme;
 
 return ListView.builder(
 padding: const EdgeInsets.all(16),
 itemCount: messages.length + (ref.watch(isLoadingProvider) ? 1 : 0),
 itemBuilder: (context, index) {
 // Show streaming message widget as last item when loading
 if (index == messages.length && ref.watch(isLoadingProvider)) {
 // Check if we're in an agent conversation to show streaming response
 final conversation = ref.watch(conversationProvider(conversationId)).value;
 final isAgentConversation = conversation?.metadata?['type'] == 'agent';
 
 if (isAgentConversation) {
 return Container(
 margin: const EdgeInsets.symmetric(vertical: 8),
 child: StreamingMessageWidget(
 messageId: _getActiveStreamingMessageId(ref, conversationId),
 role: 'assistant',
 ),
 );
 } else {
 return const MessageLoadingIndicator();
 }
 }
 
 final message = messages[index];
 final isUser = message.role == core.MessageRole.user;
 final hasStreamingData = message.metadata?.containsKey('streaming') == true ||
 message.metadata?.containsKey('mcpInteractions') == true ||
 message.metadata?.containsKey('toolResults') == true;

 // Use streaming widget for assistant messages with MCP data
 if (!isUser && hasStreamingData) {
 return Container(
 margin: const EdgeInsets.symmetric(vertical: 8),
 child: StreamingMessageWidget(
 messageId: message.id,
 role: 'assistant',
 ),
 );
 }

 // Standard message display for simple messages
 return Container(
 margin: const EdgeInsets.symmetric(vertical: 8),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 if (!isUser) ...[
 CircleAvatar(
 radius: 16,
 backgroundColor: colorScheme.primary,
 child: Icon(
 Icons.smart_toy,
 size: 20,
 color: colorScheme.onPrimary,
 ),
 ),
 const SizedBox(width: SpacingTokens.componentSpacing),
 ],
 Expanded(
 child: Container(
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: isUser ? colorScheme.primary : colorScheme.surface,
 borderRadius: BorderRadius.circular(8),
 border: !isUser ? Border.all(
 color: colorScheme.outline.withValues(alpha: 0.3),
 ) : null,
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 message.content,
 style: theme.textTheme.bodyMedium?.copyWith(
 color: isUser ? colorScheme.onPrimary : colorScheme.onSurface,
  ),
 ),
 const SizedBox(height: 4),
 Text(
 _formatTime(message.timestamp),
 style: theme.textTheme.bodySmall?.copyWith(
 color: (isUser ? colorScheme.onPrimary : colorScheme.onSurface).withValues(alpha: 0.7),
  ),
 ),
 ],
 ),
 ),
 ),
 if (isUser) ...[
 const SizedBox(width: SpacingTokens.componentSpacing),
 CircleAvatar(
 radius: 16,
 backgroundColor: colorScheme.surface,
 child: Icon(
 Icons.person,
 size: 20,
 color: colorScheme.onSurface,
 ),
 ),
 ],
 ],
 ),
 );
 },
 );
 },
 loading: () => Center(
 child: CircularProgressIndicator(color: ThemeColors(context).primary),
 ),
 error: (error, stack) => Center(
 child: ErrorMessage(
 message: 'Failed to load messages: ${error.toString()}',
 onRetry: () {
 ref.invalidate(messagesProvider(conversationId));
 },
 ),
 ),
 );
 }

 Widget _buildActiveAgentContext(BuildContext context) {
   final selectedConversationId = ref.watch(selectedConversationIdProvider);
   final theme = Theme.of(context);
   
   if (selectedConversationId == null) {
     return _buildNoActiveAgentCard(theme);
   }
   
   final conversationAsync = ref.watch(conversationProvider(selectedConversationId));
   
   return conversationAsync.when(
     data: (conversation) => _buildAgentContextCard(conversation, theme),
     loading: () => _buildLoadingAgentCard(theme),
     error: (_, __) => _buildErrorAgentCard(theme),
   );
 }

 Widget _buildAgentToolsContext(BuildContext context) {
   final selectedConversationId = ref.watch(selectedConversationIdProvider);
   final theme = Theme.of(context);
   
   if (selectedConversationId == null) {
     return Container();
   }
   
   final conversationAsync = ref.watch(conversationProvider(selectedConversationId));
   
   return conversationAsync.when(
     data: (conversation) => _buildToolsContextCard(conversation, theme),
     loading: () => Container(),
     error: (_, __) => Container(),
   );
 }

 Widget _buildAgentContextCard(core.Conversation conversation, ThemeData theme) {
   final agentName = _getDisplayName(conversation);
   final agentType = conversation.metadata?['type'] ?? 'default_api';
   final mcpServers = conversation.metadata?['mcpServers'] as List<dynamic>? ?? [];
   final contextDocs = conversation.metadata?['contextDocuments'] as List<dynamic>? ?? [];
   
   return Padding(
     padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.elementSpacing),
     child: Container(
       padding: const EdgeInsets.all(SpacingTokens.cardPadding),
       decoration: BoxDecoration(
         color: agentType == 'agent' 
           ? theme.colorScheme.primary.withValues(alpha: 0.08)
           : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.05),
         borderRadius: BorderRadius.circular(12),
         border: Border.all(
           color: agentType == 'agent' 
             ? theme.colorScheme.primary.withValues(alpha: 0.2)
             : theme.colorScheme.outline.withValues(alpha: 0.2),
         ),
       ),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           // Agent header
           Row(
             children: [
               Container(
                 padding: const EdgeInsets.all(8),
                 decoration: BoxDecoration(
                   color: agentType == 'agent'
                     ? theme.colorScheme.primary.withValues(alpha: 0.1)
                     : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
                   borderRadius: BorderRadius.circular(8),
                 ),
                 child: Icon(
                   agentType == 'agent' ? Icons.psychology : Icons.chat,
                   size: 16,
                   color: agentType == 'agent'
                     ? theme.colorScheme.primary
                     : theme.colorScheme.onSurfaceVariant,
                 ),
               ),
               const SizedBox(width: SpacingTokens.componentSpacing),
               Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(
                       agentName,
                       style: GoogleFonts.fustat(
                                                                          fontWeight: FontWeight.w600,
                         color: theme.colorScheme.onSurface,
                       ),
                     ),
                     Text(
                       _getConversationDescription(conversation),
                       style: GoogleFonts.fustat(
                                                                          color: theme.colorScheme.onSurfaceVariant,
                       ),
                     ),
                   ],
                 ),
               ),
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                 decoration: BoxDecoration(
                   color: agentType == 'agent' ? Colors.green : Colors.orange,
                   borderRadius: BorderRadius.circular(4),
                 ),
                 child: Text(
                   agentType == 'agent' ? 'LIVE' : 'BASIC',
                   style: GoogleFonts.fustat(
                                                              fontWeight: FontWeight.w600,
                     color: Colors.white,
                   ),
                 ),
               ),
             ],
           ),
           
           // Agent capabilities summary
           const SizedBox(height: SpacingTokens.componentSpacing),
           Row(
             children: [
               _buildCapabilityChip(
                 '${mcpServers.length} Tools',
                 Icons.extension,
                 mcpServers.isNotEmpty ? Colors.green : theme.colorScheme.onSurfaceVariant,
                 theme,
               ),
               const SizedBox(width: SpacingTokens.componentSpacing),
               _buildCapabilityChip(
                 '${contextDocs.length} Docs',
                 Icons.description,
                 contextDocs.isNotEmpty ? Colors.blue : theme.colorScheme.onSurfaceVariant,
                 theme,
               ),
             ],
           ),
         ],
       ),
     ),
   );
 }

 Widget _buildToolsContextCard(core.Conversation conversation, ThemeData theme) {
   final mcpServers = conversation.metadata?['mcpServers'] as List<dynamic>? ?? [];
   final mcpConfigs = conversation.metadata?['mcpServerConfigs'] as Map<String, dynamic>? ?? {};
   final contextDocs = conversation.metadata?['contextDocuments'] as List<dynamic>? ?? [];
   
   if (mcpServers.isEmpty && contextDocs.isEmpty) {
     return Container();
   }
   
   return Padding(
     padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.elementSpacing),
     child: Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         // Section header
         Text(
           'Agent Resources',
           style: GoogleFonts.fustat(
                                      fontWeight: FontWeight.w600,
             color: theme.colorScheme.onSurface,
           ),
         ),
         const SizedBox(height: SpacingTokens.componentSpacing),
         
         // MCP Tools
         if (mcpServers.isNotEmpty) ...[
           _buildSectionTitle('Active Tools (${mcpServers.length})', Icons.extension, theme),
           const SizedBox(height: SpacingTokens.iconSpacing),
           ...mcpServers.take(4).map((serverId) {
             final config = mcpConfigs[serverId] as Map<String, dynamic>?;
             final status = config?['status'] ?? 'connected';
             return _buildToolItem(serverId.toString(), status, theme);
           }),
           if (mcpServers.length > 4)
             Text(
               '+ ${mcpServers.length - 4} more tools',
               style: GoogleFonts.fustat(
                                                  color: theme.colorScheme.onSurfaceVariant,
                 fontStyle: FontStyle.italic,
               ),
             ),
           const SizedBox(height: SpacingTokens.componentSpacing),
         ],
         
         // Context Documents
         if (contextDocs.isNotEmpty) ...[
           _buildSectionTitle('Context Documents (${contextDocs.length})', Icons.description, theme),
           const SizedBox(height: SpacingTokens.iconSpacing),
           ...contextDocs.take(3).map((doc) => _buildContextDocItem(doc.toString(), theme)),
           if (contextDocs.length > 3)
             Text(
               '+ ${contextDocs.length - 3} more documents',
               style: GoogleFonts.fustat(
                                                  color: theme.colorScheme.onSurfaceVariant,
                 fontStyle: FontStyle.italic,
               ),
             ),
         ],
       ],
     ),
   );
 }

 Widget _buildCapabilityChip(String text, IconData icon, Color color, ThemeData theme) {
   return Container(
     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
     decoration: BoxDecoration(
       color: color.withValues(alpha: 0.1),
       borderRadius: BorderRadius.circular(12),
     ),
     child: Row(
       mainAxisSize: MainAxisSize.min,
       children: [
         Icon(icon, size: 12, color: color),
         const SizedBox(width: 4),
         Text(
           text,
           style: GoogleFonts.fustat(
                                      fontWeight: FontWeight.w500,
             color: color,
           ),
         ),
       ],
     ),
   );
 }

 Widget _buildSectionTitle(String title, IconData icon, ThemeData theme) {
   return Row(
     children: [
       Icon(icon, size: 14, color: theme.colorScheme.primary),
       const SizedBox(width: 6),
       Text(
         title,
         style: GoogleFonts.fustat(
                                fontWeight: FontWeight.w500,
           color: theme.colorScheme.onSurface,
         ),
       ),
     ],
   );
 }

 Widget _buildToolItem(String serverId, String status, ThemeData theme) {
   final statusColor = status == 'connected' ? Colors.green : 
                      status == 'error' ? Colors.red : Colors.orange;
   
   return Padding(
     padding: const EdgeInsets.only(bottom: 6),
     child: Row(
       children: [
         Container(
           width: 6,
           height: 6,
           decoration: BoxDecoration(
             color: statusColor,
             shape: BoxShape.circle,
           ),
         ),
         const SizedBox(width: 8),
         Expanded(
           child: Text(
             serverId,
             style: GoogleFonts.fustat(
                                            color: theme.colorScheme.onSurface,
             ),
           ),
         ),
         Text(
           status.toUpperCase(),
           style: GoogleFonts.fustat(
                                      fontWeight: FontWeight.w600,
             color: statusColor,
           ),
         ),
       ],
     ),
   );
 }

 Widget _buildContextDocItem(String docName, ThemeData theme) {
   return Padding(
     padding: const EdgeInsets.only(bottom: 6),
     child: Row(
       children: [
         Icon(Icons.description, size: 12, color: theme.colorScheme.primary),
         const SizedBox(width: 8),
         Expanded(
           child: Text(
             docName,
             style: GoogleFonts.fustat(
                                            color: theme.colorScheme.onSurface,
             ),
             overflow: TextOverflow.ellipsis,
           ),
         ),
       ],
     ),
   );
 }

 Widget _buildNoActiveAgentCard(ThemeData theme) {
   return Padding(
     padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.elementSpacing),
     child: Container(
       padding: const EdgeInsets.all(SpacingTokens.cardPadding),
       decoration: BoxDecoration(
         color: theme.colorScheme.surface.withValues(alpha: 0.5),
         borderRadius: BorderRadius.circular(12),
         border: Border.all(
           color: theme.colorScheme.outline.withValues(alpha: 0.2),
         ),
       ),
       child: Column(
         children: [
           Icon(
             Icons.chat_bubble_outline,
             size: 32,
             color: theme.colorScheme.onSurfaceVariant,
           ),
           const SizedBox(height: SpacingTokens.componentSpacing),
           Text(
             'No conversation selected',
             style: GoogleFonts.fustat(
                                            fontWeight: FontWeight.w500,
               color: theme.colorScheme.onSurfaceVariant,
             ),
           ),
         ],
       ),
     ),
   );
 }

 Widget _buildLoadingAgentCard(ThemeData theme) {
   return Padding(
     padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.elementSpacing),
     child: Container(
       padding: const EdgeInsets.all(SpacingTokens.cardPadding),
       decoration: BoxDecoration(
         color: theme.colorScheme.surface.withValues(alpha: 0.5),
         borderRadius: BorderRadius.circular(12),
       ),
       child: Row(
         children: [
           const SizedBox(
             width: 16,
             height: 16,
             child: CircularProgressIndicator(strokeWidth: 2),
           ),
           const SizedBox(width: SpacingTokens.componentSpacing),
           Text(
             'Loading agent context...',
             style: GoogleFonts.fustat(
                                            color: theme.colorScheme.onSurfaceVariant,
             ),
           ),
         ],
       ),
     ),
   );
 }

 Widget _buildErrorAgentCard(ThemeData theme) {
   return Padding(
     padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.elementSpacing),
     child: Container(
       padding: const EdgeInsets.all(SpacingTokens.cardPadding),
       decoration: BoxDecoration(
         color: Colors.red.withValues(alpha: 0.1),
         borderRadius: BorderRadius.circular(12),
       ),
       child: Text(
         'Error loading agent context',
         style: GoogleFonts.fustat(
                                color: Colors.red,
         ),
       ),
     ),
   );
 }

 /// Build MCP contextual recommendations widget
 Widget _buildMCPRecommendations(BuildContext context) {
   final colors = ThemeColors(context);
   final selectedConversationId = ref.watch(selectedConversationIdProvider);

   if (selectedConversationId == null) return const SizedBox.shrink();

   return ref.watch(conversationProvider(selectedConversationId)).when(
     data: (conversation) => _buildMCPRecommendationsContent(context, conversation, colors),
     loading: () => const SizedBox.shrink(),
     error: (_, __) => const SizedBox.shrink(),
   );
 }

 /// Build MCP recommendations content
 Widget _buildMCPRecommendationsContent(BuildContext context, core.Conversation conversation, ThemeColors colors) {
   // For now, show MCP integration for all conversations
   return Consumer(
     builder: (context, ref, child) {
       return MCPChatIntegration(currentAgent: null);
     },
   );
 }

 /// Build MCP server status widget showing currently running servers
 Widget _buildMCPServerStatus(BuildContext context) {
   final colors = ThemeColors(context);
   final runningServersAsync = ref.watch(runningMCPServersProvider);

   return runningServersAsync.when(
     data: (List<mcp_models.MCPServerProcess> servers) {
       if (servers.isEmpty) return const SizedBox.shrink();

       return Container(
         margin: const EdgeInsets.symmetric(
           horizontal: SpacingTokens.elementSpacing,
           vertical: SpacingTokens.xs,
         ),
         padding: const EdgeInsets.all(SpacingTokens.cardPadding),
         decoration: BoxDecoration(
           color: colors.surface.withValues(alpha: 0.8),
           borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
           border: Border.all(color: colors.border.withValues(alpha: 0.5)),
         ),
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Row(
               children: [
                 Icon(
                   Icons.settings_applications,
                   color: colors.primary,
                   size: 16,
                 ),
                 const SizedBox(width: SpacingTokens.xs),
                 Text(
                   'Active MCP Servers (${servers.length})',
                   style: TextStyles.bodySmall.copyWith(
                     color: colors.onSurfaceVariant,
                     fontWeight: FontWeight.w600,
                   ),
                 ),
               ],
             ),
             const SizedBox(height: SpacingTokens.xs),
             Wrap(
               spacing: SpacingTokens.xs,
               runSpacing: SpacingTokens.xs,
               children: servers.map((server) => _buildServerStatusChip(server, colors)).toList(),
             ),
           ],
         ),
       );
     },
     loading: () => const SizedBox.shrink(),
     error: (error, stack) => const SizedBox.shrink(),
   );
 }

 /// Build individual server status chip
 Widget _buildServerStatusChip(mcp_models.MCPServerProcess server, ThemeColors colors) {
   Color statusColor;
   IconData statusIcon;

   switch (server.status) {
     case mcp_models.MCPServerStatus.running:
       statusColor = Colors.green;
       statusIcon = Icons.check_circle;
       break;
     case mcp_models.MCPServerStatus.starting:
       statusColor = Colors.orange;
       statusIcon = Icons.access_time;
       break;
     case mcp_models.MCPServerStatus.stopping:
       statusColor = Colors.orange;
       statusIcon = Icons.stop_circle;
       break;
     case mcp_models.MCPServerStatus.error:
       statusColor = Colors.red;
       statusIcon = Icons.error;
       break;
     case mcp_models.MCPServerStatus.stopped:
     default:
       statusColor = Colors.grey;
       statusIcon = Icons.stop;
       break;
   }

   return Container(
     padding: const EdgeInsets.symmetric(
       horizontal: SpacingTokens.sm,
       vertical: SpacingTokens.xs,
     ),
     decoration: BoxDecoration(
       color: statusColor.withValues(alpha: 0.1),
       borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
       border: Border.all(color: statusColor.withValues(alpha: 0.3)),
     ),
     child: Row(
       mainAxisSize: MainAxisSize.min,
       children: [
         Icon(
           statusIcon,
           color: statusColor,
           size: 12,
         ),
         const SizedBox(width: SpacingTokens.xs),
         Text(
           server.serverId,
           style: TextStyles.bodySmall.copyWith(
             color: colors.onSurface,
             fontSize: 11,
           ),
         ),
       ],
     ),
   );
 }

 /// Create a new direct chat conversation with the selected model
 Future<void> _startNewDirectChat() async {
   try {
     // Get the selected model (falls back to first configured model if none selected)
     final selectedModel = ref.read(selectedModelProvider);
     
     if (selectedModel == null) {
       // Show error if no model is configured
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text('Please configure at least one AI model in Settings to start chatting'),
           backgroundColor: ThemeColors(context).warning,
           action: SnackBarAction(
             label: 'Settings',
             onPressed: () => context.push(AppRoutes.settings),
             textColor: Colors.white,
           ),
         ),
       );
       return;
     }

     // Create a new direct conversation (not agent-based)
     final conversationService = ref.read(conversationServiceProvider);
     final newConversation = core.Conversation(
       id: DateTime.now().millisecondsSinceEpoch.toString(),
       title: 'Chat with ${selectedModel.name}',
       messages: [],
       createdAt: DateTime.now(),
       lastModified: DateTime.now(),
       metadata: {
         'model_id': selectedModel.id,
         'model_name': selectedModel.name,
         'model_type': selectedModel.isLocal ? 'local' : 'api',
         'created_from': 'start_new_chat_button',
         'type': 'direct', // Mark as direct conversation (not agent-based)
       },
     );

     // Save the conversation
     await conversationService.createConversation(newConversation);

     // Refresh the conversations list to show the new conversation
     ref.invalidate(conversationsProvider);

     // Select the new conversation to enable chatting
     ref.read(selectedConversationIdProvider.notifier).state = newConversation.id;

   } catch (e) {
     // Show error message if conversation creation fails
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text('Failed to start new chat: $e'),
         backgroundColor: Colors.red,
       ),
     );
   }
 }

 void _sendMessage() async {
 final selectedConversationId = ref.read(selectedConversationIdProvider);
 if (messageController.text.trim().isEmpty || 
 ref.read(isLoadingProvider) || 
 selectedConversationId == null) {
   return;
 }

 try {
 ref.read(isLoadingProvider.notifier).state = true;

 // OPTIMIZATION: Removed priming request to eliminate 1-5s delay on first message
 // The model warmup service handles initial model loading in the background
 // No need to prime before every first message - wastes time and creates latency

 final sendMessage = ref.read(sendMessageProvider);
 await sendMessage(
 conversationId: selectedConversationId,
 content: messageController.text.trim(),
 );
 
 final messageContent = messageController.text.trim();
 messageController.clear();
 
 // Get conversation details to check if it's an agent conversation
 final conversation = await ref.read(conversationProvider(selectedConversationId).future);
 final isAgentConversation = conversation.metadata?['type'] == 'agent';
 
 if (isAgentConversation) {
 // Simple direct response for agent conversations (bypass MCP for now)
 await _handleAgentDirectResponse(selectedConversationId, messageContent, conversation);
 } else {
 // Standard API response for non-agent conversations
 await _handleStandardResponse(selectedConversationId);
 }
 
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Failed to send message: $e'),
 backgroundColor: ThemeColors(context).error,
 ),
 );
 }
 } finally {
 ref.read(isLoadingProvider.notifier).state = false;
 }
 }

 Future<void> _handleAgentDirectResponse(String conversationId, String userMessage, core.Conversation conversation) async {
  // Check if DSPy backend is connected
  final dspyService = ref.read(dspyServiceProvider);
  final dspyConnected = dspyService.state.isConnected;

  if (!dspyConnected) {
    // Fallback to standard response if DSPy is not connected
    AppLogger.warning('DSPy not connected, falling back to standard LLM', component: 'Chat.Agent');
    await _handleStandardResponse(conversationId);
    return;
  }

  try {
    // Get MCP tools from conversation metadata
    final mcpServers = conversation.metadata?['mcpServers'] as List<dynamic>? ?? [];

    // TASK 5: Ensure MCP servers are running before processing message
    if (mcpServers.isNotEmpty) {
      AppLogger.info('Checking MCP server health for ${mcpServers.length} servers', component: 'Chat.MCP');
      final mcpExecutionService = ref.read(mcpServerExecutionServiceProvider);

      for (final server in mcpServers) {
        final serverId = server is Map ? server['id'] as String? : server.toString();
        if (serverId == null) continue;

        // Check if server is running
        final runningServer = mcpExecutionService.getRunningServer(serverId);

        if (runningServer == null) {
          // Server not running, start it
          AppLogger.info('Starting MCP server: $serverId', component: 'Chat.MCP');
          try {
            await mcpExecutionService.startMCPServer(serverId);
            AppLogger.info('MCP server started successfully: $serverId', component: 'Chat.MCP');
          } catch (e) {
            AppLogger.error('Failed to start MCP server: $serverId', component: 'Chat.MCP', error: e);
            // Continue with other servers even if one fails
          }
        } else {
          AppLogger.info('MCP server already running: $serverId (status: ${runningServer.status})', component: 'Chat.MCP');
        }
      }
    }

    final tools = <Map<String, dynamic>>[];

    // Build tool definitions for MCP servers
    for (final server in mcpServers) {
      final serverId = server is Map ? server['id'] as String? : server.toString();
      if (serverId != null) {
        tools.add({
          'name': serverId.replaceAll('-', '_'),
          'description': 'MCP server: $serverId',
          'server_id': serverId,
        });
      }
    }

    AppLogger.info(
      'Starting DSPy agent stream for agent conversation (${tools.length} tools, ${mcpServers.length} MCP servers)',
      component: 'Chat.Agent',
    );

    // Create streaming message to show progress
    final streamingMessageId = DateTime.now().millisecondsSinceEpoch.toString();
    final service = ref.read(conversationServiceProvider);

    var streamingMessage = core.Message(
      id: streamingMessageId,
      content: '',
      role: core.MessageRole.assistant,
      timestamp: DateTime.now(),
      metadata: {
        'streaming': true,
        'processingStatus': 'initializing',
        'mcpInteractions': <Map<String, dynamic>>[],
        'toolResults': <Map<String, dynamic>>[],
        'dspyStream': true,
      },
    );

    await service.addMessage(conversationId, streamingMessage);
    ref.invalidate(messagesProvider(conversationId));

    // Initialize streaming message state for real-time UI updates
    final streamingNotifier = ref.read(streamingMessageProvider.notifier);
    streamingNotifier.startStreaming(streamingMessageId, conversationId, '');
    streamingNotifier.updateProcessingStatus(streamingMessageId, 'Starting agent...');

    // Start streaming from DSPy
    String currentAnswer = '';
    final stepsList = <Map<String, dynamic>>[];
    final toolCalls = <Map<String, dynamic>>[];
    final toolResults = <Map<String, dynamic>>[];
    String currentStatus = 'Starting agent...';

    await for (final event in dspyService.streamAgent(
      userMessage,
      tools: tools,
      maxIterations: 5,
      conversationId: conversationId,
      flutterCallbackUrl: 'http://localhost:3000', // Plugin Bridge Server
    )) {
      switch (event.type) {
        case DspyStreamEventType.status:
          currentStatus = event.statusMessage ?? currentStatus;
          // Update streaming widget status in real-time
          streamingNotifier.updateProcessingStatus(streamingMessageId, currentStatus);
          break;

        case DspyStreamEventType.toolCall:
          final toolName = event.toolName ?? 'unknown';
          final toolData = {
            'tool': toolName,
            'arguments': event.data['arguments'],
            'timestamp': event.timestamp.toIso8601String(),
          };
          toolCalls.add(toolData);
          currentStatus = 'Calling tool: $toolName';
          streamingNotifier.updateProcessingStatus(streamingMessageId, currentStatus);
          break;

        case DspyStreamEventType.toolResult:
          final resultData = {
            'result': event.data['result'],
            'success': event.data['success'] ?? true,
            'timestamp': event.timestamp.toIso8601String(),
          };
          toolResults.add(resultData);
          currentStatus = 'Tool completed';
          // Add tool result to streaming widget
          streamingNotifier.addToolResult(
            streamingMessageId,
            MCPToolResult(
              serverId: event.data['server_id'] as String? ?? 'unknown',
              toolName: event.data['tool'] as String? ?? 'unknown',
              arguments: (event.data['arguments'] as Map<String, dynamic>?) ?? {},
              result: event.data['result'],
              success: event.data['success'] as bool? ?? true,
              error: event.data['error'] as String?,
              timestamp: event.timestamp,
            ),
          );
          streamingNotifier.updateProcessingStatus(streamingMessageId, currentStatus);
          break;

        case DspyStreamEventType.step:
          stepsList.add(event.data);
          final thought = event.data['thought'] as String?;
          if (thought != null) {
            streamingNotifier.updateProcessingStatus(streamingMessageId, 'Thinking: ${thought.length > 50 ? '${thought.substring(0, 50)}...' : thought}');
          }
          break;

        case DspyStreamEventType.token:
          // Append token to answer (for streaming text support)
          final token = event.data['token'] as String? ?? '';
          currentAnswer += token;
          streamingNotifier.addStreamedToken(streamingMessageId, token);
          break;

        case DspyStreamEventType.done:
          // Final answer received
          currentAnswer = event.answer ?? currentAnswer;
          final iterations = event.data['iterations'] as int? ?? stepsList.length;

          // Complete the streaming state
          streamingNotifier.completeStreaming(
            streamingMessageId,
            metadata: {
              'toolsUsed': toolCalls.length,
              'iterations': iterations,
              'processingTime': DateTime.now().difference(streamingMessage.timestamp).inMilliseconds,
            },
          );

          // Also update final content if we didn't stream tokens
          if (currentAnswer.isNotEmpty) {
            streamingNotifier.addStreamedToken(streamingMessageId, currentAnswer);
          }

          // Create final message for persistence
          final finalMessage = core.Message(
            id: streamingMessageId,
            content: currentAnswer,
            role: core.MessageRole.assistant,
            timestamp: streamingMessage.timestamp,
            metadata: {
              'streaming': false,
              'processingStatus': 'completed',
              'mcpInteractions': toolCalls,
              'toolResults': toolResults,
              'steps': stepsList,
              'iterations': iterations,
              'success': event.data['success'] ?? true,
              'dspyStream': true,
            },
          );

          await service.addMessage(conversationId, finalMessage);
          ref.invalidate(messagesProvider(conversationId));
          break;

        case DspyStreamEventType.error:
          // Handle error
          final errorMsg = event.errorMessage ?? 'Unknown error';
          AppLogger.error('DSPy stream error', component: 'Chat.Agent', error: errorMsg);

          // Complete streaming with error
          streamingNotifier.completeStreaming(
            streamingMessageId,
            error: errorMsg,
          );

          final errorMessage = core.Message(
            id: streamingMessageId,
            content: 'Sorry, I encountered an error: $errorMsg',
            role: core.MessageRole.assistant,
            timestamp: streamingMessage.timestamp,
            metadata: {
              'streaming': false,
              'processingStatus': 'error',
              'error': errorMsg,
              'isError': true,
              'dspyStream': true,
            },
          );

          await service.addMessage(conversationId, errorMessage);
          ref.invalidate(messagesProvider(conversationId));
          break;
      }
    }

  } catch (e) {
    AppLogger.error('DSPy agent execution failed', component: 'Chat.Agent', error: e);
    // Fallback to standard response on error
    await _handleStandardResponse(conversationId);
  }
}

// DEPRECATED: MCPBridgeService removed
// Future<void> _handleMCPResponse(MCPBridgeService mcpBridge, String conversationId, String userMessage, core.Conversation conversation) async {
//  try {
//  // Create streaming message with MCP metadata
//  final streamingMessage = core.Message(
//  id: DateTime.now().millisecondsSinceEpoch.toString(),
//  content: '',
//  role: core.MessageRole.assistant,
//  timestamp: DateTime.now(),
//  metadata: {
//  'streaming': true,
//  'processingStatus': 'initializing',
//  'mcpInteractions': <Map<String, dynamic>>[],
//  'toolResults': <Map<String, dynamic>>[],
//  },
//  );
//
//  final service = ref.read(conversationServiceProvider);
//  await service.addMessage(conversationId, streamingMessage);
//  ref.invalidate(messagesProvider(conversationId));
//
//  // Process message through MCP bridge
//  final enabledServers = (conversation.metadata?['mcpServers'] as List<dynamic>?)
//  ?.map((server) => server['id'] as String)
//  .toList() ?? <String>[];
//  
//  final response = await mcpBridge.processMessage(
//  conversationId: conversationId,
//  message: userMessage,
//  enabledServerIds: enabledServers,
//  conversationMetadata: conversation.metadata,
//  );
//
//  // Update message with final content and MCP interaction data
//  AppLogger.debug('MCP response received: length=${response.response.length}', component: 'Chat.MCP');
//  
//  final finalMessage = core.Message(
//  id: streamingMessage.id,
//  content: response.response,
//  role: core.MessageRole.assistant,
//  timestamp: streamingMessage.timestamp,
//  metadata: {
//  'streaming': false,
//  'processingStatus': 'completed',
//  'mcpInteractions': response.metadata['interactions'] ?? [],
//  'toolResults': response.metadata['toolResults'] ?? [],
//  'executionTime': response.latency,
//  'mcpServersUsed': response.usedServers,
//  },
//  );
//
//  await service.addMessage(conversationId, finalMessage);
//  ref.invalidate(messagesProvider(conversationId));
//
//  } catch (e) {
//  print('MCP response error: $e');
//  // Fallback to standard response
//  await _handleStandardResponse(conversationId);
//  }
//  }

 Future<void> _handleStandardResponse(String conversationId) async {
 try {
 // Get unified LLM service and conversation-specific model
 final unifiedLLMService = ref.read(unifiedLLMServiceProvider);
 var selectedModel = ref.read(conversationModelProvider(conversationId))
     ?? ref.read(selectedModelProvider);

 // OPTIMIZATION: Use quick chat model for instant responses in agentless chats
 // Check if this is a simple agentless conversation that can benefit from a quick model
 final conversation = await ref.read(conversationProvider(conversationId).future);
 final isAgentConversation = conversation.metadata?['type'] == 'agent';
 final hasGlobalMCP = ref.read(mcpSettingsServiceProvider).getAllMCPServers()
     .where((server) => server.enabled).isNotEmpty;
 final hasContextDocs = ref.read(mcpSettingsServiceProvider).globalContextDocuments.isNotEmpty;

 // Use quick chat model if:
 // 1. Not an agent conversation
 // 2. No global MCP servers enabled
 // 3. No global context documents
 // 4. No specific model already selected for this conversation
 final shouldUseQuickChat = !isAgentConversation && !hasGlobalMCP && !hasContextDocs &&
                            ref.read(conversationModelProvider(conversationId)) == null;

 if (shouldUseQuickChat) {
   final quickChatService = ref.read(quickChatModelServiceProvider);
   final quickModelId = quickChatService.getBestQuickChatModel();

   if (quickModelId != null) {
     final quickModel = ref.read(modelConfigServiceProvider).getModelConfig(quickModelId);
     if (quickModel != null && quickModel.isConfigured) {
       debugPrint('🚀 Using quick chat model: ${quickModel.name} for instant response');
       selectedModel = quickModel;
       // Mark as used to maintain keep-alive
       quickChatService.markAsUsed(quickModelId);
     }
   }
 }

 // Check if model is configured - different logic for local vs API models
 AppLogger.debug(
   'Model validation: name=${selectedModel?.name}, isLocal=${selectedModel?.isLocal}, isConfigured=${selectedModel?.isConfigured}, status=${selectedModel?.status}',
   component: 'Chat.Model'
 );
 
 if (selectedModel == null) {
   if (mounted) {
     _showApiKeyConfigurationDialog();
   }
   throw Exception('No model selected. Please select an AI model to start chatting.');
 }
 
 if (!selectedModel.isConfigured) {
   if (selectedModel.isLocal) {
     // For local models, try to make them ready if Ollama is available
     if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text('Local model "${selectedModel.name}" is not ready. Status: ${selectedModel.status}.\n\nTo fix:\n1. Install Ollama from ollama.ai\n2. Run: ollama pull ${selectedModel.ollamaModelId ?? selectedModel.name.toLowerCase()}'),
           backgroundColor: ThemeColors(context).error,
           duration: const Duration(seconds: 6),
         ),
       );
     }
     throw Exception('Local model not ready. Status: ${selectedModel.status}. Please install Ollama and run: ollama pull ${selectedModel.ollamaModelId ?? selectedModel.name.toLowerCase()}');
   } else {
     // For API models, show API key configuration
     if (mounted) {
       _showApiKeyConfigurationDialog();
     }
     throw Exception('API model not configured. Please configure your API key to start chatting.');
   }
 }

 // Get conversation messages for context
 final service = ref.read(conversationServiceProvider);
 final messages = await service.getMessages(conversationId);
 
 // Build conversation history for LLM
 final conversationHistory = messages
 .where((msg) => msg.role != core.MessageRole.system)
 .map((msg) => {
 'role': msg.role == core.MessageRole.user ? 'user' : 'assistant',
 'content': msg.content,
 })
 .toList();

 // Remove the last user message since it will be sent separately
 final lastUserMessage = conversationHistory.removeLast();
 final userMessage = lastUserMessage['content'] as String;

 // Enhanced system prompt with context integration for non-agent conversations
 // (conversation already fetched earlier for quick chat check)
 String enhancedSystemPrompt;
 final baseSystemPrompt = conversation.metadata?['systemPrompt'] as String?;
 
 // Check for global context documents and MCP servers from settings
 final mcpService = ref.read(mcpSettingsServiceProvider);
 final globalContextDocs = mcpService.globalContextDocuments;
 final globalMcpServers = mcpService.getAllMCPServers()
     .where((server) => server.enabled)
     .map((server) => server.id)
     .toList();
 
 if (globalContextDocs.isNotEmpty || globalMcpServers.isNotEmpty) {
   // Use context prompt service to enhance the system prompt
   final contextService = ref.read(agentContextPromptServiceProvider);
   final contextInstructions = globalContextDocs.isNotEmpty 
     ? '\n\n## Available Context\nYou have access to context documents that may be relevant to user questions.'
     : '';
   final mcpInstructions = globalMcpServers.isNotEmpty
     ? contextService.generateMCPContextInstructions(globalMcpServers)
     : '';
     
   enhancedSystemPrompt = (baseSystemPrompt ?? 'You are a helpful AI assistant.') + 
                          contextInstructions + mcpInstructions;
 } else {
   enhancedSystemPrompt = baseSystemPrompt ?? 'You are a helpful AI assistant.';
 }

 // Create enhanced chat context with MCP and context awareness
 final chatContext = ChatContext(
 messages: conversationHistory,
 systemPrompt: enhancedSystemPrompt,
 metadata: {
   'hasGlobalContext': globalContextDocs.isNotEmpty,
   'hasGlobalMCP': globalMcpServers.isNotEmpty,
   'globalMcpServers': globalMcpServers,
   'globalContextDocs': globalContextDocs,
 },
 );

  // For non-agent conversations with global MCP servers, try to use MCP bridge
  // DEPRECATED: MCPBridgeService removed, falling back to direct LLM
  if (globalMcpServers.isNotEmpty) {
    AppLogger.warning('Global MCP servers detected but MCPBridgeService unavailable, using direct LLM', component: 'Chat.MCP');
    // Fall through to direct LLM call
  }
  /*
  if (globalMcpServers.isNotEmpty) {
    AppLogger.info('Standard conversation using global MCP servers: $globalMcpServers', component: 'Chat.MCP');
    try {
      final mcpBridge = MCPBridgeService(mcpService);
      final mcpResponse = await mcpBridge.processMessage(
        conversationId: conversationId,
        message: userMessage,
        enabledServerIds: globalMcpServers,
        conversationMetadata: {
          ...conversation.metadata ?? {},
          'mcpServers': globalMcpServers.map((id) => {'id': id}).toList(),
          'contextDocuments': globalContextDocs,
          'type': 'standard_with_mcp',
        },
      );
      
      // Create assistant message with MCP response
      final assistantMessage = core.Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: mcpResponse.response,
        role: core.MessageRole.assistant,
        timestamp: DateTime.now(),
        metadata: {
          'modelUsed': selectedModel.id,
          'responseType': 'mcp_enhanced',
          'mcpServersUsed': globalMcpServers,
          'mcpServersActuallyUsed': mcpResponse.usedServers,
          'hasGlobalContext': globalContextDocs.isNotEmpty,
          'mcpLatency': mcpResponse.latency,
          'mcpMetadata': mcpResponse.metadata,
        },
      );
      
      await service.addMessage(conversationId, assistantMessage);
      
      // Update conversation priming status to success since message worked
      await _updateConversationPrimingAfterSuccess(conversationId, selectedModel);
      
      ref.invalidate(messagesProvider(conversationId));
      return;
      
    } catch (mcpError) {
      AppLogger.warning('MCP processing failed for standard conversation, falling back to direct LLM', component: 'Chat.MCP', error: mcpError);
      // Fall through to direct LLM call
    }
  }
  */

 // Direct LLM call (fallback or when no global MCP servers)
 final response = await unifiedLLMService.chat(
 message: userMessage,
 modelId: selectedModel.id,
 context: chatContext,
 );

 // Create assistant message with the response
 final assistantMessage = core.Message(
 id: DateTime.now().millisecondsSinceEpoch.toString(),
 content: response.content,
 role: core.MessageRole.assistant,
 timestamp: DateTime.now(),
 metadata: {
 'modelUsed': response.modelUsed,
 'responseType': 'direct_llm',
 'enhancedPrompt': enhancedSystemPrompt != baseSystemPrompt,
 'hasGlobalContext': globalContextDocs.isNotEmpty,
 'modelType': selectedModel.type.name,
 'modelProvider': selectedModel.provider,
 'tokenUsage': response.usage != null ? {
 'inputTokens': response.usage!.inputTokens,
 'outputTokens': response.usage!.outputTokens,
 'totalTokens': response.usage!.totalTokens,
 'estimatedCost': response.usage!.estimatedCost,
 } : null,
 'responseMetadata': response.metadata,
 },
 );

 await service.addMessage(conversationId, assistantMessage);
 
 // Update conversation priming status to success since message worked
 await _updateConversationPrimingAfterSuccess(conversationId, selectedModel);
 
 ref.invalidate(messagesProvider(conversationId));
 
 } catch (e) {
 // Create error message
 final errorMessage = core.Message(
 id: DateTime.now().millisecondsSinceEpoch.toString(),
 content: 'Sorry, I encountered an error: ${e.toString()}',
 role: core.MessageRole.assistant,
 timestamp: DateTime.now(),
 metadata: {
 'isError': true,
 'errorType': e.runtimeType.toString(),
 },
 );

 final service = ref.read(conversationServiceProvider);
 await service.addMessage(conversationId, errorMessage);
 ref.invalidate(messagesProvider(conversationId));
 }
 }

 Widget _buildEmptyConversationState(BuildContext context) {
 final theme = Theme.of(context);
 return Center(
 child: Container(
 constraints: const BoxConstraints(maxWidth: 400),
 child: Column(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 Container(
 width: 64,
 height: 64,
 decoration: BoxDecoration(
 color: theme.colorScheme.surfaceContainerHighest,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: theme.colorScheme.outline),
 ),
 child: Icon(
 Icons.chat_bubble_outline,
 size: 32,
 color: theme.colorScheme.onSurfaceVariant,
 ),
 ),
 const SizedBox(height: SpacingTokens.textSectionSpacing),
 Text(
 'Let\'s Talk',
 style: GoogleFonts.fustat(
  fontWeight: FontWeight.w600,
 color: theme.colorScheme.onSurface,
 ),
 ),
 const SizedBox(height: SpacingTokens.componentSpacing),
 Text(
 'Type a message below to begin this conversation.',
 style: GoogleFonts.fustat(
  color: theme.colorScheme.onSurfaceVariant,
 height: 1.5,
 ),
 textAlign: TextAlign.center,
 ),
 ],
 ),
 ),
 );
 }
 
 String _formatTime(DateTime time) {
 return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
 }

 /// Get display name for conversation - shows the actual conversation title or appropriate default
 String _getDisplayName(core.Conversation conversation) {
 final agentType = conversation.metadata?['type'] as String?;
 final agentName = conversation.metadata?['agentName'] as String?;
 
 // For agent conversations, prefer agent name
 if (agentType == 'agent' && agentName != null && agentName.isNotEmpty) {
 return agentName;
 }
 
 // For non-agent conversations, use the conversation title if it's meaningful
 if (conversation.title.isNotEmpty && 
 conversation.title != 'Let\'s Talk' && 
 conversation.title != 'New Chat' &&
 !conversation.title.startsWith('New Conversation')) {
 return conversation.title;
 }
 
 // Fallback based on conversation type
 switch (agentType) {
 case 'agent':
 return agentName ?? 'Agent Assistant';
 case 'default_api':
 case 'direct_chat':
 return 'AI Assistant';
 default:
 return 'Chat Session';
 }
 }

 /// Get description for conversation based on its type and current model
 String _getConversationDescription(core.Conversation conversation) {
 final agentType = conversation.metadata?['type'] as String?;
 final selectedModel = ref.read(selectedModelProvider);
 
 switch (agentType) {
 case 'agent':
 final mcpServers = conversation.metadata?['mcpServers'] as List<dynamic>? ?? [];
 return mcpServers.isNotEmpty 
 ? 'MCP-Enabled Agent with ${mcpServers.length} tool(s)'
 : 'Custom Agent Assistant';
 
 case 'default_api':
 case 'direct_chat':
 return 'Direct AI conversation';
 
 default:
 return 'Chat Session';
 }
 }


/// Build priming status indicator for conversation
Widget _buildPrimingStatusIndicator(BuildContext context, core.Conversation conversation) {
 final primingStatus = ref.watch(conversationPrimingStatusProvider(conversation.id));
 final theme = Theme.of(context);
 
 if (primingStatus == null) return Container();
 
 final isPrimed = primingStatus['isPrimed'] as bool? ?? false;
 final primingAttempted = primingStatus['primingAttempted'] as bool? ?? false;
 final primingError = primingStatus['primingError'] as String?;
 
 Color indicatorColor;
 String statusText;
 IconData statusIcon;
 
 if (isPrimed) {
   indicatorColor = ThemeColors(context).success;
   statusText = 'PRIMED';
   statusIcon = Icons.check_circle;
 } else if (primingError != null) {
   indicatorColor = ThemeColors(context).error;
   statusText = 'ERROR';
   statusIcon = Icons.error;
 } else if (primingAttempted) {
   indicatorColor = theme.colorScheme.onSurfaceVariant;
   statusText = 'FAILED';
   statusIcon = Icons.warning;
 } else {
   indicatorColor = theme.colorScheme.onSurfaceVariant;
   statusText = 'NOT PRIMED';
   statusIcon = Icons.schedule;
 }
 
 return Container(
   padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
   decoration: BoxDecoration(
     color: indicatorColor.withValues(alpha: 0.1),
     borderRadius: BorderRadius.circular(8),
     border: Border.all(
       color: indicatorColor.withValues(alpha: 0.3),
     ),
   ),
   child: Row(
     mainAxisSize: MainAxisSize.min,
     children: [
       Icon(
         statusIcon,
         size: 10,
         color: indicatorColor,
       ),
       const SizedBox(width: 4),
       Text(
         statusText,
         style: GoogleFonts.fustat(
                     fontWeight: FontWeight.w600,
           color: indicatorColor,
         ),
       ),
     ],
   ),
 );
}

/// Update conversation priming status to success after message works
Future<void> _updateConversationPrimingAfterSuccess(String conversationId, ModelConfig model) async {
 try {
   final businessService = ref.read(conversationBusinessServiceProvider);
   
   // Update conversation metadata to reflect successful priming
   await businessService.updateConversation(
     conversationId: conversationId,
     metadata: {
       'isPrimed': true,
       'primingAttempted': true,
       'primedAt': DateTime.now().toIso8601String(),
       'primingResult': {
         'status': 'success',
         'method': 'message_success',
         'modelUsed': model.id,
         'modelName': model.name,
         'verifiedAt': DateTime.now().toIso8601String(),
       },
       'primingError': null, // Clear any previous error
     },
   );
   
   // Update model warm-up status to ready since message succeeded
   final warmUpService = ref.read(modelWarmUpServiceProvider);
   warmUpService.markModelAsReady(model.id);
   
   // Refresh conversation provider to update UI
   ref.invalidate(conversationProvider(conversationId));
   
 } catch (e) {
   AppLogger.error('Failed to update priming status after success', component: 'Chat.Priming', error: e);
 }
}

 /// Show API key configuration dialog when user tries to chat without API key
 void _showApiKeyConfigurationDialog() {
   showDialog(
     context: context,
     barrierDismissible: false, // Force user to configure or cancel
     builder: (context) => AlertDialog(
       title: Row(
         children: [
           Icon(Icons.key, color: ThemeColors(context).primary),
           const SizedBox(width: 8),
           const Text('API Key Required'),
         ],
       ),
       content: const Column(
         mainAxisSize: MainAxisSize.min,
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Text('To start chatting with AI, you need to configure your API key.'),
           SizedBox(height: 8),
           Text('This enables real AI conversations with Claude or other providers.'),
         ],
       ),
       actions: [
         TextButton(
           onPressed: () => Navigator.of(context).pop(),
           child: const Text('Later'),
         ),
         ElevatedButton.icon(
           onPressed: () {
             Navigator.of(context).pop();
             context.push(AppRoutes.settings);
           },
           icon: const Icon(Icons.settings),
           label: const Text('Configure API Key'),
           style: ElevatedButton.styleFrom(
             backgroundColor: ThemeColors(context).primary,
             foregroundColor: ThemeColors(context).onPrimary,
           ),
         ),
       ],
     ),
   );
 }

  /// New contextual input area implementation
  Widget _buildContextualInput() {
    return ContextualInputArea(
      messageController: messageController,
      onSendMessage: _sendMessage,
      isLoading: ref.watch(isLoadingProvider),
    );
  }

  /// Get the active streaming message ID for the given conversation
  String _getActiveStreamingMessageId(WidgetRef ref, String conversationId) {
    final streamingStates = ref.watch(streamingMessageProvider);
    return streamingStates.keys
        .where((id) => streamingStates[id]?.conversationId == conversationId && !streamingStates[id]!.isComplete)
        .firstOrNull ?? 'streaming-temp';
  }
}



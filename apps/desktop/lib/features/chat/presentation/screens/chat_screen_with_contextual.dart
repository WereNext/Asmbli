import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:agent_engine_core/models/conversation.dart' as core;
import 'dart:async';
import 'dart:ui';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/widgets/floating_notification.dart';
import '../../../../providers/conversation_provider.dart';
// import '../../../../core/services/mcp_bridge_service.dart'; // REMOVED: MCPBridgeService deleted
import '../../../../core/services/mcp_settings_service.dart';
import '../../../../core/services/llm/unified_llm_service.dart';
import '../../../../core/services/llm/llm_provider.dart';
import '../../../../core/services/model_config_service.dart';
// DSPy Integration - unified AI backend
import '../../../../core/services/dspy/dspy.dart';
import '../../../../core/models/model_config.dart';
import '../../../../core/services/agent_context_prompt_service.dart';
import '../../../../core/services/model_warmup_service.dart';
import '../widgets/improved_conversation_sidebar.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/agent_deployment_section.dart';
import '../widgets/streaming_message_widget.dart';
import '../widgets/editable_conversation_title.dart';
import '../widgets/context_sidebar_section.dart';
import '../widgets/contextual_context_widget.dart';
import '../widgets/animated_context_toolbar.dart';
import '../widgets/artifacts/artifact_workspace.dart';
import '../widgets/chat_tab_bar.dart';
import '../widgets/chat_status_bar.dart';
import '../widgets/conversation_starter.dart';
import '../../../../providers/agent_provider.dart';

/// Chat screen with contextual context integration
class ChatScreenWithContextual extends ConsumerStatefulWidget {
 final String? selectedTemplate;
 final String? agentId;

  const ChatScreenWithContextual({super.key, this.selectedTemplate, this.agentId});

 @override
 ConsumerState<ChatScreenWithContextual> createState() => _ChatScreenWithContextualState();
}

class _ChatScreenWithContextualState extends ConsumerState<ChatScreenWithContextual> {
 final TextEditingController messageController = TextEditingController();

 /// Whether we're currently initializing an agent chat session
 bool _isInitializingAgentChat = false;
 
 @override
 void initState() {
   super.initState();
   _initializeServices();
   _loadRecentConversationsIntoTabs();

   // Check if an agent was requested via URL parameter
   if (widget.agentId != null) {
     _isInitializingAgentChat = true;
     _initializeAgentChat();
   }
 }

 /// Load recent conversations into the tab bar on initialization
 Future<void> _loadRecentConversationsIntoTabs() async {
   // Wait a frame for providers to be available
   await Future.delayed(const Duration(milliseconds: 100));
   if (!mounted) return;

   try {
     // Get recent conversations from the provider
     final conversationsAsync = ref.read(conversationsProvider);
     final conversations = conversationsAsync.valueOrNull;

     if (conversations == null || conversations.isEmpty) {
       debugPrint('📋 No recent conversations to load into tabs');
       return;
     }

     // Get existing open tabs to avoid duplicates
     final existingTabs = ref.read(openConversationTabsProvider);
     final tabNotifier = ref.read(openConversationTabsProvider.notifier);

     // Load the most recent conversations (up to 5) that aren't already open
     final recentToLoad = conversations
         .where((c) => !existingTabs.contains(c.id))
         .take(5)
         .toList();

     for (final conversation in recentToLoad) {
       tabNotifier.openTab(conversation.id);
     }

     // Set the first conversation as active if none is selected
     final activeTab = ref.read(activeConversationTabProvider);
     final selectedId = ref.read(selectedConversationIdProvider);

     if (activeTab == null && selectedId == null && conversations.isNotEmpty) {
       final firstConv = conversations.first;
       ref.read(activeConversationTabProvider.notifier).state = firstConv.id;
       ref.read(selectedConversationIdProvider.notifier).state = firstConv.id;
     }

     debugPrint('📋 Loaded ${recentToLoad.length} recent conversations into tabs');
   } catch (e) {
     debugPrint('❌ Failed to load recent conversations: $e');
   }
 }

 Future<void> _initializeServices() async {
 try {
 // Services are initialized via Riverpod providers
 // No manual ServiceProvider needed - services auto-initialize when accessed

 // Set default model to Llama3.2 if no model is selected
 _setDefaultModel();

 // Start model warm-up process in background (non-blocking)
 _startModelWarmUpInBackground();
 } catch (e) {
 print('Service initialization failed: $e');
 }
 }

 /// Initialize a chat session with a specific agent
 Future<void> _initializeAgentChat() async {
   final agentId = widget.agentId;
   if (agentId == null) return;

   try {
     // Wait a frame for providers to be available
     await Future.delayed(const Duration(milliseconds: 100));
     if (!mounted) return;

     // Get the agent from the provider
     final agentsAsync = ref.read(agentsProvider);
     final agents = agentsAsync.valueOrNull;
     if (agents == null || agents.isEmpty) {
       debugPrint('⚠️ No agents loaded yet, waiting...');
       // Try again after agents load
       Future.delayed(const Duration(milliseconds: 500), () {
         if (mounted) _initializeAgentChat();
       });
       return;
     }

     // Find the requested agent
     final agent = agents.where((a) => a.id == agentId).firstOrNull;
     if (agent == null) {
       debugPrint('⚠️ Agent not found: $agentId');
       if (mounted) {
         setState(() => _isInitializingAgentChat = false);
       }
       return;
     }

     debugPrint('🤖 Initializing chat with agent: ${agent.name}');

     // Create a new agent conversation using the existing provider
     final createAgentConversation = ref.read(createAgentConversationProvider);

     // Get agent configuration
     final mcpServersRaw = agent.configuration['mcpServers'];
     final mcpServers = mcpServersRaw is List
         ? List<String>.from(mcpServersRaw)
         : <String>[];

     final mcpServerConfigsRaw = agent.configuration['mcpServerConfigs'];
     final mcpServerConfigs = mcpServerConfigsRaw is Map
         ? Map<String, dynamic>.from(mcpServerConfigsRaw)
         : <String, dynamic>{};

     final contextDocsRaw = agent.configuration['contextDocuments'];
     final contextDocuments = contextDocsRaw is List
         ? List<String>.from(contextDocsRaw)
         : <String>[];

     // Get the default model for the API provider
     final defaultModel = ref.read(defaultModelConfigProvider);
     final modelProvider = defaultModel?.name ?? 'Local Model';

     // Create the conversation with the agent's name as title
     final conversation = await createAgentConversation(
       agentId: agent.id,
       agentName: agent.name,
       systemPrompt: agent.configuration['systemPrompt']?.toString() ??
         'You are a helpful AI assistant named ${agent.name}. ${agent.description}',
       apiProvider: modelProvider,
       mcpServers: mcpServers,
       mcpServerConfigs: mcpServerConfigs,
       contextDocuments: contextDocuments,
     );

     if (!mounted) return;

     // Select the new conversation
     ref.read(selectedConversationIdProvider.notifier).state = conversation.id;

     // Add to tab bar so it shows in the chat header
     ref.read(openConversationTabsProvider.notifier).openTab(conversation.id);
     ref.read(activeConversationTabProvider.notifier).state = conversation.id;

     // Refresh conversations list
     ref.invalidate(conversationsProvider);

     debugPrint('✅ Created agent chat: ${conversation.title} (${conversation.id})');

     // Clear loading state and show notification
     if (mounted) {
       setState(() => _isInitializingAgentChat = false);
       FloatingNotification.success(
         context,
         'Started chat with ${agent.name}',
       );
     }
   } catch (e) {
     debugPrint('❌ Failed to initialize agent chat: $e');
     if (mounted) {
       setState(() => _isInitializingAgentChat = false);
       FloatingNotification.error(
         context,
         'Failed to start chat with agent',
       );
     }
   }
 }

 void _setDefaultModel() {
 try {
   final currentModel = ref.read(selectedModelProvider);
   final modelConfig = ref.read(modelConfigServiceProvider);
   final allModels = modelConfig.allModelConfigs.values.toList();

   debugPrint('🔍 _setDefaultModel called - current model: ${currentModel?.name ?? "null"}');
   debugPrint('📋 Available models (${allModels.length} total):');
   for (final model in allModels) {
     debugPrint('  • ${model.name} (ID: ${model.id}, Ollama: ${model.ollamaModelId}, Local: ${model.isLocal})');
   }

   // Check if we should change the model:
   // 1. No model is set, OR
   // 2. Current model is not Llama3.2 and Llama3.2 is available
   bool shouldSetLlama = false;
   if (currentModel == null) {
     debugPrint('ℹ️ No model currently set');
     shouldSetLlama = true;
   } else {
     final isLlama32 = currentModel.name.toLowerCase().contains('llama3.2') ||
                       currentModel.ollamaModelId?.toLowerCase().contains('llama3.2') == true;
     if (!isLlama32) {
       debugPrint('ℹ️ Current model is not Llama3.2, will try to switch');
       shouldSetLlama = true;
     } else {
       debugPrint('✅ Current model is already Llama3.2: ${currentModel.name}');
       return;
     }
   }

   if (shouldSetLlama) {
     // Try to find Llama3.2 model (case-insensitive search)
     ModelConfig? llamaModel;
     try {
       llamaModel = allModels.firstWhere(
         (model) {
           final nameMatch = model.name.toLowerCase().contains('llama3.2');
           final ollamaMatch = model.ollamaModelId?.toLowerCase().contains('llama3.2') == true;
           debugPrint('  🔎 Checking ${model.name}: nameMatch=$nameMatch, ollamaMatch=$ollamaMatch');
           return nameMatch || ollamaMatch;
         },
       );
       debugPrint('✅ Found Llama3.2 model: ${llamaModel.name}');

       // Set the model after the build cycle completes (Riverpod requirement)
       Future.microtask(() {
         if (mounted && llamaModel != null) {
           ref.read(selectedModelProvider.notifier).state = llamaModel;
           debugPrint('✅ Set default model to: ${llamaModel.name} (ID: ${llamaModel.id})');
         }
       });
     } catch (e) {
       debugPrint('⚠️ Llama3.2 not found in available models');
       if (currentModel == null && allModels.isNotEmpty) {
         debugPrint('⚠️ Falling back to first available model: ${allModels.first.name}');
         ref.read(selectedModelProvider.notifier).state = allModels.first;
       }
     }
   }
 } catch (e) {
   debugPrint('❌ Could not set default model: $e');
 }
 }

 Future<void> _startModelWarmUpInBackground() async {
 try {
   print('🔥 Starting model warm-up for chat screen...');
   final warmUpService = ref.read(modelWarmUpServiceProvider);
   // Run warmup in background without blocking UI
   unawaited(warmUpService.warmUpAllModels());
   print('✅ Model warm-up started in background');
 } catch (e) {
   print('❌ Model warm-up failed: $e');
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

 // Main Content - Minimal chat UI (no sidebars)
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

 /// Build the chat title with optional agent indicator
 Widget _buildChatTitle(ThemeData theme, ThemeColors colors) {
   // Check if we have an active agent
   final agentId = widget.agentId;

   if (agentId == null) {
     // No agent - just show "Chat"
     return Text(
       'Chat',
       style: GoogleFonts.fustat(
         fontWeight: FontWeight.w600,
         fontSize: 16,
         color: theme.colorScheme.onSurface,
       ),
     );
   }

   // We have an agent - show agent indicator
   final agentsAsync = ref.watch(agentsProvider);

   return agentsAsync.when(
     loading: () => Text(
       'Chat',
       style: GoogleFonts.fustat(
         fontWeight: FontWeight.w600,
         fontSize: 16,
         color: theme.colorScheme.onSurface,
       ),
     ),
     error: (_, __) => Text(
       'Chat',
       style: GoogleFonts.fustat(
         fontWeight: FontWeight.w600,
         fontSize: 16,
         color: theme.colorScheme.onSurface,
       ),
     ),
     data: (agents) {
       final agent = agents.where((a) => a.id == agentId).firstOrNull;

       if (agent == null) {
         return Text(
           'Chat',
           style: GoogleFonts.fustat(
             fontWeight: FontWeight.w600,
             fontSize: 16,
             color: theme.colorScheme.onSurface,
           ),
         );
       }

       // Show agent name with indicator
       return Row(
         mainAxisSize: MainAxisSize.min,
         children: [
           Container(
             padding: const EdgeInsets.symmetric(
               horizontal: SpacingTokens.sm,
               vertical: SpacingTokens.xxs,
             ),
             decoration: BoxDecoration(
               color: colors.primary.withValues(alpha: 0.15),
               borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
               border: Border.all(
                 color: colors.primary.withValues(alpha: 0.3),
               ),
             ),
             child: Row(
               mainAxisSize: MainAxisSize.min,
               children: [
                 Icon(
                   Icons.smart_toy,
                   size: 14,
                   color: colors.primary,
                 ),
                 const SizedBox(width: SpacingTokens.xs),
                 Text(
                   agent.name,
                   style: GoogleFonts.fustat(
                     fontWeight: FontWeight.w600,
                     fontSize: 14,
                     color: colors.primary,
                   ),
                 ),
               ],
             ),
           ),
           const SizedBox(width: SpacingTokens.sm),
           // Clear agent button
           InkWell(
             onTap: () => context.go(AppRoutes.chat),
             borderRadius: BorderRadius.circular(BorderRadiusTokens.xs),
             child: Padding(
               padding: const EdgeInsets.all(4),
               child: Icon(
                 Icons.close,
                 size: 14,
                 color: colors.onSurfaceVariant,
               ),
             ),
           ),
         ],
       );
     },
   );
 }

 Widget _buildChatHeader(ThemeData theme) {
 final selectedConversationId = ref.watch(selectedConversationIdProvider);
 final colors = ThemeColors(context);

 // No conversation selected - show simple header
 if (selectedConversationId == null) {
   return Container(
     padding: const EdgeInsets.all(SpacingTokens.elementSpacing),
     decoration: BoxDecoration(
       border: Border(
         bottom: BorderSide(
           color: theme.colorScheme.outline.withValues(alpha: 0.2),
           width: 1,
         ),
       ),
     ),
     child: Row(
       children: [
         Text(
           'Chat',
           style: GoogleFonts.fustat(
             fontSize: 16,
             fontWeight: FontWeight.w600,
             color: colors.onSurface,
           ),
         ),
         const Spacer(),
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
 padding: const EdgeInsets.all(SpacingTokens.elementSpacing),
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
 final colors = ThemeColors(context);
 final hasConversation = ref.watch(selectedConversationIdProvider) != null;

 // Desktop OS-style interface with centered, window-like content
 return Container(
 decoration: BoxDecoration(
 // Desktop wallpaper-like gradient background
 gradient: RadialGradient(
 center: Alignment.topCenter,
 radius: 2.0,
 colors: [
 colors.backgroundGradientStart.withValues(alpha: 0.95),
 colors.backgroundGradientMiddle.withValues(alpha: 0.98),
 colors.backgroundGradientEnd,
 ],
 stops: const [0.0, 0.5, 1.0],
 ),
 ),
 child: Stack(
 children: [
   Column(
     children: [
       // Minimal header (model selector only)
       _buildChatHeader(theme),

       // Main desktop workspace - centered content area
       Expanded(
         child: Center(
           child: Container(
             constraints: const BoxConstraints(maxWidth: 1200),
             padding: const EdgeInsets.all(SpacingTokens.xxl),
             child: hasConversation
                 ? _buildConversationWindow(context)
                 : _buildWelcomeDesktop(context),
           ),
         ),
       ),
     ],
   ),

   // Artifact workspace for interactive artifact windows
   const ArtifactWorkspace(),

   // Note: Floating dock removed - replaced by ChatTabBar + ChatStatusBar at top
   ],
   ),
 );

 /* Commented out old input area - now using ContextualInputArea
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
 */
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

 Text(
 'Ready to chat',
 style: GoogleFonts.fustat(
  fontWeight: FontWeight.w600,
  fontSize: 20,
 color: theme.colorScheme.onSurface,
 ),
 ),

 const SizedBox(height: SpacingTokens.componentSpacing),

 Text(
 'Start typing in the input below to begin your conversation.',
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

 /// Loading state shown while initializing an agent chat session
 Widget _buildAgentInitializingState(BuildContext context) {
   final colors = ThemeColors(context);

   return Center(
     child: Container(
       constraints: const BoxConstraints(maxWidth: 400),
       padding: const EdgeInsets.all(SpacingTokens.xxl),
       child: Column(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
           // Animated loading icon
           Container(
             width: 80,
             height: 80,
             decoration: BoxDecoration(
               gradient: LinearGradient(
                 begin: Alignment.topLeft,
                 end: Alignment.bottomRight,
                 colors: [
                   colors.primary.withValues(alpha: 0.15),
                   colors.accent.withValues(alpha: 0.15),
                 ],
               ),
               borderRadius: BorderRadius.circular(20),
             ),
             child: Center(
               child: SizedBox(
                 width: 32,
                 height: 32,
                 child: CircularProgressIndicator(
                   strokeWidth: 3,
                   valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                 ),
               ),
             ),
           ),

           const SizedBox(height: SpacingTokens.xl),

           Text(
             'Starting Agent...',
             style: GoogleFonts.fustat(
               fontWeight: FontWeight.w600,
               fontSize: 20,
               color: colors.onSurface,
             ),
           ),

           const SizedBox(height: SpacingTokens.md),

           Text(
             'Preparing your chat session',
             style: GoogleFonts.fustat(
               color: colors.onSurfaceVariant,
               height: 1.5,
             ),
             textAlign: TextAlign.center,
           ),
         ],
       ),
     ),
   );
 }

 /// Simple "ready to chat" state for when a conversation is already open but has no messages
 /// This is different from _buildEmptyConversationState which shows the full type selector
 Widget _buildReadyToChatState(BuildContext context) {
   final colors = ThemeColors(context);
   final selectedModel = ref.watch(selectedModelProvider);

   return Center(
     child: Container(
       constraints: const BoxConstraints(maxWidth: 500),
       padding: const EdgeInsets.all(SpacingTokens.xxl),
       child: Column(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
           // Icon with gradient background
           Container(
             width: 80,
             height: 80,
             decoration: BoxDecoration(
               gradient: LinearGradient(
                 begin: Alignment.topLeft,
                 end: Alignment.bottomRight,
                 colors: [
                   colors.primary.withValues(alpha: 0.15),
                   colors.accent.withValues(alpha: 0.15),
                 ],
               ),
               borderRadius: BorderRadius.circular(20),
             ),
             child: Icon(
               Icons.chat_bubble_outline,
               size: 40,
               color: colors.primary,
             ),
           ),

           const SizedBox(height: SpacingTokens.xl),

           Text(
             'Ready to Chat',
             style: GoogleFonts.fustat(
               fontWeight: FontWeight.w600,
               fontSize: 24,
               color: colors.onSurface,
             ),
           ),

           const SizedBox(height: SpacingTokens.md),

           // Show the current model
           if (selectedModel != null)
             Container(
               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
               decoration: BoxDecoration(
                 color: selectedModel.isLocal
                     ? colors.success.withValues(alpha: 0.1)
                     : colors.accent.withValues(alpha: 0.1),
                 borderRadius: BorderRadius.circular(20),
                 border: Border.all(
                   color: selectedModel.isLocal
                       ? colors.success.withValues(alpha: 0.3)
                       : colors.accent.withValues(alpha: 0.3),
                 ),
               ),
               child: Row(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   Container(
                     width: 8,
                     height: 8,
                     decoration: BoxDecoration(
                       color: selectedModel.isLocal ? colors.success : colors.accent,
                       shape: BoxShape.circle,
                     ),
                   ),
                   const SizedBox(width: 8),
                   Text(
                     selectedModel.name,
                     style: GoogleFonts.fustat(
                       fontSize: 14,
                       fontWeight: FontWeight.w500,
                       color: selectedModel.isLocal ? colors.success : colors.accent,
                     ),
                   ),
                   if (selectedModel.isLocal) ...[
                     const SizedBox(width: 8),
                     Text(
                       'Local',
                       style: GoogleFonts.fustat(
                         fontSize: 12,
                         color: colors.success,
                       ),
                     ),
                   ],
                 ],
               ),
             ),

           const SizedBox(height: SpacingTokens.lg),

           Text(
             'Type your message below to start the conversation',
             style: GoogleFonts.fustat(
               color: colors.onSurfaceVariant,
               fontSize: 14,
               height: 1.5,
             ),
             textAlign: TextAlign.center,
           ),

           const SizedBox(height: SpacingTokens.md),

           // Keyboard shortcut hint
           Row(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               Icon(Icons.keyboard, size: 14, color: colors.onSurfaceVariant.withValues(alpha: 0.5)),
               const SizedBox(width: 6),
               Text(
                 'Shift+Enter to send',
                 style: GoogleFonts.fustat(
                   fontSize: 12,
                   color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                 ),
               ),
             ],
           ),
         ],
       ),
     ),
   );
 }

 /// Desktop-style conversation window with frosted glass effect
 Widget _buildConversationWindow(BuildContext context) {
 final colors = ThemeColors(context);

 return Container(
 decoration: BoxDecoration(
 color: colors.surface.withValues(alpha: 0.7),
 borderRadius: BorderRadius.circular(16),
 border: Border.all(
 color: colors.border.withValues(alpha: 0.2),
 width: 1,
 ),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withValues(alpha: 0.1),
 blurRadius: 24,
 offset: const Offset(0, 8),
 spreadRadius: 0,
 ),
 ],
 ),
 child: ClipRRect(
 borderRadius: BorderRadius.circular(16),
 child: BackdropFilter(
 filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
 child: Column(
 children: [
 // Messages area
 Expanded(
 child: _buildMessagesArea(context),
 ),

 // Input area at bottom
 _buildContextualInput(),
 ],
 ),
 ),
 ),
 );
 }


 /// Welcome screen for desktop - shown when no conversation
 Widget _buildWelcomeDesktop(BuildContext context) {
   // Use the same ConversationStarter as the empty state
   return _buildEmptyConversationState(context);
 }

 Widget _buildMessagesArea(BuildContext context) {
 final selectedConversationId = ref.watch(selectedConversationIdProvider);
 
 // Show loading state while initializing agent chat
 if (_isInitializingAgentChat && selectedConversationId == null) {
   return _buildAgentInitializingState(context);
 }

 if (selectedConversationId == null) {
   return _buildEmptyState(context);
 }

 return _buildMessagesList(context, selectedConversationId);
 }
 
 Widget _buildMessagesList(BuildContext context, String conversationId) {
 final messagesAsync = ref.watch(messagesProvider(conversationId));

 return messagesAsync.when(
 data: (messages) {
 if (messages.isEmpty) {
 // Conversation is already selected - show simple "ready to chat" state
 // not the full conversation type selector
 return _buildReadyToChatState(context);
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
 margin: const EdgeInsets.only(
                    top: SpacingTokens.lg,
                    bottom: SpacingTokens.lg,
                    left: SpacingTokens.md,
                    right: SpacingTokens.md,
                  ),
 child: const StreamingMessageWidget(
 messageId: 'streaming-temp',
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
 margin: const EdgeInsets.only(
                    top: SpacingTokens.lg,
                    bottom: SpacingTokens.lg,
                    left: SpacingTokens.md,
                    right: SpacingTokens.md,
                  ),
 child: StreamingMessageWidget(
 messageId: message.id,
 role: 'assistant',
 ),
 );
 }

 // Standard message display for simple messages
 return Container(
 margin: const EdgeInsets.only(
                    top: SpacingTokens.lg,
                    bottom: SpacingTokens.lg,
                    left: SpacingTokens.md,
                    right: SpacingTokens.md,
                  ),
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

 /// Create a new direct chat conversation with the selected model
 Future<void> _startNewDirectChat() async {
   try {
     // Get the selected model (default if none selected)
     final selectedModel = ref.read(selectedModelProvider) ?? ref.read(defaultModelConfigProvider);
     
     if (selectedModel == null) {
       // Show error if no model is configured
       FloatingNotification.warning(
        context,
        'Please configure at least one AI model in Settings',
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
     FloatingNotification.error(
       context,
       'Failed to start new chat: $e',
     );
   }
 }

 /// Handle conversation start from ConversationStarter widget
 Future<void> _handleConversationStart(ModelConfig model, ConversationType type) async {
   try {
     // Set the selected model
     ref.read(selectedModelProvider.notifier).state = model;

     // Create new conversation with type metadata
     final businessService = ref.read(conversationBusinessServiceProvider);
     final result = await businessService.createConversation(
       title: 'Chat with ${model.name}',
       agentId: null,
       metadata: {
         'type': type.name,
         'modelId': model.id,
         'modelName': model.name,
       },
     );

     if (!result.isSuccess || result.data == null) {
       throw Exception(result.error ?? 'Failed to create conversation');
     }

     final conversationId = result.data!.id;

     // Set as active conversation
     ref.read(selectedConversationIdProvider.notifier).state = conversationId;
     ref.read(activeConversationTabProvider.notifier).state = conversationId;
     ref.read(openConversationTabsProvider.notifier).openTab(conversationId);

     debugPrint('✅ Started ${type.name} conversation with ${model.name}');
   } catch (e) {
     FloatingNotification.error(
       context,
       'Failed to start conversation: $e',
     );
   }
 }

 void _sendMessage() async {
 if (messageController.text.trim().isEmpty || ref.read(isLoadingProvider)) {
   return;
 }

 var selectedConversationId = ref.read(selectedConversationIdProvider);

 // If no conversation is selected, create a new one automatically
 if (selectedConversationId == null) {
   debugPrint('📝 No conversation selected, creating new chat automatically...');
   final selectedModel = ref.read(selectedModelProvider) ?? ref.read(defaultModelConfigProvider);

   if (selectedModel == null) {
     FloatingNotification.warning(
       context,
       'Please configure at least one AI model in Settings',
     );
     return;
   }

   try {
     // Create a new direct conversation
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
         'created_from': 'auto_on_send',
         'type': 'direct',
       },
     );

     await conversationService.createConversation(newConversation);
     ref.invalidate(conversationsProvider);
     ref.read(selectedConversationIdProvider.notifier).state = newConversation.id;
     selectedConversationId = newConversation.id;

     debugPrint('✅ Auto-created conversation: ${newConversation.id}');
   } catch (e) {
     FloatingNotification.error(
       context,
       'Failed to create conversation: $e',
     );
     return;
   }
 }

 try {
 ref.read(isLoadingProvider.notifier).state = true;

 // Note: Conversation priming is handled by business service during creation
 // Removed ensureConversationPrimedProvider call to prevent widget disposal issues

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

 // Check if DSPy mode is enabled (default: true)
 final useDspy = ref.read(dspyModeEnabledProvider);

 if (useDspy) {
   // Use DSPy backend for all AI responses (recommended)
   debugPrint('🧠 Using DSPy backend for response...');
   await _handleDspyResponse(selectedConversationId, messageContent);
 } else if (isAgentConversation) {
   // Legacy: Simple direct response for agent conversations
   await _handleAgentDirectResponse(selectedConversationId, messageContent, conversation);
 } else {
   // Legacy: Standard API response for non-agent conversations
   await _handleStandardResponse(selectedConversationId);
 }

 } catch (e) {
 if (mounted) {
 FloatingNotification.error(
 context,
 'Failed to send message: $e',
 );
 }
 } finally {
 ref.read(isLoadingProvider.notifier).state = false;
 }
 }

 Future<void> _handleAgentDirectResponse(String conversationId, String userMessage, core.Conversation conversation) async {
  // For now, just use the same logic as standard response
  // The agent's system prompt is already stored in the conversation metadata
  // and will be used by the LLM service automatically
  await _handleStandardResponse(conversationId);
}

/// Handle response using DSPy backend
/// This is the new unified AI backend that replaces 50+ fragmented services
Future<void> _handleDspyResponse(String conversationId, String userMessage) async {
  try {
    // Check if DSPy backend is connected
    final dspyService = ref.read(dspyServiceProvider);
    final isConnected = ref.read(dspyIsConnectedProvider);

    if (!isConnected) {
      // Try to connect
      final connected = await dspyService.connect();
      if (!connected) {
        throw Exception('DSPy backend is not running. Please start it with: cd dspy-backend && ./run.sh');
      }
    }

    // Use DSPy conversation service for AI response
    final dspyConversation = ref.read(dspyConversationServiceProvider);

    final response = await dspyConversation.processMessage(
      conversationId: conversationId,
      content: userMessage,
    );

    // The DSPy conversation service handles saving messages,
    // just refresh the UI
    ref.invalidate(messagesProvider(conversationId));

    debugPrint('✅ DSPy response received: ${response.content.substring(0, response.content.length.clamp(0, 100))}...');

  } catch (e) {
    debugPrint('❌ DSPy response failed: $e');
    rethrow;
  }
}

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
//  print('DEBUG: MCP response content: "${response.response}"');
//  print('DEBUG: MCP response length: ${response.response.length}');
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
 final selectedModel = ref.read(conversationModelProvider(conversationId)) 
     ?? ref.read(selectedModelProvider);

 // Check if model is configured - different logic for local vs API models
 print('DEBUG: Selected model: ${selectedModel?.name}, isLocal: ${selectedModel?.isLocal}, isConfigured: ${selectedModel?.isConfigured}, status: ${selectedModel?.status}');
 
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
       FloatingNotification.error(
         context,
         'Local model "${selectedModel.name}" is not ready. Status: ${selectedModel.status}.\n\nTo fix:\n1. Install Ollama from ollama.ai\n2. Run: ollama pull ${selectedModel.ollamaModelId ?? selectedModel.name.toLowerCase()}',
         duration: const Duration(seconds: 6),
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

 // Get conversation details to check for enhanced context and MCP integration
 final conversation = await ref.read(conversationProvider(conversationId).future);
 
 // Enhanced system prompt with context integration for non-agent conversations
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

  //  // For non-agent conversations with global MCP servers, try to use MCP bridge
  //  if (globalMcpServers.isNotEmpty) {
  //    print('🔗 Standard conversation using global MCP servers: $globalMcpServers');
  //    try {
  //      final mcpBridge = MCPBridgeService(mcpService);
  //      final mcpResponse = await mcpBridge.processMessage(
  //        conversationId: conversationId,
  //        message: userMessage,
  //        enabledServerIds: globalMcpServers,
  //        conversationMetadata: {
  //          ...conversation.metadata ?? {},
  //          'mcpServers': globalMcpServers.map((id) => {'id': id}).toList(),
  //          'contextDocuments': globalContextDocs,
  //          'type': 'standard_with_mcp',
  //        },
  //      );
  //      
  //      // Create assistant message with MCP response
  //      final assistantMessage = core.Message(
  //        id: DateTime.now().millisecondsSinceEpoch.toString(),
  //        content: mcpResponse.response,
  //        role: core.MessageRole.assistant,
  //        timestamp: DateTime.now(),
  //        metadata: {
  //          'modelUsed': selectedModel.id,
  //          'responseType': 'mcp_enhanced',
  //          'mcpServersUsed': globalMcpServers,
  //          'mcpServersActuallyUsed': mcpResponse.usedServers,
  //          'hasGlobalContext': globalContextDocs.isNotEmpty,
  //          'mcpLatency': mcpResponse.latency,
  //          'mcpMetadata': mcpResponse.metadata,
  //        },
  //      );
  //      
  //      await service.addMessage(conversationId, assistantMessage);
  //      
  //      // Update conversation priming status to success since message worked
  //      await _updateConversationPrimingAfterSuccess(conversationId, selectedModel);
  //      
  //      ref.invalidate(messagesProvider(conversationId));
  //      return;
  //      
  //    } catch (mcpError) {
  //      print('⚠️ MCP processing failed for standard conversation, falling back to direct LLM: $mcpError');
  //      // Fall through to direct LLM call
  //    }
  //  }

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
   final modelConfigService = ref.watch(modelConfigServiceProvider);
   final availableModels = modelConfigService.allModelConfigs.values
       .where((m) => m.status == ModelStatus.ready)
       .toList();
   final selectedModel = ref.watch(selectedModelProvider);

   return ConversationStarter(
     availableModels: availableModels,
     selectedModel: selectedModel,
     onStart: (model, type) => _handleConversationStart(model, type),
     onAgentSelect: () => context.go(AppRoutes.agents),
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

 // For non-agent conversations, show the currently selected model
 final selectedModel = ref.watch(selectedModelProvider);
 if (selectedModel != null) {
 return 'Chat with ${selectedModel.name}';
 }

 // Fallback if no model selected
 return 'Chat Session';
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
   print('Failed to update priming status after success: $e');
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

  /// Create a new chat conversation with a specific model
  Future<void> _startNewChatWithModel(ModelConfig model) async {
    try {
      // Show feedback about creating new chat with selected model
      if (mounted) {
        FloatingNotification.info(
          context,
          'Starting new chat with ${model.name}',
          duration: const Duration(seconds: 2),
        );
      }

      // Create a new direct conversation with the specific model
      final conversationService = ref.read(conversationServiceProvider);
      final newConversation = core.Conversation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Chat with ${model.name}',
        messages: [],
        createdAt: DateTime.now(),
        lastModified: DateTime.now(),
        metadata: {
          'model_id': model.id,
          'model_name': model.name,
          'model_type': model.isLocal ? 'local' : 'api',
          'model_provider': model.provider,
          'created_from': 'model_switch',
          'type': 'direct', // Mark as direct conversation (not agent-based)
        },
      );

      // Save the conversation
      await conversationService.createConversation(newConversation);

      // Refresh the conversations list to show the new conversation
      ref.invalidate(conversationsProvider);

      // Select the new conversation to enable chatting
      ref.read(selectedConversationIdProvider.notifier).state = newConversation.id;

      // Update the global selected model to match the new conversation
      ref.read(selectedModelProvider.notifier).state = model;

    } catch (e) {
      // Show error message if conversation creation fails
      if (mounted) {
        FloatingNotification.error(
          context,
          'Failed to start new chat with ${model.name}: $e',
          duration: const Duration(seconds: 3),
        );
      }
    }
  }
}



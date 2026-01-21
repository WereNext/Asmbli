import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_engine_core/models/conversation.dart';
import 'package:agent_engine_core/models/agent.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../providers/conversation_provider.dart';
import '../../../../providers/agent_provider.dart';
import 'loading_overlay.dart';

class ConversationList extends ConsumerWidget {
 const ConversationList({super.key});

 @override
 Widget build(BuildContext context, WidgetRef ref) {
 final conversationsAsync = ref.watch(conversationsProvider);
 final selectedConversationId = ref.watch(selectedConversationIdProvider);
 
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.lg),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const SizedBox(height: SpacingTokens.lg),
 Row(
 children: [
 Icon(
 Icons.chat_bubble_outline,
 size: 16,
 color: ThemeColors(context).onSurface,
 ),
 const SizedBox(width: SpacingTokens.iconSpacing),
 Text(
 'All Conversations',
 style: TextStyles.bodyMedium.copyWith(
 color: ThemeColors(context).onSurface,
 fontWeight: FontWeight.w600,
 fontSize: 14,
 ),
 ),
 ],
 ),
 const SizedBox(height: SpacingTokens.lg),
 Expanded(
 child: conversationsAsync.when(
 data: (conversations) {
 if (conversations.isEmpty) {
 return _buildEmptyState(context);
 }
 
 return ListView.builder(
 itemCount: conversations.length,
 itemBuilder: (context, index) {
 final conversation = conversations[index];
 final isSelected = conversation.id == selectedConversationId;
 
 return _ConversationItem(
 conversation: conversation,
 isSelected: isSelected,
 onTap: () {
 ref.read(selectedConversationIdProvider.notifier).state = conversation.id;
 },
 onArchive: () => _archiveConversation(ref, conversation.id),
 onDelete: () => _deleteConversation(context, ref, conversation),
 );
 },
 );
 },
 loading: () => _buildLoadingState(context),
 error: (error, stack) => _buildErrorState(context, error.toString(), ref),
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildEmptyState(BuildContext context) {
 return Consumer(
 builder: (context, ref, _) {
 return _buildEmptyStateContent(context, ref);
 },
 );
 }

 Widget _buildEmptyStateContent(BuildContext context, WidgetRef ref) {
 return Center(
 child: Column(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 Container(
 width: 80,
 height: 80,
 decoration: BoxDecoration(
 color: ThemeColors(context).primary.withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(40),
 border: Border.all(color: ThemeColors(context).primary.withValues(alpha: 0.2)),
 ),
 child: Icon(
 Icons.chat_bubble_outline,
 size: 40,
 color: ThemeColors(context).primary,
 ),
 ),
 const SizedBox(height: SpacingTokens.xl),
 Text(
 'Start Your First Conversation',
 style: TextStyles.bodyMedium.copyWith(
 color: ThemeColors(context).onSurface,
 fontWeight: FontWeight.w600,
 fontSize: 16,
 ),
 ),
 const SizedBox(height: SpacingTokens.sm),
 Text(
 'Chat directly with AI or organize\nconversations with topics later',
 style: TextStyles.bodySmall.copyWith(
 color: ThemeColors(context).onSurfaceVariant,
 height: 1.5,
 ),
 textAlign: TextAlign.center,
 ),
 const SizedBox(height: SpacingTokens.xl),
 AsmblButton.primary(
 text: 'Start New Chat',
 icon: Icons.add_comment,
 onPressed: () => _createNewConversation(ref),
 ),
 ],
 ),
 );
 }

 Widget _buildLoadingState(BuildContext context) {
 return Center(
 child: Column(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 CircularProgressIndicator(
 color: ThemeColors(context).primary,
 strokeWidth: 2,
 ),
 const SizedBox(height: SpacingTokens.lg),
 Text(
 'Loading conversations...',
 style: TextStyle(
 
 color: ThemeColors(context).onSurfaceVariant,
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildErrorState(BuildContext context, String error, WidgetRef ref) {
 return Center(
 child: ErrorMessage(
 message: 'Failed to load conversations: $error',
 onRetry: () {
 ref.invalidate(conversationsProvider);
 },
 ),
 );
 }

 void _createNewConversation(WidgetRef ref) async {
 try {
 ref.read(isLoadingProvider.notifier).state = true;
 
 final createConversation = ref.read(createConversationProvider);
 final conversation = await createConversation(
 title: 'New Conversation - ${DateTime.now().toString().substring(0, 16)}',
 );
 
 ref.read(selectedConversationIdProvider.notifier).state = conversation.id;
 ref.invalidate(conversationsProvider);
 } catch (e) {
 // Handle error
 } finally {
 ref.read(isLoadingProvider.notifier).state = false;
 }
 }

 void _archiveConversation(WidgetRef ref, String conversationId) async {
 try {
 final archiveConversation = ref.read(archiveConversationProvider);
 await archiveConversation(conversationId, true); // true = archive
 
 // Clear selection if archiving selected conversation
 final selectedId = ref.read(selectedConversationIdProvider);
 if (selectedId == conversationId) {
 ref.read(selectedConversationIdProvider.notifier).state = null;
 }
 } catch (e) {
 // Handle error
 }
 }

 void _deleteConversation(BuildContext context, WidgetRef ref, Conversation conversation) async {
 // Show confirmation dialog
 final confirmed = await showDialog<bool>(
 context: context,
 builder: (context) => AlertDialog(
 backgroundColor: ThemeColors(context).surface,
 title: Text(
 'Delete Conversation',
 style: TextStyles.bodyLarge.copyWith(
 color: ThemeColors(context).onSurface,
 fontWeight: FontWeight.w600,
 ),
 ),
 content: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Are you sure you want to delete this conversation?',
 style: TextStyles.bodyMedium.copyWith(
 color: ThemeColors(context).onSurface,
 ),
 ),
 const SizedBox(height: SpacingTokens.sm),
 Text(
 '"${conversation.title}"',
 style: TextStyles.bodyMedium.copyWith(
 color: ThemeColors(context).onSurfaceVariant,
 fontStyle: FontStyle.italic,
 ),
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 ),
 const SizedBox(height: SpacingTokens.md),
 Container(
 padding: const EdgeInsets.all(SpacingTokens.sm),
 decoration: BoxDecoration(
 color: ThemeColors(context).error.withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
 border: Border.all(color: ThemeColors(context).error.withValues(alpha: 0.3)),
 ),
 child: Row(
 children: [
 Icon(
 Icons.warning_amber_rounded,
 size: 16,
 color: ThemeColors(context).error,
 ),
 const SizedBox(width: SpacingTokens.sm),
 Expanded(
 child: Text(
 'This action cannot be undone.',
 style: TextStyles.bodySmall.copyWith(
 color: ThemeColors(context).error,
 fontWeight: FontWeight.w500,
 ),
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 actions: [
 AsmblButton.secondary(
 text: 'Cancel',
 onPressed: () => Navigator.of(context).pop(false),
 ),
 AsmblButton.destructive(
 text: 'Delete',
 onPressed: () => Navigator.of(context).pop(true),
 ),
 ],
 ),
 );

 if (confirmed == true) {
 try {
 final deleteConversation = ref.read(deleteConversationProvider);
 await deleteConversation(conversation.id);
 } catch (e) {
 // Handle error
 }
 }
 }
}

class _ConversationItem extends ConsumerStatefulWidget {
 final Conversation conversation;
 final bool isSelected;
 final VoidCallback onTap;
 final VoidCallback onArchive;
 final VoidCallback onDelete;

 const _ConversationItem({
 required this.conversation,
 required this.isSelected,
 required this.onTap,
 required this.onArchive,
 required this.onDelete,
 });

 @override
 ConsumerState<_ConversationItem> createState() => _ConversationItemState();
}

class _ConversationItemState extends ConsumerState<_ConversationItem> {
 bool _isHovered = false;

 @override
 Widget build(BuildContext context) {
 return Container(
 margin: const EdgeInsets.only(bottom: SpacingTokens.sm),
 child: MouseRegion(
 onEnter: (_) => setState(() => _isHovered = true),
 onExit: (_) => setState(() => _isHovered = false),
 child: Material(
 color: Colors.transparent,
 child: InkWell(
 onTap: widget.onTap,
 onLongPress: () => _showContextMenu(context),
 borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
 hoverColor: ThemeColors(context).primary.withValues(alpha: 0.04),
 splashColor: ThemeColors(context).primary.withValues(alpha: 0.12),
 child: Container(
 padding: const EdgeInsets.all(SpacingTokens.md),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
 border: widget.isSelected
 ? Border.all(color: ThemeColors(context).primary, width: 2)
 : Border.all(color: ThemeColors(context).border),
 color: widget.isSelected
 ? ThemeColors(context).primary.withValues(alpha: 0.05)
 : ThemeColors(context).surface.withValues(alpha: 0.5),
 ),
 child: Stack(
 children: [
 _buildConversationContent(context, ref),
 // Delete button on hover
 if (_isHovered)
 Positioned(
 top: 0,
 right: 0,
 child: GestureDetector(
 onTap: widget.onDelete,
 child: Container(
 padding: const EdgeInsets.all(4),
 decoration: BoxDecoration(
 color: ThemeColors(context).error.withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
 ),
 child: Icon(
 Icons.close,
 size: 14,
 color: ThemeColors(context).error,
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
 );
 }

 Widget _buildConversationContent(BuildContext context, WidgetRef ref) {
 final agentId = widget.conversation.metadata?['agentId'] as String?;
 
 if (agentId != null) {
 return _buildAgentConversationCard(context, ref, agentId);
 } else {
 return _buildStandardConversationCard(context);
 }
 }
 
 Widget _buildAgentConversationCard(BuildContext context, WidgetRef ref, String agentId) {
 final agentsAsync = ref.watch(agentNotifierProvider);
 
 return agentsAsync.when(
 loading: () => _buildStandardConversationCard(context),
 error: (_, __) => _buildStandardConversationCard(context),
 data: (agents) {
 final agent = agents.firstWhere(
 (a) => a.id == agentId,
 orElse: () => Agent(
 id: agentId,
 name: agentId,
 description: 'Unknown agent',
 capabilities: [],
 ),
 );
 
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Agent Header
 Row(
 children: [
 Container(
 width: 32,
 height: 32,
 decoration: BoxDecoration(
 color: _getAgentColor(agent, context).withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
 border: Border.all(
 color: _getAgentColor(agent, context).withValues(alpha: 0.3),
 width: 1,
 ),
 ),
 child: Icon(
 _getAgentIcon(agent),
 size: 16,
 color: _getAgentColor(agent, context),
 ),
 ),
 const SizedBox(width: SpacingTokens.sm),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
 decoration: BoxDecoration(
 color: _getAgentColor(agent, context),
 borderRadius: BorderRadius.circular(4),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 const Icon(
 Icons.smart_toy,
 size: 8,
 color: Colors.white,
 ),
 const SizedBox(width: 2),
 Text(
 'AGENT',
 style: TextStyles.caption.copyWith(
 color: Colors.white,
 fontSize: 8,
 fontWeight: FontWeight.w600,
 ),
 ),
 ],
 ),
 ),
 const Spacer(),
 if (agent.status == AgentStatus.active) ...[
 Container(
 width: 8,
 height: 8,
 decoration: BoxDecoration(
 color: ThemeColors(context).success,
 borderRadius: BorderRadius.circular(4),
 ),
 ),
 ],
 ],
 ),
 Text(
 agent.name,
 style: TextStyles.bodyMedium.copyWith(
 fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
 color: widget.isSelected
 ? ThemeColors(context).primary
 : ThemeColors(context).onSurface,
 ),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 ],
 ),
 ),
 ],
 ),

 const SizedBox(height: SpacingTokens.xs),

 // Conversation Title (if different from agent name)
 if (widget.conversation.title != agent.name && widget.conversation.title.isNotEmpty) ...[
 Text(
 widget.conversation.title,
 style: TextStyles.bodySmall.copyWith(
 color: ThemeColors(context).onSurfaceVariant,
 fontStyle: FontStyle.italic,
 ),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 const SizedBox(height: SpacingTokens.xs),
 ],
 
 // Agent capabilities (show top 2)
 if (agent.capabilities.isNotEmpty) ...[
 Row(
 children: [
 ...agent.capabilities.take(2).map((capability) => Container(
 margin: const EdgeInsets.only(right: 4),
 padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
 decoration: BoxDecoration(
 color: _getAgentColor(agent, context).withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
 ),
 child: Text(
 capability,
 style: TextStyles.caption.copyWith(
 color: _getAgentColor(agent, context),
 fontSize: 9,
 ),
 ),
 )),
 if (agent.capabilities.length > 2) ...[
 Text(
 '+${agent.capabilities.length - 2}',
 style: TextStyles.caption.copyWith(
 color: ThemeColors(context).onSurfaceVariant,
 fontSize: 9,
 ),
 ),
 ],
 const Spacer(),
 Text(
 _formatDate(widget.conversation.createdAt),
 style: TextStyles.caption.copyWith(
 color: ThemeColors(context).onSurfaceVariant,
 ),
 ),
 ],
 ),
 ] else ...[
 // Fallback info row
 Row(
 children: [
 Icon(
 Icons.message,
 size: 12,
 color: ThemeColors(context).onSurfaceVariant,
 ),
 const SizedBox(width: SpacingTokens.xs),
 Text(
 '${widget.conversation.messages.length} messages',
 style: TextStyles.caption.copyWith(
 color: ThemeColors(context).onSurfaceVariant,
 ),
 ),
 const Spacer(),
 Text(
 _formatDate(widget.conversation.createdAt),
 style: TextStyles.caption.copyWith(
 color: ThemeColors(context).onSurfaceVariant,
 ),
 ),
 ],
 ),
 ],
 ],
 );
 },
 );
 }
 
 Widget _buildStandardConversationCard(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 // Agent/API type indicator
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
 decoration: BoxDecoration(
 color: _getTypeColor(context),
 borderRadius: BorderRadius.circular(4),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(
 _getTypeIcon(),
 size: 10,
 color: Colors.white,
 ),
 const SizedBox(width: 4),
 Text(
 _getTypeLabel(),
 style: TextStyles.caption.copyWith(
 color: Colors.white,
 fontSize: 9,
 fontWeight: FontWeight.w500,
 ),
 ),
 ],
 ),
 ),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 widget.conversation.title,
 style: TextStyles.bodyMedium.copyWith(
 fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
 color: widget.isSelected
 ? ThemeColors(context).primary
 : ThemeColors(context).onSurface,
 ),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 ),
 ],
 ),
 if (_getProviderDisplayText() != null) ...[
 const SizedBox(height: 4),
 Text(
 _getProviderDisplayText()!,
 style: TextStyles.caption.copyWith(
 color: ThemeColors(context).onSurfaceVariant,
 fontSize: 10,
 ),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 ],
 const SizedBox(height: SpacingTokens.xs),
 Row(
 children: [
 Icon(
 Icons.message,
 size: 12,
 color: ThemeColors(context).onSurfaceVariant,
 ),
 const SizedBox(width: SpacingTokens.xs),
 Text(
 '${widget.conversation.messages.length} messages',
 style: TextStyles.caption.copyWith(
 color: ThemeColors(context).onSurfaceVariant,
 ),
 ),
 const Spacer(),
 Text(
 _formatDate(widget.conversation.createdAt),
 style: TextStyles.caption.copyWith(
 color: ThemeColors(context).onSurfaceVariant,
 ),
 ),
 ],
 ),
 ],
 );
 }

 void _showContextMenu(BuildContext context) {
 showDialog(
 context: context,
 builder: (context) => AlertDialog(
 backgroundColor: ThemeColors(context).surface,
 title: Text(
 widget.conversation.title,
 style: TextStyles.bodyMedium.copyWith(
 color: ThemeColors(context).onSurface,
 fontWeight: FontWeight.w600,
 ),
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 ),
 content: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 ListTile(
 leading: Icon(
 Icons.archive,
 color: ThemeColors(context).onSurfaceVariant,
 ),
 title: Text(
 'Archive Conversation',
 style: TextStyles.bodyMedium.copyWith(
 color: ThemeColors(context).onSurface,
 ),
 ),
 onTap: () {
 Navigator.of(context).pop();
 widget.onArchive();
 },
 ),
 ListTile(
 leading: Icon(
 Icons.delete_outline,
 color: ThemeColors(context).error,
 ),
 title: Text(
 'Delete Conversation',
 style: TextStyles.bodyMedium.copyWith(
 color: ThemeColors(context).error,
 ),
 ),
 onTap: () {
 Navigator.of(context).pop();
 widget.onDelete();
 },
 ),
 ],
 ),
 actions: [
 AsmblButton.secondary(
 text: 'Cancel',
 onPressed: () => Navigator.of(context).pop(),
 ),
 ],
 ),
 );
 }

 String _getTypeLabel() {
 final type = widget.conversation.metadata?['type'] as String?;
 switch (type) {
 case 'agent':
 return 'AGENT';
 case 'default_api':
 return 'API';
 default:
 return 'CHAT';
 }
 }

 IconData _getTypeIcon() {
 final type = widget.conversation.metadata?['type'] as String?;
 switch (type) {
 case 'agent':
 return Icons.smart_toy;
 case 'default_api':
 return Icons.api;
 default:
 return Icons.chat;
 }
 }

 Color _getTypeColor(BuildContext context) {
 final type = widget.conversation.metadata?['type'] as String?;
 switch (type) {
 case 'agent':
 return ThemeColors(context).primary;
 case 'default_api':
 return ThemeColors(context).onSurfaceVariant;
 default:
 return ThemeColors(context).onSurfaceVariant.withValues(alpha: 0.7);
 }
 }

 String? _getApiProvider() {
 // First try to get from stored conversation metadata
 final storedModelName = widget.conversation.metadata?['defaultModelName'] as String?;
 final modelType = widget.conversation.metadata?['modelType'] as String?;
 final provider = widget.conversation.metadata?['defaultModelProvider'] as String?;

 if (modelType == 'local' && storedModelName != null) {
   return 'Local';
 } else if (provider != null) {
   return provider;
 } else if (storedModelName != null) {
   return storedModelName;
 } else {
   // Fallback to legacy apiProvider field
   return widget.conversation.metadata?['apiProvider'] as String?;
 }
 }

 String? _getProviderDisplayText() {
   final storedModelName = widget.conversation.metadata?['defaultModelName'] as String?;
   final modelType = widget.conversation.metadata?['modelType'] as String?;
   final provider = widget.conversation.metadata?['defaultModelProvider'] as String?;

   if (modelType == 'local' && storedModelName != null) {
     return 'Local';
   } else if (provider != null) {
     return provider;
   } else if (storedModelName != null) {
     return storedModelName;
   } else {
     // Fallback to legacy apiProvider field
     final legacyProvider = widget.conversation.metadata?['apiProvider'] as String?;
     return legacyProvider;
   }
 }

 String _formatDate(DateTime date) {
 final now = DateTime.now();
 final diff = now.difference(date);
 
 if (diff.inDays == 0) {
 return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
 } else if (diff.inDays == 1) {
 return 'Yesterday';
 } else if (diff.inDays < 7) {
 return '${diff.inDays}d ago';
 } else {
 return '${date.day}/${date.month}';
 }
 }

 Color _getAgentColor(Agent agent, BuildContext context) {
 final colors = ThemeColors(context);
 switch (agent.id) {
 case 'research-assistant':
 return colors.success; // Use theme success color
 case 'code-helper':
 return colors.primary; // Use theme primary color
 case 'data-analyst':
 return colors.accent; // Use theme accent color
 default:
 return colors.primary; // Default theme primary color
 }
 }

 IconData _getAgentIcon(Agent agent) {
 switch (agent.id) {
 case 'research-assistant':
 return Icons.search;
 case 'code-helper':
 return Icons.code;
 case 'data-analyst':
 return Icons.analytics;
 default:
 return Icons.smart_toy;
 }
 }
}
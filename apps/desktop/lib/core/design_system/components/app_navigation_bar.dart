import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';
import '../tokens/theme_colors.dart';
import 'dropdown_header_button.dart';
import 'asmbli_button.dart';
import 'theme_toggle.dart';
import '../../constants/routes.dart';
import '../../../providers/conversation_provider.dart';
import '../../../features/human_verification/presentation/widgets/verification_inbox_popover.dart';

// Centralized navigation bar for all screens
class AppNavigationBar extends ConsumerWidget {
 final String currentRoute;
 
 const AppNavigationBar({
 super.key,
 required this.currentRoute,
 });

 @override
 Widget build(BuildContext context, WidgetRef ref) {
 final colors = ThemeColors(context);
 return Container(
 padding: const EdgeInsets.only(
 left: SpacingTokens.headerPadding,
 right: SpacingTokens.headerPadding,
 top: SpacingTokens.pageVertical,
 bottom: 0,  // No bottom padding to eliminate gap
 ),
 decoration: BoxDecoration(
 color: colors.headerBackground,
 border: Border(bottom: BorderSide(color: colors.headerBorder)),
 ),
 child: SizedBox(
 height: 60, // Explicit height to maintain header size
 child: Row(
 mainAxisAlignment: MainAxisAlignment.start,
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 // Brand Title
 GestureDetector(
 onTap: () => context.go(AppRoutes.home),
 child: Row(
 children: [
 // Brand Title
 Text(
 'Asmbli',
 style: TextStyles.brandTitle.copyWith(
 color: colors.primary,
 fontWeight: FontWeight.bold,
 fontSize: 24,
 ),
 ),
 ],
 ),
 ),
 const SizedBox(width: SpacingTokens.xxl),
 
 // Navigation Dropdowns
 DropdownHeaderButton(
 text: 'Workspace',
 icon: Icons.work_outline,
 isActive: _isWorkspaceRoute(currentRoute),
 items: [
 DropdownItem(
 text: 'Chat',
 icon: Icons.chat_bubble_outline,
 onTap: () => context.go(AppRoutes.chat),
 isActive: currentRoute == AppRoutes.chat,
 ),
 DropdownItem(
 text: 'My Agents',
 icon: Icons.smart_toy,
 onTap: () => context.go(AppRoutes.agents),
 isActive: currentRoute == AppRoutes.agents,
 ),
 DropdownItem(
 text: 'Canvas Library',
 icon: Icons.photo_library,
 onTap: () => context.go(AppRoutes.canvasLibrary),
 isActive: currentRoute == AppRoutes.canvasLibrary,
 ),
 DropdownItem(
 text: 'Canvas Editor',
 icon: Icons.palette,
 onTap: () => context.go(AppRoutes.canvas),
 isActive: currentRoute == AppRoutes.canvas,
 ),
 ],
 ),
 const SizedBox(width: SpacingTokens.lg),

 DropdownHeaderButton(
 text: 'Development',
 icon: Icons.developer_mode,
 isActive: _isDevelopmentRoute(currentRoute),
 items: [
 DropdownItem(
 text: 'Context',
 icon: Icons.library_books,
 onTap: () => context.go(AppRoutes.context),
 isActive: currentRoute == AppRoutes.context,
 ),
 DropdownItem(
 text: 'Tools',
 icon: Icons.extension,
 onTap: () => context.go(AppRoutes.integrationHub),
 isActive: currentRoute == AppRoutes.integrationHub,
 ),
 DropdownItem(
 text: 'Reasoning Flows',
 icon: Icons.account_tree,
 onTap: () => context.go(AppRoutes.orchestration),
 isActive: currentRoute == AppRoutes.orchestration,
 ),
 DropdownItem(
 text: 'Human Verification',
 icon: Icons.verified_user,
 onTap: () => context.go('/human-verification'),
 isActive: currentRoute == '/human-verification',
 ),
 DropdownItem(
 text: 'Settings',
 icon: Icons.settings,
 onTap: () => context.go(AppRoutes.settings),
 isActive: currentRoute == AppRoutes.settings,
 ),
 ],
 ),
 const SizedBox(width: SpacingTokens.lg),
 
  
 // Spacer to push right-aligned items to the right
 const Spacer(),

 // Human Verification Inbox
 const VerificationInboxPopover(),
 const SizedBox(width: SpacingTokens.md),

 // Theme Toggle (top-right)
 const ThemeToggle(),
 
 // New Chat button (only visible on Chat routes)
 if (currentRoute == AppRoutes.chat || currentRoute == AppRoutes.chatV2) ...[
   const SizedBox(width: SpacingTokens.lg),
   AsmblButton.primary(
     text: 'New Chat',
     icon: Icons.add,
     onPressed: () => _startNewChat(context, ref),
   ),
 ],
 ],
 ),
 ),
 );
 }

  
 Future<void> _startNewChat(BuildContext context, WidgetRef ref) async {
   try {
     // Create a new conversation
     final createConversation = ref.read(createConversationProvider);
     final conversation = await createConversation(title: 'New Chat');
     
     // Set as selected conversation
     ref.read(selectedConversationIdProvider.notifier).state = conversation.id;
     
     // Refresh conversations list
     ref.invalidate(conversationsProvider);
     
     // Show success feedback
     if (context.mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: const Row(
             children: [
               Icon(Icons.chat_bubble, color: Colors.white, size: 16),
               SizedBox(width: 8),
               Text('New conversation started'),
             ],
           ),
           backgroundColor: ThemeColors(context).success,
           behavior: SnackBarBehavior.floating,
           duration: const Duration(seconds: 2),
         ),
       );
     }
   } catch (e) {
     if (context.mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text('Failed to create new chat: $e'),
           backgroundColor: ThemeColors(context).error,
         ),
       );
     }
   }
 }

 bool _isWorkspaceRoute(String route) {
   return route == AppRoutes.chat ||
       route == AppRoutes.chatV2 ||
       route == AppRoutes.agents ||
       route == AppRoutes.canvas ||
       route == AppRoutes.canvasLibrary;
 }

 bool _isDevelopmentRoute(String route) {
   return route == AppRoutes.context ||
       route == AppRoutes.integrationHub ||
       route == AppRoutes.orchestration ||
       route == AppRoutes.settings;
 }
}
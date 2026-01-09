import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/routes.dart';

class AgentsScreen extends StatelessWidget {
 const AgentsScreen({super.key});

 @override
 Widget build(BuildContext context) {
 return Scaffold(
 appBar: AppBar(
 title: const Text('My Agents'),
 actions: [
 IconButton(
 icon: const Icon(Icons.add),
 onPressed: () {
 context.push(AppRoutes.agentWizard);
 },
 ),
 ],
 ),
 body: Padding(
 padding: const EdgeInsets.all(16),
 child: Column(
 children: [
 // Stats cards
 const Row(
 children: [
 Expanded(
 child: _StatsCard(
 title: 'Total Agents',
 value: '12',
 icon: Icons.smart_toy,
 ),
 ),
 SizedBox(width: 16),
 Expanded(
 child: _StatsCard(
 title: 'Active Today',
 value: '3',
 icon: Icons.schedule,
 ),
 ),
 SizedBox(width: 16),
 Expanded(
 child: _StatsCard(
 title: 'Messages',
 value: '1,234',
 icon: Icons.message,
 ),
 ),
 ],
 ),
 
 const SizedBox(height: 24),
 
 // Agents list
 Expanded(
 child: ListView.builder(
 itemCount: 5, // Mock data
 itemBuilder: (context, index) {
 return _AgentListItem(
 name: 'Agent ${index + 1}',
 description: 'Description for agent ${index + 1}',
 lastUsed: DateTime.now().subtract(Duration(days: index)),
 messageCount: 123 - (index * 10),
 );
 },
 ),
 ),
 ],
 ),
 ),
 );
 }
}

class _StatsCard extends StatelessWidget {
 final String title;
 final String value;
 final IconData icon;

 const _StatsCard({
 required this.title,
 required this.value,
 required this.icon,
 });

 @override
 Widget build(BuildContext context) {
 final theme = Theme.of(context);
 
 return Material(
 color: Colors.transparent,
 child: InkWell(
 borderRadius: BorderRadius.circular(12),
 hoverColor: theme.colorScheme.primary.withValues(alpha: 0.04),
 splashColor: theme.colorScheme.primary.withValues(alpha: 0.12),
 onTap: () {
 // Add stats card interaction if needed
 },
 child: Card(
 child: Padding(
 padding: const EdgeInsets.all(16),
 child: Column(
 children: [
 Icon(
 icon,
 size: 32,
 color: theme.colorScheme.primary,
 ),
 const SizedBox(height: 8),
 Text(
 value,
 style: theme.textTheme.headlineSmall,
 ),
 Text(
 title,
 style: theme.textTheme.bodySmall,
 ),
 ],
 ),
 ),
 ),
 ),
 );
 }
}

class _AgentListItem extends StatelessWidget {
 final String name;
 final String description;
 final DateTime lastUsed;
 final int messageCount;

 const _AgentListItem({
 required this.name,
 required this.description,
 required this.lastUsed,
 required this.messageCount,
 });

 @override
 Widget build(BuildContext context) {
 final theme = Theme.of(context);
 
 return Card(
 margin: const EdgeInsets.only(bottom: 8),
 child: Material(
 color: Colors.transparent,
 child: InkWell(
 borderRadius: BorderRadius.circular(12),
 hoverColor: theme.colorScheme.primary.withValues(alpha: 0.04),
 splashColor: theme.colorScheme.primary.withValues(alpha: 0.12),
 onTap: () {
 // Open agent details/chat
 },
 child: ListTile(
 leading: CircleAvatar(
 backgroundColor: theme.colorScheme.primaryContainer,
 child: Icon(
 Icons.smart_toy,
 color: theme.colorScheme.onPrimaryContainer,
 ),
 ),
 title: Text(name),
 subtitle: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(description),
 const SizedBox(height: 4),
 Row(
 children: [
 Text(
 'Last used: ${_formatDate(lastUsed)}',
 style: theme.textTheme.bodySmall,
 ),
 const SizedBox(width: 16),
 Text(
 '$messageCount messages',
 style: theme.textTheme.bodySmall,
 ),
 ],
 ),
 ],
 ),
 trailing: PopupMenuButton(
 itemBuilder: (context) => [
 const PopupMenuItem(
 value: 'edit',
 child: ListTile(
 leading: Icon(Icons.edit),
 title: Text('Edit'),
 contentPadding: EdgeInsets.zero,
 ),
 ),
 const PopupMenuItem(
 value: 'duplicate',
 child: ListTile(
 leading: Icon(Icons.copy),
 title: Text('Duplicate'),
 contentPadding: EdgeInsets.zero,
 ),
 ),
 const PopupMenuItem(
 value: 'export',
 child: ListTile(
 leading: Icon(Icons.file_download),
 title: Text('Export'),
 contentPadding: EdgeInsets.zero,
 ),
 ),
 const PopupMenuItem(
 value: 'delete',
 child: ListTile(
 leading: Icon(Icons.delete, color: Colors.red),
 title: Text('Delete', style: TextStyle(color: Colors.red)),
 contentPadding: EdgeInsets.zero,
 ),
 ),
 ],
 onSelected: (value) {
 _handleMenuAction(context, value, 'agent_${index + 1}');
 },
 ),
 ),
 ),
 ),
 );
 }

 String _formatDate(DateTime date) {
 final now = DateTime.now();
 final difference = now.difference(date).inDays;
 
 if (difference == 0) return 'Today';
 if (difference == 1) return 'Yesterday';
 if (difference < 7) return '$difference days ago';
 return '${date.day}/${date.month}/${date.year}';
 }

 void _handleMenuAction(BuildContext context, String action, String agentId) {
   switch (action) {
     case 'edit':
       context.push('${AppRoutes.agentBuilder}?id=$agentId');
       break;
     case 'duplicate':
       // TODO: Implement agent duplication
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Duplicate feature coming soon')),
       );
       break;
     case 'export':
       // TODO: Implement agent export
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Export feature coming soon')),
       );
       break;
     case 'delete':
       _showDeleteConfirmation(context, agentId);
       break;
   }
 }

 void _showDeleteConfirmation(BuildContext context, String agentId) {
   showDialog(
     context: context,
     builder: (BuildContext context) {
       return AlertDialog(
         title: const Text('Delete Agent'),
         content: const Text('Are you sure you want to delete this agent? This action cannot be undone.'),
         actions: [
           TextButton(
             onPressed: () => Navigator.of(context).pop(),
             child: const Text('Cancel'),
           ),
           TextButton(
             onPressed: () {
               Navigator.of(context).pop();
               // TODO: Implement agent deletion
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text('Agent deleted')),
               );
             },
             style: TextButton.styleFrom(foregroundColor: Colors.red),
             child: const Text('Delete'),
           ),
         ],
       );
     },
   );
 }
}
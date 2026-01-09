import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/design_system/components/asmbli_card_enhanced.dart';
import '../../../../core/constants/routes.dart';
import '../../../context/presentation/widgets/context_hub_widget.dart';
import '../../../../core/services/agent_context_prompt_service.dart';
import '../../../../core/services/model_config_service.dart';
import '../../../../providers/agent_provider.dart';
import 'package:agent_engine_core/models/agent.dart';
import '../widgets/agent_terminal_widget.dart';
import '../widgets/mcp_server_status_widget.dart';
import '../widgets/mcp_server_logs_widget.dart';
import '../widgets/recommended_tools_widget.dart';

class AgentConfigurationScreen extends ConsumerStatefulWidget {
 final String? agentId;

 const AgentConfigurationScreen({
 super.key,
 this.agentId,
 });

 @override
 ConsumerState<AgentConfigurationScreen> createState() => _AgentConfigurationScreenState();
}

class _AgentConfigurationScreenState extends ConsumerState<AgentConfigurationScreen> {
 final _nameController = TextEditingController();
 final _descriptionController = TextEditingController();
 final _systemPromptController = TextEditingController();
 
 String selectedModel = 'Default Model';
 String selectedCategory = 'Research';
 double temperature = 0.7;
 int maxTokens = 2048;
 bool enableMemory = true;
 bool enableWebSearch = false;
 bool enableCodeExecution = false;
 
 // Guided system prompt configuration
 String selectedPersonality = 'Professional and helpful';
 String selectedTone = 'Friendly and approachable';
 String selectedExpertise = 'General knowledge';
 bool showAdvancedPrompt = false;
 
 List<String> selectedMCPServers = [];
 Agent? currentAgent;
 
 
 final List<String> categories = [
 'Research',
 'Development',
 'Writing',
 'Data Analysis',
 'Customer Support',
 'Marketing',
 'Design',
 ];
 
 final List<String> personalityOptions = [
 'Professional and helpful',
 'Casual and friendly',
 'Expert and authoritative',
 'Creative and inspiring',
 'Analytical and precise',
 'Supportive and encouraging',
 ];
 
 final List<String> toneOptions = [
 'Friendly and approachable',
 'Professional and formal',
 'Casual and conversational',
 'Enthusiastic and energetic',
 'Calm and patient',
 'Direct and efficient',
 ];
 
 final List<String> expertiseOptions = [
 'General knowledge',
 'Technical and coding',
 'Business and strategy',
 'Creative and design',
 'Research and analysis',
 'Communication and writing',
 ];
 
 final List<MCPServer> availableMCPServers = [
 MCPServer('Files', Icons.folder, 'Access and manage local files'),
 MCPServer('Git', Icons.code, 'Version control operations'),
 MCPServer('GitHub', Icons.code_outlined, 'GitHub API integration'),
 MCPServer('Postgres', Icons.storage, 'Database operations'),
 MCPServer('Memory', Icons.memory, 'Persistent memory storage'),
 MCPServer('Time', Icons.schedule, 'Time and scheduling functions'),
 MCPServer('Brave Search', Icons.search, 'Web search capabilities'),
 MCPServer('Slack', Icons.chat, 'Slack messaging integration'),
 MCPServer('Linear', Icons.assignment, 'Project management'),
 MCPServer('Notion', Icons.note, 'Knowledge base integration'),
 MCPServer('Figma', Icons.design_services, 'Design file access'),
 ];

 @override
 void initState() {
 super.initState();
 if (widget.agentId != null) {
 _loadAgentData();
 }
 }

 void _loadAgentData() {
 // Load existing agent data
 _nameController.text = widget.agentId ?? '';
 _descriptionController.text = 'Academic research agent with citation management';
 _systemPromptController.text = 'You are a helpful research assistant...';
 selectedMCPServers = ['Brave Search', 'Memory', 'Files'];
 }

 @override
 Widget build(BuildContext context) {
   // Get available models from model config service
   final modelConfigs = ref.watch(allModelConfigsProvider);
   final availableModels = ['Default Model', ...modelConfigs.values.where((m) => m.isConfigured).map((m) => m.name)];

 return Scaffold(
 body: Container(
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
 // Compact Header
 Container(
 padding: const EdgeInsets.symmetric(
 horizontal: SpacingTokens.headerPadding, 
 vertical: SpacingTokens.elementSpacing,
 ),
 decoration: BoxDecoration(
 color: ThemeColors(context).surface.withValues(alpha: 0.95),
 border: Border(
 bottom: BorderSide(
 color: ThemeColors(context).border,
 width: 1,
 ),
 ),
 ),
 child: Row(
 children: [
 IconButton(
 icon: Icon(Icons.arrow_back, color: ThemeColors(context).onSurface),
 onPressed: () => context.go(AppRoutes.agents),
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(),
 ),
 const SizedBox(width: SpacingTokens.componentSpacing),
 Text(
 widget.agentId != null ? 'Edit Agent' : 'Create New Agent',
 style: TextStyles.sectionTitle.copyWith(
 color: ThemeColors(context).onSurface,
 ),
 ),
 const Spacer(),
 AsmblButton.secondary(
 text: 'Cancel',
 onPressed: () => context.go(AppRoutes.agents),
 ),
 const SizedBox(width: SpacingTokens.componentSpacing),
 AsmblButton.primary(
 text: widget.agentId != null ? 'Save' : 'Create',
 onPressed: _saveAgent,
 icon: Icons.save,
 ),
 ],
 ),
 ),

 // Main Content - 3 Column Layout
 Expanded(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Left Panel - Core Configuration (Compact)
 Expanded(
 flex: 3,
 child: Container(
 padding: const EdgeInsets.all(SpacingTokens.lg),
 child: SingleChildScrollView(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Basic Info - Compact Layout
 AsmblCard(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const _CompactSectionHeader(
 title: 'Tell us about your agent', 
 icon: Icons.info_outline,
 tooltip: 'Give your agent a name, choose its specialty, and describe what you want it to help you with.',
 ),
 const SizedBox(height: SpacingTokens.componentSpacing),
 Row(
 children: [
 Expanded(
 flex: 2,
 child: _FormField(
 label: 'What would you like to name your agent?',
 controller: _nameController,
 placeholder: 'e.g., Research Assistant, Code Helper',
 ),
 ),
 const SizedBox(width: SpacingTokens.componentSpacing),
 Expanded(
 child: _DropdownField(
 label: 'What type of work will it do?',
 value: selectedCategory,
 items: categories,
 onChanged: (value) => setState(() => selectedCategory = value!),
 ),
 ),
 ],
 ),
 const SizedBox(height: SpacingTokens.elementSpacing),
 _FormField(
 label: 'What should your agent be great at?',
 controller: _descriptionController,
 placeholder: 'Tell us what you want your agent to help you with',
 maxLines: 2,
 ),
 ],
 ),
 ),
 
 const SizedBox(height: SpacingTokens.elementSpacing),
 
 // Model Configuration - Vertical Layout
 AsmblCard(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const _CompactSectionHeader(
 title: "Choose your agent's brain", 
 icon: Icons.tune,
 tooltip: 'Select the AI model and configure how creative or focused your agent should be when responding.',
 ),
 const SizedBox(height: SpacingTokens.componentSpacing),
 _DropdownField(
 label: 'Which AI model should power your agent?',
 value: selectedModel,
 items: availableModels,
 onChanged: (value) => setState(() => selectedModel = value!),
 ),
 const SizedBox(height: SpacingTokens.elementSpacing),
 _CreativitySlider(
 value: temperature,
 onChanged: (value) => setState(() => temperature = value),
 ),
 const SizedBox(height: SpacingTokens.elementSpacing),
 _ResponseLengthSlider(
 value: maxTokens.toDouble(),
 onChanged: (value) => setState(() => maxTokens = value.toInt()),
 ),
 ],
 ),
 ),
 
 const SizedBox(height: SpacingTokens.elementSpacing),
 
 // Guided Agent Personality Configuration
 AsmblCard(
 child: _GuidedPersonalityConfig(
 selectedPersonality: selectedPersonality,
 selectedTone: selectedTone,
 selectedExpertise: selectedExpertise,
 showAdvancedPrompt: showAdvancedPrompt,
 systemPromptController: _systemPromptController,
 personalityOptions: personalityOptions,
 toneOptions: toneOptions,
 expertiseOptions: expertiseOptions,
 onPersonalityChanged: (value) => setState(() => selectedPersonality = value),
 onToneChanged: (value) => setState(() => selectedTone = value),
 onExpertiseChanged: (value) => setState(() => selectedExpertise = value),
 onToggleAdvanced: () => setState(() => showAdvancedPrompt = !showAdvancedPrompt),
 ),
 ),
 
 ],
 ),
 ),
 ),
 ),
 
 // Middle Panel - MCP Servers (Compact)
 Container(
 width: 280,
 decoration: BoxDecoration(
 color: ThemeColors(context).surface.withValues(alpha: 0.3),
 border: Border(
 left: BorderSide(color: ThemeColors(context).border, width: 1),
 right: BorderSide(color: ThemeColors(context).border, width: 1),
 ),
 ),
 padding: const EdgeInsets.all(SpacingTokens.lg),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Superpowers Section
 const _CompactSectionHeader(
 title: 'Add Actions', 
 icon: Icons.auto_awesome,
 tooltip: 'Enable built-in capabilities like memory, web search, and code execution to give your agent superpowers.',
 ),
 const SizedBox(height: SpacingTokens.componentSpacing),
 Column(
 children: [
 _CapabilityToggle(
 label: 'Remember our chats',
 icon: Icons.memory,
 value: enableMemory,
 onChanged: (value) => setState(() => enableMemory = value),
 ),
 const SizedBox(height: SpacingTokens.xs),
 _CapabilityToggle(
 label: 'Search the web',
 icon: Icons.search,
 value: enableWebSearch,
 onChanged: (value) => setState(() => enableWebSearch = value),
 ),
 const SizedBox(height: SpacingTokens.xs),
 _CapabilityToggle(
 label: 'Run code safely',
 icon: Icons.terminal,
 value: enableCodeExecution,
 onChanged: (value) => setState(() => enableCodeExecution = value),
 ),
 ],
 ),
 
 const SizedBox(height: SpacingTokens.sectionSpacing),
 
 // Master Prompt Preview Section
 const _CompactSectionHeader(
 title: 'Master Prompt Preview', 
 icon: Icons.preview_outlined,
 tooltip: 'Preview the complete prompt that will be sent to the AI model, including personality, expertise, and context.',
 ),
 const SizedBox(height: SpacingTokens.xs),
 
                Expanded(
                  child: _MasterPromptPreview(
                    name: _nameController.text.isNotEmpty ? _nameController.text : 'Your Agent',
                    description: _descriptionController.text,
                    personality: selectedPersonality,
                    tone: selectedTone,
                    expertise: selectedExpertise,
                    systemPrompt: _systemPromptController.text,
                    showAdvancedPrompt: showAdvancedPrompt,
                  ),
                ),
 ],
 ),
 ),
 
 // Right Panel - Context Hub
 Container(
 width: 320,
 decoration: BoxDecoration(
 color: ThemeColors(context).surface.withValues(alpha: 0.3),
 ),
 padding: const EdgeInsets.all(SpacingTokens.lg),
 child: const Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _CompactSectionHeader(
 title: 'Give your agent knowledge', 
 icon: Icons.library_books_outlined,
 tooltip: 'Add context documents, examples, and knowledge to make your agent smarter about specific topics or tasks.',
 ),
 SizedBox(height: SpacingTokens.componentSpacing),
 Expanded(
 child: ContextHubWidget(),
 ),
 ],
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

 Widget _buildRightPanel() {
   return DefaultTabController(
     length: 4,
     child: Column(
       children: [
         // Tab bar
         Container(
           decoration: BoxDecoration(
             color: ThemeColors(context).surfaceVariant,
             borderRadius: const BorderRadius.only(
               topLeft: Radius.circular(BorderRadiusTokens.md),
               topRight: Radius.circular(BorderRadiusTokens.md),
             ),
           ),
           child: TabBar(
             tabs: const [
               Tab(icon: Icon(Icons.library_books), text: 'Context'),
               Tab(icon: Icon(Icons.terminal), text: 'Terminal'),
               Tab(icon: Icon(Icons.extension), text: 'Tools'),
               Tab(icon: Icon(Icons.bug_report), text: 'Logs'),
             ],
             labelColor: ThemeColors(context).primary,
             unselectedLabelColor: ThemeColors(context).onSurfaceVariant,
             indicatorColor: ThemeColors(context).primary,
           ),
         ),
         
         // Tab content
         Expanded(
           child: TabBarView(
             children: [
               // Context tab
               const Padding(
                 padding: EdgeInsets.all(SpacingTokens.lg),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     _CompactSectionHeader(
                       title: 'Give your agent knowledge',
                       icon: Icons.library_books_outlined,
                       tooltip: 'Add context documents, examples, and knowledge to make your agent smarter about specific topics or tasks.',
                     ),
                     SizedBox(height: SpacingTokens.componentSpacing),
                     Expanded(
                       child: ContextHubWidget(),
                     ),
                   ],
                 ),
               ),
               
               // Terminal tab
               Padding(
                 padding: const EdgeInsets.all(SpacingTokens.lg),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     const _CompactSectionHeader(
                       title: 'Agent Terminal',
                       icon: Icons.terminal,
                       tooltip: 'Execute commands in your agent\'s isolated terminal environment.',
                     ),
                     const SizedBox(height: SpacingTokens.componentSpacing),
                     Expanded(
                       child: currentAgent != null
                           ? AgentTerminalWidget(
                               agentId: currentAgent!.id,
                               height: double.infinity,
                             )
                           : Center(
                               child: Text(
                                 'Save agent to access terminal',
                                 style: TextStyles.bodyMedium.copyWith(
                                   color: ThemeColors(context).onSurfaceVariant,
                                 ),
                               ),
                             ),
                     ),
                   ],
                 ),
               ),
               
               // MCP Tools tab with recommendations
               Padding(
                 padding: const EdgeInsets.all(SpacingTokens.lg),
                 child: Row(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     // Left side - Recommended Tools
                     Expanded(
                       flex: 2,
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           const _CompactSectionHeader(
                             title: 'Recommended Tools',
                             icon: Icons.recommend,
                             tooltip: 'Tools recommended for your agent\'s category and use case.',
                           ),
                           const SizedBox(height: SpacingTokens.componentSpacing),
                           Expanded(
                             child: RecommendedToolsWidget(
                               category: selectedCategory,
                               onToolSelected: (tool) {
                                 // TODO: Implement tool installation/selection
                                 ScaffoldMessenger.of(context).showSnackBar(
                                   SnackBar(
                                     content: Text('Selected: ${tool.name}'),
                                     duration: const Duration(seconds: 2),
                                   ),
                                 );
                               },
                             ),
                           ),
                         ],
                       ),
                     ),

                     const SizedBox(width: SpacingTokens.lg),

                     // Right side - Current MCP Servers
                     Expanded(
                       flex: 1,
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           const _CompactSectionHeader(
                             title: 'Active Tools',
                             icon: Icons.extension,
                             tooltip: 'Currently installed and active MCP servers for this agent.',
                           ),
                           const SizedBox(height: SpacingTokens.componentSpacing),
                           Expanded(
                             child: currentAgent != null
                                 ? MCPServerStatusWidget(
                                     agentId: currentAgent!.id,
                                   )
                                 : Center(
                                     child: Text(
                                       'Save agent to manage active tools',
                                       style: TextStyles.bodyMedium.copyWith(
                                         color: ThemeColors(context).onSurfaceVariant,
                                       ),
                                       textAlign: TextAlign.center,
                                     ),
                                   ),
                           ),
                         ],
                       ),
                     ),
                   ],
                 ),
               ),

               // Logs tab
               Padding(
                 padding: const EdgeInsets.all(SpacingTokens.lg),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     const _CompactSectionHeader(
                       title: 'MCP Server Logs',
                       icon: Icons.bug_report,
                       tooltip: 'View detailed logs and debug information from MCP servers.',
                     ),
                     const SizedBox(height: SpacingTokens.componentSpacing),
                     Expanded(
                       child: currentAgent != null
                           ? MCPServerLogsWidget(
                               agentId: currentAgent!.id,
                               height: double.infinity,
                             )
                           : Center(
                               child: Text(
                                 'Save agent to access server logs',
                                 style: TextStyles.bodyMedium.copyWith(
                                   color: ThemeColors(context).onSurfaceVariant,
                                 ),
                               ),
                             ),
                     ),
                   ],
                 ),
               ),
             ],
           ),
         ),
       ],
     ),
   );
 }

 String _generateSystemPrompt() {
 String basePrompt = 'You are an AI assistant with the following characteristics:\n\n';
 
 // Add personality
 basePrompt += 'Personality: $selectedPersonality\n';
 basePrompt += 'Tone: $selectedTone\n';
 basePrompt += 'Expertise: $selectedExpertise\n\n';
 
 // Add description from user
 if (_descriptionController.text.isNotEmpty) {
 basePrompt += 'Your primary purpose: ${_descriptionController.text}\n\n';
 }
 
 // Add capabilities context
 List<String> capabilities = [];
 if (enableMemory) capabilities.add('remember our conversation history');
 if (enableWebSearch) capabilities.add('search the web for current information');
 if (enableCodeExecution) capabilities.add('execute code in a safe environment');
 
 if (capabilities.isNotEmpty) {
 basePrompt += 'You have the ability to: ${capabilities.join(', ')}.\n\n';
 }
 
 // Add context from Knowledge Library if available
 final agentId = widget.agentId;
 if (agentId != null) {
 basePrompt += _addContextToPrompt(agentId);
 }
 
 // Add helpful guidelines
 basePrompt += 'Always be helpful, accurate, and aligned with your personality and tone. ';
 basePrompt += 'Ask clarifying questions when needed, and provide clear, actionable responses.';
 
 return basePrompt;
 }

 String _addContextToPrompt(String agentId) {
 // This method will be enhanced to include context documents
 // For now, add a placeholder section for context integration
 String contextPrompt = '\n## Knowledge Base\n';
 contextPrompt += 'You have access to specialized knowledge and context documents that will help you provide more accurate and relevant responses. ';
 contextPrompt += 'Use this information to enhance your responses when relevant.\n\n';
 
 // TODO: In a real implementation, we would:
 // 1. Get context documents assigned to this agent using contextForAgentProvider
 // 2. Add relevant excerpts or summaries to the prompt
 // 3. Organize context by type (examples, knowledge, procedures, etc.)
 
 return contextPrompt;
 }

 void _saveAgent() async {
 // Generate enhanced system prompt if not in advanced mode
 if (!showAdvancedPrompt) {
 final contextPromptService = ref.read(agentContextPromptServiceProvider);
 
 if (widget.agentId != null) {
 // Existing agent - enhance with context
 final enhancedPrompt = await contextPromptService.enhancePromptWithContext(
 _generateSystemPrompt(),
 widget.agentId!,
 ref,
 );
 _systemPromptController.text = enhancedPrompt;
 } else {
 // New agent - use context-aware prompt creation
 final capabilities = <String>[];
 if (enableMemory) capabilities.add('remember our conversation history');
 if (enableWebSearch) capabilities.add('search the web for current information');
 if (enableCodeExecution) capabilities.add('execute code in a safe environment');
 
 final contextAwarePrompt = contextPromptService.createContextAwarePrompt(
 agentName: _nameController.text.isNotEmpty ? _nameController.text : 'AI Assistant',
 agentDescription: _descriptionController.text,
 personality: selectedPersonality,
 expertise: selectedExpertise,
 capabilities: capabilities,
 mcpServers: [], // TODO: Get from MCP configuration
 );
 _systemPromptController.text = contextAwarePrompt;
 }
 }
 
 // Save agent configuration
 try {
   final agentNotifier = ref.read(agentNotifierProvider.notifier);
   
   if (currentAgent != null) {
     // Update existing agent
     final updatedAgent = Agent(
       id: currentAgent!.id,
       name: _nameController.text,
       description: _descriptionController.text,
       capabilities: _getCapabilitiesFromCategory(selectedCategory),
       configuration: {
         'systemPrompt': _systemPromptController.text,
         'temperature': temperature,
         'maxTokens': maxTokens,
         'category': selectedCategory,
         'selectedModel': selectedModel,
         'mcpServers': selectedMCPServers,
         'enableMemory': enableMemory,
         'enableWebSearch': enableWebSearch,
         'enableCodeExecution': enableCodeExecution,
       },
       status: currentAgent!.status,
     );
     
     await agentNotifier.updateAgent(updatedAgent);
   } else {
     // Create new agent
     final newAgent = Agent(
       id: 'agent_${DateTime.now().millisecondsSinceEpoch}',
       name: _nameController.text,
       description: _descriptionController.text,
       capabilities: _getCapabilitiesFromCategory(selectedCategory),
       configuration: {
         'systemPrompt': _systemPromptController.text,
         'temperature': temperature,
         'maxTokens': maxTokens,
         'category': selectedCategory,
         'selectedModel': selectedModel,
         'mcpServers': selectedMCPServers,
         'enableMemory': enableMemory,
         'enableWebSearch': enableWebSearch,
         'enableCodeExecution': enableCodeExecution,
       },
     );
     
     await agentNotifier.createAgent(newAgent);
   }
   
   if (mounted) {
     context.go(AppRoutes.agents);
   }
 } catch (e) {
   print('Error saving agent: $e');
   // Show error to user
   if (mounted) {
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(content: Text('Error saving agent: $e')),
     );
   }
 }
}

List<String> _getCapabilitiesFromCategory(String category) {
 switch (category) {
   case 'Research':
     return ['research', 'analysis', 'citation', 'fact-checking'];
   case 'Development':
     return ['coding', 'debugging', 'code-review', 'testing'];
   case 'Writing':
     return ['content-creation', 'editing', 'seo', 'copywriting'];
   case 'Data Analysis':
     return ['data-analysis', 'visualization', 'statistics', 'reporting'];
   case 'Customer Support':
     return ['customer-service', 'troubleshooting', 'communication', 'ticket-management'];
   case 'Marketing':
     return ['marketing', 'campaigns', 'analytics', 'strategy'];
   default:
     return ['general-assistance', 'problem-solving', 'communication'];
 }
 }

 void _showMCPSetupDialog() {
 showDialog(
 context: context,
 builder: (context) => const MCPSetupDialog(),
 );
 }

 @override
 void dispose() {
 _nameController.dispose();
 _descriptionController.dispose();
 _systemPromptController.dispose();
 super.dispose();
 }
}

class _SectionHeader extends StatelessWidget {
 final String title;

 const _SectionHeader({required this.title});

 @override
 Widget build(BuildContext context) {
 return Text(
 title,
 style: TextStyles.sectionTitle.copyWith(
 color: ThemeColors(context).onSurface,
 ),
 );
 }
}

class _CompactSectionHeader extends StatelessWidget {
 final String title;
 final IconData icon;
 final String? tooltip;

 const _CompactSectionHeader({
 required this.title,
 required this.icon,
 this.tooltip,
 });

 @override
 Widget build(BuildContext context) {
 return Row(
 children: [
 Icon(
 icon,
 size: 18,
 color: ThemeColors(context).primary,
 ),
 const SizedBox(width: SpacingTokens.xs),
 Expanded(
 child: Text(
 title,
 style: TextStyles.bodyMedium.copyWith(
 color: ThemeColors(context).onSurface,
 fontWeight: FontWeight.w600,
 ),
 overflow: TextOverflow.ellipsis,
 ),
 ),
 if (tooltip != null) ...[
 const SizedBox(width: SpacingTokens.xs),
 Tooltip(
 message: tooltip!,
 child: Icon(
 Icons.help_outline,
 size: 16,
 color: ThemeColors(context).onSurfaceVariant.withValues(alpha: 0.6),
 ),
 ),
 ],
 ],
 );
 }
}

class _CompactSliderField extends StatelessWidget {
 final String label;
 final double value;
 final double min;
 final double max;
 final int? divisions;
 final ValueChanged<double> onChanged;
 final String? displayValue;

 const _CompactSliderField({
 required this.label,
 required this.value,
 required this.min,
 required this.max,
 required this.onChanged,
 this.divisions,
 this.displayValue,
 });

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text(
 label,
 style: TextStyles.bodySmall.copyWith(
 color: ThemeColors(context).onSurfaceVariant,
 fontWeight: FontWeight.w500,
 ),
 ),
 Container(
 padding: const EdgeInsets.symmetric(
 horizontal: SpacingTokens.xs,
 vertical: 2,
 ),
 decoration: BoxDecoration(
 color: ThemeColors(context).surfaceVariant,
 borderRadius: BorderRadius.circular(4),
 ),
 child: Text(
 displayValue ?? value.toStringAsFixed(1),
 style: TextStyles.caption.copyWith(
 color: ThemeColors(context).onSurface,
 fontWeight: FontWeight.w600,
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 4),
 SizedBox(
 height: 20,
 child: Slider(
 value: value,
 min: min,
 max: max,
 divisions: divisions,
 onChanged: onChanged,
 activeColor: ThemeColors(context).primary,
 inactiveColor: ThemeColors(context).border,
 ),
 ),
 ],
 );
 }
}

class _CapabilityToggle extends StatelessWidget {
 final String label;
 final IconData icon;
 final bool value;
 final ValueChanged<bool> onChanged;

 const _CapabilityToggle({
 required this.label,
 required this.icon,
 required this.value,
 required this.onChanged,
 });

 @override
 Widget build(BuildContext context) {
 return GestureDetector(
 onTap: () => onChanged(!value),
 child: Container(
 padding: const EdgeInsets.symmetric(
 horizontal: SpacingTokens.componentSpacing,
 vertical: SpacingTokens.xs,
 ),
 decoration: BoxDecoration(
 color: value 
 ? ThemeColors(context).primary.withValues(alpha: 0.1) 
 : ThemeColors(context).surfaceVariant.withValues(alpha: 0.5),
 borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
 border: Border.all(
 color: value 
 ? ThemeColors(context).primary 
 : ThemeColors(context).border,
 ),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(
 icon,
 size: 16,
 color: value 
 ? ThemeColors(context).primary 
 : ThemeColors(context).onSurfaceVariant,
 ),
 const SizedBox(width: 6),
 Text(
 label,
 style: TextStyles.bodySmall.copyWith(
 color: value 
 ? ThemeColors(context).primary 
 : ThemeColors(context).onSurfaceVariant,
 fontWeight: value ? FontWeight.w600 : FontWeight.normal,
 ),
 ),
 ],
 ),
 ),
 );
 }
}

class _CompactMCPServerItem extends StatelessWidget {
 final MCPServer server;
 final bool isSelected;
 final VoidCallback onToggle;

 const _CompactMCPServerItem({
 required this.server,
 required this.isSelected,
 required this.onToggle,
 });

 @override
 Widget build(BuildContext context) {
 return GestureDetector(
 onTap: onToggle,
 child: Container(
 padding: const EdgeInsets.symmetric(
 horizontal: SpacingTokens.componentSpacing,
 vertical: SpacingTokens.xs,
 ),
 decoration: BoxDecoration(
 color: isSelected 
 ? ThemeColors(context).primary.withValues(alpha: 0.1) 
 : ThemeColors(context).surface.withValues(alpha: 0.5),
 borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
 border: Border.all(
 color: isSelected 
 ? ThemeColors(context).primary 
 : ThemeColors(context).border.withValues(alpha: 0.5),
 ),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 width: 4,
 height: 4,
 decoration: BoxDecoration(
 color: isSelected 
 ? ThemeColors(context).primary 
 : ThemeColors(context).border,
 shape: BoxShape.circle,
 ),
 ),
 const SizedBox(width: SpacingTokens.xs),
 Icon(
 server.icon,
 size: 16,
 color: isSelected 
 ? ThemeColors(context).primary 
 : ThemeColors(context).onSurfaceVariant,
 ),
 const SizedBox(width: SpacingTokens.xs),
 Expanded(
 child: Text(
 server.name,
 style: TextStyles.bodySmall.copyWith(
 color: isSelected 
 ? ThemeColors(context).primary 
 : ThemeColors(context).onSurface,
 fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
 ),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 ),
 ],
 ),
 // Show description when selected
 if (isSelected) ...[
 const SizedBox(height: 4),
 Padding(
 padding: const EdgeInsets.only(left: 20), // Align with text
 child: Text(
 server.description,
 style: TextStyles.caption.copyWith(
 color: ThemeColors(context).onSurfaceVariant,
 fontSize: 10,
 ),
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 ),
 ),
 ],
 ],
 ),
 ),
 );
 }
}

class _FormField extends StatelessWidget {
 final String label;
 final TextEditingController controller;
 final String placeholder;
 final int maxLines;

 const _FormField({
 required this.label,
 required this.controller,
 required this.placeholder,
 this.maxLines = 1,
 });

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 if (label.isNotEmpty) ...[
 Text(
 label,
 style: TextStyles.bodySmall.copyWith(
 color: ThemeColors(context).onSurfaceVariant,
 fontWeight: FontWeight.w500,
 ),
 ),
 const SizedBox(height: SpacingTokens.xs),
 ],
 TextField(
 controller: controller,
 maxLines: maxLines,
 style: TextStyles.bodyMedium.copyWith(
 color: ThemeColors(context).onSurface,
 ),
 decoration: InputDecoration(
 hintText: placeholder,
 hintStyle: TextStyles.bodyMedium.copyWith(
 color: ThemeColors(context).onSurfaceVariant.withValues(alpha: 0.5),
 ),
 filled: true,
 fillColor: ThemeColors(context).surface,
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
 borderSide: BorderSide(
 color: ThemeColors(context).border,
 ),
 ),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
 borderSide: BorderSide(
 color: ThemeColors(context).border,
 ),
 ),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
 borderSide: BorderSide(
 color: ThemeColors(context).primary,
 width: 2,
 ),
 ),
 contentPadding: const EdgeInsets.all(SpacingTokens.componentSpacing),
 ),
 ),
 ],
 );
 }
}

class _DropdownField extends StatelessWidget {
 final String label;
 final String value;
 final List<String> items;
 final ValueChanged<String?> onChanged;

 const _DropdownField({
 required this.label,
 required this.value,
 required this.items,
 required this.onChanged,
 });

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 label,
 style: TextStyles.bodySmall.copyWith(
 color: ThemeColors(context).onSurfaceVariant,
 fontWeight: FontWeight.w500,
 ),
 ),
 const SizedBox(height: SpacingTokens.xs),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.componentSpacing),
 decoration: BoxDecoration(
 color: ThemeColors(context).surface,
 borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
 border: Border.all(
 color: ThemeColors(context).border,
 ),
 ),
 child: DropdownButton<String>(
 value: value,
 onChanged: onChanged,
 isExpanded: true,
 underline: const SizedBox(),
 style: TextStyles.bodyMedium.copyWith(
 color: ThemeColors(context).onSurface,
 ),
 items: items.map((item) {
 return DropdownMenuItem(
 value: item,
 child: Text(item),
 );
 }).toList(),
 ),
 ),
 ],
 );
 }
}

class _SliderField extends StatelessWidget {
 final String label;
 final double value;
 final double min;
 final double max;
 final int? divisions;
 final ValueChanged<double> onChanged;
 final String? displayValue;

 const _SliderField({
 required this.label,
 required this.value,
 required this.min,
 required this.max,
 required this.onChanged,
 this.divisions,
 this.displayValue,
 });

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text(
 label,
 style: TextStyles.bodySmall.copyWith(
 color: ThemeColors(context).onSurfaceVariant,
 fontWeight: FontWeight.w500,
 ),
 ),
 Container(
 padding: const EdgeInsets.symmetric(
 horizontal: SpacingTokens.sm,
 vertical: SpacingTokens.xs,
 ),
 decoration: BoxDecoration(
 color: ThemeColors(context).surfaceVariant,
 borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
 ),
 child: Text(
 displayValue ?? value.toStringAsFixed(1),
 style: TextStyles.bodySmall.copyWith(
 color: ThemeColors(context).onSurface,
 fontWeight: FontWeight.w600,
 ),
 ),
 ),
 ],
 ),
 Slider(
 value: value,
 min: min,
 max: max,
 divisions: divisions,
 onChanged: onChanged,
 activeColor: ThemeColors(context).primary,
 inactiveColor: ThemeColors(context).border,
 ),
 ],
 );
 }
}

class _SwitchField extends StatelessWidget {
 final String label;
 final String subtitle;
 final bool value;
 final ValueChanged<bool> onChanged;

 const _SwitchField({
 required this.label,
 required this.subtitle,
 required this.value,
 required this.onChanged,
 });

 @override
 Widget build(BuildContext context) {
 return Padding(
 padding: const EdgeInsets.symmetric(vertical: SpacingTokens.componentSpacing),
 child: Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 label,
 style: TextStyles.bodyMedium.copyWith(
 color: ThemeColors(context).onSurface,
 fontWeight: FontWeight.w500,
 ),
 ),
 Text(
 subtitle,
 style: TextStyles.caption.copyWith(
 color: ThemeColors(context).onSurfaceVariant,
 ),
 ),
 ],
 ),
 ),
 Switch(
 value: value,
 onChanged: onChanged,
 
 ),
 ],
 ),
 );
 }
}

class _GuidedPersonalityConfig extends StatelessWidget {
 final String selectedPersonality;
 final String selectedTone;
 final String selectedExpertise;
 final bool showAdvancedPrompt;
 final TextEditingController systemPromptController;
 final List<String> personalityOptions;
 final List<String> toneOptions;
 final List<String> expertiseOptions;
 final ValueChanged<String> onPersonalityChanged;
 final ValueChanged<String> onToneChanged;
 final ValueChanged<String> onExpertiseChanged;
 final VoidCallback onToggleAdvanced;

 const _GuidedPersonalityConfig({
 required this.selectedPersonality,
 required this.selectedTone,
 required this.selectedExpertise,
 required this.showAdvancedPrompt,
 required this.systemPromptController,
 required this.personalityOptions,
 required this.toneOptions,
 required this.expertiseOptions,
 required this.onPersonalityChanged,
 required this.onToneChanged,
 required this.onExpertiseChanged,
 required this.onToggleAdvanced,
 });

 @override
 Widget build(BuildContext context) {
 final colors = ThemeColors(context);
 
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 const Expanded(
 child: _CompactSectionHeader(
 title: 'Teach your agent how to behave', 
 icon: Icons.psychology,
 tooltip: "Choose your agent's personality and communication style, or write custom instructions for advanced users.",
 ),
 ),
 TextButton.icon(
 onPressed: onToggleAdvanced,
 icon: Icon(
 showAdvancedPrompt ? Icons.visibility_off : Icons.code,
 size: 16,
 color: colors.primary,
 ),
 label: Text(
 showAdvancedPrompt ? 'Simple' : 'Advanced',
 style: TextStyles.bodySmall.copyWith(
 color: colors.primary,
 fontWeight: FontWeight.w600,
 ),
 ),
 style: TextButton.styleFrom(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 minimumSize: Size.zero,
 ),
 ),
 ],
 ),
 
 const SizedBox(height: SpacingTokens.componentSpacing),
 
 if (!showAdvancedPrompt) ...[
 // Guided Configuration
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Expanded(
 child: _DropdownField(
 label: 'What personality should it have?',
 value: selectedPersonality,
 items: personalityOptions,
 onChanged: (value) => onPersonalityChanged(value!),
 ),
 ),
 const SizedBox(width: SpacingTokens.componentSpacing),
 Expanded(
 child: _DropdownField(
 label: 'How should it communicate?',
 value: selectedTone,
 items: toneOptions,
 onChanged: (value) => onToneChanged(value!),
 ),
 ),
 ],
 ),
 const SizedBox(height: SpacingTokens.elementSpacing),
 _DropdownField(
 label: 'What should it be an expert in?',
 value: selectedExpertise,
 items: expertiseOptions,
 onChanged: (value) => onExpertiseChanged(value!),
 ),
 
 const SizedBox(height: SpacingTokens.componentSpacing),
 
 // Preview hint
 Container(
 padding: const EdgeInsets.all(SpacingTokens.componentSpacing),
 decoration: BoxDecoration(
 color: colors.primary.withValues(alpha: 0.05),
 borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
 border: Border.all(color: colors.primary.withValues(alpha: 0.1)),
 ),
 child: Row(
 children: [
 Icon(
 Icons.auto_awesome,
 size: 16,
 color: colors.primary.withValues(alpha: 0.7),
 ),
 const SizedBox(width: SpacingTokens.xs),
 Expanded(
 child: Text(
 "We'll create the perfect instructions for your agent based on these choices",
 style: TextStyles.caption.copyWith(
 color: colors.primary.withValues(alpha: 0.8),
 ),
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 ] else ...[
 // Advanced Mode
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Write custom instructions for your agent',
 style: TextStyles.bodySmall.copyWith(
 color: colors.onSurfaceVariant,
 fontWeight: FontWeight.w500,
 ),
 ),
 const SizedBox(height: SpacingTokens.xs),
 _FormField(
 label: '',
 controller: systemPromptController,
 placeholder: 'Enter detailed system prompt to guide agent behavior...',
 maxLines: 6,
 ),
 ],
 ),
 ],
 ],
 );
 }
}

class _CreativitySlider extends StatelessWidget {
 final double value;
 final ValueChanged<double> onChanged;

 const _CreativitySlider({
 required this.value,
 required this.onChanged,
 });

 @override
 Widget build(BuildContext context) {
 final colors = ThemeColors(context);
 String getCreativityLabel(double value) {
 if (value <= 0.3) return 'Focused';
 if (value <= 0.7) return 'Balanced';
 if (value <= 1.2) return 'Creative';
 return 'Very Creative';
 }

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text(
 'Creativity level',
 style: TextStyles.bodySmall.copyWith(
 color: colors.onSurfaceVariant,
 fontWeight: FontWeight.w500,
 ),
 ),
 Container(
 padding: const EdgeInsets.symmetric(
 horizontal: SpacingTokens.xs,
 vertical: 2,
 ),
 decoration: BoxDecoration(
 color: colors.primary.withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(4),
 ),
 child: Text(
 getCreativityLabel(value),
 style: TextStyles.caption.copyWith(
 color: colors.primary,
 fontWeight: FontWeight.w600,
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 4),
 Column(
 children: [
 SizedBox(
 height: 20,
 child: Slider(
 value: value,
 min: 0.0,
 max: 2.0,
 onChanged: onChanged,
 activeColor: colors.primary,
 inactiveColor: colors.border,
 ),
 ),
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text(
 '🎯 Focused',
 style: TextStyles.caption.copyWith(
 color: colors.onSurfaceVariant,
 fontSize: 10,
 ),
 ),
 Text(
 '🎨 Creative',
 style: TextStyles.caption.copyWith(
 color: colors.onSurfaceVariant,
 fontSize: 10,
 ),
 ),
 ],
 ),
 ],
 ),
 ],
 );
 }
}

class _ResponseLengthSlider extends StatelessWidget {
 final double value;
 final ValueChanged<double> onChanged;

 const _ResponseLengthSlider({
 required this.value,
 required this.onChanged,
 });

 @override
 Widget build(BuildContext context) {
 final colors = ThemeColors(context);
 String getLengthLabel(double value) {
 if (value <= 512) return 'Brief';
 if (value <= 1024) return 'Balanced';
 if (value <= 2048) return 'Detailed';
 return 'Very Detailed';
 }

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text(
 'Response length',
 style: TextStyles.bodySmall.copyWith(
 color: colors.onSurfaceVariant,
 fontWeight: FontWeight.w500,
 ),
 ),
 Container(
 padding: const EdgeInsets.symmetric(
 horizontal: SpacingTokens.xs,
 vertical: 2,
 ),
 decoration: BoxDecoration(
 color: colors.surfaceVariant,
 borderRadius: BorderRadius.circular(4),
 ),
 child: Text(
 getLengthLabel(value),
 style: TextStyles.caption.copyWith(
 color: colors.onSurface,
 fontWeight: FontWeight.w600,
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 4),
 Column(
 children: [
 SizedBox(
 height: 20,
 child: Slider(
 value: value,
 min: 256,
 max: 4096,
 divisions: 15,
 onChanged: onChanged,
 activeColor: colors.primary,
 inactiveColor: colors.border,
 ),
 ),
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text(
 '📝 Brief',
 style: TextStyles.caption.copyWith(
 color: colors.onSurfaceVariant,
 fontSize: 10,
 ),
 ),
 Text(
 '📚 Detailed',
 style: TextStyles.caption.copyWith(
 color: colors.onSurfaceVariant,
 fontSize: 10,
 ),
 ),
 ],
 ),
 ],
 ),
 ],
 );
 }
}

class MCPServer {
 final String name;
 final IconData icon;
 final String description;

 MCPServer(this.name, this.icon, this.description);
}

class _MCPSetupGuideButton extends StatelessWidget {
 final VoidCallback onPressed;

 const _MCPSetupGuideButton({required this.onPressed});

 @override
 Widget build(BuildContext context) {
 final colors = ThemeColors(context);
 
 return AsmblButton.outline(
 text: 'Need help setting up tools?',
 icon: Icons.help_outline,
 onPressed: onPressed,
 size: AsmblButtonSize.small,
 );
 }
}

class MCPSetupDialog extends StatefulWidget {
 const MCPSetupDialog({super.key});

 @override
 State<MCPSetupDialog> createState() => _MCPSetupDialogState();
}

class _MCPSetupDialogState extends State<MCPSetupDialog>
 with TickerProviderStateMixin {
 late TabController _tabController;
 String _selectedPlatform = 'claude_desktop';

 final Map<String, Map<String, String>> _platforms = {
 'claude_desktop': {
 'name': 'Claude Desktop',
 'icon': '🖥️',
 'description': 'Official Anthropic app with built-in MCP support',
 'difficulty': 'Easy',
 'time': '5 minutes'
 },
 'vs_code': {
 'name': 'VS Code',
 'icon': '📝',
 'description': 'Code editor with MCP extension support',
 'difficulty': 'Easy', 
 'time': '3 minutes'
 },
 'custom': {
 'name': 'Custom Integration',
 'icon': '🔧',
 'description': 'Advanced setup for other AI platforms',
 'difficulty': 'Advanced',
 'time': '15 minutes'
 },
 };

 @override
 void initState() {
 super.initState();
 _tabController = TabController(length: 3, vsync: this);
 }

 @override
 void dispose() {
 _tabController.dispose();
 super.dispose();
 }

 @override
 Widget build(BuildContext context) {
 final colors = ThemeColors(context);
 
 return Dialog(
 backgroundColor: Colors.transparent,
 child: AsmblCardEnhanced.outlined(
 isInteractive: false,
 child: Container(
 width: 700,
 constraints: const BoxConstraints(maxHeight: 600),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Header
 Row(
 children: [
 Icon(
 Icons.build_circle_outlined,
 size: 24,
 color: colors.primary,
 ),
 const SizedBox(width: SpacingTokens.componentSpacing),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'MCP Server Setup Guide',
 style: TextStyles.pageTitle.copyWith(
 color: colors.onSurface,
 ),
 ),
 Text(
 'Connect powerful tools to your AI agents',
 style: TextStyles.bodyMedium.copyWith(
 color: colors.onSurfaceVariant,
 ),
 ),
 ],
 ),
 ),
 IconButton(
 onPressed: () => Navigator.of(context).pop(),
 icon: const Icon(Icons.close),
 style: IconButton.styleFrom(
 foregroundColor: colors.onSurfaceVariant,
 ),
 ),
 ],
 ),
 
 const SizedBox(height: SpacingTokens.elementSpacing),
 
 // Platform Selection
 Container(
 padding: const EdgeInsets.all(SpacingTokens.componentSpacing),
 decoration: BoxDecoration(
 color: colors.surfaceVariant.withValues(alpha: 0.3),
 borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Choose your AI platform:',
 style: TextStyles.bodyMedium.copyWith(
 fontWeight: FontWeight.w600,
 color: colors.onSurface,
 ),
 ),
 const SizedBox(height: SpacingTokens.componentSpacing),
 Row(
 children: _platforms.entries.map((entry) {
 final platform = entry.value;
 final isSelected = _selectedPlatform == entry.key;
 
 return Expanded(
 child: Padding(
 padding: const EdgeInsets.only(right: SpacingTokens.componentSpacing),
 child: GestureDetector(
 onTap: () => setState(() => _selectedPlatform = entry.key),
 child: Container(
 padding: const EdgeInsets.all(SpacingTokens.componentSpacing),
 decoration: BoxDecoration(
 color: isSelected 
 ? colors.primary.withValues(alpha: 0.1)
 : colors.surface,
 borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
 border: Border.all(
 color: isSelected ? colors.primary : colors.border,
 width: isSelected ? 2 : 1,
 ),
 ),
 child: Column(
 children: [
 Text(
 platform['icon']!,
 style: const TextStyle(fontSize: 24),
 ),
 const SizedBox(height: SpacingTokens.xs),
 Text(
 platform['name']!,
 style: TextStyles.bodySmall.copyWith(
 fontWeight: FontWeight.w600,
 color: isSelected ? colors.primary : colors.onSurface,
 ),
 ),
 const SizedBox(height: 4),
 Text(
 platform['difficulty']!,
 style: TextStyles.caption.copyWith(
 color: colors.onSurfaceVariant,
 ),
 ),
 ],
 ),
 ),
 ),
 ),
 );
 }).toList(),
 ),
 ],
 ),
 ),
 
 const SizedBox(height: SpacingTokens.elementSpacing),
 
 // Setup Instructions
 Expanded(
 child: SingleChildScrollView(
 child: _buildSetupInstructions(),
 ),
 ),
 
 const SizedBox(height: SpacingTokens.elementSpacing),
 
 // Footer
 Row(
 mainAxisAlignment: MainAxisAlignment.end,
 children: [
 AsmblButton.secondary(
 text: 'Close',
 onPressed: () => Navigator.of(context).pop(),
 size: AsmblButtonSize.medium,
 ),
 const SizedBox(width: SpacingTokens.componentSpacing),
 AsmblButton.accent(
 text: 'Open Documentation',
 icon: Icons.open_in_new,
 onPressed: () {
 // Open MCP documentation in browser
 Navigator.of(context).pop();
 },
 size: AsmblButtonSize.medium,
 ),
 ],
 ),
 ],
 ),
 ),
 ),
 );
 }

 Widget _buildSetupInstructions() {
 final colors = ThemeColors(context);
 
 switch (_selectedPlatform) {
 case 'claude_desktop':
 return _buildClaudeDesktopSetup(colors);
 case 'vs_code':
 return _buildVSCodeSetup(colors);
 case 'custom':
 return _buildCustomSetup(colors);
 default:
 return Container();
 }
 }

 Widget _buildClaudeDesktopSetup(ThemeColors colors) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildStepCard(
 colors,
 '1',
 'Install Prerequisites',
 'Make sure you have Python 3.10+ and Claude Desktop app installed',
 [
 '• Download Python from python.org (3.10 or higher required)',
 '• Install Claude Desktop app from anthropic.com',
 '• Verify installation: Open terminal and run "python --version"'
 ],
 ),
 const SizedBox(height: SpacingTokens.componentSpacing),
 _buildStepCard(
 colors,
 '2',
 'Install uv Package Manager',
 'Install the modern Python package manager for MCP servers',
 [
 '• Run: curl -LsSf https://astral.sh/uv/install.sh | sh',
 '• Or on Windows: winget install astral-sh.uv',
 '• Restart your terminal after installation'
 ],
 ),
 const SizedBox(height: SpacingTokens.componentSpacing),
 _buildStepCard(
 colors,
 '3',
 'Create MCP Server Project',
 'Set up a directory for your MCP servers',
 [
 '• Run: uv init my-mcp-servers',
 '• Run: cd my-mcp-servers',
 '• Run: uv venv',
 '• Run: uv add "mcp[cli]" httpx'
 ],
 ),
 const SizedBox(height: SpacingTokens.componentSpacing),
 _buildStepCard(
 colors,
 '4',
 'Configure Claude Desktop',
 'Add MCP servers to Claude Desktop configuration',
 [
 '• Edit: ~/Library/Application Support/Claude/claude_desktop_config.json (Mac)',
 '• Or: %APPDATA%\\Claude\\claude_desktop_config.json (Windows)',
 '• Add your server configuration with absolute paths',
 '• Restart Claude Desktop app'
 ],
 ),
 ],
 );
 }

 Widget _buildVSCodeSetup(ThemeColors colors) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildStepCard(
 colors,
 '1',
 'Update VS Code',
 'Make sure you have VS Code 1.102 or higher',
 [
 '• Update VS Code to the latest version',
 '• MCP support is built-in (no extension needed)',
 '• Check version in Help → About'
 ],
 ),
 const SizedBox(height: SpacingTokens.componentSpacing),
 _buildStepCard(
 colors,
 '2',
 'Enable MCP Support',
 'Configure VS Code to use MCP servers',
 [
 '• Open Command Palette (Cmd/Ctrl + Shift + P)',
 '• Run: "MCP: Browse Servers"',
 '• Or search Extensions for "@mcp"',
 '• Install desired MCP servers from the marketplace'
 ],
 ),
 const SizedBox(height: SpacingTokens.componentSpacing),
 _buildStepCard(
 colors,
 '3',
 'Configure MCP Settings',
 'Adjust MCP behavior in VS Code settings',
 [
 '• Open Settings (Cmd/Ctrl + ,)',
 '• Search for "chat.mcp.enabled"',
 '• Enable MCP support',
 '• Configure trusted server sources'
 ],
 ),
 ],
 );
 }

 Widget _buildCustomSetup(ThemeColors colors) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 padding: const EdgeInsets.all(SpacingTokens.componentSpacing),
 decoration: BoxDecoration(
 color: colors.primary.withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Icon(Icons.warning_amber, color: colors.primary, size: 20),
 const SizedBox(width: SpacingTokens.xs),
 Text(
 'Advanced Setup Required',
 style: TextStyles.bodyMedium.copyWith(
 fontWeight: FontWeight.w600,
 color: colors.primary,
 ),
 ),
 ],
 ),
 const SizedBox(height: SpacingTokens.xs),
 Text(
 'Custom integration requires programming knowledge and API configuration.',
 style: TextStyles.bodySmall.copyWith(
 color: colors.onSurface,
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: SpacingTokens.componentSpacing),
 _buildStepCard(
 colors,
 '1',
 'Set up MCP Server',
 'Create a standalone MCP server instance',
 [
 '• Create Python project with MCP SDK',
 '• Implement server interface for your AI platform',
 '• Handle authentication and communication protocols',
 ],
 ),
 const SizedBox(height: SpacingTokens.componentSpacing),
 _buildStepCard(
 colors,
 '2',
 'Create API Bridge',
 'Build connection between your AI platform and MCP servers',
 [
 '• Implement HTTP/WebSocket bridge server',
 '• Handle message routing and protocol conversion',
 '• Set up authentication and security measures',
 ],
 ),
 const SizedBox(height: SpacingTokens.componentSpacing),
 _buildStepCard(
 colors,
 '3',
 'Platform Integration',
 'Connect your AI platform to the MCP bridge',
 [
 '• Configure your AI platform to use external tools',
 '• Set up API endpoints and webhook handlers',
 '• Test integration with sample MCP server calls',
 ],
 ),
 ],
 );
 }

 Widget _buildStepCard(ThemeColors colors, String stepNumber, String title, String description, List<String> instructions) {
 return Container(
 padding: const EdgeInsets.all(SpacingTokens.componentSpacing),
 decoration: BoxDecoration(
 color: colors.surface,
 borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
 border: Border.all(color: colors.border),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 width: 28,
 height: 28,
 decoration: BoxDecoration(
 color: colors.primary,
 borderRadius: BorderRadius.circular(14),
 ),
 child: Center(
 child: Text(
 stepNumber,
 style: TextStyles.bodyMedium.copyWith(
 color: Colors.white,
 fontWeight: FontWeight.w600,
 ),
 ),
 ),
 ),
 const SizedBox(width: SpacingTokens.componentSpacing),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 title,
 style: TextStyles.bodyMedium.copyWith(
 fontWeight: FontWeight.w600,
 color: colors.onSurface,
 ),
 ),
 Text(
 description,
 style: TextStyles.bodySmall.copyWith(
 color: colors.onSurfaceVariant,
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 const SizedBox(height: SpacingTokens.componentSpacing),
 ...instructions.map((instruction) => Padding(
 padding: const EdgeInsets.only(left: 40, bottom: 4),
 child: Text(
 instruction,
 style: TextStyles.bodySmall.copyWith(
 color: colors.onSurfaceVariant,
 ),
 ),
 )),
 ],
 ),
 );
 }
}

class _MasterPromptPreview extends StatelessWidget {
  final String name;
  final String description;
  final String personality;
  final String tone;
  final String expertise;
  final String systemPrompt;
  final bool showAdvancedPrompt;

  const _MasterPromptPreview({
    required this.name,
    required this.description,
    required this.personality,
    required this.tone,
    required this.expertise,
    required this.systemPrompt,
    required this.showAdvancedPrompt,
  });

  @override
  Widget build(BuildContext context) {
    final colors = ThemeColors(context);
    final masterPrompt = _buildMasterPrompt();

    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
        border: Border.all(color: colors.border.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(SpacingTokens.sm),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(BorderRadiusTokens.lg),
                topRight: Radius.circular(BorderRadiusTokens.lg),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.smart_toy_outlined, size: 16, color: colors.primary),
                const SizedBox(width: SpacingTokens.xs),
                Text('Master Prompt for $name', style: TextStyles.bodySmall.copyWith(color: colors.primary, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${masterPrompt.length} characters', style: TextStyles.caption.copyWith(color: colors.onSurfaceVariant)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(SpacingTokens.sm),
              child: SingleChildScrollView(
                child: SelectableText(masterPrompt, style: TextStyles.bodySmall.copyWith(fontFamily: 'monospace', color: colors.onSurface, height: 1.4)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _buildMasterPrompt() {
    final buffer = StringBuffer();
    buffer.writeln('You are $name, an AI assistant.');
    if (description.isNotEmpty) buffer.writeln('\nRole: $description');
    buffer.writeln('\nPersonality: $personality');
    buffer.writeln('Communication Style: $tone');
    buffer.writeln('Expertise: $expertise');
    if (showAdvancedPrompt && systemPrompt.isNotEmpty) {
      buffer.writeln('\nAdditional Instructions:');
      buffer.writeln(systemPrompt);
    }
    buffer.writeln('\nGuidelines:');
    buffer.writeln('- Always be helpful, accurate, and respectful');
    buffer.writeln('- Provide clear, well-structured responses');
    buffer.writeln('- Ask for clarification when needed');
    buffer.writeln('- Stay within your area of expertise');
    return buffer.toString();
  }
}

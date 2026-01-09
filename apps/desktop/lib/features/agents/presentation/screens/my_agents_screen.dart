import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:agent_engine_core/services/agent_service.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../providers/agent_provider.dart';
import 'package:agent_engine_core/models/agent.dart';
import '../widgets/enhanced_agent_card.dart';
import '../widgets/enhanced_agent_template_card.dart';
import '../../../agents/data/models/agent_template.dart';

class MyAgentsScreen extends ConsumerStatefulWidget {
 const MyAgentsScreen({super.key});

 @override
 ConsumerState<MyAgentsScreen> createState() => _MyAgentsScreenState();
}

class _MyAgentsScreenState extends ConsumerState<MyAgentsScreen> {
 int selectedTab = 0; // 0 = My AI Team, 1 = Hire AI Employee
 String searchQuery = '';
 String selectedCategory = 'All';
 String agentSearchQuery = '';
 AgentStatus? selectedAgentStatus;
 String agentSortBy = 'name'; // 'name', 'created', 'status', 'lastUsed'
 bool sortAscending = true;

 final List<String> categories = [
 'All', 'Research', 'Development', 'Writing', 'Data Analysis', 
 'Customer Support', 'Marketing', 'Design', 'DevOps', 'Security',
 'Product', 'Database', 'API', 'Blockchain', 'QA', 'AI/ML',
 'Content Creation', 'IoT', 'Gaming', 'Robotics', 'AR/VR',
 'Quantum', 'Bioinformatics', 'Finance', 'E-commerce', 'Cloud',
 'Automation', 'Mobile', 'Real Estate', 'Legal', 'Healthcare'
 ];


 final List<AgentTemplate> templates = [
 AgentTemplate(
 name: 'Research Assistant',
 description: 'Academic research agent with citation management and fact-checking',
 category: 'Research',
 tags: ['academic', 'citations', 'fact-checking'],
 mcpStack: true,
 mcpServers: ['brave-search', 'memory', 'filesystem'],
 exampleUse: 'Find recent papers on quantum computing with proper citations',
 popularity: 95,
 reasoningFlow: ReasoningFlow.hierarchical,
 recommendedModel: RecommendedLLM.claude35Sonnet,
 alternativeModels: [RecommendedLLM.gpt4o, RecommendedLLM.gemini15Pro],
 taskOutline: [
   'Parse research query and identify key concepts',
   'Search academic databases for relevant papers',
   'Evaluate source credibility and relevance',
   'Extract key findings and methodologies',
   'Format citations according to style guide',
   'Synthesize findings into coherent summary'
 ],
 ),
 AgentTemplate(
 name: 'Code Reviewer',
 description: 'Automated code review with best practices and security checks',
 category: 'Development',
 tags: ['code-review', 'security', 'best-practices'],
 mcpStack: true,
 mcpServers: ['github', 'git', 'filesystem', 'memory'],
 exampleUse: 'Review React components for security vulnerabilities',
 popularity: 87,
 reasoningFlow: ReasoningFlow.parallel,
 recommendedModel: RecommendedLLM.deepseekR1,
 alternativeModels: [RecommendedLLM.gpt4o, RecommendedLLM.claude35Sonnet],
 taskOutline: [
   'Parse code structure and dependencies',
   'Run security vulnerability scans',
   'Check coding standards compliance',
   'Analyze performance implications',
   'Generate detailed feedback report',
   'Suggest specific improvements'
 ],
 ),
 AgentTemplate(
 name: 'Content Writer',
 description: 'SEO-optimized content generation with tone customization',
 category: 'Writing',
 tags: ['seo', 'content', 'marketing'],
 mcpStack: true,
 mcpServers: ['brave-search', 'web-fetch', 'memory', 'filesystem'],
 exampleUse: 'Create engaging blog posts about sustainable technology',
 popularity: 92,
 reasoningFlow: ReasoningFlow.iterative,
 recommendedModel: RecommendedLLM.claude35Sonnet,
 alternativeModels: [RecommendedLLM.gpt4o, RecommendedLLM.llama32],
 taskOutline: [
   'Analyze topic and target keywords',
   'Research current trends and competitor content',
   'Generate initial content outline',
   'Write draft with SEO optimization',
   'Review and refine for tone consistency',
   'Finalize with meta descriptions and tags'
 ],
 ),
 AgentTemplate(
 name: 'Data Analyst',
 description: 'Statistical analysis and visualization for business insights',
 category: 'Data Analysis',
 tags: ['statistics', 'visualization', 'insights'],
 mcpStack: true,
 mcpServers: ['postgres', 'python', 'jupyter', 'memory', 'filesystem'],
 exampleUse: 'Analyze customer churn patterns and create visualizations',
 popularity: 78,
 recommendedModel: RecommendedLLM.gpt4o,
 alternativeModels: [RecommendedLLM.deepseekR1, RecommendedLLM.claude35Sonnet],
 ),
 AgentTemplate(
 name: 'Customer Support Bot',
 description: 'Intelligent support agent with ticket management integration',
 category: 'Customer Support',
 tags: ['support', 'tickets', 'automation'],
 mcpStack: true,
 mcpServers: ['jira', 'slack', 'zendesk', 'memory'],
 exampleUse: 'Handle customer inquiries and route tickets efficiently',
 popularity: 89,
 recommendedModel: RecommendedLLM.gpt4oMini,
 alternativeModels: [RecommendedLLM.claude35Haiku, RecommendedLLM.llama32],
 ),
 AgentTemplate(
 name: 'Marketing Strategist',
 description: 'Campaign planning and performance analysis agent',
 category: 'Marketing',
 tags: ['campaigns', 'strategy', 'analytics'],
 mcpStack: true,
 mcpServers: ['brave-search', 'google-analytics', 'notion', 'memory'],
 exampleUse: 'Plan social media campaigns with performance tracking',
 popularity: 84,
 recommendedModel: RecommendedLLM.claude35Sonnet,
 alternativeModels: [RecommendedLLM.gpt4o, RecommendedLLM.gemini15Pro],
 ),
 AgentTemplate(
 name: 'Design Agent',
 description: 'Visual design assistant with interactive canvas, Material Design components, and prototyping capabilities',
 category: 'Design',
 tags: ['material-design', 'ui-ux', 'canvas', 'prototyping', 'components', 'wireframes'],
 mcpStack: true,
 mcpServers: ['figma', 'github', 'canvas-mcp', 'filesystem', 'memory'],
 exampleUse: 'Create Material Design wireframes and generate component code',
 popularity: 95,
 reasoningFlow: ReasoningFlow.iterative,
 recommendedModel: RecommendedLLM.llava13b,
 alternativeModels: [RecommendedLLM.gpt4o, RecommendedLLM.gemini15Pro],
 taskOutline: [
   'Analyze design requirements and user needs',
   'Create wireframes and mockups on interactive canvas',
   'Apply Material Design 3 principles and guidelines',
   'Generate responsive component structures',
   'Iterate based on feedback and design principles',
   'Export design assets and component code'
 ],
 ),
 // DevOps & Infrastructure
 AgentTemplate(
 name: 'DevOps Engineer',
 description: 'Infrastructure automation and deployment specialist',
 category: 'DevOps',
 tags: ['docker', 'kubernetes', 'aws', 'ci-cd', 'automation'],
 mcpStack: true,
 mcpServers: ['aws', 'docker', 'kubernetes', 'shell', 'memory'],
 exampleUse: 'Automate deployment pipelines and manage cloud infrastructure',
 popularity: 88,
 recommendedModel: RecommendedLLM.deepseekR1,
 alternativeModels: [RecommendedLLM.gpt4o, RecommendedLLM.claude35Sonnet],
 ),
 AgentTemplate(
 name: 'Database Administrator',
 description: 'Database optimization with PostgreSQL and Redis',
 category: 'Database',
 tags: ['postgresql', 'mysql', 'redis', 'mongodb', 'optimization'],
 mcpStack: true,
 mcpServers: ['postgres', 'mysql', 'redis', 'mongodb', 'memory'],
 exampleUse: 'Optimize database queries and manage backup strategies',
 popularity: 82,
 recommendedModel: RecommendedLLM.deepseekR1,
 alternativeModels: [RecommendedLLM.gpt4o, RecommendedLLM.llama32],
 ),
 // Security
 AgentTemplate(
 name: 'Security Analyst',
 description: 'Cybersecurity expert with penetration testing tools',
 category: 'Security',
 tags: ['pentesting', 'nmap', 'metasploit', 'vulnerability', 'ethical-hacking'],
 mcpStack: true,
 mcpServers: ['nmap', 'burp-suite', 'filesystem', 'shell', 'memory'],
 exampleUse: 'Conduct security audits and vulnerability assessments',
 popularity: 85,
 recommendedModel: RecommendedLLM.gpt4o,
 alternativeModels: [RecommendedLLM.deepseekR1, RecommendedLLM.claude35Sonnet],
 ),
 // Product & Analytics
 AgentTemplate(
 name: 'Product Manager',
 description: 'Product strategy with Jira and analytics integration',
 category: 'Product',
 tags: ['jira', 'analytics', 'roadmap', 'stakeholder', 'metrics'],
 mcpStack: true,
 mcpServers: ['jira', 'google-analytics', 'slack', 'memory', 'filesystem'],
 exampleUse: 'Plan product roadmaps and track success metrics',
 popularity: 86,
 recommendedModel: RecommendedLLM.claude35Sonnet,
 alternativeModels: [RecommendedLLM.gpt4o, RecommendedLLM.gemini15Pro],
 ),
 AgentTemplate(
 name: 'Data Scientist',
 description: 'ML/AI specialist with Python and data analysis tools',
 category: 'Data Analysis',
 tags: ['python', 'jupyter', 'machine-learning', 'visualization', 'sql'],
 mcpStack: true,
 mcpServers: ['python', 'jupyter', 'postgres', 'memory', 'filesystem'],
 exampleUse: 'Build ML models and analyze complex datasets',
 popularity: 90,
 recommendedModel: RecommendedLLM.gpt4o,
 alternativeModels: [RecommendedLLM.deepseekR1, RecommendedLLM.claude35Sonnet],
 ),
 // API & Development
 AgentTemplate(
 name: 'API Architect',
 description: 'RESTful and GraphQL API design specialist',
 category: 'API',
 tags: ['rest', 'graphql', 'openapi', 'postman', 'microservices'],
 mcpStack: true,
 mcpServers: ['postman', 'swagger-ui', 'graphql', 'memory', 'filesystem'],
 exampleUse: 'Design robust APIs with comprehensive documentation',
 popularity: 83,
 recommendedModel: RecommendedLLM.deepseekR1,
 alternativeModels: [RecommendedLLM.gpt4o, RecommendedLLM.claude35Sonnet],
 ),
 AgentTemplate(
 name: 'QA Automation Engineer',
 description: 'Test automation with Selenium and Cypress',
 category: 'QA',
 tags: ['selenium', 'cypress', 'jest', 'testing', 'automation'],
 mcpStack: true,
 mcpServers: ['selenium', 'browserbase', 'jest', 'github', 'memory'],
 exampleUse: 'Create comprehensive test suites and automation frameworks',
 popularity: 81,
 recommendedModel: RecommendedLLM.deepseekR1,
 alternativeModels: [RecommendedLLM.gpt4o, RecommendedLLM.llama32],
 ),
 // Blockchain & Web3
 AgentTemplate(
 name: 'Blockchain Developer',
 description: 'Smart contract and Web3 development expert',
 category: 'Blockchain',
 tags: ['ethereum', 'solidity', 'web3', 'defi', 'smart-contracts'],
 mcpStack: true,
 mcpServers: ['ethereum', 'ipfs', 'the-graph', 'memory', 'filesystem'],
 exampleUse: 'Develop and audit smart contracts for DeFi protocols',
 popularity: 79,
 recommendedModel: RecommendedLLM.gpt4o,
 alternativeModels: [RecommendedLLM.deepseekR1, RecommendedLLM.claude35Sonnet],
 ),
 AgentTemplate(
 name: 'UX Designer',
 description: 'User experience design with Figma integration',
 category: 'Design',
 tags: ['figma', 'ux', 'user-research', 'prototyping', 'accessibility'],
 mcpStack: true,
 mcpServers: ['figma', 'hotjar', 'airtable', 'memory', 'filesystem'],
 exampleUse: 'Create user-centered designs with comprehensive research',
 popularity: 87,
 recommendedModel: RecommendedLLM.llava13b,
 alternativeModels: [RecommendedLLM.gpt4o, RecommendedLLM.gemini15Pro],
 ),
 // Coming Soon - AI/ML
 AgentTemplate(
 name: 'AI Model Trainer',
 description: 'Fine-tuning and training custom AI models',
 category: 'AI/ML',
 tags: ['huggingface', 'fine-tuning', 'wandb', 'gpu', 'training'],
 mcpStack: true,
 mcpServers: ['huggingface', 'openai', 'wandb', 'aws', 'memory'],
 exampleUse: 'Fine-tune LLMs for domain-specific applications',
 popularity: 93,
 isComingSoon: true,
 ),
 // Coming Soon - Content Creation
 AgentTemplate(
 name: 'Video Content Creator',
 description: 'AI-powered video editing and generation',
 category: 'Content Creation',
 tags: ['runway', 'elevenlabs', 'youtube', 'premiere', 'video-ai'],
 mcpStack: true,
 mcpServers: ['runway', 'elevenlabs', 'youtube', 'adobe-creative', 'memory'],
 exampleUse: 'Create and edit videos with AI-powered tools',
 popularity: 89,
 isComingSoon: true,
 ),
 // Coming Soon - IoT
 AgentTemplate(
 name: 'IoT Systems Engineer',
 description: 'IoT device management and edge computing',
 category: 'IoT',
 tags: ['mqtt', 'azure-iot', 'influxdb', 'edge', 'sensors'],
 mcpStack: true,
 mcpServers: ['azure-iot', 'aws-iot', 'influxdb', 'mqtt', 'memory'],
 exampleUse: 'Manage IoT devices and process sensor data streams',
 popularity: 76,
 isComingSoon: true,
 ),
 // Coming Soon - Gaming
 AgentTemplate(
 name: 'Game Developer',
 description: 'Game development with Unity and Unreal integration',
 category: 'Gaming',
 tags: ['unity', 'unreal', 'steam', 'playfab', 'gamedev'],
 mcpStack: true,
 mcpServers: ['unity', 'steam', 'playfab', 'github', 'memory'],
 exampleUse: 'Develop games with automated testing and deployment',
 popularity: 80,
 isComingSoon: true,
 ),
 // Coming Soon - Robotics
 AgentTemplate(
 name: 'Robotics Engineer',
 description: 'ROS integration and robot control systems',
 category: 'Robotics',
 tags: ['ros', 'gazebo', 'opencv', 'arduino', 'control-systems'],
 mcpStack: true,
 mcpServers: ['ros', 'gazebo', 'opencv', 'arduino', 'memory'],
 exampleUse: 'Program autonomous robots with computer vision',
 popularity: 74,
 isComingSoon: true,
 ),
 // Coming Soon - AR/VR
 AgentTemplate(
 name: 'AR/VR Developer',
 description: 'Augmented and Virtual Reality experiences',
 category: 'AR/VR',
 tags: ['arcore', 'oculus', 'babylon', 'blender', 'spatial'],
 mcpStack: true,
 mcpServers: ['arcore', 'oculus', 'unity', 'blender', 'memory'],
 exampleUse: 'Build immersive AR/VR applications and experiences',
 popularity: 77,
 isComingSoon: true,
 ),
 // Coming Soon - Quantum
 AgentTemplate(
 name: 'Quantum Computing Researcher',
 description: 'Quantum algorithm development and simulation',
 category: 'Quantum',
 tags: ['qiskit', 'cirq', 'aws-braket', 'pennylane', 'quantum-ml'],
 mcpStack: true,
 mcpServers: ['qiskit', 'cirq', 'aws-braket', 'pennylane', 'memory'],
 exampleUse: 'Develop quantum algorithms and run quantum simulations',
 popularity: 68,
 isComingSoon: true,
 ),
 // Coming Soon - Bioinformatics
 AgentTemplate(
 name: 'Bioinformatics Analyst',
 description: 'Genomic analysis and protein modeling',
 category: 'Bioinformatics',
 tags: ['blast', 'alphafold', 'pubmed', 'biopython', 'genomics'],
 mcpStack: true,
 mcpServers: ['blast', 'alphafold', 'pubmed', 'biopython', 'memory'],
 exampleUse: 'Analyze genomic sequences and predict protein structures',
 popularity: 71,
 isComingSoon: true,
 ),
 // Finance & Trading
 AgentTemplate(
 name: 'Financial Analyst',
 description: 'Market analysis with real-time data and trading tools',
 category: 'Finance',
 tags: ['trading', 'market-data', 'alpaca', 'financial', 'analysis'],
 mcpStack: true,
 mcpServers: ['alpaca', 'alpha-vantage', 'yahoo-finance', 'stripe', 'memory'],
 exampleUse: 'Analyze stock trends and execute automated trading strategies',
 popularity: 84,
 ),
 // E-commerce
 AgentTemplate(
 name: 'E-commerce Manager',
 description: 'Online store management with Shopify and payment integration',
 category: 'E-commerce',
 tags: ['shopify', 'stripe', 'inventory', 'orders', 'analytics'],
 mcpStack: true,
 mcpServers: ['shopify', 'stripe', 'google-analytics', 'zendesk', 'memory'],
 exampleUse: 'Manage inventory, process orders, and analyze sales performance',
 popularity: 82,
 ),
 // Cloud Infrastructure
 AgentTemplate(
 name: 'Cloud Architect',
 description: 'Multi-cloud infrastructure with Azure, AWS, and Alibaba Cloud',
 category: 'Cloud',
 tags: ['azure', 'aws', 'alibaba-cloud', 'terraform', 'monitoring'],
 mcpStack: true,
 mcpServers: ['azure', 'aws', 'alibaba-cloud', 'terraform', 'datadog', 'memory'],
 exampleUse: 'Design and deploy scalable multi-cloud architectures',
 popularity: 86,
 ),
 // Authentication & Identity
 AgentTemplate(
 name: 'Identity & Access Manager',
 description: 'Authentication and authorization with Auth0 and Asgardeo',
 category: 'Security',
 tags: ['auth0', 'asgardeo', 'identity', 'oauth', 'security'],
 mcpStack: true,
 mcpServers: ['auth0', 'asgardeo', 'okta', 'ldap', 'memory'],
 exampleUse: 'Configure SSO, manage user permissions, and audit access logs',
 popularity: 78,
 ),
 // Browser Automation
 AgentTemplate(
 name: 'Web Automation Specialist',
 description: 'Advanced browser automation with Browserbase and Puppeteer',
 category: 'Automation',
 tags: ['browserbase', 'puppeteer', 'selenium', 'scraping', 'testing'],
 mcpStack: true,
 mcpServers: ['browserbase', 'puppeteer', 'selenium', 'playwright', 'memory'],
 exampleUse: 'Automate complex web workflows and data extraction tasks',
 popularity: 79,
 ),
 // Mobile Development
 AgentTemplate(
 name: 'Mobile App Developer',
 description: 'Cross-platform mobile development with CI/CD integration',
 category: 'Mobile',
 tags: ['bitrise', 'firebase', 'react-native', 'flutter', 'ci-cd'],
 mcpStack: true,
 mcpServers: ['bitrise', 'firebase', 'expo', 'fastlane', 'memory'],
 exampleUse: 'Build, test, and deploy mobile apps with automated workflows',
 popularity: 83,
 isComingSoon: true,
 ),
 // Content Creation
 AgentTemplate(
 name: 'Visual Content Creator',
 description: 'Design automation with Canva and creative tools integration',
 category: 'Design',
 tags: ['canva', 'unsplash', 'adobe', 'creative', 'automation'],
 mcpStack: true,
 mcpServers: ['canva', 'unsplash', 'adobe-creative', 'pexels', 'memory'],
 exampleUse: 'Generate branded graphics and marketing materials automatically',
 popularity: 85,
 isComingSoon: true,
 ),
 // Real Estate
 AgentTemplate(
 name: 'Real Estate Analyst',
 description: 'Property analysis with market data and CRM integration',
 category: 'Real Estate',
 tags: ['zillow', 'mls', 'crm', 'market-analysis', 'properties'],
 mcpStack: true,
 mcpServers: ['zillow', 'mls-data', 'salesforce', 'google-maps', 'memory'],
 exampleUse: 'Analyze property values, market trends, and manage client relationships',
 popularity: 76,
 isComingSoon: true,
 ),
 // Legal & Compliance
 AgentTemplate(
 name: 'Legal Research Assistant',
 description: 'Legal document analysis and compliance checking',
 category: 'Legal',
 tags: ['westlaw', 'legal-research', 'compliance', 'documents', 'analysis'],
 mcpStack: true,
 mcpServers: ['westlaw', 'lexis-nexis', 'courthouse', 'docusign', 'memory'],
 exampleUse: 'Research case law, analyze contracts, and ensure regulatory compliance',
 popularity: 73,
 isComingSoon: true,
 ),
 // Healthcare
 AgentTemplate(
 name: 'Healthcare Data Analyst',
 description: 'Medical data analysis with FHIR and healthcare systems',
 category: 'Healthcare',
 tags: ['fhir', 'hl7', 'medical-data', 'epic', 'cerner'],
 mcpStack: true,
 mcpServers: ['fhir', 'hl7', 'epic', 'cerner', 'smart-on-fhir', 'memory'],
 exampleUse: 'Analyze patient data, generate health insights, and ensure HIPAA compliance',
 popularity: 77,
 isComingSoon: true,
 ),
 ];

 List<AgentTemplate> get filteredTemplates {
 return templates.where((template) {
 final matchesSearch = template.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
 template.description.toLowerCase().contains(searchQuery.toLowerCase()) ||
 template.tags.any((tag) => tag.toLowerCase().contains(searchQuery.toLowerCase()));
 
 final matchesCategory = selectedCategory == 'All' || template.category == selectedCategory;
 
 return matchesSearch && matchesCategory;
 }).toList();
 }

 @override
 Widget build(BuildContext context) {
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
 // Header
 const AppNavigationBar(currentRoute: AppRoutes.agents),

// Compact Header with Inline Tabs
_buildCompactHeaderWithTabs(),

 // Main Content - Direct content without redundant wrapper
 Expanded(
 child: Padding(
 padding: const EdgeInsets.fromLTRB(SpacingTokens.xxl, SpacingTokens.sm, SpacingTokens.xxl, SpacingTokens.xxl),
 child: selectedTab == 0 ? _buildMyAgentsContent() : _buildAgentLibraryContent(),
 ),
 ),
 ],
 ),
 ),
 ),
 );
 }

 Widget _buildMyAgentsContent() {
 final agentsAsync = ref.watch(agentNotifierProvider);
 
 return agentsAsync.when(
 data: (agents) {
 if (agents.isEmpty) {
 return _buildEmptyAgentsState();
 }
 
 final filteredAgents = _filterAndSortAgents(agents);
 
 return Column(
 children: [
 // Search and Filter Section for My Agents
 _buildAgentSearchAndFilter(),
 const SizedBox(height: SpacingTokens.elementSpacing),
 
 // Agents Grid
 Expanded(
 child: filteredAgents.isEmpty 
 ? _buildNoAgentsFoundState()
 : GridView.builder(
 gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
 crossAxisCount: 4,
 crossAxisSpacing: SpacingTokens.componentSpacing,
 mainAxisSpacing: SpacingTokens.componentSpacing,
 childAspectRatio: 0.9,
 ),
 itemCount: filteredAgents.length,
 itemBuilder: (context, index) {
 final agent = filteredAgents[index];
 return EnhancedAgentCard(
   agent: agent,
   onEdit: () => _editAgent(agent),
   onDelete: () => _deleteAgent(agent),
   onDuplicate: () => _duplicateAgent(agent),
 );
 },
 ),
 ),
 ],
 );
 },
 loading: () => Center(
 child: Column(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 CircularProgressIndicator(
 color: ThemeColors(context).primary,
 ),
 const SizedBox(height: SpacingTokens.componentSpacing),
 Text(
 'Loading your agents...',
 style: TextStyles.bodyMedium.copyWith(
 color: ThemeColors(context).onSurfaceVariant,
 ),
 ),
 ],
 ),
 ),
 error: (error, stack) => Center(
 child: Column(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 Icon(
 Icons.error_outline,
 size: 48,
 color: ThemeColors(context).error,
 ),
 const SizedBox(height: SpacingTokens.componentSpacing),
 Text(
 'Failed to load agents',
 style: TextStyles.bodyLarge.copyWith(
 color: ThemeColors(context).error,
 ),
 ),
 const SizedBox(height: SpacingTokens.xs),
 Text(
 error.toString(),
 style: TextStyles.bodySmall.copyWith(
 color: ThemeColors(context).onSurfaceVariant,
 ),
 textAlign: TextAlign.center,
 ),
 const SizedBox(height: SpacingTokens.componentSpacing),
 AsmblButton.secondary(
 text: 'Retry',
 onPressed: () {
 ref.invalidate(agentsProvider);
 },
 ),
 ],
 ),
 ),
 );
 }

 Widget _buildAIEmployeeHeroSection() {
   final colors = ThemeColors(context);
   return Container(
     padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
     child: Row(
       children: [
         // Quick stats row - compact inline
         _buildStatBadge(colors, '${templates.length}', 'Available'),
         const SizedBox(width: 12),
         _buildStatBadge(colors, '${categories.length - 1}', 'Categories'),
         const SizedBox(width: 12),
         _buildStatBadge(colors, 'Ready', 'To Deploy'),
       ],
     ),
   );
 }

 Widget _buildStatBadge(ThemeColors colors, String number, String label) {
   return Container(
     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
     decoration: BoxDecoration(
       color: colors.surface.withValues(alpha: 0.5),
       borderRadius: BorderRadius.circular(6),
       border: Border.all(color: colors.border.withValues(alpha: 0.5)),
     ),
     child: Row(
       mainAxisSize: MainAxisSize.min,
       children: [
         Text(
           number,
           style: TextStyle(
             fontSize: 14,
             fontWeight: FontWeight.w600,
             color: colors.primary,
           ),
         ),
         const SizedBox(width: 6),
         Text(
           label,
           style: TextStyle(
             fontSize: 12,
             color: colors.onSurfaceVariant,
           ),
         ),
       ],
     ),
   );
 }

 Widget _buildStatCard(String number, String label) {
 return Column(
 children: [
 Text(
 number,
 style: TextStyles.pageTitle.copyWith(
 color: ThemeColors(context).primary,
 fontSize: 24,
 fontWeight: FontWeight.bold,
 ),
 ),
 Text(
 label,
 style: TextStyles.bodySmall.copyWith(
 color: ThemeColors(context).onSurfaceVariant,
 ),
 ),
 ],
 );
 }

 Widget _buildAgentLibraryContent() {
 return Column(
 children: [
 // Hero section for AI Employees
 _buildAIEmployeeHeroSection(),
 
 const SizedBox(height: SpacingTokens.xl),
 
 // Search and Filter Section - Responsive Layout
 LayoutBuilder(
 builder: (context, constraints) {
 // Determine if we should stack (when width is less than 800px)
 final shouldStack = constraints.maxWidth < 800;
 
 if (shouldStack) {
 // Stacked layout for smaller screens
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Search Bar (full width when stacked)
 AsmblCard(
 child: TextField(
 onChanged: (value) => setState(() => searchQuery = value),
 decoration: InputDecoration(
 hintText: 'Search templates...',
 hintStyle: TextStyles.bodyMedium.copyWith(
 color: ThemeColors(context).onSurfaceVariant,
 ),
 prefixIcon: Icon(
 Icons.search,
 color: ThemeColors(context).onSurfaceVariant,
 size: 18,
 ),
 border: InputBorder.none,
 contentPadding: const EdgeInsets.symmetric(
 horizontal: SpacingTokens.componentSpacing, 
 vertical: SpacingTokens.sm,
 ),
 ),
 style: TextStyles.bodyMedium.copyWith(color: ThemeColors(context).onSurface),
 ),
 ),
 const SizedBox(height: SpacingTokens.componentSpacing),
 
 // Filter Chips
 Wrap(
 spacing: SpacingTokens.sm,
 runSpacing: SpacingTokens.sm,
 children: _buildFilterChips(),
 ),
 ],
 );
 } else {
 // Horizontal layout for larger screens
 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Search Bar (flexible width)
 Expanded(
 flex: 2,
 child: AsmblCard(
 child: TextField(
 onChanged: (value) => setState(() => searchQuery = value),
 decoration: InputDecoration(
 hintText: 'Search templates...',
 hintStyle: TextStyles.bodyMedium.copyWith(
 color: ThemeColors(context).onSurfaceVariant,
 ),
 prefixIcon: Icon(
 Icons.search,
 color: ThemeColors(context).onSurfaceVariant,
 size: 18,
 ),
 border: InputBorder.none,
 contentPadding: const EdgeInsets.symmetric(
 horizontal: SpacingTokens.componentSpacing, 
 vertical: SpacingTokens.sm,
 ),
 ),
 style: TextStyles.bodyMedium.copyWith(color: ThemeColors(context).onSurface),
 ),
 ),
 ),
 const SizedBox(width: SpacingTokens.componentSpacing),
 
 // Filter Chips (flexible width)
 Expanded(
 flex: 3,
 child: Wrap(
 spacing: SpacingTokens.sm,
 runSpacing: SpacingTokens.sm,
 children: _buildFilterChips(),
 ),
 ),
 ],
 );
 }
 },
 ),
 const SizedBox(height: SpacingTokens.elementSpacing),
 // Templates Grid
 Expanded(
 child: filteredTemplates.isEmpty 
 ? _buildEmptyState()
 : GridView.builder(
 gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
 crossAxisCount: 4,
 crossAxisSpacing: SpacingTokens.componentSpacing,
 mainAxisSpacing: SpacingTokens.componentSpacing,
 childAspectRatio: 0.8,
 ),
 itemCount: filteredTemplates.length,
 itemBuilder: (context, index) {
 return EnhancedAgentTemplateCard(
 template: filteredTemplates[index],
 onUseTemplate: () => _createFromTemplate(filteredTemplates[index]),
 onPreview: () => _previewTemplate(filteredTemplates[index]),
 );
 },
 ),
 ),
 ],
 );
 }

 void _createFromTemplate(AgentTemplate template) async {
   final colors = ThemeColors(context);
   
   try {
     // Show loading dialog
     showDialog(
       context: context,
       barrierDismissible: false,
       builder: (context) => AlertDialog(
         backgroundColor: colors.surface,
         content: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             CircularProgressIndicator(color: colors.primary),
             const SizedBox(height: SpacingTokens.lg),
             Text(
               'Creating agent from template...',
               style: TextStyles.bodyMedium.copyWith(color: colors.onSurface),
             ),
           ],
         ),
       ),
     );

     // Create agent from template using basic agent service
     final agentService = ServiceLocator.instance.get<AgentService>();
     final capabilities = _getCapabilitiesFromTemplate(template);
     
     print('🔧 Creating agent with capabilities: $capabilities');
     
     final newAgent = Agent(
       id: 'agent_${DateTime.now().millisecondsSinceEpoch}',
       name: template.name.replaceAll(' Template', '').replaceAll(' (Template)', ''),
       description: template.description,
       capabilities: capabilities,
       configuration: {
         'systemPrompt': _generateSystemPromptFromTemplate(template),
         'temperature': 0.7,
         'maxTokens': 2048,
         'source_template': template.name,
         'category': template.category,
         'mcpServers': template.mcpServers,
         'createdAt': DateTime.now().toIso8601String(),
         'fromTemplate': true,
       },
     );
     
     final createdAgent = await agentService.createAgent(newAgent);
     
     print('✅ Agent created from template: ${createdAgent.name} (ID: ${createdAgent.id})');
     
     // Close loading dialog
     if (context.mounted) {
       Navigator.of(context).pop();
       
       // Show success message with template-specific routing
       final bool isDesignAgent = template.category == 'Design';
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text(
             'Agent "${createdAgent.name}" created from template!',
             style: TextStyles.bodyMedium.copyWith(color: Colors.white),
           ),
           backgroundColor: colors.success,
           action: SnackBarAction(
             label: isDesignAgent ? 'Open Canvas' : 'Edit Agent',
             textColor: Colors.white,
             onPressed: () {
               if (isDesignAgent) {
                 context.go(AppRoutes.canvas);
               } else {
                 context.go('/agents/configure/${createdAgent.id}');
               }
             },
           ),
         ),
       );
       
       // Refresh the agents list
       ref.invalidate(agentsProvider);
     }
     
   } catch (e) {
     print('❌ Failed to create agent from template: $e');
     
     // Close loading dialog if open
     if (context.mounted) {
       Navigator.of(context).pop();
       
       // Show error message
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text(
             'Failed to create agent: $e',
             style: TextStyles.bodyMedium.copyWith(color: Colors.white),
           ),
           backgroundColor: colors.error,
           action: SnackBarAction(
             label: 'Try Builder',
             textColor: Colors.white,
             onPressed: () {
               context.go(AppRoutes.agentBuilder);
             },
           ),
         ),
       );
     }
   }
 }
 
 void _editAgent(Agent agent) {
   context.go('/agents/configure/${agent.id}');
 }
 
 void _deleteAgent(Agent agent) {
   // Show confirmation dialog and delete agent
   showDialog(
     context: context,
     builder: (context) => AlertDialog(
       backgroundColor: ThemeColors(context).surface,
       title: Text(
         'Delete Agent',
         style: TextStyles.cardTitle.copyWith(
           color: ThemeColors(context).onSurface,
         ),
       ),
       content: Text(
         'Are you sure you want to delete "${agent.name}"? This action cannot be undone.',
         style: TextStyles.bodyMedium.copyWith(
           color: ThemeColors(context).onSurfaceVariant,
         ),
       ),
       actions: [
         TextButton(
           onPressed: () => Navigator.of(context).pop(),
           child: const Text('Cancel'),
         ),
         TextButton(
           onPressed: () async {
             Navigator.of(context).pop();
             try {
               final agentNotifier = ref.read(agentNotifierProvider.notifier);
               await agentNotifier.deleteAgent(agent.id);
               ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text('Deleted "${agent.name}"')),
               );
             } catch (e) {
               ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(
                   content: Text('Failed to delete agent: $e'),
                   backgroundColor: ThemeColors(context).error,
                 ),
               );
             }
           },
           style: TextButton.styleFrom(
             foregroundColor: ThemeColors(context).error,
           ),
           child: const Text('Delete'),
         ),
       ],
     ),
   );
 }
 
 void _duplicateAgent(Agent agent) async {
   try {
     final agentNotifier = ref.read(agentNotifierProvider.notifier);
     final duplicatedAgent = Agent(
       id: 'agent_${DateTime.now().millisecondsSinceEpoch}',
       name: '${agent.name} (Copy)',
       description: agent.description,
       capabilities: List.from(agent.capabilities),
       configuration: Map.from(agent.configuration ?? {}),
       status: AgentStatus.idle,
     );
     
     await agentNotifier.createAgent(duplicatedAgent);
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(content: Text('Duplicated "${agent.name}"')),
     );
   } catch (e) {
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text('Failed to duplicate agent: $e'),
         backgroundColor: ThemeColors(context).error,
       ),
     );
   }
 }
 
 void _previewTemplate(AgentTemplate template) {
   showDialog(
     context: context,
     builder: (context) => Dialog(
       backgroundColor: ThemeColors(context).surface,
       child: Container(
         width: MediaQuery.of(context).size.width * 0.8,
         height: MediaQuery.of(context).size.height * 0.8,
         padding: const EdgeInsets.all(SpacingTokens.xl),
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Row(
               children: [
                 Container(
                   padding: const EdgeInsets.all(SpacingTokens.sm),
                   decoration: BoxDecoration(
                     color: ThemeColors(context).primary.withValues(alpha: 0.1),
                     borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
                   ),
                   child: Icon(
                     _getCategoryIcon(template.category),
                     color: ThemeColors(context).primary,
                     size: 24,
                   ),
                 ),
                 const SizedBox(width: SpacingTokens.sm),
                 Expanded(
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(
                         template.name,
                         style: TextStyles.pageTitle.copyWith(
                           color: ThemeColors(context).onSurface,
                         ),
                       ),
                       Text(
                         template.category,
                         style: TextStyles.bodyMedium.copyWith(
                           color: ThemeColors(context).primary,
                           fontWeight: FontWeight.w600,
                         ),
                       ),
                     ],
                   ),
                 ),
                 IconButton(
                   onPressed: () => Navigator.of(context).pop(),
                   icon: Icon(Icons.close, color: ThemeColors(context).onSurfaceVariant),
                 ),
               ],
             ),
             const SizedBox(height: SpacingTokens.lg),
             
             // Description
             Text(
               'Description',
               style: TextStyles.bodyLarge.copyWith(
                 color: ThemeColors(context).onSurface,
                 fontWeight: FontWeight.w600,
               ),
             ),
             const SizedBox(height: SpacingTokens.sm),
             Text(
               template.description,
               style: TextStyles.bodyMedium.copyWith(
                 color: ThemeColors(context).onSurfaceVariant,
                 height: 1.6,
               ),
             ),
             
             const SizedBox(height: SpacingTokens.lg),
             
             // Example Use Case
             Text(
               'Example Use Case',
               style: TextStyles.bodyLarge.copyWith(
                 color: ThemeColors(context).onSurface,
                 fontWeight: FontWeight.w600,
               ),
             ),
             const SizedBox(height: SpacingTokens.sm),
             Container(
               width: double.infinity,
               padding: const EdgeInsets.all(SpacingTokens.sm),
               decoration: BoxDecoration(
                 color: ThemeColors(context).primary.withValues(alpha: 0.1),
                 borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
                 border: Border.all(color: ThemeColors(context).primary.withValues(alpha: 0.2)),
               ),
               child: Text(
                 template.exampleUse,
                 style: TextStyles.bodyMedium.copyWith(
                   color: ThemeColors(context).onSurface,
                   height: 1.6,
                 ),
               ),
             ),
             
             if (template.mcpServers.isNotEmpty) ...[
               const SizedBox(height: SpacingTokens.lg),
               Text(
                 'MCP Integrations',
                 style: TextStyles.bodyLarge.copyWith(
                   color: ThemeColors(context).onSurface,
                   fontWeight: FontWeight.w600,
                 ),
               ),
               const SizedBox(height: SpacingTokens.sm),
               Wrap(
                 spacing: SpacingTokens.sm,
                 runSpacing: SpacingTokens.sm,
                 children: template.mcpServers.map((server) {
                   return Container(
                     padding: const EdgeInsets.symmetric(
                       horizontal: SpacingTokens.sm,
                       vertical: SpacingTokens.xs,
                     ),
                     decoration: BoxDecoration(
                       color: ThemeColors(context).surfaceVariant,
                       borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
                       border: Border.all(color: ThemeColors(context).primary.withValues(alpha: 0.3)),
                     ),
                     child: Row(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         Icon(
                           Icons.hub,
                           size: 14,
                           color: ThemeColors(context).primary,
                         ),
                         const SizedBox(width: SpacingTokens.xs),
                         Text(
                           server,
                           style: TextStyles.bodySmall.copyWith(
                             color: ThemeColors(context).onSurface,
                             fontWeight: FontWeight.w500,
                           ),
                         ),
                       ],
                     ),
                   );
                 }).toList(),
               ),
             ],
             
             const Spacer(),
             
             // Action buttons
             Row(
               mainAxisAlignment: MainAxisAlignment.end,
               children: [
                 AsmblButton.secondary(
                   text: 'Close',
                   onPressed: () => Navigator.of(context).pop(),
                 ),
                 const SizedBox(width: SpacingTokens.sm),
                 AsmblButton.primary(
                   text: template.isComingSoon ? 'Coming Soon' : 'Create Agent',
                   onPressed: template.isComingSoon ? null : () {
                     Navigator.of(context).pop();
                     _createFromTemplate(template);
                   },
                 ),
               ],
             ),
           ],
         ),
       ),
     ),
   );
 }
 
 List<String> _getCapabilitiesFromTemplate(AgentTemplate template) {
   print('🔍 Getting capabilities for template: ${template.name}, category: ${template.category}');
   
   final capabilities = switch (template.category) {
     'Research' => ['research', 'analysis', 'citation', 'fact-checking'],
     'Development' => ['coding', 'debugging', 'code-review', 'testing'],
     'Writing' => ['content-creation', 'editing', 'seo', 'copywriting'],
     'Data Analysis' => ['data-analysis', 'visualization', 'statistics', 'reporting'],
     'Customer Support' => ['customer-service', 'troubleshooting', 'communication', 'ticket-management'],
     'Marketing' => ['marketing', 'campaigns', 'analytics', 'strategy'],
     'Design' => ['design', 'ui-ux', 'prototyping', 'canvas', 'material-design', 'wireframes', 'figma'],
     'DevOps' => ['devops', 'deployment', 'automation', 'infrastructure'],
     'Database' => ['database', 'sql', 'optimization', 'administration'],
     'Security' => ['security', 'penetration-testing', 'vulnerability-assessment', 'auditing'],
     'Product' => ['product-management', 'strategy', 'roadmap', 'analytics'],
     'API' => ['api-design', 'rest', 'graphql', 'documentation'],
     'QA' => ['testing', 'automation', 'quality-assurance', 'validation'],
     'Blockchain' => ['blockchain', 'smart-contracts', 'web3', 'defi'],
     'AI/ML' => ['machine-learning', 'ai', 'model-training', 'data-science'],
     'Content Creation' => ['content-creation', 'video-editing', 'multimedia', 'production'],
     'IoT' => ['iot', 'embedded-systems', 'sensors', 'edge-computing'],
     String() => ['general-assistance', 'problem-solving', 'communication'],
   };
   
   print('✅ Generated capabilities: $capabilities');
   return capabilities;
 }
 
 String _generateSystemPromptFromTemplate(AgentTemplate template) {
   switch (template.category) {
     case 'Research':
       return '''You are a helpful research assistant specializing in ${template.name.toLowerCase()}. You excel at:

• Finding and analyzing relevant information from multiple sources
• Providing accurate citations and references  
• Synthesizing complex information into clear summaries
• Fact-checking and verifying information accuracy

Always provide well-sourced, objective information and clearly indicate when something is uncertain or requires verification.''';

     case 'Development': 
       return '''You are an expert ${template.name.toLowerCase()} focused on software development. Your strengths include:

• Writing clean, efficient, and maintainable code
• Following best practices and coding standards
• Debugging and troubleshooting technical issues
• Code review and optimization suggestions
• Explaining complex technical concepts clearly

Always provide well-commented code examples and explain your reasoning behind technical decisions.''';

     case 'Writing':
       return '''You are a professional ${template.name.toLowerCase()} who helps with content creation. You specialize in:

• Creating engaging, well-structured content
• Adapting tone and style to target audiences  
• Grammar, style, and clarity improvements
• SEO optimization and readability
• Creative and persuasive writing techniques

Always maintain high writing standards while preserving the author's unique voice and intent.''';

     case 'Data Analysis':
       return '''You are a skilled ${template.name.toLowerCase()} with expertise in data science. You excel at:

• Statistical analysis and data interpretation
• Data visualization and reporting
• Identifying patterns and trends in datasets
• Providing actionable insights from data
• Explaining complex analytical concepts simply

Always provide clear explanations of your analytical methods and ensure recommendations are data-driven.''';

     case 'Customer Support':
       return '''You are a friendly and efficient ${template.name.toLowerCase()}. Your core capabilities include:

• Providing helpful, accurate customer service
• Troubleshooting common issues step-by-step  
• Escalating complex problems appropriately
• Maintaining professional, empathetic communication
• Following company policies and procedures

Always prioritize customer satisfaction while being helpful, patient, and solution-focused.''';

     case 'Marketing':
       return '''You are a creative ${template.name.toLowerCase()} with expertise in marketing strategy. You specialize in:

• Developing effective marketing campaigns
• Understanding target audience needs and behaviors
• Creating compelling content and messaging
• Analyzing marketing performance and ROI
• Staying current with marketing trends and best practices  

Always focus on data-driven strategies that deliver measurable results and authentic brand engagement.''';

     case 'Design':
       return '''You are an expert ${template.name.toLowerCase()} specializing in Material Design and modern UI/UX principles. You excel at:

• Creating intuitive, accessible user interfaces following Material Design 3 guidelines
• Generating wireframes, prototypes, and interactive designs on the canvas
• Applying proper color theory, typography, and spacing systems
• Building responsive component libraries and design systems
• Collaborating through visual design tools and code generation
• Translating user requirements into polished design solutions

Always prioritize user experience, accessibility (WCAG guidelines), and design consistency. Use the interactive canvas to create visual mockups and explain design decisions with clear reasoning.''';

     default:
       return '''You are a helpful AI assistant specializing in ${template.name.toLowerCase()}. 

Please customize this system prompt to define:
• Your specific role and expertise
• Key capabilities and strengths  
• How you approach tasks and problems
• Your communication style and tone
• Any important guidelines or limitations

This template gives you a starting point - modify it to create your perfect AI assistant!''';
   }
 }

 IconData _getCategoryIcon(String category) {
 switch (category) {
 case 'Research': return Icons.search;
 case 'Development': return Icons.code;
 case 'Writing': return Icons.edit;
 case 'Data Analysis': return Icons.analytics;
 case 'Customer Support': return Icons.support_agent;
 case 'Marketing': return Icons.campaign;
 case 'Design': return Icons.design_services;
 default: return Icons.smart_toy;
 }
 }

 List<Widget> _buildFilterChips() {
   final colors = ThemeColors(context);
   return categories.map((category) {
     final isSelected = selectedCategory == category;
     return GestureDetector(
       onTap: () => setState(() => selectedCategory = category),
       child: AnimatedContainer(
         duration: const Duration(milliseconds: 150),
         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
         decoration: BoxDecoration(
           color: isSelected ? colors.primary : colors.surface.withValues(alpha: 0.5),
           borderRadius: BorderRadius.circular(6),
           border: Border.all(
             color: isSelected ? colors.primary : colors.border.withValues(alpha: 0.5),
           ),
         ),
         child: Row(
           mainAxisSize: MainAxisSize.min,
           children: [
             if (category != 'All') ...[
               Icon(
                 _getCategoryIcon(category),
                 size: 12,
                 color: isSelected ? Colors.white : colors.onSurfaceVariant,
               ),
               const SizedBox(width: 4),
             ],
             Text(
               category,
               style: TextStyle(
                 fontSize: 12,
                 fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                 color: isSelected ? Colors.white : colors.onSurfaceVariant,
               ),
             ),
           ],
         ),
       ),
     );
   }).toList();
 }

 Widget _buildEmptyState() {
   final colors = ThemeColors(context);
   return Center(
     child: Column(
       mainAxisAlignment: MainAxisAlignment.center,
       children: [
         Container(
           padding: const EdgeInsets.all(16),
           decoration: BoxDecoration(
             color: colors.surface,
             shape: BoxShape.circle,
             border: Border.all(color: colors.border),
           ),
           child: Icon(Icons.search_off, size: 28, color: colors.onSurfaceVariant),
         ),
         const SizedBox(height: 16),
         Text(
           'No templates found',
           style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: colors.onSurface),
         ),
         const SizedBox(height: 4),
         Text(
           'Try adjusting your search or filters',
           style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
         ),
         const SizedBox(height: 16),
         _buildCompactGhostButton(colors, 'Clear Filters', () {
           setState(() {
             searchQuery = '';
             selectedCategory = 'All';
           });
         }),
       ],
     ),
   );
 }

 Widget _buildCompactGhostButton(ThemeColors colors, String label, VoidCallback onPressed) {
   return Material(
     color: Colors.transparent,
     child: InkWell(
       onTap: onPressed,
       borderRadius: BorderRadius.circular(6),
       child: Container(
         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
         decoration: BoxDecoration(
           border: Border.all(color: colors.border),
           borderRadius: BorderRadius.circular(6),
         ),
         child: Text(
           label,
           style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface),
         ),
       ),
     ),
   );
 }

 Widget _buildEmptyAgentsState() {
   final colors = ThemeColors(context);
   return Center(
     child: Column(
       mainAxisAlignment: MainAxisAlignment.center,
       children: [
         Container(
           padding: const EdgeInsets.all(16),
           decoration: BoxDecoration(
             color: colors.surface,
             shape: BoxShape.circle,
             border: Border.all(color: colors.border),
           ),
           child: Icon(Icons.smart_toy_outlined, size: 28, color: colors.onSurfaceVariant),
         ),
         const SizedBox(height: 16),
         Text(
           'No agents yet',
           style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: colors.onSurface),
         ),
         const SizedBox(height: 4),
         Text(
           'Create your first AI agent to get started',
           style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
           textAlign: TextAlign.center,
         ),
         const SizedBox(height: 20),
         Row(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
             _buildCompactGhostButton(colors, 'Browse Templates', () => setState(() => selectedTab = 1)),
             const SizedBox(width: 8),
             _buildCompactPrimaryButton(colors, 'Create Agent', () => context.go(AppRoutes.agentBuilder)),
           ],
         ),
       ],
     ),
   );
 }

 Widget _buildCompactPrimaryButton(ThemeColors colors, String label, VoidCallback onPressed) {
   return Material(
     color: colors.primary,
     borderRadius: BorderRadius.circular(6),
     child: InkWell(
       onTap: onPressed,
       borderRadius: BorderRadius.circular(6),
       child: Container(
         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
         child: Text(
           label,
           style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
         ),
       ),
     ),
   );
 }

 // Helper methods for agent search and filtering
 List<Agent> _filterAndSortAgents(List<Agent> agents) {
 var filtered = agents.where((agent) {
 final matchesSearch = agentSearchQuery.isEmpty ||
     agent.name.toLowerCase().contains(agentSearchQuery.toLowerCase()) ||
     agent.description.toLowerCase().contains(agentSearchQuery.toLowerCase()) ||
     agent.capabilities.any((cap) => cap.toLowerCase().contains(agentSearchQuery.toLowerCase()));

 final matchesStatus = selectedAgentStatus == null || agent.status == selectedAgentStatus;

 return matchesSearch && matchesStatus;
 }).toList();

 // Sort agents
 filtered.sort((a, b) {
 int comparison = 0;
 
 switch (agentSortBy) {
 case 'name':
 comparison = a.name.compareTo(b.name);
 break;
 case 'status':
 comparison = a.status.toString().compareTo(b.status.toString());
 break;
 case 'created':
 final aCreated = a.configuration['createdAt'] as String? ?? '';
 final bCreated = b.configuration['createdAt'] as String? ?? '';
 comparison = aCreated.compareTo(bCreated);
 break;
 case 'lastUsed':
 final aUsed = a.configuration['lastUsed'] as String? ?? '';
 final bUsed = b.configuration['lastUsed'] as String? ?? '';
 comparison = aUsed.compareTo(bUsed);
 break;
 default:
 comparison = a.name.compareTo(b.name);
 }

 return sortAscending ? comparison : -comparison;
 });

 return filtered;
 }

 Widget _buildAgentSearchAndFilter() {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Search bar
 Row(
 children: [
 Expanded(
 child: AsmblCard(
 child: TextField(
 onChanged: (value) => setState(() => agentSearchQuery = value),
 decoration: InputDecoration(
 hintText: 'Search your agents...',
 hintStyle: TextStyles.bodyMedium.copyWith(
 color: ThemeColors(context).onSurfaceVariant,
 ),
 prefixIcon: Icon(
 Icons.search,
 color: ThemeColors(context).onSurfaceVariant,
 size: 18,
 ),
 border: InputBorder.none,
 contentPadding: const EdgeInsets.symmetric(
 horizontal: SpacingTokens.componentSpacing,
 vertical: SpacingTokens.sm,
 ),
 ),
 style: TextStyles.bodyMedium.copyWith(
 color: ThemeColors(context).onSurface,
 ),
 ),
 ),
 ),
 const SizedBox(width: SpacingTokens.componentSpacing),
 
 // Sort dropdown
 AsmblCard(
 child: DropdownButton<String>(
 value: ['name', 'status', 'created', 'lastUsed'].contains(agentSortBy) ? agentSortBy : 'name',
 onChanged: (value) => setState(() => agentSortBy = value ?? 'name'),
 underline: Container(),
 icon: Icon(
 sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
 size: 16,
 color: ThemeColors(context).primary,
 ),
 items: const [
 DropdownMenuItem(value: 'name', child: Text('Name')),
 DropdownMenuItem(value: 'status', child: Text('Status')),
 DropdownMenuItem(value: 'created', child: Text('Created')),
 DropdownMenuItem(value: 'lastUsed', child: Text('Last Used')),
 ],
 ),
 ),
 
 const SizedBox(width: SpacingTokens.xs),
 
 // Sort direction toggle
 IconButton(
 onPressed: () => setState(() => sortAscending = !sortAscending),
 icon: Icon(
 sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
 size: 18,
 color: ThemeColors(context).primary,
 ),
 ),
 ],
 ),
 
 const SizedBox(height: SpacingTokens.sm),
 
 // Status filter chips
 Wrap(
 spacing: SpacingTokens.xs,
 children: [
 _buildStatusFilterChip('All', null),
 _buildStatusFilterChip('Active', AgentStatus.active),
 _buildStatusFilterChip('Idle', AgentStatus.idle),
 ],
 ),
 ],
 );
 }

 Widget _buildStatusFilterChip(String label, AgentStatus? status) {
 final isSelected = selectedAgentStatus == status;
 return GestureDetector(
 onTap: () => setState(() => selectedAgentStatus = status),
 child: Container(
 padding: const EdgeInsets.symmetric(
 horizontal: SpacingTokens.componentSpacing,
 vertical: SpacingTokens.xs,
 ),
 decoration: BoxDecoration(
 color: isSelected 
 ? ThemeColors(context).primary 
 : ThemeColors(context).surfaceVariant.withValues(alpha: 0.7),
 borderRadius: BorderRadius.circular(BorderRadiusTokens.pill),
 border: Border.all(
 color: isSelected 
 ? ThemeColors(context).primary 
 : ThemeColors(context).border,
 width: 1,
 ),
 ),
 child: Text(
 label,
 style: TextStyles.caption.copyWith(
 color: isSelected 
 ? Colors.white 
 : ThemeColors(context).onSurfaceVariant,
 fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
 ),
 ),
 ),
 );
 }

 Widget _buildCompactHeaderWithTabs() {
   final colors = ThemeColors(context);

   return Container(
     decoration: BoxDecoration(
       color: colors.surface.withValues(alpha: 0.5),
       border: Border(
         bottom: BorderSide(
           color: colors.border.withValues(alpha: 0.5),
         ),
       ),
     ),
     child: Padding(
       padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
       child: Row(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           // Title and Description
           Expanded(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text(
                   selectedTab == 0 ? 'My AI Agents' : 'Agent Templates',
                   style: TextStyle(
                     fontSize: 24,
                     fontWeight: FontWeight.w600,
                     color: colors.onSurface,
                     letterSpacing: -0.5,
                   ),
                 ),
                 const SizedBox(height: 4),
                 Text(
                   selectedTab == 0
                       ? 'Manage and organize your AI-powered assistants.'
                       : 'Start with a pre-built template and customize it to your needs.',
                   style: TextStyle(
                     fontSize: 14,
                     color: colors.onSurfaceVariant,
                     height: 1.5,
                   ),
                 ),
               ],
             ),
           ),

           const SizedBox(width: 16),

           // Compact tab switcher
           Container(
             padding: const EdgeInsets.all(4),
             decoration: BoxDecoration(
               color: colors.surface.withValues(alpha: 0.5),
               borderRadius: BorderRadius.circular(8),
               border: Border.all(color: colors.border.withValues(alpha: 0.5)),
             ),
             child: Row(
               mainAxisSize: MainAxisSize.min,
               children: [
                 _buildCompactTab(colors, 'My AI Team', selectedTab == 0, () => setState(() => selectedTab = 0)),
                 _buildCompactTab(colors, 'Templates', selectedTab == 1, () => setState(() => selectedTab = 1)),
               ],
             ),
           ),
         ],
       ),
     ),
   );
 }

 Widget _buildCompactTab(ThemeColors colors, String label, bool isSelected, VoidCallback onTap) {
   return GestureDetector(
     onTap: onTap,
     child: AnimatedContainer(
       duration: const Duration(milliseconds: 150),
       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
       decoration: BoxDecoration(
         color: isSelected ? colors.surface : Colors.transparent,
         borderRadius: BorderRadius.circular(6),
         boxShadow: isSelected
             ? [BoxShadow(color: colors.border.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 1))]
             : null,
       ),
       child: Text(
         label,
         style: TextStyle(
           fontSize: 13,
           fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
           color: isSelected ? colors.onSurface : colors.onSurfaceVariant,
         ),
       ),
     ),
   );
 }

 Widget _buildNoAgentsFoundState() {
 return Center(
 child: Column(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 Icon(
 Icons.search_off,
 size: 48,
 color: ThemeColors(context).onSurfaceVariant.withValues(alpha: 0.5),
 ),
 const SizedBox(height: SpacingTokens.componentSpacing),
 Text(
 'No agents found',
 style: TextStyles.bodyLarge.copyWith(
 color: ThemeColors(context).onSurface,
 fontWeight: FontWeight.bold,
 ),
 ),
 const SizedBox(height: SpacingTokens.xs),
 Text(
 'Try adjusting your search or filters',
 style: TextStyles.bodyMedium.copyWith(
 color: ThemeColors(context).onSurfaceVariant,
 ),
 textAlign: TextAlign.center,
 ),
 const SizedBox(height: SpacingTokens.componentSpacing),
 AsmblButton.secondary(
 text: 'Clear Search',
 onPressed: () {
 setState(() {
 agentSearchQuery = '';
 selectedAgentStatus = null;
 agentSortBy = 'name';
 sortAscending = true;
 });
 },
 ),
 ],
 ),
 );
 }

 void _toggleAgentStatus(Agent agent) async {
 try {
 final agentNotifier = ref.read(agentNotifierProvider.notifier);
 final newStatus = agent.status == AgentStatus.active 
 ? AgentStatus.idle 
 : AgentStatus.active;
 
 await agentNotifier.setAgentStatus(agent.id, newStatus);
 
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(
 newStatus == AgentStatus.active 
 ? 'Activated "${agent.name}"' 
 : 'Deactivated "${agent.name}"'
 ),
 backgroundColor: ThemeColors(context).success,
 ),
 );
 }
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Failed to change agent status: $e'),
 backgroundColor: ThemeColors(context).error,
 ),
 );
 }
 }
 }

 void _openAgentChat(Agent agent) {
 // Open canvas for Design Agents, chat for others
 final isDesignAgent = agent.capabilities.contains('design') || 
                       agent.capabilities.contains('canvas') ||
                       agent.capabilities.contains('ui-ux');
 if (isDesignAgent) {
   context.go(AppRoutes.canvas);
 } else {
   context.go('${AppRoutes.chat}?agent=${agent.id}');
 }
 }
}

class _AgentCard extends StatelessWidget {
 final Agent agent;

 const _AgentCard({required this.agent});

 @override
 Widget build(BuildContext context) {
 return AsmblCard(
 onTap: () {
 // Navigate to canvas for Design Agents, chat for others
 final isDesignAgent = agent.capabilities.contains('design') || 
                       agent.capabilities.contains('canvas') ||
                       agent.capabilities.contains('ui-ux');
 if (isDesignAgent) {
   context.go(AppRoutes.canvas);
 } else {
   context.go('${AppRoutes.chat}?agent=${agent.id}');
 }
 },
 child: Padding(
 padding: const EdgeInsets.all(SpacingTokens.componentSpacing),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Header with icon, name, and actions
 Row(
 children: [
 // Icon with status indicator
 Stack(
 alignment: Alignment.bottomRight,
 children: [
 Container(
 padding: const EdgeInsets.all(SpacingTokens.xs),
 decoration: BoxDecoration(
 color: ThemeColors(context).surfaceVariant,
 borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
 ),
 child: Icon(
 Icons.smart_toy,
 size: 18,
 color: ThemeColors(context).primary,
 ),
 ),
 // Status indicator
 Container(
 width: 6,
 height: 6,
 decoration: BoxDecoration(
 color: agent.status == AgentStatus.idle 
 ? ThemeColors(context).success 
 : ThemeColors(context).onSurfaceVariant,
 shape: BoxShape.circle,
 border: Border.all(
 color: ThemeColors(context).surface,
 width: 1,
 ),
 ),
 ),
 ],
 ),
 const SizedBox(width: SpacingTokens.sm),
 
 // Agent name and category
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 agent.name,
 style: TextStyles.bodyMedium.copyWith(
 color: ThemeColors(context).onSurface,
 fontWeight: FontWeight.w600,
 ),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 const SizedBox(height: 2),
 Text(
 agent.capabilities.isNotEmpty ? agent.capabilities.first : 'General',
 style: TextStyles.caption.copyWith(
 color: ThemeColors(context).onSurfaceVariant,
 ),
 ),
 ],
 ),
 ),
 
 // Action buttons
 Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 IconButton(
 icon: Icon(
 Icons.edit,
 size: 14,
 color: ThemeColors(context).onSurfaceVariant,
 ),
 padding: const EdgeInsets.all(4),
 constraints: const BoxConstraints(
 minWidth: 24,
 minHeight: 24,
 ),
 onPressed: () {
 context.go('/agents/configure/${agent.id}');
 },
 tooltip: 'Edit',
 ),
 PopupMenuButton(
 icon: Icon(
 Icons.more_vert,
 color: ThemeColors(context).onSurfaceVariant,
 size: 14,
 ),
 padding: EdgeInsets.zero,
 iconSize: 14,
 itemBuilder: (context) => [
 PopupMenuItem(
 value: 'duplicate',
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(Icons.copy, size: 12, color: ThemeColors(context).onSurface),
 const SizedBox(width: 6),
 Text('Duplicate', style: TextStyles.caption.copyWith(color: ThemeColors(context).onSurface)),
 ],
 ),
 ),
 const PopupMenuItem(
 value: 'delete',
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(Icons.delete, color: Colors.red, size: 12),
 SizedBox(width: 6),
 Text('Delete', style: TextStyle(color: Colors.red, fontSize: 12)),
 ],
 ),
 ),
 ],
 onSelected: (value) {
 // Handle menu actions
 },
 ),
 ],
 ),
 ],
 ),
 
 const SizedBox(height: SpacingTokens.sm),
 
 // Recent chat preview
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Icon(
 Icons.info_outline,
 size: 11,
 color: ThemeColors(context).onSurfaceVariant,
 ),
 const SizedBox(width: 4),
 Text(
 'Description',
 style: TextStyles.caption.copyWith(
 color: ThemeColors(context).onSurfaceVariant,
 fontWeight: FontWeight.w500,
 ),
 ),
 ],
 ),
 const SizedBox(height: 4),
 
 // Agent description
 Container(
 padding: const EdgeInsets.all(SpacingTokens.xs),
 decoration: BoxDecoration(
 color: ThemeColors(context).surfaceVariant.withValues(alpha: 0.3),
 borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
 border: Border.all(
 color: ThemeColors(context).border.withValues(alpha: 0.5),
 width: 0.5,
 ),
 ),
 child: Text(
 agent.description,
 style: TextStyles.caption.copyWith(
 color: ThemeColors(context).onSurface,
 height: 1.2,
 ),
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 ),
 ),
 
 const Spacer(),
 
 // Stats row
 Row(
 children: [
 Icon(
 Icons.hub,
 size: 10,
 color: ThemeColors(context).onSurfaceVariant,
 ),
 const SizedBox(width: 3),
 Text(
 '${agent.capabilities.length} capabilities',
 style: TextStyles.caption.copyWith(
 color: ThemeColors(context).onSurfaceVariant,
 fontWeight: FontWeight.w500,
 ),
 ),
 const SizedBox(width: SpacingTokens.xs),
 Icon(
 Icons.circle,
 size: 8,
 color: agent.status == AgentStatus.idle 
 ? ThemeColors(context).success 
 : ThemeColors(context).onSurfaceVariant,
 ),
 const SizedBox(width: 3),
 Expanded(
 child: Text(
 agent.status == AgentStatus.idle ? 'Ready' : 'Busy',
 style: TextStyles.caption.copyWith(
 color: ThemeColors(context).onSurfaceVariant,
 ),
 overflow: TextOverflow.ellipsis,
 ),
 ),
 ],
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 );
 }

}

class _TabButton extends StatelessWidget {
 final String text;
 final bool isSelected;
 final VoidCallback onTap;

 const _TabButton({
 required this.text,
 required this.isSelected,
 required this.onTap,
 });

 @override
 Widget build(BuildContext context) {
 return isSelected 
 ? AsmblButton.primary(text: text, onPressed: onTap)
 : AsmblButton.secondary(text: text, onPressed: onTap);
 }
}



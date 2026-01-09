/// Centralized route constants for the Asmbli desktop app
class AppRoutes {
 // Private constructor to prevent instantiation
 AppRoutes._();

 // Setup routes
 static const String setup = '/setup';

 // Main routes
 static const String home = '/';
 static const String chat = '/chat';
 static const String chatV2 = '/chat-v2';
 static const String settings = '/settings';
 static const String agents = '/agents';
 static const String context = '/context';
 static const String wizard = '/wizard';
 static const String agentWizard = '/agent-wizard';
 static const String agentBuilder = '/agent-builder';
 static const String orchestration = '/orchestration';
 static const String workflowBrowser = '/workflow-browser';
 static const String workflowMarketplace = '/workflow-marketplace';
 static const String integrations = '/integrations';
 static const String integrationHub = '/integration-hub';
 static const String marketplace = '/marketplace';
 static const String canvas = '/canvas';
 static const String canvasLibrary = '/canvas-library';
 static const String agentExecute = '/agents/execute'; // Dynamic: /agents/execute/:id
 
 // Demo routes
 static const String demoChat = '/demo-chat';
 static const String demoOnboarding = '/demo-onboarding';
 static const String demoUnified = '/demo-unified';
 static const String controlledOnboarding = '/controlled-onboarding';
 
 // Route names for easier identification
 static const Map<String, String> routeNames = {
 setup: 'Setup',
 home: 'Home',
 chat: 'Chat',
 chatV2: 'Chat V2',
 settings: 'Settings',
 agents: 'My Agents',
 context: 'Context',
 wizard: 'Wizard',
 agentWizard: 'Create Agent',
 agentBuilder: 'Build Agent',
 orchestration: 'Reasoning Flows',
 workflowBrowser: 'Workflow Library',
 workflowMarketplace: 'Workflow Marketplace',
 integrations: 'Add Integrations',
 integrationHub: 'Integration Hub',
 marketplace: 'Marketplace',
 canvas: 'Visual Canvas',
 canvasLibrary: 'Canvas Library',
 demoChat: 'Demo Chat',
 demoOnboarding: 'Demo Showcase',
 demoUnified: 'Unified Demo',
 controlledOnboarding: 'Agent Configuration',
 };
 
 // Helper method to get route name
 static String getRouteName(String route) {
 return routeNames[route] ?? 'Unknown';
 }
 
 // All valid routes list
 static const List<String> allRoutes = [
 setup,
 home,
 chat,
 chatV2,
 settings,
 agents,
 context,
 wizard,
 agentWizard,
 agentBuilder,
 orchestration,
 workflowBrowser,
 workflowMarketplace,
 integrations,
 integrationHub,
 marketplace,
 canvas,
 canvasLibrary,
 demoChat,
 demoOnboarding,
 demoUnified,
 controlledOnboarding,
 ];
}
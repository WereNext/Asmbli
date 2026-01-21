import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:agent_engine_core/models/conversation.dart' as core;
import '../../core/design_system/design_system.dart';
import '../../features/chat/presentation/widgets/rich_text_message_widget.dart';
import '../../features/chat/presentation/widgets/enhanced_message_input.dart';
import '../models/demo_models.dart';

/// Asmbli demo chat using the actual chat interface with human verification modals
class AsmblDemoChat extends ConsumerStatefulWidget {
  final String scenario;
  final String? deliverable;
  final double confidenceThreshold;
  final Function(HumanIntervention)? onInterventionNeeded;
  final Function(String, {String? actionContext})? onCanvasUpdate;
  final VoidCallback? onDemoComplete;
  final Function(VerificationRequest)? onVerificationNeeded;
  final Function(EnhancedVerificationRequest)? onEnhancedVerificationNeeded;

  const AsmblDemoChat({
    super.key,
    required this.scenario,
    this.deliverable,
    this.confidenceThreshold = 0.8,
    this.onInterventionNeeded,
    this.onCanvasUpdate,
    this.onDemoComplete,
    this.onVerificationNeeded,
    this.onEnhancedVerificationNeeded,
  });

  @override
  ConsumerState<AsmblDemoChat> createState() => _AsmblDemoChatState();
}

class _AsmblDemoChatState extends ConsumerState<AsmblDemoChat>
    with TickerProviderStateMixin {
  final List<DemoMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  int _currentStep = 0;
  bool _isInteractiveMode = false;
  List<String> _currentChatOptions = [];
  bool _waitingForUserInput = false;
  bool _isCompletionPhase = false;

  // Track selected actions for canvas updates
  String? _selectedFirstAction;
  String? _selectedSecondAction;
  String? _selectedThirdAction;

  // Helper to get coding agent deliverable type for dynamic content
  String get _codingDeliverableType {
    final d = widget.deliverable?.toLowerCase() ?? '';
    if (d.contains('refactor')) return 'refactor';
    if (d.contains('api')) return 'api';
    if (d.contains('test')) return 'test';
    if (d.contains('ci') || d.contains('cd') || d.contains('devops') || d.contains('pipeline')) return 'devops';
    if (d.contains('review')) return 'review';
    return 'refactor'; // default
  }

  // Dynamic coding agent content based on deliverable type
  String _getCodingAgentGreeting(String deliverable) {
    switch (_codingDeliverableType) {
      case 'refactor':
        return 'Hey there! I am your AI Coding Assistant. I\'m ready to help you create **$deliverable**. I\'ll analyze your codebase, identify optimization opportunities, and modernize your code following best practices. Let\'s make your code cleaner and faster!';
      case 'api':
        return 'Hey there! I am your AI Coding Assistant. I\'m ready to help you create **$deliverable**. I\'ll design RESTful endpoints, generate OpenAPI documentation, and implement proper authentication. Let\'s build a robust API!';
      case 'test':
        return 'Hey there! I am your AI Coding Assistant. I\'m ready to help you create **$deliverable**. I\'ll analyze your code for testable components, generate comprehensive unit and integration tests, and set up coverage reporting. Let\'s ensure code quality!';
      case 'devops':
        return 'Hey there! I am your AI Coding Assistant. I\'m ready to help you create **$deliverable**. I\'ll configure GitHub Actions, set up automated deployments, and implement health monitoring. Let\'s streamline your development workflow!';
      case 'review':
        return 'Hey there! I am your AI Coding Assistant. I\'m ready to help you create **$deliverable**. I\'ll set up static analysis, security scanning, and automated code suggestions. Let\'s establish continuous code quality!';
      default:
        return 'Hey there! I am your AI Coding Assistant. I\'m ready to help you create **$deliverable**. I can write code, manage git workflows, run tests, and deploy your project. Let\'s build something amazing!';
    }
  }

  String _getCodingAgentUserMessage() {
    switch (_codingDeliverableType) {
      case 'refactor':
        return 'I need to refactor our legacy API client. It has grown complex over time and needs error handling, better typing, and performance improvements.';
      case 'api':
        return 'I need to create a REST API for our user management system with authentication, CRUD operations, and proper documentation.';
      case 'test':
        return 'I need comprehensive tests for our authentication module. We need unit tests, integration tests, and proper coverage reporting.';
      case 'devops':
        return 'I need to set up a CI/CD pipeline with GitHub Actions. It should run tests, build the project, and deploy to staging automatically.';
      case 'review':
        return 'I want to set up automated code review for our repository. It should check for security issues, code style, and suggest improvements.';
      default:
        return 'I need to add error handling to our API client and implement retry logic for failed requests.';
    }
  }

  String _getCodingAgentFirstAction() {
    switch (_codingDeliverableType) {
      case 'refactor':
        return 'Analyze Codebase';
      case 'api':
        return 'Design API Schema';
      case 'test':
        return 'Analyze Test Coverage';
      case 'devops':
        return 'Analyze Current Setup';
      case 'review':
        return 'Scan Codebase';
      default:
        return 'Analyze Codebase';
    }
  }

  String _getCodingAgentFirstActionDetails() {
    switch (_codingDeliverableType) {
      case 'refactor':
        return 'I will analyze your current codebase structure, identify code smells, performance bottlenecks, and areas that need modernization. I\'ll prepare a refactoring plan following best practices.';
      case 'api':
        return 'I will design the API schema including endpoints, request/response formats, and authentication flow. I\'ll create an OpenAPI specification for documentation.';
      case 'test':
        return 'I will analyze your current test coverage, identify untested code paths, and determine which components need unit vs integration tests. I\'ll create a comprehensive test plan.';
      case 'devops':
        return 'I will analyze your current project structure, dependencies, and deployment requirements. I\'ll design a CI/CD pipeline that fits your workflow.';
      case 'review':
        return 'I will scan your codebase for patterns, identify areas that commonly have issues, and configure static analysis rules tailored to your project.';
      default:
        return 'I will analyze your current codebase structure, identify areas for improvement, and prepare to implement the requested changes using best practices.';
    }
  }

  String _getCodingAgentExecutionMessage() {
    switch (_codingDeliverableType) {
      case 'refactor':
        return 'Codebase Analysis Complete\n\nFindings:\n- Current API client lacks error handling\n- No retry mechanism for failed requests\n- TypeScript types could be improved\n- Found 3 potential optimization points\n\nProposed Changes:\n- Wrap API calls in try-catch blocks\n- Implement exponential backoff retry\n- Add proper error types and handling\n- Include loading states\n\nI\'ve opened the code editor with your files.\n\nNext Step: Should I implement the refactoring?';
      case 'api':
        return 'API Schema Design Complete\n\nEndpoints Designed:\n- POST /api/auth/login - User authentication\n- POST /api/auth/register - User registration\n- GET /api/users - List users (paginated)\n- GET /api/users/:id - Get user details\n- PUT /api/users/:id - Update user\n- DELETE /api/users/:id - Delete user\n\nFeatures:\n- JWT authentication with refresh tokens\n- Input validation with Zod schemas\n- Proper error responses (RFC 7807)\n\nI\'ve generated the OpenAPI spec.\n\nNext Step: Should I implement the API endpoints?';
      case 'test':
        return 'Test Coverage Analysis Complete\n\nCurrent Coverage:\n- Statements: 45%\n- Branches: 32%\n- Functions: 51%\n- Lines: 44%\n\nGaps Identified:\n- Authentication flow: 0% coverage\n- Error handling paths: 15% coverage\n- Edge cases in validators: 20% coverage\n\nTest Plan:\n- 12 unit tests for auth module\n- 6 integration tests for API\n- 4 E2E tests for critical paths\n\nNext Step: Should I generate the test suite?';
      case 'devops':
        return 'Project Analysis Complete\n\nCurrent Setup:\n- Build system: npm/webpack\n- No CI/CD pipeline detected\n- Manual deployment process\n\nProposed Pipeline:\n- Lint and type check on PR\n- Run tests with coverage\n- Build and bundle application\n- Deploy to staging on merge\n- Production deploy with approval\n\nEnvironments:\n- Staging: Auto-deploy from main\n- Production: Manual approval required\n\nNext Step: Should I create the pipeline configuration?';
      case 'review':
        return 'Codebase Scan Complete\n\nFindings:\n- 23 potential security issues\n- 45 code style violations\n- 12 deprecated API usages\n- 8 performance concerns\n\nRecommendations:\n- Enable ESLint security plugin\n- Configure Prettier for consistency\n- Add dependency vulnerability scanning\n- Implement pre-commit hooks\n\nPriority Issues:\n- SQL injection risk in query builder\n- Missing input sanitization\n- Outdated dependencies with CVEs\n\nNext Step: Should I configure the review system?';
      default:
        return 'Codebase Analysis Complete\n\nFindings:\n- Current API client lacks error handling\n- No retry mechanism for failed requests\n- TypeScript types could be improved\n- Found 3 potential optimization points\n\nProposed Changes:\n- Wrap API calls in try-catch blocks\n- Implement exponential backoff retry\n- Add proper error types and handling\n- Include loading states\n\nI\'ve opened the code editor with your files.\n\nNext Step: Should I implement the error handling improvements?';
    }
  }

  List<MCPStep> _getCodingAgentMcpSteps() {
    switch (_codingDeliverableType) {
      case 'refactor':
        return [
          MCPStep(type: 'code_analysis', title: 'Code Analysis', description: 'Scanning codebase for improvements', status: 'completed', icon: Icons.code),
          MCPStep(type: 'git_integration', title: 'Git Status', description: 'Checking current branch and changes', status: 'completed', icon: Icons.source),
        ];
      case 'api':
        return [
          MCPStep(type: 'schema_design', title: 'Schema Design', description: 'Designing REST API endpoints', status: 'completed', icon: Icons.api),
          MCPStep(type: 'openapi_gen', title: 'OpenAPI Spec', description: 'Generating API documentation', status: 'completed', icon: Icons.description),
        ];
      case 'test':
        return [
          MCPStep(type: 'coverage_analysis', title: 'Coverage Analysis', description: 'Analyzing test coverage gaps', status: 'completed', icon: Icons.assessment),
          MCPStep(type: 'test_planning', title: 'Test Planning', description: 'Creating comprehensive test plan', status: 'completed', icon: Icons.checklist),
        ];
      case 'devops':
        return [
          MCPStep(type: 'project_scan', title: 'Project Scan', description: 'Analyzing project structure', status: 'completed', icon: Icons.folder_open),
          MCPStep(type: 'pipeline_design', title: 'Pipeline Design', description: 'Designing CI/CD workflow', status: 'completed', icon: Icons.account_tree),
        ];
      case 'review':
        return [
          MCPStep(type: 'security_scan', title: 'Security Scan', description: 'Scanning for vulnerabilities', status: 'completed', icon: Icons.security),
          MCPStep(type: 'lint_analysis', title: 'Lint Analysis', description: 'Checking code style issues', status: 'completed', icon: Icons.rule),
        ];
      default:
        return [
          MCPStep(type: 'code_analysis', title: 'Code Analysis', description: 'Scanning codebase for improvements', status: 'completed', icon: Icons.code),
          MCPStep(type: 'git_integration', title: 'Git Status', description: 'Checking current branch and changes', status: 'completed', icon: Icons.source),
        ];
    }
  }

  String _getCodingAgentSecondAction() {
    switch (_codingDeliverableType) {
      case 'refactor':
        return 'Implement Refactoring';
      case 'api':
        return 'Implement API Endpoints';
      case 'test':
        return 'Generate Test Suite';
      case 'devops':
        return 'Create Pipeline Config';
      case 'review':
        return 'Configure Review Tools';
      default:
        return 'Implement Code Changes';
    }
  }

  String _getCodingAgentSecondActionDetails() {
    switch (_codingDeliverableType) {
      case 'refactor':
        return 'I will implement the refactoring changes: add error handling with proper try-catch blocks, implement retry logic with exponential backoff, improve TypeScript types, and optimize performance-critical paths.';
      case 'api':
        return 'I will implement all API endpoints with proper authentication, input validation, error handling, and database integration. Each endpoint will follow RESTful best practices.';
      case 'test':
        return 'I will generate the test suite including unit tests for individual functions, integration tests for API endpoints, and E2E tests for critical user flows. All tests will include proper mocking and assertions.';
      case 'devops':
        return 'I will create the GitHub Actions workflow files, configure environment variables, set up deployment scripts, and implement health checks for staging and production environments.';
      case 'review':
        return 'I will configure ESLint with security rules, set up Prettier for code formatting, add pre-commit hooks with Husky, and configure automated PR review with actionable suggestions.';
      default:
        return 'I will implement the error handling improvements, add retry logic with exponential backoff, and ensure proper TypeScript types.';
    }
  }

  String _getCodingAgentThirdAction() {
    switch (_codingDeliverableType) {
      case 'refactor':
        return 'Commit & Create PR';
      case 'api':
        return 'Deploy API Service';
      case 'test':
        return 'Run Test Suite';
      case 'devops':
        return 'Activate Pipeline';
      case 'review':
        return 'Enable Code Review';
      default:
        return 'Commit and Push Changes';
    }
  }

  String _getCodingAgentThirdActionDetails() {
    switch (_codingDeliverableType) {
      case 'refactor':
        return 'Commit all refactoring changes with a descriptive message, push to a feature branch, and create a pull request for code review.';
      case 'api':
        return 'Deploy the API service to the staging environment, run smoke tests, and generate the final API documentation.';
      case 'test':
        return 'Execute the full test suite, generate coverage reports, and update the CI configuration to run tests on every PR.';
      case 'devops':
        return 'Activate the CI/CD pipeline, run the first deployment to staging, and verify all health checks pass.';
      case 'review':
        return 'Enable the code review bot, run initial scan on the repository, and configure notification settings for the team.';
      default:
        return 'Commit all changes with descriptive message, push to feature branch, and create a pull request for code review.';
    }
  }

  String _getCodingAgentFinalMessage() {
    switch (_codingDeliverableType) {
      case 'refactor':
        return 'Refactoring Complete!\n\nChanges Made:\n- Added comprehensive error handling\n- Implemented retry logic with exponential backoff\n- Created proper TypeScript error types\n- Added loading and error states\n\nCode Quality:\n- All tests passing ✓\n- Type coverage: 100%\n- No linting errors\n\nThe changes are staged and ready for commit. Should I proceed with creating the PR?';
      case 'api':
        return 'API Implementation Complete!\n\nEndpoints Created:\n- Authentication: login, register, refresh\n- Users: CRUD operations with pagination\n- All endpoints documented in OpenAPI\n\nFeatures:\n- JWT authentication working ✓\n- Input validation active ✓\n- Error responses standardized ✓\n\nAPI documentation available at /docs. Ready to deploy to staging?';
      case 'test':
        return 'Test Suite Generated!\n\nTests Created:\n- 12 unit tests for auth module\n- 6 integration tests for API\n- 4 E2E tests for critical paths\n\nCoverage Improved:\n- Statements: 45% → 87%\n- Branches: 32% → 79%\n- Functions: 51% → 91%\n\nAll tests passing. Ready to run the full suite?';
      case 'devops':
        return 'CI/CD Pipeline Created!\n\nWorkflows Configured:\n- PR checks: lint, type-check, test\n- Main branch: build and deploy to staging\n- Release: production deployment\n\nFeatures:\n- Automated testing on every PR ✓\n- Staging auto-deploy active ✓\n- Production requires approval ✓\n\nPipeline ready. Should I activate it?';
      case 'review':
        return 'Code Review System Configured!\n\nTools Enabled:\n- ESLint with security rules\n- Prettier for formatting\n- Pre-commit hooks with Husky\n- Automated PR suggestions\n\nInitial Scan Results:\n- Fixed 18 auto-fixable issues\n- 5 issues require manual review\n- Security score: A\n\nReady to enable for all PRs?';
      default:
        return 'Code Implementation Complete!\n\nChanges Made:\n- Added comprehensive error handling to API client\n- Implemented retry logic with exponential backoff\n- Created proper TypeScript error types\n- Added loading and error states\n\nCode Quality:\n- All tests passing ✓\n- Type coverage: 100%\n- No linting errors\n\nThe changes are staged and ready for commit. Should I proceed with git commit and push?';
    }
  }

  String _getCodingAgentCompletionMessage() {
    switch (_codingDeliverableType) {
      case 'refactor':
        return '✅ Refactoring Complete!\n\nPull Request Created:\n- Branch: feature/api-client-refactor\n- PR #127 ready for review\n- All checks passing\n\nImprovements:\n- Code complexity reduced by 40%\n- Error handling coverage: 100%\n- Performance improved by ~25%\n\nYour refactored code is now ready for team review!';
      case 'api':
        return '✅ API Service Deployed!\n\nDeployment Status:\n- Staging URL: api-staging.example.com\n- All health checks passing\n- Documentation live at /docs\n\nEndpoints Active:\n- 6 REST endpoints operational\n- Authentication working\n- Rate limiting enabled\n\nYour API service is live and ready for integration!';
      case 'test':
        return '✅ Test Suite Complete!\n\nFinal Results:\n- 22 tests executed\n- All tests passing\n- Coverage: 87%\n\nCI Configuration:\n- Tests run on every PR\n- Coverage reports generated\n- Failing tests block merge\n\nYour codebase now has comprehensive test coverage!';
      case 'devops':
        return '✅ CI/CD Pipeline Active!\n\nFirst Run Results:\n- Build: Success\n- Tests: 22/22 passing\n- Deploy: Staging updated\n\nPipeline Status:\n- PR checks: Enabled\n- Auto-deploy: Active\n- Production: Ready\n\nYour development workflow is now fully automated!';
      case 'review':
        return '✅ Code Review System Active!\n\nConfiguration Complete:\n- All PRs will be auto-reviewed\n- Security checks enabled\n- Style enforcement active\n\nTeam Impact:\n- Faster PR reviews\n- Consistent code quality\n- Automated security scanning\n\nYour repository now has continuous code quality monitoring!';
      default:
        return '✅ Implementation Complete!\n\nChanges Committed:\n- All code changes committed\n- PR created and ready for review\n- CI checks passing\n\nYour code is now ready for team review and deployment!';
    }
  }

  List<String> _getCodingAgentUserChatOptions() {
    switch (_codingDeliverableType) {
      case 'refactor':
        return [
          'I need to refactor our legacy API client. It has grown complex and needs better error handling and typing.',
          'Can you modernize our authentication module? It\'s using outdated patterns.',
          'I want to optimize our database queries - they\'ve become slow over time.',
        ];
      case 'api':
        return [
          'I need to create a REST API for our user management system with authentication and CRUD operations.',
          'Can you build a GraphQL API for our product catalog with filtering and pagination?',
          'I want to create webhook endpoints for third-party integrations.',
        ];
      case 'test':
        return [
          'I need comprehensive tests for our authentication module with unit and integration tests.',
          'Can you generate tests for our payment processing flow? It\'s critical and needs coverage.',
          'I want E2E tests for our checkout process to catch regressions.',
        ];
      case 'devops':
        return [
          'I need to set up a CI/CD pipeline with GitHub Actions for automated testing and deployment.',
          'Can you configure Docker containers and Kubernetes deployment for our microservices?',
          'I want to set up automated staging deployments with preview environments for PRs.',
        ];
      case 'review':
        return [
          'I want automated code review for our repository with security checks and style enforcement.',
          'Can you set up dependency vulnerability scanning and automated updates?',
          'I need pre-commit hooks to catch issues before code is pushed.',
        ];
      default:
        return [
          'I need to add error handling to our API client and implement retry logic for failed requests.',
          'Can you help me create a new React component for displaying real-time analytics?',
          'I want to refactor our authentication flow to use JWT tokens.',
        ];
    }
  }

  List<String> _getCodingAgentFollowUpOptions() {
    switch (_codingDeliverableType) {
      case 'refactor':
        return [
          'Great! Can you also add unit tests for the refactored code?',
          'Can you document the new API patterns we\'re using?',
          'Help me create a migration guide for the team.',
        ];
      case 'api':
        return [
          'Can you add rate limiting and request throttling?',
          'Help me set up API versioning for backwards compatibility.',
          'Can you generate a Postman collection for testing?',
        ];
      case 'test':
        return [
          'Can you add snapshot testing for our React components?',
          'Help me set up test data factories for consistent fixtures.',
          'Can you configure parallel test execution for faster CI?',
        ];
      case 'devops':
        return [
          'Can you add Slack notifications for deployment status?',
          'Help me set up rollback procedures for failed deployments.',
          'Can you configure blue-green deployments for zero downtime?',
        ];
      case 'review':
        return [
          'Can you add custom lint rules for our coding standards?',
          'Help me set up CODEOWNERS for automatic reviewer assignment.',
          'Can you configure branch protection rules?',
        ];
      default:
        return [
          'Great work! Can you also add unit tests for the new error handling code?',
          'Can you implement caching to reduce API calls and improve performance?',
          'Help me set up a CI/CD pipeline to automatically run tests on pull requests.',
        ];
    }
  }

  String _getCodingAgentFollowUpResponse() {
    final q = _selectedFollowUpQuestion.toLowerCase();

    switch (_codingDeliverableType) {
      case 'refactor':
        if (q.contains('unit tests') || q.contains('test')) {
          return 'I\'ve created comprehensive unit tests for the refactored code.\n\n**Test Coverage:**\n- 24 new tests added covering all refactored modules\n- Edge cases for error handling\n- Mock data for async operations\n- Coverage: 62% → **98%**\n\n**Test Results:**\n```\n✓ processUsers filters active users correctly\n✓ transformUser formats names properly\n✓ fetchAndProcess handles network errors\n✓ async operations respect timeout\n```\n\nAll tests passing! Ready to commit.';
        } else if (q.contains('document') || q.contains('api patterns')) {
          return 'I\'ve documented the new API patterns.\n\n**Documentation Created:**\n\n**1. Error Handling Guide**\n- Custom error types and when to use them\n- Error boundary patterns\n- Logging best practices\n\n**2. TypeScript Patterns**\n- Interface definitions with JSDoc\n- Generic type usage examples\n- Type guard implementations\n\n**3. Migration Notes**\n- Breaking changes summary\n- Deprecation warnings\n- Upgrade path for consumers\n\nDocumentation saved to `/docs/api-patterns.md`';
        } else if (q.contains('migration') || q.contains('guide')) {
          return 'I\'ve created a comprehensive migration guide.\n\n**Migration Guide Created:**\n\n**Breaking Changes:**\n1. `processData()` → `processUsers()` (typed)\n2. Callback-based API → async/await\n3. New error types required\n\n**Step-by-Step Migration:**\n```typescript\n// Before\nprocessor.processData(rawData);\n\n// After\nconst users = processor.processUsers(typedData);\n```\n\n**Automated Codemods:**\n- Run `npx migrate-processor` for auto-updates\n- 90% of changes automated\n\nGuide saved to `/docs/MIGRATION.md`';
        }
        break;

      case 'api':
        if (q.contains('rate limit') || q.contains('throttl')) {
          return 'I\'ve implemented rate limiting and request throttling.\n\n**Rate Limiting Configuration:**\n\n**Per-User Limits:**\n- 100 requests/minute for authenticated users\n- 20 requests/minute for anonymous users\n- Burst allowance: 10 extra requests\n\n**Implementation:**\n```typescript\nconst rateLimiter = rateLimit({\n  windowMs: 60000,\n  max: 100,\n  message: { error: \'Rate limit exceeded\' }\n});\n```\n\n**Headers Added:**\n- `X-RateLimit-Limit`\n- `X-RateLimit-Remaining`\n- `X-RateLimit-Reset`\n\nRate limiting middleware active on all routes!';
        } else if (q.contains('version') || q.contains('backwards')) {
          return 'I\'ve set up API versioning for backwards compatibility.\n\n**Versioning Strategy:**\n\n**URL-Based Versioning:**\n- `/api/v1/users` - Current stable\n- `/api/v2/users` - New features\n\n**Version Support:**\n```typescript\nrouter.use(\'/v1\', v1Routes);\nrouter.use(\'/v2\', v2Routes);\n```\n\n**Deprecation Headers:**\n- `Sunset: date` for deprecated endpoints\n- `Deprecation: true` warning\n- Link to migration guide\n\n**Compatibility Layer:**\n- v1 routes forward-compatible\n- Automatic response transformation\n\nVersion 2 endpoints ready for rollout!';
        } else if (q.contains('postman') || q.contains('collection')) {
          return 'I\'ve generated a Postman collection for testing.\n\n**Postman Collection Created:**\n\n**Included Requests:**\n- Auth: Login, Register, Refresh Token\n- Users: CRUD operations\n- Pre-configured environments\n\n**Features:**\n- Auto-populated auth tokens\n- Example request bodies\n- Test scripts for validation\n- Environment variables\n\n**Collection Stats:**\n- 24 requests organized in folders\n- 100% endpoint coverage\n- Ready for import\n\nExported to `postman/api-collection.json`';
        }
        break;

      case 'test':
        if (q.contains('snapshot')) {
          return 'I\'ve added snapshot testing for your React components.\n\n**Snapshot Tests Created:**\n\n**Components Covered:**\n- Button variants (12 snapshots)\n- Form components (8 snapshots)\n- Layout components (6 snapshots)\n\n**Configuration:**\n```typescript\nit(\'renders correctly\', () => {\n  const tree = renderer.create(<Button />).toJSON();\n  expect(tree).toMatchSnapshot();\n});\n```\n\n**Update Strategy:**\n- Run `npm test -- -u` to update snapshots\n- CI fails on unexpected changes\n- Visual diff in PR comments\n\n26 snapshot tests added and passing!';
        } else if (q.contains('data factor') || q.contains('fixture')) {
          return 'I\'ve set up test data factories for consistent fixtures.\n\n**Factory Setup:**\n\n**User Factory:**\n```typescript\nconst userFactory = Factory.define<User>(() => ({\n  id: faker.datatype.uuid(),\n  name: faker.name.fullName(),\n  email: faker.internet.email(),\n}));\n```\n\n**Usage:**\n```typescript\nconst user = userFactory.build();\nconst users = userFactory.buildList(10);\n```\n\n**Factories Created:**\n- User, Order, Product, Comment\n- Relationship builders\n- State traits (admin, inactive, etc.)\n\nFactories available in `test/factories/`';
        } else if (q.contains('parallel')) {
          return 'I\'ve configured parallel test execution for faster CI.\n\n**Parallel Configuration:**\n\n**Jest Config:**\n```typescript\nmodule.exports = {\n  maxWorkers: \'50%\',\n  workerIdleMemoryLimit: \'512MB\',\n};\n```\n\n**Performance Impact:**\n- Before: 4.5 minutes\n- After: **1.8 minutes** (60% faster)\n\n**Optimizations:**\n- Tests grouped by type\n- Heavy tests isolated\n- Shared setup cached\n\n**CI Integration:**\n- GitHub Actions matrix builds\n- Test sharding across runners\n\nCI pipeline now runs 60% faster!';
        }
        break;

      case 'devops':
        if (q.contains('slack') || q.contains('notification')) {
          return 'I\'ve added Slack notifications for deployment status.\n\n**Slack Integration:**\n\n**Notifications Configured:**\n- Build started\n- Tests passed/failed\n- Deployment success/failure\n- Rollback alerts\n\n**Message Format:**\n```\n[SUCCESS] Production Deploy\nCommit: abc123 by @developer\nDuration: 4m 32s\nChanges: 3 files\n```\n\n**Channels:**\n- #deployments - All deploys\n- #alerts - Failures only\n- DM on your deploys\n\nSlack webhook configured and tested!';
        } else if (q.contains('rollback')) {
          return 'I\'ve set up rollback procedures for failed deployments.\n\n**Rollback Strategy:**\n\n**Automatic Rollback Triggers:**\n- Health check failures (3 consecutive)\n- Error rate > 5% in first 5 minutes\n- Memory/CPU threshold exceeded\n\n**Rollback Process:**\n```yaml\nrollback:\n  - Revert to previous image\n  - Restore database backup\n  - Notify team via Slack\n  - Create incident ticket\n```\n\n**One-Click Rollback:**\n- GitHub Actions workflow dispatch\n- `gh workflow run rollback.yml`\n\n**Recovery Time:** ~90 seconds average\n\nRollback procedures tested and ready!';
        } else if (q.contains('blue-green') || q.contains('zero downtime')) {
          return 'I\'ve configured blue-green deployments for zero downtime.\n\n**Blue-Green Setup:**\n\n**Architecture:**\n- Blue (current): 100% traffic\n- Green (new): Staged for testing\n- Load balancer controls routing\n\n**Deployment Flow:**\n1. Deploy to Green environment\n2. Run smoke tests\n3. Gradually shift traffic (10% → 50% → 100%)\n4. Keep Blue as instant rollback\n\n**Traffic Shifting:**\n```yaml\ntraffic:\n  - weight: 90\n    target: blue\n  - weight: 10\n    target: green\n```\n\n**Benefits:**\n- Zero downtime deploys\n- Instant rollback capability\n- A/B testing ready\n\nBlue-green infrastructure ready!';
        }
        break;

      case 'review':
        if (q.contains('lint') || q.contains('coding standards')) {
          return 'I\'ve added custom lint rules for your coding standards.\n\n**Custom Rules Created:**\n\n**ESLint Rules:**\n```javascript\n\'no-console\': \'error\',\n\'prefer-const\': \'error\',\n\'custom/no-any-type\': \'warn\',\n\'custom/require-jsdoc\': \'error\',\n```\n\n**TypeScript Rules:**\n- Strict null checks enforced\n- No implicit any\n- Consistent type imports\n\n**Auto-fix Available:**\n- 80% of issues auto-fixable\n- Pre-commit hook for enforcement\n\n**Documentation:**\n- Rule explanations in `.eslintrc`\n- Examples in `docs/coding-standards.md`\n\nCustom rules active and enforced!';
        } else if (q.contains('codeowners') || q.contains('reviewer')) {
          return 'I\'ve set up CODEOWNERS for automatic reviewer assignment.\n\n**CODEOWNERS File:**\n```\n# Default owners\n* @team-leads\n\n# Frontend\n/src/components/ @frontend-team\n/src/styles/ @design-team\n\n# Backend\n/src/api/ @backend-team\n/src/services/ @backend-team\n\n# Critical paths\n/src/auth/ @security-team @team-leads\n```\n\n**Review Rules:**\n- Minimum 2 approvals required\n- Owner approval mandatory\n- Auto-assign based on file changes\n\nCODEOWNERS configured and active!';
        } else if (q.contains('branch protection')) {
          return 'I\'ve configured branch protection rules.\n\n**Protection Rules (main):**\n\n**Required Checks:**\n- CI pipeline must pass\n- Code review approval (2 minimum)\n- No merge conflicts\n- Up-to-date with base branch\n\n**Restrictions:**\n- No force pushes\n- No direct commits\n- Require signed commits\n- Include administrators\n\n**Status Checks:**\n```yaml\nrequired_status_checks:\n  - lint\n  - test\n  - build\n  - security-scan\n```\n\n**Branch Rules:**\n- `main`: Production-ready\n- `develop`: Integration branch\n- `feature/*`: Required PR\n\nBranch protection rules enforced!';
        }
        break;
    }

    // Default response if no specific match
    return 'I\'ve implemented your requested enhancements. Code is ready!';
  }

  @override
  void initState() {
    super.initState();
    _startDemo();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _startDemo() {
    // Initial AI message
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _addMessage(DemoMessage(
          id: '1',
          role: 'assistant',
          content: _getInitialMessage(),
          timestamp: DateTime.now(),
          confidence: 0.95,
        ));
        
        // Show user options after AI message loads, but don't auto-progress
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _showUserChatOptions();
          }
        });
      }
    });
  }

  String _getInitialMessage() {
    // If deliverable is specified, personalize the greeting
    if (widget.deliverable != null && widget.deliverable!.isNotEmpty) {
      final deliverable = widget.deliverable!;

      switch (widget.scenario) {
        case 'operations-manager':
          return 'Hello! I am your Operations Manager AI. I\'m ready to help you create a **$deliverable**. I\'ll optimize scheduling, automate workflows, and streamline your operations. Let\'s get started!';
        case 'business-analyst':
          return 'Hi! I am your Business Analyst AI. I\'m here to create a **$deliverable** for you. I\'ll analyze your data, generate insights, and deliver actionable recommendations. Ready to dive in?';
        case 'design-assistant':
          return 'Welcome! I am your Design Assistant AI. I\'m excited to help you build a **$deliverable**. I\'ll create beautiful interfaces, generate components, and bring your vision to life. What should we design?';
        case 'coding-agent':
          return _getCodingAgentGreeting(deliverable);
        default:
          return 'Hello! I\'m ready to help you create a **$deliverable**. How can I assist you today?';
      }
    }

    // Fallback to generic greetings
    switch (widget.scenario) {
      case 'operations-manager':
        return 'Hello! I am your Operations Manager AI. I can help optimize scheduling, automate notifications, and streamline workflows. What operational challenge would you like me to help with?';
      case 'business-analyst':
        return 'Hi! I am your Business Analyst AI. I can analyze data, generate insights, and create comprehensive reports. What business question should we explore together?';
      case 'design-assistant':
        return 'Welcome! I am your Design Assistant AI. I can create interfaces, generate components, and build visual designs. What would you like to design today?';
      case 'coding-agent':
        return 'Hey there! I am your AI Coding Assistant. I can help you write code, manage git workflows, debug issues, and create full applications. What would you like to build today?';
      default:
        return 'Hello! How can I assist you today?';
    }
  }

  String _getUserMessage() {
    switch (widget.scenario) {
      case 'operations-manager':
        return 'I need to optimize our team schedules for next week and set up automated notifications for project deadlines. Can you help?';
      case 'business-analyst':
        return 'Can you analyze our Q4 sales performance and identify the key trends affecting our revenue growth?';
      case 'design-assistant':
        return 'I need to create a modern dashboard interface for our project management system. It should be clean and user-friendly.';
      default:
        return 'Can you help me with my task?';
    }
  }

  String _getFirstAction() {
    switch (widget.scenario) {
      case 'operations-manager':
        return 'Analyze Current Schedules';
      case 'business-analyst':
        return 'Access Sales Database';
      case 'design-assistant':
        return 'Create Initial Mockup';
      case 'coding-agent':
        return _getCodingAgentFirstAction();
      default:
        return 'Start Analysis';
    }
  }

  String _getFirstActionDetails() {
    switch (widget.scenario) {
      case 'operations-manager':
        return 'I will analyze your current team schedules, identify conflicts, and propose optimizations. This will involve accessing calendar data and resource allocation systems.';
      case 'business-analyst':
        return 'I will connect to your sales database to retrieve Q4 performance data, including revenue, customer metrics, and product performance.';
      case 'design-assistant':
        return 'I will create an initial dashboard mockup based on modern design principles and your project management requirements.';
      case 'coding-agent':
        return _getCodingAgentFirstActionDetails();
      default:
        return 'I will begin the analysis process.';
    }
  }

  void _executeFirstAction() {
    _addMessage(DemoMessage(
      id: '3',
      role: 'assistant',
      content: _getExecutionMessage(),
      timestamp: DateTime.now(),
      confidence: 0.88,
      mcpSteps: _getMcpSteps(),
    ));

    // Trigger canvas/editor progression
    if (widget.scenario == 'design-assistant') {
      widget.onCanvasUpdate?.call('wireframe');
    } else if (widget.scenario == 'coding-agent') {
      widget.onCanvasUpdate?.call('show_editor');
    }

    // Wait for user to continue instead of auto-progressing
    setState(() {
      _currentStep = 1;
      _waitingForUserInput = true;
    });
    
    // Show continue button after AI "finishes" work
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _showContinueToNextStep();
      }
    });
  }

  String _getExecutionMessage() {
    switch (widget.scenario) {
      case 'operations-manager':
        return 'Analysis complete! I have identified 3 scheduling conflicts and found optimization opportunities:\n\nCurrent Status:\n- 12 team members across 4 projects\n- 3 resource conflicts detected\n- Average utilization: 78%\n\nOptimization Recommendations:\n- Redistribute tasks from overloaded members\n- Implement buffer time for critical deliverables\n- Automate daily standup scheduling\n\nNext Step: Should I implement these schedule changes?';
      case 'business-analyst':
        return 'Q4 Sales Analysis Complete\n\nKey Insights:\n- Total Revenue: \$3.2M (+15% vs Q3)\n- Customer Acquisition: +22%\n- Average Deal Size: \$45K (+8%)\n- Top Product: Enterprise Suite (40% of revenue)\n\nTrends Identified:\n- Strong growth in enterprise segment\n- Geographic expansion showing results\n- Seasonal uptick in December\n\nNext Step: Generate detailed competitive analysis?';
      case 'design-assistant':
        return 'Initial Mockup Created\n\nI have designed a modern dashboard with:\n- Clean navigation sidebar\n- Real-time project status cards\n- Interactive data visualizations\n- Responsive layout for all devices\n\nDesign Principles Applied:\n- Minimal cognitive load\n- Consistent spacing and typography\n- Accessible color scheme\n- Intuitive user flow\n\nNext Step: Should I create the interactive prototype?';
      case 'coding-agent':
        return _getCodingAgentExecutionMessage();
      default:
        return 'Analysis completed successfully.';
    }
  }

  List<MCPStep> _getMcpSteps() {
    switch (widget.scenario) {
      case 'operations-manager':
        return [
          MCPStep(
            type: 'calendar_integration',
            title: 'Calendar Analysis',
            description: 'Analyzing team schedules and availability',
            status: 'completed',
            icon: Icons.calendar_today,
          ),
          MCPStep(
            type: 'resource_optimization',
            title: 'Resource Optimization',
            description: 'Computing optimal task allocation',
            status: 'completed',
            icon: Icons.trending_up,
          ),
        ];
      case 'business-analyst':
        return [
          MCPStep(
            type: 'database_query',
            title: 'Sales Database',
            description: 'Retrieving Q4 sales data',
            status: 'completed',
            icon: Icons.storage,
          ),
          MCPStep(
            type: 'data_analysis',
            title: 'Trend Analysis',
            description: 'Computing growth metrics and trends',
            status: 'completed',
            icon: Icons.analytics,
          ),
        ];
      case 'design-assistant':
        return [
          MCPStep(
            type: 'design_system',
            title: 'Design System',
            description: 'Applying design tokens and components',
            status: 'completed',
            icon: Icons.palette,
          ),
          MCPStep(
            type: 'mockup_generation',
            title: 'Mockup Creation',
            description: 'Generating dashboard layout',
            status: 'completed',
            icon: Icons.design_services,
          ),
        ];
      case 'coding-agent':
        return _getCodingAgentMcpSteps();
      default:
        return [];
    }
  }

  void _requestSecondVerification() {
    _requestEnhancedVerification(
      title: 'Ready to Implement Changes?',
      situation: _getSecondActionDetails(),
      actions: _getSecondVerificationActions(),
    );
  }

  void _requestThirdVerification() {
    _requestEnhancedVerification(
      title: 'Deploy to Production?',
      situation: _getThirdActionDetails(),
      actions: _getThirdVerificationActions(),
    );
  }

  String _getSecondAction() {
    switch (widget.scenario) {
      case 'operations-manager':
        return 'Implement Schedule Changes';
      case 'business-analyst':
        return 'Generate Executive Summary';
      case 'design-assistant':
        return 'Build Interactive Prototype';
      case 'coding-agent':
        return _getCodingAgentSecondAction();
      default:
        return 'Continue Process';
    }
  }

  String _getSecondActionDetails() {
    switch (widget.scenario) {
      case 'operations-manager':
        return 'Apply the optimized schedule changes and set up automated notifications for the identified deadlines.';
      case 'business-analyst':
        return 'Create an executive summary with actionable recommendations based on the Q4 analysis.';
      case 'design-assistant':
        return 'Convert the static mockup into an interactive prototype with working navigation and components.';
      case 'coding-agent':
        return _getCodingAgentSecondActionDetails();
      default:
        return 'Proceed with the next step.';
    }
  }

  String _getThirdAction() {
    switch (widget.scenario) {
      case 'operations-manager':
        return 'Deploy Monitoring System';
      case 'business-analyst':
        return 'Schedule Reporting Automation';
      case 'design-assistant':
        return 'Deploy to Production';
      case 'coding-agent':
        return _getCodingAgentThirdAction();
      default:
        return 'Finalize Implementation';
    }
  }

  String _getThirdActionDetails() {
    switch (widget.scenario) {
      case 'operations-manager':
        return 'Set up continuous monitoring of team performance, automated weekly reports, and alert system for resource bottlenecks.';
      case 'business-analyst':
        return 'Implement automated quarterly report generation, set up real-time dashboards, and configure trend alerts for key metrics.';
      case 'design-assistant':
        return 'Deploy the finalized design system to production, set up design token updates, and implement component usage tracking.';
      case 'coding-agent':
        return _getCodingAgentThirdActionDetails();
      default:
        return 'Complete the final implementation and deployment steps.';
    }
  }

  void _executeSecondAction() {
    _addMessage(DemoMessage(
      id: '4',
      role: 'assistant',
      content: _getFinalMessage(),
      timestamp: DateTime.now(),
      confidence: 0.94,
    ));

    // Trigger canvas/editor progression
    if (widget.scenario == 'design-assistant') {
      widget.onCanvasUpdate?.call('styled');
    } else if (widget.scenario == 'coding-agent') {
      widget.onCanvasUpdate?.call('code_updated');
    }
    
    // Wait for user to continue
    setState(() {
      _currentStep = 2;
      _waitingForUserInput = true;
    });
    
    // Show follow-up question button
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _showFollowUpPrompt();
      }
    });
  }
  
  void _addUserFollowUpQuestion() {
    _addMessage(DemoMessage(
      id: '5',
      role: 'user',
      content: _getUserFollowUpQuestion(),
      timestamp: DateTime.now(),
    ));
    
    // AI responds to user question
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _addAIFollowUpResponse();
      }
    });
  }
  
  void _addAIFollowUpResponse() {
    _addMessage(DemoMessage(
      id: '6',
      role: 'assistant',
      content: _getAIFollowUpResponse(),
      timestamp: DateTime.now(),
      confidence: 0.96,
      mcpSteps: _getFollowUpMcpSteps(),
    ));

    // Trigger canvas update to add follow-up artifact
    _triggerFollowUpArtifact();

    // Wait for user to proceed to final step
    setState(() {
      _currentStep = 3;
      _waitingForUserInput = true;
    });

    // Show final action button after brief delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _showFinalActionPrompt();
      }
    });
  }

  void _triggerFollowUpArtifact() {
    // Determine which artifact to create based on selected question
    if (widget.scenario == 'operations-manager') {
      if (_selectedFollowUpQuestion.contains('automated reminders')) {
        widget.onCanvasUpdate?.call('automation_added', actionContext: 'Automated Reminders & PM Integration');
      } else if (_selectedFollowUpQuestion.contains('capacity limits')) {
        widget.onCanvasUpdate?.call('alerts_configured', actionContext: 'Capacity Alert System');
      } else if (_selectedFollowUpQuestion.contains('performance metrics')) {
        widget.onCanvasUpdate?.call('metrics_dashboard', actionContext: 'Performance Metrics Dashboard');
      }
    } else if (widget.scenario == 'business-analyst') {
      if (_selectedFollowUpQuestion.contains('customer retention')) {
        widget.onCanvasUpdate?.call('retention_analysis', actionContext: 'Customer Retention & Forecasting');
      } else if (_selectedFollowUpQuestion.contains('competitive landscape')) {
        widget.onCanvasUpdate?.call('competitive_analysis', actionContext: 'Competitive Landscape Analysis');
      } else if (_selectedFollowUpQuestion.contains('marketing channels')) {
        widget.onCanvasUpdate?.call('channel_performance', actionContext: 'Marketing Channel Performance');
      }
    } else if (widget.scenario == 'design-assistant') {
      if (_selectedFollowUpQuestion.contains('mobile and tablet')) {
        widget.onCanvasUpdate?.call('responsive_designs', actionContext: 'Responsive Design Variations');
      } else if (_selectedFollowUpQuestion.contains('component library')) {
        widget.onCanvasUpdate?.call('component_library', actionContext: 'Component Library');
      } else if (_selectedFollowUpQuestion.contains('user testing')) {
        widget.onCanvasUpdate?.call('testing_scenarios', actionContext: 'User Testing Framework');
      }
    } else if (widget.scenario == 'coding-agent') {
      // Handle follow-up artifacts based on deliverable type
      _triggerCodingAgentFollowUpArtifact();
    }
  }

  void _triggerCodingAgentFollowUpArtifact() {
    final q = _selectedFollowUpQuestion.toLowerCase();

    switch (_codingDeliverableType) {
      case 'refactor':
        if (q.contains('unit tests') || q.contains('test')) {
          widget.onCanvasUpdate?.call('code_followup', actionContext: 'Unit Test Suite Added');
        } else if (q.contains('document') || q.contains('api patterns')) {
          widget.onCanvasUpdate?.call('code_followup', actionContext: 'API Documentation Generated');
        } else if (q.contains('migration')) {
          widget.onCanvasUpdate?.call('code_followup', actionContext: 'Migration Guide Created');
        }
        break;
      case 'api':
        if (q.contains('rate limiting') || q.contains('throttling')) {
          widget.onCanvasUpdate?.call('code_followup', actionContext: 'Rate Limiting Configured');
        } else if (q.contains('versioning')) {
          widget.onCanvasUpdate?.call('code_followup', actionContext: 'API Versioning Setup');
        } else if (q.contains('postman')) {
          widget.onCanvasUpdate?.call('code_followup', actionContext: 'Postman Collection Generated');
        }
        break;
      case 'test':
        if (q.contains('snapshot')) {
          widget.onCanvasUpdate?.call('code_followup', actionContext: 'Snapshot Tests Added');
        } else if (q.contains('data factories') || q.contains('fixtures')) {
          widget.onCanvasUpdate?.call('code_followup', actionContext: 'Test Data Factories Created');
        } else if (q.contains('parallel')) {
          widget.onCanvasUpdate?.call('code_followup', actionContext: 'Parallel Test Execution Configured');
        }
        break;
      case 'devops':
        if (q.contains('slack')) {
          widget.onCanvasUpdate?.call('code_followup', actionContext: 'Slack Notifications Configured');
        } else if (q.contains('rollback')) {
          widget.onCanvasUpdate?.call('code_followup', actionContext: 'Rollback Procedures Added');
        } else if (q.contains('blue-green') || q.contains('zero downtime')) {
          widget.onCanvasUpdate?.call('code_followup', actionContext: 'Blue-Green Deployment Setup');
        }
        break;
      case 'review':
        if (q.contains('custom lint') || q.contains('lint rules')) {
          widget.onCanvasUpdate?.call('code_followup', actionContext: 'Custom Lint Rules Added');
        } else if (q.contains('codeowners')) {
          widget.onCanvasUpdate?.call('code_followup', actionContext: 'CODEOWNERS Configured');
        } else if (q.contains('branch protection')) {
          widget.onCanvasUpdate?.call('code_followup', actionContext: 'Branch Protection Rules Set');
        }
        break;
    }
  }

  void _executeThirdAction() {
    // IMMEDIATELY set completion phase to prevent any delayed futures from overwriting options
    setState(() {
      _isCompletionPhase = true;
    });

    _addMessage(DemoMessage(
      id: '7',
      role: 'assistant',
      content: _getCompletionMessage(),
      timestamp: DateTime.now(),
      confidence: 0.98,
      mcpSteps: _getCompletionMcpSteps(),
    ));

    // Trigger final canvas/editor progression
    if (widget.scenario == 'design-assistant') {
      widget.onCanvasUpdate?.call('interactive');
    } else if (widget.scenario == 'coding-agent') {
      widget.onCanvasUpdate?.call('git_commit');
    }

    // Show completion options after a brief delay to let user read the message
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _waitingForUserInput = true;
          _currentChatOptions = [
            'Finish Demo',
            'Explore more options',
          ];
        });
      }
    });
  }

  void _showUserChatOptions() {
    setState(() {
      _isInteractiveMode = true;
      _waitingForUserInput = true;
      _currentChatOptions = _getUserChatOptions();
    });
  }

  List<String> _getUserChatOptions() {
    switch (widget.scenario) {
      case 'operations-manager':
        return [
          'I need to optimize our team schedules for next week and set up automated notifications for project deadlines. Can you help?',
          'Can you analyze our current operational bottlenecks and suggest improvements?',
          'Help me create a workflow automation system for our team processes.',
        ];
      case 'business-analyst':
        return [
          'Can you analyze our Q4 sales performance and identify the key trends affecting our revenue growth?',
          'I need insights into our customer acquisition costs and retention rates.',
          'Help me create a competitive analysis report for our market segment.',
        ];
      case 'design-assistant':
        return [
          'I need to create a modern dashboard interface for our project management system. It should be clean and user-friendly.',
          'Can you help me design a mobile-first landing page for our new product?',
          'I want to redesign our user onboarding flow to improve conversion rates.',
        ];
      case 'coding-agent':
        return _getCodingAgentUserChatOptions();
      default:
        return ['Can you help me with my task?'];
    }
  }

  void _selectChatOption(String selectedMessage) {
    setState(() {
      _isInteractiveMode = false;
      _waitingForUserInput = false;
      _currentChatOptions = [];
    });

    // Handle completion phase options without adding a message
    if (_isCompletionPhase) {
      setState(() => _isCompletionPhase = false);
      if (selectedMessage == 'Finish Demo') {
        widget.onDemoComplete?.call();
        return;
      } else if (selectedMessage == 'Explore more options') {
        // Add a friendly response and show follow-up options
        _addMessage(DemoMessage(
          id: 'explore',
          role: 'assistant',
          content: 'Great! Feel free to explore additional features. I\'m here if you need any assistance.',
          timestamp: DateTime.now(),
          confidence: 0.95,
        ));
        return;
      }
    }

    // Add the selected user message
    _addMessage(DemoMessage(
      id: '2',
      role: 'user',
      content: selectedMessage,
      timestamp: DateTime.now(),
    ));

    // Handle different progression options
    if (selectedMessage == 'Continue to next step') {
      _requestSecondVerification();
    } else if (selectedMessage == 'Ask follow-up question') {
      _showFollowUpOptions();
    } else if (selectedMessage == 'Proceed to deployment') {
      _requestThirdVerification();
    } else {
      // Default behavior for initial user responses
      // Trigger canvas update for design assistant
      if (widget.scenario == 'design-assistant') {
        widget.onCanvasUpdate?.call('start_design');
      }

      // Continue with the demo flow
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _requestEnhancedVerification(
            title: 'Ready to Begin Analysis?',
            situation: _getFirstActionDetails(),
            actions: _getFirstVerificationActions(),
          );
        }
      });
    }
  }

  void _showFollowUpOptions() {
    setState(() {
      _isInteractiveMode = true;
      _waitingForUserInput = true;
      _currentChatOptions = _getFollowUpChatOptions();
    });
  }

  List<String> _getFollowUpChatOptions() {
    switch (widget.scenario) {
      case 'operations-manager':
        return [
          'This looks great! Can you also set up automated reminders for our weekly team reviews and sync this with our project management system?',
          'Can you create alerts for when team members exceed their capacity limits?',
          'Help me set up performance metrics tracking for the optimized schedules.',
        ];
      case 'business-analyst':
        return [
          'Excellent analysis! Can you also break down the customer retention rates by segment and predict next quarter\'s performance?',
          'Can you analyze the competitive landscape impact on these trends?',
          'Help me identify which marketing channels are driving the highest quality leads.',
        ];
      case 'design-assistant':
        return [
          'Love the design! Can you create variations for mobile and tablet, plus add a dark mode option?',
          'Can you design a comprehensive component library based on this style?',
          'Help me create user testing scenarios to validate this design approach.',
        ];
      case 'coding-agent':
        return _getCodingAgentFollowUpOptions();
      default:
        return ['This is helpful! Can you provide more details on the implementation?'];
    }
  }

  String _selectedFollowUpQuestion = '';

  void _selectFollowUpOption(String selectedMessage) {
    setState(() {
      _isInteractiveMode = false;
      _waitingForUserInput = false;
      _currentChatOptions = [];
      _selectedFollowUpQuestion = selectedMessage;
    });

    // Add the selected follow-up message
    _addMessage(DemoMessage(
      id: '5',
      role: 'user',
      content: selectedMessage,
      timestamp: DateTime.now(),
    ));

    // AI responds to user question automatically (this is expected for follow-up responses)
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _addAIFollowUpResponse();
      }
    });
  }

  String _getFinalMessage() {
    switch (widget.scenario) {
      case 'operations-manager':
        return 'Implementation Complete!\n\n- Schedule optimization applied\n- Automated notifications configured\n- Team members notified of changes\n\nYour operational efficiency should improve by an estimated 23%. I will monitor the changes and suggest further optimizations as needed.';
      case 'business-analyst':
        return 'Executive Summary Generated\n\nKey Recommendations:\n1. Expand enterprise sales team (+30%)\n2. Increase investment in geographic expansion\n3. Develop specialized seasonal campaigns\n4. Launch customer retention program\n\nProjected Impact: +25% revenue growth in Q1\n\nFull analysis report has been saved to your dashboard.';
      case 'design-assistant':
        return 'Prototype Complete!\n\nYour interactive dashboard prototype is ready with:\n- Fully functional navigation\n- Real-time data connections\n- Mobile-responsive design\n- Accessibility compliance\n\nThe prototype is now available for team review and user testing. Ready to move to development?';
      case 'coding-agent':
        return _getCodingAgentFinalMessage();
      default:
        return 'Process completed successfully.';
    }
  }

  void _requestVerification({
    required String action,
    required String details,
    required VoidCallback onApprove,
  }) {
    // Pass verification request to parent instead of showing local modal
    widget.onVerificationNeeded?.call(VerificationRequest(
      action: action,
      details: details,
      onApprove: onApprove,
      onReject: () => _rejectAction(),
    ));
  }

  void _requestEnhancedVerification({
    required String title,
    required String situation,
    required List<ProposedAction> actions,
  }) {
    debugPrint('🔍 Requesting enhanced verification: $title');
    debugPrint('🔍 Actions count: ${actions.length}');
    debugPrint('🔍 First action title: ${actions.isNotEmpty ? actions.first.title : "none"}');
    debugPrint('🔍 Enhanced verification callback available: ${widget.onEnhancedVerificationNeeded != null}');

    // Get code samples for coding agent verifications
    String? codeBefore;
    String? codeAfter;

    if (widget.scenario == 'coding-agent') {
      codeBefore = _getCodeBeforeSample(title);
      codeAfter = _getCodeAfterSample(title);
    }

    widget.onEnhancedVerificationNeeded?.call(EnhancedVerificationRequest(
      title: title,
      situation: situation,
      proposedActions: actions,
      onChat: () => print('Opening chat for discussion'),
      codeBefore: codeBefore,
      codeAfter: codeAfter,
    ));
  }

  String? _getCodeBeforeSample(String verificationTitle) {
    // Only show code diff for steps that actually modify code
    if (!verificationTitle.contains('Implement') &&
        !verificationTitle.contains('Generate') &&
        !verificationTitle.contains('Create') &&
        !verificationTitle.contains('Configure')) {
      return null;
    }

    switch (_codingDeliverableType) {
      case 'refactor':
        return '''async function fetchData(url) {
  const response = await fetch(url);
  const data = await response.json();
  return data;
}

function processResults(data) {
  return data.map(item => item.value);
}''';
      case 'api':
        return '''// No existing API endpoints
// Starting from scratch''';
      case 'test':
        return '''// auth.ts - No tests exist
export function login(email, password) {
  return api.post('/auth/login', { email, password });
}

export function logout() {
  return api.post('/auth/logout');
}''';
      case 'devops':
        return '''# No CI/CD configuration
# Manual deployment process
npm run build
scp -r dist/ server:/var/www/''';
      case 'review':
        return '''// .eslintrc.js - Basic config
module.exports = {
  extends: ['eslint:recommended'],
  rules: {}
};''';
      default:
        return '''async function fetchData(url) {
  const response = await fetch(url);
  return response.json();
}''';
    }
  }

  String? _getCodeAfterSample(String verificationTitle) {
    // Only show code diff for steps that actually modify code
    if (!verificationTitle.contains('Implement') &&
        !verificationTitle.contains('Generate') &&
        !verificationTitle.contains('Create') &&
        !verificationTitle.contains('Configure')) {
      return null;
    }

    switch (_codingDeliverableType) {
      case 'refactor':
        return '''async function fetchData(url, retries = 3) {
  try {
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(\`HTTP \${response.status}\`);
    }
    return await response.json();
  } catch (error) {
    if (retries > 0) {
      await delay(1000 * (4 - retries));
      return fetchData(url, retries - 1);
    }
    throw error;
  }
}

function processResults(data) {
  if (!Array.isArray(data)) {
    throw new TypeError('Expected array');
  }
  return data.map(item => item.value);
}''';
      case 'api':
        return '''// POST /api/auth/login
router.post('/login', validate(loginSchema), async (req, res) => {
  const { email, password } = req.body;
  const user = await authService.login(email, password);
  const token = generateJWT(user);
  res.json({ user, token });
});

// GET /api/users
router.get('/users', authenticate, paginate, async (req, res) => {
  const users = await userService.list(req.pagination);
  res.json(users);
});''';
      case 'test':
        return '''// auth.test.ts
describe('Authentication', () => {
  it('should login with valid credentials', async () => {
    const result = await login('test@example.com', 'password');
    expect(result.token).toBeDefined();
    expect(result.user.email).toBe('test@example.com');
  });

  it('should reject invalid credentials', async () => {
    await expect(login('test@example.com', 'wrong'))
      .rejects.toThrow('Invalid credentials');
  });

  it('should logout successfully', async () => {
    const result = await logout();
    expect(result.success).toBe(true);
  });
});''';
      case 'devops':
        return '''# .github/workflows/ci.yml
name: CI/CD Pipeline
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: npm ci
      - run: npm test -- --coverage
  deploy:
    needs: test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - run: npm run build
      - run: aws s3 sync dist/ s3://\$BUCKET''';
      case 'review':
        return '''// .eslintrc.js - Enhanced config
module.exports = {
  extends: [
    'eslint:recommended',
    'plugin:security/recommended',
    'plugin:@typescript-eslint/recommended'
  ],
  plugins: ['security', '@typescript-eslint'],
  rules: {
    'security/detect-sql-injection': 'error',
    'security/detect-eval-with-expression': 'error',
    '@typescript-eslint/explicit-function-return-type': 'warn'
  }
};''';
      default:
        return '''async function fetchData(url, retries = 3) {
  try {
    const response = await fetch(url);
    if (!response.ok) throw new Error(\`HTTP \${response.status}\`);
    return await response.json();
  } catch (error) {
    if (retries > 0) return fetchData(url, retries - 1);
    throw error;
  }
}''';
    }
  }

  void _selectAction(String actionTitle, int verificationStep) {
    switch (verificationStep) {
      case 1:
        _selectedFirstAction = actionTitle;
        break;
      case 2:
        _selectedSecondAction = actionTitle;
        break;
      case 3:
        _selectedThirdAction = actionTitle;
        break;
    }
  }

  List<ProposedAction> _getFirstVerificationActions() {
    debugPrint('🔍 Building first verification actions for scenario: ${widget.scenario}');
    switch (widget.scenario) {
      case 'operations-manager':
        return [
          ProposedAction(
            title: 'Proceed with Analysis',
            description: 'Analyze team schedules and identify optimization opportunities',
            icon: Icons.analytics,
            isRecommended: true,
            onSelect: () => _executeFirstActionWithContext('Proceed with Analysis'),
          ),
          ProposedAction(
            title: 'Adjust Parameters',
            description: 'Customize the analysis scope and team selection',
            icon: Icons.tune,
            onSelect: () => _executeFirstActionWithContext('Adjust Parameters'),
          ),
          ProposedAction(
            title: 'Skip for Now',
            description: 'Continue without this analysis step',
            icon: Icons.skip_next,
            onSelect: () => _executeFirstActionWithContext('Skip for Now'),
          ),
        ];
      case 'business-analyst':
        return [
          ProposedAction(
            title: 'Access Sales Data',
            description: 'Connect to database and retrieve Q4 performance metrics',
            icon: Icons.storage,
            isRecommended: true,
            onSelect: () => _executeFirstActionWithContext('Access Sales Data'),
          ),
          ProposedAction(
            title: 'Use Sample Data',
            description: 'Demonstrate with anonymized sample dataset',
            icon: Icons.science,
            onSelect: () => _executeFirstActionWithContext('Use Sample Data'),
          ),
          ProposedAction(
            title: 'Configure Filters',
            description: 'Select specific date ranges and metrics to analyze',
            icon: Icons.filter_alt,
            onSelect: () => _executeFirstActionWithContext('Configure Filters'),
          ),
        ];
      case 'design-assistant':
        return [
          ProposedAction(
            title: 'Create Mockup',
            description: 'Generate initial dashboard design based on requirements',
            icon: Icons.design_services,
            isRecommended: true,
            onSelect: () {
              debugPrint('🎯 Create Mockup button clicked!');
              _executeFirstActionWithContext('Create Mockup');
            },
          ),
          ProposedAction(
            title: 'Review Examples',
            description: 'Show design inspiration and style references first',
            icon: Icons.collections,
            onSelect: () => _executeFirstActionWithContext('Review Examples'),
          ),
          ProposedAction(
            title: 'Gather More Context',
            description: 'Ask additional questions about design preferences',
            icon: Icons.quiz,
            onSelect: () => _executeFirstActionWithContext('Gather More Context'),
          ),
        ];
      case 'coding-agent':
        return [
          ProposedAction(
            title: 'Analyze Codebase',
            description: 'Scan code for improvements and optimization opportunities',
            icon: Icons.code,
            isRecommended: true,
            onSelect: () => _executeFirstActionWithContext('Analyze Codebase'),
          ),
          ProposedAction(
            title: 'Run Tests First',
            description: 'Execute existing tests to understand current state',
            icon: Icons.check_circle_outline,
            onSelect: () => _executeFirstActionWithContext('Run Tests First'),
          ),
          ProposedAction(
            title: 'Review Architecture',
            description: 'Examine project structure and dependencies',
            icon: Icons.account_tree,
            onSelect: () => _executeFirstActionWithContext('Review Architecture'),
          ),
        ];
      default:
        return [
          ProposedAction(
            title: 'Proceed',
            description: 'Continue with the recommended action',
            icon: Icons.play_arrow,
            isRecommended: true,
            onSelect: () => _executeFirstActionWithContext('Proceed'),
          ),
        ];
    }
  }

  List<ProposedAction> _getSecondVerificationActions() {
    switch (widget.scenario) {
      case 'operations-manager':
        return [
          ProposedAction(
            title: 'Apply Changes',
            description: 'Implement schedule optimizations and setup notifications',
            icon: Icons.update,
            isRecommended: true,
            onSelect: () => _executeSecondActionWithContext('Apply Changes'),
          ),
          ProposedAction(
            title: 'Review First',
            description: 'Let team leads review proposed changes before applying',
            icon: Icons.groups,
            onSelect: () => _executeSecondActionWithContext('Review First'),
          ),
          ProposedAction(
            title: 'Gradual Rollout',
            description: 'Apply changes to one team first as a pilot',
            icon: Icons.trending_up,
            onSelect: () => _executeSecondActionWithContext('Gradual Rollout'),
          ),
        ];
      case 'business-analyst':
        return [
          ProposedAction(
            title: 'Generate Report',
            description: 'Create executive summary with actionable recommendations',
            icon: Icons.description,
            isRecommended: true,
            onSelect: () => _executeSecondActionWithContext('Generate Report'),
          ),
          ProposedAction(
            title: 'Deep Dive Analysis',
            description: 'Perform additional segmentation and trend analysis',
            icon: Icons.analytics,
            onSelect: () => _executeSecondActionWithContext('Deep Dive Analysis'),
          ),
          ProposedAction(
            title: 'Schedule Presentation',
            description: 'Prepare stakeholder presentation with key insights',
            icon: Icons.present_to_all,
            onSelect: () => _executeSecondActionWithContext('Schedule Presentation'),
          ),
        ];
      case 'design-assistant':
        return [
          ProposedAction(
            title: 'Build Prototype',
            description: 'Convert mockup into interactive, clickable prototype',
            icon: Icons.touch_app,
            isRecommended: true,
            onSelect: () => _executeSecondActionWithContext('Build Prototype'),
          ),
          ProposedAction(
            title: 'Create Variations',
            description: 'Generate alternative layouts and color schemes',
            icon: Icons.palette,
            onSelect: () => _executeSecondActionWithContext('Create Variations'),
          ),
          ProposedAction(
            title: 'User Testing',
            description: 'Prepare design for user testing and feedback collection',
            icon: Icons.people,
            onSelect: () => _executeSecondActionWithContext('User Testing'),
          ),
        ];
      case 'coding-agent':
        return [
          ProposedAction(
            title: 'Implement Changes',
            description: 'Add error handling, retry logic, and improved TypeScript types',
            icon: Icons.build,
            isRecommended: true,
            onSelect: () => _executeSecondActionWithContext('Implement Changes'),
          ),
          ProposedAction(
            title: 'Write Tests First',
            description: 'Create comprehensive test suite before implementing changes',
            icon: Icons.check_circle_outline,
            onSelect: () => _executeSecondActionWithContext('Write Tests First'),
          ),
          ProposedAction(
            title: 'Incremental Changes',
            description: 'Implement one improvement at a time with testing',
            icon: Icons.linear_scale,
            onSelect: () => _executeSecondActionWithContext('Incremental Changes'),
          ),
        ];
      default:
        return [
          ProposedAction(
            title: 'Continue',
            description: 'Proceed with the next step',
            icon: Icons.arrow_forward,
            isRecommended: true,
            onSelect: () => _executeSecondActionWithContext('Continue'),
          ),
        ];
    }
  }

  List<ProposedAction> _getThirdVerificationActions() {
    switch (widget.scenario) {
      case 'operations-manager':
        return [
          ProposedAction(
            title: 'Deploy Monitoring',
            description: 'Set up real-time performance tracking and automated reports',
            icon: Icons.monitor_heart,
            isRecommended: true,
            onSelect: () => _executeThirdActionWithContext('Deploy Monitoring'),
          ),
          ProposedAction(
            title: 'Staged Deployment',
            description: 'Deploy monitoring to pilot team first, then expand',
            icon: Icons.layers,
            onSelect: () => _executeThirdActionWithContext('Staged Deployment'),
          ),
          ProposedAction(
            title: 'Manual Monitoring',
            description: 'Set up manual check-ins before full automation',
            icon: Icons.schedule,
            onSelect: () => _executeThirdActionWithContext('Manual Monitoring'),
          ),
        ];
      case 'business-analyst':
        return [
          ProposedAction(
            title: 'Setup Automation',
            description: 'Deploy automated reporting and real-time dashboards',
            icon: Icons.auto_awesome,
            isRecommended: true,
            onSelect: () => _executeThirdActionWithContext('Setup Automation'),
          ),
          ProposedAction(
            title: 'Weekly Reports',
            description: 'Start with weekly automated reports before daily',
            icon: Icons.schedule,
            onSelect: () => _executeThirdActionWithContext('Weekly Reports'),
          ),
          ProposedAction(
            title: 'Dashboard Only',
            description: 'Deploy real-time dashboard without automated reports',
            icon: Icons.dashboard,
            onSelect: () => _executeThirdActionWithContext('Dashboard Only'),
          ),
        ];
      case 'design-assistant':
        return [
          ProposedAction(
            title: 'Deploy Design System',
            description: 'Release production design tokens and component library',
            icon: Icons.rocket_launch,
            isRecommended: true,
            onSelect: () => _executeThirdActionWithContext('Deploy Design System'),
          ),
          ProposedAction(
            title: 'Beta Release',
            description: 'Deploy to limited audience for feedback first',
            icon: Icons.bug_report,
            onSelect: () => _executeThirdActionWithContext('Beta Release'),
          ),
          ProposedAction(
            title: 'Development Only',
            description: 'Share with developers for implementation planning',
            icon: Icons.developer_mode,
            onSelect: () => _executeThirdActionWithContext('Development Only'),
          ),
        ];
      case 'coding-agent':
        return [
          ProposedAction(
            title: 'Commit & Push',
            description: 'Commit changes with proper message and create pull request',
            icon: Icons.upload,
            isRecommended: true,
            onSelect: () => _showCommitMessagePreview(),
          ),
          ProposedAction(
            title: 'Create Draft PR',
            description: 'Push as draft for team review before final merge',
            icon: Icons.drafts,
            onSelect: () => _showCommitMessagePreview(isDraft: true),
          ),
          ProposedAction(
            title: 'Local Testing',
            description: 'Run more comprehensive tests locally first',
            icon: Icons.computer,
            onSelect: () => _executeThirdActionWithContext('Local Testing'),
          ),
        ];
      default:
        return [
          ProposedAction(
            title: 'Finalize',
            description: 'Complete the implementation and deployment',
            icon: Icons.done,
            isRecommended: true,
            onSelect: () => _executeThirdActionWithContext('Finalize'),
          ),
        ];
    }
  }

  // Action execution with context tracking
  void _executeFirstActionWithContext(String actionTitle) {
    debugPrint('🎬 _executeFirstActionWithContext called with: $actionTitle');
    debugPrint('🎬 Widget scenario: ${widget.scenario}');
    debugPrint('🎬 Canvas update callback available: ${widget.onCanvasUpdate != null}');

    _selectAction(actionTitle, 1);
    _executeFirstAction();

    // Update canvas with action context for ALL agent types
    if (widget.scenario == 'design-assistant') {
      debugPrint('🎬 Calling canvas update for wireframe with context: $actionTitle');
      widget.onCanvasUpdate?.call('wireframe', actionContext: actionTitle);
    } else if (widget.scenario == 'coding-agent') {
      debugPrint('🎬 Calling canvas update for show_editor with context: $actionTitle');
      widget.onCanvasUpdate?.call('show_editor', actionContext: actionTitle);
    } else if (widget.scenario == 'business-analyst') {
      debugPrint('🎬 Calling canvas update for data_analysis with context: $actionTitle');
      widget.onCanvasUpdate?.call('data_analysis', actionContext: actionTitle);
    } else if (widget.scenario == 'operations-manager') {
      debugPrint('🎬 Calling canvas update for schedule_analysis with context: $actionTitle');
      widget.onCanvasUpdate?.call('schedule_analysis', actionContext: actionTitle);
    }
    debugPrint('🎬 Canvas update call completed');
  }

  void _executeSecondActionWithContext(String actionTitle) {
    _selectAction(actionTitle, 2);
    _executeSecondAction();

    // Update canvas with action context for ALL agent types
    if (widget.scenario == 'design-assistant') {
      widget.onCanvasUpdate?.call('styled', actionContext: actionTitle);
    } else if (widget.scenario == 'coding-agent') {
      widget.onCanvasUpdate?.call('code_updated', actionContext: actionTitle);
    } else if (widget.scenario == 'business-analyst') {
      widget.onCanvasUpdate?.call('report_generated', actionContext: actionTitle);
    } else if (widget.scenario == 'operations-manager') {
      widget.onCanvasUpdate?.call('schedule_optimized', actionContext: actionTitle);
    }
  }

  void _executeThirdActionWithContext(String actionTitle) {
    _selectAction(actionTitle, 3);
    _executeThirdAction();

    // Update canvas with action context for ALL agent types
    if (widget.scenario == 'design-assistant') {
      widget.onCanvasUpdate?.call('interactive', actionContext: actionTitle);
    } else if (widget.scenario == 'coding-agent') {
      widget.onCanvasUpdate?.call('git_commit', actionContext: actionTitle);
    } else if (widget.scenario == 'business-analyst') {
      widget.onCanvasUpdate?.call('dashboard_deployed', actionContext: actionTitle);
    } else if (widget.scenario == 'operations-manager') {
      widget.onCanvasUpdate?.call('monitoring_active', actionContext: actionTitle);
    }
  }

  // Alternative action handlers
  void _customizeAndExecuteFirst() => _executeFirstAction();
  void _skipFirstAction() => _executeSecondAction();
  void _useSampleDataFirst() => _executeFirstAction();
  void _configureAndExecuteFirst() => _executeFirstAction();
  void _showDesignExamples() => _executeFirstAction();
  void _gatherMoreContext() => _executeFirstAction();
  void _runTestsFirst() => _executeFirstAction();
  void _reviewArchitecture() => _executeFirstAction();
  
  void _scheduleTeamReview() => _executeSecondAction();
  void _gradualRollout() => _executeSecondAction();
  void _performDeepDive() => _executeSecondAction();
  void _schedulePresentation() => _executeSecondAction();
  void _createVariations() => _executeSecondAction();
  void _prepareUserTesting() => _executeSecondAction();
  void _writeTestsFirst() => _executeSecondAction();
  void _incrementalImplementation() => _executeSecondAction();
  
  void _stagedMonitoringDeploy() => _executeThirdAction();
  void _manualMonitoring() => _executeThirdAction();
  void _weeklyReporting() => _executeThirdAction();
  void _dashboardOnly() => _executeThirdAction();
  void _betaRelease() => _executeThirdAction();
  void _developmentOnlyRelease() => _executeThirdAction();
  void _createDraftPR() => _executeThirdAction();
  void _extendedLocalTesting() => _executeThirdAction();

  void _rejectAction() {
    // Add rejection message
    _addMessage(DemoMessage(
      id: 'reject-${_currentStep}',
      role: 'assistant',
      content: 'Understood. Let me know how you would like to proceed differently, or if you would like me to suggest alternative approaches.',
      timestamp: DateTime.now(),
      confidence: 0.85,
    ));
  }

  void _addMessage(DemoMessage message) {
    if (mounted) {
      setState(() {
        _messages.add(message);
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = ThemeColors(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: Column(
        children: [
          // Chat header
          Container(
            padding: const EdgeInsets.all(SpacingTokens.md),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(bottom: BorderSide(color: colors.border)),
            ),
            child: Row(
              children: [
                Icon(
                  _getScenarioIcon(),
                  color: colors.primary,
                  size: 20,
                ),
                const SizedBox(width: SpacingTokens.sm),
                Text(
                  _getScenarioTitle(),
                  style: TextStyles.bodyLarge.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SpacingTokens.sm,
                    vertical: SpacingTokens.xs,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
                  ),
                  child: Text(
                    'DEMO',
                    style: TextStyles.bodySmall.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Messages area
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(SpacingTokens.md),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessage(_messages[index], colors);
              },
            ),
          ),

          // Interactive message input
          _buildMessageInput(colors),
        ],
      ),
    );
  }

  IconData _getScenarioIcon() {
    switch (widget.scenario) {
      case 'operations-manager':
        return Icons.schedule;
      case 'business-analyst':
        return Icons.analytics;
      case 'design-assistant':
        return Icons.palette;
      case 'coding-agent':
        return Icons.code;
      default:
        return Icons.chat;
    }
  }

  String _getScenarioTitle() {
    switch (widget.scenario) {
      case 'operations-manager':
        return 'Operations Manager AI';
      case 'business-analyst':
        return 'Business Analyst AI';
      case 'design-assistant':
        return 'Design Assistant AI';
      case 'coding-agent':
        return 'AI Coding Assistant';
      default:
        return 'AI Assistant';
    }
  }
  
  String _getUserFollowUpQuestion() {
    switch (widget.scenario) {
      case 'operations-manager':
        return 'This looks great! Can you also set up automated reminders for our weekly team reviews and sync this with our project management system?';
      case 'business-analyst':
        return 'Excellent analysis! Can you also break down the customer retention rates by segment and predict next quarter\'s performance?';
      case 'design-assistant':
        return 'Love the design! Can you create variations for mobile and tablet, plus add a dark mode option?';
      default:
        return 'This is helpful! Can you provide more details on the implementation?';
    }
  }
  
  String _getAIFollowUpResponse() {
    switch (widget.scenario) {
      case 'operations-manager':
        // Check which question was selected
        if (_selectedFollowUpQuestion.contains('automated reminders')) {
          return 'Absolutely! I\'ll set up the automated reminders and integrate with your PM system.\n\n**Weekly Team Review Setup:**\n- Automated calendar invites every Monday at 9 AM\n- Agenda auto-generated from completed tasks\n- Action items tracked and followed up\n\n**PM System Integration:**\n- Connected to Jira/Asana for real-time updates\n- Automated status reports to stakeholders\n- Smart deadline adjustments based on progress\n\nAll systems are now synchronized and running smoothly!';
        } else if (_selectedFollowUpQuestion.contains('capacity limits')) {
          return 'Great idea! I\'ll set up intelligent capacity monitoring.\n\n**Capacity Alert System:**\n- Real-time workload tracking per team member\n- **Alert Threshold:** Triggers at >90% capacity\n- **Notification Channels:** Slack, Email, Dashboard\n\n**Smart Features:**\n- Predictive alerts 48 hours before overload\n- Automatic task redistribution suggestions\n- Historical capacity trend analysis\n\n**Integration:** Connected to your project tracking system for instant workload visibility!\n\nYour team will now be protected from burnout with proactive capacity management.';
        } else if (_selectedFollowUpQuestion.contains('performance metrics')) {
          return 'Excellent! I\'ll configure comprehensive performance tracking.\n\n**Performance Metrics Dashboard:**\n- **Schedule Efficiency:** Track time saved vs. manual scheduling\n- **Resource Utilization:** Monitor optimal vs. actual capacity usage\n- **Meeting Effectiveness:** Analyze meeting duration and outcomes\n\n**Key Performance Indicators:**\n- Average task completion time: **-18% improvement**\n- Team idle time: **Reduced by 34%**\n- Meeting overlap conflicts: **Zero since optimization**\n\n**Automated Reports:** Weekly summaries sent to stakeholders every Friday.\n\nYour operations are now fully instrumented for continuous improvement!';
        }
        return 'I\'ve configured your requested enhancements. The system is now fully optimized!';

      case 'business-analyst':
        if (_selectedFollowUpQuestion.contains('customer retention')) {
          return 'Perfect! Let me dive deeper into customer retention and forecasting.\n\n**Customer Retention Analysis:**\n- **Enterprise:** 94% retention (+2% vs Q3)\n- **Mid-market:** 87% retention (stable)\n- **SMB:** 78% retention (+5% improvement)\n\n**Segment Insights:**\n- Enterprise churn primarily due to pricing (3 accounts)\n- Mid-market shows strong satisfaction scores\n- SMB retention improved after onboarding revamp\n\n**Q1 Performance Prediction:**\n- **Expected Revenue:** \$4.1M (+28% growth)\n- **New Customer Acquisition:** 340 customers\n- **Upsell Opportunities:** \$650K potential\n\n**Risk Factors:** Economic uncertainty (15% impact), competitive pressure (8% impact)\n\nHigh confidence in positive trajectory with these optimizations!';
        } else if (_selectedFollowUpQuestion.contains('competitive landscape')) {
          return 'Excellent question! I\'ll analyze the competitive dynamics.\n\n**Competitive Analysis:**\n- **Market Leader (Competitor A):** 32% market share, declining\n- **Fast-Riser (Competitor B):** 18% share, aggressive pricing\n- **Our Position:** 24% share, strongest growth velocity\n\n**Competitive Advantages:**\n- **Product Quality:** Rated #1 in customer surveys\n- **Customer Support:** 2.5x faster response time vs. competitors\n- **Innovation:** 3 major features launched vs. 1 from competitors\n\n**Threats & Opportunities:**\n- ⚠️ **Threat:** Competitor B\'s pricing pressure in SMB segment\n- ✅ **Opportunity:** Enterprise market underserved - expand sales team\n\n**Strategic Recommendation:** Defend SMB pricing, aggressively pursue enterprise accounts where our quality advantage justifies premium positioning.\n\nWe\'re positioned to capture 30% market share by Q3!';
        } else if (_selectedFollowUpQuestion.contains('marketing channels')) {
          return 'Great focus area! Let me analyze your marketing channel performance.\n\n**Channel Performance Analysis:**\n\n**Top Performers:**\n- **🥇 Content Marketing:** \$38K CAC, 92% retention, highest LTV\n- **🥈 Partner Referrals:** \$45K CAC, 88% retention, fastest close\n- **🥉 LinkedIn Ads:** \$52K CAC, 85% retention, scalable\n\n**Underperformers:**\n- Google Ads: High volume, low quality (68% retention)\n- Trade Shows: Expensive (\$95K CAC), slow pipeline\n\n**Lead Quality Indicators:**\n- Content leads: 3.2x more likely to upgrade\n- Referral leads: 40% faster time-to-value\n- Paid leads: Require 2x more sales touches\n\n**Recommendation:** Triple content marketing budget, double down on partner program, optimize Google Ads targeting to mirror content lead profiles.\n\nProjected impact: **+40% lead quality, -22% CAC** within 2 quarters!';
        }
        return 'I\'ve completed your requested analysis. The insights are ready for review!';

      case 'design-assistant':
        if (_selectedFollowUpQuestion.contains('mobile and tablet')) {
          return 'Fantastic idea! I\'ve created responsive variations and dark mode.\n\n**Mobile Design (375px):**\n- Condensed navigation with hamburger menu\n- Touch-optimized button sizes (44px minimum)\n- Simplified card layouts for better thumb reach\n- Bottom sheet interactions for better reachability\n\n**Tablet Design (768px):**\n- Two-column layout for optimal space usage\n- Enhanced sidebar with quick actions\n- Adaptive grid system (2-3 column adaptive)\n- Split-view support for multitasking\n\n**Dark Mode Theme:**\n- Carefully selected contrast ratios (WCAG AAA)\n- Blue accent colors for better night viewing\n- Smooth theme transition animations\n- Reduced eye strain for night usage\n\nAll designs maintain brand consistency and accessibility standards!';
        } else if (_selectedFollowUpQuestion.contains('component library')) {
          return 'Excellent thinking! I\'ve built a comprehensive component library.\n\n**Core Components Created:**\n- **Buttons:** Primary, Secondary, Tertiary, Icon (8 variants)\n- **Forms:** Input, TextArea, Select, Checkbox, Radio, Toggle\n- **Cards:** Standard, Elevated, Outlined, Interactive\n- **Navigation:** AppBar, Sidebar, Tabs, Breadcrumbs\n- **Feedback:** Alerts, Toasts, Modals, Loading States\n\n**Design System Features:**\n- **Token System:** Colors, Typography, Spacing, Shadows\n- **Accessibility:** WCAG AA compliant, keyboard navigation\n- **Documentation:** Storybook with live examples\n- **Code Export:** React, Vue, and plain CSS variants\n\n**Reusability Impact:**\n- 85% of future designs can use existing components\n- Estimated 40% reduction in design-to-dev time\n\nYour design system is now production-ready and future-proof!';
        } else if (_selectedFollowUpQuestion.contains('user testing')) {
          return 'Smart move! I\'ve created comprehensive user testing scenarios.\n\n**Testing Framework:**\n\n**Scenario 1: First-Time User Journey**\n- Task: Create account → explore dashboard → complete first action\n- Success Criteria: <3 min completion, <2 help requests\n- Key Metrics: Time to value, confusion points\n\n**Scenario 2: Power User Efficiency**\n- Task: Execute complex workflow with keyboard shortcuts\n- Success Criteria: 50% faster than mouse-only\n- Key Metrics: Shortcut discovery, task completion speed\n\n**Scenario 3: Mobile Usability**\n- Task: Complete core tasks on 375px mobile device\n- Success Criteria: 90% task completion, minimal zoom\n- Key Metrics: Tap target hits, scroll depth\n\n**Testing Tools:**\n- Figma prototypes with interactive hotspots\n- UserTesting.com script templates\n- Heatmap and session recording setup\n\n**Recommended Sample:** 12-15 users (mix of new/experienced, mobile/desktop)\n\nYou\'re ready to validate with real users!';
        }
        return 'I\'ve created your requested design variations. Ready for review!';

      case 'coding-agent':
        return _getCodingAgentFollowUpResponse();

      default:
        return 'I\'ve gathered additional implementation details based on your requirements. The system is now fully configured and ready for deployment.';
    }
  }
  
  List<MCPStep> _getFollowUpMcpSteps() {
    switch (widget.scenario) {
      case 'operations-manager':
        return [
          MCPStep(
            type: 'calendar_integration',
            title: 'Calendar Setup',
            description: 'Automated weekly review scheduling',
            status: 'completed',
            icon: Icons.event_repeat,
          ),
          MCPStep(
            type: 'pm_integration',
            title: 'PM System Sync',
            description: 'Connected to project management tools',
            status: 'completed',
            icon: Icons.sync,
          ),
        ];
      case 'business-analyst':
        return [
          MCPStep(
            type: 'retention_analysis',
            title: 'Retention Analysis',
            description: 'Customer segment breakdown completed',
            status: 'completed',
            icon: Icons.people,
          ),
          MCPStep(
            type: 'forecasting_model',
            title: 'Predictive Model',
            description: 'Q1 performance forecasting',
            status: 'completed',
            icon: Icons.trending_up,
          ),
        ];
      case 'design-assistant':
        return [
          MCPStep(
            type: 'responsive_design',
            title: 'Responsive Variants',
            description: 'Mobile and tablet layouts created',
            status: 'completed',
            icon: Icons.devices,
          ),
          MCPStep(
            type: 'dark_mode',
            title: 'Dark Mode Theme',
            description: 'Accessibility-compliant dark theme',
            status: 'completed',
            icon: Icons.dark_mode,
          ),
        ];
      case 'coding-agent':
        return [
          MCPStep(
            type: 'test_suite',
            title: 'Test Suite Created',
            description: 'Unit and integration tests added',
            status: 'completed',
            icon: Icons.check_circle_outline,
          ),
          MCPStep(
            type: 'ci_pipeline',
            title: 'CI/CD Pipeline',
            description: 'GitHub Actions workflow configured',
            status: 'completed',
            icon: Icons.account_tree,
          ),
        ];
      default:
        return [];
    }
  }

  String _getCompletionMessage() {
    switch (widget.scenario) {
      case 'operations-manager':
        return 'System Deployment Complete! 🚀\n\n**Monitoring Dashboard Live:**\n- Real-time team performance tracking\n- Automated weekly efficiency reports\n- Smart alert system for resource conflicts\n\n**Next Steps:**\n- Review weekly performance reports\n- Adjust optimization parameters based on results\n- Scale successful patterns to other teams\n\nYour operations are now fully optimized and self-monitoring!';
      case 'business-analyst':
        return 'Analytics Platform Deployed! 📊\n\n**Automated Systems Active:**\n- Quarterly report generation (next: Q1 2024)\n- Real-time revenue dashboard\n- Trend alerts for key metrics\n\n**Business Intelligence Features:**\n- Predictive analytics for revenue forecasting\n- Customer behavior pattern detection\n- Competitive analysis automation\n\nYour data-driven insights are now automated and actionable!';
      case 'design-assistant':
        return 'Design System Deployed! 🎨\n\n**Production Ready:**\n- Design tokens integrated across platforms\n- Component library live in production\n- Usage tracking and analytics enabled\n\n**Developer Experience:**\n- Auto-updating design documentation\n- Component usage metrics dashboard\n- Design-to-code synchronization\n\nYour design system is now scaling beautifully across your entire product!';
      case 'coding-agent':
        return _getCodingAgentCompletionMessage();
      default:
        return 'Implementation completed successfully!';
    }
  }

  List<MCPStep> _getCompletionMcpSteps() {
    switch (widget.scenario) {
      case 'operations-manager':
        return [
          MCPStep(
            type: 'monitoring_deployment',
            title: 'Monitoring System',
            description: 'Real-time performance tracking deployed',
            status: 'completed',
            icon: Icons.monitor_heart,
          ),
          MCPStep(
            type: 'automation_setup',
            title: 'Report Automation',
            description: 'Weekly reports and alerts configured',
            status: 'completed',
            icon: Icons.auto_awesome,
          ),
        ];
      case 'business-analyst':
        return [
          MCPStep(
            type: 'dashboard_deployment',
            title: 'Analytics Dashboard',
            description: 'Real-time business intelligence deployed',
            status: 'completed',
            icon: Icons.dashboard,
          ),
          MCPStep(
            type: 'reporting_automation',
            title: 'Report Generation',
            description: 'Automated quarterly reporting system',
            status: 'completed',
            icon: Icons.auto_awesome,
          ),
        ];
      case 'design-assistant':
        return [
          MCPStep(
            type: 'design_system_deployment',
            title: 'Design System',
            description: 'Production design system deployed',
            status: 'completed',
            icon: Icons.palette,
          ),
          MCPStep(
            type: 'component_tracking',
            title: 'Usage Analytics',
            description: 'Component usage tracking enabled',
            status: 'completed',
            icon: Icons.analytics,
          ),
        ];
      case 'coding-agent':
        return [
          MCPStep(
            type: 'deployment_pipeline',
            title: 'CI/CD Pipeline',
            description: 'Automated deployment system active',
            status: 'completed',
            icon: Icons.rocket_launch,
          ),
          MCPStep(
            type: 'monitoring_setup',
            title: 'Performance Monitoring',
            description: 'Real-time metrics and error tracking',
            status: 'completed',
            icon: Icons.monitor_heart,
          ),
        ];
      default:
        return [];
    }
  }

  String _getCompletionSummary() {
    switch (widget.scenario) {
      case 'project-manager':
        return 'Analyzed project scope, created sprint plan, and deployed monitoring dashboard';
      case 'business-analyst':
        return 'Assessed business metrics, built data pipeline, and deployed real-time analytics';
      case 'design-assistant':
        return 'Analyzed brand requirements, created component library, and published design system';
      case 'coding-agent':
        return 'Reviewed codebase, implemented changes, and deployed to CI/CD pipeline';
      default:
        return 'Completed all requested tasks and deployed deliverables';
    }
  }

  Widget _buildCompletionUI(ThemeColors colors) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(SpacingTokens.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.success.withOpacity(0.15),
              colors.primary.withOpacity(0.1),
            ],
          ),
          border: Border(
            top: BorderSide(
              color: colors.success.withOpacity(0.5),
              width: 2,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: colors.success.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Success header with animated checkmark
            Row(
              children: [
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 800),
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: colors.success,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: colors.success.withOpacity(0.4),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: SpacingTokens.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Demo Complete!',
                        style: TextStyles.sectionTitle.copyWith(
                          color: colors.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getCompletionSummary(),
                        style: TextStyles.bodySmall.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: SpacingTokens.lg),

            // Action buttons
            Row(
              children: [
                // Primary action - Finish Demo
                Expanded(
                  flex: 2,
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 900),
                    tween: Tween(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: 0.9 + (0.1 * value),
                        child: Opacity(
                          opacity: value,
                          child: child,
                        ),
                      );
                    },
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _selectChatOption('Finish Demo'),
                        borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: SpacingTokens.lg,
                            vertical: SpacingTokens.md,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                colors.success,
                                colors.success.withOpacity(0.85),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
                            boxShadow: [
                              BoxShadow(
                                color: colors.success.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.celebration_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: SpacingTokens.sm),
                              Text(
                                'Finish Demo',
                                style: TextStyles.bodyMedium.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: SpacingTokens.md),

                // Secondary action - Explore more
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 1000),
                    tween: Tween(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: 0.9 + (0.1 * value),
                        child: Opacity(
                          opacity: value,
                          child: child,
                        ),
                      );
                    },
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _selectChatOption('Explore more options'),
                        borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: SpacingTokens.md,
                            vertical: SpacingTokens.md,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
                            border: Border.all(
                              color: colors.primary.withOpacity(0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.explore_rounded,
                                color: colors.primary,
                                size: 18,
                              ),
                              const SizedBox(width: SpacingTokens.xs),
                              Flexible(
                                child: Text(
                                  'Explore',
                                  style: TextStyles.bodySmall.copyWith(
                                    color: colors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput(ThemeColors colors) {
    // Special completion phase UI
    if (_isCompletionPhase && _waitingForUserInput) {
      return _buildCompletionUI(colors);
    }

    if (_waitingForUserInput && _currentChatOptions.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(SpacingTokens.md),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(top: BorderSide(color: colors.primary.withOpacity(0.3), width: 2)),
          boxShadow: [
            BoxShadow(
              color: colors.primary.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(seconds: 1),
                    tween: Tween(begin: 0.0, end: 1.0),
                    onEnd: () {
                      // Restart animation
                      if (mounted) setState(() {});
                    },
                    builder: (context, value, child) {
                      return Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: colors.primary.withOpacity(0.6 * value),
                              blurRadius: 12 * value,
                              spreadRadius: 4 * value,
                            ),
                          ],
                        ),
                        child: child,
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: SpacingTokens.sm),
                Text(
                  'Choose your response:',
                  style: TextStyles.bodyMedium.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: SpacingTokens.sm),
            ..._currentChatOptions.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: SpacingTokens.sm),
                child: TweenAnimationBuilder<double>(
                  duration: Duration(milliseconds: 800 + (index * 200)),
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: 0.95 + (0.05 * value),
                      child: Opacity(
                        opacity: value,
                        child: child,
                      ),
                    );
                  },
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _currentStep > 1 ? _selectFollowUpOption(option) : _selectChatOption(option),
                      borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(SpacingTokens.md),
                        decoration: BoxDecoration(
                          color: colors.background,
                          borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
                          border: Border.all(
                            color: index == 0 ? colors.primary.withOpacity(0.4) : colors.border,
                            width: index == 0 ? 2 : 1,
                          ),
                          boxShadow: index == 0 ? [
                            BoxShadow(
                              color: colors.primary.withOpacity(0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ] : [],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: index == 0 ? colors.primary : colors.primary.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyles.bodySmall.copyWith(
                                    color: colors.surface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: SpacingTokens.md),
                            Expanded(
                              child: Text(
                                option,
                                style: TextStyles.bodyMedium.copyWith(
                                  color: colors.onSurface,
                                  fontWeight: index == 0 ? FontWeight.w600 : FontWeight.w400,
                                ),
                              ),
                            ),
                            TweenAnimationBuilder<double>(
                              duration: const Duration(milliseconds: 1500),
                              tween: Tween(begin: 0.0, end: 1.0),
                              onEnd: () {
                                if (mounted) setState(() {});
                              },
                              builder: (context, value, child) {
                                return Transform.translate(
                                  offset: Offset(4 * value, 0),
                                  child: child,
                                );
                              },
                              child: Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: index == 0 ? colors.primary : colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      );
    } else {
      // Default demo mode message
      return Container(
        padding: const EdgeInsets.all(SpacingTokens.md),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(top: BorderSide(color: colors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.md,
                  vertical: SpacingTokens.sm,
                ),
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
                  border: Border.all(color: colors.border),
                ),
                child: Text(
                  _waitingForUserInput 
                      ? 'Choose a response option above...'
                      : 'Demo mode - AI is handling this conversation...',
                  style: TextStyles.bodyMedium.copyWith(
                    color: colors.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
            const SizedBox(width: SpacingTokens.sm),
            Container(
              padding: const EdgeInsets.all(SpacingTokens.sm),
              decoration: BoxDecoration(
                color: colors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
              ),
              child: Icon(
                Icons.send,
                color: colors.primary.withOpacity(0.5),
                size: 20,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildMessage(DemoMessage message, ThemeColors colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: SpacingTokens.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.role == 'assistant') ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: colors.primary,
              child: Icon(
                Icons.smart_toy,
                size: 16,
                color: colors.surface,
              ),
            ),
            const SizedBox(width: SpacingTokens.sm),
          ],
          
          Expanded(
            child: Column(
              crossAxisAlignment: message.role == 'user' 
                  ? CrossAxisAlignment.end 
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(SpacingTokens.md),
                  decoration: BoxDecoration(
                    color: message.role == 'user' 
                        ? colors.primary 
                        : colors.surface,
                    borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
                    border: message.role == 'assistant' 
                        ? Border.all(color: colors.border) 
                        : null,
                  ),
                  child: Text(
                    message.content,
                    style: TextStyles.bodyMedium.copyWith(
                      color: message.role == 'user' 
                          ? colors.surface 
                          : colors.onSurface,
                    ),
                  ),
                ),
                
                // MCP Steps
                if (message.mcpSteps != null && message.mcpSteps!.isNotEmpty) ...[
                  const SizedBox(height: SpacingTokens.sm),
                  ...message.mcpSteps!.map((step) => _buildMcpStep(step, colors)),
                ],
                
                // Confidence indicator with threshold context
                if (message.confidence != null) ...[
                  const SizedBox(height: SpacingTokens.sm),
                  _buildConfidenceIndicator(message.confidence!, colors),
                ],
              ],
            ),
          ),
          
          if (message.role == 'user') ...[
            const SizedBox(width: SpacingTokens.sm),
            CircleAvatar(
              radius: 16,
              backgroundColor: colors.accent,
              child: Icon(
                Icons.person,
                size: 16,
                color: colors.surface,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMcpStep(MCPStep step, ThemeColors colors) {
    return Container(
      margin: const EdgeInsets.only(top: SpacingTokens.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.sm,
        vertical: SpacingTokens.xs,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            step.icon,
            size: 14,
            color: colors.success,
          ),
          const SizedBox(width: SpacingTokens.xs),
          Text(
            step.title,
            style: TextStyles.bodySmall.copyWith(
              color: colors.onSurface,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceIndicator(double confidence, ThemeColors colors) {
    final confidencePercent = (confidence * 100).toInt();
    final thresholdPercent = (widget.confidenceThreshold * 100).toInt();
    final isAboveThreshold = confidence >= widget.confidenceThreshold;

    // Color based on confidence level relative to threshold
    final indicatorColor = isAboveThreshold
        ? (confidence >= 0.9 ? colors.success : colors.primary)
        : colors.warning;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.sm,
        vertical: SpacingTokens.xs,
      ),
      decoration: BoxDecoration(
        color: indicatorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
        border: Border.all(color: indicatorColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Confidence icon with color
          Icon(
            isAboveThreshold ? Icons.check_circle : Icons.warning_amber_rounded,
            size: 14,
            color: indicatorColor,
          ),
          const SizedBox(width: SpacingTokens.xs),
          // Confidence percentage
          Text(
            '$confidencePercent%',
            style: TextStyles.bodySmall.copyWith(
              color: indicatorColor,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: SpacingTokens.xs),
          // Mini confidence bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
            child: Stack(
              children: [
                // Threshold marker
                Positioned(
                  left: (thresholdPercent / 100) * 40 - 1,
                  child: Container(
                    width: 2,
                    height: 4,
                    color: colors.onSurface.withOpacity(0.5),
                  ),
                ),
                // Confidence fill
                FractionallySizedBox(
                  widthFactor: confidence,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      color: indicatorColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Show threshold info on hover/tap (simplified for demo)
          if (!isAboveThreshold) ...[
            const SizedBox(width: SpacingTokens.xs),
            Tooltip(
              message: 'Below $thresholdPercent% threshold',
              child: Icon(
                Icons.info_outline,
                size: 12,
                color: indicatorColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // New methods for user-controlled progression
  void _showContinueToNextStep() {
    // Don't overwrite if we're already in completion phase
    if (_isCompletionPhase) return;

    setState(() {
      _isInteractiveMode = true;
      _currentChatOptions = ['Continue to next step'];
      _waitingForUserInput = true;  // Changed to true so buttons appear
    });
  }

  void _showFollowUpPrompt() {
    // Don't overwrite if we're already in completion phase
    if (_isCompletionPhase) return;

    setState(() {
      _isInteractiveMode = true;
      _currentChatOptions = _getFollowUpChatOptions();
      _waitingForUserInput = true;
    });
  }

  void _showFinalActionPrompt() {
    // Don't overwrite if we're already in completion phase
    if (_isCompletionPhase) return;

    setState(() {
      _isInteractiveMode = true;
      _currentChatOptions = ['Proceed to deployment'];
      _waitingForUserInput = true;  // Changed to true so buttons appear
    });
  }

  void _addUserMessage(String content) {
    _addMessage(DemoMessage(
      id: 'user-${DateTime.now().millisecondsSinceEpoch}',
      role: 'user',
      content: content,
      timestamp: DateTime.now(),
    ));
  }

  /// Show commit message preview modal before committing (like Claude Code)
  void _showCommitMessagePreview({bool isDraft = false}) {
    final colors = ThemeColors(context);

    // Generate commit message based on the actions taken
    final commitMessage = '''Add error handling and retry logic to API client

- Implemented exponential backoff retry mechanism
- Added proper TypeScript error types
- Enhanced error handling for network failures
- Improved loading and error states

Changes have been tested and all tests are passing.''';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 600,
              maxHeight: 500,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(BorderRadiusTokens.xl),
              border: Border.all(color: colors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(SpacingTokens.xxl),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colors.primary.withOpacity(0.1),
                        colors.primary.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(BorderRadiusTokens.xl),
                      topRight: Radius.circular(BorderRadiusTokens.xl),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.commit,
                        color: colors.primary,
                        size: 24,
                      ),
                      const SizedBox(width: SpacingTokens.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Review Commit Message',
                              style: TextStyles.sectionTitle.copyWith(
                                color: colors.onSurface,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: SpacingTokens.xs),
                            Text(
                              isDraft ? 'Create draft PR for review' : 'Commit and push changes',
                              style: TextStyles.bodySmall.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Commit message preview
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(SpacingTokens.xxl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.text_fields,
                              size: 16,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: SpacingTokens.sm),
                            Text(
                              'Commit Message',
                              style: TextStyles.bodyMedium.copyWith(
                                color: colors.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: SpacingTokens.md),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(SpacingTokens.lg),
                          decoration: BoxDecoration(
                            color: colors.onSurface.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
                            border: Border.all(
                              color: colors.border,
                            ),
                          ),
                          child: Text(
                            commitMessage,
                            style: TextStyles.bodyMedium.copyWith(
                              color: colors.onSurface,
                              fontFamily: 'monospace',
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.xl),

                        // Files changed
                        Row(
                          children: [
                            Icon(
                              Icons.description,
                              size: 16,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: SpacingTokens.sm),
                            Text(
                              'Files Changed',
                              style: TextStyles.bodyMedium.copyWith(
                                color: colors.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: SpacingTokens.md),
                        _buildFileChange(colors, 'src/api/client.ts', '+42 -8'),
                        _buildFileChange(colors, 'src/types/errors.ts', '+28 -0'),
                        _buildFileChange(colors, 'src/utils/retry.ts', '+35 -0'),
                      ],
                    ),
                  ),
                ),

                // Footer with buttons
                Container(
                  padding: const EdgeInsets.all(SpacingTokens.xxl),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: colors.border),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AsmblButton.secondary(
                        text: 'Cancel',
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                        },
                      ),
                      AsmblButton.primary(
                        text: isDraft ? 'Create Draft PR' : 'Commit & Push',
                        icon: isDraft ? Icons.drafts : Icons.upload,
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          _executeThirdActionWithContext(
                            isDraft ? 'Create Draft PR' : 'Commit & Push',
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFileChange(ThemeColors colors, String filename, String changes) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.sm),
      child: Row(
        children: [
          Icon(
            Icons.insert_drive_file,
            size: 14,
            color: colors.success,
          ),
          const SizedBox(width: SpacingTokens.sm),
          Expanded(
            child: Text(
              filename,
              style: TextStyles.bodySmall.copyWith(
                color: colors.onSurface,
                fontFamily: 'monospace',
              ),
            ),
          ),
          Text(
            changes,
            style: TextStyles.bodySmall.copyWith(
              color: colors.success,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

}

class DemoMessage {
  final String id;
  final String role;
  final String content;
  final DateTime timestamp;
  final double? confidence;
  final List<MCPStep>? mcpSteps;

  DemoMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.confidence,
    this.mcpSteps,
  });
}

class MCPStep {
  final String type;
  final String title;
  final String description;
  final String status;
  final IconData icon;

  MCPStep({
    required this.type,
    required this.title,
    required this.description,
    required this.status,
    required this.icon,
  });
}
# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

---

## Project Overview

**Asmbli** is a Flutter desktop application for building and managing AI agents with MCP (Model Context Protocol) integration. The app uses a **DSPy Python backend** for AI operations and supports multiple LLM providers.

**Tech Stack**: Flutter 3.0+, Dart 3.0+, Riverpod, DSPy (Python backend), MCP, Hive/SQLite

**Platforms**: Windows, macOS, Linux

---

## Quick Reference

```bash
# Run the app
cd apps/desktop && flutter run

# Run tests
cd apps/desktop && flutter test

# Analyze code
flutter analyze

# Start DSPy backend
cd dspy-backend && python main.py
```

---

## Architecture

### System Overview

```
Flutter Desktop App (UI)
    │
    ├── Riverpod (State Management)
    ├── ServiceLocator (Dependency Injection)
    │
    └── DSPy Services ──────────────────────┐
        ├── DspyService (chat, health)      │
        ├── DspyAgentService (execution)    │
        ├── DspyRagService (documents)      │
        └── DspyConversationService         │
              │                             │
              ▼                             │
DSPy Python Backend ◄───────────────────────┘
    │ FastAPI @ localhost:8000
    │
    ├── /chat        - Conversations
    ├── /reasoning   - CoT, ToT patterns
    ├── /agent/execute - ReAct agents
    ├── /rag/query   - Document Q&A
    └── /documents   - Document management
```

### Directory Structure

```
apps/desktop/lib/
├── core/
│   ├── design_system/     # UI components, tokens, themes
│   ├── di/                # ServiceLocator
│   ├── services/
│   │   ├── dspy/          # DSPy integration (PRIMARY)
│   │   ├── desktop/       # Platform services
│   │   ├── llm/           # LLM providers (legacy fallback)
│   │   └── business/      # Business logic
│   └── models/
├── features/              # Feature modules
│   ├── chat/              # Chat interface
│   ├── agents/            # Agent management
│   ├── settings/          # Configuration
│   ├── context/           # Document context
│   ├── tools/             # MCP tools
│   └── orchestration/     # Workflow builder
└── providers/             # Riverpod providers

dspy-backend/              # Python AI backend
├── src/
│   ├── api/               # FastAPI endpoints
│   └── modules/           # DSPy modules (RAG, agents, reasoning)
└── main.py

packages/agent_engine_core/ # Shared models
```

---

## DSPy Integration

DSPy is the **primary AI backend**, replacing 50+ fragmented Flutter services with a unified Python API.

### Using DSPy in Flutter

```dart
import 'package:asmbli/core/services/dspy/dspy.dart';

// Check connection
final isConnected = ref.watch(dspyIsConnectedProvider);

// Chat
final dspy = ref.read(dspyServiceProvider);
final response = await dspy.chat('Hello!');

// Agent execution
final agent = ref.read(dspyAgentServiceProvider);
final result = await agent.execute(
  agentId: 'my-agent',
  task: 'Analyze this data',
  mode: AgentExecutionMode.react,
);

// RAG query
final rag = ref.read(dspyRagServiceProvider);
final answer = await rag.query('What does the doc say?');
```

### Running DSPy Backend

```bash
cd dspy-backend
pip install -e ".[dev]"
cp .env.example .env  # Add API keys
python main.py        # Runs at localhost:8000
```

### Services Replaced by DSPy

| Old Services | New DSPy Service |
|--------------|------------------|
| UnifiedLLMService, ClaudeApiService, OpenAIApiService | DspyService |
| AgentBusinessService, SmartAgentOrchestratorService | DspyAgentService |
| VectorDatabaseService, RAGPipeline | DspyRagService |
| ConversationBusinessService | DspyConversationService |

---

## Design System (CRITICAL)

### Mandatory Pattern

**ALWAYS use `ThemeColors(context)` - NEVER hardcode colors**

```dart
import 'core/design_system/design_system.dart';

final colors = ThemeColors(context);
Container(color: colors.primary)        // Correct
Container(color: Color(0xFF4ECDC4))     // WRONG
```

### Color Schemes

6 user-selectable schemes: Warm Neutral, Cool Blue, Forest Green, Sunset Orange, Silver Onyx, Rose Quartz

### Components

```dart
// Buttons
AsmblButton.primary(text: "Save", onPressed: () {})
AsmblButton.destructive(text: "Delete", onPressed: () {})

// Cards
AsmblCard(child: ...)
AsmblCardEnhanced.outlined(child: ...)

// Spacing (Golden Ratio)
SpacingTokens.sm (8px), SpacingTokens.md (13px), SpacingTokens.lg (21px)

// Typography
TextStyles.pageTitle, TextStyles.bodyMedium
```

### Standard Page Layout

```dart
return Scaffold(
  body: Container(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        center: Alignment.topCenter,
        radius: 1.5,
        colors: [
          colors.backgroundGradientStart,
          colors.backgroundGradientMiddle,
          colors.backgroundGradientEnd,
        ],
      ),
    ),
    child: SafeArea(
      child: Column(
        children: [
          const AppNavigationBar(currentRoute: AppRoutes.myRoute),
          Expanded(child: /* content */),
        ],
      ),
    ),
  ),
);
```

---

## State Management (Riverpod)

```dart
// State Notifier (mutable state)
final agentProvider = StateNotifierProvider<AgentNotifier, AsyncValue<List<Agent>>>(...);

// Future Provider (async data)
final dataProvider = FutureProvider<Data>((ref) async => service.fetchData());

// Using in widgets
class MyWidget extends ConsumerWidget {
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myProvider);      // Rebuilds on change
    final service = ref.read(serviceProvider); // One-time read
    return Container();
  }
}
```

---

## MCP Integration

MCP servers provide tools for agents (file access, git, github, etc.)

```dart
// Get catalog
final catalog = ServiceLocator.instance.get<MCPCatalogService>();
final servers = await catalog.getAllEntries();

// Key services
MCPCatalogService       // Server discovery
MCPBridgeService        // Core communication
AgentMCPService         // Agent-specific config
MCPServerExecutionService // Server lifecycle
```

---

## Data Persistence

| Storage | When Used |
|---------|-----------|
| Hive | Agents, conversations, templates, settings |
| SharedPreferences | UI state, preferences |
| Secure Storage | API keys, OAuth tokens |
| Vector DB | Document embeddings (RAG) |

```dart
final storage = DesktopStorageService.instance;
await storage.setPreference('key', value);
final value = storage.getPreference<String>('key');
```

---

## Development Guidelines

### Do

- Use `ThemeColors(context)` for all colors
- Use `SpacingTokens.*` for spacing
- Use design system components
- Write tests for business logic
- Extend existing services rather than creating new ones
- Use DSPy for AI operations

### Don't

- Hardcode colors: `Color(0xFF...)`
- Use deprecated `SemanticColors.*`
- Create new services without justification
- Skip `flutter analyze` before committing

---

## Testing

```bash
cd apps/desktop

flutter test                                    # All tests
flutter test test/unit/services/               # Service tests
flutter test --coverage                        # With coverage
```

Test structure: `test/unit/`, `test/widget/`, `test/integration/`, `test/helpers/`

---

## Key Files

| Purpose | Location |
|---------|----------|
| Entry Point | [main.dart](apps/desktop/lib/main.dart) |
| Service Locator | [service_locator.dart](apps/desktop/lib/core/di/service_locator.dart) |
| DSPy Services | [dspy/](apps/desktop/lib/core/services/dspy/) |
| Design System | [design_system.dart](apps/desktop/lib/core/design_system/design_system.dart) |
| Routes | [routes.dart](apps/desktop/lib/core/constants/routes.dart) |

---

## Documentation

| Document | Purpose |
|----------|---------|
| [DSPY_MIGRATION_GUIDE](docs/DSPY_MIGRATION_GUIDE.md) | DSPy backend integration |
| [TESTING_BOOTSTRAP](docs/TESTING_BOOTSTRAP.md) | Testing improvement plan |
| [Design System USAGE](apps/desktop/lib/core/design_system/USAGE.md) | Component reference |
| [Penpot Migration](docs/README_CANVAS_MIGRATION.md) | Canvas/design integration |

---

## Quality Checklist

Before committing:
- [ ] `flutter analyze` passes
- [ ] Tests pass
- [ ] Uses ThemeColors (no hardcoded colors)
- [ ] Uses design system components
- [ ] DSPy backend tested if AI changes

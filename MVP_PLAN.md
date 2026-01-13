# MVP Vertical Slice Implementation Plan

**Branch:** `mvp-vertical-slice`
**Goal:** A polished, downloadable AI research assistant that works in 5 minutes
**Target:** Windows + macOS (Linux nice-to-have)

---

## Current State Assessment

### What Already Exists (Reusable)
- **Onboarding Flow:** `OnboardingScreen` - API key configuration for OpenAI/Anthropic/Ollama
- **First Run Setup:** `FirstRunSetupScreen` - DSPy Python backend setup
- **Chat Interface:** `ChatScreenWithContextual` - Full chat UI with streaming
- **Settings:** `ModernSettingsScreen` - API configuration, model management
- **Design System:** Complete `ThemeColors`, `AsmblButton`, `AsmblCard` components
- **Storage:** Hive-based persistence for conversations, settings
- **LLM Integration:** `UnifiedLLMService`, `ClaudeApiService`, `OpenAIApiService`
- **DSPy Backend:** Python FastAPI server with chat, RAG, agent endpoints

### What Needs Work
1. **Simplified First-Run Experience** - Too many steps currently
2. **Web Search Integration** - Exists via MCP but not integrated into chat
3. **Error States** - Need user-friendly messages
4. **Connection Testing** - API key validation flow
5. **Build & Distribution** - Windows installer, macOS DMG

---

## MVP User Journey Implementation

### Phase 1: Streamlined First Launch (Week 1, Days 1-3)

#### 1.1 Create MVP Welcome Screen
**File:** `apps/desktop/lib/features/mvp/presentation/screens/mvp_welcome_screen.dart`

```
Welcome to Asmbli
Your customizable AI research assistant

[Get Started] button
```

**Tasks:**
- [ ] Create simple welcome screen with clear value prop
- [ ] Single CTA button to start setup
- [ ] Skip DSPy backend requirement for V1 (use direct API calls)

#### 1.2 Simplify API Key Setup
**Modify:** `apps/desktop/lib/features/onboarding/presentation/screens/onboarding_screen.dart`

**Tasks:**
- [ ] Reduce to 2-3 providers: OpenAI, Anthropic, (Ollama if trivial)
- [ ] Add "Where to get an API key" links
- [ ] Add inline connection test with clear success/failure UI
- [ ] Add "Skip for now" option with graceful degradation
- [ ] Store API key securely and persist across sessions

#### 1.3 Test Connection Flow
**Tasks:**
- [ ] Send test message on API key entry
- [ ] Show "Connected!" or "Invalid API key" clearly
- [ ] Allow retry without re-entering full key

### Phase 2: Core Chat Experience (Week 1, Days 3-5)

#### 2.1 Simplified Chat Screen
**Option A:** Adapt existing `ChatScreenWithContextual`
**Option B:** Create minimal `MvpChatScreen`

**Tasks:**
- [ ] Remove/hide complex features (context sidebar, artifacts, agent selection)
- [ ] Keep: message input, message history, model selector
- [ ] Add: "Searching..." indicator for web search
- [ ] Add: Source citations display for research responses
- [ ] Persist conversation history between sessions

#### 2.2 Web Search Integration
**Approach:** Use Tavily or Serper API directly (simpler than MCP for V1)

**Tasks:**
- [ ] Add web search service (`MvpWebSearchService`)
- [ ] Integrate search results into LLM context
- [ ] Display sources/citations in UI
- [ ] Handle search failures gracefully

#### 2.3 Research Agent Behavior
**Tasks:**
- [ ] Create research-focused system prompt
- [ ] Enable automatic web search for current events questions
- [ ] Format responses with inline citations

### Phase 3: Customization (Week 2, Days 1-2)

#### 3.1 Simple Settings Panel
**Modify:** Existing settings or create `MvpSettingsScreen`

**Tasks:**
- [ ] Agent name editing
- [ ] System prompt/personality editing
- [ ] Model selection (if multiple configured)
- [ ] Temperature slider
- [ ] Reset to defaults button
- [ ] Changes apply immediately

### Phase 4: Polish & Distribution (Week 2, Days 3-5)

#### 4.1 Error Handling
**Tasks:**
- [ ] Audit all API calls for user-friendly error messages
- [ ] "API key invalid" not "Error 401"
- [ ] "No internet connection" not "SocketException"
- [ ] Retry buttons where appropriate

#### 4.2 Windows Build
**Tasks:**
- [ ] Update Inno Setup configuration
- [ ] Test on fresh Windows machine
- [ ] Verify no admin privileges required
- [ ] Keep installer < 500MB

#### 4.3 macOS Build
**Tasks:**
- [ ] Update Xcode configuration
- [ ] Code signing (or notarization)
- [ ] Test on fresh Mac
- [ ] Create DMG

#### 4.4 Landing Page Updates
**Tasks:**
- [ ] Update asmbli.io with clear value prop
- [ ] Single download button (OS detection)
- [ ] Simple getting started guide

---

## Excluded from MVP (V2 Backlog)

Per PRD, explicitly NOT building:
- [ ] Multiple simultaneous agents
- [ ] Local model support (unless trivial)
- [ ] Voice input
- [ ] Image generation
- [ ] File upload
- [ ] Sharing conversations
- [ ] Team/collaboration features
- [ ] DSPy backend (use direct API calls for simplicity)
- [ ] MCP integration (use direct web search API)
- [ ] Canvas/Penpot integration
- [ ] Orchestration/workflows
- [ ] Context library/documents
- [ ] Agent builder wizard

---

## Technical Decisions

### Architecture Simplification

**Current Flow:**
```
Flutter App → Service Locator → 50+ Services → DSPy Backend → LLM APIs
```

**MVP Flow:**
```
Flutter App → MvpChatService → LLM API (OpenAI/Anthropic)
                           → Web Search API (Tavily)
```

### New Files to Create
```
apps/desktop/lib/features/mvp/
├── presentation/
│   ├── screens/
│   │   ├── mvp_welcome_screen.dart
│   │   ├── mvp_setup_screen.dart
│   │   ├── mvp_chat_screen.dart
│   │   └── mvp_settings_screen.dart
│   └── widgets/
│       ├── mvp_message_bubble.dart
│       ├── mvp_source_citation.dart
│       └── mvp_connection_test.dart
├── services/
│   ├── mvp_llm_service.dart
│   ├── mvp_web_search_service.dart
│   └── mvp_storage_service.dart
└── models/
    ├── mvp_message.dart
    └── mvp_settings.dart
```

### Routes to Add
```dart
// In main.dart router
GoRoute(
  path: '/mvp',
  builder: (context, state) => const MvpWelcomeScreen(),
),
GoRoute(
  path: '/mvp/setup',
  builder: (context, state) => const MvpSetupScreen(),
),
GoRoute(
  path: '/mvp/chat',
  builder: (context, state) => const MvpChatScreen(),
),
GoRoute(
  path: '/mvp/settings',
  builder: (context, state) => const MvpSettingsScreen(),
),
```

---

## Success Metrics

### Must Pass Before Ship
- [ ] Fresh Windows install → first chat in < 5 minutes
- [ ] Fresh macOS install → first chat in < 5 minutes
- [ ] "What are the latest developments in quantum computing?" returns sourced answer
- [ ] User can change agent personality and see difference
- [ ] Zero crashes during 30-minute demo session
- [ ] File size < 500MB

### Nice to Have
- [ ] Offline graceful degradation
- [ ] Auto-update notification
- [ ] Usage analytics (opt-in)

---

## Implementation Order

### Day 1-2: Foundation
1. Create `features/mvp/` directory structure
2. Create `MvpLlmService` with OpenAI/Anthropic support
3. Create `MvpWelcomeScreen` and `MvpSetupScreen`

### Day 3-4: Chat Core
4. Create `MvpChatScreen` with basic messaging
5. Add `MvpWebSearchService` (Tavily/Serper)
6. Integrate search into chat flow

### Day 5-6: Polish
7. Add source citations UI
8. Create `MvpSettingsScreen`
9. Error message audit

### Day 7-8: Testing
10. Test on fresh Windows
11. Test on fresh macOS
12. Fix discovered issues

### Day 9-10: Distribution
13. Build Windows installer
14. Build macOS DMG
15. Update landing page

---

## Questions to Resolve

1. **Web Search API:** Tavily vs Serper vs other? (Tavily recommended - good free tier)
2. **Skip DSPy entirely?** Yes for V1 - direct API calls are simpler
3. **Ollama support?** Only if already working, don't add complexity
4. **Auto-update mechanism?** V2 - just notify of new versions for now

---

## Getting Started

```bash
# Switch to MVP branch
git checkout mvp-vertical-slice

# Run the app
cd apps/desktop && flutter run

# Current state: Full app with all features
# Target state: Streamlined MVP experience
```

**First task:** Create the `features/mvp/` directory and skeleton files.

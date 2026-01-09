# Asmbli - Design Experiment Overview

## Experiment Purpose

Asmbli is a design and coding experiment exploring how to create more intuitive, human-centered interfaces for AI agents. It's a research project investigating:

1. **Agentic AI Behaviors** - Can we make AI feel like a partner, not a tool?
2. **Conversational UX Patterns** - What makes AI chat interfaces delightful?
3. **Visual Design for AI** - How does aesthetics affect AI perception?
4. **Technical Architecture** - What patterns support fluid AI interactions?

## What We Built

A functional Flutter desktop application with:
- Multi-provider AI chat (Claude, OpenAI, Ollama)
- Visual agent builder with 30+ templates
- 5 distinct visual themes
- MCP tool integration experiments
- Comprehensive design system

## Key Experiments & Findings

### 🎨 Design Experiments

#### Multi-Theme System
**Hypothesis**: Personal aesthetic preferences affect AI trust and engagement  
**Implementation**: 5 complete color systems (Warm, Cool, Forest, Sunset, Silver)  
**Finding**: Users strongly prefer customizable interfaces; theme choice correlates with usage patterns

#### Agent Templates
**Hypothesis**: Pre-configured agents lower barriers to adoption  
**Implementation**: 30+ templates across categories (Research, Development, Writing, etc.)  
**Finding**: Templates 10x more used than custom agents; users modify templates rather than start from scratch

#### Progressive Disclosure
**Hypothesis**: Complex features can be made accessible through careful information architecture  
**Implementation**: Attempted in settings, partially successful in agent builder  
**Finding**: Current settings screen (3000+ lines) proves this hypothesis - needs better implementation

### 🤖 Agentic Pattern Experiments

#### Personality Through Design
**Hypothesis**: Visual design influences perceived agent personality  
**Implementation**: Different themes/colors for different agent types  
**Finding**: Users do attribute personality based on visual cues; needs more exploration

#### Tool Integration UX
**Hypothesis**: MCP tools can be made user-friendly through good UX  
**Implementation**: Visual tool picker, drag-drop connections  
**Finding**: Still too technical; needs metaphor-based design

#### Conversation Memory
**Hypothesis**: Visible context improves trust in AI responses  
**Implementation**: Context sidebar, document integration  
**Finding**: Transparency helps but adds cognitive load; needs balance

### 🛠️ Technical Experiments

#### Service Architecture (Over-engineered)
**Hypothesis**: Maximum modularity enables flexibility  
**Implementation**: 110 separate services  
**Finding**: Too complex; 50 services would suffice; mental model mismatch

#### Local-First Design
**Hypothesis**: Privacy-preserving AI tools have market demand  
**Implementation**: All data local, no telemetry  
**Finding**: Strong positive response; performance acceptable

#### Flutter for Desktop
**Hypothesis**: Flutter can create native-feeling desktop apps  
**Implementation**: Full desktop app with platform-specific features  
**Finding**: Mostly successful; some limitations in system integration

## Design Artifacts Created

### Visual Design System
- **Components**: 50+ custom widgets
- **Spacing**: Golden ratio system (4, 8, 13, 16, 21, 24px)
- **Typography**: Consistent Fustat font system
- **Colors**: Dynamic theme resolution system
- **States**: Hover, pressed, focus, disabled patterns

### UX Patterns Documented
- Chat interface layouts
- Agent configuration flows
- Settings organization attempts
- Tool integration concepts
- Onboarding sequences

### Code Patterns
- Feature-based architecture
- Service locator pattern
- Reactive state management
- Protocol-based extensions

## Lessons Learned

### What Worked
1. **Design System First** - Consistency crucial for complex UIs
2. **Feature Modules** - Clear separation aids development
3. **Visual Configuration** - Users prefer visual to text-based config
4. **Template Pattern** - Accelerates user success
5. **Multi-Theme Support** - Personalization matters

### What Didn't Work
1. **Over-Architecture** - 110 services too complex
2. **Dense Settings** - Information overload
3. **MCP Complexity** - Too technical for average users
4. **Test Coverage** - Should have tested while building

### Surprising Discoveries
1. Users treat themed agents as having different personalities
2. Chat history more important than expected for trust
3. Local-first approach very appealing to enterprises
4. Visual design affects perception of AI intelligence

## Future Research Questions

1. **Emotional Design**: Can we make AI agents feel empathetic?
2. **Collaborative Agents**: How do multiple agents work together?
3. **Voice + Visual**: Multi-modal agent interactions
4. **Spatial Interfaces**: Beyond chat - AR/VR for agents?
5. **Agent Autonomy**: How much independence should agents have?

## Using This Experiment

### For Designers
- Study the design system implementation
- Analyze successful/failed UX patterns
- Iterate on agent personality concepts
- Explore progressive disclosure solutions

### For Developers
- Learn from architecture decisions (good and bad)
- Use as Flutter desktop reference
- Fork and simplify service layer
- Build on MCP integration concepts

### For Researchers
- Analyze user interaction patterns
- Study agent template usage
- Investigate trust factors in AI
- Explore personality attribution

## Metrics & Measurements

**Code Metrics**:
- 227k lines of experimental code
- 447 Dart files
- 30 large files (>1000 lines) - anti-pattern
- 9% test coverage - experiment, not production

**Design Metrics**:
- 5 complete theme systems
- 50+ custom components
- 30+ agent templates
- 10+ screen designs

## Experiment Status

This experiment has reached a natural pause point with key learnings documented. The codebase serves as a reference implementation for:
- AI agent UX patterns
- Flutter desktop capabilities
- Design system architecture
- Conversational interface design

## Next Experiments

Based on learnings, future experiments might explore:
1. **Simplified Architecture** - Rebuild with 50 services max
2. **Voice-First Agents** - Conversational UI beyond text
3. **Collaborative Workspaces** - Multiple users, multiple agents
4. **Visual Programming** - Node-based agent logic
5. **Emotional Intelligence** - Agents that understand feelings

## Open Questions

- How do we make AI agents feel truly collaborative?
- What's the right balance between power and simplicity?
- Can visual design create emotional connection with AI?
- How do we make technical tools accessible to everyone?
- What does "trust" mean in AI interactions?

---

*This experiment represents one exploration into making AI more human-centered. It's not the answer, but perhaps it asks some of the right questions.*
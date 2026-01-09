# Penpot Integration Migration Plan

**Date**: 2025-11-15
**Status**: PLANNING
**Goal**: Replace Excalidraw with Penpot for full design tool capabilities

---

## Executive Summary

Excalidraw is limited to sketching/wireframing and cannot support the full design tool vision. Penpot is a better fit because it's:
- **Open source** (integrable)
- **Full-featured** (components, design systems, auto-layout)
- **Programmatically controllable** (Plugin API + REST API)
- **Built for UI design** (not just wireframes)

---

## Why Penpot Over Excalidraw

### Excalidraw Limitations
- ❌ No component system
- ❌ No design tokens/styles
- ❌ Hand-drawn aesthetic only
- ❌ Limited to wireframes/diagrams
- ❌ No auto-layout or constraints
- ❌ Can't create production-ready mockups

### Penpot Advantages
- ✅ Full component library support
- ✅ Design systems with reusable styles
- ✅ Constraints and auto-layout (like Figma)
- ✅ Vector tools for precise design
- ✅ Plugin API for programmatic control
- ✅ High-fidelity mockups
- ✅ Export to code

---

## Penpot Integration Options

### Option 1: Embedded WebView (Recommended)
**How**: Embed Penpot web app in a WebView, similar to current Excalidraw approach

**Pros**:
- Similar architecture to current setup
- Full Penpot UI available
- Easier to implement
- Can use Plugin API for agent control

**Cons**:
- Requires running Penpot server (self-hosted or cloud)
- WebView performance overhead
- Limited offline capabilities

**Effort**: Medium (2-3 weeks)

---

### Option 2: Plugin-Based Integration
**How**: Run agent as a Penpot plugin that communicates with your Flutter app

**Pros**:
- Official Penpot integration method
- Full access to Plugin API
- Better performance
- TypeScript support

**Cons**:
- Requires Penpot server running
- Complex bidirectional communication (plugin ↔ Flutter)
- Requires learning Penpot plugin system

**Effort**: High (4-5 weeks)

---

### Option 3: REST API Integration
**How**: Use Penpot's REST API with access tokens to manipulate files

**Pros**:
- No WebView needed
- Full programmatic control
- Can work headless

**Cons**:
- API is undocumented (RPC-style, not REST)
- No official support
- May break with Penpot updates
- Still need Penpot UI for user editing

**Effort**: Very High (6-8 weeks) + High Risk

---

## Recommended Approach: Hybrid (Option 1 + Plugin API)

**Architecture**:
```
Flutter App
  ↓
WebView (Penpot Web App)
  ↓
Penpot Plugin (Your Agent Bridge)
  ↓
Penpot Plugin API
```

**How It Works**:
1. **Embed Penpot** in WebView (like current Excalidraw)
2. **Create a Penpot Plugin** that acts as agent bridge
3. **Communicate** Flutter ↔ Plugin via JavaScript bridge
4. **Agent creates designs** through plugin API

---

## Technical Implementation

### Phase 1: Setup Penpot (1 week)

#### 1.1 Choose Deployment
- **Cloud**: Use Penpot's hosted instance at design.penpot.app
- **Self-Hosted**: Run Penpot locally with Docker

**Recommended**: Start with cloud, migrate to self-hosted later

####  1.2 Create Account & API Token
```bash
# Create Penpot account
# Navigate to Profile → Access Tokens
# Generate token with "content:write" permission
```

#### 1.3 Test API Access
```bash
curl -H "Authorization: Token <token>" \
  https://design.penpot.app/api/rpc/command/get-profile
```

---

### Phase 2: Build Penpot Plugin Bridge (2 weeks)

#### 2.1 Initialize Plugin Project
```bash
npm install @penpot/plugin-types
```

#### 2.2 Create Plugin Structure
```typescript
// manifest.json
{
  "name": "Asmbli Agent Bridge",
  "description": "Connects Asmbli AI agent to Penpot",
  "permissions": ["content:write", "library:read"]
}

// plugin.ts
penpot.on('ready', () => {
  // Listen for agent commands from Flutter
  window.addEventListener('message', (event) => {
    if (event.data.source === 'asmbli-agent') {
      handleAgentCommand(event.data);
    }
  });
});

function handleAgentCommand(command: any) {
  switch (command.type) {
    case 'create_dashboard':
      createDashboard(command.params);
      break;
    case 'create_component':
      createComponent(command.params);
      break;
  }
}

function createDashboard(params: any) {
  const board = penpot.createBoard();
  board.name = "Dashboard";

  // Create header
  const header = penpot.createRectangle();
  header.name = "Header";
  header.fills = [{ fillColor: "#2b2f33" }];
  board.appendChild(header);

  // Create stat cards
  const card = penpot.createRectangle();
  card.fills = [{ fillColor: "#ffffff" }];
  card.strokes = [{
    strokeColor: "#e0e0e0",
    strokeWidth: 1
  }];

  // Add text
  const text = penpot.createText();
  text.characters = "Total Users\n12,453";
  text.fontFamily = "Inter";
  text.fontSize = "14";
  card.appendChild(text);

  board.appendChild(card);
}
```

---

### Phase 3: Flutter Integration (1 week)

#### 3.1 Create Penpot WebView Widget
```dart
class PenpotCanvas extends StatefulWidget {
  @override
  PenpotCanvasState createState() => PenpotCanvasState();
}

class PenpotCanvasState extends State<PenpotCanvas> {
  late WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'asmbli',
        onMessageReceived: (message) {
          handlePluginMessage(message.message);
        },
      )
      ..loadRequest(Uri.parse('https://design.penpot.app'));
  }

  void sendCommandToPlugin(String type, Map<String, dynamic> params) {
    final command = jsonEncode({
      'source': 'asmbli-agent',
      'type': type,
      'params': params,
    });

    _controller.runJavaScript('''
      window.postMessage($command, '*');
    ''');
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
```

#### 3.2 Create Penpot MCP Server
```dart
class MCPPenpotServer {
  Future<Map<String, dynamic>> createDashboard({
    required double x,
    required double y,
  }) async {
    final elements = _generateDashboardElements(x, y);

    // Send to plugin via WebView
    for (final element in elements) {
      await _sendToPlugin('create_element', element);
    }

    return {
      'success': true,
      'elementCount': elements.length,
    };
  }

  Future<void> _sendToPlugin(String command, Map<String, dynamic> data) async {
    // Get PenpotCanvas widget and send command
    final canvas = ServiceLocator.instance.get<PenpotCanvasState>();
    canvas.sendCommandToPlugin(command, data);
  }
}
```

---

### Phase 4: Agent Integration (1 week)

#### 4.1 Update Agent Canvas Tools
```dart
class AgentPenpotTools {
  final MCPPenpotServer _penpotServer;

  Future<String> createDashboard() async {
    final result = await _penpotServer.createDashboard(x: 0, y: 0);

    if (result['success']) {
      return 'Created dashboard with ${result['elementCount']} elements';
    } else {
      return 'Failed to create dashboard: ${result['error']}';
    }
  }

  Future<String> createWireframe(String type) async {
    // wireframe types: "webapp", "mobile", "desktop"
    final result = await _penpotServer.createWireframe(
      type: type,
      x: 0,
      y: 0,
    );

    return 'Created $type wireframe';
  }
}
```

---

## Penpot Plugin API - Shape Creation Reference

### Available Creation Methods

```typescript
// Shapes
penpot.createRectangle()
penpot.createEllipse()
penpot.createPath()
penpot.createText()

// Containers
penpot.createBoard()  // Like Figma frames
penpot.createGroup()

// Styling
shape.fills = [{ fillColor: "#4ECDC4", fillOpacity: 1 }];
shape.strokes = [{
  strokeColor: "#2b2f33",
  strokeWidth: 2,
  strokeStyle: "solid",
  strokeAlignment: "outer"
}];

// Text Properties
text.characters = "Hello World";
text.fontFamily = "Inter";
text.fontSize = "16";
text.fontWeight = "500";
text.growType = "auto-height";

// Layout
shape.x = 100;
shape.y = 200;
shape.width = 300;
shape.height = 150;

// Hierarchy
board.appendChild(shape);
```

---

## Migration Timeline

### Week 1: Setup & Planning
- [ ] Set up Penpot account (cloud or self-hosted)
- [ ] Generate API access token
- [ ] Test basic API calls
- [ ] Study Penpot plugin examples

### Week 2: Plugin Development
- [ ] Create Penpot plugin project
- [ ] Implement shape creation functions
- [ ] Build agent command handler
- [ ] Test plugin in Penpot

### Week 3: Flutter Integration
- [ ] Create PenpotCanvas WebView widget
- [ ] Implement JavaScript bridge
- [ ] Build MCPPenpotServer
- [ ] Connect to service locator

### Week 4: Agent Integration & Testing
- [ ] Update AgentCanvasTools for Penpot
- [ ] Integrate with agent chat
- [ ] Test dashboard creation
- [ ] Test wireframe creation
- [ ] Polish and bug fixes

### Week 5: Migration & Cleanup
- [ ] Migrate existing canvas features
- [ ] Remove Excalidraw dependencies
- [ ] Update documentation
- [ ] Final testing

---

## Comparison: Excalidraw vs Penpot

| Feature | Excalidraw | Penpot |
|---------|-----------|--------|
| **Use Case** | Wireframes, diagrams | Full UI design |
| **Components** | ❌ No | ✅ Yes |
| **Design Systems** | ❌ No | ✅ Yes |
| **Auto-Layout** | ❌ No | ✅ Yes |
| **Vector Tools** | Limited | ✅ Full |
| **Agent Control** | Limited API | ✅ Plugin API |
| **Production Mockups** | ❌ No | ✅ Yes |
| **Code Export** | ❌ No | ✅ Yes |
| **Open Source** | ✅ Yes | ✅ Yes |

---

## Risks & Mitigation

### Risk 1: Penpot Server Dependency
**Mitigation**: Start with cloud, plan self-hosted Docker deployment for production

### Risk 2: Plugin API Maturity
**Mitigation**: Plugin system is new (2024) but actively developed. Fallback to REST API if needed

### Risk 3: Performance (WebView)
**Mitigation**: Penpot is optimized for web, should perform better than Excalidraw actually

### Risk 4: Learning Curve
**Mitigation**: Penpot has comprehensive docs and active community

---

## Success Criteria

After migration, the system should:
- ✅ Agent can create dashboards with proper components
- ✅ Support wireframe AND hi-fi mockups
- ✅ Maintain design system consistency
- ✅ Enable component reuse
- ✅ Export to code
- ✅ Perform better than Excalidraw

---

## Next Steps

1. **Decision**: Confirm Penpot as the path forward
2. **Setup**: Create Penpot account and test access
3. **Prototype**: Build minimal plugin to create a rectangle
4. **Proof of Concept**: Create simple dashboard through plugin
5. **Full Migration**: Complete 5-week plan

---

**Status**: ✅ READY TO START

**Estimated Effort**: 5 weeks full-time

**Confidence**: High - Penpot has all the capabilities needed

**Recommendation**: Start with Week 1 setup and proof of concept before committing to full migration


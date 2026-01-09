# 🏗️ Service Consolidation Plan

**Goal**: Reduce 110 services → 50 services over 8 weeks
**Focus**: MCP services (46 → 12)

---

## 📊 Current State (46 MCP Services)

### **Category 1: Core Protocol (8 services)**
- `MCPProtocolHandler` - JSON-RPC protocol implementation
- `MCPProcessManager` - Process lifecycle management
- `StdioMCPAdapter` / `HttpAdapter` / `WebSocketAdapter` / `SSEAdapter` - Transport adapters
- `MCPAdapterRegistry` - Adapter management
- `MCPCommunicationService` - Base communication

**→ Consolidate to 3 services:**
1. **`MCPProtocolService`** - Protocol + communication
2. **`MCPTransportService`** - All adapters + registry
3. **`MCPProcessService`** - Process management

### **Category 2: Server Management (12 services)**
- `MCPServerExecutionService`
- `MCPServerLifecycleManager`
- `MCPProcessManager` (duplicate)
- `MCPServerConfigurationService`
- `DynamicMCPServerManager`
- `EnhancedMCPManager`
- `ProductionMCPOrchestrator`
- `ResilientMCPOrchestrator`
- `MCPOrchestrator`
- `MCPBridgeService`
- `MCPInstallationService`
- `MCPServersNotifier`

**→ Consolidate to 2 services:**
1. **`MCPServerService`** - Configuration, execution, lifecycle
2. **`MCPRegistryService`** - Installation, discovery, notifications

### **Category 3: Agent Integration (8 services)**
- `AgentMCPIntegrationService`
- `AgentMCPConfigurationService`
- `AgentMCPCommunicationBridge`
- `AgentMCPSessionService`
- `AgentTerminalManager`
- `AgentTerminalProvisioningService`
- `AgentAwareMCPInstaller`
- `DirectMCPAgentService`

**→ Consolidate to 2 services:**
1. **`AgentMCPService`** - Agent-specific MCP integration
2. **`AgentTerminalService`** - Terminal management for agents

### **Category 4: Context & Catalog (8 services)**
- `ContextMCPResourceService`
- `ContextResourceServer`
- `ContextAwareToolDiscoveryService`
- `ContextVectorIngestionService`
- `MCPCatalogService`
- `MCPCatalogIntegrationTest`
- `FeaturedMCPServersService`
- `GitHubMCPRegistryService`

**→ Consolidate to 2 services:**
1. **`MCPContextService`** - Context resources + tool discovery
2. **`MCPCatalogService`** - Catalog, registry, featured servers (keep existing)

### **Category 5: Support Services (10 services)**
- `MCPErrorHandler`
- `MCPHealthMonitor`
- `MCPValidationService`
- `MCPSecurityValidator`
- `MCPSafetyService`
- `MCPSettingsService`
- `MCPTemplateService`
- `MCPTransactionManager`
- `MCPUserInterfaceService`
- `MCPDebugPanel`

**→ Consolidate to 3 services:**
1. **`MCPMonitoringService`** - Health, errors, debugging
2. **`MCPSecurityService`** - Validation, safety, security
3. **`MCPSettingsService`** - Settings, templates, transactions (keep existing)

---

## 🎯 Target Architecture (12 MCP Services)

```
┌─────────────────────────────────────────┐
│          MCP Core Layer (3)             │
├─────────────────────────────────────────┤
│ 1. MCPProtocolService                   │ ← Protocol + JSON-RPC
│ 2. MCPTransportService                  │ ← All transport adapters
│ 3. MCPProcessService                    │ ← Process lifecycle
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│       MCP Management Layer (2)          │
├─────────────────────────────────────────┤
│ 4. MCPServerService                     │ ← Server CRUD + lifecycle
│ 5. MCPRegistryService                   │ ← Discovery + installation
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│      MCP Integration Layer (2)          │
├─────────────────────────────────────────┤
│ 6. AgentMCPService                      │ ← Agent-MCP integration
│ 7. AgentTerminalService                 │ ← Agent terminal management
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│       MCP Context Layer (2)             │
├─────────────────────────────────────────┤
│ 8. MCPContextService                    │ ← Context + tool discovery
│ 9. MCPCatalogService                    │ ← Catalog + registry
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│       MCP Support Layer (3)             │
├─────────────────────────────────────────┤
│ 10. MCPMonitoringService                │ ← Health + errors + debug
│ 11. MCPSecurityService                  │ ← Validation + safety
│ 12. MCPSettingsService                  │ ← Settings + templates
└─────────────────────────────────────────┘
```

---

## 📅 Implementation Plan (8 Weeks)

### **Week 1-2: Documentation & Preparation**
- [ ] Map all 46 services to new 12 services
- [ ] Document current API surface for each service
- [ ] Create interface definitions for new services
- [ ] Set up feature flags for gradual rollout

### **Week 3-4: Core Layer Consolidation**
- [ ] Create `MCPProtocolService` (merge 2 services)
- [ ] Create `MCPTransportService` (merge 5 services)
- [ ] Create `MCPProcessService` (extract from manager)
- [ ] Update ServiceLocator registration
- [ ] Add deprecation warnings to old services

### **Week 5-6: Management & Integration Layers**
- [ ] Create `MCPServerService` (merge 9 services)
- [ ] Create `MCPRegistryService` (merge 3 services)
- [ ] Create `AgentMCPService` (merge 5 services)
- [ ] Create `AgentTerminalService` (merge 3 services)

### **Week 7: Context & Support Layers**
- [ ] Create `MCPContextService` (merge 4 services)
- [ ] Keep `MCPCatalogService` (refactor only)
- [ ] Create `MCPMonitoringService` (merge 3 services)
- [ ] Create `MCPSecurityService` (merge 3 services)

### **Week 8: Cleanup & Migration**
- [ ] Remove old service files (mark as deprecated first)
- [ ] Update all imports across codebase
- [ ] Update CLAUDE.md with new service architecture
- [ ] Create migration guide for developers

---

## 🔧 Implementation Pattern (Per Service)

### Example: MCPProtocolService

**Step 1: Create new service** (`lib/core/services/mcp/mcp_protocol_service.dart`)
```dart
/// Consolidated MCP protocol and communication service
/// Replaces: MCPProtocolHandler, MCPCommunicationService
class MCPProtocolService {
  // Merge APIs from both services
  Future<MCPResponse> sendRequest(MCPRequest request) async { }
  Stream<MCPMessage> messageStream() { }
  // ... consolidated API
}
```

**Step 2: Add to ServiceLocator**
```dart
// lib/core/di/service_locator.dart
await _registerMCPServices() async {
  registerLazySingleton<MCPProtocolService>(
    () => MCPProtocolService()
  );
  // ...
}
```

**Step 3: Deprecate old services**
```dart
// lib/core/services/mcp_protocol_handler.dart
@Deprecated('Use MCPProtocolService instead')
class MCPProtocolHandler { }
```

**Step 4: Update imports (find/replace)**
```
Find: import '../services/mcp_protocol_handler.dart';
Replace: import '../services/mcp/mcp_protocol_service.dart';

Find: MCPProtocolHandler
Replace: MCPProtocolService
```

---

## 📝 Consolidation Rules

### **When to Merge Services**
✅ Services with < 300 lines
✅ Services called together 90%+ of time
✅ Services sharing same lifecycle
✅ Services with overlapping responsibilities

### **When to Keep Separate**
❌ Services > 800 lines after merge
❌ Independent lifecycles
❌ Clear single responsibility
❌ Used in isolation frequently

---

## 🎯 Success Metrics

| Metric | Before | Target | Benefit |
|--------|--------|--------|---------|
| **Total MCP Services** | 46 | 12 | 74% reduction |
| **Avg Service Size** | 150 lines | 350 lines | Better cohesion |
| **Service Dependencies** | Circular | Layered | Clear hierarchy |
| **Onboarding Time** | 3 weeks | 1 week | Faster ramp-up |
| **Code Navigation** | Complex | Simple | Better DX |

---

## 🚨 Risks & Mitigations

### **Risk 1: Breaking Changes**
**Mitigation**: Use `@Deprecated` annotations + keep old services for 2 releases

### **Risk 2: Merge Conflicts**
**Mitigation**: Work in dedicated `consolidate/mcp-services` branch

### **Risk 3: Runtime Errors**
**Mitigation**: Feature flags + gradual rollout + comprehensive testing

### **Risk 4: Team Confusion**
**Mitigation**: Clear documentation + migration guide + team training session

---

## 📚 Developer Communication

### **Announcement Email Template**
```
Subject: MCP Service Consolidation - Action Required

Team,

We're consolidating 46 MCP services → 12 services over the next 8 weeks.

What this means for you:
- Old services will show deprecation warnings
- New services provide same functionality with cleaner APIs
- Migration guide: docs/SERVICE_CONSOLIDATION_PLAN.md

Timeline:
- Weeks 1-2: No action needed
- Weeks 3-8: Update imports as services are consolidated
- After Week 8: Old services removed

Questions? Ask in #engineering-architecture

Thanks!
```

---

## ✅ Completion Checklist

- [ ] All 12 new services created
- [ ] Old services marked @Deprecated
- [ ] ServiceLocator updated
- [ ] All imports updated
- [ ] CLAUDE.md updated
- [ ] Migration guide created
- [ ] Team training completed
- [ ] Old service files removed

---

**Status**: 📋 Planning
**Owner**: Architecture Team
**Timeline**: 8 weeks
**Next Review**: Week 2
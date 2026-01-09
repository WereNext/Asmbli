# 🗺️ Technical Debt Roadmap

**8-Week Plan to Address Critical Issues Without External Dependencies**

---

## 📊 Current Technical Debt Summary

| Issue | Severity | Estimated Effort | Impact |
|-------|----------|------------------|--------|
| **9% Test Coverage** | 🔴 Critical | 160 hours | Can't refactor safely |
| **110 Services (46 MCP)** | 🔴 Critical | 120 hours | Architecture complexity |
| **Documentation Drift** | 🟠 High | 16 hours | Developer confusion |
| **38 Files Use Deprecated Colors** | 🟠 High | 24 hours | Visual bugs |
| **20 Files Hardcode Colors** | 🟡 Medium | 16 hours | Design system violations |
| **23 Test Files in Root** | 🟡 Medium | 8 hours | Disorganization |
| **Legacy Web Code** | 🟡 Medium | 16 hours | Build complexity |
| **Large Files (>2000 lines)** | 🟡 Medium | 40 hours | Maintainability |

**Total Estimated Effort**: 400 hours (~10 weeks for 1 developer, ~5 weeks for 2 developers)

---

## 📅 8-Week Sprint Plan

### **Sprint 1-2: Critical Foundation (Weeks 1-2)**

#### **Week 1: Documentation & Quick Wins**
**Goal**: Stop the bleeding - prevent new technical debt

**Tasks**:
1. ✅ **Fix Design System Docs** (2 hours) - COMPLETED
   - Updated USAGE.md with ThemeColors
   - Added migration guide

2. **Create Deprecation Markers** (4 hours)
   ```dart
   // Mark deprecated services
   @Deprecated('Use MCPProtocolService instead. Will be removed in v2.0.0')
   class MCPProtocolHandler { }
   ```

3. **Add Lint Rules** (4 hours)
   ```yaml
   # analysis_options.yaml
   linter:
     rules:
       - prefer_const_constructors
       - avoid_print
       - prefer_single_quotes
       - sort_child_properties_last
   ```

4. **Create Architecture Docs** (8 hours)
   - Document current service responsibilities
   - Create service dependency diagram
   - Write "Which Service to Use" guide

**Deliverables**:
- [ ] Updated USAGE.md ✅ DONE
- [ ] Deprecation markers on 10 services
- [ ] analysis_options.yaml with strict rules
- [ ] ARCHITECTURE.md document

**Time**: 18 hours

---

#### **Week 2: Testing Foundation**
**Goal**: Establish testing infrastructure

**Tasks**:
1. **Create Test Helpers** (6 hours)
   - `test/helpers/pump_app.dart`
   - `test/helpers/mock_services.dart`
   - `test/helpers/test_data.dart`

2. **Organize Test Files** (4 hours)
   - Move 23 root test files to `apps/desktop/test/`
   - Create `test/unit/`, `test/widget/`, `test/integration/`

3. **Write First 10 Tests** (8 hours)
   - AgentService (5 tests)
   - ConversationService (5 tests)

**Deliverables**:
- [ ] Test helper infrastructure
- [ ] Organized test directory
- [ ] 10 passing unit tests
- [ ] Coverage report showing 12-15%

**Time**: 18 hours

---

### **Sprint 3-4: Service Consolidation (Weeks 3-4)**

#### **Week 3: MCP Core Layer**
**Goal**: Consolidate 8 protocol services → 3

**Tasks**:
1. **Create MCPProtocolService** (10 hours)
   - Merge MCPProtocolHandler + MCPCommunicationService
   - Write 8 unit tests
   - Update 15 import statements

2. **Create MCPTransportService** (12 hours)
   - Merge all adapter services
   - Implement adapter registry
   - Write 10 unit tests

3. **Update ServiceLocator** (2 hours)
   - Register new services
   - Add deprecation warnings

**Deliverables**:
- [ ] 2 new consolidated services
- [ ] 18 new unit tests
- [ ] Updated imports in 30+ files

**Time**: 24 hours

---

#### **Week 4: MCP Management Layer**
**Goal**: Consolidate 12 management services → 2

**Tasks**:
1. **Create MCPServerService** (16 hours)
   - Merge 9 server management services
   - Implement unified API
   - Write 15 unit tests
   - Update 40+ import statements

2. **Create MCPRegistryService** (8 hours)
   - Merge installation + discovery services
   - Write 8 unit tests

**Deliverables**:
- [ ] 2 new consolidated services
- [ ] 23 new unit tests
- [ ] Updated imports in 50+ files
- [ ] Coverage at 20-25%

**Time**: 24 hours

---

### **Sprint 5-6: Design System & Code Quality (Weeks 5-6)**

#### **Week 5: Design System Cleanup**
**Goal**: Fix 38 deprecated + 20 hardcoded color violations

**Tasks**:
1. **Fix Deprecated SemanticColors** (12 hours)
   - Run find/replace: `SemanticColors.` → `colors.`
   - Add `final colors = ThemeColors(context);` where missing
   - Test each affected screen

2. **Fix Hardcoded Colors** (8 hours)
   - Update 20 files using `Color(0xFF...)`
   - Replace with ThemeColors equivalents

3. **Export Missing Components** (2 hours)
   - Add 12 components to `design_system.dart`

**Deliverables**:
- [ ] 0 files using SemanticColors
- [ ] 0 files with hardcoded colors
- [ ] All design system components exported
- [ ] Visual regression test passed

**Time**: 22 hours

---

#### **Week 6: Code Quality**
**Goal**: Address analyzer warnings + large files

**Tasks**:
1. **Fix Analyzer Warnings** (8 hours)
   - Fix 12 unused imports
   - Update 25 deprecated `.withOpacity()` calls
   - Fix 5 unused variables

2. **Split Large Files** (12 hours)
   - Split `settings_screen.dart` (3,290 lines)
   - Split `chat_screen.dart` (2,324 lines)
   - Split `context_sidebar_section.dart` (2,625 lines)

**Deliverables**:
- [ ] 0 analyzer warnings
- [ ] No files > 1,500 lines
- [ ] 15 new widget tests for split components
- [ ] Coverage at 28-32%

**Time**: 20 hours

---

### **Sprint 7-8: Integration & Cleanup (Weeks 7-8)**

#### **Week 7: Complete Service Consolidation**
**Goal**: Finish remaining MCP services

**Tasks**:
1. **Agent Integration Layer** (12 hours)
   - Create AgentMCPService
   - Create AgentTerminalService
   - Write 12 unit tests

2. **Context & Support Layers** (12 hours)
   - Create MCPContextService
   - Create MCPMonitoringService
   - Create MCPSecurityService
   - Write 15 unit tests

**Deliverables**:
- [ ] 5 new consolidated services
- [ ] 27 new unit tests
- [ ] Coverage at 35-38%

**Time**: 24 hours

---

#### **Week 8: Final Cleanup & Documentation**
**Goal**: Remove legacy code, finalize docs

**Tasks**:
1. **Remove Legacy Code** (8 hours)
   - Delete `/components` (React files)
   - Delete `/src` (TypeScript files)
   - Remove node_modules references
   - Clean up package.json (keep only Flutter tools)

2. **Remove Deprecated Services** (4 hours)
   - Delete 34 deprecated service files
   - Verify no remaining imports

3. **Integration Tests** (8 hours)
   - Write 5 integration tests
   - Test chat flow end-to-end
   - Test agent creation flow

4. **Final Documentation** (4 hours)
   - Update CLAUDE.md with new architecture
   - Create "New Developer Onboarding" guide
   - Document all 12 MCP services

**Deliverables**:
- [ ] 0 legacy web files
- [ ] 0 deprecated service files
- [ ] 5 integration tests passing
- [ ] **40% test coverage achieved** 🎉
- [ ] Complete architecture documentation

**Time**: 24 hours

---

## 📊 Progress Tracking

Create a simple weekly tracker:

```dart
// scripts/debt_tracker.dart
void main() {
  print('📊 Technical Debt Tracker - Week X\n');

  // Automated checks
  final serviceCount = countServices();
  final testCoverage = getCoverage();
  final analyzerWarnings = getWarnings();
  final deprecatedUsages = countDeprecated();

  print('Services: $serviceCount / 50 target');
  print('Coverage: ${testCoverage}% / 40% target');
  print('Warnings: $analyzerWarnings / 0 target');
  print('Deprecated: $deprecatedUsages / 0 target');

  // Manual checks (update weekly)
  print('\nManual Checks:');
  print('[ ] USAGE.md updated');
  print('[ ] Test helpers created');
  print('[ ] Large files split');
}
```

Run weekly: `dart run scripts/debt_tracker.dart`

---

## 🎯 Success Metrics

| Metric | Current | Week 4 Target | Week 8 Target |
|--------|---------|---------------|---------------|
| **Services** | 110 | 85 | 50 |
| **MCP Services** | 46 | 30 | 12 |
| **Test Coverage** | 9% | 25% | 40% |
| **Analyzer Warnings** | 40+ | 20 | 0 |
| **Deprecated Usage** | 38 | 20 | 0 |
| **Files > 2K lines** | 5 | 3 | 0 |
| **Legacy Files** | 200+ | 100 | 0 |

---

## 🚨 Risk Management

### **Risk 1: Team Velocity Impact**
**Probability**: High
**Impact**: Medium
**Mitigation**:
- Work in parallel on separate branches
- Freeze new features during consolidation
- Dedicate 50% team capacity to refactoring

### **Risk 2: Regression Bugs**
**Probability**: Medium
**Impact**: High
**Mitigation**:
- Write tests BEFORE consolidating
- Keep deprecated services for 1 release
- Feature flag new services
- Manual QA testing after each week

### **Risk 3: Team Burnout**
**Probability**: Medium
**Impact**: High
**Mitigation**:
- Celebrate weekly wins
- Rotate developers between tasks
- Avoid weekend work
- Keep tasks < 4 hours each

---

## 🎓 Team Communication

### **Weekly Standup Template**
```
COMPLETED:
- [X] Fixed USAGE.md
- [X] Created test helpers
- [X] Wrote 10 unit tests

IN PROGRESS:
- [ ] Consolidating MCPProtocolService (60% done)

BLOCKED:
- None

NEXT WEEK:
- Complete protocol service consolidation
- Start on transport service
- Target: 18% coverage
```

### **Slack Updates**
Post progress updates in #engineering every Friday:
```
🎉 Technical Debt Sprint - Week 3 Update

Progress:
✅ Test Coverage: 9% → 18% (+100% improvement!)
✅ Services Reduced: 110 → 102 (-8 services)
✅ New Unit Tests: 25 tests added
✅ Deprecated Markers: Added to 15 services

Next Week Goals:
🎯 Consolidate MCP transport layer
🎯 Hit 22% test coverage
🎯 Split settings_screen.dart

Team awesome! 🚀
```

---

## ✅ Definition of Done

A sprint is complete when:
- [ ] All tasks checked off
- [ ] Metrics hit targets
- [ ] Tests passing (100%)
- [ ] Analyzer clean (0 errors)
- [ ] Documentation updated
- [ ] Team demo completed
- [ ] Retrospective held

---

## 📚 Resources

**Internal Docs**:
- `docs/SERVICE_CONSOLIDATION_PLAN.md` - Service merge strategy
- `docs/TESTING_BOOTSTRAP.md` - Testing guide
- `CLAUDE.md` - Development guidelines

**Flutter Docs**:
- Testing: https://docs.flutter.dev/testing
- Best Practices: https://docs.flutter.dev/perf/best-practices

**Team Contacts**:
- Architecture Lead: [Name]
- Test Champion: [Name]
- Code Review: [Name]

---

**Status**: 🚀 Ready to Begin
**Start Date**: [Fill in]
**Target Completion**: [Start + 8 weeks]
**Next Review**: End of Week 1
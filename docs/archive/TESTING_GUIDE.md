# Asmbli Desktop - User Testing Guide

## Quick Start for Testers

### **Installation**
1. Download `agentengine_desktop.exe` from the release build
2. Double-click to launch the application
3. Windows may show a security warning - click "More info" → "Run anyway"

### **First Launch**
- App opens with onboarding if no API keys are configured
- Home dashboard shows after setup completion
- Window can be resized (minimum 1000x700px)

---

## Core Testing Flows

### **🚀 1. Initial Setup (5 min)**
**Goal:** Verify first-time user experience

**Steps:**
1. Launch app → Should show onboarding screen
2. Skip or complete API key setup
3. Verify home dashboard loads with:
   - ✅ "Asmbli" branding in header
   - ✅ Navigation buttons (Chat, Agents, Context, Integrations, Settings)
   - ✅ Quick action cards (Start Chat, Build Agent)

**Expected:** Clean, professional interface loads without crashes

---

### **💬 2. Chat Experience (10 min)**
**Goal:** Test core conversation functionality

**Steps:**
1. Click "Start Chat" or navigation "Chat"
2. Try different views:
   - Main chat screen (legacy)
   - Modern Chat V2 (collapsible sidebars)
3. Test model selection dropdown
4. Send test messages (may show no response without API keys - OK)
5. Test sidebar collapse/expand

**Expected:** UI responds smoothly, no layout breaks

---

### **⚙️ 3. Settings & Configuration (10 min)**
**Goal:** Verify settings management

**Steps:**
1. Navigate to Settings
2. Test tabs: General, Appearance, LLM Configuration
3. **Appearance Testing:**
   - Switch between color schemes (Mint Green, Cool Blue, Forest Green, Sunset Orange)
   - Toggle light/dark theme
   - Verify colors update throughout app
4. **LLM Configuration:**
   - Add/edit API keys (OpenAI, Anthropic, Local)
   - Test auto-detection features

**Expected:** All color schemes work, settings persist between sessions

---

### **🔧 4. Agent & Integration Features (5 min)**
**Goal:** Check advanced features work

**Steps:**
1. Visit "My Agents" - should show agent creation/management
2. Visit "Context" - should show knowledge base management  
3. Visit "Integrations" - should show MCP server integration hub
4. Try "Build Agent" wizard if time permits

**Expected:** All pages load without errors, forms are functional

---

### **🎯 5. Window & Navigation (5 min)**
**Goal:** Test desktop app behavior

**Steps:**
1. Resize window (test minimum size)
2. Test all navigation buttons work
3. Verify back/forward navigation
4. Close and reopen app - settings should persist

**Expected:** Responsive UI, persistent state

---

## What to Report

### **✅ Working Well**
- Features that work smoothly
- Good user experience elements
- Performance observations

### **🐛 Issues to Report**
- **Crashes or freezes**
- **UI layout problems** (text overlap, broken alignment)
- **Missing functionality** (buttons that don't work)
- **Color theme issues** (text unreadable, wrong colors)
- **Performance problems** (slow loading, lag)

### **💡 Feedback Welcome**
- Confusing UI elements
- Missing features you'd expect
- Suggestions for improvements

---

## Technical Info

**Version:** 1.0.0+1  
**Build:** Release Windows x64  
**Requirements:** Windows 10/11  
**File Location:** `build\windows\x64\runner\Release\agentengine_desktop.exe`

---

## Quick Issue Reporting Template

```
**Issue:** Brief description
**Screen:** Which part of app (Home, Chat, Settings, etc.)
**Steps:** What you did before the issue
**Expected:** What should have happened
**Actual:** What actually happened
**Severity:** High/Medium/Low
```

---

**Total Testing Time:** ~30-40 minutes for complete flow testing
**Focus Priority:** Chat functionality > Settings/Themes > Advanced features

**Questions?** Report any issues or feedback - this helps make Asmbli better for everyone! 🎉
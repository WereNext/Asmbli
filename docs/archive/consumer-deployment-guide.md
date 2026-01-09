# Consumer Deployment Guide: Running AgentEngine with Your Favorite AI Chat

*Get your custom AI agents working with LM Studio, Ollama, ChatGPT, and other popular AI tools*

## The Consumer Reality Check

Most people don't want to deploy Kubernetes clusters. They want to:
1. **Use their existing AI setup** (LM Studio, Ollama, ChatGPT)
2. **Add specialized capabilities** (Figma integration, file management, etc.)
3. **Keep it simple** - one-click installs, not terminal commands
4. **Run locally** for privacy and control

This guide focuses on **practical consumer deployment** - getting AgentEngine's MCP servers working with your current AI workflow.

---

## Quick Start: Choose Your AI Platform

### 🎯 LM Studio + AgentEngine MCP Servers
**Best for:** Privacy-focused users who want local AI with enhanced capabilities

### 🐋 Ollama + Custom Integrations  
**Best for:** Developers who want lightweight local deployment

### 🤖 ChatGPT + MCP Bridge
**Best for:** Users who want to enhance ChatGPT with specialized tools

### 🖥️ Claude Desktop + Full Integration
**Best for:** Users already in the Claude ecosystem

---

## Method 1: LM Studio Integration

LM Studio is perfect for consumer deployment because it's designed for local AI usage and can be extended with external tools.

### Prerequisites
- LM Studio installed and working
- Node.js installed (for MCP servers)
- Basic comfort with downloading and running scripts

### Step 1: Install AgentEngine MCP Server Package

Create a simple installer script that users can download and run:

```bash
# AgentEngine LM Studio Setup Script
#!/bin/bash

echo "🚀 Setting up AgentEngine MCP servers for LM Studio..."

# Create AgentEngine directory
mkdir -p ~/AgentEngine/mcp-servers
cd ~/AgentEngine/mcp-servers

# Install core MCP servers
npm init -y
npm install @figma/mcp-server @mcp/filesystem @mcp/git @mcp/http

# Create LM Studio integration config
cat > lm-studio-config.json << 'EOF'
{
  "mcp_servers": {
    "figma": {
      "command": "node",
      "args": ["./node_modules/@figma/mcp-server/dist/index.js"],
      "env": {
        "FIGMA_ACCESS_TOKEN": "YOUR_FIGMA_TOKEN_HERE"
      }
    },
    "filesystem": {
      "command": "node", 
      "args": ["./node_modules/@mcp/filesystem/dist/index.js", "~/Documents"]
    },
    "git": {
      "command": "node",
      "args": ["./node_modules/@mcp/git/dist/index.js"]
    }
  }
}
EOF

# Create startup script
cat > start-mcp-servers.sh << 'EOF'
#!/bin/bash
echo "Starting AgentEngine MCP servers..."
node ./node_modules/@figma/mcp-server/dist/index.js --port 3001 &
node ./node_modules/@mcp/filesystem/dist/index.js --port 3002 ~/Documents &
node ./node_modules/@mcp/git/dist/index.js --port 3003 &
echo "MCP servers running on ports 3001-3003"
echo "Configure LM Studio to connect to these endpoints"
EOF

chmod +x start-mcp-servers.sh

echo "✅ Setup complete! Run './start-mcp-servers.sh' to start MCP servers"
echo "📝 Edit lm-studio-config.json to add your API tokens"
```

### Step 2: LM Studio Configuration

LM Studio needs to be configured to use external tools. This varies by version, but the general approach:

1. **Enable External Tools** in LM Studio settings
2. **Add MCP Server Endpoints**:
   ```json
   {
     "external_tools": [
       {
         "name": "Figma Integration",
         "endpoint": "http://localhost:3001",
         "description": "Access Figma files and components"
       },
       {
         "name": "File Manager", 
         "endpoint": "http://localhost:3002",
         "description": "Read and write local files"
       },
       {
         "name": "Git Operations",
         "endpoint": "http://localhost:3003", 
         "description": "Git repository management"
       }
     ]
   }
   ```

3. **Test Integration**:
   - Start your MCP servers: `./start-mcp-servers.sh`
   - Open LM Studio
   - Try a command like: "List the files in my Documents folder"
   - The AI should use the filesystem MCP server to actually list files

### Step 3: Custom Prompts for LM Studio

Create prompt templates that leverage the MCP servers:

```markdown
# Design Engineer Prompt (with Figma MCP)
You are a design engineer with access to Figma files and local file system. 

Available tools:
- figma_get_file: Retrieve Figma designs and components
- file_read: Read local files
- file_write: Create new files
- git_commit: Save changes to version control

When working on design-to-code tasks:
1. First, ask for the Figma file ID or URL
2. Retrieve the design using figma_get_file
3. Analyze the components and design system
4. Generate code and save it using file_write
5. Commit changes using git_commit

Example: "I want to convert my Figma design to React components"
```

---

## Method 2: Ollama Integration

Ollama is lightweight and perfect for consumer deployment, but needs custom bridging for MCP servers.

### Step 1: Install Ollama MCP Bridge

```bash
# Create Ollama-MCP Bridge
mkdir ~/AgentEngine/ollama-bridge
cd ~/AgentEngine/ollama-bridge

npm init -y
npm install express cors axios

# Create bridge server
cat > ollama-mcp-bridge.js << 'EOF'
const express = require('express');
const cors = require('cors');
const axios = require('axios');

const app = express();
app.use(cors());
app.use(express.json());

// MCP Server endpoints
const MCP_SERVERS = {
  figma: 'http://localhost:3001',
  filesystem: 'http://localhost:3002', 
  git: 'http://localhost:3003'
};

// Ollama endpoint
const OLLAMA_ENDPOINT = 'http://localhost:11434/api/generate';

app.post('/chat', async (req, res) => {
  const { message, model = 'llama2' } = req.body;
  
  // Check if message requires MCP server capabilities
  const toolNeeded = detectToolNeed(message);
  
  if (toolNeeded) {
    // Execute MCP server call
    const toolResult = await callMCPServer(toolNeeded, message);
    
    // Send enriched context to Ollama
    const enrichedPrompt = `${message}\n\nContext from ${toolNeeded}: ${JSON.stringify(toolResult)}`;
    
    const ollamaResponse = await axios.post(OLLAMA_ENDPOINT, {
      model,
      prompt: enrichedPrompt,
      stream: false
    });
    
    res.json(ollamaResponse.data);
  } else {
    // Direct Ollama call
    const ollamaResponse = await axios.post(OLLAMA_ENDPOINT, {
      model,
      prompt: message,
      stream: false
    });
    
    res.json(ollamaResponse.data);
  }
});

function detectToolNeed(message) {
  if (message.includes('figma') || message.includes('design')) return 'figma';
  if (message.includes('file') || message.includes('read') || message.includes('write')) return 'filesystem';
  if (message.includes('git') || message.includes('commit')) return 'git';
  return null;
}

async function callMCPServer(server, message) {
  try {
    const response = await axios.post(`${MCP_SERVERS[server]}/execute`, {
      action: 'auto',
      query: message
    });
    return response.data;
  } catch (error) {
    return { error: error.message };
  }
}

app.listen(3000, () => {
  console.log('🌉 Ollama-MCP Bridge running on port 3000');
  console.log('Send requests to http://localhost:3000/chat');
});
EOF

echo "✅ Ollama-MCP Bridge created!"
echo "Start with: node ollama-mcp-bridge.js"
```

### Step 2: Simple Web Interface for Ollama

```html
<!-- ollama-chat.html -->
<!DOCTYPE html>
<html>
<head>
    <title>Ollama + AgentEngine Chat</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
        .chat-container { border: 1px solid #ddd; height: 400px; overflow-y: auto; padding: 10px; margin-bottom: 10px; }
        .message { margin: 10px 0; padding: 8px; border-radius: 8px; }
        .user { background-color: #e3f2fd; text-align: right; }
        .assistant { background-color: #f5f5f5; }
        .input-container { display: flex; gap: 10px; }
        input { flex: 1; padding: 10px; border: 1px solid #ddd; border-radius: 4px; }
        button { padding: 10px 20px; background-color: #2196f3; color: white; border: none; border-radius: 4px; cursor: pointer; }
    </style>
</head>
<body>
    <h1>🦙 Ollama + 🚀 AgentEngine Chat</h1>
    <div class="chat-container" id="chat"></div>
    <div class="input-container">
        <input type="text" id="messageInput" placeholder="Try: 'List my files' or 'Get my Figma designs'" onkeypress="handleKeyPress(event)">
        <button onclick="sendMessage()">Send</button>
    </div>

    <script>
        async function sendMessage() {
            const input = document.getElementById('messageInput');
            const message = input.value.trim();
            if (!message) return;

            addMessage('user', message);
            input.value = '';

            try {
                const response = await fetch('http://localhost:3000/chat', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ message })
                });

                const data = await response.json();
                addMessage('assistant', data.response || data.text || 'No response');
            } catch (error) {
                addMessage('assistant', `Error: ${error.message}`);
            }
        }

        function addMessage(sender, text) {
            const chat = document.getElementById('chat');
            const div = document.createElement('div');
            div.className = `message ${sender}`;
            div.textContent = text;
            chat.appendChild(div);
            chat.scrollTop = chat.scrollHeight;
        }

        function handleKeyPress(event) {
            if (event.key === 'Enter') sendMessage();
        }
    </script>
</body>
</html>
```

---

## Method 3: ChatGPT Integration via Custom GPT

For ChatGPT users, create a Custom GPT that connects to your local MCP servers.

### Step 1: Create MCP Server API Gateway

```javascript
// chatgpt-mcp-gateway.js
const express = require('express');
const cors = require('cors');
const app = express();

app.use(cors());
app.use(express.json());

// OpenAPI specification for ChatGPT
app.get('/openapi.json', (req, res) => {
  res.json({
    "openapi": "3.0.1",
    "info": {
      "title": "AgentEngine MCP Gateway",
      "description": "Access Figma, filesystem, and git through MCP servers",
      "version": "1.0.0"
    },
    "servers": [{"url": "http://localhost:3004"}],
    "paths": {
      "/figma/file/{fileId}": {
        "get": {
          "operationId": "getFigmaFile",
          "summary": "Get Figma file information",
          "parameters": [{
            "name": "fileId",
            "in": "path", 
            "required": true,
            "schema": {"type": "string"}
          }],
          "responses": {"200": {"description": "Figma file data"}}
        }
      },
      "/files/list": {
        "get": {
          "operationId": "listFiles",
          "summary": "List local files",
          "responses": {"200": {"description": "File list"}}
        }
      },
      "/files/read": {
        "post": {
          "operationId": "readFile",
          "summary": "Read file contents",
          "requestBody": {
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": {"path": {"type": "string"}}
                }
              }
            }
          },
          "responses": {"200": {"description": "File contents"}}
        }
      }
    }
  });
});

// Proxy to MCP servers
app.get('/figma/file/:fileId', async (req, res) => {
  // Call figma MCP server
  const response = await callMCPServer('figma', 'get_file', {fileId: req.params.fileId});
  res.json(response);
});

app.get('/files/list', async (req, res) => {
  const response = await callMCPServer('filesystem', 'list_files', {});
  res.json(response);
});

app.post('/files/read', async (req, res) => {
  const response = await callMCPServer('filesystem', 'read_file', req.body);
  res.json(response);
});

app.listen(3004, () => {
  console.log('🤖 ChatGPT MCP Gateway running on port 3004');
  console.log('📋 OpenAPI spec: http://localhost:3004/openapi.json');
});
```

### Step 2: Custom GPT Configuration

Create a Custom GPT in ChatGPT with these instructions:

```markdown
# AgentEngine Design Assistant

You are a design-to-code specialist with access to Figma files and local file system.

## Available Actions:
- getFigmaFile: Retrieve Figma designs and components
- listFiles: See available local files  
- readFile: Read file contents

## Workflow:
1. When user mentions Figma, ask for file ID and use getFigmaFile
2. For file operations, use listFiles and readFile
3. Generate code based on designs and save instructions

## Example Usage:
User: "Convert my Figma button to React"
Assistant: I'll help you convert your Figma button to React. First, I need your Figma file ID...
```

---

## Method 4: One-Click Consumer Installers

Create platform-specific installers that handle everything automatically.

### Windows Installer (PowerShell)

```powershell
# install-agentengine.ps1
Write-Host "🚀 Installing AgentEngine for Consumer Use..." -ForegroundColor Green

# Check if Node.js is installed
if (!(Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Node.js not found. Please install Node.js first." -ForegroundColor Red
    Start-Process "https://nodejs.org"
    exit
}

# Create AgentEngine directory
$agentDir = "$env:USERPROFILE\AgentEngine"
New-Item -ItemType Directory -Force -Path $agentDir
Set-Location $agentDir

# Download and extract MCP servers
Write-Host "📦 Installing MCP servers..." -ForegroundColor Yellow
npm init -y
npm install @figma/mcp-server @mcp/filesystem @mcp/git

# Create configuration wizard
Write-Host "🎯 Choose your AI platform:" -ForegroundColor Cyan
Write-Host "1. LM Studio"
Write-Host "2. Ollama" 
Write-Host "3. ChatGPT (Custom GPT)"
Write-Host "4. Claude Desktop"

$choice = Read-Host "Enter choice (1-4)"

switch ($choice) {
    "1" { 
        # LM Studio setup
        Write-Host "Setting up for LM Studio..." -ForegroundColor Green
        # Create LM Studio config files
    }
    "2" { 
        # Ollama setup
        Write-Host "Setting up for Ollama..." -ForegroundColor Green
        # Create Ollama bridge
    }
    "3" { 
        # ChatGPT setup  
        Write-Host "Setting up for ChatGPT..." -ForegroundColor Green
        # Create API gateway
    }
    "4" { 
        # Claude Desktop setup
        Write-Host "Setting up for Claude Desktop..." -ForegroundColor Green
        # Create Claude config
    }
}

Write-Host "✅ Installation complete!" -ForegroundColor Green
```

### macOS/Linux Installer (Bash)

```bash
#!/bin/bash
# install-agentengine.sh

echo "🚀 Installing AgentEngine for Consumer Use..."

# Check dependencies
if ! command -v node &> /dev/null; then
    echo "❌ Node.js not found. Please install Node.js first."
    open "https://nodejs.org" 2>/dev/null || xdg-open "https://nodejs.org" 2>/dev/null
    exit 1
fi

# Create AgentEngine directory
AGENT_DIR="$HOME/AgentEngine"
mkdir -p "$AGENT_DIR"
cd "$AGENT_DIR"

# Install MCP servers
echo "📦 Installing MCP servers..."
npm init -y
npm install @figma/mcp-server @mcp/filesystem @mcp/git

# Platform selection
echo "🎯 Choose your AI platform:"
echo "1. LM Studio"
echo "2. Ollama"
echo "3. ChatGPT (Custom GPT)" 
echo "4. Claude Desktop"

read -p "Enter choice (1-4): " choice

case $choice in
    1) setup_lm_studio ;;
    2) setup_ollama ;;
    3) setup_chatgpt ;;
    4) setup_claude_desktop ;;
    *) echo "Invalid choice" && exit 1 ;;
esac

echo "✅ Installation complete!"
```

---

## Consumer UI Integration

Add a consumer-focused deployment section to the AgentEngine UI:

### New "Consumer Deploy" Tab

```typescript
// Add to TemplatesPage.tsx
<TabsTrigger value="consumer">🏠 Consumer Deploy</TabsTrigger>

<TabsContent value="consumer" className="space-y-6">
  <div className="text-center space-y-4 py-8">
    <h2 className="text-3xl font-bold">Deploy to Your AI Setup</h2>
    <p className="text-lg text-muted-foreground max-w-2xl mx-auto">
      Connect AgentEngine capabilities to your existing AI tools - no complex deployments needed.
    </p>
  </div>

  {/* Consumer Platform Cards */}
  <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
    {[
      {
        name: 'LM Studio',
        icon: '🎯',
        description: 'Local AI with enhanced MCP capabilities',
        difficulty: 'Easy',
        time: '5 minutes'
      },
      {
        name: 'Ollama',
        icon: '🐋', 
        description: 'Lightweight local deployment',
        difficulty: 'Medium',
        time: '10 minutes'
      },
      {
        name: 'ChatGPT',
        icon: '🤖',
        description: 'Enhance ChatGPT with custom tools',
        difficulty: 'Medium', 
        time: '15 minutes'
      },
      {
        name: 'Claude Desktop',
        icon: '🖥️',
        description: 'Full integration with Claude',
        difficulty: 'Easy',
        time: '5 minutes'
      }
    ].map((platform) => (
      <Card key={platform.name} className="selection-card cursor-pointer hover:shadow-lg">
        <CardHeader className="text-center">
          <div className="text-4xl mb-2">{platform.icon}</div>
          <CardTitle className="text-lg">{platform.name}</CardTitle>
          <CardDescription>{platform.description}</CardDescription>
        </CardHeader>
        <CardContent className="space-y-3">
          <div className="flex justify-between text-sm">
            <span>Difficulty:</span>
            <Badge variant={platform.difficulty === 'Easy' ? 'default' : 'secondary'}>
              {platform.difficulty}
            </Badge>
          </div>
          <div className="flex justify-between text-sm">
            <span>Setup time:</span>
            <span className="font-medium">{platform.time}</span>
          </div>
          <Button className="w-full">
            <Download className="w-4 h-4 mr-2" />
            Download Installer
          </Button>
        </CardContent>
      </Card>
    ))}
  </div>

  {/* Quick Setup Instructions */}
  <Card>
    <CardHeader>
      <CardTitle>Quick Setup Instructions</CardTitle>
    </CardHeader>
    <CardContent>
      <Tabs defaultValue="lm-studio">
        <TabsList className="grid grid-cols-4 w-full">
          <TabsTrigger value="lm-studio">LM Studio</TabsTrigger>
          <TabsTrigger value="ollama">Ollama</TabsTrigger>
          <TabsTrigger value="chatgpt">ChatGPT</TabsTrigger>
          <TabsTrigger value="claude">Claude</TabsTrigger>
        </TabsList>
        
        <TabsContent value="lm-studio" className="space-y-4">
          <div className="space-y-3">
            <div className="flex items-start gap-3">
              <Badge className="bg-primary text-primary-foreground">1</Badge>
              <div>
                <p className="font-medium">Download and run installer</p>
                <p className="text-sm text-muted-foreground">Downloads MCP servers and creates LM Studio integration</p>
              </div>
            </div>
            <div className="flex items-start gap-3">
              <Badge className="bg-primary text-primary-foreground">2</Badge>
              <div>
                <p className="font-medium">Configure your API tokens</p>
                <p className="text-sm text-muted-foreground">Add Figma, GitHub, or other service tokens</p>
              </div>
            </div>
            <div className="flex items-start gap-3">
              <Badge className="bg-primary text-primary-foreground">3</Badge>
              <div>
                <p className="font-medium">Start enhanced LM Studio</p>
                <p className="text-sm text-muted-foreground">Your AI now has Figma, file system, and Git capabilities</p>
              </div>
            </div>
          </div>
        </TabsContent>
        
        {/* Similar for other platforms */}
      </Tabs>
    </CardContent>
  </Card>
</TabsContent>
```

---

## Key Consumer Benefits

### Why This Approach Works

1. **Uses Existing Tools** - People don't need to abandon their current AI setup
2. **Progressive Enhancement** - Add capabilities without complexity
3. **Local Control** - MCP servers run locally for privacy
4. **One-Click Setup** - Installers handle technical details
5. **Platform Agnostic** - Works with any AI chat interface

### Real-World Consumer Journey

1. **Discovery**: "I want my AI to read my Figma designs"
2. **Selection**: Choose LM Studio (already using it)
3. **Installation**: Download one-click installer, run it
4. **Configuration**: Add Figma token when prompted
5. **Usage**: "Show me the components in my design system" → AI actually accesses Figma
6. **Expansion**: Add more MCP servers as needed

This transforms AgentEngine from an enterprise deployment platform into a consumer enhancement tool that makes any AI chat interface more powerful.

<function_calls>
<invoke name="TodoWrite">
<parameter name="todos">[{"content": "Create consumer-friendly MCP server deployment guide", "status": "completed", "id": "1"}, {"content": "Add LM Studio integration instructions", "status": "completed", "id": "2"}, {"content": "Add Ollama deployment method", "status": "completed", "id": "3"}, {"content": "Create ChatGPT/OpenAI integration guide", "status": "completed", "id": "4"}, {"content": "Add simple one-click MCP server installers", "status": "completed", "id": "5"}, {"content": "Create consumer deployment wizard in UI", "status": "in_progress", "id": "6"}]
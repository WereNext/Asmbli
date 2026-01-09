#!/usr/bin/env python3
"""
Tests for MCP-DSPy Bridge

Tests the bridge that connects DSPy agents to MCP tool servers via Flutter.

Run with:
    pytest tests/test_mcp_bridge.py -v
    python tests/test_mcp_bridge.py  # standalone
"""

import asyncio
import json
from unittest.mock import AsyncMock, MagicMock, patch
from http.server import HTTPServer, BaseHTTPRequestHandler
import threading
import time

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

# Try to import pytest, but allow standalone mode without it
try:
    import pytest
    PYTEST_AVAILABLE = True
except ImportError:
    PYTEST_AVAILABLE = False
    # Create dummy decorators for standalone mode
    class pytest:
        @staticmethod
        def fixture(func):
            return func
        class mark:
            @staticmethod
            def asyncio(func):
                return func

from src.mcp.mcp_bridge import (
    MCPBridge,
    MCPToolDefinition,
    MCPToolResult,
    get_mcp_bridge,
    create_mcp_tool,
)


# ============== Test Fixtures ==============

@pytest.fixture
def mcp_tool():
    """Create a sample MCP tool definition"""
    return MCPToolDefinition(
        name="github_search",
        description="Search GitHub repositories",
        server_id="github-mcp-server",
        input_schema={
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "Search query"}
            },
            "required": ["query"]
        }
    )


@pytest.fixture
def mcp_bridge():
    """Create a fresh MCP bridge instance"""
    bridge = MCPBridge(flutter_callback_url="http://localhost:3001")
    yield bridge
    # Cleanup
    asyncio.run(bridge.close())


# ============== Unit Tests: MCPToolDefinition ==============

class TestMCPToolDefinition:
    """Test MCPToolDefinition dataclass"""

    def test_create_tool_definition(self):
        """Test creating a tool definition"""
        tool = MCPToolDefinition(
            name="test_tool",
            description="A test tool",
            server_id="test-server",
        )
        assert tool.name == "test_tool"
        assert tool.description == "A test tool"
        assert tool.server_id == "test-server"
        assert tool.input_schema == {}

    def test_create_tool_with_schema(self):
        """Test creating a tool with input schema"""
        schema = {
            "type": "object",
            "properties": {
                "query": {"type": "string"}
            }
        }
        tool = MCPToolDefinition(
            name="search",
            description="Search something",
            server_id="search-server",
            input_schema=schema,
        )
        assert tool.input_schema == schema

    def test_to_dict(self, mcp_tool):
        """Test converting tool to dictionary"""
        d = mcp_tool.to_dict()
        assert d["name"] == "github_search"
        assert d["description"] == "Search GitHub repositories"
        assert d["server_id"] == "github-mcp-server"
        assert "type" in d["input_schema"]


# ============== Unit Tests: MCPBridge ==============

class TestMCPBridge:
    """Test MCPBridge class"""

    def test_create_bridge(self):
        """Test creating a bridge instance"""
        bridge = MCPBridge(flutter_callback_url="http://localhost:3000")
        assert bridge.flutter_callback_url == "http://localhost:3000"
        assert bridge._tool_registry == {}

    def test_register_tool(self, mcp_bridge, mcp_tool):
        """Test registering a tool"""
        mcp_bridge.register_tool(mcp_tool)
        assert "github_search" in mcp_bridge._tool_registry
        assert mcp_bridge.get_tool("github_search") == mcp_tool

    def test_register_multiple_tools(self, mcp_bridge):
        """Test registering multiple tools"""
        tools = [
            MCPToolDefinition(name="tool1", description="Tool 1", server_id="server1"),
            MCPToolDefinition(name="tool2", description="Tool 2", server_id="server2"),
            MCPToolDefinition(name="tool3", description="Tool 3", server_id="server3"),
        ]
        mcp_bridge.register_tools(tools)
        assert len(mcp_bridge._tool_registry) == 3
        assert mcp_bridge.get_tool("tool1") is not None
        assert mcp_bridge.get_tool("tool2") is not None
        assert mcp_bridge.get_tool("tool3") is not None

    def test_get_unregistered_tool(self, mcp_bridge):
        """Test getting a tool that doesn't exist"""
        result = mcp_bridge.get_tool("nonexistent")
        assert result is None


# ============== Async Tests: Tool Execution ==============

class TestMCPBridgeExecution:
    """Test MCP tool execution"""

    @pytest.mark.asyncio
    async def test_execute_unregistered_tool(self, mcp_bridge):
        """Test executing a tool that's not registered"""
        result = await mcp_bridge.execute_tool("nonexistent", {"query": "test"})
        assert result.success is False
        assert "not registered" in result.error

    @pytest.mark.asyncio
    async def test_execute_tool_success(self, mcp_bridge, mcp_tool):
        """Test successful tool execution with mocked HTTP response"""
        mcp_bridge.register_tool(mcp_tool)

        # Mock the HTTP client
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "success": True,
            "result": {"repos": [{"name": "test-repo"}]},
            "execution_time_ms": 150,
        }

        with patch.object(mcp_bridge, '_get_client') as mock_get_client:
            mock_client = AsyncMock()
            mock_client.post = AsyncMock(return_value=mock_response)
            mock_get_client.return_value = mock_client

            result = await mcp_bridge.execute_tool(
                "github_search",
                {"query": "flutter mcp"},
                agent_id="test-agent"
            )

        assert result.success is True
        assert result.result == {"repos": [{"name": "test-repo"}]}
        assert result.execution_time_ms == 150

    @pytest.mark.asyncio
    async def test_execute_tool_http_error(self, mcp_bridge, mcp_tool):
        """Test tool execution with HTTP error"""
        mcp_bridge.register_tool(mcp_tool)

        mock_response = MagicMock()
        mock_response.status_code = 500

        with patch.object(mcp_bridge, '_get_client') as mock_get_client:
            mock_client = AsyncMock()
            mock_client.post = AsyncMock(return_value=mock_response)
            mock_get_client.return_value = mock_client

            result = await mcp_bridge.execute_tool("github_search", {"query": "test"})

        assert result.success is False
        assert "HTTP 500" in result.error

    @pytest.mark.asyncio
    async def test_execute_tool_timeout(self, mcp_bridge, mcp_tool):
        """Test tool execution timeout"""
        import httpx
        mcp_bridge.register_tool(mcp_tool)

        with patch.object(mcp_bridge, '_get_client') as mock_get_client:
            mock_client = AsyncMock()
            mock_client.post = AsyncMock(side_effect=httpx.TimeoutException("timeout"))
            mock_get_client.return_value = mock_client

            result = await mcp_bridge.execute_tool("github_search", {"query": "test"})

        assert result.success is False
        assert "timed out" in result.error


# ============== Tests: DSPy Tool Creation ==============

class TestDSPyToolCreation:
    """Test creating DSPy-compatible tool functions"""

    def test_create_dspy_tool(self, mcp_bridge, mcp_tool):
        """Test creating a DSPy tool wrapper"""
        mcp_bridge.register_tool(mcp_tool)
        dspy_tool = mcp_bridge.create_dspy_tool(mcp_tool)

        # Check function metadata
        assert dspy_tool.__name__ == "github_search"
        assert "Search GitHub repositories" in dspy_tool.__doc__
        assert "github-mcp-server" in dspy_tool.__doc__

    def test_create_all_dspy_tools(self, mcp_bridge):
        """Test creating all registered tools as DSPy functions"""
        tools = [
            MCPToolDefinition(name="tool1", description="Tool 1", server_id="server1"),
            MCPToolDefinition(name="tool2", description="Tool 2", server_id="server2"),
        ]
        mcp_bridge.register_tools(tools)

        dspy_tools = mcp_bridge.create_all_dspy_tools()
        assert len(dspy_tools) == 2
        tool_names = [t.__name__ for t in dspy_tools]
        assert "tool1" in tool_names
        assert "tool2" in tool_names

    def test_dspy_tool_with_json_input(self, mcp_bridge, mcp_tool):
        """Test DSPy tool wrapper handles JSON input"""
        mcp_bridge.register_tool(mcp_tool)
        dspy_tool = mcp_bridge.create_dspy_tool(mcp_tool)

        # Mock the execute_tool method
        mock_result = MCPToolResult(
            success=True,
            result={"found": 10},
            execution_time_ms=100,
        )

        with patch.object(mcp_bridge, 'execute_tool', new_callable=AsyncMock) as mock_execute:
            mock_execute.return_value = mock_result

            # Call with JSON string
            result = dspy_tool('{"query": "flutter"}')

        # Verify the call
        mock_execute.assert_called_once()
        call_args = mock_execute.call_args
        assert call_args[0][0] == "github_search"
        assert call_args[0][1] == {"query": "flutter"}

    def test_dspy_tool_with_plain_text_input(self, mcp_bridge, mcp_tool):
        """Test DSPy tool wrapper handles plain text input"""
        mcp_bridge.register_tool(mcp_tool)
        dspy_tool = mcp_bridge.create_dspy_tool(mcp_tool)

        mock_result = MCPToolResult(
            success=True,
            result="search results",
            execution_time_ms=50,
        )

        with patch.object(mcp_bridge, 'execute_tool', new_callable=AsyncMock) as mock_execute:
            mock_execute.return_value = mock_result

            # Call with plain text (not JSON)
            result = dspy_tool("flutter mcp tools")

        # Should wrap in {"input": ...}
        call_args = mock_execute.call_args
        assert call_args[0][1] == {"input": "flutter mcp tools"}


# ============== Tests: Global Bridge ==============

class TestGlobalBridge:
    """Test global bridge instance management"""

    def test_get_mcp_bridge_creates_instance(self):
        """Test that get_mcp_bridge creates a new instance"""
        # Reset global
        import src.mcp.mcp_bridge as bridge_module
        bridge_module._bridge = None

        bridge = get_mcp_bridge("http://localhost:3000")
        assert bridge is not None
        assert bridge.flutter_callback_url == "http://localhost:3000"

    def test_get_mcp_bridge_returns_same_instance(self):
        """Test that get_mcp_bridge returns the same instance"""
        import src.mcp.mcp_bridge as bridge_module
        bridge_module._bridge = None

        bridge1 = get_mcp_bridge("http://localhost:3000")
        bridge2 = get_mcp_bridge("http://localhost:3000")
        assert bridge1 is bridge2

    def test_create_mcp_tool_convenience(self):
        """Test the create_mcp_tool convenience function"""
        import src.mcp.mcp_bridge as bridge_module
        bridge_module._bridge = None

        tool_fn = create_mcp_tool(
            name="brave_search",
            description="Search the web with Brave",
            server_id="brave-search-server",
            input_schema={"query": {"type": "string"}},
        )

        assert tool_fn.__name__ == "brave_search"
        assert "Search the web with Brave" in tool_fn.__doc__


# ============== Integration Test: Mock Flutter Server ==============

class MockFlutterHandler(BaseHTTPRequestHandler):
    """Mock Flutter Plugin Bridge Server for integration testing"""

    def log_message(self, format, *args):
        pass  # Suppress logging

    def do_POST(self):
        if self.path == "/mcp/execute":
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length)
            data = json.loads(body)

            # Simulate successful MCP tool execution
            response = {
                "success": True,
                "result": {
                    "tool": data.get("tool_name"),
                    "server": data.get("server_id"),
                    "arguments": data.get("arguments"),
                    "mock_data": "This is mock data from the test server"
                },
                "execution_time_ms": 42,
            }

            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(response).encode())
        else:
            self.send_response(404)
            self.end_headers()


@pytest.fixture
def mock_flutter_server():
    """Start a mock Flutter server for integration testing"""
    server = HTTPServer(('localhost', 3002), MockFlutterHandler)
    thread = threading.Thread(target=server.serve_forever)
    thread.daemon = True
    thread.start()
    time.sleep(0.1)  # Give server time to start
    yield server
    server.shutdown()


class TestIntegration:
    """Integration tests with mock Flutter server"""

    @pytest.mark.asyncio
    async def test_full_tool_execution_flow(self, mock_flutter_server):
        """Test complete flow: register tool -> execute -> get result"""
        bridge = MCPBridge(flutter_callback_url="http://localhost:3002")

        # Register a tool
        tool = MCPToolDefinition(
            name="file_read",
            description="Read a file from the filesystem",
            server_id="filesystem-server",
            input_schema={
                "type": "object",
                "properties": {
                    "path": {"type": "string"}
                }
            }
        )
        bridge.register_tool(tool)

        # Execute the tool
        result = await bridge.execute_tool(
            "file_read",
            {"path": "/test/file.txt"},
            agent_id="integration-test-agent"
        )

        # Verify result
        assert result.success is True
        assert result.result["tool"] == "file_read"
        assert result.result["server"] == "filesystem-server"
        assert result.result["arguments"]["path"] == "/test/file.txt"
        assert result.execution_time_ms == 42

        await bridge.close()

    @pytest.mark.asyncio
    async def test_dspy_tool_integration(self, mock_flutter_server):
        """Test DSPy tool wrapper with mock server"""
        bridge = MCPBridge(flutter_callback_url="http://localhost:3002")

        tool = MCPToolDefinition(
            name="web_search",
            description="Search the web",
            server_id="brave-search",
        )
        bridge.register_tool(tool)

        # Create DSPy tool wrapper
        dspy_tool = bridge.create_dspy_tool(tool)

        # Execute via DSPy tool interface
        result = dspy_tool('{"query": "DSPy MCP integration"}')

        # Result should be JSON string
        result_data = json.loads(result)
        assert result_data["tool"] == "web_search"
        assert result_data["arguments"]["query"] == "DSPy MCP integration"

        await bridge.close()


# ============== API Models Integration Test ==============

class TestAPIModelsIntegration:
    """Test integration with API models"""

    def test_tool_definition_model(self):
        """Test that ToolDefinition in API models supports MCP fields"""
        from src.api.models import ToolDefinition

        # Create regular tool
        regular_tool = ToolDefinition(
            name="calculator",
            description="Perform calculations"
        )
        assert regular_tool.is_mcp_tool is False

        # Create MCP tool
        mcp_tool = ToolDefinition(
            name="github_search",
            description="Search GitHub",
            server_id="github-mcp-server",
            input_schema={"query": {"type": "string"}}
        )
        assert mcp_tool.is_mcp_tool is True
        assert mcp_tool.server_id == "github-mcp-server"

    def test_agent_request_model(self):
        """Test that AgentRequest supports flutter_callback_url"""
        from src.api.models import AgentRequest, ToolDefinition

        request = AgentRequest(
            task="Search for Flutter MCP tools",
            tools=[
                ToolDefinition(
                    name="github_search",
                    description="Search GitHub",
                    server_id="github-server"
                )
            ],
            flutter_callback_url="http://localhost:3000"
        )

        assert request.flutter_callback_url == "http://localhost:3000"
        assert len(request.tools) == 1
        assert request.tools[0].is_mcp_tool is True


# ============== Standalone Runner ==============

def run_standalone_tests():
    """Run tests standalone without pytest"""
    print("=" * 60)
    print("[TEST] MCP Bridge Tests (Standalone)")
    print("=" * 60)

    # Test 1: Tool Definition
    print("\n[1] Test 1: MCPToolDefinition")
    tool = MCPToolDefinition(
        name="test_tool",
        description="A test tool",
        server_id="test-server",
        input_schema={"query": {"type": "string"}}
    )
    assert tool.name == "test_tool"
    assert tool.to_dict()["server_id"] == "test-server"
    print("   [OK] PASSED")

    # Test 2: Bridge Creation
    print("\n[2] Test 2: MCPBridge Creation")
    bridge = MCPBridge(flutter_callback_url="http://localhost:3000")
    assert bridge.flutter_callback_url == "http://localhost:3000"
    print("   [OK] PASSED")

    # Test 3: Tool Registration
    print("\n[3] Test 3: Tool Registration")
    bridge.register_tool(tool)
    assert bridge.get_tool("test_tool") == tool
    assert bridge.get_tool("nonexistent") is None
    print("   [OK] PASSED")

    # Test 4: DSPy Tool Creation
    print("\n[4] Test 4: DSPy Tool Wrapper")
    dspy_fn = bridge.create_dspy_tool(tool)
    assert dspy_fn.__name__ == "test_tool"
    assert "A test tool" in dspy_fn.__doc__
    print("   [OK] PASSED")

    # Test 5: Unregistered Tool Execution
    print("\n[5] Test 5: Execute Unregistered Tool")
    result = asyncio.run(bridge.execute_tool("fake_tool", {}))
    assert result.success is False
    assert "not registered" in result.error
    print("   [OK] PASSED")

    # Test 6: Global Bridge
    print("\n[6] Test 6: Global Bridge Instance")
    import src.mcp.mcp_bridge as bridge_module
    bridge_module._bridge = None
    b1 = get_mcp_bridge()
    b2 = get_mcp_bridge()
    assert b1 is b2
    print("   [OK] PASSED")

    # Test 7: API Models (if available)
    print("\n[7] Test 7: API Models Integration")
    try:
        from src.api.models import ToolDefinition, AgentRequest
        mcp_tool = ToolDefinition(
            name="github_search",
            description="Search GitHub",
            server_id="github-server"
        )
        assert mcp_tool.is_mcp_tool is True

        request = AgentRequest(
            task="Test task",
            flutter_callback_url="http://localhost:3000"
        )
        assert request.flutter_callback_url == "http://localhost:3000"
        print("   [OK] PASSED")
    except ImportError as e:
        print(f"   [SKIP] SKIPPED (import error: {e})")

    print("\n" + "=" * 60)
    print("[SUCCESS] All standalone tests passed!")
    print("=" * 60)

    # Cleanup
    asyncio.run(bridge.close())


if __name__ == "__main__":
    import sys

    if len(sys.argv) > 1 and sys.argv[1] == "--pytest":
        pytest.main([__file__, "-v"])
    else:
        run_standalone_tests()

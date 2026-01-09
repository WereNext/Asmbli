"""
MCP Bridge - Connects DSPy agents to MCP tool servers via Flutter

Architecture:
1. Flutter sends agent execution request with MCP tool definitions
2. DSPy agent reasons and decides to use a tool
3. Python calls Flutter's MCP execution endpoint
4. Flutter executes the tool via MCP server
5. Result returns to Python for agent to continue reasoning

This bridge enables DSPy agents to use any MCP tool from the registry:
- GitHub, filesystem, Brave search, databases, etc.
"""

import httpx
import asyncio
from typing import Optional, Any, Callable
from dataclasses import dataclass, field
from functools import wraps
import json


@dataclass
class MCPToolDefinition:
    """Enhanced tool definition with MCP routing info"""
    name: str
    description: str
    server_id: str  # Which MCP server provides this tool
    input_schema: dict = field(default_factory=dict)  # JSON Schema for parameters

    def to_dict(self) -> dict:
        return {
            "name": self.name,
            "description": self.description,
            "server_id": self.server_id,
            "input_schema": self.input_schema,
        }


@dataclass
class MCPToolResult:
    """Result from MCP tool execution"""
    success: bool
    result: Any
    error: Optional[str] = None
    execution_time_ms: int = 0


class MCPBridge:
    """
    Bridge between DSPy agents and MCP tools.

    When DSPy needs to execute a tool, this bridge:
    1. Formats the request for MCP
    2. Calls the Flutter app's MCP execution endpoint
    3. Returns the result to DSPy
    """

    def __init__(self, flutter_callback_url: str = "http://localhost:3000"):
        """
        Initialize the MCP bridge.

        Args:
            flutter_callback_url: URL where Flutter listens for tool execution requests.
                                  This is the Plugin Bridge Server port.
        """
        self.flutter_callback_url = flutter_callback_url
        self._tool_registry: dict[str, MCPToolDefinition] = {}
        self._http_client: Optional[httpx.AsyncClient] = None

    async def _get_client(self) -> httpx.AsyncClient:
        """Get or create HTTP client"""
        if self._http_client is None:
            self._http_client = httpx.AsyncClient(timeout=60.0)
        return self._http_client

    async def close(self):
        """Close HTTP client"""
        if self._http_client:
            await self._http_client.aclose()
            self._http_client = None

    def register_tool(self, tool: MCPToolDefinition):
        """Register an MCP tool for use by agents"""
        self._tool_registry[tool.name] = tool

    def register_tools(self, tools: list[MCPToolDefinition]):
        """Register multiple MCP tools"""
        for tool in tools:
            self.register_tool(tool)

    def get_tool(self, name: str) -> Optional[MCPToolDefinition]:
        """Get a registered tool by name"""
        return self._tool_registry.get(name)

    async def execute_tool(
        self,
        tool_name: str,
        arguments: dict[str, Any],
        agent_id: Optional[str] = None,
    ) -> MCPToolResult:
        """
        Execute an MCP tool via Flutter.

        Args:
            tool_name: Name of the tool to execute
            arguments: Arguments to pass to the tool
            agent_id: Optional agent ID for context

        Returns:
            MCPToolResult with success/failure and result data
        """
        tool = self._tool_registry.get(tool_name)
        if not tool:
            return MCPToolResult(
                success=False,
                result=None,
                error=f"Tool '{tool_name}' not registered in MCP bridge"
            )

        try:
            client = await self._get_client()

            # Call Flutter's MCP execution endpoint
            response = await client.post(
                f"{self.flutter_callback_url}/mcp/execute",
                json={
                    "tool_name": tool_name,
                    "server_id": tool.server_id,
                    "arguments": arguments,
                    "agent_id": agent_id,
                },
                timeout=60.0,
            )

            if response.status_code == 200:
                data = response.json()
                return MCPToolResult(
                    success=data.get("success", False),
                    result=data.get("result"),
                    error=data.get("error"),
                    execution_time_ms=data.get("execution_time_ms", 0),
                )
            else:
                return MCPToolResult(
                    success=False,
                    result=None,
                    error=f"MCP execution failed: HTTP {response.status_code}"
                )

        except httpx.TimeoutException:
            return MCPToolResult(
                success=False,
                result=None,
                error="MCP tool execution timed out (60s)"
            )
        except Exception as e:
            return MCPToolResult(
                success=False,
                result=None,
                error=f"MCP execution error: {str(e)}"
            )

    def create_dspy_tool(self, tool: MCPToolDefinition) -> Callable:
        """
        Create a DSPy-compatible tool function that executes via MCP.

        DSPy tools are simple functions with docstrings. This creates
        a wrapper that:
        1. Takes input string from DSPy agent
        2. Parses it into arguments
        3. Calls MCP via Flutter
        4. Returns result string to DSPy
        """
        bridge = self

        def mcp_tool_wrapper(input_str: str) -> str:
            """
            Wrapper function that DSPy calls.
            Converts to async execution internally.
            """
            try:
                # Parse input - could be JSON or plain text
                try:
                    arguments = json.loads(input_str)
                except json.JSONDecodeError:
                    # If not JSON, wrap in a simple structure
                    arguments = {"input": input_str}

                # Execute synchronously (DSPy tools are sync)
                # Use a new event loop if we're not in one
                try:
                    loop = asyncio.get_running_loop()
                    # We're in an async context, need to use run_in_executor
                    import concurrent.futures
                    with concurrent.futures.ThreadPoolExecutor() as executor:
                        future = executor.submit(
                            asyncio.run,
                            bridge.execute_tool(tool.name, arguments)
                        )
                        result = future.result(timeout=60)
                except RuntimeError:
                    # No event loop, we can just run
                    result = asyncio.run(bridge.execute_tool(tool.name, arguments))

                if result.success:
                    # Return result as string for DSPy
                    if isinstance(result.result, str):
                        return result.result
                    return json.dumps(result.result, indent=2)
                else:
                    return f"Error: {result.error}"

            except Exception as e:
                return f"Tool execution failed: {str(e)}"

        # Set function metadata for DSPy
        mcp_tool_wrapper.__name__ = tool.name
        mcp_tool_wrapper.__doc__ = f"{tool.description}\n\nMCP Server: {tool.server_id}"

        return mcp_tool_wrapper

    def create_all_dspy_tools(self) -> list[Callable]:
        """Create DSPy tool functions for all registered MCP tools"""
        return [self.create_dspy_tool(tool) for tool in self._tool_registry.values()]


# Global bridge instance
_bridge: Optional[MCPBridge] = None


def get_mcp_bridge(flutter_url: str = "http://localhost:3000") -> MCPBridge:
    """Get or create the global MCP bridge instance"""
    global _bridge
    if _bridge is None:
        _bridge = MCPBridge(flutter_callback_url=flutter_url)
    return _bridge


def create_mcp_tool(
    name: str,
    description: str,
    server_id: str,
    input_schema: dict = None,
) -> Callable:
    """
    Convenience function to create an MCP-backed tool for DSPy.

    Usage:
        github_search = create_mcp_tool(
            name="search_repositories",
            description="Search GitHub repositories",
            server_id="github-mcp-server",
            input_schema={"query": {"type": "string"}}
        )
    """
    bridge = get_mcp_bridge()
    tool = MCPToolDefinition(
        name=name,
        description=description,
        server_id=server_id,
        input_schema=input_schema or {},
    )
    bridge.register_tool(tool)
    return bridge.create_dspy_tool(tool)

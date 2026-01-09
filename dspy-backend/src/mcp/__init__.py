"""
MCP Integration Module

Provides the bridge between DSPy agents and MCP tool servers.
"""

from .mcp_bridge import (
    MCPBridge,
    MCPToolDefinition,
    MCPToolResult,
    get_mcp_bridge,
    create_mcp_tool,
)

__all__ = [
    "MCPBridge",
    "MCPToolDefinition",
    "MCPToolResult",
    "get_mcp_bridge",
    "create_mcp_tool",
]

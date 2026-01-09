"""
Pydantic models for API requests and responses.

These are the contracts between your Flutter app and the DSPy backend.
"""
from __future__ import annotations

from pydantic import BaseModel, Field
from typing import Optional, Any, List, Dict
from enum import Enum


class ModelType(str, Enum):
    """Available model types"""
    GPT4O_MINI = "openai/gpt-4o-mini"
    GPT4O = "openai/gpt-4o"
    GPT4_TURBO = "openai/gpt-4-turbo"
    CLAUDE_SONNET = "anthropic/claude-3-5-sonnet-20241022"
    CLAUDE_HAIKU = "anthropic/claude-3-haiku-20240307"


class ReasoningPattern(str, Enum):
    """Available reasoning patterns"""
    BASIC = "basic"
    CHAIN_OF_THOUGHT = "chain_of_thought"
    TREE_OF_THOUGHT = "tree_of_thought"
    REACT = "react"


# ============== Chat Endpoints ==============

class ChatRequest(BaseModel):
    """Simple chat request"""
    message: str = Field(..., description="The user's message")
    model: Optional[str] = Field(None, description="Model to use (defaults to configured default)")
    system_prompt: Optional[str] = Field(None, description="Optional system prompt override")
    temperature: float = Field(0.7, ge=0, le=2, description="Temperature for generation")

    class Config:
        json_schema_extra = {
            "example": {
                "message": "What is the capital of France?",
                "model": "openai/gpt-4o-mini",
                "temperature": 0.7
            }
        }


class ChatResponse(BaseModel):
    """Chat response"""
    response: str = Field(..., description="The model's response")
    model: str = Field(..., description="Model that was used")
    reasoning: Optional[str] = Field(None, description="Reasoning if chain-of-thought was used")
    confidence: Optional[float] = Field(None, description="Confidence score if available")

    class Config:
        json_schema_extra = {
            "example": {
                "response": "The capital of France is Paris.",
                "model": "openai/gpt-4o-mini",
                "confidence": 0.95
            }
        }


# ============== RAG Endpoints ==============

class RAGRequest(BaseModel):
    """RAG (Retrieval-Augmented Generation) request"""
    question: str = Field(..., description="The question to answer")
    document_ids: Optional[list[str]] = Field(None, description="Specific documents to search")
    num_passages: int = Field(5, ge=1, le=20, description="Number of passages to retrieve")
    include_citations: bool = Field(True, description="Include source citations in response")
    model: Optional[str] = Field(None, description="Model to use")

    class Config:
        json_schema_extra = {
            "example": {
                "question": "How does the authentication system work?",
                "num_passages": 5,
                "include_citations": True
            }
        }


class RAGSource(BaseModel):
    """A source document used in RAG response"""
    document_id: str
    title: str
    excerpt: str
    relevance_score: float


class RAGResponse(BaseModel):
    """RAG response with sources"""
    answer: str = Field(..., description="The generated answer")
    sources: list[RAGSource] = Field(default_factory=list, description="Sources used")
    confidence: float = Field(..., description="Confidence in the answer")
    model: str = Field(..., description="Model that was used")
    passages_used: int = Field(..., description="Number of passages retrieved")

    class Config:
        json_schema_extra = {
            "example": {
                "answer": "The authentication system uses JWT tokens...",
                "sources": [
                    {
                        "document_id": "doc_123",
                        "title": "Auth Guide",
                        "excerpt": "JWT tokens are used for...",
                        "relevance_score": 0.92
                    }
                ],
                "confidence": 0.88,
                "model": "openai/gpt-4o-mini",
                "passages_used": 3
            }
        }


# ============== Agent Endpoints ==============

class ToolDefinition(BaseModel):
    """Definition of a tool the agent can use - supports MCP tools"""
    name: str = Field(..., description="Tool name")
    description: str = Field(..., description="What the tool does")
    server_id: Optional[str] = Field(None, description="MCP server ID that provides this tool")
    input_schema: Optional[Dict[str, Any]] = Field(None, description="JSON Schema for tool parameters")

    @property
    def is_mcp_tool(self) -> bool:
        """Check if this is an MCP-backed tool"""
        return self.server_id is not None


class AgentRequest(BaseModel):
    """Agent request for task execution"""
    task: str = Field(..., description="The task to perform")
    tools: list[ToolDefinition] = Field(default_factory=list, description="Available tools")
    max_iterations: int = Field(5, ge=1, le=20, description="Maximum reasoning iterations")
    model: Optional[str] = Field(None, description="Model to use")
    agent_id: Optional[str] = Field(None, description="Agent ID for tracking/context")
    flutter_callback_url: Optional[str] = Field(
        None,
        description="Flutter callback URL for MCP tool execution (e.g., http://localhost:3000)"
    )

    class Config:
        json_schema_extra = {
            "example": {
                "task": "Calculate 25 * 4 + 100 and explain the steps",
                "tools": [
                    {"name": "calculator", "description": "Evaluate math expressions"},
                    {"name": "github_search", "description": "Search GitHub repos", "server_id": "github-mcp-server"}
                ],
                "max_iterations": 5,
                "flutter_callback_url": "http://localhost:3000"
            }
        }


class AgentStep(BaseModel):
    """A single step in agent execution"""
    iteration: int
    thought: str
    action: str
    observation: Optional[str] = None


class AgentResponse(BaseModel):
    """Agent response with execution trace"""
    answer: str = Field(..., description="Final answer")
    success: bool = Field(..., description="Whether the task was completed successfully")
    steps: list[AgentStep] = Field(default_factory=list, description="Execution trace")
    iterations_used: int = Field(..., description="Number of iterations used")
    model: str = Field(..., description="Model that was used")

    class Config:
        json_schema_extra = {
            "example": {
                "answer": "The result is 200",
                "success": True,
                "steps": [
                    {
                        "iteration": 1,
                        "thought": "I need to calculate 25 * 4 first",
                        "action": "calculator: 25 * 4",
                        "observation": "100"
                    }
                ],
                "iterations_used": 2,
                "model": "openai/gpt-4o-mini"
            }
        }


# ============== Reasoning Endpoints ==============

class ReasoningRequest(BaseModel):
    """Reasoning request with pattern selection"""
    question: str = Field(..., description="The question to reason about")
    pattern: ReasoningPattern = Field(
        ReasoningPattern.CHAIN_OF_THOUGHT,
        description="Reasoning pattern to use"
    )
    model: Optional[str] = Field(None, description="Model to use")
    num_branches: int = Field(3, ge=2, le=5, description="Branches for tree-of-thought")

    class Config:
        json_schema_extra = {
            "example": {
                "question": "Should we use microservices or monolith for a new startup?",
                "pattern": "tree_of_thought",
                "num_branches": 3
            }
        }


class ReasoningResponse(BaseModel):
    """Reasoning response with full trace"""
    answer: str = Field(..., description="Final answer")
    reasoning: str = Field(..., description="Reasoning trace")
    confidence: float = Field(..., description="Confidence in the answer")
    pattern_used: str = Field(..., description="Reasoning pattern that was used")
    model: str = Field(..., description="Model that was used")
    branches: Optional[list[dict]] = Field(None, description="Branches for tree-of-thought")


# ============== Document Management ==============

class DocumentUploadRequest(BaseModel):
    """Upload a document for RAG"""
    title: str = Field(..., description="Document title")
    content: str = Field(..., description="Document content")
    metadata: dict[str, Any] = Field(default_factory=dict, description="Additional metadata")


class DocumentUploadResponse(BaseModel):
    """Response after document upload"""
    document_id: str
    title: str
    chunks_created: int
    message: str


class DocumentListResponse(BaseModel):
    """List of documents in the system"""
    documents: list[dict]
    total_count: int


# ============== Health & Status ==============

class HealthResponse(BaseModel):
    """Health check response"""
    status: str
    version: str
    models_available: list[str]
    vector_db_status: str
    documents_indexed: int


class OptimizationStatus(BaseModel):
    """Status of prompt optimization"""
    module: str
    optimized: bool
    examples_used: int
    accuracy_improvement: Optional[float] = None


# ============== Streaming Agent Events ==============

class StreamEventType(str, Enum):
    """Types of events in agent streaming"""
    STATUS = "status"           # Agent status update (thinking, calling tool, etc.)
    TOKEN = "token"             # Text token for streaming response
    TOOL_CALL = "tool_call"     # Agent is calling a tool
    TOOL_RESULT = "tool_result" # Tool returned a result
    STEP = "step"               # Complete reasoning step
    ERROR = "error"             # Error occurred
    DONE = "done"               # Agent finished


class AgentStreamRequest(BaseModel):
    """Request for streaming agent execution"""
    task: str = Field(..., description="The task to perform")
    tools: list[ToolDefinition] = Field(default_factory=list, description="Available tools")
    max_iterations: int = Field(5, ge=1, le=20, description="Maximum reasoning iterations")
    model: Optional[str] = Field(None, description="Model to use")
    agent_id: Optional[str] = Field(None, description="Agent ID for tracking/context")
    conversation_id: Optional[str] = Field(None, description="Conversation ID for context")
    flutter_callback_url: Optional[str] = Field(
        None,
        description="Flutter callback URL for MCP tool execution (e.g., http://localhost:3000)"
    )

    class Config:
        json_schema_extra = {
            "example": {
                "task": "Search GitHub for MCP examples and summarize",
                "tools": [
                    {"name": "github_search", "description": "Search GitHub repos", "server_id": "github-mcp-server"}
                ],
                "max_iterations": 5,
                "conversation_id": "conv_123",
                "flutter_callback_url": "http://localhost:3000"
            }
        }


class StreamEvent(BaseModel):
    """A single event in the agent stream"""
    event: StreamEventType = Field(..., description="Type of event")
    data: Dict[str, Any] = Field(default_factory=dict, description="Event data")
    timestamp: str = Field(..., description="ISO timestamp of event")

    class Config:
        json_schema_extra = {
            "examples": [
                {
                    "event": "status",
                    "data": {"message": "Thinking about the task..."},
                    "timestamp": "2024-01-15T10:30:00Z"
                },
                {
                    "event": "tool_call",
                    "data": {"tool": "github_search", "server_id": "github-mcp-server", "arguments": {"query": "MCP"}},
                    "timestamp": "2024-01-15T10:30:01Z"
                },
                {
                    "event": "tool_result",
                    "data": {"tool": "github_search", "result": {"items": []}, "success": True},
                    "timestamp": "2024-01-15T10:30:02Z"
                },
                {
                    "event": "done",
                    "data": {"answer": "Found 5 MCP repos...", "success": True, "iterations": 3},
                    "timestamp": "2024-01-15T10:30:05Z"
                }
            ]
        }


# ============== Knowledge Graph Endpoints ==============

class GraphEntity(BaseModel):
    """An entity in the knowledge graph"""
    name: str = Field(..., description="Entity name")
    type: str = Field(..., description="Entity type (PERSON, ORG, CONCEPT, etc.)")
    description: str = Field("", description="Optional description")
    importance_score: float = Field(0.5, ge=0, le=1, description="Importance score")
    mentions: int = Field(1, ge=1, description="Number of mentions")


class GraphRelationship(BaseModel):
    """A relationship between entities"""
    source: str = Field(..., description="Source entity name")
    target: str = Field(..., description="Target entity name")
    relation: str = Field(..., description="Relationship type/verb")
    weight: float = Field(1.0, ge=0, description="Relationship weight")
    bidirectional: bool = Field(False, description="Is this relationship bidirectional?")


class GraphIngestRequest(BaseModel):
    """Request to ingest text into knowledge graph"""
    content: str = Field(..., description="Text content to process")
    doc_id: Optional[str] = Field(None, description="Optional document ID")
    title: Optional[str] = Field(None, description="Optional document title")

    class Config:
        json_schema_extra = {
            "example": {
                "content": "Elon Musk founded SpaceX in 2002. SpaceX is headquartered in Hawthorne, California.",
                "doc_id": "doc_spacex_01",
                "title": "SpaceX Overview"
            }
        }


class GraphIngestResponse(BaseModel):
    """Response after ingesting text into knowledge graph"""
    doc_id: str
    entities_found: int
    relationships_found: int
    new_entities: int
    new_relationships: int
    total_entities: int
    total_relationships: int


class GraphQueryRequest(BaseModel):
    """Request to query the knowledge graph"""
    query: str = Field(..., description="Natural language query or entity names")
    max_hops: int = Field(2, ge=1, le=4, description="Maximum traversal hops")
    max_entities: int = Field(20, ge=1, le=100, description="Maximum entities to return")
    include_relationships: bool = Field(True, description="Include relationships in response")

    class Config:
        json_schema_extra = {
            "example": {
                "query": "What companies did Elon Musk found?",
                "max_hops": 2,
                "max_entities": 20
            }
        }


class GraphQueryResponse(BaseModel):
    """Response from knowledge graph query"""
    entities: List[Dict[str, Any]] = Field(default_factory=list)
    relationships: List[Dict[str, Any]] = Field(default_factory=list)
    query_entities: List[str] = Field(default_factory=list, description="Entities extracted from query")
    context_text: str = Field("", description="Formatted context for LLM consumption")


class GraphRAGRequest(BaseModel):
    """Request for graph-enhanced RAG query"""
    question: str = Field(..., description="Question to answer")
    use_vector_db: bool = Field(True, description="Also use vector retrieval")
    graph_hops: int = Field(2, ge=1, le=4, description="Graph traversal depth")
    num_passages: int = Field(5, ge=1, le=20, description="Number of vector passages")
    model: Optional[str] = Field(None, description="Model to use for synthesis")

    class Config:
        json_schema_extra = {
            "example": {
                "question": "How is SpaceX related to Tesla?",
                "use_vector_db": True,
                "graph_hops": 2,
                "num_passages": 5
            }
        }


class GraphRAGResponse(BaseModel):
    """Response from graph-enhanced RAG"""
    answer: str = Field(..., description="Generated answer")
    reasoning: str = Field("", description="Reasoning process")
    confidence: float = Field(0.5, ge=0, le=1, description="Confidence score")
    graph_entities_used: int = Field(0, description="Number of graph entities used")
    vector_passages_used: int = Field(0, description="Number of vector passages used")
    model: str = Field(..., description="Model used")


class GraphStatsResponse(BaseModel):
    """Statistics about the knowledge graph"""
    node_count: int
    edge_count: int
    entity_count: int
    relationship_count: int
    document_count: int
    density: float
    spacy_available: bool

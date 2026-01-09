"""
FastAPI Server - The main entry point for the DSPy backend

This is what your Flutter app calls.
"""

import dspy
import json
import asyncio
from datetime import datetime, timezone
from typing import AsyncGenerator
from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from contextlib import asynccontextmanager
import chromadb

from ..config import settings
from .models import (
    ChatRequest,
    ChatResponse,
    RAGRequest,
    RAGResponse,
    RAGSource,
    AgentRequest,
    AgentResponse,
    AgentStep,
    ReasoningRequest,
    ReasoningResponse,
    DocumentUploadRequest,
    DocumentUploadResponse,
    DocumentListResponse,
    HealthResponse,
    ReasoningPattern,
    AgentStreamRequest,
    StreamEventType,
    # Graph models
    GraphIngestRequest,
    GraphIngestResponse,
    GraphQueryRequest,
    GraphQueryResponse,
    GraphRAGRequest,
    GraphRAGResponse,
    GraphStatsResponse,
)
from ..modules import (
    SimpleRAG,
    RAGModule,
    MultiHopRAG,
    ReActAgent,
    CodeAgent,
    ChainOfThoughtModule,
    TreeOfThoughtModule,
    # Graph modules
    get_graph_store,
    get_entity_extractor,
    ingest_text,
    LocalGraphRAG,
    GraphOnlyRAG,
)
from ..modules.agents import create_calculator_tool, create_json_tool
from ..mcp import MCPBridge, MCPToolDefinition, get_mcp_bridge


# Global state
class AppState:
    """Application state holding initialized components"""
    lm: dspy.LM = None
    chroma_client: chromadb.Client = None
    collection: chromadb.Collection = None
    rag_module: RAGModule = None
    cot_module: ChainOfThoughtModule = None
    tot_module: TreeOfThoughtModule = None


state = AppState()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialize and cleanup application resources"""
    # Startup
    print("[*] Starting DSPy Backend...")

    # Check if we have LLM keys
    has_llm = settings.openai_api_key or settings.anthropic_api_key

    # Validate configuration - allow graph-only mode without API keys
    valid, messages = settings.validate_config(require_llm=has_llm)
    if not valid:
        print(f"[!] Configuration errors: {messages}")
        raise RuntimeError(f"Invalid configuration: {messages}")

    if messages:
        print(f"[!] Configuration warnings: {messages}")

    # Initialize LLM only if we have keys
    if has_llm:
        print(f"[>] Initializing LLM: {settings.default_model}")
        state.lm = dspy.LM(
            settings.default_model,
            api_key=settings.openai_api_key or settings.anthropic_api_key,
        )
        dspy.configure(lm=state.lm)
    else:
        print("[!] No API keys - running in graph-only mode (local NLP)")
        state.lm = None

    # Initialize ChromaDB for vector storage (using new API)
    print(f"[>] Initializing ChromaDB at {settings.chroma_persist_dir}")
    state.chroma_client = chromadb.PersistentClient(
        path=settings.chroma_persist_dir,
    )
    state.collection = state.chroma_client.get_or_create_collection(
        name=settings.chroma_collection_name
    )

    # Set up DSPy retriever with ChromaDB
    # Note: For production, you'd want a more sophisticated retriever
    # This is a simple in-memory retriever for now
    dspy.configure(rm=None)  # We'll handle retrieval manually for now

    # Initialize LLM-dependent modules only if we have an LLM
    if has_llm:
        print("[>] Initializing DSPy modules...")
        state.rag_module = RAGModule(num_passages=5)
        state.cot_module = ChainOfThoughtModule()
        state.tot_module = TreeOfThoughtModule(num_branches=3)
    else:
        print("[>] Skipping LLM modules (graph-only mode)")
        state.rag_module = None
        state.cot_module = None
        state.tot_module = None

    # Initialize graph store (always available - local-first)
    print("[>] Initializing knowledge graph...")
    graph_store = get_graph_store()
    extractor = get_entity_extractor()
    stats = graph_store.get_stats()
    print(f"    - Graph has {stats['entity_count']} entities")
    print(f"    - spaCy NLP: {'available' if extractor.nlp is not None else 'not available (using regex)'}")

    print("[+] DSPy Backend ready!")

    yield

    # Shutdown
    print("[*] Shutting down DSPy Backend...")
    # PersistentClient auto-persists, no explicit persist() call needed


def create_app() -> FastAPI:
    """Create and configure the FastAPI application"""
    app = FastAPI(
        title="Asmbli DSPy Backend",
        description="Production-ready AI agent infrastructure powered by DSPy",
        version="0.1.0",
        lifespan=lifespan,
    )

    # CORS middleware for Flutter app
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],  # Configure appropriately for production
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    return app


app = create_app()


# ============== Health Endpoints ==============

@app.get("/health", response_model=HealthResponse, tags=["Health"])
async def health_check():
    """Check if the backend is healthy and ready"""
    doc_count = state.collection.count() if state.collection else 0

    return HealthResponse(
        status="healthy",
        version="0.1.0",
        models_available=settings.get_available_models(),
        vector_db_status="connected" if state.chroma_client else "disconnected",
        documents_indexed=doc_count,
    )


@app.get("/", tags=["Health"])
async def root():
    """Root endpoint"""
    return {
        "message": "Asmbli DSPy Backend",
        "docs": "/docs",
        "health": "/health",
    }


# ============== Chat Endpoints ==============

@app.post("/chat", response_model=ChatResponse, tags=["Chat"])
async def chat(request: ChatRequest):
    """
    Simple chat endpoint.

    Use this for basic conversations without RAG or complex reasoning.
    """
    try:
        # Use specified model or default
        model = request.model or settings.default_model

        # Get API key based on model provider
        api_key = settings.anthropic_api_key if "anthropic" in model else settings.openai_api_key

        # Configure LM for this request with API key
        lm = dspy.LM(model, api_key=api_key)

        # Simple predict
        predict = dspy.ChainOfThought("question -> answer")

        with dspy.context(lm=lm):
            result = predict(question=request.message)

        return ChatResponse(
            response=result.answer,
            model=model,
            reasoning=getattr(result, 'reasoning', None),
            confidence=0.8,  # Default confidence for simple chat
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ============== RAG Endpoints ==============

@app.post("/rag/query", response_model=RAGResponse, tags=["RAG"])
async def rag_query(request: RAGRequest):
    """
    Query documents using RAG.

    Retrieves relevant documents and generates an answer.
    """
    try:
        model = request.model or settings.default_model
        api_key = settings.anthropic_api_key if "anthropic" in model else settings.openai_api_key

        # Get documents from ChromaDB
        results = state.collection.query(
            query_texts=[request.question],
            n_results=request.num_passages,
        )

        # Build context from results
        passages = []
        sources = []

        if results and results['documents'] and results['documents'][0]:
            for i, (doc, meta, dist) in enumerate(zip(
                results['documents'][0],
                results['metadatas'][0] if results['metadatas'] else [{}] * len(results['documents'][0]),
                results['distances'][0] if results['distances'] else [0] * len(results['documents'][0])
            )):
                passages.append(f"[Source {i+1}]: {doc}")
                sources.append(RAGSource(
                    document_id=meta.get('document_id', f'doc_{i}'),
                    title=meta.get('title', 'Unknown'),
                    excerpt=doc[:200] + "..." if len(doc) > 200 else doc,
                    relevance_score=1 - dist if dist else 0.5,  # Convert distance to similarity
                ))

        context = "\n\n".join(passages) if passages else "No relevant documents found."

        # Generate answer using DSPy
        class RAGSignature(dspy.Signature):
            """Answer based on context"""
            context: str = dspy.InputField()
            question: str = dspy.InputField()
            answer: str = dspy.OutputField()

        generate = dspy.ChainOfThought(RAGSignature)

        lm = dspy.LM(model, api_key=api_key)
        with dspy.context(lm=lm):
            result = generate(context=context, question=request.question)

        # Calculate confidence based on sources
        confidence = sum(s.relevance_score for s in sources) / len(sources) if sources else 0.3

        return RAGResponse(
            answer=result.answer,
            sources=sources if request.include_citations else [],
            confidence=min(confidence, 1.0),
            model=model,
            passages_used=len(passages),
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ============== Agent Endpoints ==============

@app.post("/agent/execute", response_model=AgentResponse, tags=["Agent"])
async def execute_agent(request: AgentRequest):
    """
    Execute a ReAct agent to complete a task.

    Uses official dspy.ReAct for optimized reasoning and tool use.
    The agent will reason, use tools, and iterate until done.

    MCP Tools:
    - If a tool has a server_id, it will be executed via Flutter's MCP bridge
    - Flutter must provide flutter_callback_url for MCP tool execution
    """
    try:
        model = request.model or settings.default_model
        api_key = settings.anthropic_api_key if "anthropic" in model else settings.openai_api_key

        # Build tools as dspy.ReAct compatible functions
        tools = [create_calculator_tool(), create_json_tool()]

        # Initialize MCP bridge if callback URL provided
        mcp_bridge = None
        if request.flutter_callback_url:
            mcp_bridge = get_mcp_bridge(request.flutter_callback_url)

        # Add custom tools from request
        for tool_def in request.tools:
            tool_names = [t.__name__ for t in tools]
            if tool_def.name not in tool_names:
                # Check if this is an MCP tool
                if tool_def.is_mcp_tool and mcp_bridge:
                    # Create MCP-backed tool that calls Flutter
                    mcp_tool_def = MCPToolDefinition(
                        name=tool_def.name,
                        description=tool_def.description,
                        server_id=tool_def.server_id,
                        input_schema=tool_def.input_schema or {},
                    )
                    mcp_bridge.register_tool(mcp_tool_def)
                    tools.append(mcp_bridge.create_dspy_tool(mcp_tool_def))
                else:
                    # Create a placeholder tool for non-MCP custom tools
                    def make_placeholder(name, desc):
                        def placeholder(input_str: str) -> str:
                            f"""Tool '{name}': {desc}. (Not yet implemented on backend)"""
                            return f"Tool {name} not implemented on backend: {input_str}"
                        placeholder.__name__ = name
                        placeholder.__doc__ = desc
                        return placeholder
                    tools.append(make_placeholder(tool_def.name, tool_def.description))

        # Create and run agent using official dspy.ReAct wrapper
        agent = ReActAgent(tools=tools, max_iters=request.max_iterations)

        lm = dspy.LM(model, api_key=api_key)
        with dspy.context(lm=lm):
            result = agent.run(question=request.task)

        # Parse trajectory into steps
        steps = []
        trajectory = getattr(result, 'trajectory', '') or ''

        # Handle trajectory being a dict or string
        if isinstance(trajectory, dict):
            trajectory = str(trajectory)

        if trajectory and isinstance(trajectory, str) and trajectory != "Trajectory not available":
            trajectory_lines = trajectory.split('\n')
            current_step = {}

            for line in trajectory_lines:
                line = line.strip()
                if not line:
                    continue

                if line.startswith("Thought") or line.startswith("Step"):
                    if current_step and current_step.get("thought"):
                        steps.append(AgentStep(**current_step))
                    iteration = len(steps) + 1
                    current_step = {
                        "iteration": iteration,
                        "thought": line.split(":", 1)[1].strip() if ":" in line else line,
                        "action": "",
                        "observation": None
                    }
                elif line.startswith("Action") and current_step:
                    current_step["action"] = line.split(":", 1)[1].strip() if ":" in line else line
                elif line.startswith("Observation") and current_step:
                    current_step["observation"] = line.split(":", 1)[1].strip() if ":" in line else line
                elif line.startswith("Reasoning") and current_step:
                    current_step["thought"] = line.split(":", 1)[1].strip() if ":" in line else line

            if current_step and current_step.get("thought"):
                steps.append(AgentStep(**current_step))

        # If no steps parsed, create a summary step
        if not steps:
            steps.append(AgentStep(
                iteration=1,
                thought=f"Processed task: {request.task}",
                action="reasoning",
                observation=str(result.answer) if hasattr(result, 'answer') else str(result)
            ))

        return AgentResponse(
            answer=result.answer,
            success=getattr(result, 'success', True),
            steps=steps,
            iterations_used=getattr(result, 'iterations', len(steps)),
            model=model,
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ============== Streaming Agent Endpoint ==============

def _create_sse_event(event_type: StreamEventType, data: dict) -> str:
    """Create an SSE-formatted event string"""
    event_data = {
        "event": event_type.value,
        "data": data,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    return f"data: {json.dumps(event_data)}\n\n"


async def _stream_agent_execution(request: AgentStreamRequest) -> AsyncGenerator[str, None]:
    """
    Generator that yields SSE events during agent execution.

    This wraps the ReAct agent execution and emits events at each step.
    """
    model = request.model or settings.default_model
    api_key = settings.anthropic_api_key if "anthropic" in model else settings.openai_api_key

    try:
        # Emit starting status
        yield _create_sse_event(StreamEventType.STATUS, {
            "message": "Starting agent execution...",
            "task": request.task,
            "agent_id": request.agent_id,
            "conversation_id": request.conversation_id,
        })

        # Build tools
        tools = [create_calculator_tool(), create_json_tool()]

        # Initialize MCP bridge if callback URL provided
        mcp_bridge = None
        if request.flutter_callback_url:
            mcp_bridge = get_mcp_bridge(request.flutter_callback_url)
            yield _create_sse_event(StreamEventType.STATUS, {
                "message": f"MCP bridge initialized: {request.flutter_callback_url}",
            })

        # Add custom tools from request
        for tool_def in request.tools:
            tool_names = [t.__name__ for t in tools]
            if tool_def.name not in tool_names:
                if tool_def.is_mcp_tool and mcp_bridge:
                    # Create MCP-backed tool
                    mcp_tool_def = MCPToolDefinition(
                        name=tool_def.name,
                        description=tool_def.description,
                        server_id=tool_def.server_id,
                        input_schema=tool_def.input_schema or {},
                    )
                    mcp_bridge.register_tool(mcp_tool_def)

                    # Create a streaming-aware wrapper for MCP tools
                    original_tool = mcp_bridge.create_dspy_tool(mcp_tool_def)

                    # We'll track tool calls through the agent execution
                    tools.append(original_tool)

                    yield _create_sse_event(StreamEventType.STATUS, {
                        "message": f"Registered MCP tool: {tool_def.name}",
                        "server_id": tool_def.server_id,
                    })
                else:
                    # Create placeholder for non-MCP tools
                    def make_placeholder(name, desc):
                        def placeholder(input_str: str) -> str:
                            return f"Tool {name} not implemented on backend: {input_str}"
                        placeholder.__name__ = name
                        placeholder.__doc__ = desc
                        return placeholder
                    tools.append(make_placeholder(tool_def.name, tool_def.description))

        # Emit thinking status
        yield _create_sse_event(StreamEventType.STATUS, {
            "message": "Analyzing task and planning approach...",
        })

        # Create agent
        agent = ReActAgent(tools=tools, max_iters=request.max_iterations)

        # Run agent (this is synchronous, so we run in executor)
        lm = dspy.LM(model, api_key=api_key)

        yield _create_sse_event(StreamEventType.STATUS, {
            "message": f"Executing with model: {model}",
        })

        # Execute agent
        loop = asyncio.get_event_loop()
        with dspy.context(lm=lm):
            result = await loop.run_in_executor(
                None,
                lambda: agent.run(question=request.task)
            )

        # Parse trajectory into steps and emit them
        trajectory = getattr(result, 'trajectory', '') or ''
        if isinstance(trajectory, dict):
            trajectory = str(trajectory)

        steps = []
        iteration = 0

        if trajectory and isinstance(trajectory, str) and trajectory != "Trajectory not available":
            trajectory_lines = trajectory.split('\n')
            current_step = {}

            for line in trajectory_lines:
                line = line.strip()
                if not line:
                    continue

                if line.startswith("Thought") or line.startswith("Step"):
                    if current_step and current_step.get("thought"):
                        iteration += 1
                        step_data = {
                            "iteration": iteration,
                            "thought": current_step.get("thought", ""),
                            "action": current_step.get("action", ""),
                            "observation": current_step.get("observation"),
                        }
                        steps.append(step_data)
                        yield _create_sse_event(StreamEventType.STEP, step_data)

                        # If action looks like a tool call, emit tool events
                        action = current_step.get("action", "")
                        if ":" in action:
                            tool_name = action.split(":")[0].strip()
                            yield _create_sse_event(StreamEventType.TOOL_CALL, {
                                "tool": tool_name,
                                "arguments": action.split(":", 1)[1].strip() if ":" in action else "",
                            })

                    current_step = {
                        "thought": line.split(":", 1)[1].strip() if ":" in line else line,
                        "action": "",
                        "observation": None,
                    }
                elif line.startswith("Action") and current_step:
                    current_step["action"] = line.split(":", 1)[1].strip() if ":" in line else line
                elif line.startswith("Observation") and current_step:
                    current_step["observation"] = line.split(":", 1)[1].strip() if ":" in line else line
                    # Emit tool result for observations
                    yield _create_sse_event(StreamEventType.TOOL_RESULT, {
                        "result": current_step["observation"],
                        "success": True,
                    })
                elif line.startswith("Reasoning") and current_step:
                    current_step["thought"] = line.split(":", 1)[1].strip() if ":" in line else line

            # Don't forget the last step
            if current_step and current_step.get("thought"):
                iteration += 1
                step_data = {
                    "iteration": iteration,
                    "thought": current_step.get("thought", ""),
                    "action": current_step.get("action", ""),
                    "observation": current_step.get("observation"),
                }
                steps.append(step_data)
                yield _create_sse_event(StreamEventType.STEP, step_data)

        # If no steps parsed, create a summary step
        if not steps:
            step_data = {
                "iteration": 1,
                "thought": f"Processed task: {request.task}",
                "action": "reasoning",
                "observation": str(result.answer) if hasattr(result, 'answer') else str(result),
            }
            steps.append(step_data)
            yield _create_sse_event(StreamEventType.STEP, step_data)

        # Emit final done event
        yield _create_sse_event(StreamEventType.DONE, {
            "answer": result.answer,
            "success": getattr(result, 'success', True),
            "iterations": len(steps),
            "model": model,
            "steps": steps,
        })

    except Exception as e:
        yield _create_sse_event(StreamEventType.ERROR, {
            "error": str(e),
            "error_type": type(e).__name__,
        })


@app.post("/agent/stream", tags=["Agent"])
async def stream_agent_execution(request: AgentStreamRequest):
    """
    Stream agent execution with real-time updates.

    Returns Server-Sent Events (SSE) stream with:
    - status: Agent status updates (thinking, calling tool, etc.)
    - tool_call: When agent decides to call a tool
    - tool_result: Results from tool execution
    - step: Complete reasoning steps
    - error: If something goes wrong
    - done: Final result with answer

    Use this for real-time UI updates during agent execution.

    Example SSE events:
    ```
    data: {"event": "status", "data": {"message": "Thinking..."}, "timestamp": "..."}

    data: {"event": "tool_call", "data": {"tool": "github_search", "arguments": {...}}, "timestamp": "..."}

    data: {"event": "tool_result", "data": {"result": {...}, "success": true}, "timestamp": "..."}

    data: {"event": "done", "data": {"answer": "...", "success": true}, "timestamp": "..."}
    ```
    """
    return StreamingResponse(
        _stream_agent_execution(request),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",  # Disable nginx buffering
        }
    )


# ============== Reasoning Endpoints ==============

@app.post("/reasoning", response_model=ReasoningResponse, tags=["Reasoning"])
async def reason(request: ReasoningRequest):
    """
    Apply structured reasoning to a question.

    Supports different reasoning patterns:
    - basic: Simple Q&A
    - chain_of_thought: Step-by-step reasoning
    - tree_of_thought: Explore multiple approaches
    """
    try:
        model = request.model or settings.default_model
        api_key = settings.anthropic_api_key if "anthropic" in model else settings.openai_api_key
        lm = dspy.LM(model, api_key=api_key)

        with dspy.context(lm=lm):
            if request.pattern == ReasoningPattern.CHAIN_OF_THOUGHT:
                result = state.cot_module(question=request.question)
                return ReasoningResponse(
                    answer=result.answer,
                    reasoning=result.reasoning,
                    confidence=result.confidence,
                    pattern_used="chain_of_thought",
                    model=model,
                )

            elif request.pattern == ReasoningPattern.TREE_OF_THOUGHT:
                tot = TreeOfThoughtModule(num_branches=request.num_branches)
                result = tot(problem=request.question)
                return ReasoningResponse(
                    answer=result.final_answer,
                    reasoning=result.reasoning,
                    confidence=0.8,  # ToT doesn't have built-in confidence
                    pattern_used="tree_of_thought",
                    model=model,
                    branches=result.branches,
                )

            else:  # Basic
                predict = dspy.Predict("question -> answer")
                result = predict(question=request.question)
                return ReasoningResponse(
                    answer=result.answer,
                    reasoning="Direct answer without explicit reasoning",
                    confidence=0.7,
                    pattern_used="basic",
                    model=model,
                )

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ============== Document Management ==============

@app.post("/documents/upload", response_model=DocumentUploadResponse, tags=["Documents"])
async def upload_document(request: DocumentUploadRequest):
    """
    Upload a document for RAG.

    The document will be chunked and indexed.
    """
    try:
        import hashlib

        # Generate document ID
        doc_id = hashlib.md5(request.content.encode()).hexdigest()[:12]

        # Simple chunking (in production, use a more sophisticated chunker)
        chunk_size = 1000
        overlap = 200
        chunks = []

        text = request.content
        start = 0
        while start < len(text):
            end = start + chunk_size
            chunk = text[start:end]
            chunks.append(chunk)
            start = end - overlap

        # Add to ChromaDB
        ids = [f"{doc_id}_chunk_{i}" for i in range(len(chunks))]
        metadatas = [
            {
                "document_id": doc_id,
                "title": request.title,
                "chunk_index": i,
                **request.metadata
            }
            for i in range(len(chunks))
        ]

        state.collection.add(
            documents=chunks,
            ids=ids,
            metadatas=metadatas,
        )

        return DocumentUploadResponse(
            document_id=doc_id,
            title=request.title,
            chunks_created=len(chunks),
            message=f"Document '{request.title}' uploaded successfully",
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/documents", response_model=DocumentListResponse, tags=["Documents"])
async def list_documents():
    """List all indexed documents"""
    try:
        # Get unique documents from collection
        all_items = state.collection.get()

        documents = {}
        if all_items and all_items['metadatas']:
            for meta in all_items['metadatas']:
                doc_id = meta.get('document_id')
                if doc_id and doc_id not in documents:
                    documents[doc_id] = {
                        "document_id": doc_id,
                        "title": meta.get('title', 'Unknown'),
                        "chunk_count": 0,
                    }
                if doc_id:
                    documents[doc_id]["chunk_count"] += 1

        return DocumentListResponse(
            documents=list(documents.values()),
            total_count=len(documents),
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.delete("/documents/{document_id}", tags=["Documents"])
async def delete_document(document_id: str):
    """Delete a document and all its chunks"""
    try:
        # Get all chunk IDs for this document
        all_items = state.collection.get()

        ids_to_delete = []
        if all_items and all_items['metadatas']:
            for i, meta in enumerate(all_items['metadatas']):
                if meta.get('document_id') == document_id:
                    ids_to_delete.append(all_items['ids'][i])

        if ids_to_delete:
            state.collection.delete(ids=ids_to_delete)
            return {"message": f"Deleted {len(ids_to_delete)} chunks", "document_id": document_id}
        else:
            raise HTTPException(status_code=404, detail="Document not found")

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ============== Code Generation ==============

@app.post("/code/generate", tags=["Code"])
async def generate_code(
    task: str,
    language: str = "python",
    execute: bool = False,
    model: str = None
):
    """
    Generate code for a task.

    Optionally execute Python code to verify it works.
    """
    try:
        model = model or settings.default_model
        api_key = settings.anthropic_api_key if "anthropic" in model else settings.openai_api_key

        agent = CodeAgent(execute_python=execute)

        lm = dspy.LM(model, api_key=api_key)
        with dspy.context(lm=lm):
            result = agent(task=task, language=language)

        response = {
            "code": result.code,
            "explanation": result.explanation,
            "language": language,
            "model": model,
        }

        if execute and language.lower() == "python":
            response["execution_result"] = getattr(result, 'execution_result', None)

        return response

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ============== Knowledge Graph Endpoints ==============

@app.get("/graph/stats", response_model=GraphStatsResponse, tags=["Graph"])
async def get_graph_stats():
    """
    Get statistics about the knowledge graph.

    Returns node count, edge count, and other metrics.
    This is a local operation - no API calls needed.
    """
    try:
        graph_store = get_graph_store()
        extractor = get_entity_extractor()
        stats = graph_store.get_stats()

        return GraphStatsResponse(
            node_count=stats['node_count'],
            edge_count=stats['edge_count'],
            entity_count=stats['entity_count'],
            relationship_count=stats['relationship_count'],
            document_count=stats['document_count'],
            density=stats['density'],
            spacy_available=extractor.use_spacy,
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/graph/ingest", response_model=GraphIngestResponse, tags=["Graph"])
async def ingest_to_graph(request: GraphIngestRequest):
    """
    Ingest text into the knowledge graph.

    Uses local NLP (spaCy) to extract entities and relationships.
    No LLM API calls - runs entirely offline.

    This builds the knowledge graph that can be queried later.
    """
    try:
        result = ingest_text(
            text=request.content,
            doc_id=request.doc_id or "",
        )

        return GraphIngestResponse(
            doc_id=result['doc_id'],
            entities_found=result['entities_found'],
            relationships_found=result['relationships_found'],
            new_entities=result['new_entities'],
            new_relationships=result['new_relationships'],
            total_entities=result['total_entities'],
            total_relationships=result['total_relationships'],
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/graph/query", response_model=GraphQueryResponse, tags=["Graph"])
async def query_graph(request: GraphQueryRequest):
    """
    Query the knowledge graph for related entities.

    Uses local NLP to extract entities from the query,
    then traverses the graph to find related context.
    No LLM API calls - runs entirely offline.
    """
    try:
        graph_store = get_graph_store()
        extractor = get_entity_extractor()

        # Extract entities from query
        query_entities, _ = extractor.extract(request.query)
        entity_names = [e.name for e in query_entities]

        # Also do fuzzy search for entities
        for word in request.query.split():
            if len(word) > 2:
                matches = graph_store.find_entities(word, limit=3)
                entity_names.extend([m.name for m in matches])

        entity_names = list(set(entity_names))

        # Get subgraph context
        context = graph_store.get_subgraph(
            seed_entities=entity_names,
            max_hops=request.max_hops,
            max_nodes=request.max_entities,
        )

        return GraphQueryResponse(
            entities=context.entities,
            relationships=context.relationships if request.include_relationships else [],
            query_entities=entity_names,
            context_text=context.to_text(),
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/graph/rag", response_model=GraphRAGResponse, tags=["Graph"])
async def graph_rag_query(request: GraphRAGRequest):
    """
    Graph-enhanced RAG query.

    Combines:
    1. Local NLP entity extraction (no API)
    2. Graph traversal for context (no API)
    3. Optional vector retrieval
    4. LLM synthesis (API call)

    This is the hybrid neurosymbolic approach:
    - Fast offline extraction and retrieval
    - LLM only for final synthesis
    """
    try:
        model = request.model or settings.default_model
        api_key = settings.anthropic_api_key if "anthropic" in model else settings.openai_api_key

        # Choose RAG module based on settings
        if request.use_vector_db:
            rag = LocalGraphRAG(
                num_passages=request.num_passages,
                graph_hops=request.graph_hops,
                use_vector_db=True,
            )
        else:
            rag = GraphOnlyRAG(graph_hops=request.graph_hops)

        lm = dspy.LM(model, api_key=api_key)
        with dspy.context(lm=lm):
            result = rag(question=request.question)

        # Get graph context stats
        graph_context = getattr(result, 'graph_context', None)
        graph_entities_used = len(graph_context.entities) if graph_context else 0

        # Get confidence from result or default
        confidence = getattr(result, 'confidence', 0.7)

        return GraphRAGResponse(
            answer=result.answer,
            reasoning=getattr(result, 'reasoning', ''),
            confidence=confidence,
            graph_entities_used=graph_entities_used,
            vector_passages_used=request.num_passages if request.use_vector_db else 0,
            model=model,
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.delete("/graph/clear", tags=["Graph"])
async def clear_graph():
    """
    Clear all data from the knowledge graph.

    Warning: This is destructive and cannot be undone!
    """
    try:
        graph_store = get_graph_store()
        graph_store.clear()
        return {"message": "Knowledge graph cleared successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/graph/entities", tags=["Graph"])
async def list_entities(limit: int = 50, offset: int = 0):
    """
    List all entities in the knowledge graph.

    Paginated for large graphs.
    """
    try:
        graph_store = get_graph_store()
        all_entities = list(graph_store.entity_data.values())

        # Sort by importance
        all_entities.sort(key=lambda e: e.importance_score, reverse=True)

        # Paginate
        paginated = all_entities[offset:offset + limit]

        return {
            "entities": [e.to_dict() for e in paginated],
            "total": len(all_entities),
            "limit": limit,
            "offset": offset,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/graph/communities", tags=["Graph"])
async def get_communities(min_size: int = 3):
    """
    Detect and return communities/clusters in the knowledge graph.

    Uses graph algorithms to find densely connected groups of entities.
    """
    try:
        graph_store = get_graph_store()
        communities = graph_store.compute_communities(min_size=min_size)

        return {
            "communities": communities,
            "count": len(communities),
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

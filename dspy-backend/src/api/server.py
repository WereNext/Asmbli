"""
FastAPI Server - The main entry point for the DSPy backend

This is what your Flutter app calls.
"""

import dspy
from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
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
)
from ..modules import (
    SimpleRAG,
    RAGModule,
    MultiHopRAG,
    ReActAgent,
    CodeAgent,
    ChainOfThoughtModule,
    TreeOfThoughtModule,
)
from ..modules.agents import create_calculator_tool, create_json_tool


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
    print("🚀 Starting DSPy Backend...")

    # Validate configuration
    valid, errors = settings.validate_config()
    if not valid:
        print(f"❌ Configuration errors: {errors}")
        raise RuntimeError(f"Invalid configuration: {errors}")

    # Initialize LLM
    print(f"📦 Initializing LLM: {settings.default_model}")
    state.lm = dspy.LM(
        settings.default_model,
        api_key=settings.openai_api_key or settings.anthropic_api_key,
    )
    dspy.configure(lm=state.lm)

    # Initialize ChromaDB for vector storage (using new API)
    print(f"🗄️ Initializing ChromaDB at {settings.chroma_persist_dir}")
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

    # Initialize modules
    print("🧠 Initializing DSPy modules...")
    state.rag_module = RAGModule(num_passages=5)
    state.cot_module = ChainOfThoughtModule()
    state.tot_module = TreeOfThoughtModule(num_branches=3)

    print("✅ DSPy Backend ready!")

    yield

    # Shutdown
    print("👋 Shutting down DSPy Backend...")
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
    """
    try:
        model = request.model or settings.default_model
        api_key = settings.anthropic_api_key if "anthropic" in model else settings.openai_api_key

        # Build tools as dspy.ReAct compatible functions
        tools = [create_calculator_tool(), create_json_tool()]

        # Add custom tools from request
        for tool_def in request.tools:
            tool_names = [t.__name__ for t in tools]
            if tool_def.name not in tool_names:
                # Create a placeholder tool for custom tools
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

        if trajectory and trajectory != "Trajectory not available":
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

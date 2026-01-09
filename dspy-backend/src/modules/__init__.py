"""
DSPy Modules - AI components using official DSPy primitives

ReActAgent now wraps official dspy.ReAct for better optimization.
Includes hybrid neurosymbolic GraphRAG for local-first context graphs.
"""

from .rag import RAGModule, SimpleRAG, MultiHopRAG
from .agents import ReActAgent, CodeAgent, Tool, create_tool, create_calculator_tool, create_json_tool
from .reasoning import ChainOfThoughtModule, TreeOfThoughtModule

# Graph modules - local-first hybrid neurosymbolic approach
from .graph import (
    Entity,
    Relationship,
    GraphContext,
    LocalEntityExtractor,
    LocalGraphStore,
    get_graph_store,
    get_entity_extractor,
    ingest_text,
)
from .graph_rag import (
    LocalGraphRAG,
    GraphOnlyRAG,
    MultiHopGraphRAG,
    GraphQueryExpander,
)

__all__ = [
    # RAG
    "RAGModule",
    "SimpleRAG",
    "MultiHopRAG",
    # Agents
    "ReActAgent",
    "CodeAgent",
    "Tool",  # Legacy, prefer create_tool
    "create_tool",
    "create_calculator_tool",
    "create_json_tool",
    # Reasoning
    "ChainOfThoughtModule",
    "TreeOfThoughtModule",
    # Graph (local-first)
    "Entity",
    "Relationship",
    "GraphContext",
    "LocalEntityExtractor",
    "LocalGraphStore",
    "get_graph_store",
    "get_entity_extractor",
    "ingest_text",
    # GraphRAG
    "LocalGraphRAG",
    "GraphOnlyRAG",
    "MultiHopGraphRAG",
    "GraphQueryExpander",
]

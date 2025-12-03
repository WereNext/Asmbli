"""
DSPy Modules - AI components using official DSPy primitives

ReActAgent now wraps official dspy.ReAct for better optimization.
"""

from .rag import RAGModule, SimpleRAG, MultiHopRAG
from .agents import ReActAgent, CodeAgent, Tool, create_tool, create_calculator_tool, create_json_tool
from .reasoning import ChainOfThoughtModule, TreeOfThoughtModule

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
]

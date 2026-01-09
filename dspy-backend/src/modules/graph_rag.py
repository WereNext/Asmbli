"""
GraphRAG Module - DSPy integration for graph-enhanced RAG

This module combines:
1. Traditional vector retrieval (ChromaDB)
2. Graph context retrieval (NetworkX)
3. DSPy synthesis (LLM only at the end)

The hybrid approach means:
- Extraction: Local NLP (fast, offline, deterministic)
- Retrieval: Graph traversal + vector similarity
- Synthesis: LLM via DSPy (only step that needs API)
"""
from __future__ import annotations

import dspy
from typing import Optional, List, Dict

from .graph import (
    get_graph_store,
    get_entity_extractor,
    GraphContext,
    LocalGraphStore,
    LocalEntityExtractor,
)


# ============== DSPy Signatures ==============

class GraphRAGSignature(dspy.Signature):
    """Answer questions using both graph and vector context"""

    question: str = dspy.InputField(desc="The user's question")
    vector_context: str = dspy.InputField(desc="Retrieved text passages from vector DB")
    graph_context: str = dspy.InputField(desc="Related entities and relationships from knowledge graph")
    answer: str = dspy.OutputField(desc="A comprehensive answer based on both contexts")
    reasoning: str = dspy.OutputField(desc="Explanation of how the answer was derived")


class GraphQuerySignature(dspy.Signature):
    """Extract search terms from a question for graph querying"""

    question: str = dspy.InputField(desc="The user's question")
    entities: list[str] = dspy.OutputField(desc="Key entities to search for in the knowledge graph")
    concepts: list[str] = dspy.OutputField(desc="Abstract concepts related to the question")


class GraphSynthesisSignature(dspy.Signature):
    """Synthesize an answer from graph context alone"""

    question: str = dspy.InputField(desc="The user's question")
    entities: str = dspy.InputField(desc="Relevant entities and their types")
    relationships: str = dspy.InputField(desc="Relationships between entities")
    answer: str = dspy.OutputField(desc="Answer based on the knowledge graph")
    confidence: float = dspy.OutputField(desc="Confidence score from 0.0 to 1.0")


# ============== DSPy Modules ==============

class GraphQueryExpander(dspy.Module):
    """
    Expand a user question into graph search terms.

    Uses LLM to identify entities and concepts to search for,
    then finds them in the local graph.
    """

    def __init__(self, graph_store: Optional[LocalGraphStore] = None):
        super().__init__()
        self.graph = graph_store or get_graph_store()
        self.extractor = get_entity_extractor()
        self.query_gen = dspy.ChainOfThought(GraphQuerySignature)

    def forward(self, question: str) -> dspy.Prediction:
        # First, try local NLP extraction (no LLM call)
        entities_local, _ = self.extractor.extract(question)
        local_entity_names = [e.name for e in entities_local]

        # Find matching entities in graph
        graph_matches = []
        for name in local_entity_names:
            matches = self.graph.find_entities(name, limit=3)
            graph_matches.extend([m.name for m in matches])

        # If we found entities locally, use them
        if graph_matches:
            return dspy.Prediction(
                entities=graph_matches,
                concepts=local_entity_names,
                used_llm=False,
            )

        # Fall back to LLM for complex queries
        try:
            result = self.query_gen(question=question)
            return dspy.Prediction(
                entities=result.entities if isinstance(result.entities, list) else [],
                concepts=result.concepts if isinstance(result.concepts, list) else [],
                used_llm=True,
            )
        except Exception:
            # If LLM fails, return what we have
            return dspy.Prediction(
                entities=local_entity_names,
                concepts=[],
                used_llm=False,
            )


class LocalGraphRAG(dspy.Module):
    """
    Local-first GraphRAG module.

    Architecture:
    1. Extract entities from question (local NLP)
    2. Traverse graph for related context (local)
    3. Optionally retrieve from vector DB
    4. Synthesize answer with LLM (only API call)

    This is optimized for:
    - Offline capability (extraction + traversal work without internet)
    - Low latency (no API calls for graph operations)
    - Cost efficiency (LLM only used for final synthesis)
    """

    def __init__(
        self,
        graph_store: Optional[LocalGraphStore] = None,
        num_passages: int = 5,
        graph_hops: int = 2,
        use_vector_db: bool = True,
    ):
        super().__init__()
        self.graph = graph_store or get_graph_store()
        self.extractor = get_entity_extractor()
        self.num_passages = num_passages
        self.graph_hops = graph_hops
        self.use_vector_db = use_vector_db

        # DSPy modules
        self.query_expander = GraphQueryExpander(self.graph)
        self.synthesizer = dspy.ChainOfThought(GraphRAGSignature)

        # Optional vector retrieval
        if use_vector_db:
            self.retrieve = dspy.Retrieve(k=num_passages)

    def forward(self, question: str) -> dspy.Prediction:
        # Step 1: Extract entities from question (LOCAL - no API)
        query_entities, _ = self.extractor.extract(question)
        entity_names = [e.name for e in query_entities]

        # Step 2: Expand query if needed
        expanded = self.query_expander(question=question)
        all_entities = list(set(entity_names + expanded.entities))

        # Step 3: Get graph context (LOCAL - no API)
        graph_context = self.graph.get_subgraph(
            seed_entities=all_entities,
            max_hops=self.graph_hops,
            max_nodes=30,
        )
        graph_text = graph_context.to_text()

        # Step 4: Get vector context (optional)
        vector_text = ""
        if self.use_vector_db:
            try:
                retrieved = self.retrieve(question)
                if retrieved and retrieved.passages:
                    vector_text = "\n\n".join(retrieved.passages)
            except Exception:
                pass  # Vector DB might not be configured

        # Step 5: Synthesize answer (LLM API call)
        result = self.synthesizer(
            question=question,
            vector_context=vector_text or "No vector context available.",
            graph_context=graph_text,
        )

        return dspy.Prediction(
            answer=result.answer,
            reasoning=result.reasoning,
            graph_context=graph_context,
            query_entities=all_entities,
            used_llm_for_expansion=expanded.used_llm if hasattr(expanded, 'used_llm') else False,
        )


class GraphOnlyRAG(dspy.Module):
    """
    Graph-only RAG for when vector DB is not available.

    Uses only the knowledge graph for context, no vector retrieval.
    Useful for completely offline operation with local LLM.
    """

    def __init__(
        self,
        graph_store: Optional[LocalGraphStore] = None,
        graph_hops: int = 2,
    ):
        super().__init__()
        self.graph = graph_store or get_graph_store()
        self.extractor = get_entity_extractor()
        self.graph_hops = graph_hops
        self.synthesizer = dspy.ChainOfThought(GraphSynthesisSignature)

    def forward(self, question: str) -> dspy.Prediction:
        # Extract entities locally
        query_entities, _ = self.extractor.extract(question)
        entity_names = [e.name for e in query_entities]

        # Get graph context
        graph_context = self.graph.get_subgraph(
            seed_entities=entity_names,
            max_hops=self.graph_hops,
            max_nodes=40,
        )

        # Format for LLM
        entities_text = "\n".join([
            f"- {e['name']} ({e.get('type', 'UNKNOWN')}): {e.get('description', '')}"
            for e in graph_context.entities[:20]
        ])

        relationships_text = "\n".join([
            f"- {r['source']} --[{r.get('relation', 'related')}]--> {r['target']}"
            for r in graph_context.relationships[:30]
        ])

        # Check if we have any context
        if not graph_context.entities:
            return dspy.Prediction(
                answer="I don't have enough information in my knowledge graph to answer this question.",
                confidence=0.0,
                graph_context=graph_context,
                query_entities=entity_names,
            )

        # Synthesize answer
        result = self.synthesizer(
            question=question,
            entities=entities_text or "No entities found.",
            relationships=relationships_text or "No relationships found.",
        )

        # Parse confidence
        try:
            confidence = float(result.confidence)
        except (ValueError, TypeError):
            confidence = 0.5

        return dspy.Prediction(
            answer=result.answer,
            confidence=min(max(confidence, 0.0), 1.0),
            graph_context=graph_context,
            query_entities=entity_names,
        )


class MultiHopGraphRAG(dspy.Module):
    """
    Multi-hop reasoning over the knowledge graph.

    For complex questions that require connecting multiple entities:
    1. Start with question entities
    2. Expand through graph relationships
    3. Generate follow-up queries
    4. Synthesize multi-hop answer
    """

    def __init__(
        self,
        graph_store: Optional[LocalGraphStore] = None,
        max_hops: int = 3,
    ):
        super().__init__()
        self.graph = graph_store or get_graph_store()
        self.extractor = get_entity_extractor()
        self.max_hops = max_hops

        # Multi-hop query generator
        class HopQuerySignature(dspy.Signature):
            """Generate a follow-up query to gather more context"""
            question: str = dspy.InputField()
            current_context: str = dspy.InputField()
            follow_up_query: str = dspy.OutputField()

        self.hop_generator = dspy.ChainOfThought(HopQuerySignature)
        self.synthesizer = dspy.ChainOfThought(GraphRAGSignature)

    def forward(self, question: str) -> dspy.Prediction:
        all_context = []
        all_entities = set()

        # Initial extraction
        query_entities, _ = self.extractor.extract(question)
        current_entities = [e.name for e in query_entities]
        all_entities.update(current_entities)

        # Multi-hop expansion
        for hop in range(self.max_hops):
            # Get context for current entities
            graph_context = self.graph.get_subgraph(
                seed_entities=current_entities,
                max_hops=1,  # Single hop at a time
                max_nodes=20,
            )

            if not graph_context.entities:
                break

            all_context.append(graph_context)

            # Extract new entities for next hop
            new_entities = set()
            for rel in graph_context.relationships:
                new_entities.add(rel['source'])
                new_entities.add(rel['target'])

            # Only explore entities we haven't seen
            current_entities = list(new_entities - all_entities)
            all_entities.update(new_entities)

            if not current_entities:
                break

        # Merge all contexts
        merged_entities = []
        merged_relationships = []
        seen_entities = set()
        seen_rels = set()

        for ctx in all_context:
            for e in ctx.entities:
                if e['name'] not in seen_entities:
                    seen_entities.add(e['name'])
                    merged_entities.append(e)

            for r in ctx.relationships:
                rel_key = f"{r['source']}|{r['target']}"
                if rel_key not in seen_rels:
                    seen_rels.add(rel_key)
                    merged_relationships.append(r)

        final_context = GraphContext(
            entities=merged_entities,
            relationships=merged_relationships,
        )

        # Synthesize answer
        result = self.synthesizer(
            question=question,
            vector_context="Multi-hop graph traversal (no vector context used).",
            graph_context=final_context.to_text(),
        )

        return dspy.Prediction(
            answer=result.answer,
            reasoning=result.reasoning,
            graph_context=final_context,
            hops_used=len(all_context),
            entities_explored=len(all_entities),
        )

"""
Local-First Knowledge Graph Module

Hybrid neurosymbolic approach for context graphs:
- spaCy for NLP entity/relationship extraction (runs offline)
- NetworkX for graph storage and traversal
- JSON persistence for local-first storage
- DSPy integration for LLM synthesis only at the end

This approach is:
- Fast: No API calls for extraction
- Offline-capable: Works without internet
- Deterministic: No LLM hallucinations in graph construction
- Cost-effective: Only uses LLM for final synthesis
"""
from __future__ import annotations

import json
import re
from pathlib import Path
from typing import List, Dict, Tuple, Optional, Set
from dataclasses import dataclass, field, asdict
from collections import defaultdict
import hashlib

import networkx as nx


# ============== Data Models ==============

@dataclass
class Entity:
    """An entity extracted from text"""
    name: str
    type: str  # PERSON, ORG, CONCEPT, LOCATION, etc.
    description: str = ""
    mentions: int = 1
    importance_score: float = 0.5
    source_docs: List[str] = field(default_factory=list)

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict) -> "Entity":
        return cls(**data)


@dataclass
class Relationship:
    """A relationship between two entities"""
    source: str
    target: str
    relation: str  # verb or dependency type
    weight: float = 1.0
    bidirectional: bool = False
    source_docs: List[str] = field(default_factory=list)

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict) -> "Relationship":
        return cls(**data)


@dataclass
class GraphContext:
    """Context retrieved from the graph for a query"""
    entities: List[Dict]
    relationships: List[Dict]
    communities: List[Dict] = field(default_factory=list)
    relevance_scores: Dict[str, float] = field(default_factory=dict)

    def to_text(self, max_entities: int = 15, max_rels: int = 20) -> str:
        """Format as text for LLM consumption"""
        lines = []

        if self.entities:
            lines.append("## Relevant Entities")
            sorted_entities = sorted(
                self.entities[:max_entities],
                key=lambda e: self.relevance_scores.get(e.get('name', ''), 0),
                reverse=True
            )
            for e in sorted_entities:
                etype = e.get('type', 'UNKNOWN')
                desc = e.get('description', '')
                desc_str = f" - {desc}" if desc else ""
                lines.append(f"- **{e['name']}** ({etype}){desc_str}")

        if self.relationships:
            lines.append("\n## Relationships")
            for r in self.relationships[:max_rels]:
                rel = r.get('relation', 'related to')
                lines.append(f"- {r['source']} --[{rel}]--> {r['target']}")

        if self.communities:
            lines.append("\n## Topic Clusters")
            for c in self.communities[:5]:
                members = ", ".join(c.get('members', [])[:5])
                lines.append(f"- {c.get('name', 'Cluster')}: {members}")

        return "\n".join(lines) if lines else "No relevant graph context found."


# ============== Local NLP Extractor ==============

class LocalEntityExtractor:
    """
    Extract entities and relationships using spaCy.

    Falls back to regex patterns if spaCy is not available.
    This is the "neuro" part that runs locally without API calls.
    """

    def __init__(self, use_spacy: bool = True):
        self.nlp = None
        self.use_spacy = use_spacy

        if use_spacy:
            try:
                import spacy
                # Try to load the small English model
                try:
                    self.nlp = spacy.load("en_core_web_sm")
                except OSError:
                    # Model not installed, try to download
                    print("[!] spaCy model not found. Falling back to regex extraction.")
                    print("    To enable full NLP: python -m spacy download en_core_web_sm")
                    self.use_spacy = False
            except ImportError:
                print("[!] spaCy not installed. Using regex fallback.")
                self.use_spacy = False

    def extract(self, text: str, doc_id: str = "") -> Tuple[List[Entity], List[Relationship]]:
        """Extract entities and relationships from text"""
        if self.use_spacy and self.nlp:
            return self._extract_with_spacy(text, doc_id)
        else:
            return self._extract_with_regex(text, doc_id)

    def _extract_with_spacy(self, text: str, doc_id: str) -> Tuple[List[Entity], List[Relationship]]:
        """Full NLP extraction using spaCy"""
        doc = self.nlp(text)

        entities = []
        entity_names = set()

        # Extract named entities
        for ent in doc.ents:
            if ent.text.strip() and len(ent.text) > 1:
                name = ent.text.strip()
                if name not in entity_names:
                    entity_names.add(name)
                    entities.append(Entity(
                        name=name,
                        type=ent.label_,
                        source_docs=[doc_id] if doc_id else [],
                    ))

        # Extract noun chunks as concepts
        for chunk in doc.noun_chunks:
            name = chunk.root.text.strip()
            if name and len(name) > 2 and name.lower() not in ('it', 'this', 'that', 'which'):
                if name not in entity_names:
                    entity_names.add(name)
                    entities.append(Entity(
                        name=name,
                        type="CONCEPT",
                        source_docs=[doc_id] if doc_id else [],
                        importance_score=0.3,  # Lower score for noun chunks
                    ))

        # Extract relationships from dependency parse
        relationships = []
        for token in doc:
            # Subject-Verb-Object patterns
            if token.dep_ in ("nsubj", "nsubjpass"):
                verb = token.head
                if verb.pos_ == "VERB":
                    # Find the object
                    for child in verb.children:
                        if child.dep_ in ("dobj", "pobj", "attr"):
                            if token.text in entity_names and child.text in entity_names:
                                relationships.append(Relationship(
                                    source=token.text,
                                    target=child.text,
                                    relation=verb.lemma_,
                                    source_docs=[doc_id] if doc_id else [],
                                ))

            # Prepositional relationships (X of Y, X in Y, etc.)
            if token.dep_ == "prep" and token.head.pos_ in ("NOUN", "PROPN"):
                for pobj in token.children:
                    if pobj.dep_ == "pobj":
                        source_name = token.head.text
                        target_name = pobj.text
                        if source_name in entity_names and target_name in entity_names:
                            relationships.append(Relationship(
                                source=source_name,
                                target=target_name,
                                relation=token.text,  # prep word like "of", "in"
                                source_docs=[doc_id] if doc_id else [],
                            ))

        return entities, relationships

    def _extract_with_regex(self, text: str, doc_id: str) -> Tuple[List[Entity], List[Relationship]]:
        """Fallback regex extraction when spaCy is not available"""
        entities = []
        entity_names = set()

        # Extract capitalized phrases (potential proper nouns)
        proper_nouns = re.findall(r'\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\b', text)
        for noun in proper_nouns:
            if noun not in entity_names and len(noun) > 2:
                entity_names.add(noun)
                entities.append(Entity(
                    name=noun,
                    type="PROPER_NOUN",
                    source_docs=[doc_id] if doc_id else [],
                ))

        # Extract quoted terms
        quoted = re.findall(r'"([^"]+)"', text) + re.findall(r"'([^']+)'", text)
        for term in quoted:
            if term not in entity_names and len(term) > 2:
                entity_names.add(term)
                entities.append(Entity(
                    name=term,
                    type="TERM",
                    source_docs=[doc_id] if doc_id else [],
                ))

        # Simple verb-based relationship extraction
        relationships = []
        sentences = re.split(r'[.!?]', text)
        verb_pattern = re.compile(
            r'(\b[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*\b)\s+'
            r'(is|are|was|were|has|have|had|does|do|did|can|will|'
            r'creates?|builds?|uses?|implements?|calls?|returns?|'
            r'contains?|includes?|requires?|depends?\s+on)\s+'
            r'(?:a\s+|an\s+|the\s+)?'
            r'(\b[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*\b|\b[a-z]+\b)',
            re.IGNORECASE
        )

        for sentence in sentences:
            matches = verb_pattern.findall(sentence)
            for match in matches:
                source, verb, target = match
                if source in entity_names or target in entity_names:
                    relationships.append(Relationship(
                        source=source,
                        target=target,
                        relation=verb.lower(),
                        source_docs=[doc_id] if doc_id else [],
                    ))

        return entities, relationships


# ============== Graph Storage ==============

class LocalGraphStore:
    """
    Persisted NetworkX graph with JSON storage.

    This is fully offline and local-first:
    - In-memory NetworkX graph for fast traversal
    - JSON persistence for portability
    - No external database needed
    """

    def __init__(self, storage_path: str = "./data/graph_store.json"):
        self.storage_path = Path(storage_path)
        self.storage_path.parent.mkdir(parents=True, exist_ok=True)

        self.graph = nx.DiGraph()
        self.entity_data: Dict[str, Entity] = {}
        self.relationship_data: Dict[str, Relationship] = {}
        self.doc_index: Dict[str, Set[str]] = defaultdict(set)  # doc_id -> entity names

        self._load()

    def _load(self):
        """Load graph from JSON file"""
        if self.storage_path.exists():
            try:
                data = json.loads(self.storage_path.read_text(encoding='utf-8'))

                # Load entities
                for name, ent_data in data.get('entities', {}).items():
                    entity = Entity.from_dict(ent_data)
                    self.entity_data[name] = entity
                    self.graph.add_node(
                        name,
                        type=entity.type,
                        importance=entity.importance_score,
                        mentions=entity.mentions,
                    )
                    for doc_id in entity.source_docs:
                        self.doc_index[doc_id].add(name)

                # Load relationships
                for rel_key, rel_data in data.get('relationships', {}).items():
                    rel = Relationship.from_dict(rel_data)
                    self.relationship_data[rel_key] = rel
                    self.graph.add_edge(
                        rel.source,
                        rel.target,
                        relation=rel.relation,
                        weight=rel.weight,
                    )
                    if rel.bidirectional:
                        self.graph.add_edge(
                            rel.target,
                            rel.source,
                            relation=rel.relation,
                            weight=rel.weight,
                        )

                print(f"[+] Loaded graph: {len(self.entity_data)} entities, {len(self.relationship_data)} relationships")
            except Exception as e:
                print(f"[!] Failed to load graph: {e}")

    def save(self):
        """Persist graph to JSON file"""
        data = {
            'entities': {name: ent.to_dict() for name, ent in self.entity_data.items()},
            'relationships': {key: rel.to_dict() for key, rel in self.relationship_data.items()},
            'metadata': {
                'node_count': self.graph.number_of_nodes(),
                'edge_count': self.graph.number_of_edges(),
            }
        }
        self.storage_path.write_text(json.dumps(data, indent=2), encoding='utf-8')

    def add_entity(self, entity: Entity) -> bool:
        """Add or update an entity"""
        name = entity.name

        if name in self.entity_data:
            # Update existing entity
            existing = self.entity_data[name]
            existing.mentions += 1
            existing.importance_score = min(1.0, existing.importance_score + 0.1)
            for doc in entity.source_docs:
                if doc not in existing.source_docs:
                    existing.source_docs.append(doc)
                    self.doc_index[doc].add(name)

            # Update graph node
            self.graph.nodes[name]['mentions'] = existing.mentions
            self.graph.nodes[name]['importance'] = existing.importance_score
            return False  # Not a new entity
        else:
            # Add new entity
            self.entity_data[name] = entity
            self.graph.add_node(
                name,
                type=entity.type,
                importance=entity.importance_score,
                mentions=entity.mentions,
            )
            for doc in entity.source_docs:
                self.doc_index[doc].add(name)
            return True  # New entity

    def add_relationship(self, rel: Relationship) -> bool:
        """Add or update a relationship"""
        rel_key = f"{rel.source}|{rel.relation}|{rel.target}"

        if rel_key in self.relationship_data:
            # Update weight
            existing = self.relationship_data[rel_key]
            existing.weight += rel.weight
            for doc in rel.source_docs:
                if doc not in existing.source_docs:
                    existing.source_docs.append(doc)

            if self.graph.has_edge(rel.source, rel.target):
                self.graph[rel.source][rel.target]['weight'] = existing.weight
            return False
        else:
            # Ensure both nodes exist
            if rel.source not in self.graph:
                self.graph.add_node(rel.source, type="UNKNOWN", importance=0.3, mentions=1)
            if rel.target not in self.graph:
                self.graph.add_node(rel.target, type="UNKNOWN", importance=0.3, mentions=1)

            # Add relationship
            self.relationship_data[rel_key] = rel
            self.graph.add_edge(
                rel.source,
                rel.target,
                relation=rel.relation,
                weight=rel.weight,
            )
            if rel.bidirectional:
                self.graph.add_edge(
                    rel.target,
                    rel.source,
                    relation=rel.relation,
                    weight=rel.weight,
                )
            return True

    def get_entity(self, name: str) -> Optional[Entity]:
        """Get entity by name"""
        return self.entity_data.get(name)

    def find_entities(self, query: str, limit: int = 10) -> List[Entity]:
        """Find entities matching a query (fuzzy search)"""
        query_lower = query.lower()
        matches = []

        for name, entity in self.entity_data.items():
            if query_lower in name.lower():
                matches.append((entity, 1.0))  # Exact match
            elif any(word in name.lower() for word in query_lower.split()):
                matches.append((entity, 0.5))  # Partial match

        # Sort by match quality and importance
        matches.sort(key=lambda x: (x[1], x[0].importance_score), reverse=True)
        return [m[0] for m in matches[:limit]]

    def get_subgraph(
        self,
        seed_entities: List[str],
        max_hops: int = 2,
        max_nodes: int = 50,
    ) -> GraphContext:
        """
        Get a subgraph around seed entities using BFS traversal.

        This is the "semantic random walk" part of the hybrid approach.
        """
        if not seed_entities:
            return GraphContext(entities=[], relationships=[])

        # Find matching nodes for seeds (fuzzy match)
        start_nodes = set()
        for seed in seed_entities:
            seed_lower = seed.lower()
            for node in self.graph.nodes():
                if seed_lower in node.lower() or node.lower() in seed_lower:
                    start_nodes.add(node)

        if not start_nodes:
            return GraphContext(entities=[], relationships=[])

        # BFS traversal with hop limit
        visited = set()
        relevance_scores = {}

        current_level = start_nodes
        for hop in range(max_hops + 1):
            next_level = set()
            for node in current_level:
                if node not in visited and len(visited) < max_nodes:
                    visited.add(node)
                    # Relevance decreases with distance
                    relevance_scores[node] = 1.0 / (hop + 1)

                    # Add neighbors for next iteration
                    next_level.update(self.graph.successors(node))
                    next_level.update(self.graph.predecessors(node))

            current_level = next_level - visited
            if not current_level:
                break

        # Build result
        entities = []
        for node in visited:
            if node in self.entity_data:
                entities.append(self.entity_data[node].to_dict())
            else:
                # Node exists in graph but not in entity_data
                node_data = self.graph.nodes.get(node, {})
                entities.append({
                    'name': node,
                    'type': node_data.get('type', 'UNKNOWN'),
                    'importance_score': node_data.get('importance', 0.5),
                    'mentions': node_data.get('mentions', 1),
                })

        relationships = []
        for u, v, data in self.graph.edges(data=True):
            if u in visited and v in visited:
                relationships.append({
                    'source': u,
                    'target': v,
                    'relation': data.get('relation', 'related'),
                    'weight': data.get('weight', 1.0),
                })

        return GraphContext(
            entities=entities,
            relationships=relationships,
            relevance_scores=relevance_scores,
        )

    def get_document_context(self, doc_id: str) -> GraphContext:
        """Get all entities and relationships from a specific document"""
        entity_names = self.doc_index.get(doc_id, set())
        return self.get_subgraph(list(entity_names), max_hops=1)

    def compute_communities(self, min_size: int = 3) -> List[Dict]:
        """Detect communities/clusters in the graph"""
        if self.graph.number_of_nodes() < min_size:
            return []

        try:
            # Use Louvain community detection
            import community as community_louvain
            partition = community_louvain.best_partition(self.graph.to_undirected())

            communities = defaultdict(list)
            for node, comm_id in partition.items():
                communities[comm_id].append(node)

            result = []
            for comm_id, members in communities.items():
                if len(members) >= min_size:
                    # Find central node
                    subgraph = self.graph.subgraph(members)
                    centrality = nx.degree_centrality(subgraph)
                    central_node = max(members, key=lambda n: centrality.get(n, 0))

                    result.append({
                        'id': comm_id,
                        'name': central_node,
                        'members': members,
                        'size': len(members),
                    })

            return sorted(result, key=lambda c: c['size'], reverse=True)
        except ImportError:
            # Fallback to connected components
            undirected = self.graph.to_undirected()
            components = list(nx.connected_components(undirected))

            return [
                {
                    'id': i,
                    'name': f"Cluster {i+1}",
                    'members': list(comp),
                    'size': len(comp),
                }
                for i, comp in enumerate(components)
                if len(comp) >= min_size
            ]

    def get_stats(self) -> Dict:
        """Get graph statistics"""
        return {
            'node_count': self.graph.number_of_nodes(),
            'edge_count': self.graph.number_of_edges(),
            'entity_count': len(self.entity_data),
            'relationship_count': len(self.relationship_data),
            'document_count': len(self.doc_index),
            'density': nx.density(self.graph) if self.graph.number_of_nodes() > 0 else 0,
        }

    def clear(self):
        """Clear all data"""
        self.graph.clear()
        self.entity_data.clear()
        self.relationship_data.clear()
        self.doc_index.clear()
        if self.storage_path.exists():
            self.storage_path.unlink()


# ============== Singleton Access ==============

_graph_store: Optional[LocalGraphStore] = None
_entity_extractor: Optional[LocalEntityExtractor] = None


def get_graph_store(storage_path: str = "./data/graph_store.json") -> LocalGraphStore:
    """Get or create the singleton graph store"""
    global _graph_store
    if _graph_store is None:
        _graph_store = LocalGraphStore(storage_path)
    return _graph_store


def get_entity_extractor(use_spacy: bool = True) -> LocalEntityExtractor:
    """Get or create the singleton entity extractor"""
    global _entity_extractor
    if _entity_extractor is None:
        _entity_extractor = LocalEntityExtractor(use_spacy)
    return _entity_extractor


def ingest_text(
    text: str,
    doc_id: str = "",
    store: Optional[LocalGraphStore] = None,
    extractor: Optional[LocalEntityExtractor] = None,
) -> Dict:
    """
    Ingest text into the knowledge graph.

    This is the main entry point for adding documents.
    """
    if not doc_id:
        doc_id = hashlib.md5(text.encode()).hexdigest()[:12]

    store = store or get_graph_store()
    extractor = extractor or get_entity_extractor()

    entities, relationships = extractor.extract(text, doc_id)

    new_entities = 0
    new_relationships = 0

    for entity in entities:
        if store.add_entity(entity):
            new_entities += 1

    for rel in relationships:
        if store.add_relationship(rel):
            new_relationships += 1

    store.save()

    return {
        'doc_id': doc_id,
        'entities_found': len(entities),
        'relationships_found': len(relationships),
        'new_entities': new_entities,
        'new_relationships': new_relationships,
        'total_entities': len(store.entity_data),
        'total_relationships': len(store.relationship_data),
    }

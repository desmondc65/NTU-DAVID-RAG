"""
Assemble a directed knowledge graph from per-chunk extractions, then detect
hierarchical communities.

Graph model
-----------
- Nodes: canonical entity (keyed by lower-cased name). Stored attributes:
  ``name`` (display), ``type``, ``description`` (concatenated across
  chunks, deduped), ``chunk_ids`` (list), ``paper_titles`` (list),
  ``degree`` (populated after construction).
- Edges: directed, ``relationship_type``, ``description``, ``weight``
  (sum of strengths), ``chunk_ids``, ``paper_titles``.

Community detection
-------------------
Uses Leiden via ``graspologic`` when available (better modularity and
hierarchy), otherwise falls back to NetworkX's built-in greedy modularity
which still yields reasonable communities for small-to-medium graphs.
"""
from __future__ import annotations

import logging
from collections import defaultdict
from typing import Any, Dict, Iterable, List, Optional, Tuple

import networkx as nx

from .entity_extractor import ChunkExtraction

logger = logging.getLogger(__name__)


def _canonical(name: str) -> str:
    return name.strip().lower()


def build_graph(extractions: Iterable[ChunkExtraction]) -> nx.DiGraph:
    """Merge extractions into a single directed graph."""
    g = nx.DiGraph()

    # ── Nodes: merge per canonical name ─────────────────────────────────
    for ex in extractions:
        for e in ex.entities:
            key = _canonical(e.name)
            if key in g.nodes:
                node = g.nodes[key]
                if e.description and e.description not in node["descriptions"]:
                    node["descriptions"].append(e.description)
                if e.chunk_id and e.chunk_id not in node["chunk_ids"]:
                    node["chunk_ids"].append(e.chunk_id)
                if e.paper_title and e.paper_title not in node["paper_titles"]:
                    node["paper_titles"].append(e.paper_title)
                # Prefer the most-specific type (avoid 'concept' when another type exists)
                if node["type"] == "concept" and e.type != "concept":
                    node["type"] = e.type
            else:
                g.add_node(
                    key,
                    name=e.name,
                    type=e.type,
                    descriptions=[e.description] if e.description else [],
                    chunk_ids=[e.chunk_id] if e.chunk_id else [],
                    paper_titles=[e.paper_title] if e.paper_title else [],
                )

    # ── Edges: accumulate strengths per (source, target, type) ──────────
    for ex in extractions:
        for r in ex.relationships:
            s = _canonical(r.source)
            t = _canonical(r.target)
            if s not in g.nodes or t not in g.nodes:
                continue
            key = (s, t, r.type)
            if g.has_edge(s, t):
                # Merge multi-type rels into one edge, keep description of the strongest.
                edge = g[s][t]
                edge["weight"] += r.strength
                if r.strength > edge.get("max_strength", 0):
                    edge["max_strength"] = r.strength
                    edge["relationship_type"] = r.type
                    if r.description:
                        edge["description"] = r.description
                if r.chunk_id not in edge["chunk_ids"]:
                    edge["chunk_ids"].append(r.chunk_id)
                if r.paper_title and r.paper_title not in edge["paper_titles"]:
                    edge["paper_titles"].append(r.paper_title)
                if r.type not in edge["types"]:
                    edge["types"].append(r.type)
            else:
                g.add_edge(
                    s, t,
                    relationship_type=r.type,
                    types=[r.type],
                    description=r.description,
                    weight=r.strength,
                    max_strength=r.strength,
                    chunk_ids=[r.chunk_id] if r.chunk_id else [],
                    paper_titles=[r.paper_title] if r.paper_title else [],
                )

    # Compute degree for convenience
    for n in g.nodes:
        g.nodes[n]["degree"] = g.degree(n)

    logger.info("Graph built: %d nodes, %d edges.", g.number_of_nodes(), g.number_of_edges())
    return g


# ── Community detection ─────────────────────────────────────────────────

def _detect_leiden(g_undirected: nx.Graph) -> Optional[Dict[str, int]]:
    try:
        from graspologic.partition import hierarchical_leiden  # type: ignore
    except Exception:
        return None
    try:
        clusters = hierarchical_leiden(
            g_undirected,
            max_cluster_size=30,
            random_seed=42,
        )
        # hierarchical_leiden returns a list of PartitionResult items; take top-level only.
        top_level = {}
        for item in clusters:
            # item attributes: node, cluster, level, parent_cluster
            if item.level == 0:
                top_level[item.node] = int(item.cluster)
        return top_level or None
    except Exception as exc:
        logger.warning("Leiden failed, falling back to greedy modularity: %s", exc)
        return None


def _detect_greedy(g_undirected: nx.Graph) -> Dict[str, int]:
    # greedy_modularity_communities requires a connected graph; run per-component.
    from networkx.algorithms.community import greedy_modularity_communities
    assignment: Dict[str, int] = {}
    cluster_idx = 0
    for component in nx.connected_components(g_undirected):
        sub = g_undirected.subgraph(component)
        if sub.number_of_nodes() <= 3:
            # Tiny components become single-community.
            for n in sub.nodes:
                assignment[n] = cluster_idx
            cluster_idx += 1
            continue
        try:
            communities = list(greedy_modularity_communities(sub, weight="weight"))
        except Exception:
            communities = [set(sub.nodes)]
        for comm in communities:
            for n in comm:
                assignment[n] = cluster_idx
            cluster_idx += 1
    return assignment


def detect_communities(g: nx.DiGraph) -> Dict[str, int]:
    """
    Assign each node to a community ID. Returns a mapping ``node -> community_id``.

    Works on the undirected projection of the graph.
    """
    undirected = g.to_undirected()
    # Remove isolates first (they can't belong to meaningful communities)
    undirected.remove_nodes_from(list(nx.isolates(undirected)))
    if undirected.number_of_nodes() == 0:
        return {}

    assignment = _detect_leiden(undirected)
    if assignment is None:
        assignment = _detect_greedy(undirected)

    # Write community_id back onto the original graph nodes.
    for node, cid in assignment.items():
        if node in g.nodes:
            g.nodes[node]["community_id"] = cid
    # Isolated nodes get community_id = -1
    for node in g.nodes:
        if "community_id" not in g.nodes[node]:
            g.nodes[node]["community_id"] = -1

    comm_count = len(set(assignment.values()))
    logger.info("Detected %d communities over %d nodes.", comm_count, len(assignment))
    return assignment


def community_members(g: nx.DiGraph) -> Dict[int, List[str]]:
    """Return ``community_id -> [node_keys]`` (excluding isolates with id -1)."""
    members: Dict[int, List[str]] = defaultdict(list)
    for node, attrs in g.nodes(data=True):
        cid = attrs.get("community_id", -1)
        if cid < 0:
            continue
        members[cid].append(node)
    return dict(members)


def collect_community_evidence(
    g: nx.DiGraph,
    node_keys: List[str],
    max_relationships: int = 40,
) -> Dict[str, Any]:
    """Gather raw evidence for a single community to feed the summarizer."""
    entity_blocks: List[Dict[str, Any]] = []
    paper_set = set()
    for key in node_keys:
        attrs = g.nodes[key]
        entity_blocks.append({
            "name": attrs.get("name", key),
            "type": attrs.get("type", "concept"),
            "descriptions": attrs.get("descriptions", [])[:4],
            "paper_titles": attrs.get("paper_titles", [])[:6],
        })
        for p in attrs.get("paper_titles", []):
            paper_set.add(p)

    rels: List[Dict[str, Any]] = []
    seen = set()
    # Prefer within-community edges; then incident edges for cross-community context.
    node_set = set(node_keys)
    # Within-community
    for u in node_keys:
        for v, data in g[u].items():
            if v not in node_set:
                continue
            key = (u, v, data.get("relationship_type"))
            if key in seen:
                continue
            seen.add(key)
            rels.append({
                "source": g.nodes[u].get("name", u),
                "target": g.nodes[v].get("name", v),
                "type": data.get("relationship_type", "mentions"),
                "description": data.get("description", ""),
                "weight": data.get("weight", 1),
            })
    rels.sort(key=lambda r: -r["weight"])
    rels = rels[:max_relationships]

    return {
        "entities": entity_blocks,
        "relationships": rels,
        "paper_titles": sorted(paper_set),
        "size": len(node_keys),
    }

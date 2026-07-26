"""LumiNode RAG - Embedding model + vector store.

Wraps sentence-transformers (embeddings) and Chroma (local persistent
vector store) behind a tiny interface - the rest of the pipeline never
touches either library directly. Chroma metadata values must be scalar, so
the chunker's list/optional fields (scope, topic_tags, effective_date,
supersedes_topic) are serialized to "|"-joined strings / "" sentinels on the
way in and parsed back on the way out - RetrievedChunk always carries the
real list/None types.
"""

import os;
import chromadb;
import from sentence_transformers { SentenceTransformer }
import from rag.chunker { Chunk, chunk_all_knowledge }

glob KNOWLEDGE_DIR: str = "knowledge";
glob STORE_DIR: str = ".rag_store";
glob COLLECTION_NAME: str = "lumi_knowledge";
glob EMBED_MODEL_NAME: str = "all-MiniLM-L6-v2";

glob _model: SentenceTransformer | None = None;
glob _client: any = None;

def _get_model() -> SentenceTransformer {
    if _model is None {
        _model = SentenceTransformer(EMBED_MODEL_NAME);
    }
    return _model;
}

def _get_client() -> any {
    if _client is None {
        os.makedirs(STORE_DIR, exist_ok=True);
        _client = chromadb.PersistentClient(path=STORE_DIR);
    }
    return _client;
}

def _get_collection() -> any {
    client = _get_client();
    return client.get_or_create_collection(
        name=COLLECTION_NAME,
        metadata={"hnsw:space": "cosine"}
    );
}

def _join(values: list[str]) -> str {
    return "|".join(values);
}

def _split(value: str) -> list[str] {
    if not value {
        return [];
    }
    return value.split("|");
}

"""(Re)builds the index from every .md file in knowledge/."""
def ingest_knowledge_base() -> int {
    chunks = chunk_all_knowledge(KNOWLEDGE_DIR);
    if len(chunks) == 0 {
        return 0;
    }

    model = _get_model();
    texts = [c.text for c in chunks];
    embeddings = model.encode(texts).tolist();

    metadatas: list[dict] = [];
    for c in chunks {
        metadatas.append({
            "source_doc": c.source_doc,
            "heading": c.heading,
            "section_path": c.section_path,
            "level": c.level,
            "chunk_type": c.chunk_type,
            "scope": _join(c.scope),
            "topic_tags": _join(c.topic_tags),
            "effective_date": c.effective_date if c.effective_date else "",
            "supersedes_topic": c.supersedes_topic if c.supersedes_topic else ""
        });
    }

    collection = _get_collection();
    collection.upsert(
        ids=[c.chunk_id for c in chunks],
        documents=texts,
        embeddings=embeddings,
        metadatas=metadatas
    );
    return len(chunks);
}

"""Wipes and rebuilds the index from scratch - use after a chunking/metadata
schema change, since upsert alone won't drop stale-schema entries for
sections that no longer exist under the new heading split."""
def reindex_knowledge_base() -> int {
    client = _get_client();
    try {
        client.delete_collection(COLLECTION_NAME);
    } except Exception {}
    return ingest_knowledge_base();
}

obj RetrievedChunk {
    has chunk_id: str,
        source_doc: str,
        heading: str,
        section_path: str,
        text: str,
        similarity: float,
        chunk_type: str = "content",
        scope: list[str] = [],
        topic_tags: list[str] = [],
        effective_date: str | None = None,
        supersedes_topic: str | None = None;
}

def _to_retrieved_chunk(cid: str, doc: str, meta: dict, similarity: float) -> RetrievedChunk {
    eff = meta.get("effective_date", "");
    sup = meta.get("supersedes_topic", "");
    heading_val: str = meta.get("heading", "");
    section_path_val: str = meta.get("section_path", "");
    if not section_path_val {
        section_path_val = heading_val;
    }
    return RetrievedChunk(
        chunk_id=cid,
        source_doc=meta.get("source_doc", ""),
        heading=heading_val,
        section_path=section_path_val,
        text=doc,
        similarity=similarity,
        chunk_type=meta.get("chunk_type", "content"),
        scope=_split(meta.get("scope", "")),
        topic_tags=_split(meta.get("topic_tags", "")),
        effective_date=eff if eff else None,
        supersedes_topic=sup if sup else None
    );
}

"""Semantic search over the knowledge base. `source_files`, when given, is a
hard filter (only chunks from those files are eligible at all) - this is the
scope-routing gate, applied at the Chroma query level so a scoped surface
never even sees candidates outside its allowed files."""
def semantic_search(query: str, top_k: int, source_files: list[str] | None = None) -> list[RetrievedChunk] {
    model = _get_model();
    collection = _get_collection();
    if collection.count() == 0 {
        ingest_knowledge_base();
    }
    if collection.count() == 0 {
        return [];
    }

    query_embedding = model.encode([query]).tolist();
    where_filter = {"source_doc": {"$in": source_files}} if source_files else None;
    if where_filter is not None {
        results = collection.query(query_embeddings=query_embedding, n_results=top_k, where=where_filter);
    } else {
        results = collection.query(query_embeddings=query_embedding, n_results=top_k);
    }

    out: list[RetrievedChunk] = [];
    ids = results["ids"][0];
    docs = results["documents"][0];
    metas = results["metadatas"][0];
    dists = results["distances"][0];

    i = 0;
    for cid in ids {
        # Cosine space (configured on the collection): distance = 1 - cosine_similarity.
        similarity = 1.0 - dists[i];
        out.append(_to_retrieved_chunk(cid, docs[i], metas[i], similarity));
        i = i + 1;
    }
    return out;
}

"""Embeds arbitrary text with the same model used for indexing - used by the
rerank step (rag/rerank.jac) to measure chunk-to-chunk similarity for
near-duplicate suppression, not just query-to-chunk similarity."""
def embed_texts(texts: list[str]) -> any {
    if len(texts) == 0 {
        return [];
    }
    model = _get_model();
    return model.encode(texts).tolist();
}

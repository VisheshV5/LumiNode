"""LumiNode RAG - Dedup + precedence rerank.

Two deliberate post-retrieval steps, run on every result regardless of scope:

1. Near-duplicate suppression - the chat knowledge file deliberately restates
   condensed versions of the other three files' content, so a naive top-k over
   all four files tends to surface both the detailed original and the
   condensed restatement of the same fact. Measured with real embeddings
   (the same model used for indexing), not a text-overlap heuristic.

2. Dated-fact precedence - two 2025-2026 facts (medical-debt reporting status,
   which mortgage scoring models are live) are newer and more specific than
   anything the original factors doc says on the same topics. When a newer
   dated chunk and an older/undated chunk share a topic, the older one is
   dropped from what's sent to the model rather than left for similarity
   score to referee.

Guardrail chunks are exempt from both - they're duplicated on purpose, once
per source file, specifically so a query landing on any single file still
gets its guardrails; suppressing the "duplicate" would defeat that.
"""

import from rag.store { RetrievedChunk, embed_texts }

glob DEDUP_SIMILARITY_THRESHOLD: float = 0.85;

# Lower rank wins a near-duplicate tie. The chat file condenses the other
# three on purpose, so it's always the side dropped when both appear.
glob SOURCE_PRECEDENCE_RANK: dict[str, int] = {
    "discovered-actions-agent-knowledge-base.md": 0,
    "recommended-90-day-agent-knowledge-base.md": 0,
    "credit_score_factors_knowledge_base.md": 0,
    "chat-agent-knowledge-base.md": 1
};

obj SuppressedChunk {
    has suppressed_chunk_id: str,
        suppressed_source_doc: str,
        suppressed_heading: str,
        kept_chunk_id: str,
        kept_source_doc: str,
        kept_heading: str,
        reason: str;
}

def _cosine(a: list[float], b: list[float]) -> float {
    dot = 0.0;
    norm_a = 0.0;
    norm_b = 0.0;
    for i in range(len(a)) {
        dot = dot + (a[i] * b[i]);
        norm_a = norm_a + (a[i] * a[i]);
        norm_b = norm_b + (b[i] * b[i]);
    }
    if norm_a == 0.0 or norm_b == 0.0 {
        return 0.0;
    }
    return dot / ((norm_a ** 0.5) * (norm_b ** 0.5));
}

"""Suppresses near-duplicate chunks within a single retrieved set."""
def suppress_near_duplicates(chunks: list[RetrievedChunk]) -> tuple[list[RetrievedChunk], list[SuppressedChunk]] {
    dedup_candidates = [c for c in chunks if c.chunk_type != "guardrail"];
    if len(dedup_candidates) <= 1 {
        return (chunks, []);
    }

    texts = [c.text for c in dedup_candidates];
    vectors = embed_texts(texts);

    suppressed_ids: dict[str, bool] = {};
    suppressed_log: list[SuppressedChunk] = [];

    for i in range(len(dedup_candidates)) {
        if suppressed_ids.get(dedup_candidates[i].chunk_id, False) {
            continue;
        }
        for j in range(i + 1, len(dedup_candidates)) {
            if suppressed_ids.get(dedup_candidates[j].chunk_id, False) {
                continue;
            }
            sim = _cosine(vectors[i], vectors[j]);
            if sim >= DEDUP_SIMILARITY_THRESHOLD {
                a = dedup_candidates[i];
                b = dedup_candidates[j];
                rank_a = SOURCE_PRECEDENCE_RANK.get(a.source_doc, 0);
                rank_b = SOURCE_PRECEDENCE_RANK.get(b.source_doc, 0);
                keep_a = (rank_a < rank_b) or (rank_a == rank_b and a.similarity >= b.similarity);
                drop = b if keep_a else a;
                keep = a if keep_a else b;
                suppressed_ids[drop.chunk_id] = True;
                suppressed_log.append(SuppressedChunk(
                    suppressed_chunk_id=drop.chunk_id,
                    suppressed_source_doc=drop.source_doc,
                    suppressed_heading=drop.heading,
                    kept_chunk_id=keep.chunk_id,
                    kept_source_doc=keep.source_doc,
                    kept_heading=keep.heading,
                    reason=f"near-duplicate (cosine={sim:.3f}) of {keep.source_doc} § {keep.heading}"
                ));
            }
        }
    }

    survivors = [c for c in chunks if not suppressed_ids.get(c.chunk_id, False)];
    return (survivors, suppressed_log);
}

"""Resolves dated-fact conflicts: when a chunk's topic_tags overlap a topic
that some OTHER chunk in this set has already staked out with a supersedes_topic
+ effective_date, only the most-recent dated chunk(s) for that topic survive."""
def apply_precedence(chunks: list[RetrievedChunk]) -> tuple[list[RetrievedChunk], list[SuppressedChunk]] {
    newest_by_topic: dict[str, str] = {};
    newest_chunk_by_topic: dict[str, RetrievedChunk] = {};
    for c in chunks {
        topic = c.supersedes_topic;
        date = c.effective_date;
        if topic and date {
            current_best = newest_by_topic.get(topic, "");
            if date > current_best {
                newest_by_topic[topic] = date;
                newest_chunk_by_topic[topic] = c;
            }
        }
    }

    if len(newest_by_topic) == 0 {
        return (chunks, []);
    }

    survivors: list[RetrievedChunk] = [];
    suppressed_log: list[SuppressedChunk] = [];

    for c in chunks {
        conflict_topic = "";
        for tag in c.topic_tags {
            if tag in newest_by_topic {
                conflict_topic = tag;
                break;
            }
        }
        is_newest = bool(c.supersedes_topic) and c.effective_date == newest_by_topic.get(c.supersedes_topic if c.supersedes_topic else "", "");
        if conflict_topic and not is_newest {
            winner = newest_chunk_by_topic[conflict_topic];
            suppressed_log.append(SuppressedChunk(
                suppressed_chunk_id=c.chunk_id,
                suppressed_source_doc=c.source_doc,
                suppressed_heading=c.heading,
                kept_chunk_id=winner.chunk_id,
                kept_source_doc=winner.source_doc,
                kept_heading=winner.heading,
                reason=f"superseded by a {newest_by_topic[conflict_topic]} statement on {conflict_topic}"
            ));
        } else {
            survivors.append(c);
        }
    }

    return (survivors, suppressed_log);
}

"""Runs precedence then dedup - precedence resolves recency conflicts first,
dedup then catches any remaining redundant phrasing among the survivors."""
def rerank(chunks: list[RetrievedChunk]) -> tuple[list[RetrievedChunk], list[SuppressedChunk]] {
    if len(chunks) <= 1 {
        return (chunks, []);
    }
    (after_precedence, precedence_log) = apply_precedence(chunks);
    (after_dedup, dedup_log) = suppress_near_duplicates(after_precedence);
    return (after_dedup, precedence_log + dedup_log);
}

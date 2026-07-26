"""LumiNode RAG - Retrieval agent.

The control flow (whether to retrieve, whether the chunks are good enough,
whether to reformulate and retry, which files are even eligible, what to
suppress) is real Jac code. The LLM is only used for the two sub-steps that
genuinely need judgment: rewriting a query, and writing the final answer
grounded in retrieved text. Model is whatever's configured project-wide in
jac.toml ([byllm.model], currently Gemini) - no per-file override here.
"""

import from rag.store { semantic_search, RetrievedChunk }
import from rag.rerank { rerank, SuppressedChunk }

glob TOP_K: int = 4;
glob SUFFICIENCY_THRESHOLD: float = 0.35;

# Section 3 routing: each scoped surface hard-filters to its own knowledge
# file(s) plus the shared factors doc. "chat" (and no scope at all, for
# backward-compatible unscoped callers like the Score Factors agent) sees
# every file - empty list means "no source_doc filter" to semantic_search.
glob SCOPE_SOURCE_FILES: dict[str, list[str]] = {
    "discovered_actions": ["discovered-actions-agent-knowledge-base.md", "credit_score_factors_knowledge_base.md"],
    "ninety_day": ["recommended-90-day-agent-knowledge-base.md", "credit_score_factors_knowledge_base.md"],
    "chat": []
};

glob _GREETING_PHRASES: list[str] = [
    "hi", "hello", "hey", "yo", "sup", "thanks", "thank you", "ok", "okay",
    "bye", "goodbye", "who are you", "what can you do", "what are you"
];

def should_retrieve(query: str) -> bool {
    q = query.strip().lower();
    if len(q) == 0 {
        return False;
    }
    if q in _GREETING_PHRASES {
        return False;
    }
    word_count = len(q.split());
    if word_count <= 3 {
        for phrase in _GREETING_PHRASES {
            if phrase in q {
                return False;
            }
        }
    }
    return True;
}

def is_sufficient(chunks: list[RetrievedChunk]) -> bool {
    if len(chunks) == 0 {
        return False;
    }
    return chunks[0].similarity >= SUFFICIENCY_THRESHOLD;
}

"""Resolves an agent_scope string to its hard source_doc filter. None/"" and
unrecognized scopes fall back to unscoped (full four-file access) rather
than failing - only "discovered_actions" and "ninety_day" are actually
restrictive."""
def _source_files_for_scope(agent_scope: str | None) -> list[str] | None {
    if not agent_scope {
        return None;
    }
    files = SCOPE_SOURCE_FILES.get(agent_scope, []);
    if len(files) == 0 {
        return None;
    }
    return files;
}

def _is_hard_scoped(agent_scope: str | None) -> bool {
    return agent_scope == "discovered_actions" or agent_scope == "ninety_day";
}

def reformulate_query(original_query: str) -> str by llm();
sem reformulate_query = """
Rewrite the user's question as a focused search query against a credit-scoring
knowledge base (FICO/VantageScore factors, inquiries, derogatory marks,
discovered actions, 90-day sequencing, money-judgment questions).
Use precise domain terminology. Return ONLY the rewritten query, nothing else.
""";
sem reformulate_query.original_query = "The user's original question.";

def answer_from_chunks(question: str, chunks: list[RetrievedChunk]) -> str by llm();
sem answer_from_chunks = """
Answer the user's question using ONLY the provided knowledge-base excerpts.
Do not use outside knowledge. If the excerpts do not actually contain the
answer, say plainly that the knowledge base doesn't cover it. Be concise and
mention which factor/section the answer comes from. If an excerpt's chunk_type
is "guardrail", treat it as a hard constraint on how you may answer (e.g.
never state a specific success percentage, never invent a causal mechanism,
never promise a date), not just background information.
""";
sem answer_from_chunks.question = "The user's question.";
sem answer_from_chunks.chunks = "Retrieved knowledge-base excerpts, most relevant first.";

def _fallback_reformulate(original_query: str) -> str {
    return original_query;
}

def _fallback_answer(chunks: list[RetrievedChunk]) -> str {
    if len(chunks) == 0 {
        return "I don't have reliable information on that in the knowledge base yet.";
    }
    top = chunks[0];
    return (
        f"From \"{top.heading}\" ({top.source_doc}): {top.text} "
        + "(LLM unavailable - set GOOGLE_API_KEY for a synthesized answer.)"
    );
}

obj RetrievalAttempt {
    has query_used: str,
        chunks: list[RetrievedChunk],
        sufficient: bool;
}

obj RagResult {
    has original_query: str,
        agent_scope: str = "",
        retrieval_skipped: bool = False,
        skip_reason: str = "",
        attempts: list[RetrievalAttempt] = [],
        suppressed: list[SuppressedChunk] = [],
        answer: str = "",
        answered_from_knowledge: bool = False;
}

"""Runs one semantic_search + rerank pass, scoped by agent_scope."""
def _search_and_rerank(query: str, agent_scope: str | None) -> tuple[list[RetrievedChunk], list[SuppressedChunk]] {
    source_files = _source_files_for_scope(agent_scope);
    raw_chunks = semantic_search(query, TOP_K, source_files=source_files);
    (reranked, suppressed) = rerank(raw_chunks);
    return (reranked, suppressed);
}

"""Retrieval-augmented answer, routed by which surface is calling.

agent_scope: "discovered_actions" | "ninety_day" | "chat" | None. The first
two are hard-filtered to their own knowledge file plus the shared factors
doc (section 3); "chat" and None see all four files. A hard-scoped surface
that can't find a sufficient answer within its own files says so explicitly
rather than silently falling back to the unscoped corpus - a scoped surface
reaching outside its scope would defeat the point of scoping it."""
def run_rag_agent(query: str, agent_scope: str | None = None) -> RagResult {
    if not should_retrieve(query) {
        return RagResult(
            original_query=query,
            agent_scope=agent_scope if agent_scope else "",
            retrieval_skipped=True,
            skip_reason="Looks like a greeting or non-knowledge input - retrieval skipped.",
            answer="Hey! Ask me anything about how credit scores work - payment history, utilization, inquiries, derogatory marks, FICO vs VantageScore."
        );
    }

    attempts: list[RetrievalAttempt] = [];
    all_suppressed: list[SuppressedChunk] = [];

    (chunks, suppressed) = _search_and_rerank(query, agent_scope);
    all_suppressed = all_suppressed + suppressed;
    sufficient = is_sufficient(chunks);
    attempts.append(RetrievalAttempt(query_used=query, chunks=chunks, sufficient=sufficient));

    if not sufficient {
        try {
            reformulated = reformulate_query(query);
        } except Exception {
            reformulated = _fallback_reformulate(query);
        }

        if reformulated.strip() and reformulated.strip().lower() != query.strip().lower() {
            (chunks2, suppressed2) = _search_and_rerank(reformulated, agent_scope);
            all_suppressed = all_suppressed + suppressed2;
            sufficient2 = is_sufficient(chunks2);
            attempts.append(RetrievalAttempt(query_used=reformulated, chunks=chunks2, sufficient=sufficient2));

            better = len(chunks2) > 0 and (len(chunks) == 0 or chunks2[0].similarity > chunks[0].similarity);
            if sufficient2 or better {
                chunks = chunks2;
                sufficient = sufficient2;
            }
        }
    }

    if not sufficient {
        if _is_hard_scoped(agent_scope) {
            scope_label = agent_scope if agent_scope else "this";
            return RagResult(
                original_query=query,
                agent_scope=scope_label,
                attempts=attempts,
                suppressed=all_suppressed,
                answer=f"I don't have that in my {scope_label} knowledge base - try asking the general chat assistant instead."
            );
        }
        return RagResult(
            original_query=query,
            agent_scope=agent_scope if agent_scope else "",
            attempts=attempts,
            suppressed=all_suppressed,
            answer="I don't have reliable information on that in the knowledge base yet - I don't want to guess."
        );
    }

    try {
        answer = answer_from_chunks(query, chunks);
    } except Exception {
        answer = _fallback_answer(chunks);
    }

    return RagResult(
        original_query=query,
        agent_scope=agent_scope if agent_scope else "",
        attempts=attempts,
        suppressed=all_suppressed,
        answer=answer,
        answered_from_knowledge=True
    );
}

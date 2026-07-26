"""LumiNode RAG - CLI for evaluating retrieval quality.

Run with: jac run rag/cli.jac
"""

import from rag.agent { run_rag_agent, RagResult, RetrievalAttempt }
import from rag.store { ingest_knowledge_base, reindex_knowledge_base, RetrievedChunk }
import from rag.rerank { SuppressedChunk }

def _print_chunk(c: RetrievedChunk, i: int) {
    tags = ", ".join(c.topic_tags) if len(c.topic_tags) > 0 else "-";
    scope = ", ".join(c.scope) if len(c.scope) > 0 else "-";
    date_part = f"  eff={c.effective_date}" if c.effective_date else "";
    print(f"    [{i}] {c.source_doc} § {c.section_path}  (sim={c.similarity:.3f}, type={c.chunk_type}, scope=[{scope}], tags=[{tags}]{date_part})");
    preview = c.text if len(c.text) <= 160 else c.text[:160] + "...";
    print(f"        {preview}");
}

def _print_suppressed(s: SuppressedChunk, i: int) {
    print(f"    ~[{i}] SUPPRESSED: {s.suppressed_source_doc} § {s.suppressed_heading}");
    print(f"          -> kept {s.kept_source_doc} § {s.kept_heading}  ({s.reason})");
}

def _print_result(result: RagResult) {
    print("");
    print("=" * 70);
    print(f"Query: {result.original_query}   [scope={result.agent_scope if result.agent_scope else 'unscoped/chat'}]");
    if result.retrieval_skipped {
        print(f"Retrieval: SKIPPED - {result.skip_reason}");
    } else {
        attempt_num = 1;
        for attempt in result.attempts {
            label = "sufficient" if attempt.sufficient else "insufficient";
            print(f"Retrieval attempt {attempt_num} (query=\"{attempt.query_used}\") - {label}");
            idx = 0;
            for c in attempt.chunks {
                _print_chunk(c, idx);
                idx = idx + 1;
            }
            attempt_num = attempt_num + 1;
        }
    }
    if len(result.suppressed) > 0 {
        print(f"Suppressed by rerank ({len(result.suppressed)}):");
        idx = 0;
        for s in result.suppressed {
            _print_suppressed(s, idx);
            idx = idx + 1;
        }
    }
    print(f"Answered from knowledge base: {result.answered_from_knowledge}");
    print("-" * 70);
    print(f"Answer: {result.answer}");
    print("=" * 70);
}

with entry:__main__ {
    print("LumiNode RAG CLI - re-indexing knowledge base (fresh schema)...");
    count = reindex_knowledge_base();
    print(f"Indexed {count} chunks.");
    print("Type a question ('exit' to quit). Prefix with 'da:' / '90:' / 'chat:' to force a scope.");
    while True {
        raw = input("\n> ");
        query = raw.strip();
        if query.lower() in ["exit", "quit"] {
            break;
        }
        if not query {
            continue;
        }
        agent_scope: str | None = None;
        if query.lower().startswith("da:") {
            agent_scope = "discovered_actions";
            query = query[3:].strip();
        } elif query.lower().startswith("90:") {
            agent_scope = "ninety_day";
            query = query[3:].strip();
        } elif query.lower().startswith("chat:") {
            agent_scope = "chat";
            query = query[5:].strip();
        }
        result = run_rag_agent(query, agent_scope=agent_scope);
        _print_result(result);
    }
}

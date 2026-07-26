"""LumiNode RAG - Smoke test / regression check.

Runs the 9 test queries from the RAG knowledge-base extension spec across
all three scoped surfaces, logs which chunks were retrieved (and any
suppressed as duplicates or superseded), and prints the answer - so this
file doubles as a manual regression check after any chunking/retrieval
change. Not a pass/fail assertion suite (answers depend on whether an LLM
key is configured) - it's a visibility tool: read the retrieved chunks per
query and confirm they match the "expect" comment.

Run with: jac run rag/smoke_test.jac
"""

import from rag.agent { run_rag_agent, RagResult }
import from rag.store { reindex_knowledge_base, RetrievedChunk }

obj TestCase {
    has scope: str,
        query: str,
        expect: str;
}

glob TEST_CASES: list[TestCase] = [
    TestCase(
        scope="discovered_actions",
        query="Why does paying down my store card by $430 give more points than paying $1216 on my Capital One card?",
        expect="discovered-actions KB - utilization mechanics + threshold bands"
    ),
    TestCase(
        scope="discovered_actions",
        query="Is it safe to request a credit limit increase on Discover?",
        expect="discovered-actions KB §1.2 (+ maybe factors KB on new-credit weight)"
    ),
    TestCase(
        scope="discovered_actions",
        query="How reliable are goodwill letters?",
        expect="discovered-actions KB §1.3; answer should NOT state a specific success percentage"
    ),
    TestCase(
        scope="ninety_day",
        query="Why does my plan say wait 35 days for my score to update?",
        expect="90-day KB §1/§2 - reporting cycle + timing table"
    ),
    TestCase(
        scope="ninety_day",
        query="Can I use a rapid rescore to speed this up?",
        expect="90-day KB rapid-rescore row + guardrail; should clarify mortgage-underwriting-only"
    ),
    TestCase(
        scope="ninety_day",
        query="Will my mortgage lender use the new VantageScore model in my plan?",
        expect="90-day KB §4.2; should NOT assume yes or no"
    ),
    TestCase(
        scope="chat",
        query="Can I afford a $500 TV right now?",
        expect="chat KB §1.2 (+ possibly utilization mechanics); should distinguish cash vs. card-carried"
    ),
    TestCase(
        scope="chat",
        query="What should I pay off first, my card or my personal loan?",
        expect="chat KB §1.1; should name which lens (cost vs. score) it's using"
    ),
    TestCase(
        scope="chat",
        query="Does my medical debt still hurt my score?",
        expect="chat KB §5.1 (vacated-rule chunk) should win over any older factors-doc statement - precedence test"
    )
];

def _print_chunk(c: RetrievedChunk, i: int) {
    tags = ", ".join(c.topic_tags) if len(c.topic_tags) > 0 else "-";
    date_part = f"  eff={c.effective_date}" if c.effective_date else "";
    print(f"      [{i}] {c.source_doc} § {c.section_path}  (sim={c.similarity:.3f}, type={c.chunk_type}, tags=[{tags}]{date_part})");
}

def _run_case(tc: TestCase, idx: int) {
    print("");
    print("#" * 78);
    print(f"[{idx}] scope={tc.scope}");
    print(f"    query:  {tc.query}");
    print(f"    expect: {tc.expect}");
    print("-" * 78);

    result: RagResult = run_rag_agent(tc.query, agent_scope=tc.scope);

    attempt_num = 1;
    for attempt in result.attempts {
        label = "sufficient" if attempt.sufficient else "insufficient";
        print(f"    attempt {attempt_num} (\"{attempt.query_used}\") - {label}, {len(attempt.chunks)} chunk(s):");
        j = 0;
        for c in attempt.chunks {
            _print_chunk(c, j);
            j = j + 1;
        }
        attempt_num = attempt_num + 1;
    }

    if len(result.suppressed) > 0 {
        print(f"    suppressed ({len(result.suppressed)}):");
        for s in result.suppressed {
            print(f"      - {s.suppressed_source_doc} § {s.suppressed_heading} -> kept {s.kept_source_doc} § {s.kept_heading} ({s.reason})");
        }
    } else {
        print("    suppressed: none");
    }

    print(f"    answered_from_knowledge: {result.answered_from_knowledge}");
    print(f"    ANSWER: {result.answer}");
}

with entry:__main__ {
    print("Re-indexing knowledge base (fresh schema, all 4 files)...");
    count = reindex_knowledge_base();
    print(f"Indexed {count} chunks across the knowledge base.");

    idx = 1;
    for tc in TEST_CASES {
        _run_case(tc, idx);
        idx = idx + 1;
    }

    print("");
    print("#" * 78);
    print(f"Done - {len(TEST_CASES)} smoke-test queries run across discovered_actions / ninety_day / chat scopes.");
    print("Review each query's retrieved chunks/suppressions against its 'expect' line above.");
}

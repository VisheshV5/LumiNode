"""LumiNode RAG - Markdown chunker.

Splits a markdown knowledge file into one chunk per `##`/`###` heading, so
dropping a new topic file into knowledge/ needs zero pipeline changes. Also
tags each chunk with the metadata the multi-domain retrieval layer needs:
which agent surfaces it belongs to (scope), what kind of chunk it is
(content/guardrail/sourcing_note/table), free-form topic tags for dedup and
precedence, and an effective_date/supersedes_topic pair for chunks that state
a dated fact newer than anything else in the corpus.
"""

import os;

obj Chunk {
    has chunk_id: str,
        source_doc: str,
        heading: str,
        section_path: str,
        level: int,
        text: str,
        chunk_type: str = "content",
        scope: list[str] = [],
        topic_tags: list[str] = [],
        effective_date: str | None = None,
        supersedes_topic: str | None = None;
}

# Which agent surface(s) each file belongs to by default. Empty list = no
# standing scope of its own - the chat surface's full-corpus access is
# implicit/unscoped, not a per-chunk tag (see rag/agent.jac routing).
glob SCOPE_BY_FILE: dict[str, list[str]] = {
    "credit_score_factors_knowledge_base.md": ["discovered_actions", "ninety_day"],
    "discovered-actions-agent-knowledge-base.md": ["discovered_actions"],
    "recommended-90-day-agent-knowledge-base.md": ["ninety_day"],
    "chat-agent-knowledge-base.md": []
};

# Free-form topic tags, detected by keyword. Used for cross-file dedup
# (same topic + near-duplicate text) and precedence (same topic + dated fact).
glob TOPIC_KEYWORDS: dict[str, list[str]] = {
    "utilization": ["utilization"],
    "cli": ["credit limit increase", "cli approval", "cli)", "cli:", "request a cli", "a cli "],
    "goodwill": ["goodwill"],
    "dispute": ["dispute", "fcra"],
    "authorized_user": ["authorized user"],
    "collections": ["collection"],
    "alternative_data": ["experian boost", "ultrafico", "alternative-data", "alternative data"],
    "credit_mix": ["credit mix"],
    "inquiries": ["inquiry", "inquiries"],
    "account_age": ["account age", "length of credit history"],
    "reporting_cycle": ["statement clos", "reporting cycle", "furnisher"],
    "sequencing": ["sequenc", "90-day plan", "day 0-14", "day 30-60", "day 60-90"],
    "medical_debt_reporting": ["medical debt", "medical collection"],
    # Deliberately NOT bare "mortgage" - that word alone appears in many
    # unrelated chunks (rapid-rescore eligibility, dispute freezing
    # underwriting, mortgage lender pull types). This tag means specifically
    # "which scoring model a mortgage uses," so it requires the model names.
    "mortgage_scoring_models": ["vantagescore 4.0", "fico 10t"],
    "affordability": ["afford"],
    "debt_payoff_method": ["avalanche", "snowball"],
    "target_score": ["target score"],
    "rapid_rescore": ["rapid rescore"],
    "azeo": ["azeo"]
};

def _detect_chunk_type(heading: str, body: str) -> str {
    h = heading.lower();
    if "guardrail" in h {
        return "guardrail";
    }
    if "sourcing note" in h {
        return "sourcing_note";
    }
    if "|---" in body or "| ---" in body or "|-----" in body {
        return "table";
    }
    return "content";
}

def _detect_topic_tags(full_text: str) -> list[str] {
    t = full_text.lower();
    tags: list[str] = [];
    for tag in TOPIC_KEYWORDS.keys() {
        keywords = TOPIC_KEYWORDS[tag];
        for kw in keywords {
            if kw in t {
                tags.append(tag);
                break;
            }
        }
    }
    return tags;
}

"""Detects a chunk stating one of the two known 2025-2026 dated facts that
supersede older, undated statements on the same topic elsewhere in the
corpus. Matched on the actual claim text, not just the heading, so an inline
mention (e.g. the collections action's regulatory aside) is caught too."""
def _detect_dated_fact(full_text: str) -> tuple[str | None, str | None] {
    t = full_text.lower();
    if "vacated" in t and "medical" in t {
        return ("2025-07", "medical_debt_reporting");
    }
    if ("april 22, 2026" in t) or ("fhfa" in t and "hud" in t and "approved" in t and "vantagescore" in t) {
        return ("2026-04-22", "mortgage_scoring_models");
    }
    return (None, None);
}

def _scope_for(source_doc: str, heading: str) -> list[str] {
    base = list(SCOPE_BY_FILE.get(source_doc, []));
    # Utilization mechanics is the shared math engine other files' point
    # estimates depend on - useful to the 90-day surface even though it
    # lives in the discovered-actions file.
    if source_doc == "discovered-actions-agent-knowledge-base.md" and heading.startswith("2. Utilization Mechanics") {
        if "ninety_day" not in base {
            base.append("ninety_day");
        }
    }
    return base;
}

def chunk_markdown(path: str, source_doc: str) -> list[Chunk] {
    with open(path, "r") as f {
        raw = f.read();
    }
    lines = raw.split("\n");

    chunks: list[Chunk] = [];
    heading = "";
    level = 0;
    current_h2 = "";
    buffer: list[str] = [];

    def _flush {
        if not heading.strip() {
            return;
        }
        # Each new KB file opens with "# <Title>" then an "### <Domain> |
        # companion to ..." byline right under it - real markup, but a
        # document-metadata line, not a retrievable content section.
        if "companion to" in heading.lower() {
            return;
        }
        body = "\n".join(buffer).strip();
        text = (heading + "\n\n" + body) if body else heading;
        section_path = heading if level == 2 else (current_h2 + " > " + heading if current_h2 else heading);
        chunk_type = _detect_chunk_type(heading, body);
        topic_tags = _detect_topic_tags(text);
        (effective_date, supersedes_topic) = _detect_dated_fact(text);
        chunks.append(Chunk(
            chunk_id=source_doc + "::" + str(len(chunks)),
            source_doc=source_doc,
            heading=heading,
            section_path=section_path,
            level=level,
            text=text,
            chunk_type=chunk_type,
            scope=_scope_for(source_doc, heading),
            topic_tags=topic_tags,
            effective_date=effective_date,
            supersedes_topic=supersedes_topic
        ));
    }

    for line in lines {
        stripped = line.strip();
        is_h3 = stripped.startswith("### ");
        is_h2 = (not is_h3) and stripped.startswith("## ");
        if is_h2 or is_h3 {
            _flush();
            heading = stripped.lstrip("#").strip();
            level = 3 if is_h3 else 2;
            if level == 2 {
                current_h2 = heading;
            }
            buffer = [];
        } else {
            buffer.append(line);
        }
    }
    _flush();
    return chunks;
}

def chunk_all_knowledge(knowledge_dir: str) -> list[Chunk] {
    all_chunks: list[Chunk] = [];
    if not os.path.isdir(knowledge_dir) {
        return all_chunks;
    }
    for fname in sorted(os.listdir(knowledge_dir)) {
        if fname.endswith(".md") {
            full_path = os.path.join(knowledge_dir, fname);
            all_chunks = all_chunks + chunk_markdown(full_path, fname);
        }
    }
    return all_chunks;
}

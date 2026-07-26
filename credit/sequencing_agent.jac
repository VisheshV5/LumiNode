"""LumiNode - Strategic Credit Limit & Utilization Sequencing Agent.

Replaces the old single-shot sequence_credit_actions call (one prompt in, one
plan out, no tools) with a genuine ReAct agent: it can check the person's
actual income/savings before deciding whether a paydown is realistically
affordable on the timeline it's proposing, and it grounds every timing
decision in the 90-day sequencing knowledge base (hard-scoped - never leaks
into the discovered-actions or chat files) instead of guessing at reporting-
cycle mechanics from general knowledge.
"""

import from rag.agent { run_rag_agent }
import from .graph_tools { _tool_read_cards, _tool_read_loans, _tool_read_income_summary }

# ═══════════════════════════════════════════
# TOOLS - read tools are shared (credit/graph_tools.jac); this agent's own
# tool is its scoped knowledge-base search, hard-filtered to the 90-day
# sequencing doc + the shared factors doc.
# ═══════════════════════════════════════════

def _tool_search_sequencing_rules(query: str) -> str {
    result = run_rag_agent(query, agent_scope="ninety_day");
    return result.answer;
}
sem _tool_search_sequencing_rules = """
Search the 90-day sequencing knowledge base for the actual reporting-cycle
timing, dispute/goodwill response windows, rapid-rescore eligibility, or
dated landscape facts (current medical-debt reporting status, mortgage
scoring model rollout) relevant to when and in what order to schedule an
action.
""";
sem _tool_search_sequencing_rules.query = "A focused search query about the timing or sequencing of a credit-improvement action.";

# ═══════════════════════════════════════════
# THE AGENT
# ═══════════════════════════════════════════

obj ActionStep {
    has action_type: str,
        description: str,
        score_impact: int,
        days_to_effect: int,
        difficulty: str,
        reasoning: str,
        success_probability: float,
        cumulative_score: int;
}

obj OptimalPath {
    has path_name: str,
        ordered_steps: list[ActionStep],
        projected_final_score: int,
        total_days: int,
        confidence: float,
        counterintuitive_insight: str;
}
sem OptimalPath.counterintuitive_insight = "One surprising finding about why this sequence works better than the obvious approach";

def sequence_credit_actions(
    current_score: int,
    target_score: int,
    available_actions: list[dict]
) -> OptimalPath by llm(
    tools=[_tool_read_cards, _tool_read_loans, _tool_read_income_summary, _tool_search_sequencing_rules],
    max_react_iterations=12
);
sem sequence_credit_actions = """
You are a credit score optimization strategist. Given a person's current
score, target score, and available actions, determine the OPTIMAL ORDER and
TIMING to execute them - true strategic sequencing of credit limit requests
and utilization paydowns, not just a static impact sort.

Use search_sequencing_rules to ground every timing decision in the actual
reporting-cycle mechanics: never schedule a step faster than the reporting
cycle allows (statement close -> furnisher reports -> bureau processes ->
score recalculates, about 30-45 days); never suggest a rapid rescore for a
general user (mortgage-underwriting-only); frame every projected score as a
range, not a guarantee.

HARD CONSTRAINT ON YOUR counterintuitive_insight - READ CAREFULLY: utilization
math is order-independent. Requesting a credit limit increase before paying
down a balance changes NOTHING about approval odds or the final utilization
ratio - issuers approve larger increases based on LOWER utilization and
stronger payment history, never higher/"more active" utilization. This is a
real, commonly-repeated internet myth and you must NOT reproduce it in any
form (e.g. "do the CLI first because issuers like to see the card in active
use," "a higher starting balance signals more activity," or any similar
framing). If you cannot find a real, mechanism-grounded reason (confirmed via
search_sequencing_rules) why one legitimate ordering beats another, do not
invent one - it is completely fine for counterintuitive_insight to instead
explain a REAL timing constraint (e.g. why disputes/goodwill letters should
start early despite their slow, uncertain timeline, or why paydowns should be
timed to land just before a statement closes) rather than a fabricated
approval-odds mechanism.

Use the read tools (cards, loans, income summary) to sanity-check whether the
person can realistically afford a paydown's dollar amount given their income,
cost of living, and savings before sequencing it early - don't front-load a
paydown they can't actually make.

Find the genuinely fastest realistic sequence to reach the target score.
""";

"""Deterministic stand-in used when no LLM key is configured - sorts by impact-per-day."""
def _fallback_optimal_path(current_score: int, target_score: int, available_actions: list[dict]) -> OptimalPath {
    ordered = sorted(
        available_actions,
        key=lambda (a: dict) -> float { return (a["impact"] as float) / ((a["days"] as float) + 1.0); },
        reverse=True
    );

    steps: list[ActionStep] = [];
    running_score = current_score;
    running_days = 0;
    for a in ordered {
        running_score = running_score + (a["impact"] as int);
        if running_score > 850 { running_score = 850; }
        if running_score < 300 { running_score = 300; }
        running_days = running_days + (a["days"] as int);
        steps.append(ActionStep(
            action_type=a["type"] as str,
            description=a["description"] as str,
            score_impact=a["impact"] as int,
            days_to_effect=a["days"] as int,
            difficulty=a["difficulty"] as str,
            reasoning="Sorted by score impact per day (LLM unavailable - set GOOGLE_API_KEY for adaptive sequencing).",
            success_probability=0.7,
            cumulative_score=running_score
        ));
    }

    return OptimalPath(
        path_name="Fastest available path",
        ordered_steps=steps,
        projected_final_score=running_score,
        total_days=running_days,
        confidence=0.6,
        counterintuitive_insight="Actions are ranked by score impact per day of effect - connect an LLM for reporting-cycle-aware sequencing."
    );
}

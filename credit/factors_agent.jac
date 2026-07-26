"""LumiNode - Score Factors Agent.

A genuine ReAct agent (not a one-shot prompt): it decides for itself which
parts of the credit graph to inspect - cards, payment history, credit mix,
account age, inquiries - via read tools, and grounds each verdict in the
real FICO scoring rules by calling into the RAG knowledge base, instead of
the fixed if/else thresholds this used to be.
"""

import from rag.agent { run_rag_agent }
import from .model {
    CreditProfile, CreditCard, Loan, PaymentHistory, CreditMix, AccountAge, HardInquiry,
    FactorAssessment, FactorAssessmentSet,
    HasAccount, HasHistory, HasMix, HasAge, HasInquiry, HasFactorAssessment
}
import from .graph_tools {
    _tool_read_cards, _tool_read_payment_history, _tool_read_credit_mix,
    _tool_read_account_age, _tool_read_inquiries
}

# ═══════════════════════════════════════════
# TOOLS - the agent decides which of these to call, and when.
# Read tools are shared (credit/graph_tools.jac); this agent's own tool is
# just its scoped knowledge-base search.
# ═══════════════════════════════════════════

def _tool_search_fico_rules(query: str) -> str {
    result = run_rag_agent(query);
    return result.answer;
}
sem _tool_search_fico_rules = """
Search the credit-scoring knowledge base for the actual FICO/VantageScore
rule you need (exact utilization buckets, how derogatory marks decay, how
long an inquiry affects the score, what counts as a "good" account age) -
use this instead of guessing thresholds from general knowledge.
""";
sem _tool_search_fico_rules.query = "A focused search query for the credit-scoring knowledge base.";

# ═══════════════════════════════════════════
# THE AGENT
# ═══════════════════════════════════════════

def assess_credit_factors() -> list[FactorAssessment] by llm(
    tools=[
        _tool_read_cards, _tool_read_payment_history, _tool_read_credit_mix,
        _tool_read_account_age, _tool_read_inquiries, _tool_search_fico_rules
    ],
    max_react_iterations=10
);
sem assess_credit_factors = """
Assess this person's credit profile against the five FICO scoring factors:
Credit Utilization (30%), Payment History (35%), Length of Credit History (15%),
Credit Mix (10%), and New Credit/Inquiries (10%).

Use the read tools to gather their real account data - cards, payment
history, credit mix, account age, and inquiries. Use search_fico_rules to
ground each verdict in the actual scoring rules (exact utilization buckets,
how long inquiries affect the score, what a healthy account age looks like)
rather than guessing thresholds.

Return exactly one FactorAssessment per factor (five total), each with a
tone ('good' if it currently helps their score, 'bad' if it hurts it, 'warn'
if mediocre), a short headline value, and a 1-2 sentence explanation that
cites their real numbers.
""";

"""Deterministic stand-in used when no LLM key is configured."""
def _fallback_factor_assessments() -> list[FactorAssessment] {
    profiles = [root -->][?:CreditProfile];
    if len(profiles) == 0 { return []; }
    profile = profiles[0];
    cards = [profile ->:HasAccount:->][?:CreditCard];
    mixes = [profile ->:HasMix:->][?:CreditMix];
    ages = [profile ->:HasAge:->][?:AccountAge];
    inquiries = [profile ->:HasInquiry:->][?:HardInquiry];

    total_limit = sum([c.credit_limit for c in cards]);
    total_balance = sum([c.current_balance for c in cards]);
    utilization = (total_balance / total_limit * 100.0) if total_limit > 0.0 else 0.0;
    util_tone = "good" if utilization < 30.0 else ("warn" if utilization < 50.0 else "bad");

    has_late = False;
    for c in cards {
        for h in [c ->:HasHistory:->][?:PaymentHistory] {
            if h.late_payments_30 > 0 or h.late_payments_60 > 0 or h.late_payments_90 > 0 {
                has_late = True;
            }
        }
    }
    history_tone = "bad" if has_late else "good";

    mix_count = 0;
    mix_tone = "warn";
    if len(mixes) > 0 {
        m = mixes[0];
        mix_count = (1 if m.num_credit_cards > 0 else 0) + (1 if m.num_installment_loans > 0 else 0) + (1 if m.num_mortgage > 0 else 0);
        mix_tone = "good" if mix_count >= 2 else "warn";
    }

    avg_age = ages[0].average_age_months if len(ages) > 0 else 0;
    age_tone = "good" if avg_age >= 24 else ("warn" if avg_age >= 12 else "bad");

    inquiry_count = len(inquiries);
    inquiry_tone = "good" if inquiry_count <= 1 else ("warn" if inquiry_count <= 3 else "bad");
    inquiry_word = "inquiry" if inquiry_count == 1 else "inquiries";

    return [
        FactorAssessment(
            factor_name="Credit Utilization", tone=util_tone,
            headline=f"{utilization:.0f}%",
            explanation=f"30% of your score. Under 9% is ideal - you're carrying ${total_balance:.0f} of ${total_limit:.0f} available."
        ),
        FactorAssessment(
            factor_name="Payment History", tone=history_tone,
            headline="Clean" if not has_late else "Late marks",
            explanation="35% of your score - the single biggest lever. " + ("No issues found." if not has_late else "A dispute action can help remove this.")
        ),
        FactorAssessment(
            factor_name="Credit Mix", tone=mix_tone,
            headline=f"{mix_count}/3 types",
            explanation="10% of your score. Cards, installment loans, and mortgages each count as a type."
        ),
        FactorAssessment(
            factor_name="Credit Age", tone=age_tone,
            headline=f"{(avg_age / 12.0):.1f}y",
            explanation="15% of your score. Average account age - older is better, so keep old accounts open."
        ),
        FactorAssessment(
            factor_name="New Credit", tone=inquiry_tone,
            headline=f"{inquiry_count} {inquiry_word}",
            explanation="10% of your score. Each hard inquiry can cost a few points and fades within about a year."
        )
    ];
}

"""True only if the agent returned the five well-formed assessments the
prompt asks for - guards against malformed/partial ReAct output (empty
factor_name, junk tone, or a stray extra entry per tool-call iteration)."""
def valid_factor_assessments(assessments: list[FactorAssessment]) -> bool {
    if len(assessments) != 5 { return False; }
    seen: dict[str, bool] = {};
    for fa in assessments {
        if not fa.factor_name.strip() or not fa.headline.strip() or not fa.explanation.strip() {
            return False;
        }
        if fa.tone not in ["good", "bad", "warn"] { return False; }
        if seen.get(fa.factor_name) { return False; }
        seen[fa.factor_name] = True;
    }
    return True;
}

"""Runs the factor agent (with fallback) and persists the result on the profile."""
def compute_and_store_factor_assessments() {
    profiles = [root -->][?:CreditProfile];
    if len(profiles) == 0 { return; }
    profile = profiles[0];

    for old_set in [profile ->:HasFactorAssessment:->][?:FactorAssessmentSet] {
        del old_set;
    }

    try {
        assessments = assess_credit_factors();
        if not valid_factor_assessments(assessments) {
            assessments = _fallback_factor_assessments();
        }
    } except Exception {
        assessments = _fallback_factor_assessments();
    }

    result_set = FactorAssessmentSet(assessments=assessments);
    profile +>:HasFactorAssessment():+> result_set;
}

"""LumiNode - Ripple Effect Analysis.

Understands that paying down one card shifts utilization ratios on every
other card too - `simulate_credit_action_effects` asks the LLM to reason
about the second- and third-order consequences of a single action.
"""

import from .model { CreditProfile, CreditCard, Action, HasAccount }

obj RippleEffect {
    has affected_factor: str,
        current_value: str,
        projected_value: str,
        score_impact: int,
        explanation: str;
}
sem RippleEffect = "A single ripple effect showing how one credit action cascades to affect other factors";
sem RippleEffect.affected_factor = "The credit factor affected: 'utilization', 'payment_history', 'credit_age', 'credit_mix', 'inquiries'";

def simulate_credit_action_effects(
    action_type: str,
    action_description: str,
    current_score: int,
    overall_utilization: float,
    num_cards: int,
    total_limit: float,
    total_balance: float
) -> list[RippleEffect] by llm();
sem simulate_credit_action_effects = """
Analyze how a credit action cascades through the FICO scoring model.
Consider:
- Utilization changes affect ALL cards (total utilization shifts)
- Payment history weight (35% of FICO)
- Utilization weight (30% of FICO)
- Credit age weight (15% of FICO)
- Credit mix weight (10% of FICO)
- New credit weight (10% of FICO)
Return 2-5 ripple effects showing second and third-order consequences.
""";

"""Deterministic stand-in used when no LLM key is configured."""
def _fallback_ripple_effects(action_type: str, estimated_impact: int) -> list[RippleEffect] {
    if action_type == "pay_down" {
        return [
            RippleEffect(
                affected_factor="utilization",
                current_value="high utilization",
                projected_value="lower utilization",
                score_impact=estimated_impact,
                explanation="Paying down this balance lowers your overall utilization ratio, the single biggest lever after payment history."
            ),
            RippleEffect(
                affected_factor="credit_mix",
                current_value="unchanged",
                projected_value="unchanged",
                score_impact=0,
                explanation="This action does not change the types of credit you hold."
            )
        ];
    }
    if action_type == "request_cli" {
        return [
            RippleEffect(
                affected_factor="utilization",
                current_value="current limit",
                projected_value="higher limit, same balance",
                score_impact=estimated_impact,
                explanation="A higher limit against the same balance drops your utilization ratio without paying anything down."
            )
        ];
    }
    if action_type == "dispute" {
        return [
            RippleEffect(
                affected_factor="payment_history",
                current_value="late payment on file",
                projected_value="late payment removed",
                score_impact=estimated_impact,
                explanation="Payment history is 35% of your FICO score - removing one late mark can move the needle more than almost anything else."
            )
        ];
    }
    if action_type == "open_account" {
        return [
            RippleEffect(
                affected_factor="inquiries",
                current_value="no new inquiry",
                projected_value="one new hard inquiry",
                score_impact=-5,
                explanation="A new application triggers a small, temporary dip from the hard inquiry."
            ),
            RippleEffect(
                affected_factor="credit_mix",
                current_value="fewer account types",
                projected_value="broader account mix",
                score_impact=8,
                explanation="A wider mix of account types is worth 10% of your score, and recovers within 1-2 billing cycles."
            )
        ];
    }
    return [
        RippleEffect(
            affected_factor="credit_age",
            current_value="unchanged",
            projected_value="unchanged",
            score_impact=estimated_impact,
            explanation="Riding on an older, well-managed account lengthens your average account age over time."
        )
    ];
}

"""Hold a ripple breakdown to the action's own sourced budget. A ripple view
decomposes ONE action across the factors it touches, so its parts must not sum
to more than that action's clamped total - otherwise the ripple panel and the
action path quote different numbers for the same action. Gains are scaled down
proportionally; negative side-effects are left alone, since a larger downside
is the conservative read."""
def _fit_to_budget(effects: list[RippleEffect], budget: int) -> list[RippleEffect] {
    allowed = budget if budget > 0 else 0;
    gains = 0;
    for e in effects {
        if e.score_impact > 0 { gains = gains + e.score_impact; }
    }
    if gains > 0 and gains > allowed {
        scale = (allowed as float) / (gains as float);
        for e in effects {
            if e.score_impact > 0 {
                e.score_impact = int((e.score_impact as float) * scale);
            }
        }
    }
    # Drop "0 points, nothing changes" rows - they pad the panel without
    # saying anything. Negative rows STAY: a real downside is a warning the
    # user needs, not a recommendation, and hiding it would mislead.
    kept: list[RippleEffect] = [];
    for e in effects {
        if e.score_impact != 0 { kept.append(e); }
    }
    return kept;
}

"""Simulate the cascading effects of one specific discovered action."""
def:protect run_ripple_simulation(action_id: str) -> list[RippleEffect] {
    profiles = [root -->][?:CreditProfile];
    if len(profiles) == 0 { return []; }
    profile = profiles[0];

    cards = [profile ->:HasAccount:->][?:CreditCard];
    total_limit = sum([c.credit_limit for c in cards]);
    total_balance = sum([c.current_balance for c in cards]);
    overall_utilization = (total_balance / total_limit * 100.0) if total_limit > 0.0 else 0.0;

    actions = [profile -->][?:Action];
    target_action: Action | None = None;
    for a in actions {
        if jid(a) == action_id { target_action = a; }
    }
    if target_action is None { return []; }
    found = target_action as Action;

    try {
        effects = simulate_credit_action_effects(
            action_type=found.action_type,
            action_description=found.description,
            current_score=profile.current_score,
            overall_utilization=overall_utilization,
            num_cards=len(cards),
            total_limit=total_limit,
            total_balance=total_balance
        );
        return _fit_to_budget(effects, found.estimated_score_impact);
    } except Exception {
        return _fallback_ripple_effects(found.action_type, found.estimated_score_impact);
    }
}

"""LumiNode - Discovered Actions Agent.

Replaces the old fixed if/else ActionGenerator walker (which only ever
implemented 4 of the action catalog's 10 levers). A genuine ReAct agent:
reads the person's real account data via tools, cross-references the actual
action catalog and trigger conditions in the discovered-actions knowledge
base (hard-scoped - never leaks into the 90-day or chat files), and only
surfaces an action when its trigger condition is genuinely met by this
person's data.
"""

import from rag.agent { run_rag_agent }
import from .graph_tools {
    _tool_read_cards, _tool_read_loans, _tool_read_payment_history,
    _tool_read_credit_mix, _tool_read_account_age, _tool_read_inquiries
}
import from .model {
    CreditProfile, Action,
    _estimate_utilization_impact, _estimate_cli_impact, _estimate_dispute_impact
}

# ═══════════════════════════════════════════
# TOOLS - read tools are shared (credit/graph_tools.jac); this agent's own
# tool is its scoped knowledge-base search, hard-filtered to the
# discovered-actions catalog + the shared factors doc.
# ═══════════════════════════════════════════

def _tool_search_action_playbook(query: str) -> str {
    result = run_rag_agent(query, agent_scope="discovered_actions");
    return result.answer;
}
sem _tool_search_action_playbook = """
Search the discovered-actions knowledge base for the actual mechanism,
realistic impact, time-to-reflect, risk/caveats, and trigger condition for a
specific lever (paydown, credit limit increase, goodwill letter, formal
dispute, authorized user, paying/settling a collection, alternative-data
boosts, credit mix, hard inquiries, keeping old accounts open) before
surfacing it as a recommendation.
""";
sem _tool_search_action_playbook.query = "A focused search query about one specific credit-improvement action.";

# ═══════════════════════════════════════════
# THE AGENT
# ═══════════════════════════════════════════

obj DiscoveredActionSpec {
    has action_type: str,
        description: str,
        estimated_score_impact: int,
        time_to_effect_days: int,
        difficulty: str,
        risk_level: str;
}
sem DiscoveredActionSpec = "One concrete, worthwhile action this specific person could take, grounded in their real account data and the action catalog's trigger conditions.";
sem DiscoveredActionSpec.action_type = "One of: 'pay_down', 'request_cli', 'dispute', 'become_au', 'open_account', 'pay_collection', 'alt_data_boost', 'avoid_inquiries', 'keep_old_open'.";
sem DiscoveredActionSpec.description = "A specific, concrete description citing the person's real numbers (account name, dollar amount, target utilization) - not generic advice.";
sem DiscoveredActionSpec.estimated_score_impact = "A modeled point estimate grounded in the knowledge base's threshold-band math, never presented as a guarantee. Can be negative (e.g. a new account's temporary dip).";
sem DiscoveredActionSpec.time_to_effect_days = "Realistic days until this action's effect would actually reflect on the score, per the knowledge base's timing guidance.";
sem DiscoveredActionSpec.difficulty = "'easy', 'medium', or 'hard'.";
sem DiscoveredActionSpec.risk_level = "'low', 'medium', or 'high'.";

def discover_actions -> list[DiscoveredActionSpec] by llm(
    tools=[
        _tool_read_cards, _tool_read_loans, _tool_read_payment_history,
        _tool_read_credit_mix, _tool_read_account_age, _tool_read_inquiries,
        _tool_search_action_playbook
    ],
    max_react_iterations=12
);
sem discover_actions = """
Discover every concrete, worthwhile action this specific person could take to
improve their credit score right now.

Use the read tools to gather their real account data - cards, loans, payment
history, credit mix, account age, and inquiries. Use search_action_playbook
to confirm the actual mechanism and trigger condition for each candidate
action before surfacing it - only include an action when its trigger
condition is genuinely satisfied by THIS person's data, not generic advice
padded onto the list.

Follow every guardrail search_action_playbook returns: never state a point
value as certain, never invent a causal mechanism (e.g. requesting a credit
limit increase before paying down a balance does NOT unlock bigger approvals
- that's backwards and fabricated), never present goodwill-letter or dispute
success rates as fixed statistics, never suggest tradeline-renting as a
recommended action.
""";

"""Deterministic stand-in used when no LLM key is configured - the original
fixed-rule logic this agent replaces, kept as a safety net."""
def _fallback_discover_actions -> list[DiscoveredActionSpec] {
    cards = _tool_read_cards();
    mix = _tool_read_credit_mix();
    histories = _tool_read_payment_history();

    specs: list[DiscoveredActionSpec] = [];

    if mix.get("num_credit_cards", 0) < 3 {
        specs.append(DiscoveredActionSpec(
            action_type="open_account",
            description="Open a new credit card to improve credit mix and total available credit",
            estimated_score_impact=-5,
            time_to_effect_days=30,
            difficulty="medium",
            risk_level="medium"
        ));
    }

    for c in cards {
        util: float = c["utilization_pct"];
        limit: float = c["limit"];
        balance: float = c["balance"];
        name: str = c["name"];
        is_au: bool = c["is_authorized_user"];

        if util > 10.0 {
            target_balance = limit * 0.089;
            pay_amount = balance - target_balance;
            if pay_amount > 0.0 {
                specs.append(DiscoveredActionSpec(
                    action_type="pay_down",
                    description=f"Pay down {name} by ${pay_amount:.0f} to reach 8.9% utilization",
                    estimated_score_impact=_estimate_utilization_impact(util, 8.9),
                    time_to_effect_days=14,
                    difficulty="easy" if pay_amount < 500.0 else "medium",
                    risk_level="low"
                ));
            }
        }

        if not is_au {
            specs.append(DiscoveredActionSpec(
                action_type="request_cli",
                description=f"Request a credit limit increase on {name} (soft pull)",
                estimated_score_impact=_estimate_cli_impact(util, limit),
                time_to_effect_days=7,
                difficulty="easy",
                risk_level="low"
            ));
        }
    }

    for h in histories {
        late_30: int = h["late_30"];
        late_60: int = h["late_60"];
        late_90: int = h["late_90"];
        if late_30 > 0 or late_60 > 0 {
            specs.append(DiscoveredActionSpec(
                action_type="dispute",
                description=f"Dispute the late payment on {h['account_name']} (goodwill letter or formal dispute)",
                estimated_score_impact=_estimate_dispute_impact(late_30, late_60, late_90),
                time_to_effect_days=45,
                difficulty="medium",
                risk_level="low"
            ));
        }
    }

    specs.append(DiscoveredActionSpec(
        action_type="become_au",
        description="Get added as an authorized user on a family member's oldest card with perfect history",
        estimated_score_impact=30,
        time_to_effect_days=30,
        difficulty="medium",
        risk_level="low"
    ));

    return specs;
}

"""True only if the agent returned at least one well-formed action - guards
against a ReAct call that completes without error but whose structured
output silently parses to an empty or malformed list."""
def valid_discovered_actions(specs: list[DiscoveredActionSpec]) -> bool {
    if len(specs) == 0 { return False; }
    for s in specs {
        if not s.action_type.strip() or not s.description.strip() { return False; }
        if s.difficulty not in ["easy", "medium", "hard"] { return False; }
        if s.risk_level not in ["low", "medium", "high"] { return False; }
    }
    return True;
}

"""Runs the discovery agent (with fallback) and persists results as Action nodes."""
def compute_and_store_discovered_actions {
    profiles = [root -->][?:CreditProfile];
    if len(profiles) == 0 { return; }
    profile = profiles[0];

    for old_action in [profile -->][?:Action] {
        del old_action;
    }

    try {
        specs = discover_actions();
        if not valid_discovered_actions(specs) {
            specs = _fallback_discover_actions();
        }
    } except Exception {
        specs = _fallback_discover_actions();
    }

    for spec in specs {
        action = Action(
            action_type=spec.action_type,
            description=spec.description,
            estimated_score_impact=spec.estimated_score_impact,
            time_to_effect_days=spec.time_to_effect_days,
            difficulty=spec.difficulty,
            risk_level=spec.risk_level
        );
        profile ++> action;
    }
}

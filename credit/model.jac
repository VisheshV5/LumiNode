"""LumiNode - Credit Graph Data Model.

The graph shape: one CreditProfile per user root, with accounts, payment
history, inquiries, age and mix summaries hanging off it, plus the Action
nodes and SimulationResult a run of the planner produces.
"""

import from datetime { datetime }

# ═══════════════════════════════════════════
# CORE GRAPH NODES
# ═══════════════════════════════════════════

node CreditProfile {
    has name: str,
        current_score: int,
        target_score: int,
        created_at: str,
        score_model: str = "FICO 8",
        monthly_income: float = 0.0,
        monthly_cost_of_living: float = 0.0,
        savings_balance: float = 0.0,
        investment_balance: float = 0.0,
        imessage_handle: str = "";

    # Body lives in credit/imessage.jac (impl CreditProfile.accept_imessage_write).
    # A node's own ability runs in the node's own permission context, so this
    # is how the anonymous BlueBubbles webhook (no login session, can't be
    # granted access the normal way) is able to write a chat message and a
    # score update onto a profile it doesn't own.
    can accept_imessage_write with entry;
}
sem CreditProfile = "The user's overall credit profile containing their current and target scores";
sem CreditProfile.imessage_handle = "The iMessage address linked for text updates - either an E.164 phone number ('+15551234567') or an Apple ID email; empty if not connected";

node CreditCard {
    has card_name: str,
        credit_limit: float,
        current_balance: float,
        utilization_pct: float,
        min_payment: float,
        apr: float,
        is_authorized_user: bool = False,
        has_late_payment: bool = False;
}
sem CreditCard = "A single credit card account with its balance, limit, and utilization";
sem CreditCard.utilization_pct = "Current balance divided by credit limit, as a percentage";

node Loan {
    has loan_type: str,
        original_amount: float,
        current_balance: float,
        monthly_payment: float,
        apr: float,
        months_remaining: int;
}
sem Loan = "An installment loan (student, auto, personal, mortgage)";
sem Loan.loan_type = "Type of loan: 'student', 'auto', 'personal', 'mortgage'";

node PaymentHistory {
    has account_name: str,
        on_time_pct: float,
        late_payments_30: int = 0,
        late_payments_60: int = 0,
        late_payments_90: int = 0,
        oldest_late_date: str = "";
}
sem PaymentHistory = "Payment history for a specific account, tracking on-time percentage and late payments";

node HardInquiry {
    has creditor: str,
        inquiry_date: str,
        inquiry_type: str,
        months_old: int;
}
sem HardInquiry = "A hard credit inquiry that temporarily lowers the score";

node AccountAge {
    has oldest_account_months: int,
        average_age_months: int,
        newest_account_months: int;
}
sem AccountAge = "Summary of the age of the user's credit accounts";

node CreditMix {
    has num_credit_cards: int,
        num_installment_loans: int,
        num_mortgage: int,
        has_auto_loan: bool,
        has_student_loan: bool;
}
sem CreditMix = "The diversity of credit types the user holds";

# ═══════════════════════════════════════════
# ACTION / SIMULATION NODES
# ═══════════════════════════════════════════

node Action {
    has action_type: str,
        description: str,
        estimated_score_impact: int,
        time_to_effect_days: int,
        difficulty: str,
        risk_level: str,
        completed: bool = False;
}
sem Action = "A specific action the user can take to improve their credit score";
sem Action.action_type = "Type: 'pay_down', 'request_cli', 'dispute', 'open_account', 'become_au'";
sem Action.difficulty = "How hard this action is: 'easy', 'medium', 'hard'";
sem Action.risk_level = "Risk level: 'low', 'medium', 'high'";

"""One step of a persisted optimal path - the wire shape stored on SimulationResult."""
obj ActionStepRecord {
    has action_type: str,
        description: str,
        score_impact: int,
        days_to_effect: int,
        difficulty: str,
        cumulative_score: int;
}

node SimulationResult {
    has path_name: str,
        starting_score: int,
        projected_score: int,
        total_days: int,
        total_actions: int,
        confidence: float,
        counterintuitive_insight: str = "",
        steps: list[ActionStepRecord] = [];
}
sem SimulationResult = "The result of a simulated path through the credit graph showing projected score improvement";

# ═══════════════════════════════════════════
# CHAT / MESSAGING NODES
# ═══════════════════════════════════════════

node ChatMessage {
    has role: str,
        content: str,
        timestamp: str;
}
sem ChatMessage = "A message in the iMessage-style financial chat";
sem ChatMessage.role = "Either 'user' or 'assistant'";

# ═══════════════════════════════════════════
# GRAPH EDGES (relationships between nodes)
# ═══════════════════════════════════════════

edge HasAccount {
    has weight: float = 1.0;
}
sem HasAccount = "Connects CreditProfile to an account (CreditCard, Loan)";

edge HasHistory {
    has weight: float = 1.0;
}
sem HasHistory = "Connects an account to its payment history";

edge HasInquiry {}
sem HasInquiry = "Connects CreditProfile to a hard inquiry";

edge HasAge {}
sem HasAge = "Connects CreditProfile to account age summary";

edge HasMix {}
sem HasMix = "Connects CreditProfile to credit mix summary";

edge Impacts {
    has impact_weight: float,
        direction: str;
}
sem Impacts = "Shows how one credit factor impacts another";
sem Impacts.impact_weight = "How strongly this factor impacts the score, 0.0 to 1.0";
sem Impacts.direction = "Either 'positive' or 'negative'";

edge ProducesResult {}
sem ProducesResult = "Connects a CreditProfile to a SimulationResult it produced";

edge HasMessage {}
sem HasMessage = "Connects CreditProfile to chat messages";

edge HasFactorAssessment {}
sem HasFactorAssessment = "Connects a CreditProfile to its latest AI-generated factor assessment set";

# ═══════════════════════════════════════════
# AGENT-GENERATED FACTOR ASSESSMENTS
# ═══════════════════════════════════════════

obj FactorAssessment {
    has factor_name: str,
        tone: str,
        headline: str,
        explanation: str;
}
sem FactorAssessment = "An AI-generated verdict on one FICO scoring factor for this profile";
sem FactorAssessment.factor_name = "One of: 'Credit Utilization', 'Payment History', 'Credit Mix', 'Credit Age', 'New Credit'";
sem FactorAssessment.tone = "'good' if this factor is helping the score, 'bad' if hurting it, 'warn' if mediocre";
sem FactorAssessment.headline = "A short value display like '66%', 'Clean', '2/3 types', '1.8y'";
sem FactorAssessment.explanation = "1-2 plain-language sentences citing the person's real numbers";

node FactorAssessmentSet {
    has assessments: list[FactorAssessment] = [];
}
sem FactorAssessmentSet = "The latest AI-generated read on all five FICO factors for this profile";

# ═══════════════════════════════════════════
# WIRE-ONLY BUNDLE (not persisted - just the dashboard payload shape)
# ═══════════════════════════════════════════

obj DashboardBundle {
    has has_profile: bool = False,
        profile: CreditProfile | None = None,
        cards: list[CreditCard] = [],
        loans: list[Loan] = [],
        actions: list[Action] = [],
        account_age: AccountAge | None = None,
        credit_mix: CreditMix | None = None,
        latest_result: SimulationResult | None = None,
        factor_assessments: list[FactorAssessment] = [],
        chat_messages: list[ChatMessage] = [];
}

# ═══════════════════════════════════════════
# PURE HELPER FUNCTIONS (no LLM, no graph access)
# ═══════════════════════════════════════════

def _get_current_date() -> str {
    return datetime.now().strftime("%Y-%m-%d");
}

# ═══════════════════════════════════════════
# SCORE IMPACT MODEL
#
# Every constant below traces to a cited section of knowledge/. Where no
# source exists, the value sits at the conservative FLOOR of the observed
# range, never its midpoint or top - a shown estimate should be one the
# user beats, not one they fall short of.
#
# The functions here are the single source of truth for point values: the
# deterministic fallback path calls them directly, and the LLM agents are
# clamped against them (see _clamp_action_impact). An agent may propose a
# LOWER number with its own reasoning; it can never propose a higher one.
# ═══════════════════════════════════════════

"""Utilization threshold band edges, per discovered-actions KB 1.1 and 2:
under 9%, under 29%, under 49%, under 69%, under 89%, with 89%+ effectively
maxed. Community-derived (long-running myFICO forum consensus) and NOT
officially disclosed by FICO - scoring moves in a step when a band is
crossed, and barely at all within one."""
glob _UTIL_BANDS: list[float] = [9.0, 29.0, 49.0, 69.0, 89.0];

"""Points per band crossing. KB 1.1 cites roughly 10-15 points for crossing an
AGGREGATE threshold and roughly 5 for an individual-card threshold. We take
the bottom of the aggregate range."""
glob _POINTS_PER_BAND: int = 10;

"""Authorized-user tradeline. No official figure exists; published experiments
report a 3-45 point spread (avg ~22), and KB 1.5 notes the effect is
"smaller for users who already have an established file". Floored well below
that average."""
glob _AU_IMPACT: int = 15;

"""Absolute per-action ceilings. pay_down/request_cli sit at 50 because five
band crossings is the most the ladder physically allows (maxed -> under 9%);
their real ceiling is usually far lower and comes from live utilization via
_estimate_utilization_impact. dispute approximates FICO's published damage
data for an already-low score (a late costs a 580-tier file far less than a
780-tier one, so recovery is correspondingly smaller); open_account is a
near-term DIP, not a gain."""
glob _ACTION_IMPACT_CEILING: dict[str, int] = {
    "pay_down": 50,
    "request_cli": 50,
    "become_au": 15,
    "dispute": 40,
    "pay_collection": 25,
    "open_account": -5,
    "alt_data_boost": 10,
    "avoid_inquiries": 5,
    "keep_old_open": 5
};

"""Confidence = P(the user reaches AT LEAST the displayed number). Because the
displayed number is the conservative floor, confidence in meeting it is
legitimately high for actions the user controls outright, and low only where
a third party can decline (issuer, creditor, bureau). Per KB 3.5, this is
calibrated to source quality and to who holds the decision."""
glob _ACTION_CONFIDENCE: dict[str, float] = {
    "pay_down": 0.85,
    "request_cli": 0.70,
    "become_au": 0.70,
    "pay_collection": 0.75,
    "avoid_inquiries": 0.80,
    "keep_old_open": 0.80,
    "open_account": 0.60,
    "alt_data_boost": 0.55,
    "dispute": 0.40
};

"""No plan is a certainty - the user still has to execute it."""
glob _MAX_PATH_CONFIDENCE: float = 0.90;

"""Primary FICO factor each action moves. Actions sharing a factor overlap and
must not be summed at full value (see _apply_factor_decay). become_au is
filed under length_of_history because the aged tradeline is its distinctive
contribution; its utilization help is secondary and partly self-cancelling,
since the AU account's balance joins the aggregate along with its limit."""
glob _ACTION_FACTOR: dict[str, str] = {
    "pay_down": "amounts_owed",
    "request_cli": "amounts_owed",
    "become_au": "length_of_history",
    "keep_old_open": "length_of_history",
    "dispute": "payment_history",
    "pay_collection": "payment_history",
    "open_account": "credit_mix",
    "avoid_inquiries": "new_credit",
    "alt_data_boost": "new_credit"
};

"""Multiplier applied to the 1st, 2nd, 3rd... action hitting the same factor."""
glob _FACTOR_DECAY: list[float] = [1.0, 0.6, 0.4, 0.25];

"""Which utilization band a ratio falls in - 0 is best (<9%), 5 is maxed."""
def _util_band(util: float) -> int {
    band = 0;
    for edge in _UTIL_BANDS {
        if util >= edge { band = band + 1; }
    }
    return band;
}

"""Estimate score impact of a utilization change, scaled by how many threshold
bands the change actually crosses - not by the dollar amount paid, per the
KB 3.1 guardrail. Paying 61% -> 58% crosses nothing and correctly scores 0."""
def _estimate_utilization_impact(current_util: float, target_util: float) -> int {
    crossings = _util_band(current_util) - _util_band(target_util);
    return crossings * _POINTS_PER_BAND;
}

"""Estimate impact of a credit limit increase (assumes a 50% increase)."""
def _estimate_cli_impact(current_util: float, current_limit: float) -> int {
    if current_limit <= 0.0 { return 0; }
    assumed_increase = current_limit * 0.5;
    new_limit = current_limit + assumed_increase;
    new_util = (current_util / 100.0 * current_limit) / new_limit * 100.0;
    return _estimate_utilization_impact(current_util, new_util);
}

"""Estimate score impact of removing a late payment, assuming removal succeeds.
The odds of it succeeding are carried in confidence (0.40), not here."""
def _estimate_dispute_impact(late_30: int, late_60: int, late_90: int) -> int {
    if late_90 > 0 { return 40; }
    if late_60 > 0 { return 30; }
    if late_30 > 0 { return 20; }
    return 0;
}

"""Estimate score impact of being added as an authorized user."""
def _estimate_au_impact() -> int {
    return _AU_IMPACT;
}

"""Sourced ceiling for an action type. An action type absent from the table is
one nobody sized against a source - most likely a lever an agent invented - so
it gets a deliberately tight default rather than a free pass."""
def _static_impact_ceiling(action_type: str) -> int {
    return _ACTION_IMPACT_CEILING.get(action_type, 15);
}

"""Hold a proposed point value to its sourced ceiling. A proposal may sit
BELOW the ceiling (an agent reasoning its way to a smaller number is fine, and
a deeper temporary dip is the conservative read); it may never sit above it."""
def _clamp_action_impact(proposed: int, ceiling: int) -> int {
    if proposed > ceiling { return ceiling; }
    return proposed;
}

"""Confidence for a single action - see _ACTION_CONFIDENCE."""
def _confidence_for_action(action_type: str) -> float {
    return _ACTION_CONFIDENCE.get(action_type, 0.50);
}

"""Blend per-action confidence into one path figure, weighted by each step's
share of the total points, so the number is dominated by whichever steps are
actually carrying the projection."""
def _path_confidence(step_types: list[str], step_impacts: list[int]) -> float {
    total_weight = 0.0;
    weighted = 0.0;
    i = 0;
    for t in step_types {
        w = abs(step_impacts[i] as float) if i < len(step_impacts) else 0.0;
        i = i + 1;
        if w <= 0.0 { continue; }
        total_weight = total_weight + w;
        weighted = weighted + w * _confidence_for_action(t);
    }
    if total_weight <= 0.0 { return 0.50; }
    conf = weighted / total_weight;
    if conf > _MAX_PATH_CONFIDENCE { return _MAX_PATH_CONFIDENCE; }
    return conf;
}

"""Decay the 2nd+ action hitting the same FICO factor. Two utilization plays
(a paydown and a limit increase on the same card) move one shared lever and
must not be added at face value - the naive sum is what produced the original
"+75 then +30, so +105" projection."""
def _apply_factor_decay(step_types: list[str], step_impacts: list[int]) -> list[int] {
    seen: dict[str, int] = {};
    out: list[int] = [];
    i = 0;
    for t in step_types {
        raw = step_impacts[i] if i < len(step_impacts) else 0;
        i = i + 1;
        factor = _ACTION_FACTOR.get(t, t);
        n = seen.get(factor, 0);
        idx = n if n < len(_FACTOR_DECAY) else (len(_FACTOR_DECAY) - 1);
        out.append(int((raw as float) * _FACTOR_DECAY[idx]));
        seen[factor] = n + 1;
    }
    return out;
}

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
        investment_balance: float = 0.0;
}
sem CreditProfile = "The user's overall credit profile containing their current and target scores";

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

"""Estimate score impact of a utilization change based on FICO buckets."""
def _estimate_utilization_impact(current_util: float, target_util: float) -> int {
    buckets = [
        (0.0, 1.0, 0), (1.0, 9.0, 10), (9.0, 29.0, -10),
        (29.0, 49.0, -25), (49.0, 74.0, -45), (74.0, 101.0, -65)
    ];
    current_penalty = -65;
    target_penalty = -65;
    for (low, high, penalty) in buckets {
        if low <= current_util < high { current_penalty = penalty; }
        if low <= target_util < high { target_penalty = penalty; }
    }
    return target_penalty - current_penalty;
}

"""Estimate impact of a credit limit increase (assumes a 50% increase)."""
def _estimate_cli_impact(current_util: float, current_limit: float) -> int {
    if current_limit <= 0.0 { return 0; }
    assumed_increase = current_limit * 0.5;
    new_limit = current_limit + assumed_increase;
    new_util = (current_util / 100.0 * current_limit) / new_limit * 100.0;
    return _estimate_utilization_impact(current_util, new_util);
}

"""Estimate score impact of removing a late payment."""
def _estimate_dispute_impact(late_30: int, late_60: int, late_90: int) -> int {
    if late_90 > 0 { return 40; }
    if late_60 > 0 { return 30; }
    if late_30 > 0 { return 20; }
    return 0;
}

"""LumiNode - Graph Construction and Discovery.

`_build_credit_graph` maps a typed onboarding payload onto the credit graph.
`ActionGenerator` is the walker agent that then crawls that graph node by
node - card by card, history by history - discovering every action the user
could take. `get_dashboard_data` bundles the whole graph into one wire
payload for the client.
"""

import from .model {
    CreditProfile, CreditCard, Loan, PaymentHistory, HardInquiry,
    AccountAge, CreditMix, Action, SimulationResult, ChatMessage,
    FactorAssessmentSet, DashboardBundle,
    HasAccount, HasHistory, HasInquiry, HasAge, HasMix, ProducesResult, HasMessage,
    HasFactorAssessment,
    _get_current_date
}
import from .planner { optimize_path }
import from .factors_agent { compute_and_store_factor_assessments, valid_factor_assessments }
import from .discovered_actions_agent { compute_and_store_discovered_actions }
import from .imessage { grant_imessage_write_access }

# ═══════════════════════════════════════════
# GRAPH RESET + CONSTRUCTION
# ═══════════════════════════════════════════

"""Map a raw onboarding payload dict onto the CreditProfile graph. Updates
the existing profile and its account-level children (cards, loans, age,
mix, inquiries) in place rather than deleting the whole subgraph - actions,
simulation results, factor assessments, and chat history are left alone
here (each has its own dedicated recompute/cleanup) so re-onboarding never
risks a wide, cascading delete across the profile's entire subgraph."""
def _build_credit_graph(payload: dict) -> CreditProfile {
    existing = [root -->][?:CreditProfile];

    if len(existing) > 0 {
        profile = existing[0];
        for acct in [profile ->:HasAccount:->] {
            for hist in [acct -->][?:PaymentHistory] { del hist; }
            del acct;
        }
        for age in [profile ->:HasAge:->][?:AccountAge] { del age; }
        for mix in [profile ->:HasMix:->][?:CreditMix] { del mix; }
        for inq in [profile ->:HasInquiry:->][?:HardInquiry] { del inq; }

        profile.name = str(payload.get("name", "Friend"));
        profile.current_score = int(payload.get("current_score", 580));
        profile.target_score = int(payload.get("target_score", 680));
        profile.monthly_income = float(payload.get("monthly_income", 0.0));
        profile.monthly_cost_of_living = float(payload.get("monthly_cost_of_living", 0.0));
        profile.savings_balance = float(payload.get("savings_balance", 0.0));
        profile.investment_balance = float(payload.get("investment_balance", 0.0));
    } else {
        profile = CreditProfile(
            name=str(payload.get("name", "Friend")),
            current_score=int(payload.get("current_score", 580)),
            target_score=int(payload.get("target_score", 680)),
            created_at=_get_current_date(),
            score_model="FICO 8",
            monthly_income=float(payload.get("monthly_income", 0.0)),
            monthly_cost_of_living=float(payload.get("monthly_cost_of_living", 0.0)),
            savings_balance=float(payload.get("savings_balance", 0.0)),
            investment_balance=float(payload.get("investment_balance", 0.0))
        );
        root ++> profile;
    }

    num_auto = 0;
    num_student = 0;
    num_installment = 0;
    num_mortgage = 0;

    cards_in: list[dict] = payload.get("cards", []);
    loans_in: list[dict] = payload.get("loans", []);

    for card in cards_in {
        card_limit = float(card.get("limit", 0.0));
        card_balance = float(card.get("balance", 0.0));
        card_late_30 = int(card.get("late_30", 0));
        card_late_60 = int(card.get("late_60", 0));
        card_late_90 = int(card.get("late_90", 0));
        card_name = str(card.get("name", ""));
        util = (card_balance / card_limit * 100.0) if card_limit > 0.0 else 0.0;
        card_node = CreditCard(
            card_name=card_name,
            credit_limit=card_limit,
            current_balance=card_balance,
            utilization_pct=util,
            min_payment=round(card_balance * 0.02, 2) if card_balance > 25.0 else 25.0,
            apr=float(card.get("apr", 24.99)),
            is_authorized_user=bool(card.get("is_au", False)),
            has_late_payment=card_late_30 > 0 or card_late_60 > 0 or card_late_90 > 0
        );
        profile +>:HasAccount(weight=card_limit):+> card_node;

        if card_late_30 > 0 or card_late_60 > 0 or card_late_90 > 0 {
            hist = PaymentHistory(
                account_name=card_name,
                on_time_pct=85.0,
                late_payments_30=card_late_30,
                late_payments_60=card_late_60,
                late_payments_90=card_late_90
            );
            card_node +>:HasHistory():+> hist;
        }
    }

    for loan in loans_in {
        loan_type = str(loan.get("loan_type", "personal"));
        loan_balance = float(loan.get("balance", 0.0));
        if loan_type == "auto" { num_auto = num_auto + 1; }
        if loan_type == "student" { num_student = num_student + 1; }
        if loan_type == "mortgage" { num_mortgage = num_mortgage + 1; }
        else { num_installment = num_installment + 1; }

        loan_node = Loan(
            loan_type=loan_type,
            original_amount=loan_balance * 1.2,
            current_balance=loan_balance,
            monthly_payment=float(loan.get("payment", 0.0)),
            apr=float(loan.get("apr", 6.0)),
            months_remaining=60
        );
        profile +>:HasAccount():+> loan_node;
    }

    for i in range(int(payload.get("num_inquiries", 0))) {
        inq_node = HardInquiry(
            creditor="Unnamed creditor",
            inquiry_date=_get_current_date(),
            inquiry_type="credit_card",
            months_old=6
        );
        profile +>:HasInquiry():+> inq_node;
    }

    history_months = int(float(payload.get("credit_history_years", 2.0)) * 12.0);
    age_node = AccountAge(
        oldest_account_months=history_months,
        average_age_months=int(history_months * 0.6),
        newest_account_months=min(6, int(history_months / 4))
    );
    profile +>:HasAge():+> age_node;

    mix_node = CreditMix(
        num_credit_cards=len(cards_in),
        num_installment_loans=num_installment,
        num_mortgage=num_mortgage,
        has_auto_loan=num_auto > 0,
        has_student_loan=num_student > 0
    );
    profile +>:HasMix():+> mix_node;

    # No-op unless the profile already has an iMessage handle connected -
    # re-applies the grant to the freshly rebuilt cards/loans, since grants
    # are per-node and the old account nodes (and their grants) were just
    # deleted/replaced above.
    grant_imessage_write_access(profile);

    return profile;
}

# ═══════════════════════════════════════════
# CLIENT-FACING ENDPOINTS
# ═══════════════════════════════════════════

"""Bundle the caller's entire credit graph into one wire payload."""
def:protect get_dashboard_data -> DashboardBundle {
    profiles = [root -->][?:CreditProfile];
    if len(profiles) == 0 {
        return DashboardBundle();
    }
    profile = profiles[0];
    cards = [profile ->:HasAccount:->][?:CreditCard];
    loans = [profile ->:HasAccount:->][?:Loan];
    actions = [profile -->][?:Action];

    if len(actions) == 0 {
        # Backfills profiles where the discovery agent's ReAct call completed
        # without error but its structured output silently parsed to an empty
        # list - the fallback generator always yields at least one action, so
        # an empty list here is never actually correct.
        compute_and_store_discovered_actions();
        actions = [profile -->][?:Action];
        optimize_path();
    }

    results = [profile ->:ProducesResult:->][?:SimulationResult];
    latest = results[-1] if len(results) > 0 else None;
    messages = [profile ->:HasMessage:->][?:ChatMessage];
    ages = [profile ->:HasAge:->][?:AccountAge];
    mixes = [profile ->:HasMix:->][?:CreditMix];
    factor_sets = [profile ->:HasFactorAssessment:->][?:FactorAssessmentSet];

    needs_recompute = len(factor_sets) == 0 or not valid_factor_assessments(factor_sets[0].assessments);
    if needs_recompute {
        # Backfills profiles onboarded before the factors agent existed, where
        # a prior run never finished, or where a malformed agent response got
        # persisted (empty/duplicate factors) - instead of leaving the panel
        # stuck showing junk or "Analyzing..." forever.
        compute_and_store_factor_assessments();
        factor_sets = [profile ->:HasFactorAssessment:->][?:FactorAssessmentSet];
    }

    return DashboardBundle(
        has_profile=True,
        profile=profile,
        cards=cards,
        loans=loans,
        actions=actions,
        account_age=ages[0] if len(ages) > 0 else None,
        credit_mix=mixes[0] if len(mixes) > 0 else None,
        latest_result=latest,
        factor_assessments=factor_sets[0].assessments if len(factor_sets) > 0 else [],
        chat_messages=messages
    );
}

"""Reconstruct the original onboarding payload shape from the current graph,
so the onboarding wizard can be reopened pre-filled for editing."""
def:protect get_edit_payload -> dict {
    profiles = [root -->][?:CreditProfile];
    if len(profiles) == 0 { return {}; }
    profile = profiles[0];

    cards = [profile ->:HasAccount:->][?:CreditCard];
    loans = [profile ->:HasAccount:->][?:Loan];
    ages = [profile ->:HasAge:->][?:AccountAge];
    inquiries = [profile ->:HasInquiry:->][?:HardInquiry];

    cards_out: list[dict] = [];
    for c in cards {
        late_30 = 0;
        hists = [c ->:HasHistory:->][?:PaymentHistory];
        if len(hists) > 0 { late_30 = hists[0].late_payments_30; }
        cards_out.append({
            "name": c.card_name,
            "limit": c.credit_limit,
            "balance": c.current_balance,
            "apr": c.apr,
            "is_au": c.is_authorized_user,
            "late_30": late_30
        });
    }

    loans_out: list[dict] = [];
    for l in loans {
        loans_out.append({
            "loan_type": l.loan_type,
            "balance": l.current_balance,
            "payment": l.monthly_payment
        });
    }

    history_years = 2.0;
    if len(ages) > 0 { history_years = ages[0].oldest_account_months / 12.0; }

    return {
        "name": profile.name,
        "current_score": profile.current_score,
        "target_score": profile.target_score,
        "monthly_income": profile.monthly_income,
        "monthly_cost_of_living": profile.monthly_cost_of_living,
        "savings_balance": profile.savings_balance,
        "investment_balance": profile.investment_balance,
        "credit_history_years": history_years,
        "num_inquiries": len(inquiries),
        "cards": cards_out,
        "loans": loans_out
    };
}

"""Build the graph, discover actions, plan the optimal path - one call."""
def:protect submit_onboarding(payload: dict) -> DashboardBundle {
    _build_credit_graph(payload);
    try {
        compute_and_store_discovered_actions();
    } except Exception {}
    try {
        optimize_path();
    } except Exception {}
    try {
        compute_and_store_factor_assessments();
    } except Exception {}
    return get_dashboard_data();
}

"""Re-plan the optimal path against the existing graph (no rebuild)."""
def:protect rerun_simulation -> DashboardBundle {
    optimize_path();
    return get_dashboard_data();
}

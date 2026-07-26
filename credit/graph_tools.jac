"""LumiNode - Shared graph read-tools.

Small, focused query functions over the caller's credit graph - the "toolbox"
every agent in credit/*_agent.jac pulls from instead of each re-implementing
its own copy of the same reads. Each agent still decides for itself which of
these to call and when; this module only owns the data-access layer.
"""

import from .model {
    CreditProfile, CreditCard, Loan, PaymentHistory, CreditMix, AccountAge, HardInquiry,
    HasAccount, HasHistory, HasMix, HasAge, HasInquiry
}

def _tool_read_cards() -> list[dict] {
    profiles = [root -->][?:CreditProfile];
    if len(profiles) == 0 { return []; }
    cards = [profiles[0] ->:HasAccount:->][?:CreditCard];
    return [
        {
            "name": c.card_name, "limit": c.credit_limit, "balance": c.current_balance,
            "utilization_pct": c.utilization_pct, "apr": c.apr, "is_authorized_user": c.is_authorized_user
        }
        for c in cards
    ];
}
sem _tool_read_cards = "Read every credit card on this person's profile, with balance/limit/utilization/APR.";

def _tool_read_loans() -> list[dict] {
    profiles = [root -->][?:CreditProfile];
    if len(profiles) == 0 { return []; }
    loans = [profiles[0] ->:HasAccount:->][?:Loan];
    return [
        {"loan_type": l.loan_type, "balance": l.current_balance, "payment": l.monthly_payment, "apr": l.apr}
        for l in loans
    ];
}
sem _tool_read_loans = "Read every installment loan (student, auto, personal, mortgage) on this person's profile.";

def _tool_read_payment_history() -> list[dict] {
    profiles = [root -->][?:CreditProfile];
    if len(profiles) == 0 { return []; }
    cards = [profiles[0] ->:HasAccount:->][?:CreditCard];
    out: list[dict] = [];
    for c in cards {
        for h in [c ->:HasHistory:->][?:PaymentHistory] {
            out.append({
                "account_name": h.account_name, "on_time_pct": h.on_time_pct,
                "late_30": h.late_payments_30, "late_60": h.late_payments_60, "late_90": h.late_payments_90
            });
        }
    }
    return out;
}
sem _tool_read_payment_history = "Read late-payment history for every account that has any on-time or delinquency data.";

def _tool_read_credit_mix() -> dict {
    profiles = [root -->][?:CreditProfile];
    if len(profiles) == 0 { return {}; }
    mixes = [profiles[0] ->:HasMix:->][?:CreditMix];
    if len(mixes) == 0 { return {}; }
    m = mixes[0];
    return {
        "num_credit_cards": m.num_credit_cards, "num_installment_loans": m.num_installment_loans,
        "num_mortgage": m.num_mortgage, "has_auto_loan": m.has_auto_loan, "has_student_loan": m.has_student_loan
    };
}
sem _tool_read_credit_mix = "Read the diversity of account types this person holds (cards, loans, mortgage).";

def _tool_read_account_age() -> dict {
    profiles = [root -->][?:CreditProfile];
    if len(profiles) == 0 { return {}; }
    ages = [profiles[0] ->:HasAge:->][?:AccountAge];
    if len(ages) == 0 { return {}; }
    a = ages[0];
    return {
        "oldest_account_months": a.oldest_account_months,
        "average_age_months": a.average_age_months,
        "newest_account_months": a.newest_account_months
    };
}
sem _tool_read_account_age = "Read the age summary (oldest/average/newest account) for this person's credit history.";

def _tool_read_inquiries() -> list[dict] {
    profiles = [root -->][?:CreditProfile];
    if len(profiles) == 0 { return []; }
    inquiries = [profiles[0] ->:HasInquiry:->][?:HardInquiry];
    return [{"creditor": i.creditor, "months_old": i.months_old} for i in inquiries];
}
sem _tool_read_inquiries = "Read every hard inquiry on this person's report and how many months old each one is.";

def _tool_read_income_summary() -> dict {
    profiles = [root -->][?:CreditProfile];
    if len(profiles) == 0 { return {}; }
    p = profiles[0];
    return {
        "monthly_income": p.monthly_income,
        "monthly_cost_of_living": p.monthly_cost_of_living,
        "savings_balance": p.savings_balance,
        "investment_balance": p.investment_balance
    };
}
sem _tool_read_income_summary = "Read this person's monthly income, cost of living, savings, and investment balance.";

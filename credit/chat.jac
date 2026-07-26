"""LumiNode - Conversational Financial Assistant.

`_generate_agent_reply` gathers the full financial context off the graph -
cards, loans, pending actions, latest simulation - then answers the user's
question with that context in hand. This is the single source of truth for
the assistant's behavior: both the website chat panel (`send_chat_message`)
and the iMessage integration (`credit/imessage.jac`) call this same function,
so the two surfaces never drift apart.
"""

import from .model {
    CreditProfile, CreditCard, Loan, Action, SimulationResult, ChatMessage,
    HasAccount, ProducesResult, HasMessage, _get_current_date
}
import from rag.agent { run_rag_agent }

"""Tool: looks up general credit-scoring education from the RAG knowledge base.
Chat is the unscoped surface - all four knowledge files (factors, discovered-
actions, 90-day, chat) are eligible, unlike the discovered-actions/ninety-day
agents which hard-filter to their own file."""
def search_credit_knowledge(query: str) -> str {
    result = run_rag_agent(query, agent_scope="chat");
    return result.answer;
}
sem search_credit_knowledge = """
Look up general credit-scoring education (FICO/VantageScore factors, hard vs
soft inquiries, derogatory marks, how the score itself works) from the
knowledge base. Use this for "what is/how does X work" questions - not for
questions about the user's own account numbers, which you already have.
""";
sem search_credit_knowledge.query = "A focused search query for the credit-scoring knowledge base.";

obj AgentReply {
    has reply: str,
        has_score_update: bool = False,
        updated_score: int = 0,
        has_card_update: bool = False,
        updated_card_name: str = "",
        updated_card_balance: float = 0.0,
        has_income_update: bool = False,
        updated_income: float = 0.0,
        has_cost_of_living_update: bool = False,
        updated_cost_of_living: float = 0.0,
        has_savings_update: bool = False,
        updated_savings: float = 0.0,
        has_investment_update: bool = False,
        updated_investment: float = 0.0;
}
sem AgentReply = "The assistant's reply, plus any account update(s) it detected in the user's message - credit score, a specific card's balance, income, cost of living, savings, or investments.";
sem AgentReply.has_score_update = "True only if the user just told you their current credit score changed (e.g. 'my score is 620 now').";
sem AgentReply.updated_score = "The new credit score value, only meaningful when has_score_update is True.";
sem AgentReply.has_card_update = "True only if the user just told you one of their card balances changed (e.g. 'my Visa balance is now $1000').";
sem AgentReply.updated_card_name = "The card name as it appears in their real card list (from financial_context['cards']), matched to whichever card they mentioned.";
sem AgentReply.updated_card_balance = "The new balance for that card, only meaningful when has_card_update is True.";
sem AgentReply.has_income_update = "True only if the user just told you their monthly income changed.";
sem AgentReply.updated_income = "The new monthly income, only meaningful when has_income_update is True.";
sem AgentReply.has_cost_of_living_update = "True only if the user just told you their monthly cost of living/expenses changed.";
sem AgentReply.updated_cost_of_living = "The new monthly cost of living, only meaningful when has_cost_of_living_update is True.";
sem AgentReply.has_savings_update = "True only if the user just told you their savings balance changed.";
sem AgentReply.updated_savings = "The new savings balance, only meaningful when has_savings_update is True.";
sem AgentReply.has_investment_update = "True only if the user just told you their investment balance changed.";
sem AgentReply.updated_investment = "The new investment balance, only meaningful when has_investment_update is True.";

def answer_financial_question(
    question: str,
    financial_context: dict
) -> AgentReply by llm(tools=[search_credit_knowledge]);
sem answer_financial_question = """
You are LumiNode, a friendly financial assistant for low-income users.
You have access to the user's complete credit profile and financial data,
and a search_credit_knowledge tool for general credit-scoring education.

Rules:
- Use simple, clear language. No jargon.
- Be specific with numbers from their actual data.
- For "can I afford X?" questions, consider their total debt and upcoming payments.
- For credit score questions about their OWN account, reference their actual credit factors and pending actions.
- For general "how does X work" questions, call search_credit_knowledge instead of guessing.
- Always be encouraging but honest.
- Keep responses concise (2-3 sentences for simple questions, a short paragraph for complex ones) -
  this reply may be read as a text message, so avoid long paragraphs or markdown formatting.
- If they ask about something outside their financial data, be helpful but note your limitations.

Separately from the reply text, detect any of these the user is reporting as their NEW current
value (not a target, a hypothetical, or a question) and set the matching fields:
- Credit score changed (e.g. "my score is 620 now", "just checked, I'm at 700") -> has_score_update,
  updated_score.
- A specific card's balance changed (e.g. "my Visa balance is now $1000", "I paid my Discover card
  down to $200") -> has_card_update, updated_card_name (match it to the real name in
  financial_context['cards'], not whatever short name they used), updated_card_balance.
- Monthly income changed -> has_income_update, updated_income.
- Monthly cost of living / expenses changed -> has_cost_of_living_update, updated_cost_of_living.
- Savings balance changed -> has_savings_update, updated_savings.
- Investment balance changed -> has_investment_update, updated_investment.
Leave every has_*_update field False unless its condition is clearly met - never guess a value.
Multiple can be true at once if they reported more than one change in the same message.
""";

"""Deterministic stand-in used when no LLM key is configured."""
def _fallback_chat_response(question: str, context: dict) -> AgentReply {
    score = context["current_score"];
    target = context["target_score"];
    total_debt = context["total_debt"];
    pending = context["pending_actions"];
    discretionary = context["discretionary_income"];
    savings = context["savings_balance"];
    q = question.lower();

    if "afford" in q {
        if context["monthly_income"] > 0.0 {
            return AgentReply(reply=(
                f"After your bills and minimum payments, you have about ${discretionary:.0f} left over each month, "
                + f"plus ${savings:.0f} in savings. "
                + "Before taking on a new payment, make sure it doesn't push any card over 30% utilization - "
                + "that's the fastest way to undo progress toward your target score."
            ));
        }
        return AgentReply(reply=(
            f"You're carrying ${total_debt:.0f} in total debt right now. "
            + "Before taking on a new payment, make sure it doesn't push any card over 30% utilization - "
            + "that's the fastest way to undo progress toward your target score."
        ));
    }
    if "pay" in q or "first" in q {
        if len(pending) > 0 {
            top = pending[0];
            return AgentReply(reply=f"Start with: {top['desc']} - it's estimated to move your score by {top['impact']} points.");
        }
        return AgentReply(reply="You don't have any pending actions queued up yet - run a simulation first.");
    }
    if "when" in q or "how long" in q {
        return AgentReply(reply=f"Your current score is {score} and your target is {target}. Run a simulation to see the fastest projected timeline.");
    }
    return AgentReply(reply=(
        f"Your score is currently {score}, and you're aiming for {target}. "
        + f"You're carrying ${total_debt:.0f} in total debt across your accounts. "
        + "Ask me things like \"how do I get to my target?\" or \"what should I pay first?\" "
        + "(connect an LLM key for fully personalized answers)."
    ));
}

"""Builds the same financial-context dict the agent reasons over, regardless
of which surface (website chat or iMessage) is asking."""
def _build_financial_context(profile: CreditProfile) -> dict {
    cards = [profile ->:HasAccount:->][?:CreditCard];
    loans = [profile ->:HasAccount:->][?:Loan];
    actions = [profile -->][?:Action];
    results = [profile ->:ProducesResult:->][?:SimulationResult];

    total_debt = sum([c.current_balance for c in cards]) + sum([l.current_balance for l in loans]);
    monthly_min_payments = sum([c.min_payment for c in cards]) + sum([l.monthly_payment for l in loans]);
    discretionary_income = profile.monthly_income - profile.monthly_cost_of_living - monthly_min_payments;

    return {
        "current_score": profile.current_score,
        "target_score": profile.target_score,
        "cards": [
            {"name": c.card_name, "balance": c.current_balance, "limit": c.credit_limit, "utilization": c.utilization_pct}
            for c in cards
        ],
        "loans": [
            {"type": l.loan_type, "balance": l.current_balance, "payment": l.monthly_payment}
            for l in loans
        ],
        "total_debt": total_debt,
        "monthly_income": profile.monthly_income,
        "monthly_cost_of_living": profile.monthly_cost_of_living,
        "discretionary_income": discretionary_income,
        "savings_balance": profile.savings_balance,
        "investment_balance": profile.investment_balance,
        "pending_actions": [
            {"desc": a.description, "impact": a.estimated_score_impact} for a in actions if not a.completed
        ],
        "projections": [
            {"path": r.path_name, "projected": r.projected_score, "days": r.total_days} for r in results
        ]
    };
}

"""The one place that actually asks the assistant a question and gets an
answer back - context-building, the LLM call, and its deterministic fallback.
Shared by every entry point (website chat, iMessage) so they can never
answer the same question differently."""
def _generate_agent_reply(message: str, profile: CreditProfile) -> AgentReply {
    context = _build_financial_context(profile);
    try {
        return answer_financial_question(question=message, financial_context=context);
    } except Exception {
        return _fallback_chat_response(message, context);
    }
}

"""Writes every update the agent detected in `reply` onto the real graph -
credit score, a specific card's balance, income, cost of living, savings, or
investments. Shared by every entry point so a change reported over iMessage
shows up on the dashboard exactly like one typed in the website chat."""
def _apply_agent_update(profile: CreditProfile, reply: AgentReply) -> None {
    if reply.has_score_update {
        profile.current_score = reply.updated_score;
    }
    if reply.has_income_update {
        profile.monthly_income = reply.updated_income;
    }
    if reply.has_cost_of_living_update {
        profile.monthly_cost_of_living = reply.updated_cost_of_living;
    }
    if reply.has_savings_update {
        profile.savings_balance = reply.updated_savings;
    }
    if reply.has_investment_update {
        profile.investment_balance = reply.updated_investment;
    }
    if reply.has_card_update and reply.updated_card_name.strip() {
        target_name = reply.updated_card_name.strip().lower();
        for c in [profile ->:HasAccount:->][?:CreditCard] {
            existing_name = c.card_name.lower();
            if target_name in existing_name or existing_name in target_name {
                c.current_balance = reply.updated_card_balance;
                if c.credit_limit > 0.0 {
                    c.utilization_pct = c.current_balance / c.credit_limit * 100.0;
                }
            }
        }
    }
}

"""Save the user's message, answer it with full graph context, save the reply."""
def:protect send_chat_message(message: str) -> list[ChatMessage] {
    profiles = [root -->][?:CreditProfile];
    if len(profiles) == 0 { return []; }
    profile = profiles[0];

    user_msg = ChatMessage(role="user", content=message, timestamp=_get_current_date());
    profile +>:HasMessage():+> user_msg;

    reply = _generate_agent_reply(message, profile);
    _apply_agent_update(profile, reply);

    assistant_msg = ChatMessage(role="assistant", content=reply.reply, timestamp=_get_current_date());
    profile +>:HasMessage():+> assistant_msg;

    return [profile ->:HasMessage:->][?:ChatMessage];
}

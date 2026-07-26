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
        updated_score: int = 0;
}
sem AgentReply = "The assistant's reply, plus any credit-score update it detected in the user's message.";
sem AgentReply.has_score_update = "True only if the user just told you their current credit score changed (e.g. 'my score is 620 now').";
sem AgentReply.updated_score = "The new credit score value, only meaningful when has_score_update is True.";

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

Separately from the reply text: if the user's message states their credit score has changed
(e.g. "my score is 620 now", "just checked, I'm at 700", "credit score updated to 580"), set
has_score_update to True and updated_score to that number. Only do this when they're reporting
an actual current score, not when discussing a target, a hypothetical, or someone else's score.
Otherwise leave has_score_update False.
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

"""Save the user's message, answer it with full graph context, save the reply."""
def:protect send_chat_message(message: str) -> list[ChatMessage] {
    profiles = [root -->][?:CreditProfile];
    if len(profiles) == 0 { return []; }
    profile = profiles[0];

    user_msg = ChatMessage(role="user", content=message, timestamp=_get_current_date());
    profile +>:HasMessage():+> user_msg;

    reply = _generate_agent_reply(message, profile);
    if reply.has_score_update {
        profile.current_score = reply.updated_score;
    }

    assistant_msg = ChatMessage(role="assistant", content=reply.reply, timestamp=_get_current_date());
    profile +>:HasMessage():+> assistant_msg;

    return [profile ->:HasMessage:->][?:ChatMessage];
}

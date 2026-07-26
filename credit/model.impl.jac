"""LumiNode - CreditProfile ability bodies.

Split from model.jac so the model itself doesn't need to import the chat
agent at module-load time. See credit/imessage.jac for the walker that
visits CreditProfile to trigger accept_imessage_write.
"""

impl CreditProfile.accept_imessage_write with entry {
    # Deferred (in-body) imports - a module-top import here creates a real
    # circular import at Python runtime (model.impl.jac -> chat.jac/imessage.jac
    # -> model.jac, since this impl file loads as part of credit.model). By the
    # time this ability actually runs, all modules have long finished loading,
    # so importing here instead of at module scope is what breaks the cycle.
    # jac check doesn't catch this - it only crashes the server process at
    # import time, silently, with no HTTP-visible error.
    import from .chat { _generate_agent_reply, _apply_agent_update }
    import from .imessage { _send_imessage_reply }

    caller: any = visitor;
    text: str = str(caller.pending_user_text or "");
    if text {
        reply = _generate_agent_reply(text, self);

        user_msg = ChatMessage(role="user", content=text, timestamp=_get_current_date());
        self +>:HasMessage():+> user_msg;

        _apply_agent_update(self, reply);

        assistant_msg = ChatMessage(role="assistant", content=reply.reply, timestamp=_get_current_date());
        self +>:HasMessage():+> assistant_msg;

        # Send right here rather than handing the reply back to a separate
        # walker-side "on arrival" ability - that ordering isn't guaranteed
        # relative to this node ability, and in testing it fired first (before
        # the reply existed), so the send silently never happened.
        chat_guid = str(caller.pending_chat_guid or "");
        address = str(caller.pending_address or "");
        if chat_guid {
            _send_imessage_reply(chat_guid, reply.reply, address);
        }
    }
}

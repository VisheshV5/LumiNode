"""LumiNode - iMessage-style financial chat sidebar."""

sv import from .model { ChatMessage }

def:pub ChatPanel(
    messages: list[ChatMessage],
    sending: bool,
    onSend: Callable[[str], None],
    onClose: Callable[[MouseEvent], None]
) -> JsxElement {
    has draft: str = "";

    def submit {
        text = draft.strip();
        if not text { return; }
        onSend(text);
        draft = "";
    }

    def handleKey(e: KeyboardEvent) {
        if e.key == "Enter" { submit(); }
    }

    suggestions = [
        "Can I afford a $500 TV?",
        "How do I get to my target score?",
        "What should I pay first?",
        "When will my score improve?"
    ];

    return <aside className="lumi-chat-panel lumi-fade-in">
        <div className="lumi-chat-header">
            <span>LumiNode Assistant</span>
            <button className="lumi-chat-close" onClick={onClose}>✕</button>
        </div>
        <div className="lumi-chat-messages">
            {if len(messages) == 0 {
                <p className="lumi-chat-empty">Ask me anything about your money.</p>
            }}
            {for (i, m) in enumerate(messages) {
                <div
                    key={str(i)}
                    className={"lumi-bubble " + ("lumi-bubble-user" if m.role == "user" else "lumi-bubble-assistant")}
                >
                    {m.content}
                </div>
            }}
            {if sending {
                <div className="lumi-bubble lumi-bubble-assistant lumi-typing">
                    <span className="lumi-typing-dot"/>
                    <span className="lumi-typing-dot"/>
                    <span className="lumi-typing-dot"/>
                </div>
            }}
        </div>
        <div className="lumi-chat-suggestions">
            {for s in suggestions {
                <button key={s} className="lumi-chip" onClick={lambda (e: MouseEvent) { onSend(s); }}>{s}</button>
            }}
        </div>
        <div className="lumi-chat-input-row">
            <input
                className="lumi-chat-input"
                placeholder="Ask a question…"
                value={draft}
                onChange={lambda (e: ChangeEvent) { draft = e.target.value; }}
                onKeyPress={handleKey}
            />
            <button className="lumi-chat-send" onClick={lambda (e: MouseEvent) { submit(); }} disabled={sending}>➤</button>
        </div>
    </aside>;
}

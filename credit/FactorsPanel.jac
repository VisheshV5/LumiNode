"""LumiNode - Score factors panel + discovered-actions ripple explorer.

The factor verdicts (tone/headline/explanation) come from the agentic
factors_agent.jac on the server now - this component only renders them.
"""

sv import from .model { CreditProfile, CreditCard, Loan, Action, FactorAssessment }
sv import from .ripple { run_ripple_simulation, RippleEffect }

def factor_tone_class(tone: str) -> str {
    if tone == "good" { return "lumi-factor-good"; }
    if tone == "bad" { return "lumi-factor-bad"; }
    return "lumi-factor-warn";
}

def:pub FactorsPanel(
    profile: CreditProfile,
    cards: list[CreditCard],
    loans: list[Loan],
    actions: list[Action],
    factorAssessments: list[FactorAssessment]
) -> JsxElement {
    has expandedId: str = "",
        rippleEffects: list[RippleEffect] = [],
        rippleLoading: bool = False;

    async def toggleRipple(actionId: str) -> None {
        if expandedId == actionId {
            expandedId = "";
            return;
        }
        expandedId = actionId;
        rippleLoading = True;
        rippleEffects = await run_ripple_simulation(actionId);
        rippleLoading = False;
    }

    return <aside className="lumi-factors-panel">
        <h2 className="lumi-panel-title">Score Factors</h2>

        {if len(factorAssessments) == 0 {
            <p className="lumi-factor-loading">Analyzing your credit factors…</p>
        }}
        {for fa in factorAssessments {
            <div key={fa.factor_name} className={"lumi-factor-card " + factor_tone_class(fa.tone)}>
                <div className="lumi-factor-head">
                    <span className="lumi-factor-name">{fa.factor_name}</span>
                    <span className="lumi-factor-value">{fa.headline}</span>
                </div>
                <p className="lumi-factor-desc">{fa.explanation}</p>
            </div>
        }}

        <h3 className="lumi-panel-subtitle">Discovered Actions ({len(actions)})</h3>
        <div className="lumi-actions-list">
            {for a in actions {
                <div key={jid(a)} className="lumi-discovered-action">
                    <div className="lumi-discovered-head" onClick={lambda (e: MouseEvent) { toggleRipple(jid(a)); }}>
                        <span className={"lumi-impact-badge " + ("lumi-impact-pos" if a.estimated_score_impact >= 0 else "lumi-impact-neg")}>
                            {("+" + str(a.estimated_score_impact)) if a.estimated_score_impact >= 0 else str(a.estimated_score_impact)}
                        </span>
                        <span className="lumi-discovered-desc">{a.description}</span>
                        <span className="lumi-discovered-chevron">{"−" if expandedId == jid(a) else "+"}</span>
                    </div>
                    {if expandedId == jid(a) {
                        <div className="lumi-ripple-box lumi-fade-in">
                            {if rippleLoading {
                                <p className="lumi-ripple-loading">Tracing ripple effects…</p>
                            }}
                            {if not rippleLoading {
                                for r in rippleEffects {
                                    <div key={r.affected_factor} className="lumi-ripple-item">
                                        <span className="lumi-ripple-factor">{r.affected_factor}</span>
                                        <p className="lumi-ripple-explain">{r.explanation}</p>
                                    </div>
                                }
                            }}
                        </div>
                    }}
                </div>
            }}
        </div>
    </aside>;
}

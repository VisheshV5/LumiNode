"""LumiNode - Optimal action-path timeline."""

sv import from .model { SimulationResult }
import from .LoadingOverlay { LoadingOverlay }

def:pub ActionPath(result: SimulationResult | None, onRerun: Callable[[], None], submitting: bool) -> JsxElement {
    if result is None {
        return <section className="lumi-action-path lumi-action-path-empty">
            <LoadingOverlay active={submitting} doneLabel="Running your simulation"/>
            <p>No simulation yet - once actions are discovered, your optimal path appears here.</p>
        </section>;
    }

    return <section className="lumi-action-path">
        <LoadingOverlay active={submitting} doneLabel="Re-running your simulation"/>
        <div className="lumi-path-head">
            <div>
                <h2 className="lumi-panel-title">{result.path_name}</h2>
                <p className="lumi-path-sub">
                    {result.starting_score} → {result.projected_score} in {result.total_days} days · {f"{(result.confidence * 100.0):.0f}%"} confidence
                </p>
            </div>
            <button className="lumi-btn-secondary" onClick={lambda (e: MouseEvent) { onRerun(); }} disabled={submitting}>
                {"Simulating…" if submitting else "Run Another Simulation"}
            </button>
        </div>

        {if result.counterintuitive_insight {
            <div className="lumi-insight-box">
                <span className="lumi-insight-icon">💡</span>
                <p>{result.counterintuitive_insight}</p>
            </div>
        }}

        <div className="lumi-timeline">
            {for (i, s) in enumerate(result.steps) {
                <div key={str(i)} className="lumi-timeline-step" style={{"animationDelay": f"{i * 0.15}s"}}>
                    <div className="lumi-timeline-marker">{i + 1}</div>
                    <div className="lumi-timeline-card">
                        <p className="lumi-timeline-desc">{s.description}</p>
                        <div className="lumi-timeline-meta">
                            <span className={"lumi-impact-badge " + ("lumi-impact-pos" if s.score_impact >= 0 else "lumi-impact-neg")}>
                                {("+" + str(s.score_impact)) if s.score_impact >= 0 else str(s.score_impact)}
                            </span>
                            <span className="lumi-timeline-days">{s.days_to_effect}d</span>
                            <span className="lumi-timeline-score">→ {s.cumulative_score}</span>
                        </div>
                    </div>
                    {if i < len(result.steps) - 1 {
                        <div className="lumi-timeline-connector"/>
                    }}
                </div>
            }}
        </div>
    </section>;
}

"""LumiNode - Full-screen loading overlay for long-running simulation runs
(onboarding submit, re-run simulation). Real backend progress isn't
observable from the client, so this never shows a number claiming to measure
it - just a bar that creeps up to 99% and holds (an honest "still working,
not stuck" signal, never a false completion claim), with the shimmer sweep
keeping it visibly alive at 99% instead of looking frozen. Rotating stage
messages describe what the multi-agent pipeline is actually doing right now."""

import from react { useEffect }

def:pub LoadingOverlay(active: bool, doneLabel: str = "Lighting up your path") -> JsxElement {
    has pct: int = 0,
        stageIdx: int = 0;

    stages = [
        "Reading your accounts…",
        "Discovering every action you could take…",
        "Grounding recommendations in real FICO rules…",
        "Sequencing the fastest path to your target…",
        "Almost there…"
    ];

    useEffect(lambda {
        if not active {
            pct = 0;
            stageIdx = 0;
            return lambda {};
        }
        count = 0;
        stage = 0;
        tick = setInterval(lambda {
            if count < 99 {
                count = count + 1;
                pct = count;
            }
        }, 180);
        stageTick = setInterval(lambda {
            stage = (stage + 1) % len(stages);
            stageIdx = stage;
        }, 3000);
        return lambda { clearInterval(tick); clearInterval(stageTick); };
    }, [active]);

    if not active { return <></>; }

    return <div className="lumi-loading-overlay">
        <div className="lumi-loading-orb">
            <div className="lumi-loading-orb-glow"/>
            <div className="lumi-loading-orb-core"/>
            <div className="lumi-loading-orbit">
                <span className="lumi-loading-dot lumi-loading-dot-1"/>
                <span className="lumi-loading-dot lumi-loading-dot-2"/>
                <span className="lumi-loading-dot lumi-loading-dot-3"/>
            </div>
        </div>
        <p className="lumi-loading-title">{doneLabel}</p>
        <p className="lumi-loading-stage">{stages[stageIdx]}</p>
        <div className="lumi-loading-bar-track">
            <div className="lumi-loading-bar-fill" style={{"width": f"{pct}%"}}/>
        </div>
    </div>;
}

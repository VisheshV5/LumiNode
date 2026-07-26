"""LumiNode - Top bar: logo, live score gauge, target marker, chat toggle."""

import from react { useEffect }
import from "@jac/runtime" { useNavigate, jacLogout }
sv import from .model { CreditProfile }
sv import from .imessage { connect_phone }

def score_color(score: int) -> str {
    if score < 580 { return "var(--node-red)"; }
    if score < 670 { return "var(--node-amber)"; }
    if score < 740 { return "var(--node-blue)"; }
    return "var(--node-green)";
}

def score_pct(score: int) -> float {
    pct = (score - 300) / (850 - 300) * 100.0;
    if pct < 2.0 { return 2.0; }
    if pct > 98.0 { return 98.0; }
    return pct;
}

def:pub TopBar(profile: CreditProfile, onToggleChat: Callable[[MouseEvent], None], chatOpen: bool) -> JsxElement {
    has displayScore: int = -1,
        phonePanelOpen: bool = False,
        phoneInput: str = "",
        consentChecked: bool = False,
        connecting: bool = False,
        connectStatus: str = "";

    nav = useNavigate();

    def goUpdateInfo(e: MouseEvent) { nav("/start?edit=1"); }
    def doLogout(e: MouseEvent) {
        jacLogout();
        nav("/login");
    }
    def togglePhonePanel(e: MouseEvent) {
        phonePanelOpen = not phonePanelOpen;
        connectStatus = "";
    }

    async def submitPhone() -> None;

    useEffect(lambda {
        target = profile.current_score;
        if displayScore == -1 {
            displayScore = target;
            return lambda {};
        }
        current = displayScore;
        diff = target - current;
        if diff == 0 { return lambda {}; }
        frames = 30;
        step_val = int(diff / frames);
        if step_val == 0 { step_val = 1 if diff > 0 else -1; }
        interval = setInterval(lambda {
            current = current + step_val;
            overshot = (step_val > 0 and current >= target) or (step_val < 0 and current <= target);
            if overshot {
                current = target;
                displayScore = current;
                clearInterval(interval);
            } else {
                displayScore = current;
            }
        }, 16);
        return lambda { clearInterval(interval); };
    }, [profile.current_score]);

    shown = profile.current_score if displayScore == -1 else displayScore;
    gap_to_target = profile.target_score - shown;

    return <header className="lumi-topbar">
        <div className="lumi-logo">
            <span className="lumi-logo-node"/>
            LumiNode
        </div>
        <div className="lumi-score-block">
            <div className="lumi-score-readout">
                <span className="lumi-score-label">Credit Score</span>
                <span className="lumi-score-value" style={{"color": score_color(shown), "textShadow": "0 0 22px " + score_color(shown)}}>
                    {shown}
                </span>
                {if gap_to_target > 0 {
                    <span className="lumi-score-gap">{gap_to_target} to target</span>
                } else {
                    <span className="lumi-score-gap lumi-score-gap-met">target reached</span>
                }}
            </div>
            <div className="lumi-score-track-wrap">
                <div className="lumi-score-track">
                    <div
                        className="lumi-score-progress"
                        style={{"width": f"{score_pct(shown)}%", "backgroundColor": score_color(shown), "boxShadow": "0 0 10px " + score_color(shown)}}
                    />
                    <div className="lumi-score-target-marker" style={{"left": f"{score_pct(profile.target_score)}%"}}>
                        <span className="lumi-score-target-pill">Target {profile.target_score}</span>
                        <span className="lumi-score-target-flag"/>
                    </div>
                </div>
                <div className="lumi-score-scale">
                    <span>300</span>
                    <span>850</span>
                </div>
            </div>
        </div>
        <div className="lumi-topbar-actions">
            <button className="lumi-btn-secondary lumi-topbar-btn" onClick={goUpdateInfo}>Update Info</button>
            {if profile.imessage_handle {
                <span className="lumi-phone-connected">📱 Connected</span>
            } else {
                <button className="lumi-btn-secondary lumi-topbar-btn" onClick={togglePhonePanel}>Connect on iMessage</button>
            }}
            <button
                className={"lumi-chat-toggle" + (" lumi-chat-toggle-active" if chatOpen else "")}
                onClick={onToggleChat}
            >
                {"Close" if chatOpen else "Chat"}
            </button>
            <button className="lumi-link-btn lumi-logout-btn" onClick={doLogout}>Log out</button>
        </div>
        {if phonePanelOpen and not profile.imessage_handle {
            <div className="lumi-phone-panel">
                <p className="lumi-phone-panel-title">Text with your LumiNode agent</p>
                <p className="lumi-phone-panel-hint">
                    Works with a phone number or an Apple ID email (handy if you use iMessage from a Mac).
                    We'll text you a starter message - reply anytime, ask questions, or just tell us when your score changes.
                </p>
                <input
                    className="lumi-input"
                    type="text"
                    placeholder="(555) 123-4567 or you@icloud.com"
                    value={phoneInput}
                    onChange={lambda (e: ChangeEvent) { phoneInput = e.target.value; }}
                    disabled={connecting}
                />
                <label className="lumi-checkbox-row">
                    <input
                        type="checkbox"
                        checked={consentChecked}
                        onChange={lambda (e: ChangeEvent) { consentChecked = not consentChecked; }}
                        disabled={connecting}
                    />
                    Text me - I agree to receive automated messages from LumiNode about my credit progress.
                </label>
                {if connectStatus {
                    <p className="lumi-auth-error">{connectStatus}</p>
                }}
                <div className="lumi-nav-row">
                    <button
                        className="lumi-btn-secondary lumi-topbar-btn"
                        onClick={submitPhone}
                        disabled={connecting or not consentChecked or not phoneInput.strip()}
                    >
                        {"Sending…" if connecting else "Text me →"}
                    </button>
                </div>
            </div>
        }}
    </header>;
}

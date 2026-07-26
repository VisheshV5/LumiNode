"""LumiNode - Login route ("/login")."""

import from "@jac/runtime" { useNavigate, jacLogin, jacIsLoggedIn, Navigate, Link }
sv import from ..credit.graph { get_dashboard_data }
import from "../credit/components/magicui/magic-card" { MagicCard }
import from "../credit/components/magicui/border-beam" { BorderBeam }
import from "../credit/components/magicui/shimmer-button" { ShimmerButton }

def:pub page() -> JsxElement {
    has email: str = "",
        password: str = "",
        submitting: bool = False,
        error: str = "";

    nav = useNavigate();

    async def handleLogin() -> None {
        if submitting { return; }
        error = "";
        if not email.strip() or not password {
            error = "Enter your email and password.";
            return;
        }
        submitting = True;

        ok: bool = False;
        bundle: any = None;
        try {
            ok = await jacLogin(email.strip(), password);
            if not ok {
                error = "Invalid email or password.";
                submitting = False;
                return;
            }
            bundle = await get_dashboard_data();  # jac:ignore[E1053]
            submitting = False;
            if bundle.has_profile {
                nav("/dashboard");
            } else {
                nav("/start");
            }
        } except Exception {
            submitting = False;
            error = "Something went wrong. Try again.";
        }
    }

    if jacIsLoggedIn() {
        return <Navigate to="/dashboard" replace={True} />;
    }

    return <div className="lumi-onboarding">
        <p className="lumi-onboarding-hint">Welcome back.</p>

        <div className="lumi-form-card">
        <MagicCard
            className="rounded-[20px] w-full"
            gradientFrom="#F0C850"
            gradientTo="#F5F5F7"
            gradientColor="#1A1A26"
            gradientOpacity={0.6}
        >
            <BorderBeam size={90} duration={7} colorFrom="#F0C850" colorTo="#F5F5F7"/>
            <div className="lumi-form-card-inner">
                <h2 className="lumi-step-title">Log in to LumiNode</h2>

                <div className="lumi-input-labeled">
                    <label>Email</label>
                    <input
                        className="lumi-input"
                        type="email"
                        placeholder="you@example.com"
                        value={email}
                        onChange={lambda (e: ChangeEvent) { email = e.target.value; }}
                    />
                </div>
                <div className="lumi-input-labeled">
                    <label>Password</label>
                    <input
                        className="lumi-input"
                        type="password"
                        placeholder="••••••••"
                        value={password}
                        onChange={lambda (e: ChangeEvent) { password = e.target.value; }}
                    />
                </div>

                {if error {
                    <p className="lumi-auth-error">{error}</p>
                }}

                <div className="lumi-nav-row">
                    <ShimmerButton
                        background="#F0C850"
                        shimmerColor="#0A0A0F"
                        className="text-black font-bold ml-auto"
                        onClick={handleLogin}
                        disabled={submitting}
                    >
                        {"Logging in…" if submitting else "Log in →"}
                    </ShimmerButton>
                </div>

                <p className="lumi-auth-switch">
                    No account yet? <Link to="/signup" className="lumi-link-btn">Sign up</Link>
                </p>
            </div>
        </MagicCard>
        </div>
    </div>;
}

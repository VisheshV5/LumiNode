"""LumiNode - Signup route ("/signup"). Lands on /start right after."""

import from "@jac/runtime" { useNavigate, useLocation, jacSignup, jacLogin, jacIsLoggedIn, Navigate, Link }
import from "../credit/components/magicui/magic-card" { MagicCard }
import from "../credit/components/magicui/border-beam" { BorderBeam }
import from "../credit/components/magicui/shimmer-button" { ShimmerButton }

def:pub page() -> JsxElement {
    has email: str = "",
        password: str = "",
        confirmPassword: str = "",
        submitting: bool = False,
        error: str = "";

    nav = useNavigate();
    location = useLocation();

    async def handleSignup() -> None {
        if submitting { return; }
        error = "";
        if not email.strip() or not password {
            error = "Enter an email and password.";
            return;
        }
        if len(password) < 8 {
            error = "Password must be at least 8 characters.";
            return;
        }
        if password != confirmPassword {
            error = "Passwords don't match.";
            return;
        }
        submitting = True;

        signup_result: dict | None = None;
        login_ok: bool = False;
        try {
            signup_result = await jacSignup(email.strip(), password);
            if not signup_result["success"] {
                submitting = False;
                error = "That email is already in use.";
                return;
            }
            login_ok = await jacLogin(email.strip(), password);
            submitting = False;
            if not login_ok {
                error = "Account created - please log in.";
                nav("/login");
                return;
            }
            start_target = "/start" + location.search;
            nav(start_target);
        } except Exception {
            submitting = False;
            error = "Something went wrong. Try again.";
        }
    }

    if jacIsLoggedIn() {
        return <Navigate to="/dashboard" replace={True} />;
    }

    return <div className="lumi-onboarding">
        <p className="lumi-onboarding-hint">Takes about a minute - then straight into your credit graph.</p>

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
                <h2 className="lumi-step-title">Create your LumiNode account</h2>

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
                        placeholder="At least 8 characters"
                        value={password}
                        onChange={lambda (e: ChangeEvent) { password = e.target.value; }}
                    />
                </div>
                <div className="lumi-input-labeled">
                    <label>Confirm password</label>
                    <input
                        className="lumi-input"
                        type="password"
                        placeholder="••••••••"
                        value={confirmPassword}
                        onChange={lambda (e: ChangeEvent) { confirmPassword = e.target.value; }}
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
                        onClick={handleSignup}
                        disabled={submitting}
                    >
                        {"Creating account…" if submitting else "Sign up →"}
                    </ShimmerButton>
                </div>

                <p className="lumi-auth-switch">
                    Already have an account? <Link to="/login" className="lumi-link-btn">Log in</Link>
                </p>
            </div>
        </MagicCard>
        </div>
    </div>;
}

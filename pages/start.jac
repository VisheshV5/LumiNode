"""LumiNode - Onboarding wizard route ("/start"), requires login."""

import from "@jac/runtime" { jacIsLoggedIn, Navigate }
import from ..credit.OnboardingPage { OnboardingPage }

def:pub page() -> JsxElement {
    if not jacIsLoggedIn() {
        return <Navigate to="/login" replace={True} />;
    }
    return <OnboardingPage/>;
}

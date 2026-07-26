"""LumiNode - Dashboard route ("/dashboard"), requires login."""

import from "@jac/runtime" { jacIsLoggedIn, Navigate }
import from ..credit.DashboardShell { DashboardShell }

def:pub page() -> JsxElement {
    if not jacIsLoggedIn() {
        return <Navigate to="/login" replace={True} />;
    }
    return <DashboardShell/>;
}

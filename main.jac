"""LumiNode - Entry Point.

Combines server-side graph endpoints with the client-side UI. File-based
routing scans pages/ for routes (/, /login, /signup, /start, /dashboard).
Auth is real email/password (see pages/login.jac, pages/signup.jac);
/start and /dashboard are wrapped in <AuthGuard/> at the page level.
"""

import from credit.graph { get_dashboard_data, submit_onboarding, rerun_simulation }
import from credit.ripple { run_ripple_simulation }
import from credit.chat { send_chat_message }

import "./assets/main.css";

cl {
    def:pub app(children: any) -> JsxElement {
        return children as JsxElement;
    }
}

"""LumiNode - Landing route ("/")."""

import from ..credit.LandingHero { LandingHero }

def:pub page() -> JsxPage {
    return <LandingHero/>;
}

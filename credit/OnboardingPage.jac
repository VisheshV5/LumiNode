"""LumiNode - Onboarding wizard route ("/start").

Local-only wizard state (nothing here is needed outside this route), so it
stays a single stateful component per the "section may keep local UI state"
rule. Owns its own submit call and post-submit navigation.
"""

import from "@jac/runtime" { useNavigate, useLocation }
sv import from .graph { submit_onboarding, get_dashboard_data, get_edit_payload }
import from "./components/magicui/magic-card" { MagicCard }
import from "./components/magicui/border-beam" { BorderBeam }
import from "./components/magicui/shimmer-button" { ShimmerButton }
import from "./components/magicui/blur-fade" { BlurFade }
import from .LoadingOverlay { LoadingOverlay }

def parse_float(s: str, fallback: float) -> float {
    if not s.strip() { return fallback; }
    try {
        return float(s);
    } except Exception {
        return fallback;
    }
}

def parse_int(s: str, fallback: int) -> int {
    if not s.strip() { return fallback; }
    try {
        return int(float(s));
    } except Exception {
        return fallback;
    }
}

"""Render a number for an input field without a trailing '.0' on whole numbers."""
def fmt_num(x: float) -> str {
    if x == int(x) { return str(int(x)); }
    return str(x);
}

def:pub OnboardingPage() -> JsxElement {
    has step: int = 1,
        totalSteps: int = 6,
        submitting: bool = False,
        submitError: str = "",
        isEditing: bool = False,
        name: str = "",
        currentScore: str = "",
        targetScore: str = "",
        monthlyIncome: str = "",
        costOfLiving: str = "",
        savings: str = "",
        investment: str = "",
        numCardsShown: int = 1,
        card1Name: str = "", card1Limit: str = "", card1Balance: str = "", card1Apr: str = "24.99", card1IsAu: bool = False, card1Late: str = "0",
        card2Name: str = "", card2Limit: str = "", card2Balance: str = "", card2Apr: str = "24.99", card2IsAu: bool = False, card2Late: str = "0",
        card3Name: str = "", card3Limit: str = "", card3Balance: str = "", card3Apr: str = "24.99", card3IsAu: bool = False, card3Late: str = "0",
        numLoansShown: int = 0,
        loan1Type: str = "student", loan1Balance: str = "", loan1Payment: str = "",
        creditHistoryYears: str = "2",
        numInquiries: str = "0";

    nav = useNavigate();
    location = useLocation();

    can with entry {
        bootstrapPage();
    }

    async def bootstrapPage() -> None;
    async def handleSubmit() -> None;

    def goNext(e: MouseEvent) { step = step + 1 if step < totalSteps else totalSteps; }
    def goBack(e: MouseEvent) { step = step - 1 if step > 1 else 1; }

    def fillMaria() {
        name = "Maria";
        currentScore = "580";
        targetScore = "640";
        monthlyIncome = "3200";
        costOfLiving = "2850";
        savings = "450";
        investment = "0";
        numCardsShown = 3;
        card1Name = "Capital One Platinum";
        card1Limit = "1500";
        card1Balance = "1350";
        card1Apr = "26.99";
        card1Late = "2";
        card2Name = "Discover It";
        card2Limit = "2000";
        card2Balance = "800";
        card2Apr = "24.49";
        card2Late = "0";
        card3Name = "Store Credit Card";
        card3Limit = "500";
        card3Balance = "475";
        card3Apr = "29.99";
        card3Late = "3";
        numLoansShown = 1;
        loan1Type = "student";
        loan1Balance = "12500";
        loan1Payment = "180";
        creditHistoryYears = "3";
        numInquiries = "2";
    }

    def applyEditPayload(data: dict) {
        isEditing = True;
        name = str(data.get("name", ""));
        currentScore = fmt_num(float(data.get("current_score", 580)));
        targetScore = fmt_num(float(data.get("target_score", 680)));
        monthlyIncome = fmt_num(float(data.get("monthly_income", 0.0)));
        costOfLiving = fmt_num(float(data.get("monthly_cost_of_living", 0.0)));
        savings = fmt_num(float(data.get("savings_balance", 0.0)));
        investment = fmt_num(float(data.get("investment_balance", 0.0)));
        creditHistoryYears = fmt_num(float(data.get("credit_history_years", 2.0)));
        numInquiries = fmt_num(float(data.get("num_inquiries", 0)));

        cards_in: list[dict] = data.get("cards", []);
        numCardsShown = len(cards_in) if len(cards_in) > 0 else 1;
        if len(cards_in) >= 1 {
            c = cards_in[0];
            card1Name = str(c.get("name", ""));
            card1Limit = fmt_num(float(c.get("limit", 0.0)));
            card1Balance = fmt_num(float(c.get("balance", 0.0)));
            card1Apr = fmt_num(float(c.get("apr", 24.99)));
            card1IsAu = bool(c.get("is_au", False));
            card1Late = fmt_num(float(c.get("late_30", 0)));
        }
        if len(cards_in) >= 2 {
            c = cards_in[1];
            card2Name = str(c.get("name", ""));
            card2Limit = fmt_num(float(c.get("limit", 0.0)));
            card2Balance = fmt_num(float(c.get("balance", 0.0)));
            card2Apr = fmt_num(float(c.get("apr", 24.99)));
            card2IsAu = bool(c.get("is_au", False));
            card2Late = fmt_num(float(c.get("late_30", 0)));
        }
        if len(cards_in) >= 3 {
            c = cards_in[2];
            card3Name = str(c.get("name", ""));
            card3Limit = fmt_num(float(c.get("limit", 0.0)));
            card3Balance = fmt_num(float(c.get("balance", 0.0)));
            card3Apr = fmt_num(float(c.get("apr", 24.99)));
            card3IsAu = bool(c.get("is_au", False));
            card3Late = fmt_num(float(c.get("late_30", 0)));
        }

        loans_in: list[dict] = data.get("loans", []);
        if len(loans_in) >= 1 {
            l = loans_in[0];
            numLoansShown = 1;
            loan1Type = str(l.get("loan_type", "student"));
            loan1Balance = fmt_num(float(l.get("balance", 0.0)));
            loan1Payment = fmt_num(float(l.get("payment", 0.0)));
        }
    }

    def buildCards() -> list[dict] {
        result: list[dict] = [];
        if numCardsShown >= 1 and card1Name.strip() {
            result.append({
                "name": card1Name, "limit": parse_float(card1Limit, 0.0), "balance": parse_float(card1Balance, 0.0),
                "apr": parse_float(card1Apr, 24.99), "is_au": card1IsAu, "late_30": parse_int(card1Late, 0)
            });
        }
        if numCardsShown >= 2 and card2Name.strip() {
            result.append({
                "name": card2Name, "limit": parse_float(card2Limit, 0.0), "balance": parse_float(card2Balance, 0.0),
                "apr": parse_float(card2Apr, 24.99), "is_au": card2IsAu, "late_30": parse_int(card2Late, 0)
            });
        }
        if numCardsShown >= 3 and card3Name.strip() {
            result.append({
                "name": card3Name, "limit": parse_float(card3Limit, 0.0), "balance": parse_float(card3Balance, 0.0),
                "apr": parse_float(card3Apr, 24.99), "is_au": card3IsAu, "late_30": parse_int(card3Late, 0)
            });
        }
        return result;
    }

    def buildLoans() -> list[dict] {
        result: list[dict] = [];
        if numLoansShown >= 1 and loan1Balance.strip() {
            result.append({
                "loan_type": loan1Type, "balance": parse_float(loan1Balance, 0.0), "payment": parse_float(loan1Payment, 0.0)
            });
        }
        return result;
    }

    return <div className="lumi-onboarding">
        <LoadingOverlay active={submitting} doneLabel={"Re-running your simulation" if isEditing else "Illuminating your path"}/>
        <div className="lumi-progress-dots">
            {for i in range(1, totalSteps + 1) {
                <span key={str(i)} className={"lumi-dot" + (" lumi-dot-active" if step >= i else "")}/>
            }}
        </div>
        <p className="lumi-onboarding-hint">
            {"Update your info, then we'll re-run your simulation." if isEditing else "Takes about 2 minutes - nothing here touches your real credit report."}
        </p>

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
            {if step == 1 {
                <BlurFade className="lumi-step">
                    <p className="lumi-step-label">Step 1 of {totalSteps}</p>
                    <h2 className="lumi-step-title">What's your credit score today?</h2>
                    <input
                        className="lumi-input-big"
                        type="number"
                        placeholder="e.g. 580"
                        value={currentScore}
                        onChange={lambda (e: ChangeEvent) { currentScore = e.target.value; }}
                    />
                    <h2 className="lumi-step-title lumi-step-title-spaced">What score do you need?</h2>
                    <input
                        className="lumi-input-big"
                        type="number"
                        placeholder="e.g. 640"
                        value={targetScore}
                        onChange={lambda (e: ChangeEvent) { targetScore = e.target.value; }}
                    />
                    <div className="lumi-chip-row">
                        <button className={"lumi-chip" + (" lumi-chip-active" if targetScore == "620" else "")} onClick={lambda (e: MouseEvent) { targetScore = "620"; }}>620 · car loan</button>
                        <button className={"lumi-chip" + (" lumi-chip-active" if targetScore == "640" else "")} onClick={lambda (e: MouseEvent) { targetScore = "640"; }}>640 · apartment</button>
                        <button className={"lumi-chip" + (" lumi-chip-active" if targetScore == "680" else "")} onClick={lambda (e: MouseEvent) { targetScore = "680"; }}>680 · better rates</button>
                        <button className={"lumi-chip" + (" lumi-chip-active" if targetScore == "740" else "")} onClick={lambda (e: MouseEvent) { targetScore = "740"; }}>740 · best rates</button>
                    </div>
                </BlurFade>
            } elif step == 2 {
                <BlurFade className="lumi-step">
                    <p className="lumi-step-label">Step 2 of {totalSteps}</p>
                    <h2 className="lumi-step-title">What's your monthly income?</h2>
                    <input
                        className="lumi-input-big"
                        type="number"
                        placeholder="e.g. 3200"
                        value={monthlyIncome}
                        onChange={lambda (e: ChangeEvent) { monthlyIncome = e.target.value; }}
                    />
                    <h2 className="lumi-step-title lumi-step-title-spaced">What's your monthly cost of living?</h2>
                    <input
                        className="lumi-input-big"
                        type="number"
                        placeholder="e.g. 2800"
                        value={costOfLiving}
                        onChange={lambda (e: ChangeEvent) { costOfLiving = e.target.value; }}
                    />
                </BlurFade>
            } elif step == 3 {
                <BlurFade className="lumi-step">
                    <p className="lumi-step-label">Step 3 of {totalSteps}</p>
                    <h2 className="lumi-step-title">How much do you have in savings?</h2>
                    <input
                        className="lumi-input-big"
                        type="number"
                        placeholder="e.g. 450"
                        value={savings}
                        onChange={lambda (e: ChangeEvent) { savings = e.target.value; }}
                    />
                    <h2 className="lumi-step-title lumi-step-title-spaced">How much do you have invested?</h2>
                    <input
                        className="lumi-input-big"
                        type="number"
                        placeholder="e.g. 0"
                        value={investment}
                        onChange={lambda (e: ChangeEvent) { investment = e.target.value; }}
                    />
                </BlurFade>
            } elif step == 4 {
                <BlurFade className="lumi-step">
                    <p className="lumi-step-label">Step 4 of {totalSteps}</p>
                    <h2 className="lumi-step-title">Tell us about your credit cards</h2>

                    <div className="lumi-account-card">
                        <p className="lumi-account-label">Card 1</p>
                        <div className="lumi-input-labeled">
                            <label>Card name</label>
                            <input className="lumi-input" placeholder="e.g. Capital One Platinum" value={card1Name} onChange={lambda (e: ChangeEvent) { card1Name = e.target.value; }}/>
                        </div>
                        <div className="lumi-input-row">
                            <div className="lumi-input-labeled">
                                <label>Credit limit ($)</label>
                                <input className="lumi-input" type="number" placeholder="e.g. 1500" value={card1Limit} onChange={lambda (e: ChangeEvent) { card1Limit = e.target.value; }}/>
                            </div>
                            <div className="lumi-input-labeled">
                                <label>Current balance ($)</label>
                                <input className="lumi-input" type="number" placeholder="e.g. 1350" value={card1Balance} onChange={lambda (e: ChangeEvent) { card1Balance = e.target.value; }}/>
                            </div>
                        </div>
                        <div className="lumi-input-row">
                            <div className="lumi-input-labeled">
                                <label>APR %</label>
                                <input className="lumi-input" type="number" placeholder="e.g. 24.99" value={card1Apr} onChange={lambda (e: ChangeEvent) { card1Apr = e.target.value; }}/>
                            </div>
                            <div className="lumi-input-labeled">
                                <label>Late payments</label>
                                <input className="lumi-input" type="number" placeholder="0" value={card1Late} onChange={lambda (e: ChangeEvent) { card1Late = e.target.value; }}/>
                            </div>
                        </div>
                        <label className="lumi-checkbox-row">
                            <input type="checkbox" checked={card1IsAu} onChange={lambda (e: ChangeEvent) { card1IsAu = not card1IsAu; }}/>
                            I'm an authorized user on this card
                        </label>
                    </div>

                    {if numCardsShown >= 2 {
                        <div className="lumi-account-card lumi-fade-in">
                            <p className="lumi-account-label">Card 2</p>
                            <div className="lumi-input-labeled">
                                <label>Card name</label>
                                <input className="lumi-input" placeholder="e.g. Discover It" value={card2Name} onChange={lambda (e: ChangeEvent) { card2Name = e.target.value; }}/>
                            </div>
                            <div className="lumi-input-row">
                                <div className="lumi-input-labeled">
                                    <label>Credit limit ($)</label>
                                    <input className="lumi-input" type="number" placeholder="e.g. 2000" value={card2Limit} onChange={lambda (e: ChangeEvent) { card2Limit = e.target.value; }}/>
                                </div>
                                <div className="lumi-input-labeled">
                                    <label>Current balance ($)</label>
                                    <input className="lumi-input" type="number" placeholder="e.g. 800" value={card2Balance} onChange={lambda (e: ChangeEvent) { card2Balance = e.target.value; }}/>
                                </div>
                            </div>
                            <div className="lumi-input-row">
                                <div className="lumi-input-labeled">
                                    <label>APR %</label>
                                    <input className="lumi-input" type="number" placeholder="e.g. 24.99" value={card2Apr} onChange={lambda (e: ChangeEvent) { card2Apr = e.target.value; }}/>
                                </div>
                                <div className="lumi-input-labeled">
                                    <label>Late payments</label>
                                    <input className="lumi-input" type="number" placeholder="0" value={card2Late} onChange={lambda (e: ChangeEvent) { card2Late = e.target.value; }}/>
                                </div>
                            </div>
                        </div>
                    }}
                    {if numCardsShown >= 3 {
                        <div className="lumi-account-card lumi-fade-in">
                            <p className="lumi-account-label">Card 3</p>
                            <div className="lumi-input-labeled">
                                <label>Card name</label>
                                <input className="lumi-input" placeholder="e.g. Store Credit Card" value={card3Name} onChange={lambda (e: ChangeEvent) { card3Name = e.target.value; }}/>
                            </div>
                            <div className="lumi-input-row">
                                <div className="lumi-input-labeled">
                                    <label>Credit limit ($)</label>
                                    <input className="lumi-input" type="number" placeholder="e.g. 500" value={card3Limit} onChange={lambda (e: ChangeEvent) { card3Limit = e.target.value; }}/>
                                </div>
                                <div className="lumi-input-labeled">
                                    <label>Current balance ($)</label>
                                    <input className="lumi-input" type="number" placeholder="e.g. 475" value={card3Balance} onChange={lambda (e: ChangeEvent) { card3Balance = e.target.value; }}/>
                                </div>
                            </div>
                            <div className="lumi-input-row">
                                <div className="lumi-input-labeled">
                                    <label>APR %</label>
                                    <input className="lumi-input" type="number" placeholder="e.g. 29.99" value={card3Apr} onChange={lambda (e: ChangeEvent) { card3Apr = e.target.value; }}/>
                                </div>
                                <div className="lumi-input-labeled">
                                    <label>Late payments</label>
                                    <input className="lumi-input" type="number" placeholder="0" value={card3Late} onChange={lambda (e: ChangeEvent) { card3Late = e.target.value; }}/>
                                </div>
                            </div>
                        </div>
                    }}
                    {if numCardsShown < 3 {
                        <button className="lumi-link-btn" onClick={lambda (e: MouseEvent) { numCardsShown = numCardsShown + 1; }}>+ Add another card</button>
                    }}
                </BlurFade>
            } elif step == 5 {
                <BlurFade className="lumi-step">
                    <p className="lumi-step-label">Step 5 of {totalSteps}</p>
                    <h2 className="lumi-step-title">Any loans we should know about?</h2>

                    {if numLoansShown >= 1 {
                        <div className="lumi-account-card lumi-fade-in">
                            <p className="lumi-account-label">Loan</p>
                            <div className="lumi-input-labeled">
                                <label>Loan type</label>
                                <select className="lumi-input" value={loan1Type} onChange={lambda (e: ChangeEvent) { loan1Type = e.target.value; }}>
                                    <option value="student">Student loan</option>
                                    <option value="auto">Auto loan</option>
                                    <option value="personal">Personal loan</option>
                                    <option value="mortgage">Mortgage</option>
                                </select>
                            </div>
                            <div className="lumi-input-row">
                                <div className="lumi-input-labeled">
                                    <label>Balance ($)</label>
                                    <input className="lumi-input" type="number" placeholder="e.g. 12500" value={loan1Balance} onChange={lambda (e: ChangeEvent) { loan1Balance = e.target.value; }}/>
                                </div>
                                <div className="lumi-input-labeled">
                                    <label>Monthly payment ($)</label>
                                    <input className="lumi-input" type="number" placeholder="e.g. 180" value={loan1Payment} onChange={lambda (e: ChangeEvent) { loan1Payment = e.target.value; }}/>
                                </div>
                            </div>
                        </div>
                    } else {
                        <button className="lumi-link-btn" onClick={lambda (e: MouseEvent) { numLoansShown = 1; }}>+ Add a loan</button>
                    }}
                </BlurFade>
            } elif step == 6 {
                <BlurFade className="lumi-step">
                    <p className="lumi-step-label">Step 6 of {totalSteps}</p>
                    <h2 className="lumi-step-title">Just a little more</h2>
                    <div className="lumi-input-labeled">
                        <label>First name (optional)</label>
                        <input className="lumi-input" placeholder="e.g. Maria" value={name} onChange={lambda (e: ChangeEvent) { name = e.target.value; }}/>
                    </div>
                    <div className="lumi-input-row">
                        <div className="lumi-input-labeled">
                            <label>Years of credit history</label>
                            <input className="lumi-input" type="number" value={creditHistoryYears} onChange={lambda (e: ChangeEvent) { creditHistoryYears = e.target.value; }}/>
                        </div>
                        <div className="lumi-input-labeled">
                            <label>Hard inquiries (last 12 mo.)</label>
                            <input className="lumi-input" type="number" value={numInquiries} onChange={lambda (e: ChangeEvent) { numInquiries = e.target.value; }}/>
                        </div>
                    </div>
                </BlurFade>
            }}

            {if submitError {
                <p className="lumi-auth-error">{submitError}</p>
            }}

            <div className="lumi-nav-row">
                {if step > 1 {
                    <button className="lumi-btn-secondary" onClick={goBack} disabled={submitting}>← Back</button>
                }}
                {if step < totalSteps {
                    <ShimmerButton background="#F0C850" shimmerColor="#0A0A0F" className="text-black font-bold ml-auto" onClick={goNext}>
                        Continue →
                    </ShimmerButton>
                } else {
                    <ShimmerButton
                        background="#F0C850"
                        shimmerColor="#0A0A0F"
                        className="text-black font-bold ml-auto"
                        onClick={handleSubmit}
                        disabled={submitting}
                    >
                        {"Illuminating…" if submitting else ("Save & Re-run Simulation →" if isEditing else "Illuminate My Path →")}
                    </ShimmerButton>
                }}
            </div>
            </div>
        </MagicCard>
        </div>
    </div>;
}

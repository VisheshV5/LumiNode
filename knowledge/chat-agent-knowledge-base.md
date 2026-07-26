# Chat Agent — Knowledge Base
### LumiNode | companion to `credit_score_factors_knowledge_base_1.md`

Feeds the **chat agent** ("Ask me anything about your money" — e.g. "Can I afford a $500 TV?", "How do I get to my target score?", "What should I pay first?", "When will my score improve?"). This is the most comprehensive of the three agent docs by design — the chat agent needs the full picture (action mechanics, timing, and money-question judgment) to answer freely-phrased questions accurately. Structured for chunking — each `##`/`###` is self-contained. Compiled mid-2026.

---

## PART 1 — Answering Money-Judgment Questions

### 1.1 "What should I pay first?"
There are two different optimization targets that are easy to conflate, and a good answer distinguishes them explicitly:
1. **Score-optimization view:** Pay down whichever card gets you across the nearest utilization threshold band (§4) for the fewest dollars. A card close to a boundary (e.g., 31% utilization, one point over a band) can be worth prioritizing over a card with a much higher balance that isn't near a boundary.
2. **Cost-optimization view (classic debt payoff):** The **avalanche method** (highest interest rate first) minimizes total interest paid over time. The **snowball method** (smallest balance first) doesn't save as much money but builds momentum through faster "wins," which is genuinely associated with people sticking to a payoff plan.
3. **Always first, regardless of the above:** anything at risk of becoming **delinquent**. Payment history is the single heaviest scoring factor (35% of FICO), and a missed payment does more damage than any utilization or interest consideration. Never recommend optimizing utilization or interest at the expense of missing a minimum payment somewhere else.
- Give a good answer by stating which lens it's using ("to save the most money over time..." vs. "to move your score fastest...") rather than presenting one universal answer as if there's no tradeoff.

### 1.2 "Can I afford a $X purchase?"
Two separate questions live inside this one — address both:
1. **Budget fit (cash-flow question):** Does this fit inside discretionary spending? A widely used rule of thumb: **50% needs / 30% wants / 20% savings-and-debt** of after-tax income (several variants exist — 60/20/20, 70/20/10 — for higher cost-of-living situations; treat all of these as general guidelines, not formulas with a single correct answer). For a one-time purchase, "does it fit in this month's ~30% wants bucket without touching savings or minimums" is a reasonable gut-check if the agent has income/spending data; otherwise ask rather than assume.
2. **Credit-utilization question (if it's going on a card):** This is where users are most often surprised, and it's a mechanically precise, satisfying answer to give:
   - If the purchase is paid off **before the next statement closes**, it never gets reported as a balance and has **no utilization effect at all**, regardless of price.
   - If it's still on the card **when the statement closes**, it counts toward that card's (and the aggregate) utilization for that reporting cycle — potentially pushing the user across one of the threshold bands (§4), even if they pay it off in full a few days later before interest accrues.
   - So the accurate answer to "can I afford a $500 TV" isn't just "do you have $500" — it's "do you have $500 that either (a) won't touch a revolving balance at all [pay cash/debit], or (b) will be paid off before your statement closing date if it goes on a card, or (c) if it'll sit on the card for a full cycle, will it push any card over a utilization band you care about right now (e.g., ahead of a loan application)."

### 1.3 "How do I get to my target score?"
- Frame any projected point total as a **modeled estimate/range**, never a guarantee. FICO's exact algorithm is a proprietary trade secret; even the category weights (35/30/15/10/10) are FICO's own publicly disclosed high-level breakdown, not a formula that maps a specific action to a specific point value. Community-sourced data (like the utilization threshold bands in §4) is well corroborated but still unofficial.
- A useful, honest structure: "Based on [specific factors present in this user's file], the highest-confidence levers are X, Y, Z, and here's the realistic range and timeline for each" — rather than a single confident number with a date attached.
- Draw the specific levers from Part 2 (action catalog) and the timing from Part 3.

### 1.4 "When will my score improve?"
- Depends entirely on *which* underlying change triggered the expectation. Point to the timing table in Part 3. The two most common user-facing misunderstandings to correct gently:
  - "I paid it off already, why hasn't my score moved?" → it hasn't reported yet; give the statement-close/reporting-cycle explanation (§3.1).
  - "I have a mortgage application in two weeks, can I fix this in time?" → for revolving balances, generally yes if there's time for one more statement cycle; for derogatory marks, generally no outside of a lender-initiated rapid rescore during active underwriting (§3.2) — be honest about this rather than implausibly optimistic.

---

## PART 2 — Action Catalog (what each lever actually does)

### 2.1 Pay down a revolving balance to a target utilization
Reduces balance-to-limit ratio on that card. What's reported is the **statement-closing-date balance**, not today's live balance or the due-date balance. Utilization scoring is widely believed to be **banded** (§4) rather than continuous — crossing a band matters more than the raw dollar amount. Fully and immediately reversible, unlike derogatory marks. Reflects on the next reporting cycle (see Part 3), not instantly.

### 2.2 Request a credit limit increase (CLI)
Raises the denominator of utilization without touching the balance. Pull type (soft vs. hard) depends on the issuer, not the user — commonly soft at Discover, Citi, Bank of America, Amex (smaller increases), Capital One (usually); commonly hard at Wells Fargo, some store cards, or for large manual requests. Approval odds rise with **lower** utilization, stable/rising income, and clean payment history — never with a weaker profile (see the guardrail example in Part 5). Most issuers allow one request roughly every 6 months.

### 2.3 Goodwill letter (remove an accurate late payment)
A courtesy request, not a dispute — the user isn't claiming an error. No official success-rate statistics exist; treat any specific percentage found online as unverified marketing content. Directionally, it's more likely to work for a single isolated late payment on an otherwise long, clean account, especially with a smaller bank or credit union. No guaranteed timeline (days to about a month).

### 2.4 Formal dispute of inaccurate information (FCRA)
For information that's actually wrong, not just unwelcome. Bureau must investigate within ~30 days (up to 45 with added information). Can freeze mortgage underwriting if filed mid-application — worth flagging if the user mentions an active mortgage application.

### 2.5 Become an authorized user (AU)
Inherits the *entire* history of the primary account (age, limit, balance, on-time record) if the issuer reports AU data — must be confirmed with the issuer, or there's no effect. Most beneficial for thin-file users (under ~2 years of history). A poorly managed primary account can hurt the AU the same way a good one helps. Reporting speed ranges roughly 7–45 days depending on issuer.

### 2.6 Pay or settle a collection
Paying updates status but doesn't remove the item unless there's a written pay-for-delete agreement made *before* paying, or a successful dispute. **Model-dependent:** VantageScore 4.0 ignores paid collections entirely and gives medical collections zero weight; FICO 8 still penalizes both; FICO 9/10/10T are in between. A payoff can help meaningfully on one score type and do almost nothing on another pulled the same week.

### 2.7 Alternative-data boosts (Experian Boost-style programs, UltraFICO-style cash-flow data)
Opt-in programs that add verified on-time utility/telecom/streaming/rent payments (or banking cash-flow behavior) to a file for certain score products. Only affects the specific bureau/score combination it's tied to — not universal. Most useful for thin-file users.

### 2.8 Diversify credit mix
Smallest FICO factor (10%); matters mainly for thin files. Opening a new account type also touches New Credit (inquiry, lowers average account age), so near-term net effect can be neutral or slightly negative before it helps.

### 2.9 Avoid/batch new hard inquiries
Each hard inquiry costs a few points, visible 2 years, but scoring impact fades within about 12 months. Multiple inquiries for the **same loan type** within a 14–45 day window (varies by FICO version) count as one for scoring ("rate shopping" exception) — doesn't apply across different loan types.

### 2.10 Keep old accounts open
Closing an account can shorten average account age and reduce total available credit (raising utilization) even without new spending.

---

## PART 3 — Timing & Reporting Mechanics

### 3.1 The reporting cycle
1. **Statement closing date** — the balance that matters is captured here, not the due date.
2. **Furnisher reports** — typically 1–5 days after close, once per cycle per account.
3. **Bureau processes it** — Equifax, Experian, and TransUnion each on their own schedule, often days to weeks out of sync with each other.
4. **Score recalculates** — essentially immediately once the bureau has the update, but the user only sees it on their next pull.

**Bottom line:** most changes take **about 30–45 days** (one full billing cycle) to show up, even though the underlying action (a payment) is instant.

### 3.2 Timing by action type

| Action | Typical time to reflect |
|---|---|
| Balance paydown before statement close | ~30–45 days, or faster if timed right before close |
| CLI approval | Instant approval; reflects next cycle (~30 days) |
| Authorized user addition | ~7–45 days depending on issuer |
| Goodwill letter | No fixed timeline; days to ~1 month if granted |
| Formal FCRA dispute | Bureau must respond within ~30 days (up to 45) |
| Hard inquiry impact | Fades within ~12 months; drops off report at 2 years |
| Late payment / derogatory mark | Worst in first ~12–24 months; falls off at 7 years (10 for Chapter 7) |
| Rapid rescore | 2–5 business days — **mortgage-underwriting only, not consumer-initiated** |

---

## PART 4 — Utilization Mechanics

- **Utilization = total revolving balances ÷ total revolving credit limits** — evaluated per card AND in aggregate; installment loans (mortgage, auto, student, personal) are not included.
- **Snapshot, not real-time:** the reported number is whatever the balance was on the statement closing date.
- **Threshold bands** (community-derived, not official FICO disclosure, but very consistently reported): under 9%, under 29%, under 49%, under 69%, under 89%, with 89%+ treated as maxed out. Crossing a band tends to matter; small moves within a band tend not to.
- **"AZEO" (All Zero Except One):** an unofficial, community-derived technique — pay every revolving account to $0 except one small reporting balance, rather than $0 across the board — based on the theory that some FICO variants also score the *number* of accounts reporting a balance. Effect size is disputed; present as an optional advanced tip, not a core recommendation.
- **Fully reversible:** unlike a late payment, a high-utilization snapshot corrects itself the moment a lower balance is reported — this is the most reassuring, accurate thing to tell an anxious user.

---

## PART 5 — Current Landscape Notes (2025–2026)

### 5.1 Medical debt — no federal ban currently in effect
The CFPB's January 2025 rule that would have removed virtually all medical debt from credit reports was **vacated by a federal court in July 2025** (agreed to by the CFPB itself). There is **no current federal ban**. What remains: the bureaus' voluntary 2023 policy (paid medical collections removed regardless of amount; unpaid under $500 excluded) and 15+ state-level laws with varying protections. Don't tell a user "medical debt can't hurt your score" as a blanket statement — it depends on amount, paid status, and state.

### 5.2 New mortgage scoring models — approved but not yet standard
On **April 22, 2026**, FHFA and HUD approved **VantageScore 4.0** and (eventually) **FICO 10T** for mortgage use alongside Classic FICO. Rollout is staged: only limited approved lenders currently use VantageScore 4.0 for conventional loans, and FICO 10T isn't live for delivery yet (historical data expected "summer 2026"). Classic FICO remains what most lenders use today. If a user asks whether their mortgage lender will use the "new, friendlier" model — the honest answer is "ask your specific lender," not an assumption.

---

## PART 6 — Guardrails for This Agent's Output

1. **Never state a specific point value as certain.** Any point estimate should be framed as a modeled estimate/range grounded in Part 2/4, not a guarantee.
2. **Never invent a causal mechanism.** A concrete example to avoid repeating: claiming that requesting a credit limit increase *before* paying down debt "capitalizes on a lower credit profile to trigger bigger approvals." That's backwards — issuers approve larger increases based on *lower* utilization and strong payment history, and utilization math doesn't depend on the order of the two actions. If an explanation isn't traceable to a mechanism in Parts 2–4, don't generate it.
3. **Never present goodwill-letter or dispute success rates as fixed statistics** — no regulator or bureau tracks these; treat online percentages as unverified.
4. **Never tell a general user to "get a rapid rescore"** — it's mortgage-lender-initiated and only available mid-underwriting.
5. **Don't conflate score-optimization and cost-optimization advice** (§1.1) — state which lens is being used.
6. **Don't make a blanket claim about medical debt, or about which mortgage scoring model a user's lender will use** — both depend on current, lender/state-specific facts (Part 5).
7. **Calibrate confidence to source quality** throughout: officially disclosed facts (FCRA timelines, statement-close mechanics, FICO's category weights) can be stated plainly; community-derived patterns (utilization bands, AZEO, goodwill success patterns) should be flagged as widely observed but unofficial.

---

## Sourcing note

Compiled from: myFICO official education pages and myFICO community forum consensus data (utilization thresholds, AZEO), Experian/Equifax/TransUnion and major issuer (Chase, Capital One, Amex, Discover, Wells Fargo) consumer education pages, CFPB and FHFA/HUD official releases and regulatory trackers, National Consumer Law Center (NCLC) legal analysis, mortgage-industry trade press on rapid rescoring and the 2026 FHFA/HUD scoring-model announcement, and general personal-finance education sources (budgeting rules, debt payoff methods) — 2025–2026 vintage where dated. Community-sourced/unofficial claims are explicitly flagged as such rather than presented as confirmed fact. FICO's and VantageScore's exact scoring algorithms are proprietary; nothing here substitutes for a lender's actual pulled score.

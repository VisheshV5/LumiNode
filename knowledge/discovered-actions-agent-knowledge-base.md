# Discovered Actions Agent — Knowledge Base
### LumiNode | companion to `credit_score_factors_knowledge_base_1.md`

Feeds the **Discovered Actions** agent: the surface that lists individual, concrete actions a user can take, each with an estimated point impact (e.g. "+75 — Pay down Capital One Platinum by $1216 to reach 8.9% utilization"). Structured for chunking — each `##`/`###` is self-contained. Compiled mid-2026.

---

## 1. Action Catalog

Each entry gives: **mechanism**, **realistic impact**, **time to reflect**, **risk/caveats**, and the **trigger condition** the agent should check before surfacing it.

### 1.1 Pay down a revolving balance to a target utilization
- **Mechanism:** Reduces the balance-to-limit ratio on that card. The number that matters is the balance on the **statement closing date**, not the balance on the due date and not today's live balance (see §2).
- **Realistic impact:** Utilization scoring is believed (based on long-running, widely corroborated user data on myFICO's community forums — not an official FICO disclosure) to be **banded**, not continuous. Commonly cited breakpoints, both per-card and in aggregate: **under 9%, under 29%, under 49%, under 69%, under 89%**, with "89%+" treated like maxed-out. Moving from 61% to 58% likely does nothing; moving from 61% to 48% (crossing the 69%→49% band) likely does something. This is why "pay down to 8.9%" appears as a specific target rather than an arbitrary round number.
- **Formula for computing the recommendation:** `amount_to_pay = current_balance − (credit_limit × target_fraction)`, floored at 0, where `target_fraction` is usually 0.089 (the "under 9%" band) for a headline recommendation, or the next lower band the user can realistically reach with available cash.
- **Point-estimate guidance:** community consensus (unofficial) suggests roughly 10–15 points for crossing an **aggregate** threshold and roughly ~5 points for crossing an **individual card** threshold, per crossing — and a single paydown can cross *multiple* bands at once if the starting utilization was high, which is what produces larger compound estimates. The estimate shown to the user should scale with how many bands are actually crossed (dependent on starting utilization), not just the dollar amount paid, and should always be labeled a modeled estimate, not a guarantee (see §3).
- **Time to reflect:** Not until the *next* statement closes and the issuer reports — typically 1–5 days after the statement closing date, on a ~28–31 day cycle. Paying today does not change the score today unless it happens before that cycle's close.
- **Risk/caveats:** None financially — this is the single lowest-risk, fastest-acting lever available (unlike late-payment history, utilization damage is fully and immediately reversible once the balance is reported lower). The only "cost" is the cash used to pay it down.
- **Trigger condition:** Surface whenever a user has a card sitting above one of the threshold bands and has liquid cash that isn't earmarked for a near-term obligation.

### 1.2 Request a credit limit increase (CLI)
- **Mechanism:** Raises the denominator of the utilization ratio without touching the balance, which mechanically lowers utilization instantly upon approval + next reporting cycle. It does **not** require paying anything down.
- **Which pull type:** Depends entirely on the issuer, not on the user's profile.
  - Commonly **soft-pull** (no score impact): Discover, Citi, Bank of America, American Express (for smaller increases), Capital One (in most but not all cases).
  - Commonly **hard-pull** (5–10 point temporary dip, fades in 3–6 months, visible 2 years): Wells Fargo, some store cards, and any issuer for a large/manual increase request.
  - Always uncertain enough that the agent should hedge ("may involve a hard inquiry depending on your issuer") rather than assert a pull type with confidence unless the specific issuer's policy is known.
- **Approval odds — what actually helps:** Rising or stable income, low existing utilization, and a track record of on-time payments. **Higher utilization or a recent negative event lowers approval odds; it does not raise them.** There is no credible mechanism by which having a *worse* profile makes an issuer *more* likely to approve a large increase — issuers extend more credit to lower-risk accounts, not higher-risk ones. (See §3 — this is a common fabrication to avoid.)
- **Time to reflect:** Approval is usually instant to a few minutes online. The new limit shows up in the next reporting cycle, same 1–5-days-after-close pattern as §1.1.
- **Risk/caveats:** Requesting increases too frequently (issuers commonly allow one request every ~6 months) or getting denied and immediately re-requesting can trigger extra scrutiny or a cooling-off period. A denial itself doesn't cost points beyond the inquiry (if any); issuers must send an adverse-action notice stating the specific reason.
- **Trigger condition:** Surface for accounts with a long clean payment history and utilization already reasonably low — this is a "make good behavior count more" lever, not a repair lever for accounts in trouble.

### 1.3 Goodwill letter (ask a creditor to remove an accurate late payment)
- **Mechanism:** Not a dispute — the user is not claiming an error. It's a request for the creditor to voluntarily remove an accurate derogatory mark as a courtesy, typically citing an otherwise clean history or a one-time hardship.
- **Realistic impact:** No official success-rate statistics exist (this is 100% creditor discretion, not a formalized or regulated process), and a wide range of specific percentages circulate online (some blogs cite numbers as high as ~80% and as low as ~10%) that should be treated as unverified marketing content, not fact — do not surface a specific percentage as if it's an established statistic. The qualitative pattern that recurs across many independent sources is consistent enough to state directionally: success is more likely with (a) a single isolated late payment rather than a pattern, (b) a long, otherwise-clean account history before and after the incident, (c) smaller regional banks/credit unions over large national issuers, and (d) a specific, honest reason. Multiple late marks on the same account, or a very recent incident, sharply lower the odds.
- **Time to reflect:** No guaranteed timeline — creditor response ranges from days to about a month. If granted, the removal itself typically posts within one reporting cycle after the creditor updates it.
- **Risk/caveats:** Free to attempt, no downside to asking (this is not a formal dispute, so it doesn't trigger the FCRA investigation clock or an "unresolved dispute" flag with a lender). Should not be presented to the user as reliable or high-probability — frame the point estimate as a best case, not an expected case.
- **Trigger condition:** One late payment, otherwise-strong history, account still open or recently closed in good standing.

### 1.4 Formal dispute of inaccurate information (FCRA)
- **Mechanism:** Different from §1.3 — this is a legal right under the Fair Credit Reporting Act to challenge information that is actually wrong (not late, but reported as late; wrong balance; account that isn't theirs; duplicate collection; etc.).
- **Realistic impact:** If the furnisher can't verify the disputed item within the investigation window, it must be removed or corrected. Should be recommended only when the user believes something is factually inaccurate, not as a general-purpose "remove derogatory marks" tool.
- **Time to reflect:** Bureaus generally must investigate within 30 days of receiving a dispute (45 days in some cases involving additional information submitted mid-investigation).
- **Risk/caveats:** During a live mortgage underwriting process, opening a formal dispute on a tradeline can freeze automated underwriting until the dispute resolves — worth a warning if the user has mentioned an active mortgage application.
- **Trigger condition:** User indicates an item is inaccurate, not merely unwelcome.

### 1.5 Become an authorized user (AU) on someone else's account
- **Mechanism:** The primary cardholder adds the user to their account. If the issuer reports authorized-user data to the bureaus (not all do — this must be confirmed with the issuer first, or the strategy has zero effect), the *entire account history* — age, limit, balance, on-time payment record — appears on the AU's file, not just activity from the add date forward.
- **Realistic impact:** Most beneficial for thin/short files (young adults, recent immigrants, anyone with under ~2 years of credit history), where it can meaningfully move a score by adding years of account age and lowering aggregate utilization. Effect is smaller for users who already have an established file. It also cuts the other way: a poorly managed primary account (high utilization, late payments) can hurt the AU's file the same way a good one helps it.
- **Time to reflect:** Typically shows up within one to two billing cycles (roughly 2–6 weeks), though it varies significantly by issuer — some report within about a week, others take over a month, and a minority don't report AU tradelines at all.
- **Risk/caveats:** The AU inherits the account's *full* history including any past negatives, has no legal obligation to pay, and the benefit disappears if removed as an AU later (the tradeline drops off). Being added to a stranger's account for a fee ("tradeline renting") is a real product that exists in the market, but it sits in a legal and scoring-model gray area, is explicitly against several issuers' terms of service, and should not be surfaced as a recommended action.
- **Trigger condition:** Thin-file users with a trusted family member who has a long-standing, low-utilization, on-time account and whose issuer is confirmed to report AU data.

### 1.6 Pay or settle a collection account
- **Mechanism:** Paying a collection updates its status but, under standard treatment, does **not** remove it from the report — removal generally requires either a *pay-for-delete* agreement negotiated and confirmed **in writing before paying**, or a successful FCRA dispute of inaccurate data.
- **Model-specific treatment (important — scoring models disagree here):**
  - **VantageScore 4.0:** Does not penalize a *paid* collection at all, and assigns **zero weight to medical collections** regardless of paid/unpaid status.
  - **FICO 8** (still the most widely used version for card/auto lending): Still penalizes a paid collection and still penalizes medical collections like any other collection.
  - **FICO 9 and FICO 10/10T:** Reduce the weight of paid collections and reduce (but do not zero out) the weight of medical collections relative to FICO 8.
  - Net effect: paying a collection may help meaningfully on a VantageScore-based product (like many free score apps) while doing little to nothing on a FICO 8 pull the same week — don't promise a uniform outcome.
- **Regulatory note (2025–2026):** the CFPB's rule that would have banned medical debt from credit reports nationwide was vacated by a federal court in July 2025 — there's no federal ban. The three bureaus' 2023 voluntary policy (paid medical collections removed regardless of amount; unpaid under $500 excluded) still stands, and 15+ states now have their own medical-debt reporting restrictions layered on top. Don't claim "medical debt can't hurt your score" as a blanket statement.
- **Trigger condition:** Any open collection, with framing calibrated to which score type the user's target lender is likely to use.

### 1.7 Alternative-data boosts (rent, utility, telecom, streaming, cash-flow)
- **Mechanism:** Opt-in programs (most commonly associated with Experian, marketed as "Experian Boost") let a consumer add verified on-time utility, telecom, streaming, and in some versions rent payment history into their file for certain FICO-based Experian scores. A related concept, sometimes called UltraFICO, incorporates checking/savings account cash-flow behavior (balances staying positive, regular savings activity) as a supplemental signal.
- **Realistic impact:** Only affects the specific bureau/score combination the program is tied to — it does not universally raise every score a lender might pull. Most useful for thin-file or "no recent credit" users; limited effect for users who already have several well-aged tradelines.
- **Trigger condition:** Thin-file users, or users who reliably pay rent/utilities/subscriptions on time but have little traditional credit.

### 1.8 Diversify credit mix (secured card, credit-builder loan)
- **Mechanism:** Adds a different account *type* (installment vs. revolving) to the file.
- **Realistic impact:** This is the smallest of the five FICO factors (10%) and matters mainly when the file is thin. Opening a new account type purely to "improve mix" has a small effect relative to utilization or payment history, and it also touches New Credit (a hard inquiry, a new average-account-age drag) — the net near-term effect can be neutral or even slightly negative before it's positive.
- **Trigger condition:** Files with only one account type and otherwise limited history.

### 1.9 Avoid/batch new hard inquiries
- **Mechanism:** Each hard inquiry can cost a few points, stays visible on the report about 2 years, though the *scoring* impact fades faster (commonly within about 12 months). Multiple inquiries for the **same loan type** (mortgage, auto, sometimes student loans) within a deduplication window — roughly 14–45 days depending on the FICO version — count as a single inquiry for scoring ("rate shopping" exception). This does not apply across different loan types or to credit cards.
- **Trigger condition:** User is about to shop multiple lenders for the same loan type — advise doing it in a tight window; or user has requested several unrelated new accounts recently — advise spacing them out.

### 1.10 Keep old accounts open
- **Mechanism:** Closing an account can shorten average account age (Length of History factor) and can also reduce total available credit, raising aggregate utilization even if nothing was charged.
- **Trigger condition:** User is considering closing their oldest or highest-limit card, especially if it has no annual fee.

---

## 2. Utilization Mechanics (the engine behind the point estimates)

- **Utilization = total revolving balances ÷ total revolving credit limits**, expressed as a percentage, evaluated **per card** and **in aggregate** — both matter independently.
- **Installment loans (mortgage, auto, student, personal loans) are not part of this ratio.** Only revolving credit (credit cards, most store cards, some lines of credit).
- **The reported balance is a snapshot** taken on the statement closing date, not a running real-time number, and not the payment due date.
- **Threshold bands** (community-derived, not officially published by FICO, but extremely consistently reported across long-running user data): under 9%, under 29%, under 49%, under 69%, under 89%, with 89%+ treated as effectively maxed out. Crossing a band tends to move the score in a step, not a smooth line; staying within a band tends to have little to no marginal effect.
- **Advanced technique ("AZEO" — All Zero Except One):** community-derived practice of paying every revolving account to $0 except one, which is left reporting a small balance (a few dollars up to a small percentage) rather than $0 on every card. The theory is that some FICO variants score "number of accounts with a balance" as its own factor and having at least one small reporting balance (rather than zero across the board) can outperform total zero. Unofficial and its effect size is disputed even within enthusiast communities — worth surfacing as an optional advanced tip, not a headline action card.
- **Reversibility:** unlike a late payment (which persists on the file for up to 7 years regardless of later good behavior), a high-utilization snapshot is fully and immediately correctable — pay it down, wait for the next report, it's gone. This is what makes utilization actions the highest-confidence, fastest-acting category in this catalog.

---

## 3. Guardrails for This Agent's Output

1. **Never state a specific point value as certain.** No FICO or VantageScore weighting below the published category level (35/30/15/10/10 for FICO; tiered "influence" levels for VantageScore 4.0) is officially disclosed. Any "+75 points" style figure this agent surfaces should be labeled as a **modeled estimate based on typical community-observed threshold effects**, not a guaranteed outcome — and should visibly account for the user's *starting* utilization (how many bands a paydown actually crosses), not just the dollar amount paid.
2. **Never invent a causal mechanism that isn't grounded in how issuers/bureaus actually operate.** A concrete example of what to avoid: framing "request a credit limit increase *before* paying down debt" as beneficial because it "capitalizes on your current lower credit profile to trigger automated high-limit approvals." That reverses the actual relationship — issuers approve larger increases based on *lower* utilization and *stronger* payment history, not a weaker profile, and there's no mechanism by which sequencing CLI-then-paydown outperforms paydown-then-CLI or doing both at once (utilization math is order-independent). If a generated explanation claims a specific behavioral or algorithmic mechanism, it should be checked against §1–2 above before being surfaced — if it isn't traceable to a mechanism described in this doc, don't generate it.
3. **Never present goodwill-letter or dispute success rates as fixed statistics.** These are not tracked by any regulator or bureau; specific percentages circulating in SEO content (which range wildly, roughly 10%–80%, depending on the source) are marketing content, not data. Use the qualitative pattern in §1.3 instead of a number.
4. **Never suggest tradeline-renting (paying a stranger to be added as an AU) as a recommended action.** It's a real product but sits in a legal/ToS gray area — out of scope for a legitimate action catalog.
5. **Calibrate confidence to source quality.** Officially disclosed facts (FICO's category weights, FCRA timelines, statement-close mechanics) can be stated plainly. Community-derived patterns (utilization threshold bands, AZEO, goodwill success patterns) should be flagged as widely observed but unofficial. Never blend the two into a single confident-sounding claim.

---

## Sourcing note

Compiled from: myFICO official education pages and myFICO community forum consensus data (utilization thresholds, AZEO), Experian/Equifax/TransUnion and major issuer (Chase, Capital One, Amex, Discover) consumer education pages, CFPB and FHFA official releases, National Consumer Law Center (NCLC) legal analysis, and general personal-finance education sources — 2025–2026 vintage where dated. Community-sourced/unofficial claims are explicitly flagged as such throughout rather than presented as confirmed fact. FICO's and VantageScore's exact scoring algorithms are proprietary; nothing in this document should be treated as a substitute for a lender's actual pulled score.

# Recommended (Next 90 Days) Agent — Knowledge Base
### LumiNode | companion to `credit_score_factors_knowledge_base_1.md`

Feeds the **Recommended for next 90 days** agent: the surface that sequences and times actions into a multi-step plan (e.g. "Day 1 → request CLI, Day 8 → request another CLI, Day 22 → pay down balance, expect 710 by day 35"). Structured for chunking — each `##`/`###` is self-contained. Compiled mid-2026.

---

## 1. The Reporting Cycle, In Order

1. **Statement closing date** — the balance that matters for utilization is captured here, not on the due date. These are commonly 3+ weeks apart.
2. **Furnisher reports to bureaus** — typically 1–5 days after the statement closes, once per billing cycle per account (not continuously). Different accounts on the same file can report on completely different days of the month.
3. **Bureau processes the update** — each of the three bureaus (Equifax, Experian, TransUnion) receives and processes furnisher data independently and on its own schedule; they are frequently a few days to a couple of weeks out of sync with each other.
4. **Score recalculates** — once the bureau has the update, the score recalculates essentially immediately, but the *user* usually only sees it when they next pull their score.

**Practical consequence for any plan built on this agent:** a single balance paydown typically takes **one full billing cycle (about 30–45 days)** to be reflected, not instantly, even though the cash movement is instant. A plan that shows a score change landing sooner than the next statement-close-plus-reporting-lag for that specific account is not realistic and should not be generated.

---

## 2. Timing by Action Type

| Action | Typical time to reflect | Notes |
|---|---|---|
| Pay down balance before statement close | 30–45 days from today if today is early in a cycle; can be as fast as the very next cycle if timed right before close | Timing the payment relative to *your* close date matters more than the payment date relative to the due date |
| Credit limit increase (approved) | Instant approval; reflects on file at next reporting cycle (1–5 days after close, ~30 days out) | |
| Authorized user addition | ~7–45 days depending on issuer (some as fast as ~1 week, most in the 30–45 day range, a minority never report it) | Confirm the issuer reports AU tradelines before counting on this in a plan |
| Goodwill letter | No fixed timeline; creditor response commonly days to ~1 month; if granted, posts on the next cycle after | Not guaranteed at all — should appear as a parallel, not a scheduled, step |
| Formal FCRA dispute | Bureau must investigate within ~30 days (up to 45 with added info) | Can freeze mortgage underwriting if filed mid-application — flag if user has an active mortgage application |
| Hard inquiry impact | Score impact starts fading within months, mostly gone by ~12 months, fully drops off report at ~2 years | |
| Late payment / derogatory mark impact | Damage is worst in the first ~12–24 months, then gradually fades even before removal | Falls off at 7 years (10 for Chapter 7 bankruptcy) regardless of anything the user does — not a 90-day lever |
| Rapid rescore | 2–5 business days | **Only available through a mortgage lender mid-underwriting — not something a consumer can request on their own outside an active mortgage application.** Never generate a plan step that tells a general user to "get a rapid rescore" as a standalone tip. |

---

## 3. Sequencing Logic for a 90-Day Plan

- **Days 0–14:** Front-load the zero-risk, fast-acting, high-certainty levers — utilization paydowns timed to the next statement close, and CLI requests (especially soft-pull ones) on well-behaved accounts. These have the best "confidence × speed" combination.
- **Running in parallel across the full window, not as a scheduled milestone:** Goodwill letters and formal disputes — start them early since they have unpredictable, often slow timelines, but don't build a plan that counts on them landing by a specific day.
- **Days 30–60:** Second paydown cycle if the plan is stacking multiple statement cycles; this is also when the first cycle's changes should actually show up in the score.
- **Days 60–90:** Verify the earlier changes reported correctly (bureau reporting isn't perfect — worth a report-check step), and layer in slower-moving items (new authorized-user tradelines that took the long end of the reporting window, results from goodwill/dispute attempts).
- **Never plan around:** rapid rescore (not accessible outside mortgage underwriting), derogatory-mark removal by aging (multi-year timeline), or a hard-pull CLI denial being immediately retried (can extend cooling-off periods).
- **Sequencing myth to avoid generating:** there is no evidence that requesting a CLI *before* versus *after* paying down a balance changes either the approval odds or the final utilization outcome. Utilization is `balance ÷ limit` at whatever point both changes have been reported — the arithmetic is the same regardless of order. Issuers approve larger increases based on *lower* utilization and stronger income/payment history, so paying down first, if anything, plausibly helps a CLI request rather than hurting it. Don't generate an "insight" claiming a specific order unlocks a bigger approval — see §5.

---

## 4. Current Landscape Notes Relevant to Timing (2025–2026)

### 4.1 Medical debt reporting — CFPB rule was vacated
- In January 2025 the CFPB finalized a rule that would have banned virtually all medical debt from credit reports nationwide. In **July 2025, a federal court (E.D. Texas) vacated that rule** at the joint request of the CFPB itself and the plaintiffs, on the grounds it exceeded the agency's statutory authority under the FCRA. **There is currently no federal ban on medical debt appearing on credit reports.**
- What's still true: the three major bureaus' **voluntary 2023 policy changes remain in effect independent of that rule** — paid medical collections are removed regardless of amount, and unpaid medical collections under $500 are excluded. Unpaid medical debt of $500+ can still appear.
- Separately, **15+ states** (as of early 2026) have passed their own laws restricting or banning medical debt on credit reports, layered on top of the bureaus' voluntary policy. State-level protection varies — don't assume a uniform national rule when building a plan around a medical collection.

### 4.2 New mortgage scoring models approved (April 2026) — staged rollout, not universal
- On **April 22, 2026**, FHFA and HUD announced that **VantageScore 4.0** and (eventually) **FICO 10T** are approved for use alongside Classic FICO in mortgage underwriting for loans sold to Fannie Mae, Freddie Mac, and FHA-insured loans.
- This is **not yet a universal switch**: only a limited set of approved lenders currently have access to VantageScore 4.0 for conventional loans; **FICO 10T is not yet live for delivery** — historical FICO 10T data was expected to publish "summer 2026," with broader lender adoption to follow after that. Classic FICO remains fully valid and is still what most lenders use today.
- Practical implication for a 90-day plan aimed at a mortgage: **do not assume the user's lender is using the newer, more forgiving trended-data models** just because they've been approved at the regulatory level — a plan should note "confirm with your lender which model they use" rather than assuming either way.
- Why it matters for timing specifically: VantageScore 4.0 and FICO 10T both use **trended data** (up to 24 months of balance history) rather than a single snapshot — a user on one of these models may see credit-building actions reflected differently (and sometimes more gradually, since a consistent multi-month paydown trend scores better than one single low snapshot) than on Classic FICO or FICO 8.

---

## 5. Guardrails for This Agent's Output

1. **Never generate a step that resolves faster than the reporting-cycle math in §1–2 allows.** If a plan shows a score change on day 7 from an action that requires a statement close and bureau report, that's not physically possible under normal (non-mortgage-underwriting) reporting timelines.
2. **Never invent a causal mechanism for why a particular sequence outperforms another.** A concrete example of what to avoid: framing "request a credit limit increase *before* paying down debt" as beneficial because it "capitalizes on your current lower credit profile to trigger automated high-limit approvals." That reverses the actual relationship (see §3) and should not be generated as an "insight" in any plan.
3. **Never schedule a goodwill letter or formal dispute as if its outcome or timing were certain.** These belong in the plan as parallel, uncertain-timeline actions, not as a milestone with a specific expected date or point value.
4. **Never include rapid rescore as an option for a general user** unless the user has explicitly mentioned they're mid-mortgage-underwriting with a lender.
5. **Every projected score figure in a plan should be presented as a range or estimate**, not a single guaranteed number — see the point-estimate guardrails in the Discovered Actions knowledge base, which this agent's estimates should stay consistent with.
6. **Calibrate confidence to source quality.** Officially disclosed reporting timelines (30-day FCRA window, 2-year inquiry visibility) can be stated plainly. Community-derived timing patterns (AU reporting speed ranges, goodwill response windows) should be flagged as typical ranges, not guarantees.

---

## Sourcing note

Compiled from: myFICO official education pages and community forum consensus data, Chase/Capital One/Experian/Equifax/TransUnion consumer education pages on reporting cycles, mortgage-industry trade press and lender sites on rapid rescoring (Experian, U.S. News, Nolo, industry rescore vendors), CFPB and FHFA/HUD official releases on the medical-debt rule vacatur and the April 2026 mortgage scoring-model announcement, and National Consumer Law Center (NCLC) legal analysis — 2025–2026 vintage where dated. Community-sourced/unofficial timing patterns are explicitly flagged as such rather than presented as guaranteed. Nothing in this document should be treated as a substitute for a lender's actual pulled score or a mortgage lender's specific underwriting timeline.

# Credit Score Factors — Knowledge Base for RAG

Source models covered: **FICO Score** (used by ~90% of top U.S. lenders) and **VantageScore** (3.0 / 4.0, joint venture of Equifax, Experian, TransUnion). Both pull from the same three credit bureau reports but weight the data differently. This doc is structured for chunking/embedding: each `##`/`###` section is a self-contained fact block.

---

## 1. FICO Score — Five Factors and Official Weights

FICO Score ranges 300–850, built from five weighted categories:

| Factor | Weight | Approx. points (of 850 scale) |
|---|---|---|
| Payment History | 35% | ~298 pts |
| Amounts Owed (Utilization) | 30% | ~255 pts |
| Length of Credit History | 15% | ~128 pts |
| New Credit (Inquiries) | 10% | ~85 pts |
| Credit Mix | 10% | ~85 pts |

Payment History + Amounts Owed together = 65% of the score — the two dominant factors.

### 1.1 Payment History (35%)
- Most heavily weighted single factor; based on whether accounts have been paid on time.
- Covers both revolving credit (credit cards) and installment loans (mortgages, auto, student, personal loans); installment loans carry slightly more weight in this category than revolving.
- FICO scoring considers **frequency, recency, and severity** of missed payments — a payment 90 days late does more damage than one 30 days late, and recent lates hurt more than old ones.
- A single late payment (30+ days) can drop a score significantly — commonly cited range up to ~100–180 points depending on starting score (higher starting scores drop more per incident).
- Accounts must generally be 30+ days past due to be reported as delinquent to bureaus.
- **Action:** pay every bill on time; if a payment is missed, catch up immediately — recency and severity both compound.

### 1.2 Amounts Owed / Credit Utilization (30%)
- Credit utilization ratio = total revolving balances ÷ total revolving credit limits, expressed as %.
- Measured two ways: **per-card utilization** and **aggregate utilization** across all revolving accounts — both matter.
- Installment loan balances (mortgage, auto) are NOT part of the utilization ratio; utilization applies to revolving credit only.
- General guidance: keep utilization under 30%; people with the best FICO scores average utilization under 10% (some sources cite <6%, <$3,000 total revolving balance, 3 accounts carrying balances).
- No fixed "optimal" threshold exists beyond "lower is better" — there is no bonus for exactly 30% vs. 1%.
- Utilization is a snapshot metric in FICO (based on most recent reported statement balances), unlike VantageScore 4.0 which also looks at trend.
- Damage from high utilization is quickly reversible once balances are paid down (unlike late payments, which persist on file for years).
- **Action:** pay down revolving balances; make extra/early payments before the statement closes to lower the reported balance; avoid maxing cards.

### 1.3 Length of Credit History (15%)
- Factors in: age of oldest account, age of newest account, and average age of all accounts.
- Longer history = more data = generally higher score potential; new credit users are structurally disadvantaged here regardless of behavior.
- Closing old accounts can shorten average account age and hurt this factor (and increase utilization). **Action:** keep old accounts open and active if there's no annual fee issue.

### 1.4 New Credit / Inquiries (10%)
- Hard inquiries (from credit applications) can each cost a few points and stay on the report ~2 years, though impact fades faster than that (usually within 12 months).
- Multiple inquiries for the same loan type (mortgage, auto) within a short shopping window (14–45 days depending on FICO version) are typically counted as a single inquiry ("rate shopping" exception).
- Opening several new accounts in a short period signals higher risk and can compound negatively, especially for those with a short credit history.
- Soft inquiries (background checks, pre-approval offers, checking your own score) do NOT affect the score.
- **Action:** space out credit applications; batch rate-shopping inquiries within the exception window; avoid opening several new accounts at once.

### 1.5 Credit Mix (10%)
- Considers diversity of account types: revolving (credit cards), installment (auto, student, personal, mortgage loans).
- Minor factor overall; matters most when the file is thin/limited.
- **Action:** don't open new account types purely to "improve mix" — the effect is small relative to payment history/utilization.

### 1.6 FICO Score Eligibility & Versions
- Requires at least one account open 6+ months and activity reported within the last 6 months to generate a score.
- FICO has 40+ score versions (FICO 8, 9, 10, 10T, and bureau-specific/industry-specific variants like FICO Auto Score, FICO Bankcard Score). Different lenders use different versions:
  - Mortgage lenders predominantly use older FICO Score 2, 4, or 5 (bureau-specific "classic" versions).
  - Credit card issuers/auto lenders often use FICO 8 or newer, or industry-specific scores.
- FICO 9 and 10 reduce the weight/impact of paid collections and medical collections relative to FICO 8.
- FICO 10T (trended data) incorporates 24 months of balance history similar to VantageScore 4.0.

---

## 2. VantageScore — Factors and Influence Tiers

VantageScore does not publish exact percentages (except older 3.0 disclosures); VantageScore 4.0 instead ranks factors by qualitative **influence tier**: Extremely / Highly / Moderately / Less influential.

### 2.1 VantageScore 3.0 (legacy weights, still referenced)
| Factor | Weight |
|---|---|
| Payment History | 40% |
| Age & Type of Credit (mix + length combined) | 21% |
| Credit Utilization | 20% |
| Total Balances/Debt | 11% |
| Recent Credit Behavior/Inquiries | 5% |
| Available Credit | 3% |

### 2.2 VantageScore 4.0 (current, influence-tier model)
| Factor | Influence | What it covers |
|---|---|---|
| Payment History | Extremely influential | On-time vs. late payment record — same core concept as FICO |
| Depth of Credit (Age & Type) | Highly influential | Combines account age + credit mix (FICO splits these into two separate categories) |
| Credit Utilization | Highly influential | % of revolving credit used, now with added weight on the **trend** over time, not just snapshot |
| Balances | Moderately influential | Total amount owed across accounts |
| Recent Credit (New accounts/inquiries) | Less influential | Hard inquiries and new accounts opened in last ~12 months |
| Available Credit | Less influential | Total open credit limits across all revolving accounts |

### 2.3 Key VantageScore 4.0 differentiators from FICO
- **Trended data**: analyzes up to 24 months of balance/payment history rather than a single snapshot. A consumer who pays down a $4,000 balance to near-zero each cycle scores better than one who carries $4,000 steadily, even if current snapshot balances match.
- **Thin-file scoring**: can generate a score for consumers with limited history (as little as one month / one account, in some cases) — designed to score ~30-40 million more consumers than classic FICO models require.
- **Medical collections**: VantageScore 4.0 assigns **zero weight** to medical collections (fully ignored). FICO 9/10 reduce medical collection weight; FICO 8 (still widely used) still penalizes them like other collections.
- **Paid collections**: VantageScore 4.0 does not penalize paid collection accounts. Older VantageScore models and most FICO versions still treat a paid collection as a lingering negative mark (though less severe than unpaid).
- **Tax liens / civil judgments**: weighted less than in older models (following broader industry changes after these fell out of standard bureau reporting practice).
- Score range: 300–850 for VantageScore 3.0 and 4.0 (earlier 1.0/2.0 used 501–990, now obsolete).

---

## 3. Derogatory Marks — Severity, Duration, Score Impact

Derogatory marks are negative items reflecting failure to repay as agreed. Two tiers:

### 3.1 Minor derogatory marks
- **Late/delinquent payment** (30/60/90/120+ days past due): reported once 30+ days late. A single 30-day late payment can drop a score by tens to ~100+ points depending on starting score (higher starting scores lose more points per incident because the model treats it as a bigger deviation from expected behavior).

### 3.2 Major derogatory marks
- **Charge-off**: creditor writes off the debt as a loss after prolonged non-payment (typically 120–180 days delinquent). Debt is still legally owed; account can still go to collections or be sued after charge-off. Stays ~7 years from the date of first delinquency.
- **Collections**: unpaid debt sold/assigned to a third-party collection agency. Reported separately from the original account. Stays ~7 years.
- **Repossession**: lender seizes collateral (e.g., vehicle) after non-payment. Stays ~7 years.
- **Foreclosure**: lender seizes real property after mortgage default. Stays ~7 years from date of first missed payment.
- **Civil judgment**: court ruling against the consumer in a creditor lawsuit. Reduced prominence in modern bureau data/scoring vs. historically.
- **Bankruptcy**:
  - Chapter 7 (liquidation): stays ~10 years from filing date.
  - Chapter 13 (repayment plan): stays ~7 years from filing date.
  - Considered the most severe derogatory event; signals debt was resolved via legal process rather than repayment.

### 3.3 General rules on derogatory marks
- Most non-bankruptcy derogatory marks fall off after 7 years regardless of payment status.
- Paying/settling a derogatory account updates its status ("paid," "settled") but does **not** remove it from the report under standard FICO/older VantageScore treatment — removal requires a "pay-for-delete" agreement negotiated with the collector in writing before payment, or a successful dispute of inaccurate information (under the Fair Credit Reporting Act, FCRA).
- Multiple derogatory marks compound the negative impact — the models read multiple negatives as a behavioral pattern, not isolated incidents.
- Not all creditors report to all three bureaus, so a derogatory mark may appear on one or two credit reports (Equifax/Experian/TransUnion) but not all three — checking all three separately matters.
- Higher starting scores take proportionally larger point hits from a new derogatory mark than lower starting scores (bigger deviation from "expected" behavior).
- **Action:** dispute inaccurate items under the FCRA; negotiate pay-for-delete in writing before settling a collection; otherwise expect the mark to age off on its own schedule (7 years, or 10 for Chapter 7).

---

## 4. Hard vs. Soft Inquiries
- **Hard inquiry**: triggered by applying for new credit (credit card, loan, mortgage). Can cost a few points; visible to other lenders; stays on report ~2 years, though scoring impact fades within roughly 12 months.
- **Rate-shopping exception**: multiple hard inquiries for the same loan type (mortgage, auto, sometimes student loans) within a defined window (roughly 14–45 days depending on the FICO version) are deduplicated and counted as one inquiry for scoring purposes.
- **Soft inquiry**: background/pre-qualification checks, employer checks, checking your own score. No effect on score, not visible to other lenders.

---

## 5. Model/Version Awareness (important for lender-context RAG answers)
- Mortgage lenders typically pull older "classic" FICO versions (Score 2, 4, or 5); credit card/auto lenders often use FICO 8/9 or industry-specific scores (Auto Score, Bankcard Score); VantageScore 4.0 shows up alongside FICO for cards/auto, rarely for mortgages.
- A consumer's FICO and VantageScore can differ meaningfully on the same report data — mainly due to medical/paid-collection treatment and trended vs. snapshot balances.
- Free apps like Credit Karma typically show VantageScore, not the FICO version a mortgage lender pulls — a common source of "why don't my scores match" questions.

---

## 6. Sourcing note
Compiled from: myFICO official education pages, Experian, NerdWallet, VantageScore Solutions official user guide (Sept. 2022 rev.), Credit Karma, and industry blogs (2025–2026). FICO's exact scoring algorithm is a proprietary trade secret; the percentages above are FICO's own publicly disclosed category weights, not reverse-engineered figures. VantageScore 4.0 does not publish precise percentages — only influence tiers — so treat "Highly/Moderately/Less influential" as qualitative, not numeric.

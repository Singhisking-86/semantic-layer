# N Brown Returns — Semantic Layer Execution Plan
**Version 0.3 · Working document · Updated after interview rounds 1–3**

---

## 1. Objective & principles

Build a semantic layer for the N Brown returns process that is:

1. **Decoupled from physical sources** — Teradata tables/views can change without breaking consumers; only the source-isolation tier is ever re-pointed.
2. **State-driven** — contracted to the return lifecycle state machine (① Requested → ② Carrier-Scanned → ③ Carrier-Handover → ④ WH-Processed → ⑤ Refund-Issued), not to any report's flag columns.
3. **AI-first and consumer-agnostic** — serves an Intelligence layer (insight discovery, problem analysis, action recommendation, impact assessment) and an Application layer (24×7 reporting, constant optimisation with HIL, agentic ad-hoc problem solving), as well as dashboards and ad-hoc SQL.
4. **Grounded in data** — every design assumption is validated by query before it is built; every metric is reconciled against the existing PBIX numbers before cutover.

## 2. Decision log

| # | Decision | Choice | Key implications |
|---|----------|--------|------------------|
| D1 | Physical platform | Deferred | Everything specified as logical contracts; materialisation (Teradata views / dbt / semantic engine) chosen later without redesign. |
| D2 | Consumers | Intelligence layer + Application layer (+ BI, ad-hoc) | L2 metric registry must be machine-readable; L3 must include a semantic catalog agents can load as context; stable entity keys + history for action impact assessment. |
| D3 | Trust in MB_ZZ_parcels flags | Hybrid — validate, then per-flag verdict | Q2–Q5 produce a verdict matrix: each flag classified *reconstructable* (rebuild in L1) or *opaque* (wrap in L0, document, reverse-engineer later). |
| D4 | History | Extensible to ~18 months; build/validation sampling capped at 150 days | L1 incrementally loadable by date partition; history accumulates forward from go-live; all sampling queries use `GE DATE - 150`. |
| D5 | Latency | Daily batch v1; NRT target state | v1 sources may include the mart where validated; architecture keeps the PRODVMUPD raw-event path open (Q12/Q13 quantify it); no design choice may preclude intraday later. |
| D6 | v1 scope | Logistics states + reasons/product + refund outcomes. CS-channel split = separate follow-on. Customer comms out. | Refund data requirement (below) triggers source discovery (Q11). |

**Refund data requirement (D6 spec):** for each return — *was a refund issued (state), when (timestamp), what amount, linked to which return request and reasons*. Payment-method split (credit account = immediate vs card = +5 working days) captured if a source exposes it (Q14).

## 3. Target architecture

```
┌──────────────────────────────────────────────────────────────┐
│  METADATA SPINE                                              │
│  glossary · state definitions · metric registry ·            │
│  data-quality SLOs (freshness, orphan rates, violations)     │
├──────────────────────────────────────────────────────────────┤
│  L3 · SERVING SURFACES (generated, not hand-built)           │
│  SQL views for BI/ad-hoc · DS extracts ·                     │
│  semantic catalog for agents (entities/states/metrics/       │
│  freshness as loadable context)                              │
├──────────────────────────────────────────────────────────────┤
│  L2 · METRIC & RULE REGISTRY (metrics-as-code)               │
│  every measure defined once: name, formula over L1, grain,   │
│  population rule, owner, version. Reason taxonomy as         │
│  governed reference data (lifted out of DAX).                │
├──────────────────────────────────────────────────────────────┤
│  L1 · CANONICAL STATE-EVENT MODEL                            │
│  return_state_transition (1 row per return per state entry)  │
│  tracking_event (ZZ + EVRI unified, source discriminator)    │
│  return_request_line (reason grain)                          │
│  refund_event (pending Q11 discovery)                        │
│  dims: product · supplier · calendar (ONE, not four)         │
├──────────────────────────────────────────────────────────────┤
│  L0 · SOURCE ISOLATION                                       │
│  thin mapping views — the only tier that knows Teradata      │
│  names. Source swap = re-point L0 only.                      │
└──────────────────────────────────────────────────────────────┘
```

### State model draft (to be confirmed by Q1–Q5 results)

| State | Entry signal | Source of truth | Operational status while in state |
|-------|-------------|-----------------|-----------------------------------|
| ① Requested | datetimerequested | ZZ_RETURN_REQUESTED | a. Idle Return Request (until ②) |
| ② Carrier-Scanned | Start_Carrier_Journey / first tracking event | tracking events (mart col to validate) | b. In Transit |
| ③ Carrier-Handover | End_Carrier_Journey / last carrier scan | tracking events (mart col to validate) | c. WH — WIP |
| ④ WH-Processed | DateReturnedWH (warehouse scan) | mart (raw source TBD) | d. Processed |
| ⑤ Refund-Issued | refund record | TBD via Q11 | terminal |

**SoS legs:** ①→② RequestToCarrierSOS · ②→③ CARRIER_SOS · ③→④ WH_SOS · ①→④ EndToEndSOS.
**SLA rule (to verify in Q4):** 10-day clock ② → ④; parcels scanned <10 days ago excluded from SLA %.

## 4. Phase plan with gates

| Phase | Work | Exit gate |
|-------|------|-----------|
| 0 · Design interview | Rounds 1–3 done. Remaining rounds: SLA rule confirmation (after Q4), reason taxonomy ownership, calendar standard, keys & governance. | All decision-log rows filled, none "deferred" except platform. |
| 1 · Data validation | User runs Q1–Q14, uploads results; Claude analyses; iterate with follow-up batches. | Per-flag verdict matrix issued; state model confirmed/amended; refund source identified or descoped; orphan rates and freshness quantified. |
| 2 · Conformance | Final entity list, grain statements, state entry/exit conditions, conformed dims, glossary, metric registry content (incl. PBIX measure parity list). | Signed-off logical model + metric definitions. |
| 3 · Build | L0 → L1 → L2 → L3 in order, on chosen platform. Incremental daily load; 150-day initial backfill window. | All objects deployed; load running daily. |
| 4 · Parallel run | Reconcile vs live PBIX (reproduce, then fix, known quirks: TodayMinus14=−15, supplier dedupe). Agent-style Q&A test against L1/L3 ("why did SLA dip in week X?"). | Differences = 0 or explained & accepted; agent test passes. |
| 5 · Cutover & governance | Re-point PBIX to layer; retire 4 calendar copies; publish change rules + DQ SLO monitors (Q2/Q6 queries become permanent checks). | PBIX refreshing from layer; monitors live. |

## 5. Validation query register

| Q | Purpose | Decides | Status |
|---|---------|---------|--------|
| Q1 | Grain of MB_ZZ_parcels (RETURNID unique?) | L1 grain statement | ⏳ pending upload |
| Q2 | State ordering violations ①≤②≤③≤④ | State-machine integrity; cleansing rules | ⏳ |
| Q3 | Do 4 statuses partition ReturnsRequested? | Status derivation logic | ⏳ |
| Q4 | SLA recompute from dates (both clock-start candidates) vs flags | True SLA rule; rebuild-vs-wrap for SLA flags | ⏳ |
| Q5 | SoS columns vs date arithmetic | Rebuild-vs-wrap for SoS | ⏳ |
| Q6 | Tracking orphan rates (both directions) | Join reliability; DQ SLO baselines | ⏳ |
| Q7 | Distinct return reasons + volumes | Taxonomy coverage vs 5-group DAX mapping | ⏳ |
| Q8 | Columns of ZZ_RETURN_REQUESTED | Channel signal (self-serve vs CS) availability | ⏳ |
| Q9 | History depth per source | Backfill feasibility beyond 150 days | ⏳ |
| Q10 | Freshness per source | Latency SLO baseline | ⏳ |
| Q11 | Refund/payment table discovery | Refund source for D6 spec | ⏳ |
| Q12 | PRODVM vs PRODVMUPD freshness | NRT path viability (D5 target state) | ⏳ |
| Q13 | Mart lag vs raw request stream | Whether v1 daily can use mart at all | ⏳ |
| Q14 | Payment-method signal in orderline | Credit-vs-card refund leg feasibility | ⏳ |

All sampling windows standardised to `GE DATE - 150` (D4). All queries return aggregates — no row-level exports required.

## 6. Open questions (future interview rounds)

- R4 (after Q4/Q7 uploads): confirm SLA clock-start; taxonomy owner & change process for the 5 groups; treatment of unmapped reasons.
- R5: conformed calendar — adopt finance calendar (Mar–Feb, Q3=4 periods) as the single standard? Week-start convention?
- R6: entity keys & identity — RETURNID stability, SKU parsing rule ownership (chars 1–5 / last 2), customer/account key for future CS-split work.
- R7: governance — who owns L2 metric definitions; versioning & deprecation policy; access model for agent consumers.

## 7. Working protocol

1. User runs the open query batch in Teradata SQL editor (150-day windows), uploads result CSVs.
2. Claude analyses → updates verdict matrix, state model, and this plan → issues next batch and/or interview round.
3. Repeat until Phase 1 exit gate, then move to Phase 2 sign-off.

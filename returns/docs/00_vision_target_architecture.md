# 00 · Vision & Target Architecture

**This document overrides any earlier framing that read as "replicate Power BI."**

## Objective

Build a detailed, evidence-grounded understanding of the **returns** and **refunds**
processes (and later **associated customer contacts**), and encode that
understanding in a **semantic model decoupled from source systems**. The semantic
layer is the durable asset: it is maintained and enhanced as the business
processes evolve, while source systems, pipelines, and even the warehouse engine
remain swappable underneath it. On top of it sit two consumer layers:

**Intelligence layer** — exposes services for
*insight discovery, problem analysis, action recommendation, action impact
assessment*; constantly improves its analytical capabilities/skills; constantly
develops capabilities for recommending business-improving actions; and over time
**learns how to take actions**.

**Application layer** —
*Reporting*: 24×7 analytics giving full visibility into operational performance.
*Constant optimization*: proposed actions supporting all ongoing operational
activity, delivered both **HIL** (human-in-the-loop) and **agentic**.
*Ad hoc conversational problem solving*.

The two Power BI reports are now only (a) a seed of process knowledge already
mined, and (b) a calibration benchmark proving our event-derived states agree
with what operations currently trusts. Parity is a sanity check, never a goal:
where the PBI logic is wrong (multi-supplier Table.Distinct, TodayMinus14
inconsistency, "last carrier scan" ③), the semantic model is **right**, and the
delta is documented.

## The NB-OS layer stack

The semantic work sits inside a four-layer NB-OS (N Brown Operating System) stack.
**Right now we are building the Data layer only — specifically the semantics for
the returns/refunds flow — without Databricks. Databricks implementation comes
later (Infrastructure & Integration layer).** The layers, bottom to top:

| Layer | Role | Our status now |
|-------|------|----------------|
| **Data layer** | Exposes a **semantic data layer for retail + FS operations, uniformly recognized across NB-OS**. Eventually implemented over Databricks. Used by the NB-OS Intelligence and Application layers, and gradually by optimization SB projects across NB. | **ACTIVE FOCUS** — we are defining the returns/refunds semantics here. Engine-agnostic; no Databricks yet. |
| **Infrastructure & Integration layer** | Databricks implementation; updated automatically on an ongoing basis (daily / hourly / TBD); AO (always-on) in production; deployment of NB-OS services (Intelligence + Application); initiating actions on N Brown operational systems. | **DEFERRED** — placeholders only; designed against, not built. |
| **Intelligence layer** | insight discovery, problem analysis, action recommendation, action impact assessment; continuously improves analytical skills; develops action-recommendation capability; learns to take actions. | Designed (target); built after Data layer is stable. |
| **Application layer** | 24×7 reporting; constant optimization (HIL + agentic); ad hoc conversational problem solving. | Designed (target). |

Dependency direction: Application & Intelligence consume the **Data layer**; the
**Infrastructure & Integration layer** runs everything (it materializes the Data
layer on Databricks, schedules refreshes, hosts the services, and is the only
layer that touches N Brown operational systems to initiate actions).

## The Data layer is decoupled from source (three tiers)

The Data layer is itself decoupled from source systems via three tiers, so it can
be "uniformly recognized across NB-OS" while sources change underneath. Tiers 1–2
change when the *business* changes; tier 3 changes when *systems* change. Source
vocabulary never leaks upward. **The deliverable we are building now is the first
versioned cut of these three tiers for returns + refunds.**

| Tier | Contents | Changes when | Examples |
|------|----------|--------------|----------|
| **1 · Process ontology** (conceptual) | Business entities, lifecycle states, events, policies, vocabulary. No column names, no system names. | The business process changes | `Return` (= one parcel), `ReturnRequestLine`, lifecycle ①Requested→②CarrierAccepted→③DeliveredToRetailer→④WarehouseProcessed→⑤Refunded; statuses Idle/InTransit/WH-WIP/Processed; policies: 10-day SLA from ② to ④, refund auto-trigger on ④, card refund +5 days; `Refund`, `RefundMethod`; future: `CustomerContact`, `ContactReason`, contact↔return linkage |
| **2 · Semantic contracts** (logical) | Canonical schemas (state-event model, conformed dims, calendar), **metrics-as-code registry** with versioned definitions, DQ SLOs, the **semantic catalog** that agents read (every entity/metric carries a business definition, derivation, caveats, freshness) | Definitions/measures evolve | `return_state_transition`, `tracking_event`, `refund_event`; metrics `sla_pass_rate v1`, `end_to_end_sos v1`, `return_rate v2 (fixes PBI non-determinism)`; SLO: state-④ completeness ≥99.5% within 4 days |
| **3 · Source bindings** (physical) | Mappings from contracts to actual objects + load rules R1–R7 + watermarks. The ONLY tier that knows PRODVM/Teradata (and later Databricks) exists. | Sources/systems change | ② := first IN_TRANSIT milestone in `PRODVM.ZZ_RETURN_IN_TRANSIT` (deduped per R1), fallback first EVRI scan; ⑤ := event `0097` in `RETURN_ITEM_EVENT_HISTORY`; CDC watermark on INSERTED_ON + 7-day window |

Practical rules that follow:

1. Every tier-2 object and metric has an ID, a version, an owner, a plain-English
   definition, and a derivation expressed against tier-1 concepts — so the
   catalog is readable by agents and humans without knowing Teradata or Databricks.
2. Tier-3 bindings are declarative (mapping specs, not buried in ETL code), so a
   source/engine swap (Teradata exploration → Databricks production) = rewrite
   bindings + rerun calibration, with tiers 1–2 untouched.
3. Process evolution (new carrier, new refund method, contact channels) = extend
   tier-1 vocabulary first, then contracts, then bindings — in that order.
4. The PBIX mart benchmark, and any future "current report" the business trusts,
   plugs in as a **calibration source** against tier-2 outputs, not as a spec.

## Domain roadmap

| # | Domain | Status | Notes |
|---|--------|--------|-------|
| 1 | Returns logistics (states ①–④, SoS, SLA, statuses, reasons/product) | Phase 1 ~80%: profiled, rules R1–R7 set, P13 bridge blocker open | Current focus |
| 2 | Refunds (issued? when? value? method? linked reasons?) | Signals located (event 0097, CUSTOMER_CREDITED_IND, POSTAGE_REFUND_VALUE, refund_type_code, RETURN_NOT_CREDITED); gated on P15 bridge + P16 decode | Same Phase-1 close |
| 3 | Customer contacts | **Discovery not started.** First steps: identify contact sources (CS systems, telephony, chat, email), find the contact↔return/refund linkage keys, profile contact reasons. Target ontology: `CustomerContact`, `ContactReason`, `ContactOutcome`, contacts-per-return, contact-driven-by-state metrics ("where in the lifecycle do contacts spike?") | Next domain after Phase 2 starts; add discovery queries to the register as C-series |

The high-value cross-domain questions the model must eventually answer natively:
which return states/delays *generate* contacts; which reasons drive refunds vs
re-deliveries; what the cost of a late ④ is in contacts + refunds.

## Intelligence layer (target design, build after the Data layer is stable)

Four exposed services, all reading ONLY the Data layer's semantic catalog + tier-2
surfaces (never source systems directly):

| Service | What it does | Grounding |
|---------|--------------|-----------|
| Insight discovery | Scans metrics/states for anomalies, drifts, emerging segments (e.g. a supplier's Fit-reason spike) | metric registry + statistical baselines per metric |
| Problem analysis | Decomposes a flagged problem along the ontology (state→leg→carrier→depot→product→reason) to candidate causes | state-event model; lineage-aware drill paths |
| Action recommendation | Maps diagnosed causes to an **action catalog** (e.g. re-route carrier, supplier QA review, sizing-guide fix, proactive contact) with expected effect | action catalog (new tier-2 artifact) + historical effect estimates |
| Action impact assessment | Before: simulates expected metric movement. After: measures realized effect vs counterfactual | metric registry + experiment/rollout markers |

Learning loops (the "constantly improves" requirement):
- **Skill registry**: each analytical capability is a versioned, evaluated skill
  (definition + prompts/code + eval set + score history). Improvement = new skill
  version beating the eval, never silent drift.
- **Action learning ladder**: recommend-only → HIL-approved execution → bounded
  agentic execution, promotion per action type gated on measured impact accuracy
  and an explicit risk policy. "Learns how to take actions" = climbing this
  ladder with evidence, with HIL as the default stance.
- Every recommendation and outcome is logged to a feedback store that feeds both
  effect estimates and skill evals.

## Application layer (target design)

- **Reporting 24×7**: generated FROM the metric registry (definitions render to
  dashboards/APIs; no hand-built report logic), with "data as of" from R7
  watermarks and DQ SLO status displayed, not hidden.
- **Constant optimization**: the recommendation service embedded in operational
  workflows; HIL queue first, agentic execution only for ladder-promoted actions.
- **Conversational problem solving**: agent sessions grounded in the semantic
  catalog (definitions, caveats, freshness) so answers are consistent with
  reporting by construction.

## Infrastructure & Integration layer (deferred — design against, don't build)

This layer is **not built now**; the repo carries placeholders so the design has a
home and so the Data-layer contracts are written to be implementable here later.
Responsibilities when it is built:

- **Databricks implementation** of the Data layer: tier-3 binding specs become
  Databricks ingestion + transforms; tier-2 contracts become governed tables /
  views / a metric store; the semantic catalog is published to a discovery
  surface (e.g. Unity Catalog).
- **Always-on (AO) in production**, updated automatically on an ongoing basis
  (daily / hourly / TBD), honouring rule R7 watermarks and exposing "data as of".
- **Deployment of NB-OS services** — both the Intelligence and Application layers
  run on this layer.
- **Initiating actions on N Brown operational systems** — the only layer with
  write access to operational systems; executes the actions the Intelligence
  layer recommends, under the HIL → agentic promotion ladder and an explicit
  risk policy.

Design implication for our current work: keep tier-3 bindings declarative and
engine-neutral so the Teradata-exploration bindings translate to Databricks
production bindings by swapping the binding spec, not by rewriting tiers 1–2.

## What this changes in current work — nothing structural, two reframings

1. **Phase-1 reconciliation = calibration, not parity.** Q15–Q19 still run;
   "explained deltas" where our derivation is better (③ first-DELIVERED vs mart's
   last-scan) are documented in the catalog as model-vs-legacy notes.
2. **Everything we profile is captured as tier-1/2/3 knowledge**, not as ETL
   trivia: P-series findings become binding specs (tier 3) and caveat entries in
   the semantic catalog (tier 2). The deliverable of Phase 2 is the first
   versioned cut of all three tiers for domains 1–2.

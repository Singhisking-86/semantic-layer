# 01 · Decision Log (binding)

Decisions agreed across three interview rounds with the project owner. Changing any
of these requires explicit sign-off from the user — do not silently deviate.

| # | Decision | Detail |
|---|----------|--------|
| D1 | **Platform deferred** | Design as logical contracts (entities, grains, metric definitions, DQ SLOs) that can be implemented on any engine. No platform-specific DDL until Phase 2 gate. |
| D2 | **Consumers are AI-first** | Two consumer classes, both reading tier-2 surfaces only. *Intelligence layer*: insight discovery, problem analysis, action recommendation, action impact assessment — with continuous improvement of analytical skills, growing action-recommendation capability, and learning to take actions (HIL → agentic ladder). *Application layer*: 24×7 reporting, constant optimization (HIL + agentic), ad hoc conversational problem solving. Power BI parity is a calibration check, not a target. |
| D3 | **Hybrid trust model** | Mart flags are not trusted blindly nor rejected wholesale: every flag gets a per-flag verdict (reconstructable / benchmark-only / dead) via the validation register. Outcome so far: ALL mart flags reconstructable from events (Q1–Q5) → REBUILD from PRODVM sources; mart = calibration benchmark only. |
| D4 | **History** | Extensible to ~18 months in production. ALL exploratory sampling capped at 150 days (`GE DATE - 150`). |
| D5 | **Latency** | v1 = daily batch. Measured CDC lag (P11): median 1.6d, p95 3.6d → honest freshness promise is "requested ≤2d ago, complete to ~4d ago". NRT is target-state and requires the PRODVMUPD intraday path (Phase 3 scope), incremental loads designed per rule R7. |
| D6 | **Scope (current domains)** | Logistics (states ①–④, SoS legs, SLA) + reasons/product analytics + **refund outcomes** (was refund issued? when? what amount? linked to which reasons?). Customer comms remain out of scope. |
| D7 | **Decoupling principle** (2026-06-12) | The semantic model is decoupled from sources via three tiers: process ontology → semantic contracts (metrics-as-code, agent-readable catalog) → source bindings. Source vocabulary never leaks above tier 3; bindings are declarative; a source swap means rewriting bindings + recalibrating, with tiers 1–2 untouched. Process evolution extends tier 1 first. See docs/00. |
| D8 | **Domain roadmap** (2026-06-12) | 1: returns logistics (in flight) → 2: refunds (signals located, same Phase-1 close) → 3: **associated customer contacts** (discovery not started; C-series queries; target ontology CustomerContact / ContactReason / ContactOutcome and contact↔return linkage). The earlier "CS-channel split = separate follow-on" is superseded by domain 3. |

## Refund spec (D6 expansion)

Must answer, per return line: refund issued (Y/N), refund timestamp, refund value
(item + postage), linkage to return reason and product. Discovery so far: event
`0097` in RETURN_ITEM_EVENT_HISTORY fires exactly and only on credited items
(1,244,064 / 1,244,064) → primary refund-event candidate; `CUSTOMER_CREDITED_IND`
and `POSTAGE_REFUND_VALUE` on RETURN_ITEM carry the outcome and value. Pending:
P16 decode of the event vocabulary + P15 bridge repair to attach WMS items to
portal request lines.

## Business flow reference (from returns_refund_flow_updated.html)

States: ① DateReturnRequested → ② Start_Carrier_Journey → ③ End_Carrier_Journey →
④ DateReturnedWH → ⑤ Refund.
Statuses partition the requested population: (a) Idle, (b) In Transit, (c) WH-WIP,
(d) Processed — verified EXACT partition on the mart snapshot (Q3).
SoS legs: RequestToCarrierSOS (①→②), CARRIER_SOS (②→③), WH_SOS (③→④),
EndToEndSOS (①→④). SLA: 10-day clock from ② to ④, target 95%.
Refund auto-triggers on the ④ scan; credit-account refunds immediate, card +5 days.

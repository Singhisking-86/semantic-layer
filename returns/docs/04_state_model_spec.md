# 04 · State Model Specification (L1 target)

The canonical entity is the **return** (header, = parcel) with a state machine
①–⑤, derived from line-grain and event-grain sources. This is the contract the
L1 build must satisfy; platform-specific DDL comes in Phase 2 (D1).

## Entities

| Entity | Grain | Source(s) |
|--------|-------|-----------|
| `return_request_line` | (RETURNID, ORDERNUMBER, ORDERLINEITEMNUMBER) | ZZ_RETURN_REQUESTED + R4 `request_attempt_seq` |
| `return` (header) | RETURNID; AK TRACKINGID when present | derived from lines |
| `tracking_event` (unified) | one row per carrier event | ZZ_RETURN_IN_TRANSIT (deduped, R1) ∪ HERMES_RETURN_TRACKING_DETAIL, normalized to a single event vocabulary |
| `wh_item_event` | one row per RETURN_ITEM_EVENT_HISTORY event | decode via RETURN_EVENT_CODE (P16) |
| `refund_event` | per credited item | event 0097 + CUSTOMER_CREDITED_IND + POSTAGE_REFUND_VALUE |
| `return_state_transition` | one row per (RETURNID, state) | derived per rules below |
| conformed `calendar` | one date dim, role-played | replaces 4 PBIX calendar copies; fin year Mar–Feb |

## State derivation rules

| State | Definition | Rules applied |
|-------|------------|---------------|
| ① Requested | DATETIMEREQUESTED on the request line (header = MIN over lines) | — |
| ② Carrier scan-in | first IN_TRANSIT-class milestone; fallback first EVRI scan | R3 |
| ③ Delivered to retailer | FIRST DELIVERED-class milestone | R1, R2 |
| ④ WH processed | RETURN_ITEM.RETURN_DATE/TIME (bridge pending P15); carrier-side signal EVRI P394 | P15 blocker |
| ⑤ Refund issued | event 0097 timestamp; value = item + POSTAGE_REFUND_VALUE | P16 pending |

Current-state statuses partition the requested population (verified EXACT, Q3):
Idle (no ②) · In Transit (② not ③/④) · WH-WIP (③ or arrived, not processed) ·
Processed (④).

## Measures (L2 registry — definitions locked to mart benchmark)

- SoS legs (calendar-day arithmetic, matching Q5):
  `RequestToCarrierSOS` = ②−①, `CARRIER_SOS` = ③−②, `WH_SOS` = ④−③,
  `EndToEndSOS` = ④−①. Note the ③ artifact: "last carrier scan" in the mart can
  postdate ④ (2,495 cases) — L1 uses first-DELIVERED (R2), so flag small expected
  deltas in reconciliation for leg 3/WH_SOS.
- SLA: pass = (④−② ≤ 10 days); population = has-②; target 0.95.
  Benchmark: population 665,210, pass 634,093 (mart snapshot 2026-05-19).
- % processed / idle / in-transit / WIP over Requested (DIVIDE-style ratios).
- Return Rate = items_returned / items_ordered per product
  (orderline_current denominator, R4 attempt collapse; fix the PBIX
  multi-supplier `Table.Distinct` non-determinism, do not replicate it).
- Reason analytics: ~30 raw reasons grouped into 5 (Buying / Customer Choice /
  Delivery-Warehouse / Fit / Quality) per the PBIX SWITCH; rank within product =
  count desc, alpha tiebreak; #1/#2/#3 label format "Reason (count) — %".
- Refund measures (D6): refund_issued_flag, request→refund elapsed,
  refund_value, refund linkage to reason group and product.
- Quirk to NOT replicate: PBIX TodayMinus14 inconsistency (TODAY()−15 on one
  calendar, −14 on another).

## Reconciliation gate (Phase 1 → 2)

L1-derived state counts on the snapshot date must match the mart benchmark within
agreed tolerance: status partition exact; SLA pass/population exact; SoS legs exact
for 1/2/4, explained deltas only for leg 3.

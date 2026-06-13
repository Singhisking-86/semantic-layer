# STATE — Returns & Refunds Semantic Layer
<!-- Updated: 2026-06-13 | Phase 1 ~80% complete -->

## Where we are

Phase 1 (data profiling + source validation) is ~80% complete. The semantic
model is grounded in evidence from P1–P14. One hard blocker remains before
Phase 1 can close.

**BLOCKER P13:** ZZ→WMS bridge join (`ORDERNUMBER` = `RETURN_ITEM.ORDER_SERIAL_NUMBER`)
matches 0% — key format mismatch. Repair path: P15a/b via `WAREHOUSEREFERENCE =
RETURN_NUMBER`. Until fixed, states ④ (WH-processed) and ⑤ (refunded) cannot be
attached to portal return requests.

## Core facts (do not re-derive)

- **Grain:** `PRODVM.ZZ_RETURN_REQUESTED` unique on (RETURNID, ORDERNUMBER,
  ORDERLINEITEMNUMBER) — 1,192,901 rows / 560,912 returns / 150d
- **State model ①–⑤ confirmed:**
  - ① Requested: `DATETIMEREQUESTED`
  - ② Carrier scan-in: `ZZ_RETURN_IN_TRANSIT` milestone row 1
  - ③ Delivered to retailer: first DELIVERED-class milestone (row 2)
  - ④ WH processed: `RETURN_ITEM` / EVRI event P394 ← BLOCKED by P13
  - ⑤ Refunded: event 0097 (1,244,064 events, 100% on credited items)
- **Load rules R1–R7** are binding — see `returns/docs/03_profiling_findings.md`
- **CDC freshness:** median lag 1.6d, p95 3.6d — v1 promise: "≤4 days old"

## Immediate next steps (in order)

1. **Run `returns/sql/open/P15_P17_next_batch.sql`**
   - REF-BRIDGE-01: diagnose ZZ→WMS key mismatch, test `WAREHOUSEREFERENCE = RETURN_NUMBER`
   - REF-VOCAB-01: decode RETURN_EVENT_CODE, confirm event 0097 = refund credit
   - RET-ORDERSTATUS-01: profile ORDERSTATUS and RETAILER values

2. **Run `returns/sql/open/Phase1_Validation_Revised_No_Warehousedb.sql`**
   - RET-REASON-01, RET-HIST-01, RET-FRESH-01, REF-DISCOVERY-01, RET-NRT-01,
     RET-PAYMENT-01, RET-KEYMAP-01, REF-EVENTVOCAB-FULL, RET-STATE-01/02/03

3. **For each result:** verdict → docs/03, register → ANSWERED, regenerate ER model if changed

4. **Phase 1 exit gate:** REF-BRIDGE-01 repaired + RET-STATE-03 calibrates live state
   counts against mart benchmark (exact or documented deltas)

5. **Phase 2 then delivers:** first versioned cut of all 3 data layer tiers for
   returns + refunds (`returns/layers/data_layer/`)

## Key file locations

| File | Purpose |
|------|---------|
| `returns/sql/REGISTER.md` | Single source of truth for all query IDs |
| `returns/docs/03_profiling_findings.md` | P1–P14 verdicts + load rules R1–R7 |
| `returns/docs/04_state_model_spec.md` | State machine spec |
| `returns/docs/05_open_questions.md` | Active run queue |
| `returns/sql/open/P15_P17_next_batch.sql` | Next batch to run |
| `tools/teradata/pull.py` | Teradata runner (ad-hoc) |
| `returns/scripts/run_sql.py` | Teradata runner (batch @name → CSV) |

## Guardrails reminder

READ-ONLY · SEL not SELECT · TOP n not LIMIT · GE DATE - 150 · no warehousedb
PRODVM.* only · check data/catalog/db_table_column_name.csv before querying DBC

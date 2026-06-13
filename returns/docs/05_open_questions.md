# 05 · Open Questions & Run Queue

**The canonical question list now lives in `../sql/REGISTER.md`** (stable
topic-keyed IDs, status, SQL location, verdict). This doc keeps only the
narrative queue order and the domain-3 backlog; do not maintain a second copy of
the question table here.

## Queue order (next session)

1. `sql/open/P15_P17_next_batch.sql` — **REF-BRIDGE-01** (the blocker: ZZ→WMS key
   diagnosis + repair via WAREHOUSEREFERENCE), **REF-VOCAB-01** (decode event
   codes, confirm 0097=credit), **RET-ORDERSTATUS-01**.
2. `sql/open/Phase1_Validation_Revised_No_Warehousedb.sql` — RET-REASON-01,
   RET-HIST-01, RET-FRESH-01, REF-DISCOVERY-01, RET-NRT-01, RET-PAYMENT-01,
   RET-KEYMAP-01, REF-EVENTVOCAB-FULL, RET-STATE-01/02/03.
3. RET-STATE-03 is the Phase-1 exit gate (reconstruction calibration).

Save each result to `data/profiling_results/<ID>_<name>.csv`, write the verdict
into `docs/03`, and flip the register row to ANSWERED before moving on.

- Eyeball ~5 negative-lag RETURNIDs from P11 (insert before request, worst −24d):
  amended timestamps on re-requests vs clock drift. DQ note only.
- RETAILER 2-value decode — confirm against trading codes (brand split).
- Confirm access to `prodvm.calendar_mart` (not in catalog dump).
- WAREHOUSEDB.MB_WH_return_scans / fact_returns — unexplored; check relevance
  once bridge is fixed (may shortcut ④ if accessible... note: warehousedb has no
  SELECT access, so likely benchmark-only).

## Done (do not re-run)

All ANSWERED rows in `../sql/REGISTER.md` — the P1–P14 profiling run,
MART-01..05 reconstruction (offline snapshot), CAT-SWEEP-01 catalog dump.
Evidence: docs/03 + data/profiling_results/. Superseded drafts: sql/archive/.

## Domain 3 backlog — customer contacts (C-series, start after Phase 2 begins)

| ID | Question |
|----|----------|
| C1 | Identify contact sources in the estate: CS/CRM systems, telephony, chat, email logs. Start with the catalog dump (`data/catalog/`) + DBC discovery for contact/case/interaction-named objects; then ask the user which CS platforms exist. |
| C2 | Find the contact↔return/refund linkage keys (account? order? RETURNID referenced in case records? Remember CustomerID = account × 10 in portal data). |
| C3 | Profile contact reasons/dispositions; volumetrics per channel; grain + dedupe behaviour. |
| C4 | Cross-domain probes: contacts per return state ("where in the lifecycle do contacts spike?"), contact rate vs SLA breach, contact rate vs refund delay. |

## Phase gate criteria

Phase 1 closes when: P15 bridge fixed (>99% match or documented residual),
P16 vocabulary decoded, Q15–Q19 **calibrate** live-rebuilt states against the
mart benchmark (exact, or explained-and-documented deltas where our derivation
is deliberately better — e.g. ③ first-DELIVERED vs mart last-scan). Then Phase 2
delivers the first versioned cut of all three tiers for returns + refunds:
tier-1 ontology, tier-2 contracts + metric registry + semantic catalog entries,
tier-3 binding specs (per docs/00 and
reference/Semantic_Layer_Execution_Plan_v0_3.md).

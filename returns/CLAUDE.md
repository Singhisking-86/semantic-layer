# N Brown Returns — AI-First Semantic Layer

You are continuing a multi-session project. **The objective is NOT to replicate
Power BI.** It is to build a detailed, evidence-grounded understanding of the
returns and refunds processes (and later associated customer contacts) and encode
it in a **semantic model decoupled from source systems** — three tiers: process
ontology → semantic contracts (metrics-as-code + agent-readable catalog) → source
bindings. Only the bindings tier knows Teradata exists; the model is maintained
and enhanced as processes evolve. On top of it: an Intelligence layer (insight
discovery, problem analysis, action recommendation, action impact assessment,
with skill/action learning loops) and an Application layer (24×7 reporting,
constant optimization via HIL + agentic, ad hoc conversational problem solving).
Two PBIX reports were reverse-engineered as seed knowledge and as a calibration
benchmark only; Phase 1 data profiling is ~80% complete.

**Read before doing anything:** `docs/00_vision_target_architecture.md` (the
objective and decoupling principle — overrides older framing),
`docs/01_decision_log.md` (binding decisions D1–D8),
`docs/03_profiling_findings.md` (what the data actually looks like — P1–P14
verdicts and load rules R1–R7), `docs/05_open_questions.md` (what to run next).

## Environment & hard guardrails

- Database: **Teradata**, server `teradata2690`. Connect via `scripts/td.py`
  (uses `teradatasql`; credentials from `.env`, never hardcoded, never committed).
- **READ-ONLY.** Only `SELECT` / `SEL`, `HELP TABLE`, `SHOW VIEW/TABLE`, and DBC
  dictionary queries. Never CREATE/INSERT/UPDATE/DELETE/COLLECT STATS on any
  production object. If a materialization is ever needed, stop and ask the user.
- **Sampling cap:** every exploratory query on event/fact tables must filter to
  `GE DATE - 150` (or tighter). History may extend to ~18 months later (D4), but
  not during exploration.
- **No `warehousedb` SELECT access.** The PBIX mart `warehousedb.MB_ZZ_parcels`
  cannot be queried; it exists only as the reconciliation benchmark (an embedded
  730,982-row snapshot, refresh 2026-05-19, was profiled offline). Build from
  PRODVM sources instead — this was validated as fully reconstructable (Q1–Q5).
- Prefer `PRODVM.*` views. `PRODVMUPD` is the intraday path — target-state only
  (Phase 3 / NRT), do not build v1 against it.
- Teradata dialect notes: `SEL` = SELECT; date math `WHERE col GE DATE - 150`;
  dictionary via `DBC.TablesV` / `DBC.ColumnsV` (match names with `LOWER()`,
  views return NULL ColumnType — use `HELP TABLE` or check the base table);
  `TOP n` not LIMIT; trailing-space CHAR comparisons need `TRIM()`.

## Core facts already established (do not re-derive)

- **Grain:** `PRODVM.ZZ_RETURN_REQUESTED` = one row per
  (RETURNID, ORDERNUMBER, ORDERLINEITEMNUMBER) — verified unique on 1,192,901 rows
  / 560,912 returns / 150d. A return = one parcel: ≤1 TRACKINGID ever (5.7% null).
- **State model ①–⑤:** ① Requested (ZZ_RETURN_REQUESTED.DATETIMEREQUESTED) →
  ② carrier scan-in (ZZ_RETURN_IN_TRANSIT milestone row 1) → ③ delivered to
  retailer (first DELIVERED-class milestone, row 2) → ④ warehouse processed
  (RETURN_ITEM / EVRI event P394) → ⑤ refund (event 0097 — 1,244,064 events,
  100% on credited items; CUSTOMER_CREDITED_IND, POSTAGE_REFUND_VALUE).
  Full spec: `docs/04_state_model_spec.md`.
- **ZZ_RETURN_IN_TRANSIT is a milestone log, not a step history** (≤3 rows;
  row1 82.6% IN_TRANSIT, row2 99.3% DELIVERED). Full EVRI step telemetry lives in
  `PRODVM.HERMES_RETURN_TRACKING_DETAIL` (join on HERMES_BARCODE = TRACKINGID).
- **BLOCKER P13:** the ZZ→WMS bridge join (`ORDERNUMBER` =
  `RETURN_ITEM.ORDER_SERIAL_NUMBER`) matches **0%** — key format mismatch.
  Repair via P15a/b in `sql/open/` (try `WAREHOUSEREFERENCE = RETURN_NUMBER`).
  Until fixed, states ④–⑤ cannot be attached to portal requests.
- **CDC freshness (P11):** batch loads ~daily; INSERTED_ON lag median 1.6d,
  p95 3.6d, max 3.8d; 0.4% negative-lag anomalies. v1 honest promise:
  "requested ≤2 days ago, complete to ~4 days ago". NRT requires PRODVMUPD.
- Load rules **R1–R7** (dedupe, first-DELIVERED, scan-in fallback,
  request_attempt_seq, no-label cohort, idle population, watermark+7d window)
  are binding for L1 — see `docs/03_profiling_findings.md`.

## Architecture (agreed)

Four-layer **NB-OS** stack (see `docs/00_vision_target_architecture.md` and
`layers/README.md`): **Data layer** (the semantic model — ACTIVE FOCUS, built
engine-agnostic now, Databricks later) → **Infrastructure & Integration layer**
(Databricks impl, always-on refresh daily/hourly/TBD, service deployment, action
initiation on N Brown operational systems — DEFERRED, placeholders only) →
**Intelligence layer** (insight discovery, problem analysis, action
recommendation, impact assessment; skill/action learning loops) → **Application
layer** (24×7 reporting, constant optimization HIL+agentic, conversational).
Application & Intelligence consume the Data layer; Infra & Integration runs
everything and is the only layer that writes to operational systems.

The Data layer is itself decoupled from source via three tiers, mapped to
`layers/data_layer/`: tier 1 process ontology (`tier1_ontology/`, source-agnostic
business model) → tier 2 semantic contracts (`tier2_contracts/`: canonical
schemas, `metric_registry/`, agent-readable `catalog/`, DQ SLOs) → tier 3 source
bindings (`tier3_bindings/`: PRODVM mappings + rules R1–R7 + watermarks — the ONLY
tier that knows Teradata/Databricks). Daily batch v1 (D5). Domain roadmap: returns
→ refunds → customer contacts (C-series discovery, not started).

Discovery work (evidence + SQL) stays at repo root (`docs/`, `sql/`, `data/`,
`reference/`); `layers/` holds the **designed semantic artifacts**. Phase plan:
`reference/Semantic_Layer_Execution_Plan_v0_3.md`.

## Immediate next steps (in order — see sql/REGISTER.md for IDs/status)

1. Run `sql/open/P15_P17_next_batch.sql` (you have DB access). Covers
   **REF-BRIDGE-01** (ZZ→WMS key diagnosis & repair — the blocker),
   **REF-VOCAB-01** (decode RETURN_EVENT_CODE, confirm 0097 = credit),
   **RET-ORDERSTATUS-01** (ORDERSTATUS/RETAILER profile). Runner names CSVs from
   the `@name` markers into `data/profiling_results/`.
2. Run the open items in `sql/open/Phase1_Validation_Revised_No_Warehousedb.sql`:
   RET-REASON-01, RET-HIST-01, RET-FRESH-01, REF-DISCOVERY-01, RET-NRT-01,
   RET-PAYMENT-01, RET-KEYMAP-01, REF-EVENTVOCAB-FULL, and the state-reconstruction
   set RET-STATE-01/02/03 (legacy Q7–Q19 inside that file).
3. For each result: write the verdict into `docs/03_profiling_findings.md`, flip
   the row in `sql/REGISTER.md` to ANSWERED, and regenerate
   `reference/Returns_Profiling_ER_Model.html` if the ER picture changes (esp.
   once REF-BRIDGE-01 repairs the bridge).
4. Gate check: when REF-BRIDGE-01 is fixed and RET-STATE-03 **calibrates**
   live-rebuilt states against the mart benchmark figures in docs/03 (exact or
   explained-and-documented deltas), Phase 1 closes. Phase 2 then delivers the
   first versioned cut of all three Data-layer tiers (in `layers/data_layer/`)
   for returns + refunds.

## Working conventions

- **`sql/REGISTER.md` is the single source of truth** for every investigative
  question. Questions have stable, topic-keyed IDs (`RET-`/`REF-`/`CAT-`/`CON-`),
  assigned once, never renumbered. Folders are lifecycle: `sql/open/` (queue),
  `sql/answered/` (verdict in docs/03), `sql/archive/` (superseded, never run).
  The old inline P-/Q-numbers are historical and collide across files — trust the
  register, not the numbers. New question → next free ID in its domain, add an
  OPEN row, `@name` it in the SQL to match the ID.
- Annotate results in `docs/03_profiling_findings.md` with verdict
  (CONFIRMED / FLAG / BLOCKER) and the rows/percentages that justify it; flip the
  register row to ANSWERED with the doc reference.
- Keep all generated SQL in `sql/`; never run ad-hoc SQL without saving it.
- Outputs from queries → `data/profiling_results/<ID>_<short_name>.csv`
  (the runner names CSVs from the `@name` marker).
- When unsure whether a table exists or what its columns are, check
  `data/catalog/db_table_column_name.csv` (94,983-row dump of DBC.ColumnsV for
  BICOEDB, Merchanddb, PO_VM, PRODVM, WAREHOUSEDB) before querying DBC.
